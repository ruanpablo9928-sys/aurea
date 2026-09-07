import 'dart:io';

import 'package:aurea/src/features/export/domain/video_color.dart';
import 'package:flutter_test/flutter_test.dart';

/// A COR DOS VIDEOS NA EXPORTACAO TEM DE SER A DO PREVIEW.
///
/// O preview e o player do sistema, que converte YUV->RGB pela etiqueta
/// do arquivo e, sem etiqueta, pelo tamanho (HD = BT.709, SD = BT.601).
/// A exportacao le os quadros pelo FFmpeg — e tem de tomar a MESMA
/// decisao, e entrega-la em RGB (PNG), porque um JPEG e lido como 601
/// nao importa o que tenha dentro. O que estes testes fixam e a decisao
/// e o formato; a conversao em si e do FFmpeg.
void main() {
  group('a matriz e a do player', () {
    test('etiqueta bt709 e respeitada', () {
      final cor = CorDoVideo.deProps({
        'color_space': 'bt709',
        'color_range': 'tv',
        'width': 640,
        'height': 360,
      });
      expect(cor.matrizResolvida, 'bt709');
      expect(cor.matrizParaScale, 'bt709');
      expect(cor.faixaResolvida, 'tv');
    });

    test('sem etiqueta, HD e 709 e SD e 601 — como o ExoPlayer e o AVPlayer', () {
      const hd = CorDoVideo.desconhecida(largura: 1920, altura: 1080);
      const sd = CorDoVideo.desconhecida(largura: 640, altura: 480);
      const hd720 = CorDoVideo.desconhecida(largura: 1280, altura: 720);
      expect(hd.matrizParaScale, 'bt709');
      expect(hd720.matrizParaScale, 'bt709');
      expect(sd.matrizParaScale, 'bt601');
      expect(sd.matrizResolvida, 'bt470bg', reason: 'o nome que o setparams entende');
    });

    test('"unknown" do ffprobe conta como sem etiqueta', () {
      final cor = CorDoVideo.deProps({
        'color_space': 'unknown',
        'color_range': 'unknown',
        'width': '1920',
        'height': '1080',
      });
      expect(cor.matriz, isNull);
      expect(cor.matrizParaScale, 'bt709');
      expect(cor.faixaResolvida, 'tv');
    });

    test('601 tem tres nomes e o scale conhece um', () {
      for (final nome in ['bt470bg', 'smpte170m']) {
        expect(CorDoVideo.deProps({'color_space': nome}).matrizParaScale, 'bt601');
      }
      expect(CorDoVideo.deProps({'color_space': 'bt2020nc'}).matrizParaScale, 'bt2020');
    });

    test('faixa cheia so quando o arquivo diz', () {
      expect(CorDoVideo.deProps({'color_range': 'pc'}).faixaResolvida, 'pc');
      expect(CorDoVideo.deProps({'color_range': 'tv'}).faixaResolvida, 'tv');
      expect(CorDoVideo.deProps({}).faixaResolvida, 'tv');
    });
  });

  group('as receitas', () {
    const hd = CorDoVideo.desconhecida(largura: 1920, altura: 1080);

    test('SDR: etiqueta os quadros, crava a matriz na conversao e sai em RGB', () {
      final vf = filtroSdr(hd, fps: 30, largura: 1080, altura: 1920);
      expect(vf, startsWith('fps=30,'));
      expect(vf, contains('setparams=colorspace=bt709:range=tv'));
      expect(vf, contains('in_color_matrix=bt709:in_range=tv'));
      expect(vf, endsWith('format=rgb24'), reason: 'RGB nao tem matriz para adivinhar');
      expect(vf, contains('force_original_aspect_ratio=decrease'));
    });

    test('HDR (PQ e HLG) passa por tonemap antes de virar 709', () {
      for (final t in ['smpte2084', 'arib-std-b67']) {
        final cor = CorDoVideo.deProps({
          'color_space': 'bt2020nc',
          'color_transfer': t,
          'color_primaries': 'bt2020',
          'width': 3840,
          'height': 2160,
        });
        expect(cor.hdr, isTrue);
        final vf = filtroHdrParaSdr(cor, fps: 30, largura: 1080, altura: 1920);
        expect(vf, contains('zscale=t=linear'));
        expect(vf, contains('tonemap='));
        expect(vf, contains('zscale=t=bt709:m=bt709:r=tv'));
        expect(vf, endsWith('format=rgb24'));
      }
      expect(CorDoVideo.deProps({'color_transfer': 'bt709'}).hdr, isFalse);
    });

    test('a ordem: HDR so para HDR, e a reserva vem por ultimo', () {
      final sdr = receitasDeExtracao(hd, fps: 24, largura: 100, altura: 100);
      expect(sdr, hasLength(2));
      expect(sdr.first, contains('setparams'));
      expect(sdr.last, filtroDeReserva(fps: 24, largura: 100, altura: 100));

      final hdr = receitasDeExtracao(
        CorDoVideo.deProps({'color_transfer': 'smpte2084'}),
        fps: 24,
        largura: 100,
        altura: 100,
      );
      expect(hdr, hasLength(3));
      expect(hdr.first, contains('tonemap'));
    });
  });

  group('o codigo de verdade usa isto', () {
    final engine = File('lib/src/features/export/application/export_engine.dart')
        .readAsStringSync();
    final screen = File('lib/src/features/export/presentation/export_video_screen.dart')
        .readAsStringSync();

    test('os quadros intermediarios sao PNG, e nada mais e JPEG', () {
      expect(engine, contains("%06d.png"));
      expect(engine, isNot(contains('.jpg')));
      expect(screen, isNot(contains('.jpg')));
      expect(screen, contains(".endsWith('.png')"));
    });

    test('a extracao pergunta a cor e tenta as receitas em ordem', () {
      expect(engine, contains('receitasDeExtracao('));
      expect(engine, contains('FFprobeKit.getMediaInformation'));
    });
  });
}
