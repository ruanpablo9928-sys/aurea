import 'dart:ui';

import 'package:aurea/src/features/editor/domain/shape.dart';
import 'package:aurea/src/features/editor/domain/svg_document.dart';
import 'package:flutter_test/flutter_test.dart';

/// SVG COMO FORMA EDITAVEL (nao como imagem).
const _svg = '''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 100" width="200" height="100">
  <defs><linearGradient id="g"><stop offset="0"/></linearGradient></defs>
  <rect x="0" y="0" width="100" height="100" fill="#ff0000"/>
  <g transform="translate(100 0)" fill="rgb(0,128,0)">
    <circle cx="50" cy="50" r="40"/>
    <path d="M 10 10 L 90 10 L 50 90 Z" style="fill:#0000ff;stroke:#ffffff;stroke-width:4"/>
  </g>
  <path d="M 0 0 L 10 10" fill="none" stroke="black" stroke-width="2"/>
  <text x="10" y="10">nao entra</text>
</svg>
''';

void main() {
  group('ler SVG', () {
    late SvgImportado svg;

    setUp(() => svg = lerSvg(_svg, alvo: 400));

    test('le cada desenho, na ordem, com a cor de cada um', () {
      expect(svg.formas.length, 4);
      expect(svg.formas[0].fill, const Color(0xFFFF0000), reason: 'rect');
      // Herda o fill do grupo.
      expect(svg.formas[1].fill, const Color(0xFF008000), reason: 'circle no g');
      // O style do proprio elemento manda mais que o do grupo.
      expect(svg.formas[2].fill, const Color(0xFF0000FF), reason: 'path style');
      expect(svg.formas[2].stroke, const Color(0xFFFFFFFF));
      expect(svg.formas[2].strokeWidth, greaterThan(0));
      // fill="none" nao pinta; o traco continua.
      expect(svg.formas[3].fill, isNull);
      expect(svg.formas[3].stroke, const Color(0xFF000000));
      expect(svg.ignorados, contains('texto do SVG'));
    });

    test('o transform do grupo entra nos pontos', () {
      // O circulo do grupo esta deslocado 100 para a direita do rect.
      double meioX(SvgForma f) {
        var min = double.infinity, max = -double.infinity;
        for (final v in f.path.vertices) {
          min = v.p.dx < min ? v.p.dx : min;
          max = v.p.dx > max ? v.p.dx : max;
        }
        return (min + max) / 2;
      }

      expect(meioX(svg.formas[1]), greaterThan(meioX(svg.formas[0])));
    });

    test('o conjunto vem centrado na origem e no tamanho pedido', () {
      var minX = double.infinity, maxX = -double.infinity;
      var minY = double.infinity, maxY = -double.infinity;
      for (final f in svg.formas) {
        for (final v in f.path.vertices) {
          minX = v.p.dx < minX ? v.p.dx : minX;
          maxX = v.p.dx > maxX ? v.p.dx : maxX;
          minY = v.p.dy < minY ? v.p.dy : minY;
          maxY = v.p.dy > maxY ? v.p.dy : maxY;
        }
      }
      expect((minX + maxX) / 2, closeTo(0, 1));
      expect((minY + maxY) / 2, closeTo(0, 1));
      expect(maxX - minX, closeTo(400, 1), reason: 'o lado maior vale o alvo');
    });

    test('cada desenho vira forma com caminho de NOS (editavel)', () {
      final itens = itensDoSvg(svg);
      expect(itens.length, 4);
      for (final lista in itens) {
        final b = lista.whereType<ShapeBezier>().single;
        expect(b.path.valueAt(Duration.zero).vertices.length, greaterThan(1));
      }
      // O que tem cor no arquivo tem pintura aqui.
      expect(itens[0].whereType<ShapeFill>().single.color, const Color(0xFFFF0000));
      // Desenho so de traco entra com traco.
      expect(itens[3].whereType<ShapeStroke>(), isNotEmpty);
      expect(itens[3].whereType<ShapeFill>(), isEmpty);
    });

    test('arquivo que nao e SVG, ou SVG sem desenho, dizem o porque', () {
      expect(() => lerSvg('<html></html>'), throwsA(isA<SvgException>()));
      expect(
        () => lerSvg('<svg xmlns="http://www.w3.org/2000/svg"></svg>'),
        throwsA(isA<SvgException>()),
      );
    });

    test('polygon, ellipse e line entram', () {
      final outro = lerSvg('''<svg xmlns="http://www.w3.org/2000/svg">
        <polygon points="0,0 50,0 25,40" fill="#123456"/>
        <ellipse cx="10" cy="10" rx="8" ry="4"/>
        <line x1="0" y1="0" x2="20" y2="20" stroke="red"/>
      </svg>''');
      expect(outro.formas.length, 3);
      expect(outro.formas.first.path.vertices.length, 3);
      expect(outro.formas.first.path.closed, isTrue);
      expect(outro.formas.last.path.closed, isFalse, reason: 'linha e aberta');
    });
  });
}
