import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:aurea/src/features/editor/domain/effect.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/pixel_effect.dart';
import 'package:aurea/src/features/editor/presentation/widgets/pixel_effect_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// OS TRES RECORTES E O CONTORNO — rodando no shader de verdade.
///
/// O que se prova aqui nao e que o kernel existe (isso o contrato ja
/// cobra): e que o fundo verde SOME e o assunto FICA. Um chroma key que
/// deixa a borda escura ou apaga a pele nao serve para nada, e so
/// olhando o alfa que sai do shader e que se sabe.
///
/// Os quatro sao efeitos de GPU sem versao em CPU (recorte por pixel na
/// thread de UI e o que travava o app), entao estes testes exigem o
/// motor de pixel — sem ele, falham, e nao passam calados.

/// Um quadro 16x8 com QUATRO regioes: fundo verde de estudio, uma pele,
/// um cinza e um preto. Cada regiao ocupa 4 colunas — largo o bastante
/// para ter MIOLO chapado longe de qualquer borda (o Sobel olha x+-1).
Future<ui.Image> quadro() async {
  const w = 16, h = 8;
  final bytes = Uint8List(w * h * 4);
  const cores = [
    [0, 177, 64], // verde de estudio (0xFF00B140)
    [220, 170, 140], // pele
    [128, 128, 128], // cinza
    [8, 8, 8], // quase preto
  ];
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final c = cores[x ~/ 4];
      final i = (y * w + x) * 4;
      bytes[i] = c[0];
      bytes[i + 1] = c[1];
      bytes[i + 2] = c[2];
      bytes[i + 3] = 255;
    }
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final d = ui.ImageDescriptor.raw(
    buffer,
    width: w,
    height: h,
    pixelFormat: ui.PixelFormat.rgba8888,
  );
  final codec = await d.instantiateCodec();
  final img = (await codec.getNextFrame()).image;
  codec.dispose();
  d.dispose();
  buffer.dispose();
  return img;
}

Future<Uint8List> aplicar(ui.Image entrada, EffectInstance efeito) async {
  final frame = PixelEffectFrame.of(efeito, Duration.zero);
  final rec = ui.PictureRecorder();
  final canvas = ui.Canvas(rec);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 16, 8),
    ui.Paint()
      ..shader = PixelEffectEngine.createShader(
        frame,
        width: 16,
        height: 8,
        image: entrada,
      ),
  );
  final pic = rec.endRecording();
  final out = await pic.toImage(16, 8);
  final data = await out.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  pic.dispose();
  out.dispose();
  return data!.buffer.asUint8List();
}

/// Alfa medio de uma regiao (colunas 4r..4r+3), em 0..255.
double alfaDa(Uint8List px, int regiao) {
  var soma = 0;
  for (var y = 0; y < 8; y++) {
    for (var x = regiao * 4; x < regiao * 4 + 4; x++) {
      soma += px[(y * 16 + x) * 4 + 3];
    }
  }
  return soma / 32;
}

const verde = 0, pele = 1, cinza = 2, preto = 3;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await PixelEffectEngine.warmUp();
    expect(PixelEffectEngine.ready, isTrue,
        reason: 'keying vive no shader; sem ele nao ha o que testar');
  });

  group('Chroma Key', () {
    test('o fundo verde some e a pele fica', () async {
      final px = await aplicar(
        await quadro(),
        EffectInstance(type: EffectType.chromaKey, params: const {}),
      );
      expect(alfaDa(px, verde), lessThan(8), reason: 'o verde nao sumiu');
      expect(alfaDa(px, pele), greaterThan(247), reason: 'a pele foi comida');
      expect(alfaDa(px, cinza), greaterThan(247), reason: 'o cinza foi comido');
      expect(alfaDa(px, preto), greaterThan(247), reason: 'o preto foi comido');
    });

    test('uma sombra no fundo verde tambem some (croma, nao RGB)', () async {
      // Verde de estudio a 40% de brilho: mesma cor, mais escura. Um
      // recorte que mede em RGB deixa isso escapar — e a moldura escura
      // em volta do assunto que denuncia recorte amador.
      const w = 8, h = 8;
      final bytes = Uint8List(w * h * 4);
      for (var i = 0; i < w * h; i++) {
        bytes[i * 4] = 0;
        bytes[i * 4 + 1] = (177 * .4).round();
        bytes[i * 4 + 2] = (64 * .4).round();
        bytes[i * 4 + 3] = 255;
      }
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final d = ui.ImageDescriptor.raw(
        buffer,
        width: w,
        height: h,
        pixelFormat: ui.PixelFormat.rgba8888,
      );
      final codec = await d.instantiateCodec();
      final sombra = (await codec.getNextFrame()).image;
      final px = await aplicar(
        sombra,
        EffectInstance(type: EffectType.chromaKey, params: const {}),
      );
      expect(alfaDa(px, 0), lessThan(40),
          reason: 'a sombra do fundo verde ficou: o recorte mede em RGB');
    });

    test('tolerancia zero nao recorta nada — o neutro e neutro', () async {
      final px = await aplicar(
        await quadro(),
        EffectInstance(
          type: EffectType.chromaKey,
          params: {'tolerancia': AnimatedDouble(0), 'suavidade': AnimatedDouble(0)},
        ),
      );
      // Com tolerancia zero so o verde EXATO cai; a pele continua inteira.
      expect(alfaDa(px, pele), greaterThan(250));
    });
  });

  group('Luma Key', () {
    test('remover o escuro tira o preto e deixa o resto', () async {
      final px = await aplicar(
        await quadro(),
        EffectInstance(type: EffectType.lumaKey, params: const {}),
      );
      expect(alfaDa(px, preto), lessThan(8), reason: 'o preto nao sumiu');
      expect(alfaDa(px, pele), greaterThan(247));
      expect(alfaDa(px, cinza), greaterThan(247));
    });

    test('remover o claro tira a pele e deixa o preto', () async {
      final px = await aplicar(
        await quadro(),
        EffectInstance(
          type: EffectType.lumaKey,
          params: {
            'limiar': AnimatedDouble(.6),
            'inverter': AnimatedDouble(1),
          },
        ),
      );
      expect(alfaDa(px, pele), lessThan(8), reason: 'a pele nao sumiu');
      expect(alfaDa(px, preto), greaterThan(247));
    });
  });

  group('Color Key', () {
    test('tira exatamente a cor pedida', () async {
      final px = await aplicar(
        await quadro(),
        EffectInstance(
          type: EffectType.colorKey,
          color: const ui.Color(0xFF808080), // o cinza
          params: const {},
        ),
      );
      expect(alfaDa(px, cinza), lessThan(8), reason: 'o cinza nao sumiu');
      expect(alfaDa(px, verde), greaterThan(247));
      expect(alfaDa(px, pele), greaterThan(247));
    });
  });

  group('Find Edges', () {
    test('desenha borda onde a cor muda e nada onde e chapado', () async {
      final px = await aplicar(
        await quadro(),
        EffectInstance(type: EffectType.findEdges, params: const {}),
      );
      double lumaEm(int x) {
        var s = 0;
        for (var y = 1; y < 7; y++) {
          final i = (y * 16 + x) * 4;
          s += (px[i] + px[i + 1] + px[i + 2]) ~/ 3;
        }
        return s / 6;
      }

      // Traco "escuro no claro" (padrao): a coluna 4 ve verde a esquerda
      // e pele a direita — e borda. A coluna 6 ve pele dos dois lados —
      // e miolo chapado, e tem de sair quase branca.
      final fronteira = lumaEm(4);
      final miolo = lumaEm(6);
      expect(fronteira, lessThan(miolo - 30),
          reason: 'a borda entre regioes nao apareceu');
    });
  });
}
