// QA 1.0 — CAMPANHA 2: ENTRADA HOSTIL. O app nao pode quebrar.
//
// Aqui a intencao e outra: em vez de conferir que o certo funciona,
// entregar o ERRADO de proposito e exigir que o aplicativo continue de
// pe. Arquivo de projeto truncado, campo com o tipo errado, expressao
// com erro de sintaxe, divisao por zero, texto vazio, texto gigante,
// duracao zero, valores absurdos, midia que nao existe mais.
//
// A regra: nada aqui pode lancar excecao para fora. Perder um pedaco do
// projeto estragado e aceitavel; derrubar o aplicativo de quem abriu o
// arquivo, nao.
import 'dart:convert';

import 'package:aurea/src/features/editor/domain/caption.dart';
import 'package:aurea/src/features/editor/domain/effect.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/project_store.dart';
import 'package:aurea/src/features/editor/domain/video_project.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('arquivo de projeto estragado', () {
    test('JSON vazio, sem camadas ou com lixo no lugar delas', () {
      final casos = <String, Map<String, dynamic>>{
        'vazio': <String, dynamic>{},
        'so o nome': {'name': 'x'},
        'camadas nulas': {'name': 'x', 'layers': null},
        'camadas com texto no lugar de mapa': {
          'name': 'x',
          'layers': ['isto nao e uma camada', 42, null],
        },
        'camada sem tipo': {
          'name': 'x',
          'layers': [
            {'id': 'a', 'name': 'sem tipo'},
          ],
        },
        'camada de tipo inventado': {
          'name': 'x',
          'layers': [
            {'id': 'a', 'type': 'hologramaQuantico', 'name': 'nova'},
          ],
        },
        'numeros como texto': {
          'name': 'x',
          'fps': 'trinta',
          'aspectRatio': 'largo',
          'resolutionHeight': [1080],
          'layers': const [],
        },
        'duracao negativa': {
          'name': 'x',
          'layers': [
            {
              'id': 'a',
              'type': 'shape',
              'name': 'f',
              'startTime': -5000000,
              'duration': -1000000,
            },
          ],
        },
      };
      final falhas = <String>[];
      casos.forEach((nome, json) {
        try {
          final p = projectFromJson(json);
          // Um projeto lido tem de ser utilizavel: nome, fps e duracao
          // fazem sentido mesmo vindo de lixo.
          if (p.fps <= 0) falhas.add('$nome: fps invalido (${p.fps})');
          if (p.aspectRatio <= 0) {
            falhas.add('$nome: proporcao invalida (${p.aspectRatio})');
          }
          if (p.resolutionHeight <= 0) {
            falhas.add('$nome: altura invalida (${p.resolutionHeight})');
          }
          for (final l in p.layers) {
            if (l.duration.isNegative) {
              falhas.add('$nome: camada com duracao negativa');
            }
          }
          // E tem de poder ser salvo de novo, sem explodir.
          jsonEncode(projectToJson(p));
        } catch (e) {
          falhas.add('$nome: EXPLODIU ($e)');
        }
      });
      expect(falhas, isEmpty, reason: falhas.join('\n'));
    });

    test('JSON truncado no meio nao derruba quem abre', () {
      final inteiro = jsonEncode(
        projectToJson(
          VideoProject(
            name: 'grande',
            createdAt: DateTime(2026),
            layers: [
              for (var i = 0; i < 10; i++)
                ShapeLayer(
                  id: 's$i',
                  name: 'F$i',
                  startTime: Duration.zero,
                  duration: const Duration(seconds: 3),
                ),
            ],
          ),
        ),
      );
      final falhas = <String>[];
      // Um arquivo cortado no meio (bateria acabou durante a gravacao)
      // tem de dar erro de leitura — e nao crash em outro lugar.
      for (final corte in [0.25, 0.5, 0.75, 0.99]) {
        final pedaco = inteiro.substring(0, (inteiro.length * corte).floor());
        try {
          jsonDecode(pedaco);
          falhas.add('corte $corte: o pedaco decodificou (nao deveria)');
        } on FormatException {
          // certo: erro de formato, tratavel por quem le o arquivo.
        } catch (e) {
          falhas.add('corte $corte: erro inesperado ($e)');
        }
      }
      expect(falhas, isEmpty, reason: falhas.join('\n'));
    });
  });

  group('expressoes erradas de proposito', () {
    test('sintaxe quebrada, variavel inventada e divisao por zero', () {
      final expressoes = <String>[
        'valor +',
        '((',
        'naoExiste * 2',
        '1 / 0',
        '0 / 0',
        'time / (time - time)',
        'valor * "texto"',
        r'$$$',
        'while(true){}',
        'valor' * 500,
        '',
        '   ',
      ];
      final falhas = <String>[];
      for (final fonte in expressoes) {
        try {
          final v = AnimatedDouble(10, null, LoopSpec.none, fonte);
          final r = v.valueAt(const Duration(seconds: 1));
          if (r.isNaN || r.isInfinite) {
            falhas.add('"$fonte": devolveu $r (nao pode virar NaN/infinito)');
          }
        } catch (e) {
          falhas.add('"$fonte": EXPLODIU ($e)');
        }
      }
      expect(falhas, isEmpty, reason: falhas.join('\n'));
    });

    test('uma expressao quebrada nao contamina a gravacao do projeto', () {
      final p = VideoProject(
        name: 'x',
        createdAt: DateTime(2026),
        layers: [
          ShapeLayer(
            id: 'f',
            name: 'F',
            startTime: Duration.zero,
            duration: const Duration(seconds: 2),
            rotation: AnimatedDouble(0, null, LoopSpec.none, 'valor +'),
          ),
        ],
      );
      final volta = projectFromJson(projectToJson(p));
      expect(volta.layers.single.rotation.expression, 'valor +');
      expect(volta.layers.single.rotation.valueAt(Duration.zero), isA<double>());
    });
  });

  group('valores extremos', () {
    test('opacidade, escala e rotacao fora de qualquer faixa razoavel', () {
      final falhas = <String>[];
      final extremos = <String, double>{
        'zero': 0,
        'negativo': -1000,
        'gigante': 1e9,
        'minusculo': 1e-9,
        'infinito': double.infinity,
        'menos infinito': double.negativeInfinity,
        'NaN': double.nan,
      };
      extremos.forEach((nome, valor) {
        try {
          final camada = ShapeLayer(
            id: 'f',
            name: 'F',
            startTime: Duration.zero,
            duration: const Duration(seconds: 2),
            opacity: AnimatedDouble(valor),
            scaleX: AnimatedDouble(valor),
            scaleY: AnimatedDouble(valor),
            rotation: AnimatedDouble(valor),
          );
          final volta = projectFromJson(
            projectToJson(
              VideoProject(
                name: 'x',
                createdAt: DateTime(2026),
                layers: [camada],
              ),
            ),
          );
          // O que nao pode: o arquivo virar invalido. NaN e infinito nao
          // existem em JSON — se eles vazarem, o projeto nao abre mais.
          final texto = jsonEncode(projectToJson(volta));
          if (texto.contains('NaN') || texto.contains('Infinity')) {
            falhas.add('$nome: gravou NaN/Infinity no arquivo');
          }
        } catch (e) {
          falhas.add('$nome: EXPLODIU ($e)');
        }
      });
      expect(falhas, isEmpty, reason: falhas.join('\n'));
    });

    test('texto vazio, gigante, com emoji e com acento', () {
      final textos = <String, String>{
        'vazio': '',
        'so espacos': '     ',
        'gigante': 'A' * 20000,
        'emoji': '🎬🔥✨👨‍👩‍👧‍👦🏳️‍🌈',
        'acentos': 'Ação, coração, à noite — não é?',
        'quebras': 'linha1\nlinha2\n\n\nlinha5',
        'controle': 'a bc',
        'rtl': 'مرحبا بالعالم',
      };
      final falhas = <String>[];
      textos.forEach((nome, texto) {
        try {
          final p = VideoProject(
            name: 'x',
            createdAt: DateTime(2026),
            layers: [
              TextLayer(
                id: 't',
                name: 'T',
                text: texto,
                startTime: Duration.zero,
                duration: const Duration(seconds: 3),
              ),
            ],
          );
          final volta = projectFromJson(projectToJson(p));
          final lido = (volta.layers.single as TextLayer).text;
          if (lido != texto) {
            falhas.add('$nome: o texto mudou na ida e volta');
          }
        } catch (e) {
          falhas.add('$nome: EXPLODIU ($e)');
        }
      });
      expect(falhas, isEmpty, reason: falhas.join('\n'));
    });

    test('duracao zero e keyframes no mesmo instante', () {
      // Duas coisas que quebram interpolacao: um clipe de duracao zero
      // (divisao pelo comprimento) e dois keyframes no mesmo tempo.
      final valor = AnimatedDouble(0)
          .withKeyframe(Duration.zero, 0)
          .withKeyframe(Duration.zero, 100)
          .withKeyframe(const Duration(seconds: 1), 50);
      expect(() => valor.valueAt(Duration.zero), returnsNormally);
      expect(valor.valueAt(Duration.zero).isFinite, isTrue);

      final camada = ShapeLayer(
        id: 'f',
        name: 'F',
        startTime: Duration.zero,
        duration: Duration.zero,
        rotation: valor,
      );
      expect(() => camada.localTime(const Duration(seconds: 1)), returnsNormally);
      expect(camada.activeAt(Duration.zero), isA<bool>());
    });
  });

  group('midia que nao existe mais', () {
    test('video, audio e imagem apontando para arquivo apagado', () {
      final falhas = <String>[];
      final camadas = <String, Layer>{
        'video': VideoLayer(
          id: 'v',
          name: 'V',
          startTime: Duration.zero,
          duration: const Duration(seconds: 5),
          sourcePath: '/nao/existe/video.mp4',
        ),
        'audio': AudioLayer(
          id: 'a',
          name: 'A',
          startTime: Duration.zero,
          duration: const Duration(seconds: 5),
          sourcePath: '/nao/existe/som.m4a',
        ),
        'imagem': ImageLayer(
          id: 'i',
          name: 'I',
          startTime: Duration.zero,
          duration: const Duration(seconds: 5),
          sourcePath: '/nao/existe/foto.png',
        ),
      };
      camadas.forEach((nome, camada) {
        try {
          final volta = projectFromJson(
            projectToJson(
              VideoProject(
                name: 'x',
                createdAt: DateTime(2026),
                layers: [camada],
              ),
            ),
          );
          if (volta.layers.length != 1) {
            falhas.add('$nome: a camada sumiu (o trabalho seria perdido)');
          }
        } catch (e) {
          falhas.add('$nome: EXPLODIU ($e)');
        }
      });
      expect(falhas, isEmpty, reason: falhas.join('\n'));
    });
  });

  group('legendas e efeitos em situacao ruim', () {
    test('SRT quebrado nao derruba a importacao', () {
      final entradas = <String>[
        '',
        'isto nao e um SRT',
        '1\n00:00:00,000 --> 00:00:02,000',
        '1\nsem tempos\ntexto',
        '1\n00:00:05,000 --> 00:00:01,000\ninvertido',
        '99999\n99:99:99,999 --> 99:99:99,999\nabsurdo',
      ];
      final falhas = <String>[];
      for (final srt in entradas) {
        try {
          final cues = parseSrt(srt);
          for (final c in cues) {
            if (c.end < c.start) {
              falhas.add('"${srt.split('\n').first}": cue invertido passou');
            }
          }
        } catch (e) {
          falhas.add('"${srt.split('\n').first}": EXPLODIU ($e)');
        }
      }
      expect(falhas, isEmpty, reason: falhas.join('\n'));
    });

    test('cinco efeitos empilhados na mesma camada', () {
      // O teste "extreme" da missao: efeitos combinados nao podem
      // quebrar a gravacao nem a leitura.
      final efeitos = [
        for (final t in [
          EffectType.gaussianBlur,
          EffectType.lightGlow,
          EffectType.tint,
          EffectType.glitch,
          EffectType.rgbSplit,
        ])
          EffectInstance(type: t),
      ];
      final p = VideoProject(
        name: 'x',
        createdAt: DateTime(2026),
        layers: [
          ShapeLayer(
            id: 'f',
            name: 'F',
            startTime: Duration.zero,
            duration: const Duration(seconds: 4),
            effects: efeitos,
            position: AnimatedOffset(const Offset(100, 100)),
          ),
        ],
      );
      final volta = projectFromJson(projectToJson(p));
      expect(volta.layers.single.effects, hasLength(5));
      expect(
        volta.layers.single.effects.map((e) => e.type),
        efeitos.map((e) => e.type),
        reason: 'a ordem da pilha muda o resultado na tela',
      );
    });
  });
}
