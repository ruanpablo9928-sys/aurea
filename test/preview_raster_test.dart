import 'package:flutter_test/flutter_test.dart';

import 'package:aurea/src/features/editor/presentation/widgets/preview_raster.dart';

/// A foto que os efeitos tiram da composicao tem de caber na memoria de
/// um celular: na resolucao da TELA, com teto, nunca na da composicao
/// vezes o DPR do aparelho.
void main() {
  test('iPhone com composicao 1080x1920: a foto cabe no preview', () {
    // Preview de 390 pt de largura: escala 0,361; DPR 3.
    final r = previewRasterRatio(
      compWidth: 1080,
      compHeight: 1920,
      stageScale: 390 / 1080,
      devicePixelRatio: 3,
    );
    // ~1,08 pixel por pixel logico: a foto sai com ~1170 x 2080, nao
    // 3240 x 5760.
    expect(r, closeTo(1.083, 0.01));
    expect(1920 * r, lessThan(2100));
  });

  test('o teto segura o iPad e a composicao 4K', () {
    final r = previewRasterRatio(
      compWidth: 3840,
      compHeight: 2160,
      stageScale: 0.5,
      devicePixelRatio: 2,
    );
    // Natural seria 1,0 (3840 px de largura); o teto de 2160 manda.
    expect(3840 * r, closeTo(2160, 1e-6));
  });

  test('preview pequeno respeita os pixels realmente exibidos', () {
    final r = previewRasterRatio(
      compWidth: 1080,
      compHeight: 1920,
      stageScale: 0.05,
      devicePixelRatio: 2,
    );
    expect(r, 0.1);
  });

  test('8K e 16K respeitam o teto mesmo abaixo de um quarto', () {
    for (final side in [7680.0, 15360.0]) {
      final r = previewRasterRatio(
        compWidth: side,
        compHeight: side / 2,
        stageScale: .2,
        devicePixelRatio: 3,
        maxSidePx: 1080,
      );
      expect(side * r, closeTo(1080, 1e-6));
    }
  });

  test('composicao pequena numa tela grande nao passa do natural', () {
    final r = previewRasterRatio(
      compWidth: 320,
      compHeight: 240,
      stageScale: 2,
      devicePixelRatio: 2,
    );
    expect(r, 4);
  });
}
