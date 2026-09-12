import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../domain/color_look.dart';

/// One long-lived isolate and interpreter per job, with bounded inference tiles.
class EnhanceWorker {
  EnhanceWorker._(this._isolate, this._port, this._messages);
  final Isolate _isolate;
  final SendPort _port;
  final StreamIterator<dynamic> _messages;
  static Future<EnhanceWorker> start() async {
    final receive = ReceivePort();
    final messages = StreamIterator<dynamic>(receive);
    final isolate = await Isolate.spawn(_workerMain, receive.sendPort);
    await messages.moveNext();
    return EnhanceWorker._(isolate, messages.current as SendPort, messages);
  }

  Future<(int, int)> frame(
    String input,
    String output,
    String model,
    String cancelFile,
    EnhanceSettings settings, {
    bool video = false,
  }) async {
    _port.send((input, output, model, cancelFile, settings, video));
    if (!await _messages.moveNext()) {
      throw StateError('Processamento interrompido');
    }
    final reply = _messages.current;
    if (reply is String) throw StateError(reply);
    return reply as (int, int);
  }

  Future<void> close() async {
    _port.send(null);
    await _messages
        .moveNext(); // interpreter.close completes before isolate termination
    await _messages.cancel();
    _isolate.kill(priority: Isolate.immediate);
  }
}

void _workerMain(SendPort reply) async {
  final commands = ReceivePort();
  reply.send(commands.sendPort);
  Interpreter? net;
  try {
    await for (final message in commands) {
      if (message == null) break;
      try {
        final (input, output, model, cancel, settings, video) =
            message as (String, String, String, String, EnhanceSettings, bool);
        void check() {
          if (File(cancel).existsSync()) throw StateError('Cancelado');
        }

        check();
        final decoded = img.decodeImage(File(input).readAsBytesSync());
        if (decoded == null) {
          throw StateError('Formato de imagem não suportado');
        }
        var image = img.bakeOrientation(decoded);
        if (settings.ai) {
          net ??= Interpreter.fromFile(
            File(model),
            options: InterpreterOptions()..threads = 2,
          );
          image = upscaleTiled(image, net, settings.scale, check);
        }
        check();
        image = applyEnhancement(image, settings);
        if (video && (image.width.isOdd || image.height.isOdd)) {
          image = img.copyResize(
            image,
            width: math.max(2, image.width ~/ 2 * 2),
            height: math.max(2, image.height ~/ 2 * 2),
          );
        }
        File(output).writeAsBytesSync(img.encodePng(image, level: 1));
        reply.send((image.width, image.height));
      } catch (e) {
        reply.send(e.toString());
      }
    }
  } finally {
    net?.close();
    commands.close();
    reply.send(true);
  }
}

img.Image upscaleTiled(
  img.Image source,
  Interpreter net,
  int scale,
  void Function() check,
) {
  if (![1, 2, 4].contains(scale)) {
    throw ArgumentError.value(scale, 'scale', 'Use 1, 2 or 4');
  }
  final input = net.getInputTensor(0), output = net.getOutputTensor(0);
  final shape = input.shape, out = output.shape;
  if (shape.length != 4 ||
      shape[0] != 1 ||
      shape[3] != 3 ||
      out.length != 4 ||
      out[1] != shape[1] * 4 ||
      out[2] != shape[2] * 4 ||
      out[3] != 3) {
    throw StateError('Modelo de super-resolução incompatível');
  }
  final tw = shape[2], th = shape[1];
  const pad = 16;
  final cw = tw - pad * 2, ch = th - pad * 2, s = scale.clamp(1, 4);
  final result = img.Image(
    width: source.width * s,
    height: source.height * s,
    numChannels: 4,
  );
  final floats = Float32List(tw * th * 3);
  for (var y = 0; y < source.height; y += ch) {
    for (var x = 0; x < source.width; x += cw) {
      check();
      for (var ty = 0; ty < th; ty++) {
        for (var tx = 0; tx < tw; tx++) {
          final pixel = source.getPixel(
            (x + tx - pad).clamp(0, source.width - 1),
            (y + ty - pad).clamp(0, source.height - 1),
          );
          final p = (ty * tw + tx) * 3;
          floats[p] = pixel.r.toDouble();
          floats[p + 1] = pixel.g.toDouble();
          floats[p + 2] = pixel.b.toDouble();
        }
      }
      input.data = floats.buffer.asUint8List();
      net.invoke();
      final bytes = output.data;
      final values = bytes.buffer.asFloat32List(
        bytes.offsetInBytes,
        bytes.lengthInBytes ~/ 4,
      );
      final w = math.min(cw, source.width - x) * s,
          h = math.min(ch, source.height - y) * s;
      final factor = 4 ~/ s;
      for (var dy = 0; dy < h; dy++) {
        for (var dx = 0; dx < w; dx++) {
          double r = 0, g = 0, b = 0;
          // Area downsample of the 4x neural output for the 2x option.
          for (var yy = 0; yy < factor; yy++) {
            for (var xx = 0; xx < factor; xx++) {
              final p =
                  ((pad * 4 + dy * factor + yy) * out[2] +
                      pad * 4 +
                      dx * factor +
                      xx) *
                  3;
              r += values[p];
              g += values[p + 1];
              b += values[p + 2];
            }
          }
          final n = factor * factor;
          result.setPixelRgba(
            x * s + dx,
            y * s + dy,
            (r / n).clamp(0, 255),
            (g / n).clamp(0, 255),
            (b / n).clamp(0, 255),
            source.getPixel(x + dx ~/ s, y + dy ~/ s).a,
          );
        }
      }
    }
  }
  return result;
}

img.Image applyEnhancement(img.Image source, EnhanceSettings settings) {
  final extra = settings.look.clarity * settings.strength;
  final blur = (settings.denoise > 0 || settings.detail > 0 || extra > 0)
      ? img.gaussianBlur(img.Image.from(source), radius: 1)
      : null;
  for (final pixel in source) {
    var r = pixel.r.toDouble(), g = pixel.g.toDouble(), b = pixel.b.toDouble();
    if (blur != null) {
      final p = blur.getPixel(pixel.x, pixel.y);
      final amount =
          settings.detail.clamp(0.0, 1.0) +
          extra -
          settings.denoise.clamp(0.0, 1.0);
      r += (r - p.r) * amount;
      g += (g - p.g) * amount;
      b += (b - p.b) * amount;
    }
    final c = settings.look.apply(r, g, b, settings.strength);
    final nx = (pixel.x + .5) / source.width * 2 - 1,
        ny = (pixel.y + .5) / source.height * 2 - 1;
    final edge = ((nx * nx + ny * ny) / 2).clamp(0.0, 1.0);
    final shade = 1 - settings.look.vignette * settings.strength * edge * edge;
    pixel
      ..r = c.$1 * shade
      ..g = c.$2 * shade
      ..b = c.$3 * shade;
  }
  return source;
}
