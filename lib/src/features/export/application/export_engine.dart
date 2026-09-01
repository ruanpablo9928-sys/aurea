import 'dart:io';
import 'dart:ui' show BlendMode;

import 'package:ffmpeg_kit_flutter_new_full/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_full/return_code.dart';
import 'package:path_provider/path_provider.dart';

import '../../editor/domain/layer.dart';
import '../../editor/domain/mask.dart';
import '../../editor/domain/video_project.dart';
import '../domain/export_settings.dart';
import 'platform_encoder.dart';

/// EXPORTACAO DE VIDEO — as partes que nao dependem da tela.
///
/// O problema: a composicao da Aurea e desenhada em Flutter (texto,
/// formas, 3D, efeitos), e video de verdade vive numa textura de
/// plataforma, que NAO entra no `toImage` de um RepaintBoundary. Entao
/// nao da para simplesmente "gravar a tela".
///
/// A saida e inverter: o FFmpeg extrai os quadros de cada camada de
/// video para o disco, o Flutter compoe cada quadro da composicao com
/// esses quadros ja decodificados, e o CODIFICADOR DA PLATAFORMA grava o
/// arquivo. Assim TUDO que aparece no preview aparece no arquivo —
/// inclusive efeito aplicado em cima de video.
///
/// Quem codifica e o MediaCodec (Android) ou o AVAssetWriter (iOS), nao
/// o x264: e hardware, e nao arrasta a GPL para dentro do aplicativo. O
/// FFmpeg segue no app so para DECODIFICAR e para juntar o audio.
class ExportEngine {
  ExportEngine(this.project, [this.settings = const ExportSettings()]);

  final VideoProject project;
  final ExportSettings settings;

  Directory? _work;
  bool _cancelled = false;

  void cancel() {
    _cancelled = true;
    PlatformEncoder.cancel();
  }

  bool get cancelled => _cancelled;

  int get fps => settings.resolveFps(project.fps);

  /// Tamanho de SAIDA (pode ser diferente do projeto). A composicao
  /// continua sendo desenhada no tamanho dela; quem redimensiona e o
  /// codificador, com a proporcao preservada.
  int get width => settings.resolve(project.outputWidth, project.outputHeight).$1;
  int get height =>
      settings.resolve(project.outputWidth, project.outputHeight).$2;

  /// Quantos quadros a composicao inteira tem.
  int get frameCount {
    final us = project.duration.inMicroseconds;
    if (us <= 0) return 0;
    return (us * fps / 1000000).round().clamp(1, 60 * 60 * 60);
  }

  Duration timeOfFrame(int i) =>
      Duration(microseconds: (i * 1000000 / fps).round());

  Future<Directory> workDir() async {
    if (_work != null) return _work!;
    final tmp = await getTemporaryDirectory();
    final d = Directory('${tmp.path}/aurea_export');
    if (d.existsSync()) d.deleteSync(recursive: true);
    d.createSync(recursive: true);
    return _work = d;
  }

  Future<void> cleanup() async {
    try {
      _work?.deleteSync(recursive: true);
    } catch (_) {}
  }

  // ------------------------------------------------- CORTE PURO

  /// CORTE PURO: a composicao e um clipe so, sem nada por cima. Nesse
  /// caso recodificar e desperdicio — da para copiar as trilhas e sair
  /// quase instantaneo, com a qualidade intacta.
  ///
  /// Basta UMA coisa fora do lugar (um efeito, uma mascara, opacidade
  /// diferente, transformacao mexida) para deixar de valer, porque ai o
  /// arquivo teria de mostrar algo que a fonte nao tem.
  VideoLayer? get pureCutSource {
    if (project.layers.length != 1) return null;
    final l = project.layers.first;
    if (l is! VideoLayer) return null;

    if (l.effects.any((e) => e.enabled)) return null;
    if (l.masks.isNotEmpty) return null;
    if (l.matteMode != MatteMode.none) return null;
    if (l.blendMode != BlendMode.srcOver) return null;
    // Velocidade diferente de 1 nao e copia: tem de renderizar.
    if (l.speed != 1.0) return null;
    // Vinculo de propriedade tambem muda o quadro.
    if (project.links.any((k) => k.targetLayerId == l.id)) return null;

    // Qualquer transformacao mexida muda o quadro: nao e mais copia.
    if (l.opacity.isAnimated || l.opacity.base != 1) return null;
    if (l.scaleX.isAnimated || l.scaleX.base != 1) return null;
    if (l.scaleY.isAnimated || l.scaleY.base != 1) return null;
    if (l.rotation.isAnimated || l.rotation.base != 0) return null;
    if (l.position.isAnimated) return null;

    return l;
  }

  /// Tenta o caminho rapido. Devolve o arquivo, ou null se nao coube.
  Future<File?> tryPureCut() async {
    final l = pureCutSource;
    if (l == null) return null;
    if (!await PlatformEncoder.available) return null;

    final file = await _outputFile();
    final ok = await PlatformEncoder.remux(
      source: l.sourcePath,
      target: file.path,
      start: l.sourceOffset,
      end: l.sourceOffset + l.duration,
    );
    if (!ok || !file.existsSync() || file.lengthSync() < 1024) return null;
    return file;
  }

  // ------------------------------------------- quadros das camadas

  /// Extrai os quadros de UMA camada de video, ja no fps da composicao e
  /// so o trecho usado. Devolve a pasta com `%06d.jpg`.
  ///
  /// Isto e DECODIFICACAO — nao precisa de codec GPL.
  Future<Directory> extractVideoFrames(
    VideoLayer layer, {
    void Function(double p)? onProgress,
  }) async {
    final work = await workDir();
    final dir = Directory('${work.path}/v_${layer.id}');
    dir.createSync(recursive: true);

    final start = layer.sourceOffset.inMicroseconds / 1000000.0;
    // Le [speed] segundos de fonte para cada segundo de linha, e depois
    // reescreve o relogio dos quadros com setpts: e assim que camera
    // lenta vira quadros de verdade em vez de quadro repetido.
    final vel = layer.speed <= 0 ? 1.0 : layer.speed;
    final dur = layer.sourceSpan.inMicroseconds / 1000000.0;

    // Escala para caber na composicao mantendo proporcao — quadro maior
    // que isso e memoria jogada fora.
    final session = await FFmpegKit.executeWithArguments([
      '-y',
      '-ss', start.toStringAsFixed(3),
      '-t', dur.toStringAsFixed(3),
      '-i', layer.sourcePath,
      '-vf',
      '${vel == 1.0 ? '' : 'setpts=PTS/${vel.toStringAsFixed(4)},'}'
          'fps=$fps,scale=$width:$height:force_original_aspect_ratio='
          'decrease',
      '-q:v', '3',
      '-start_number', '0',
      '${dir.path}/%06d.jpg',
    ]);
    if (!ReturnCode.isSuccess(await session.getReturnCode())) {
      final log = await session.getAllLogsAsString();
      throw ExportException(
          'Falha ao ler o video "${layer.name}".\n${_tail(log)}');
    }
    onProgress?.call(1);
    return dir;
  }

  // --------------------------------------------------------- audio

  /// A corrente de `atempo` para uma velocidade qualquer.
  ///
  /// O filtro so aceita 0,5..2 de cada vez: 4x sai de duas etapas de 2x.
  /// Uma etapa fora da faixa e ignorada em silencio pelo FFmpeg — e o
  /// audio fica fora de sincronia com o video sem ninguem entender por
  /// que.
  static String _atempo(double v) {
    if (v <= 0 || (v - 1).abs() < 0.001) return '';
    var resto = v;
    final etapas = <String>[];
    while (resto > 2.0 && etapas.length < 6) {
      etapas.add('atempo=2.0');
      resto /= 2.0;
    }
    while (resto < 0.5 && etapas.length < 6) {
      etapas.add('atempo=0.5');
      resto /= 0.5;
    }
    etapas.add('atempo=${resto.toStringAsFixed(4)}');
    return '${etapas.join(',')},';
  }

  /// Camadas que carregam som. Mudo sai da conta aqui — nao adianta
  /// mixar uma faixa em volume zero e pagar por ela.
  List<Layer> get audioSources => [
        for (final l in project.layers)
          if (_specOf(l) != null && !_specOf(l)!.muted)
            if (l is AudioLayer || (l is VideoLayer && l.volume > 0.001)) l,
      ];

  static AudioSpec? _specOf(Layer l) => switch (l) {
        AudioLayer a => a.audio,
        VideoLayer v => v.audio,
        _ => null,
      };

  /// Monta as entradas e o grafo de mixagem. Cada faixa e cortada no
  /// trecho usado, atrasada ate a posicao dela na linha do tempo e
  /// ajustada no volume.
  ({List<String> inputs, String? filter, String? outLabel}) audioGraph(
      int firstInputIndex) {
    final sources = audioSources;
    if (sources.isEmpty) {
      return (inputs: <String>[], filter: null, outLabel: null);
    }

    final inputs = <String>[];
    final chains = <String>[];
    final labels = <String>[];
    final porCamada = <String, String>{};
    final duckAlvo = <String, String?>{};
    var idx = firstInputIndex;

    for (final l in sources) {
      final path =
          l is AudioLayer ? l.sourcePath : (l as VideoLayer).sourcePath;
      final volume = l is AudioLayer ? l.volume : (l as VideoLayer).volume;
      final offset =
          l is VideoLayer ? l.sourceOffset : (l as AudioLayer).sourceOffset;
      final dur = l.duration.inMicroseconds / 1000000.0;
      final delayMs = l.startTime.inMilliseconds;

      inputs.addAll([
        '-ss', (offset.inMicroseconds / 1000000.0).toStringAsFixed(3),
        '-t', dur.toStringAsFixed(3),
        '-i', path,
      ]);

      final spec = _specOf(l) ?? const AudioSpec();
      final ganho = (volume * spec.gain).clamp(0.0, 12.0);

      // FADE de igual potencia: linear soa como buraco no meio, porque
      // o ouvido responde a potencia.
      final fades = <String>[];
      if (spec.fadeIn > Duration.zero) {
        final d = spec.fadeIn.inMilliseconds / 1000.0;
        fades.add('afade=t=in:st=0:d=${d.toStringAsFixed(3)}:curve=qsin');
      }
      if (spec.fadeOut > Duration.zero) {
        final d = spec.fadeOut.inMilliseconds / 1000.0;
        final st = (dur - d).clamp(0.0, dur);
        fades.add('afade=t=out:st=${st.toStringAsFixed(3)}'
            ':d=${d.toStringAsFixed(3)}:curve=qsin');
      }

      final vel = switch (l) {
        VideoLayer v => v.speed,
        AudioLayer a => a.speed,
        _ => 1.0,
      };
      // atempo so aceita 0,5..2 por etapa; velocidades maiores viram
      // uma corrente de etapas.
      final tempo = _atempo(vel);

      final label = 'a$idx';
      chains.add(
        '[$idx:a]aresample=44100,'
        '$tempo'
        'volume=${ganho.toStringAsFixed(3)}'
        '${fades.isEmpty ? '' : ',${fades.join(',')}'},'
        'adelay=$delayMs|$delayMs,'
        'apad=whole_dur=${_total.toStringAsFixed(3)}[$label]',
      );
      labels.add('[$label]');
      porCamada[l.id] = label;
      duckAlvo[l.id] = spec.duckAgainstId;
      idx++;
    }

    // ABAIXAR PELA VOZ. O compressor de cadeia lateral e a ferramenta
    // certa: a musica desce quando a voz entra e volta quando ela para,
    // sem ninguem desenhar envelope na mao.
    for (final entry in duckAlvo.entries) {
      final vozLabel = entry.value == null ? null : porCamada[entry.value];
      final musicaLabel = porCamada[entry.key];
      if (vozLabel == null || musicaLabel == null) continue;
      final amt = _duckAmountOf(entry.key);
      // A voz e usada como referencia SEM ser consumida: asplit deixa
      // ela seguir para a mixagem tambem.
      final ref = 'ref_${entry.key.hashCode.abs()}';
      final saida = 'dk_${entry.key.hashCode.abs()}';
      chains.add('[$vozLabel]asplit=2[$vozLabel~a][$ref]');
      chains.add(
        '[$musicaLabel][$ref]sidechaincompress='
        'threshold=0.05:ratio=${(1 + amt * 19).toStringAsFixed(1)}'
        ':attack=80:release=400[$saida]',
      );
      final i = labels.indexOf('[$musicaLabel]');
      if (i >= 0) labels[i] = '[$saida]';
      final j = labels.indexOf('[$vozLabel]');
      if (j >= 0) labels[j] = '[$vozLabel~a]';
    }

    final mix = labels.length == 1
        ? '${labels.first}anull[aout]'
        : '${labels.join()}amix=inputs=${labels.length}'
            ':duration=longest:dropout_transition=0[aout]';

    return (
      inputs: inputs,
      filter: '${chains.join(';')};$mix',
      outLabel: '[aout]',
    );
  }

  double get _total => project.duration.inMicroseconds / 1000000.0;

  double _duckAmountOf(String layerId) {
    for (final l in project.layers) {
      if (l.id != layerId) continue;
      return (_specOf(l)?.duckAmount ?? 0.7).clamp(0.0, 1.0);
    }
    return 0.7;
  }

  // ------------------------------------------------------ codificar

  Future<File> _outputFile() async {
    final docs = await getApplicationDocumentsDirectory();
    final out = Directory('${docs.path}/exports');
    if (!out.existsSync()) out.createSync(recursive: true);
    final stamp = project.name
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_')
        .toLowerCase();
    final file = File('${out.path}/aurea_'
        '${stamp.isEmpty ? 'video' : stamp}_${frameCount}f.mp4');
    if (file.existsSync()) file.deleteSync();
    return file;
  }

  /// SEQUENCIA PNG: leva os quadros para uma pasta que a pessoa acha.
  ///
  /// E o unico caminho com TRANSPARENCIA de verdade — MP4 com alfa so
  /// toca em um punhado de programas. Serve para levar a arte pronta
  /// para outro editor sem perder nada.
  Future<Directory> saveSequence(Directory framesDir) async {
    final base = await getApplicationDocumentsDirectory();
    final stamp = project.name.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final destino = Directory('${base.path}/exports/${stamp}_png');
    if (destino.existsSync()) destino.deleteSync(recursive: true);
    destino.createSync(recursive: true);

    final frames = framesDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.png'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    if (frames.isEmpty) {
      throw ExportException('Nenhum quadro foi desenhado.');
    }
    for (var i = 0; i < frames.length; i++) {
      final nome = i.toString().padLeft(6, '0');
      frames[i].copySync('${destino.path}/$nome.png');
    }
    return destino;
  }

  /// Codifica a sequencia de quadros com o CODIFICADOR DA PLATAFORMA e,
  /// se houver som, junta o audio depois sem tocar no video.
  Future<File> encode({
    required Directory framesDir,
    required String quality,
    void Function(double p)? onProgress,
  }) async {
    final file = await _outputFile();
    final frames = framesDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.png'))
        .map((f) => f.path)
        .toList()
      ..sort();
    if (frames.isEmpty) {
      throw ExportException('Nenhum quadro foi desenhado.');
    }

    final bitrate = settings.bitrateMbps != null ||
            settings.codec == ExportCodec.hevc ||
            settings.size != ExportSize.original
        ? settings.bitrateFor(width, height, fps)
        : PlatformEncoder.bitrateFor(width, height, fps, quality);
    final silent = File('${framesDir.parent.path}/mudo.mp4');

    if (await PlatformEncoder.available) {
      await PlatformEncoder.start(
        path: silent.path,
        width: width,
        height: height,
        fps: fps,
        bitrate: bitrate,
        hevc: settings.codec == ExportCodec.hevc,
      );
      // Em lotes: atravessar a ponte por quadro custa mais que codificar.
      const batch = 12;
      for (var i = 0; i < frames.length; i += batch) {
        if (_cancelled) throw ExportException('Cancelado.');
        final end = (i + batch).clamp(0, frames.length);
        await PlatformEncoder.frames(frames.sublist(i, end));
        onProgress?.call(end / frames.length * 0.9);
      }
      await PlatformEncoder.finish();
    } else {
      // Aparelho sem codificador de hardware. Nao caimos no x264: ele e
      // GPL e nem existe mais no pacote. MPEG-4 parte 2 e LGPL e sai do
      // apuro com arquivo maior.
      await _encodeFallback(frames, framesDir, silent, bitrate);
    }

    if (!silent.existsSync() || silent.lengthSync() < 1024) {
      throw ExportException('O codificador nao produziu video.');
    }

    final audio = audioGraph(1);
    if (audio.outLabel == null) {
      silent.renameSync(file.path);
      onProgress?.call(1);
      return file;
    }

    // Junta o audio SEM recodificar o video.
    final session = await FFmpegKit.executeWithArguments([
      '-y',
      '-i', silent.path,
      ...audio.inputs,
      '-filter_complex', audio.filter!,
      '-map', '0:v',
      '-map', audio.outLabel!,
      '-c:v', 'copy',
      '-c:a', 'aac',
      '-b:a', '192k',
      '-movflags', '+faststart',
      '-t', _total.toStringAsFixed(3),
      file.path,
    ]);
    if (!ReturnCode.isSuccess(await session.getReturnCode())) {
      final log = await session.getAllLogsAsString();
      throw ExportException('Falha ao juntar o audio.\n${_tail(log)}');
    }
    onProgress?.call(1);
    return file;
  }

  Future<void> _encodeFallback(List<String> frames, Directory framesDir,
      File target, int bitrate) async {
    final session = await FFmpegKit.executeWithArguments([
      '-y',
      '-framerate', '$fps',
      '-i', '${framesDir.path}/%06d.png',
      '-c:v', 'mpeg4',
      '-b:v', '$bitrate',
      '-pix_fmt', 'yuv420p',
      '-r', '$fps',
      target.path,
    ]);
    if (!ReturnCode.isSuccess(await session.getReturnCode())) {
      final log = await session.getAllLogsAsString();
      throw ExportException('Falha ao codificar o video.\n${_tail(log)}');
    }
  }

  static String _tail(String? log) {
    if (log == null || log.isEmpty) return '';
    final lines = log.trim().split('\n');
    return lines.length <= 12
        ? lines.join('\n')
        : lines.sublist(lines.length - 12).join('\n');
  }
}

class ExportException implements Exception {
  ExportException(this.message);
  final String message;
  @override
  String toString() => message;
}
