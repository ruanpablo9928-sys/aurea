// A FONTE DO TEXTO: escolher, importar varias, tirar.
//
// `FontService` tinha a lista, o importador de .ttf, a remocao e o
// aviso de revisao — e o unico chamador em todo o app era o boot
// (`loadAll`). Nenhuma tela listava, importava ou escolhia familia: o
// painel de Texto tinha exatamente tres controles (texto, tamanho,
// negrito), e `editTextLayer` era chamado quatro vezes, nenhuma com
// `fontFamily`. Todo texto do app saia na fonte padrao.
import 'dart:io';

import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/font_service.dart';
import 'package:aurea/src/features/editor/application/playback_controller.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/presentation/widgets/controles_da_camada.dart';
import 'package:aurea/src/features/editor/presentation/widgets/escolha_de_fonte.dart';
import 'package:flutter/material.dart' hide Easing;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Vsync extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

typedef _Bancada = ({ProviderContainer c, String id});

Future<_Bancada> _montar(
  WidgetTester tester, {
  List<String> Function()? escolher,
}) async {
  final container = ProviderContainer(
    overrides: [
      if (escolher != null)
        escolherFontesProvider.overrideWithValue(() async => escolher()),
    ],
  );
  addTearDown(container.dispose);
  final c = container.read(editorControllerProvider.notifier);
  c.addTextLayer(Duration.zero, text: 'Um');
  final camada = container.read(editorControllerProvider).layers.single;
  container.read(selectedLayerProvider.notifier).state = camada.id;

  final playback = PlaybackController(
    vsync: _Vsync(),
    durationOf: () => container.read(editorControllerProvider).duration,
  );
  addTearDown(playback.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) {
              final atual = ref
                  .watch(editorControllerProvider)
                  .layers
                  .where((l) => l.id == camada.id)
                  .firstOrNull;
              if (atual == null) return const SizedBox.shrink();
              return ControlesDaCategoria(
                categoriaId: 'texto',
                camada: atual,
                playback: playback,
                aoVoltar: () {},
              );
            },
          ),
        ),
      ),
    ),
  );
  return (c: container, id: camada.id);
}

TextLayer _texto(ProviderContainer c, String id) =>
    c.read(editorControllerProvider).layers.firstWhere((l) => l.id == id)
        as TextLayer;

Future<void> _tocar(WidgetTester tester, String rotulo) async {
  final alvo = find.bySemanticsLabel(rotulo);
  await tester.ensureVisible(alvo);
  await tester.pump();
  await tester.tap(alvo);
  await tester.pumpAndSettle();
}

void main() {
  group('a linha fechada', () {
    testWidgets('diz qual fonte esta valendo', (tester) async {
      final m = await _montar(tester);
      expect(_texto(m.c, m.id).fontFamily, isNull);
      expect(find.bySemanticsLabel('Fonte: Do aplicativo'), findsOneWidget);
    });

    testWidgets('abre a lista, e a lista volta', (tester) async {
      await _montar(tester);
      await _tocar(tester, 'Fonte: Do aplicativo');
      expect(find.bySemanticsLabel('Fonte do aplicativo'), findsOneWidget);
      expect(find.bySemanticsLabel('Importar fontes'), findsOneWidget);

      await _tocar(tester, 'Voltar ao texto');
      expect(find.bySemanticsLabel('Fonte: Do aplicativo'), findsOneWidget);
    });

    testWidgets('diz a verdade quando a fonte sumiu', (tester) async {
      final m = await _montar(tester);
      // Um projeto vindo de outro aparelho referencia uma familia que
      // nao esta instalada aqui: o texto ja desenha com a do app, e
      // mostrar o nome como se estivesse aplicada seria mentir.
      m.c
          .read(editorControllerProvider.notifier)
          .editTextLayer(m.id, fontFamily: 'Fonte Que Nao Existe');
      await tester.pump();
      expect(
        find.bySemanticsLabel('Fonte: Fonte Que Nao Existe (faltando)'),
        findsOneWidget,
      );
    });
  });

  group('escolher', () {
    testWidgets('a fonte empacotada entra na camada', (tester) async {
      final m = await _montar(tester);
      await _tocar(tester, 'Fonte: Do aplicativo');
      await _tocar(tester, 'Fonte Aurea Motion Sans');

      expect(_texto(m.c, m.id).fontFamily, 'Aurea Motion Sans');
      expect(find.bySemanticsLabel('Fonte Aurea Motion Sans'), findsOneWidget);
    });

    testWidgets('voltar ao padrao LIMPA, e nao passa nulo', (tester) async {
      final m = await _montar(tester);
      await _tocar(tester, 'Fonte: Do aplicativo');
      await _tocar(tester, 'Fonte Aurea Motion Sans');
      expect(_texto(m.c, m.id).fontFamily, isNotNull);

      // `fontFamily: null` nao limpa — nulo quer dizer "nao mexa". Sem
      // `clearFont`, voltar ao padrao seria um toque inerte.
      await _tocar(tester, 'Fonte do aplicativo');
      expect(_texto(m.c, m.id).fontFamily, isNull);
    });

    testWidgets('a empacotada nao oferece remover', (tester) async {
      await _montar(tester);
      await _tocar(tester, 'Fonte: Do aplicativo');
      expect(find.bySemanticsLabel('Tirar Aurea Motion Sans'), findsNothing);
    });
  });

  group('importar', () {
    late Directory pasta;

    setUp(() async {
      pasta = await Directory.systemTemp.createTemp('aurea-fontes-');
      // A PASTA DO APP, mockada: sem isto o servico fica esperando um
      // canal de plataforma que ninguem responde, e o teste trava em
      // "Importando..." sem provar nada.
      TestDefaultBinaryMessengerBinding
          .instance
          .defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => pasta.path,
          );
    });
    tearDown(() async {
      TestDefaultBinaryMessengerBinding
          .instance
          .defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          );
      // O servico e um singleton: sem limpar, a fonte de um teste
      // vazaria para o proximo.
      for (final f in FontService.instance.families) {
        if (!FontService.instance.isBundled(f)) {
          await FontService.instance.remove(f);
        }
      }
      if (pasta.existsSync()) await pasta.delete(recursive: true);
    });

    testWidgets('o botao pede os arquivos ao seletor', (tester) async {
      var pediu = 0;
      await _montar(
        tester,
        escolher: () {
          pediu++;
          return const <String>[];
        },
      );
      await _tocar(tester, 'Fonte: Do aplicativo');
      await _tocar(tester, 'Importar fontes');
      expect(pediu, 1);
    });

    testWidgets('cancelar o seletor nao muda nada', (tester) async {
      final m = await _montar(tester, escolher: () => const []);
      await _tocar(tester, 'Fonte: Do aplicativo');
      await _tocar(tester, 'Importar fontes');

      expect(_texto(m.c, m.id).fontFamily, isNull);
      expect(find.textContaining('importada'), findsNothing);
    });

    testWidgets('duas fontes de verdade entram na lista de uma vez', (
      tester,
    ) async {
      final m = await _montar(tester);
      await _tocar(tester, 'Fonte: Do aplicativo');
      expect(find.bySemanticsLabel('Fonte Bandeira'), findsNothing);

      // O import de verdade le, copia e registra o arquivo — trabalho
      // de disco, que so acontece em `runAsync`. O que se cobra aqui e
      // o caminho inteiro: varias de uma vez, e a lista se refazendo
      // sozinha pela revisao do servico.
      late final ({List<String> imported, int failed}) r;
      await tester.runAsync(() async {
        final fonte = File(
          'assets/templates/dnyx/AureaMotionSans.ttf',
        ).readAsBytesSync();
        File('${pasta.path}/Bandeira.ttf').writeAsBytesSync(fonte);
        File('${pasta.path}/Estandarte.ttf').writeAsBytesSync(fonte);
        File('${pasta.path}/nao-e-fonte.ttf')
            .writeAsStringSync('isto nao e uma fonte');
        r = await FontService.instance.importMany([
          '${pasta.path}/Bandeira.ttf',
          '${pasta.path}/Estandarte.ttf',
          '${pasta.path}/nao-e-fonte.ttf',
        ]);
      });
      await tester.pumpAndSettle();

      // UM ARQUIVO QUEBRADO NAO DESCARTA O RESTO DA ESCOLHA.
      expect(r.imported, ['Bandeira', 'Estandarte']);
      expect(r.failed, 1);
      expect(find.bySemanticsLabel('Fonte Bandeira'), findsOneWidget);
      expect(find.bySemanticsLabel('Fonte Estandarte'), findsOneWidget);

      await _tocar(tester, 'Fonte Bandeira');
      expect(_texto(m.c, m.id).fontFamily, 'Bandeira');
    });

    testWidgets('tirar a fonte em uso devolve a camada ao padrao', (
      tester,
    ) async {
      final m = await _montar(tester);
      await _tocar(tester, 'Fonte: Do aplicativo');
      await tester.runAsync(() async {
        File('${pasta.path}/Bandeira.ttf').writeAsBytesSync(
          File('assets/templates/dnyx/AureaMotionSans.ttf').readAsBytesSync(),
        );
        await FontService.instance.import('${pasta.path}/Bandeira.ttf');
      });
      await tester.pumpAndSettle();
      await _tocar(tester, 'Fonte Bandeira');
      expect(_texto(m.c, m.id).fontFamily, 'Bandeira');

      await tester.runAsync(() async {
        await FontService.instance.remove('Bandeira');
      });
      await tester.pumpAndSettle();
      // A camada nao pode ficar apontando para o que sumiu: o desenho
      // ja caiu na fonte do app, e o rotulo diria "(faltando)" para
      // sempre.
      expect(find.bySemanticsLabel('Fonte Bandeira'), findsNothing);
    });

    testWidgets('o filtro so aparece quando a lista fica grande', (
      tester,
    ) async {
      await _montar(tester);
      await _tocar(tester, 'Fonte: Do aplicativo');
      expect(find.bySemanticsLabel('Filtrar fontes'), findsNothing);

      for (var i = 0; i < 12; i++) {
        FontService.instance.registrarSemArquivo('Familia $i');
      }
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Filtrar fontes'), findsOneWidget);
    });
  });
}
