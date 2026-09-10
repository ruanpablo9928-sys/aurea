// ENTREGA 2A: A ESTRUTURA DO PAINEL, SO LEITURA.
//
// A condicao para avancar para a 2B e uma so, e e severa: abrir,
// navegar e fechar o painel NAO pode alterar conteudo, historico nem o
// resultado renderizado. A maior parte deste arquivo existe para provar
// isso — e o resto, para provar que a linha do tempo continua inteira.
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/application/playback_controller.dart';
import 'package:aurea/src/features/editor/presentation/widgets/seletor_de_insercao.dart';
import 'package:aurea/src/features/editor/presentation/widgets/linha_do_tempo.dart';
import 'package:aurea/src/features/editor/presentation/widgets/painel_da_camada.dart';
import 'package:aurea/src/features/editor/presentation/widgets/visao_geral_das_camadas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Vsync extends TickerProvider {
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}

Future<({ProviderContainer c, PlaybackController p})> _montar(
  WidgetTester tester, {
  int textos = 1,
  bool comVideo = false,
  bool selecionar = true,
  bool telaDeCelular = false,
}) async {
  // O SELETOR DE INSERCAO OCUPA 300 px DE ALTURA. Na tela padrao de
  // teste (800 x 600) o corpo dele cai fora do alcance do dedo; os
  // testes que mexem NELE pedem a tela de um celular de verdade.
  if (telaDeCelular) {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }
  final container = ProviderContainer();
  addTearDown(container.dispose);
  final c = container.read(editorControllerProvider.notifier);
  for (var i = 0; i < textos; i++) {
    c.addTextLayer(Duration(seconds: i), text: 'Camada ${i + 1}');
  }
  if (comVideo) c.addShapeLayer(Duration.zero);
  final camadas = container.read(editorControllerProvider).layers;
  container.read(selectedLayerProvider.notifier).state =
      selecionar && camadas.isNotEmpty ? camadas.first.id : null;
  // A LINHA DO TEMPO ABRE NA PILHA. Estes testes cobram o modo
  // DETALHADO, entao ele e escolhido de proposito.
  container.read(modoDaLinhaDoTempoProvider.notifier).state =
      ModoDaLinhaDoTempo.detalhado;

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
          // A TELA MONTA AS DUAS PECAS: a faixa no rodape e o painel
          // sobreposto por cima dela. O espaco do painel e RESERVADO no
          // arranjo, e nao tomado da linha do tempo — por isso o Column
          // guarda a altura maxima dele.
          body: Stack(
            children: [
              Column(
                children: [
                  // O ALTERNADOR DE VISTA vive no cabecalho da tela: o
                  // transporte tem exatamente os sete alvos da
                  // referencia, e um oitavo tiraria o play do centro.
                  const AlternadorDeVista(),
                  const Spacer(),
                  LinhaDoTempo(playback: playback),
                  const SizedBox(height: PainelDaCamada.alturaMaxima),
                ],
              ),
              PainelSobreposto(playback: playback),
              // O SELETOR DE INSERCAO MONTADO COMO A TELA MONTA: com o
              // instante OBSERVADO e o mesmo fecho. Passar uma copia do
              // instante testaria um arranjo que nao existe.
              Consumer(
                builder: (context, ref, _) => SeletorDeInsercao(
                  instanteDeInsercao: ref.watch(instanteDeInsercaoProvider),
                  playback: playback,
                  aoInserir: () {
                    fecharSeletor(ref);
                    abrirFerramentasDaCamada(ref);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return (c: container, p: playback);
}

/// ABRE AS FERRAMENTAS PELO GESTO DE VERDADE.
///
/// A faixa "Ferramentas da camada" do rodape foi removida — ela
/// reservava 52 px de altura o tempo todo. Quem abre hoje e um toque na
/// camada JA selecionada, na pilha; e por isso este ajudante troca de
/// vista antes de tocar.
Future<void> abrirFerramentas(
  WidgetTester tester,
  ProviderContainer c,
) async {
  c.read(modoDaLinhaDoTempoProvider.notifier).state = ModoDaLinhaDoTempo.geral;
  await tester.pump();
  final id = c.read(selectedLayerProvider);
  final camada = c
      .read(editorControllerProvider)
      .layers
      .firstWhere((l) => l.id == id);
  await tester.tap(find.bySemanticsLabel(camada.name));
  await tester.pump();
}

void main() {
  group('o rodape ficou com a linha do tempo', () {
    testWidgets('nao ha faixa "Ferramentas da camada" nenhuma', (
      tester,
    ) async {
      final m = await _montar(tester);
      expect(m.c.read(estadoDoPainelProvider), EstadoDoPainel.recolhido);
      expect(
        find.bySemanticsLabel('Ferramentas da camada'),
        findsNothing,
        reason:
            'a faixa reservava 52 px de altura o tempo todo para oferecer '
            'um caminho que o toque na propria camada ja oferece',
      );
    });

    testWidgets('o + redondo esta la, com ou sem selecao', (tester) async {
      await _montar(tester, selecionar: false);
      expect(
        find.bySemanticsLabel('Adicionar conteudo'),
        findsOneWidget,
        reason:
            'o + nao pode aparecer e sumir conforme a selecao: o layout '
            'mudaria debaixo da mao de quem esta usando',
      );
    });

    testWidgets('o + continua no projeto vazio: e por onde se comeca', (
      tester,
    ) async {
      await _montar(tester, textos: 0);
      expect(find.bySemanticsLabel('Adicionar conteudo'), findsOneWidget);
    });
  });

  group('abrir as ferramentas', () {
    testWidgets('um toque escolhe E abre', (tester) async {
      final m = await _montar(tester, textos: 2);
      m.c.read(modoDaLinhaDoTempoProvider.notifier).state =
          ModoDaLinhaDoTempo.geral;
      m.c.read(selectedLayerProvider.notifier).state = null;
      await tester.pump();

      final camadas = m.c.read(editorControllerProvider).layers;
      final alvo = camadas.first;
      // O CONTRATO DO AM (V 00:40): selecionar e entrar sao o mesmo
      // gesto. Eram dois toques, e o primeiro nao mudava nada na tela.
      await tester.tap(find.bySemanticsLabel(alvo.name));
      await tester.pump();
      expect(m.c.read(selectedLayerProvider), alvo.id);
      expect(m.c.read(estadoDoPainelProvider), EstadoDoPainel.categorias);
    });
  });

  group('navegacao', () {
    testWidgets('abrir mostra as categorias da camada', (tester) async {
      final m = await _montar(tester);
      await abrirFerramentas(tester, m.c);
      expect(m.c.read(estadoDoPainelProvider), EstadoDoPainel.categorias);
      expect(find.byKey(const ValueKey('cartao-opacidade')), findsOneWidget);
      expect(find.byKey(const ValueKey('cartao-transformar')), findsOneWidget);
    });

    testWidgets('entrar numa categoria e voltar', (tester) async {
      final m = await _montar(tester);
      await abrirFerramentas(tester, m.c);

      await tester.tap(find.byKey(const ValueKey('cartao-opacidade')));
      await tester.pump();
      expect(m.c.read(estadoDoPainelProvider), EstadoDoPainel.categoria);
      expect(m.c.read(categoriaAbertaProvider), 'opacidade');
      // O VOLTAR MUDOU DE LUGAR: saiu do cabecalho do painel, que virou
      // repeticao quando a barra da TELA passou a ser tomada pela
      // ferramenta aberta, e foi para o rail esquerdo.
      expect(
        find.bySemanticsLabel('Voltar as ferramentas'),
        findsOneWidget,
      );

      await tester.tap(find.bySemanticsLabel('Voltar as ferramentas'));
      await tester.pump();
      expect(m.c.read(estadoDoPainelProvider), EstadoDoPainel.categorias);
      expect(m.c.read(categoriaAbertaProvider), isNull);
    });

    testWidgets('recolher mantem a selecao e o tempo', (tester) async {
      final m = await _montar(tester);
      final id = m.c.read(selectedLayerProvider);
      m.p.seek(const Duration(milliseconds: 900));
      await tester.pump();
      final tempo = m.p.time.value;

      await abrirFerramentas(tester, m.c);
      await tester.tap(find.bySemanticsLabel('Recolher painel'));
      await tester.pump();

      expect(m.c.read(estadoDoPainelProvider), EstadoDoPainel.recolhido);
      expect(
        m.c.read(selectedLayerProvider),
        id,
        reason: 'fechar uma gaveta nao desfaz o que se escolheu',
      );
      expect(m.p.time.value, tempo);
    });

    testWidgets('o painel aberto SOBREPOE, e nao empurra a linha do tempo', (
      tester,
    ) async {
      final m = await _montar(tester);
      final antes = tester.getRect(find.byType(LinhaDoTempo));
      await abrirFerramentas(tester, m.c);
      expect(find.byType(PainelSobreposto), findsOneWidget);
      expect(
        tester.getRect(find.byType(LinhaDoTempo)),
        antes,
        reason:
            'abrir o painel nao pode mexer na linha do tempo: ele sobe '
            'POR CIMA, e nao empurrando a tela',
      );
    });
  });

  group('as ferramentas vem da capacidade real', () {
    testWidgets('texto ganha o cartao de Texto; forma ganha o de Forma', (
      tester,
    ) async {
      final m = await _montar(tester, comVideo: true);
      // A ORDEM DA PILHA E DO MOTOR: camada nova entra no topo. O teste
      // escolhe por TIPO, e nao por posicao, senao ele testa a ordem em
      // vez de testar o painel.
      final camadas = m.c.read(editorControllerProvider).layers;
      final texto = camadas.whereType<TextLayer>().first;
      final forma = camadas.whereType<ShapeLayer>().first;

      m.c.read(selectedLayerProvider.notifier).state = texto.id;
      await tester.pump();
      await abrirFerramentas(tester, m.c);
      expect(find.byKey(const ValueKey('cartao-texto')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('cartao-forma')),
        findsNothing,
        reason: 'camada de texto nao tem editor de forma',
      );

      m.c.read(selectedLayerProvider.notifier).state = forma.id;
      await tester.pump();
      expect(find.byKey(const ValueKey('cartao-forma')), findsOneWidget);
      expect(find.byKey(const ValueKey('cartao-texto')), findsNothing);
    });

    testWidgets('o cartao de som e de quem tem som', (tester) async {
      // Este teste ja disse o contrario, e por um motivo que era
      // verdade: `editVideoVolume` recusava o que nao fosse video, e o
      // cartao segue o comando — entao a camada de AUDIO nao ganhava
      // cartao de volume. O campo `volume` sempre esteve nela, o mixer
      // sempre leu e a exportacao sempre respeitou; o que faltava era o
      // comando, que agora existe (`editVolume`).
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      c.addTextLayer(Duration.zero, text: 'Um');
      final texto = container.read(editorControllerProvider).layers.single;
      expect(
        categoriasDaCamada(texto).map((x) => x.id),
        isNot(contains('som')),
      );

      final id = c.addAudioLayer(
        Duration.zero,
        'som.m4a',
        'Som',
        const Duration(seconds: 4),
      );
      final audio = container
          .read(editorControllerProvider)
          .layers
          .firstWhere((l) => l.id == id);
      expect(categoriasDaCamada(audio).map((x) => x.id), contains('som'));
    });

    testWidgets('toda camada tem transformar e opacidade', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final c = container.read(editorControllerProvider.notifier);
      c.addTextLayer(Duration.zero, text: 'Um');
      final camada = container.read(editorControllerProvider).layers.single;
      final ids = categoriasDaCamada(camada).map((x) => x.id);
      expect(ids, containsAll(['transformar', 'opacidade']));
    });

    testWidgets('o que ainda nao existe aparece DESABILITADO, com motivo', (
      tester,
    ) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(editorControllerProvider.notifier)
          .addTextLayer(Duration.zero, text: 'Um');
      final camada = container.read(editorControllerProvider).layers.single;
      final futuras = categoriasDaCamada(
        camada,
      ).where((x) => !x.disponivel);

      expect(
        futuras.map((x) => x.id),
        contains('borda'),
        reason:
            'a estrutura do painel fica completa: da para ver o editor '
            'inteiro de uma vez',
      );
      // A LISTA DE PROMESSAS SO ENCOLHE. Efeitos saiu quando a ficha
      // passou a ser gerada da tabela; cor saiu quando o seletor
      // chegou. Deixar um cartao apagado depois de o recurso existir e
      // tao ruim quanto acender um que abre o nada.
      expect(
        futuras.map((x) => x.id),
        isNot(contains('efeitos')),
        reason: 'efeitos deixou de ser promessa: a ficha e gerada da tabela',
      );
      expect(
        futuras.map((x) => x.id),
        isNot(contains('cor')),
        reason: 'cor deixou de ser promessa: o seletor existe e pinta',
      );
      for (final f in futuras) {
        expect(
          f.porQueNao,
          isNotNull,
          reason:
              'um cartao apagado sem explicacao vira suspeita de '
              'defeito: "${f.rotulo}" nao diz por que',
        );
      }
    });

    testWidgets('cartao desabilitado NAO abre', (tester) async {
      final m = await _montar(tester);
      await abrirFerramentas(tester, m.c);
      await tester.tap(find.byKey(const ValueKey('cartao-borda')));
      await tester.pump();
      expect(
        m.c.read(estadoDoPainelProvider),
        EstadoDoPainel.categorias,
        reason: 'um cartao aceso que abre o nada e pior que um apagado',
      );
    });

    testWidgets('efeitos abre, e lista o que a camada tem', (tester) async {
      final m = await _montar(tester, telaDeCelular: true);
      await abrirFerramentas(tester, m.c);
      // A GRADE ROLA: com a barra temporal acima dela, um texto tem
      // cartoes abaixo da dobra. Rolar ate ele e o que o dedo faria.
      await tester.ensureVisible(find.byKey(const ValueKey('cartao-efeitos')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('cartao-efeitos')));
      await tester.pump();
      expect(m.c.read(estadoDoPainelProvider), EstadoDoPainel.categoria);
      expect(m.c.read(categoriaAbertaProvider), 'efeitos');
      expect(
        find.bySemanticsLabel('Adicionar efeito'),
        findsOneWidget,
        reason: 'sem caminho para adicionar, a lista vazia e um beco',
      );
    });
  });

  group('a condicao para avancar: 2A nao escreve nada', () {
    testWidgets('abrir, navegar e fechar nao toca no projeto', (tester) async {
      final m = await _montar(tester);
      final antes = m.c.read(editorControllerProvider);
      final podiaDesfazer = m.c.read(editorControllerProvider.notifier).canUndo;

      await abrirFerramentas(tester, m.c);
      await tester.tap(find.byKey(const ValueKey('cartao-opacidade')));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Voltar as ferramentas'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('cartao-transformar')));
      await tester.pump();
      // RECOLHER SO EXISTE NA GRADE. Dentro de uma ferramenta quem fecha
      // e o `‹` da barra da TELA — e este teste monta o painel sozinho,
      // sem barra. Voltar para a grade primeiro e o caminho que existe
      // aqui, e exercita um passo a mais do que o teste ja cobria.
      await tester.tap(find.bySemanticsLabel('Voltar as ferramentas'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Recolher painel'));
      await tester.pump();

      expect(
        identical(m.c.read(editorControllerProvider), antes),
        isTrue,
        reason:
            'a 2A e so leitura: navegar no painel nao pode produzir um '
            'projeto novo',
      );
      expect(
        m.c.read(editorControllerProvider.notifier).canUndo,
        podiaDesfazer,
        reason: 'nem uma entrada de historico',
      );
    });

    testWidgets('abrir Opacidade nao mexe na opacidade', (tester) async {
      final m = await _montar(tester);
      final id = m.c.read(selectedLayerProvider)!;
      final antes = m.c
          .read(editorControllerProvider)
          .layers
          .firstWhere((l) => l.id == id);

      await abrirFerramentas(tester, m.c);
      await tester.tap(find.byKey(const ValueKey('cartao-opacidade')));
      await tester.pump();

      final depois = m.c
          .read(editorControllerProvider)
          .layers
          .firstWhere((l) => l.id == id);
      expect(
        identical(antes, depois),
        isTrue,
        reason:
            'entrar em Opacidade nao pode inicializar a camada em 100% '
            'nem inserir keyframe',
      );
    });

    testWidgets('navegar no painel nao cria nem apaga keyframe', (
      tester,
    ) async {
      final m = await _montar(tester);
      final id = m.c.read(selectedLayerProvider)!;
      m.c
          .read(editorControllerProvider.notifier)
          .toggleKeyframe(id, const Duration(milliseconds: 400), LayerProp.opacity);
      final antes = m.c
          .read(editorControllerProvider)
          .layers
          .firstWhere((l) => l.id == id)
          .keyframeTimes;

      await abrirFerramentas(tester, m.c);
      await tester.tap(find.byKey(const ValueKey('cartao-opacidade')));
      await tester.pump();
      m.p.seek(const Duration(milliseconds: 800));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Voltar as ferramentas'));
      await tester.pump();

      expect(
        m.c
            .read(editorControllerProvider)
            .layers
            .firstWhere((l) => l.id == id)
            .keyframeTimes
            .map((t) => t.inMilliseconds),
        antes.map((t) => t.inMilliseconds),
        reason: 'consultar valores no tempo nao escreve no projeto',
      );
    });
  });

  group('selecao e recuperacao', () {
    testWidgets('trocar de camada atualiza o painel', (tester) async {
      final m = await _montar(tester, textos: 2);
      await abrirFerramentas(tester, m.c);

      final camadas = m.c.read(editorControllerProvider).layers;
      final outra = camadas.last;
      m.c.read(selectedLayerProvider.notifier).state = outra.id;
      await tester.pump();

      expect(find.text(outra.name), findsWidgets);
      expect(
        m.c.read(estadoDoPainelProvider),
        EstadoDoPainel.categorias,
        reason: 'trocar de camada nao fecha o painel',
      );
    });

    testWidgets('camada removida recolhe o painel, sem referencia morta', (
      tester,
    ) async {
      final m = await _montar(tester, textos: 2);
      final id = m.c.read(selectedLayerProvider)!;
      await abrirFerramentas(tester, m.c);
      expect(m.c.read(estadoDoPainelProvider), EstadoDoPainel.categorias);

      m.c.read(editorControllerProvider.notifier).removeLayer(id);
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        m.c.read(estadoDoPainelProvider),
        EstadoDoPainel.recolhido,
        reason: 'sem camada, o painel nao tem o que mostrar',
      );
    });
  });

  group('o interruptor de validacao', () {
    testWidgets('desligado, volta a interface anterior', (tester) async {
      final m = await _montar(tester);
      expect(find.bySemanticsLabel('Adicionar conteudo'), findsOneWidget);

      m.c.read(painelDaCamadaLigadoProvider.notifier).state = false;
      await tester.pump();

      expect(
        find.bySemanticsLabel('Adicionar conteudo'),
        findsNothing,
        reason: 'desligar tem de devolver a interface anterior por inteiro',
      );
      expect(
        find.byType(PainelSobreposto),
        findsOneWidget,
        reason: 'o widget continua montado, mas sem desenhar nada',
      );
    });
  });

  group('regressao: a linha do tempo continua inteira', () {
    testWidgets('os sete botoes seguem la, com o painel aberto', (
      tester,
    ) async {
      final m = await _montar(tester);
      await abrirFerramentas(tester, m.c);
      for (final rotulo in [
        'Desfazer',
        'Refazer',
        'Inicio',
        'Reproduzir',
        'Fim',
        'Duplicar camada',
        'Enquadrar',
      ]) {
        expect(
          find.bySemanticsLabel(rotulo),
          findsOneWidget,
          reason: 'o painel comeu o controle "$rotulo"',
        );
      }
    });

    testWidgets('trocar de modo mantem painel, selecao e tempo', (
      tester,
    ) async {
      final m = await _montar(tester, textos: 2);
      final id = m.c.read(selectedLayerProvider);
      m.p.seek(const Duration(milliseconds: 700));
      await tester.pump();
      final tempo = m.p.time.value;

      // Abrir as ferramentas ja deixa a vista na pilha; a troca que este
      // teste cobra e a de VOLTA para o detalhado.
      await abrirFerramentas(tester, m.c);
      await tester.tap(find.bySemanticsLabel('Ver uma camada'));
      await tester.pump();

      expect(
        m.c.read(modoDaLinhaDoTempoProvider),
        ModoDaLinhaDoTempo.detalhado,
      );
      expect(
        m.c.read(estadoDoPainelProvider),
        EstadoDoPainel.categorias,
        reason: 'trocar a vista da timeline nao fecha as ferramentas',
      );
      expect(m.c.read(selectedLayerProvider), id);
      expect(m.p.time.value, tempo);
    });

    testWidgets('o olho continua escondendo, sem abrir o painel', (
      tester,
    ) async {
      final m = await _montar(tester);
      final id = m.c.read(selectedLayerProvider)!;
      final tempo = m.p.time.value;

      await tester.tap(find.bySemanticsLabel('Esconder Camada 1'));
      await tester.pump();

      expect(m.c.read(editorControllerProvider).metaOf(id).hidden, isTrue);
      expect(
        m.c.read(estadoDoPainelProvider),
        EstadoDoPainel.recolhido,
        reason: 'o olho nao abre ferramentas',
      );
      expect(m.p.time.value, tempo, reason: 'nem desloca o tempo');
    });
  });

  group('adicionar conteudo', () {
    // O FLUXO TEM UM NIVEL SO: o mais abre a moldura do seletor, com as
    // cinco abas ja na tela. A barra de familias e o modal centrado
    // sairam (PROMPT 03 da especificacao AM ONLY).
    Future<void> abrirAba(WidgetTester tester, String aba) async {
      await tester.tap(find.bySemanticsLabel('Adicionar conteudo'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Inserir $aba'));
      await tester.pump();
    }

    testWidgets('o mais abre o seletor, com ou sem selecao', (tester) async {
      final m = await _montar(tester, selecionar: false);
      await tester.tap(find.bySemanticsLabel('Adicionar conteudo'));
      await tester.pump();
      expect(
        m.c.read(barraDeAdicaoAbertaProvider),
        isTrue,
        reason:
            'adicionar depende de projeto editavel e tipo suportado — '
            'nao de haver camada escolhida',
      );
      expect(find.bySemanticsLabel('Inserir Forma'), findsOneWidget);
      expect(find.bySemanticsLabel('Texto'), findsOneWidget);
    });

    testWidgets('a aba de objetos traz os quatro da referencia', (
      tester,
    ) async {
      final m = await _montar(tester, textos: 0, telaDeCelular: true);
      await abrirAba(tester, 'Objeto / Elemento');
      expect(m.c.read(abaDeInsercaoProvider), AbaDeInsercao.objeto);
      for (final rotulo in [
        'Camera',
        'Grupo Vazio',
        'Nulo',
        'Elemento / Projeto',
      ]) {
        expect(
          find.bySemanticsLabel(rotulo),
          findsOneWidget,
          reason: 'a grade de objetos perdeu "$rotulo"',
        );
      }
    });

    testWidgets('os elementos da Aurea abrem MAIS UM nivel, e da para voltar', (
      tester,
    ) async {
      final m = await _montar(tester, textos: 0, telaDeCelular: true);
      await abrirAba(tester, 'Objeto / Elemento');
      await tester.tap(find.bySemanticsLabel('Elemento / Projeto'));
      await tester.pump();
      expect(m.c.read(subListaDeInsercaoProvider), 'elemento');
      expect(find.bySemanticsLabel('Cena 3D'), findsOneWidget);
      expect(
        m.c.read(editorControllerProvider).layers,
        isEmpty,
        reason: 'abrir um nivel nao cria camada nenhuma',
      );

      await tester.tap(find.bySemanticsLabel('Voltar aos objetos'));
      await tester.pump();
      expect(m.c.read(subListaDeInsercaoProvider), isNull);
      expect(find.bySemanticsLabel('Camera'), findsOneWidget);
    });

    testWidgets('escolher cria a camada, seleciona e fecha o fluxo', (
      tester,
    ) async {
      final m = await _montar(tester, textos: 0);
      expect(m.c.read(editorControllerProvider).layers, isEmpty);

      await tester.tap(find.bySemanticsLabel('Adicionar conteudo'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Texto'));
      await tester.pump(const Duration(seconds: 1));

      final camadas = m.c.read(editorControllerProvider).layers;
      expect(camadas.length, 1);
      expect(
        m.c.read(selectedLayerProvider),
        camadas.single.id,
        reason: 'a camada nova entra selecionada',
      );
      expect(
        m.c.read(barraDeAdicaoAbertaProvider),
        isFalse,
        reason: 'criado o que se foi criar, o seletor sai da frente',
      );
    });

    testWidgets('o X fecha sem criar nada', (tester) async {
      final m = await _montar(tester, textos: 0);
      await abrirAba(tester, 'Forma');
      await tester.tap(find.bySemanticsLabel('Fechar o seletor'));
      await tester.pump();
      expect(m.c.read(barraDeAdicaoAbertaProvider), isFalse);
      expect(m.c.read(editorControllerProvider).layers, isEmpty);
    });

    testWidgets('o mais vira x, e o mesmo alvo dispensa o seletor', (
      tester,
    ) async {
      final m = await _montar(tester, textos: 0);
      await tester.tap(find.bySemanticsLabel('Adicionar conteudo'));
      await tester.pump();
      expect(m.c.read(barraDeAdicaoAbertaProvider), isTrue);
      await tester.tap(find.bySemanticsLabel('Fechar o menu'));
      await tester.pump();
      expect(m.c.read(barraDeAdicaoAbertaProvider), isFalse);
    });

    testWidgets('adicionar e desfazer devolve ao estado vazio', (tester) async {
      final m = await _montar(tester, textos: 0, telaDeCelular: true);
      await tester.tap(find.bySemanticsLabel('Adicionar conteudo'));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Circulo'));
      await tester.pump(const Duration(seconds: 1));
      expect(m.c.read(editorControllerProvider).layers.length, 1);

      m.c.read(editorControllerProvider.notifier).undo();
      await tester.pump();
      await tester.pump();

      expect(
        m.c.read(editorControllerProvider).layers,
        isEmpty,
        reason: 'uma adicao, um desfazer',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('o instante de insercao e o de ABRIR o menu', (tester) async {
      final m = await _montar(tester, textos: 0);
      m.p.seek(const Duration(milliseconds: 1200));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Adicionar conteudo'));
      await tester.pump();
      // O relogio anda ENTRE abrir e escolher; o que vale e o de abrir.
      m.p.seek(const Duration(milliseconds: 2600));
      await tester.pump();
      await tester.tap(find.bySemanticsLabel('Texto'));
      await tester.pump(const Duration(seconds: 1));

      expect(
        m.c.read(editorControllerProvider).layers.single.startTime,
        m.c.read(instanteDeInsercaoProvider),
        reason:
            'a pessoa escolheu o lugar ao abrir o menu, e nao ao tocar '
            'no tipo',
      );
    });
  });

  group('o vazio vem dos DADOS, e nao do que esta desenhado', () {
    testWidgets('esconder todas as camadas NAO e projeto vazio', (
      tester,
    ) async {
      final m = await _montar(tester, textos: 2);
      for (final l in m.c.read(editorControllerProvider).layers) {
        m.c.read(editorControllerProvider.notifier).toggleHidden(l.id);
      }
      await tester.pump();

      m.c.read(modoDaLinhaDoTempoProvider.notifier).state =
          ModoDaLinhaDoTempo.geral;
      await tester.pump();
      expect(
        find.byKey(const ValueKey('visao-geral-vazia')),
        findsNothing,
        reason:
            'o preview fica preto com tudo escondido, mas as camadas '
            'continuam la — quem responde e o projeto, nao a imagem',
      );
    });

    testWidgets('tirar so a selecao NAO e projeto vazio', (tester) async {
      final m = await _montar(tester, textos: 2);
      m.c.read(selectedLayerProvider.notifier).state = null;
      await tester.pump();

      // OS TRES ESTADOS SAO DA LINHA DO TEMPO AGORA, e nao mais de uma
      // faixa no rodape: "projeto vazio", "nada escolhido" e "camada
      // escolhida" continuam separados, so que onde se trabalha.
      expect(
        find.byKey(const ValueKey('detalhado-sem-selecao')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('timeline-aviso')), findsNothing);
    });
  });

  group('layout do editor', () {
    testWidgets('a regua e o cabecote ficam no projeto vazio', (tester) async {
      await _montar(tester, textos: 0);
      expect(
        find.byKey(const ValueKey('timeline-aviso')),
        findsOneWidget,
        reason:
            'sem camadas, a referencia temporal continua: e ela que diz '
            'onde o conteudo novo vai entrar',
      );
      expect(
        find.byKey(const ValueKey('visao-geral-vazia')),
        findsNothing,
        reason: 'com duracao valida nao se troca a regua por um texto',
      );
    });

    testWidgets('a linha do tempo nao encolhe abaixo do util', (tester) async {
      await _montar(tester, textos: 0);
      final altura = tester.getSize(find.byType(LinhaDoTempo)).height;
      expect(
        altura,
        greaterThanOrEqualTo(LinhaDoTempo.alturaMinima),
        reason:
            'a timeline tem um CHAO: quem cede espaco e o preview, e '
            'nunca ela',
      );
    });

    testWidgets('a linha do tempo vai ate o pe da tela', (tester) async {
      await _montar(tester);
      final tela = tester.getRect(find.byType(Scaffold));
      final tempo = tester.getRect(find.byType(LinhaDoTempo));
      expect(
        tempo.bottom,
        closeTo(tela.bottom - PainelDaCamada.alturaMaxima, 1),
        reason:
            'neste teste o espaco do painel e reservado a mao; na tela de '
            'verdade nao ha rodape nenhum abaixo da linha do tempo',
      );
    });

    testWidgets('os alvos do transporte tem 48 px de altura', (tester) async {
      await _montar(tester);
      for (final rotulo in ['Desfazer', 'Reproduzir', 'Enquadrar']) {
        final caixa = tester.getSize(find.bySemanticsLabel(rotulo));
        expect(
          caixa.height,
          greaterThanOrEqualTo(48),
          reason:
              'a area de toque de "$rotulo" tem $caixa — abaixo de 48 dp '
              'o dedo erra',
        );
        expect(caixa.width, greaterThanOrEqualTo(44));
      }
    });
  });
}
