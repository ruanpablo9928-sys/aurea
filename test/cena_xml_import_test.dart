import 'dart:ui';

import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/shape.dart';
import 'package:aurea/src/features/editor/domain/video_project.dart';
import 'package:aurea/src/features/projects/domain/cena_xml_import.dart';
import 'package:flutter_test/flutter_test.dart';

/// O FORMATO DE VERDADE, em miniatura: uma cena com uma forma de fundo,
/// um texto com keyframes, um grupo (precomp) com um filho, um caminho
/// desenhado, uma camada oculta e um vinculo de pai.
const _cena = '''<?xml version='1.0' encoding='UTF-8' ?>
<scene title="Teste" width="1920" height="1080" bgcolor="#ff101418" totalTime="4000" fps="30">
  <media uri="content://fotos/1" filename="foto.png" type="image/png" />
  <shape id="1" label="Fundo" startTime="0" endTime="4000" fillType="color" s=".rect">
    <transform>
      <location value="960.000000,540.000000,0.000000" />
      <scale value="1.500000,1.500000" />
    </transform>
    <fillColor value="#ff2a2a2a" />
    <property name="size" type="vec2" value="800.000000,600.000000" />
  </shape>
  <text id="2" label="Titulo" startTime="500" endTime="2500" fillType="color"
        size="48.000000" font="googlefonts?name=Roboto&amp;weight=500">
    <transform>
      <location>
        <kf t="0.000000" v="100.000000,200.000000,0.000000" />
        <kf t="1.000000" v="900.000000,200.000000,0.000000" e="cubicBezier 0.25 0.1 0.25 1.0" />
      </location>
      <rotation value="-12.000000" />
    </transform>
    <fillColor value="#ffffcc00" />
    <content>Ola &amp; bem-vindo</content>
    <effect id="com.alightcreative.effects.fade" locallyApplied="true">
      <property name="inTime" type="float" value="0.500000" />
      <property name="outTime" type="float" value="0.000000" />
    </effect>
    <effect id="com.alightcreative.effects.motionblur4" locallyApplied="true" />
  </text>
  <shape id="3" label="Risco" startTime="0" endTime="4000" fillType="color">
    <transform><location value="500.000000,500.000000,0.000000" /></transform>
    <fillColor value="#ff00ff00" />
    <path d="M 0 0 L 100 0 L 100 100 Z" />
  </shape>
  <shape id="4" label="Escondida" hidden="true" startTime="0" endTime="4000" fillType="none" s=".circle">
    <transform><location value="200.000000,200.000000,0.000000" /></transform>
    <path-stroke direction="centered" end-size="4.000000">
      <color value="#ff00aaff" />
      <size value="9.000000" />
    </path-stroke>
    <property name="size" type="vec2" value="120.000000,120.000000" />
  </shape>
  <embedScene id="5" label="Grupo" startTime="1000" endTime="3000" fillType="intrinsic" parent="1">
    <transform>
      <location value="300.000000,700.000000,0.000000" />
      <opacity>
        <kf t="0.000000" v="0.000000" />
        <kf t="0.500000" v="1.000000" e="elastic 0.4 1.0 0.07 0.6" />
      </opacity>
    </transform>
    <scene title="" width="1920" height="1080" totalTime="2000">
      <shape id="6" label="Estrela" startTime="0" endTime="2000" fillType="color" s=".star">
        <transform><location value="100.000000,100.000000,0.000000" /></transform>
        <fillColor value="#ffff0055" />
        <property name="size" type="vec2" value="200.000000,200.000000" />
        <property name="pointCount" type="float" value="6.000000" />
      </shape>
    </scene>
  </embedScene>
</scene>
''';

void main() {
  group('importar cena em XML', () {
    late CenaXmlResult r;
    late VideoProject p;

    setUp(() {
      r = importarCenaXml(_cena, nome: 'Teste');
      p = r.project;
    });

    test('cena: tamanho, fps, fundo e ordem de pintura invertida', () {
      expect(p.outputWidth, 1920);
      expect(p.outputHeight, 1080);
      expect(p.fps, 30);
      expect(p.backgroundColor, const Color(0xFF101418));
      expect(p.duration, greaterThanOrEqualTo(const Duration(seconds: 4)));
      // O primeiro do arquivo (Fundo) e o que fica ATRAS: por aqui, o ultimo.
      expect(p.layers.first.name, 'Grupo');
      expect(p.layers.last.name, 'Fundo');
      expect(r.layersImported, 5);
    });

    test('forma: tamanho, cor, escala e posicao em pixel da composicao', () {
      final fundo = p.layers.firstWhere((l) => l.name == 'Fundo') as ShapeLayer;
      expect(fundo.position.base, const Offset(960, 540));
      expect(fundo.scaleX.base, closeTo(1.5, 1e-6));
      final geo = fundo.contents.whereType<ShapeParametric>().single;
      expect(geo.kind, ParamShapeKind.rect);
      expect(geo.sizeX.base, closeTo(800, 1e-6));
      expect(geo.sizeY.base, closeTo(600, 1e-6));
      expect(
        fundo.contents.whereType<ShapeFill>().single.color,
        const Color(0xFF2A2A2A),
      );
    });

    test('keyframes: t normalizado vira tempo local e a curva anda um', () {
      final titulo = p.layers.firstWhere((l) => l.name == 'Titulo');
      expect(titulo.startTime, const Duration(milliseconds: 500));
      expect(titulo.duration, const Duration(milliseconds: 2000));
      final pos = titulo.position;
      expect(pos.keyframes.length, 2);
      expect(pos.keyframes.first.time, Duration.zero);
      expect(pos.keyframes.last.time, const Duration(milliseconds: 2000));
      expect(pos.keyframes.first.value, const Offset(100, 200));
      expect(pos.keyframes.last.value, const Offset(900, 200));
      // A curva do arquivo descreve a chegada; aqui ela sai do primeiro.
      expect(pos.keyframes.first.ease.type, EasingType.cubicBezier);
      expect(pos.keyframes.first.ease.x1, closeTo(0.25, 1e-6));
      expect(pos.keyframes.last.ease, Easing.linear);
      expect(titulo.rotation.base, closeTo(-12, 1e-6));
      expect(r.keyframesImported, greaterThanOrEqualTo(4));
    });

    test('texto: conteudo, fonte, tamanho e cor', () {
      final t = p.layers.firstWhere((l) => l.name == 'Titulo') as TextLayer;
      expect(t.text, 'Ola & bem-vindo');
      expect(t.fontFamily, 'Roboto');
      expect(t.fontSize, closeTo(48, 1e-6));
      expect(t.color, const Color(0xFFFFCC00));
    });

    test('fade vira keyframes de opacidade; motion blur vira meta', () {
      final t = p.layers.firstWhere((l) => l.name == 'Titulo');
      expect(t.opacity.isAnimated, isTrue);
      expect(t.opacity.valueAt(Duration.zero), closeTo(0, 1e-6));
      expect(
        t.opacity.valueAt(const Duration(milliseconds: 500)),
        closeTo(1, 1e-6),
      );
      expect(p.metaOf(t.id).motionBlur, isTrue);
    });

    test('caminho desenhado entra editavel (bezier)', () {
      final risco = p.layers.firstWhere((l) => l.name == 'Risco') as ShapeLayer;
      final b = risco.contents.whereType<ShapeBezier>().single;
      expect(b.path.valueAt(Duration.zero).vertices.length, greaterThan(2));
    });

    test('camada oculta e traco: olho fechado e contorno com a cor certa', () {
      final e = p.layers.firstWhere((l) => l.name == 'Escondida') as ShapeLayer;
      expect(p.isHidden(e.id), isTrue);
      final stroke = e.contents.whereType<ShapeStroke>().single;
      expect(stroke.color, const Color(0xFF00AAFF));
      expect(stroke.width.base, closeTo(9, 1e-6));
      expect(e.contents.whereType<ShapeFill>(), isEmpty, reason: 'fillType none');
    });

    test('grupo vira precomp com os filhos em tempo local, e o pai vincula', () {
      final g = p.layers.firstWhere((l) => l.name == 'Grupo') as GroupLayer;
      expect(g.startTime, const Duration(seconds: 1));
      expect(g.duration, const Duration(seconds: 2));
      expect(g.sourceDuration, const Duration(seconds: 2));
      expect(g.children.length, 1);
      final estrela = g.children.single as ShapeLayer;
      expect(estrela.startTime, Duration.zero);
      expect(
        estrela.contents.whereType<ShapeParametric>().single.kind,
        ParamShapeKind.star,
      );
      expect(
        estrela.contents.whereType<ShapeParametric>().single.points.base,
        closeTo(6, 1e-6),
      );
      final fundo = p.layers.firstWhere((l) => l.name == 'Fundo');
      expect(p.linkFor(g.id, LayerProp.parent)?.sourceLayerId, fundo.id);
    });

    test('o que nao veio e dito em portugues', () {
      expect(r.ignored, isEmpty, reason: 'esta cena cabe inteira');
      final semCena = importarCenaXml;
      expect(
        () => semCena('<coisa/>'),
        throwsA(isA<CenaXmlException>()),
      );
    });

    test('midia que nao existe aqui e reportada com o nome do arquivo', () {
      final comFoto = importarCenaXml('''
<scene width="1080" height="1080" totalTime="1000" fps="30">
  <media uri="content://fotos/1" filename="foto.png" />
  <shape id="1" label="Foto" startTime="0" endTime="1000" fillType="media"
         fillImage="content://fotos/1" s=".rect">
    <transform><location value="540,540,0" /></transform>
    <property name="size" type="vec2" value="300,300" />
  </shape>
</scene>''');
      expect(comFoto.ignored.single, contains('foto.png'));
      expect(comFoto.project.layers.single, isA<ShapeLayer>());
    });
  });
}
