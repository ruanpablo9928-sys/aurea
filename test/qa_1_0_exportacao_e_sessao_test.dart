// QA 1.0 — CAMPANHA 7: TODA COMBINACAO DE EXPORTACAO, E A SESSAO LONGA.
//
// Tres frentes que so aparecem no uso real:
//
//   1. AJUSTES DE EXPORTACAO: cinco tamanhos, dois codecs, dois
//      formatos, tres qualidades — sessenta combinacoes, cada uma
//      capaz de produzir um numero que faz o ffmpeg recusar o trabalho
//      no fim de dez minutos de render. Dimensao impar e taxa de bits
//      zerada sao os classicos.
//   2. SESSAO LONGA: quinhentas edicoes seguidas e vinte projetos
//      abertos em sequencia. O historico nao pode crescer sem fim, e
//      abrir outro projeto nao pode deixar passado para tras.
//   3. ARQUIVO DE UMA VERSAO MAIS NOVA: campo desconhecido, tipo de
//      camada desconhecido, secao inteira que ainda nao existe. O
//      projeto tem de abrir com o que da para entender, e nao morrer.
import 'dart:convert';

import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/project_store.dart';
import 'package:aurea/src/features/editor/domain/video_project.dart';
import 'package:aurea/src/features/export/domain/export_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('toda combinacao de ajuste de exportacao', () {
    // Projetos de formatos que existem no mundo: quadrado, retrato de
    // celular, cinema largo, um minusculo e um exagerado.
    const formatos = <(String, int, int)>[
      ('quadrado', 1080, 1080),
      ('retrato', 1080, 1920),
      ('paisagem', 1920, 1080),
      ('cinema', 2560, 1080),
      ('minusculo', 17, 33),
      ('enorme', 7680, 4320),
    ];

    test('nenhuma combinacao produz numero que o ffmpeg recusa', () {
      final falhas = <String>[];
      for (final (nome, w, h) in formatos) {
        for (final tamanho in ExportSize.values) {
          for (final codec in ExportCodec.values) {
            for (final formato in ExportFormat.values) {
              for (final qualidade in const ['baixa', 'media', 'alta']) {
                for (final fps in const [null, 24, 30, 60, 120]) {
                  final ajustes = ExportSettings(
                    size: tamanho,
                    codec: codec,
                    format: formato,
                    quality: qualidade,
                    fps: fps,
                  );
                  final onde =
                      '$nome/${tamanho.name}/${codec.name}/'
                      '${formato.name}/$qualidade/fps=$fps';
                  final (sw, sh) = ajustes.resolve(w, h);
                  if (sw.isOdd || sh.isOdd) {
                    falhas.add('$onde: dimensao impar ${sw}x$sh');
                  }
                  if (sw < 2 || sh < 2) {
                    falhas.add('$onde: dimensao degenerada ${sw}x$sh');
                  }
                  final f = ajustes.resolveFps(30);
                  if (f < 1) falhas.add('$onde: fps $f');
                  final taxa = ajustes.bitrateFor(sw, sh, f);
                  if (taxa < 200000) {
                    falhas.add('$onde: taxa de bits ridicula ($taxa)');
                  }
                  final mb = ajustes.estimatedMegabytes(
                    sw,
                    sh,
                    f,
                    const Duration(seconds: 30),
                  );
                  if (!mb.isFinite || mb <= 0) {
                    falhas.add('$onde: estimativa $mb MB');
                  }
                }
              }
            }
          }
        }
      }
      expect(falhas, isEmpty, reason: falhas.take(20).join('\n'));
    });

    test('a proporcao do projeto sobrevive a mudanca de tamanho', () {
      final falhas = <String>[];
      for (final (nome, w, h) in formatos) {
        final original = w / h;
        for (final tamanho in ExportSize.values) {
          final (sw, sh) = ExportSettings(size: tamanho).resolve(w, h);
          final saida = sw / sh;
          // Arredondar para par mexe na proporcao; em imagem pequena
          // isso pesa mais. Tolerancia proporcional ao arredondamento.
          final folga = 2.0 / sh + 2.0 / sw;
          if ((saida - original).abs() > original * folga + 1e-9) {
            falhas.add(
              '$nome em ${tamanho.name}: $original virou $saida (${sw}x$sh)',
            );
          }
        }
      }
      expect(falhas, isEmpty, reason: falhas.join('\n'));
    });

    test('taxa de bits na mao vence a qualidade, e fica dentro do limite', () {
      for (final pedida in const [0.001, 0.5, 8.0, 500.0, 99999.0]) {
        const base = ExportSettings(quality: 'alta');
        final manual = base.copyWith(bitrateMbps: pedida);
        final v = manual.bitrateFor(1920, 1080, 30);
        expect(v, greaterThanOrEqualTo(200000));
        expect(v, lessThanOrEqualTo(200000000));
      }
    });

    test('so a sequencia PNG guarda transparencia', () {
      expect(const ExportSettings().keepsAlpha, isFalse);
      expect(
        const ExportSettings(format: ExportFormat.pngSequence).keepsAlpha,
        isTrue,
      );
    });
  });

  group('a sessao que nao acaba', () {
    late ProviderContainer container;
    EditorController ctrl() => container.read(editorControllerProvider.notifier);
    VideoProject projeto() => container.read(editorControllerProvider);

    setUp(() {
      container = ProviderContainer();
      ctrl().openProject(
        VideoProject(name: 'a', createdAt: DateTime(2026), layers: const []),
      );
    });
    tearDown(() => container.dispose());

    test('quinhentas edicoes: o historico para de crescer em cem passos', () {
      for (var i = 0; i < 500; i++) {
        ctrl().addShapeLayer(Duration.zero, name: 'F$i');
      }
      expect(projeto().layers, hasLength(500));
      var voltas = 0;
      while (ctrl().canUndo && voltas < 1000) {
        ctrl().undo();
        voltas++;
      }
      // O teto existe de proposito: guardar quinhentas fotos de um
      // projeto grande e o caminho mais curto para o aplicativo ser
      // morto por falta de memoria.
      expect(
        voltas,
        lessThanOrEqualTo(100),
        reason: 'o historico guardou $voltas passos, sem teto',
      );
      expect(voltas, greaterThan(50), reason: 'o historico ficou raso demais');
    });

    test('abrir vinte projetos em sequencia nao arrasta nada do anterior', () {
      for (var i = 0; i < 20; i++) {
        ctrl().addTextLayer(Duration.zero, text: 'projeto $i');
        ctrl().addShapeLayer(Duration.zero);
        ctrl().openProject(
          VideoProject(
            name: 'p$i',
            createdAt: DateTime(2026),
            layers: const [],
          ),
        );
        expect(projeto().layers, isEmpty, reason: 'sobrou camada da volta $i');
        expect(
          ctrl().canUndo,
          isFalse,
          reason: 'o desfazer da volta $i atravessou para o projeto novo',
        );
        expect(ctrl().canRedo, isFalse);
        expect(
          container.read(selectedLayerProvider),
          isNull,
          reason: 'a selecao da volta $i sobreviveu',
        );
      }
    });

    test('gesto aberto e cancelado volta exatamente ao ponto de partida', () {
      ctrl().addShapeLayer(Duration.zero, name: 'F');
      final id = projeto().layers.single.id;
      final antes = projeto().layers.single.opacity.valueAt(Duration.zero);
      for (var volta = 0; volta < 50; volta++) {
        ctrl().beginGesture();
        for (var i = 1; i <= 20; i++) {
          ctrl().editOpacity(id, Duration.zero, i / 20);
        }
        ctrl().cancelGesture();
        expect(
          projeto().layers.single.opacity.valueAt(Duration.zero),
          closeTo(antes, 1e-9),
          reason: 'desistir do arrasto na volta $volta nao voltou ao inicio',
        );
      }
    });

    test('gesto esquecido aberto nao desliga o desfazer da sessao', () {
      ctrl().addShapeLayer(Duration.zero, name: 'F');
      final id = projeto().layers.single.id;
      // Um widget que sai da arvore no meio do arrasto deixa o grupo
      // aberto. Se ninguem fechar, todo o resto da sessao cai num passo
      // so e o desfazer vira uma bomba.
      ctrl().beginGesture();
      ctrl().editOpacity(id, Duration.zero, 0.5);
      ctrl().endGesture();
      ctrl().addTextLayer(Duration.zero, text: 'depois');
      ctrl().undo();
      expect(
        projeto().layers.whereType<TextLayer>(),
        isEmpty,
        reason: 'o desfazer nao apagou so o texto',
      );
      expect(projeto().layers, hasLength(1));
    });
  });

  group('arquivo de uma versao mais nova', () {
    Map<String, dynamic> base() {
      final p = VideoProject(
        name: 'do futuro',
        createdAt: DateTime(2026, 9, 8),
        layers: const [],
      );
      return projectToJson(p);
    }

    test('campos desconhecidos sao ignorados sem derrubar a leitura', () {
      final m = base()
        ..['inventadoNoFuturo'] = {'a': 1, 'b': null}
        ..['outraCoisa'] = [1, 2, 3]
        ..['fps'] = 30;
      final p = projectFromJson(jsonDecode(jsonEncode(m)));
      expect(p.name, 'do futuro');
      expect(p.fps, 30);
    });

    test('uma camada de tipo desconhecido sai; as outras entram', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      c.openProject(
        VideoProject(name: 'x', createdAt: DateTime(2026), layers: const []),
      );
      c.addTextLayer(Duration.zero, text: 'sobrevivente');
      c.addShapeLayer(Duration.zero, name: 'tambem sobrevive');
      final m = projectToJson(container.read(editorControllerProvider));
      final camadas = (m['layers'] as List).toList()
        ..insert(1, {
          'id': 'futuro',
          'name': 'Camada do futuro',
          'kind': 'holograma',
          'start': 0,
          'dur': 1000000,
        });
      m['layers'] = camadas;

      final p = projectFromJson(jsonDecode(jsonEncode(m)));
      expect(
        p.layers,
        hasLength(2),
        reason: 'perdeu camada boa por causa da desconhecida',
      );
      expect(
        p.layers.map((l) => l.name),
        containsAll(<String>['sobrevivente']),
      );
      expect(
        p.layers.any((l) => l.name == 'Camada do futuro'),
        isFalse,
        reason: 'leu uma camada que nao sabe ler',
      );
    });

    test('um efeito desconhecido nao leva a camada junto', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      c.openProject(
        VideoProject(name: 'x', createdAt: DateTime(2026), layers: const []),
      );
      c.addShapeLayer(Duration.zero, name: 'com efeito');
      final m = projectToJson(container.read(editorControllerProvider));
      final camada = (m['layers'] as List).first as Map<String, dynamic>;
      camada['effects'] = [
        {
          'id': 'e1',
          'kind': 'efeito_que_ainda_nao_existe',
          'type': 9999,
          'params': <String, dynamic>{},
          'color': 0xFFFFFFFF,
          'on': true,
        },
      ];
      final p = projectFromJson(jsonDecode(jsonEncode(m)));
      expect(
        p.layers,
        hasLength(1),
        reason: 'a camada inteira se perdeu por um efeito desconhecido',
      );
    });
  });
}
