import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../application/playback_controller.dart';
import '../../domain/layer.dart';
import 'adicionar_conteudo.dart';

/// AS FERRAMENTAS DA CAMADA SELECIONADA.
///
/// ENTREGA 2A: estrutura e navegacao, SO LEITURA. Abrir, recolher,
/// entrar numa categoria e voltar. Nenhum controle escreve no projeto
/// ainda — isso e a 2B. O `+` reserva o lugar dele e fica desligado ate
/// a 2C.
///
/// A regra que decide o que aparece: CAPACIDADE REAL, e nao o nome do
/// tipo. Uma categoria so entra na lista quando existe um comando no
/// `EditorController` que a atende. O levantamento que sustenta
/// [categoriasDaCamada] esta em `docs/painel-da-camada.md`.
enum EstadoDoPainel {
  /// A faixa fina: "Ferramentas da camada" e o `+`.
  recolhido,

  /// A grade de categorias da camada selecionada.
  categorias,

  /// Uma categoria aberta, ocupando o painel.
  categoria,

  /// O menu de adicao. E um ESTADO do mesmo painel, e nao outro painel
  /// por cima: assim nao sobra uma camada invisivel recebendo gesto
  /// atras da outra.
  adicionar,
}

/// O que o painel esta mostrando. Os estados sao MUTUAMENTE EXCLUSIVOS:
/// nunca ha dois paineis empilhados, e nenhum painel invisivel continua
/// recebendo gesto atras do outro.
final estadoDoPainelProvider = StateProvider<EstadoDoPainel>(
  (ref) => EstadoDoPainel.recolhido,
);

/// A categoria aberta, quando o estado e [EstadoDoPainel.categoria].
final categoriaAbertaProvider = StateProvider<String?>((ref) => null);

/// O INSTANTE EM QUE O CONTEUDO NOVO ENTRA.
///
/// Capturado quando o menu de adicao ABRE, e nao quando o toque no tipo
/// acontece: assim que o relogio anda, os dois deixam de ser a mesma
/// coisa — e o lugar que a pessoa escolheu foi o de quando abriu.
final instanteDeInsercaoProvider = StateProvider<Duration>(
  (ref) => Duration.zero,
);

/// O INTERRUPTOR DE VALIDACAO.
///
/// Desligar devolve a interface anterior — preview e linha do tempo, sem
/// painel — sem converter projeto nenhum. Existe para a validacao poder
/// comparar as duas, e para haver um caminho de volta se o painel novo
/// atrapalhar algum fluxo.
final painelDaCamadaLigadoProvider = StateProvider<bool>((ref) => true);

/// Uma categoria de ferramentas.
@immutable
class CategoriaDaCamada {
  const CategoriaDaCamada({
    required this.id,
    required this.rotulo,
    required this.icone,
    this.disponivel = true,
    this.porQueNao,
  });

  final String id;

  /// O NOME DIZ O QUE EXISTE. Se so ha opacidade, o cartao se chama
  /// "Opacidade" — nunca "Mistura e opacidade". Prometer no rotulo o que
  /// nao esta atras dele e a forma mais barata de perder a confianca de
  /// quem usa.
  final String rotulo;
  final IconData icone;

  /// Implementado, mas indisponivel AGORA. Recurso que nao existe fica
  /// fora da lista; nao entra desabilitado.
  final bool disponivel;
  final String? porQueNao;
}

/// O QUE ESTA CAMADA SABE FAZER, conferido contra os comandos que
/// existem de verdade no `EditorController`.
///
/// Levantamento (setembro de 2026):
///
///   transformar .. editPosition / editScaleUniform / editRotation .. toda camada
///   opacidade .... editOpacity ................................... toda camada
///   texto ........ editTextLayer ................................. TextLayer
///   forma ........ editShapeParam ................................ ShapeLayer
///   volume ....... editVideoVolume ............................... VideoLayer
///   informacoes .. (leitura) ..................................... imagem, video, audio
///
/// `editVideoVolume` RECUSA o que nao for `VideoLayer` — por isso camada
/// de audio nao ganha o cartao de volume, apesar de ter o campo. Anunciar
/// um controle que o comando ignora seria pior que nao ter o cartao.
///
/// AS CATEGORIAS QUE AINDA NAO EXISTEM APARECEM DESABILITADAS, e dizem
/// por que. Elas estao aqui a pedido: a estrutura do painel fica
/// completa e da para ver o editor inteiro de uma vez. O que nao pode e
/// um cartao acesso abrir o nada — entao eles nao respondem ao toque, e
/// o motivo esta escrito no proprio cartao.
List<CategoriaDaCamada> categoriasDaCamada(Layer camada) => [
  const CategoriaDaCamada(
    id: 'transformar',
    rotulo: 'Mover e transformar',
    icone: Icons.open_with_rounded,
  ),
  const CategoriaDaCamada(
    id: 'opacidade',
    rotulo: 'Opacidade',
    icone: Icons.opacity_rounded,
  ),
  if (camada is TextLayer)
    const CategoriaDaCamada(
      id: 'texto',
      rotulo: 'Texto',
      icone: Icons.text_fields_rounded,
    ),
  if (camada is ShapeLayer)
    const CategoriaDaCamada(
      id: 'forma',
      rotulo: 'Forma',
      icone: Icons.category_rounded,
    ),
  if (camada is VideoLayer)
    const CategoriaDaCamada(
      id: 'volume',
      rotulo: 'Volume',
      icone: Icons.volume_up_rounded,
    ),
  if (camada is ImageLayer || camada is VideoLayer || camada is AudioLayer)
    const CategoriaDaCamada(
      id: 'midia',
      rotulo: 'Informacoes da midia',
      icone: Icons.info_outline_rounded,
    ),
  const CategoriaDaCamada(
    id: 'cor',
    rotulo: 'Cor e preenchimento',
    icone: Icons.palette_rounded,
    disponivel: false,
    porQueNao: 'Chega numa proxima entrega',
  ),
  const CategoriaDaCamada(
    id: 'borda',
    rotulo: 'Borda e sombra',
    icone: Icons.blur_on_rounded,
    disponivel: false,
    porQueNao: 'Chega numa proxima entrega',
  ),
  const CategoriaDaCamada(
    id: 'efeitos',
    rotulo: 'Efeitos',
    icone: Icons.auto_awesome_rounded,
    disponivel: false,
    porQueNao: 'Tem etapa propria',
  ),
];

/// COMO A CAMADA SE CHAMA POR TIPO, para o cabecalho.
///
/// O switch e EXAUSTIVO, sem caso generico. Nao e descuido: `Layer` e
/// uma hierarquia fechada, entao um tipo novo quebra a COMPILACAO aqui
/// em vez de cair calado num rotulo generico. E a diferenca entre
/// descobrir o buraco ao compilar e descobrir no aparelho de alguem.
String tipoDaCamadaEmPalavras(Layer camada) => switch (camada) {
  TextLayer() => 'Texto',
  ShapeLayer() => 'Forma',
  ImageLayer() => 'Imagem',
  VideoLayer() => 'Video',
  AudioLayer() => 'Audio',
  Scene3DLayer() => 'Cena 3D',
  Element3DLayer() => 'Elemento 3D',
  GroupLayer() => 'Grupo',
  NullLayer() => 'Nulo',
  ParticlesLayer() => 'Particulas',
  CaptionLayer() => 'Legenda',
  AdjustmentLayer() => 'Ajuste',
};

/// Medidas do painel, usadas pela tela para dividir o espaco.
abstract final class PainelDaCamada {
  /// A faixa recolhida. Alta o bastante para o dedo, baixa o bastante
  /// para nao roubar a linha do tempo.
  static const alturaRecolhido = 52.0;

  /// O TETO do painel aberto. Ele SOBREPOE, entao esta altura sai da
  /// tela e nao do espaco dos outros.
  static const alturaMaxima = 260.0;

  static const _alturaDoCabecalho = 44.0;
  static const _alturaDoCartao = 56.0;
  static const _folgaDaGrade = 24.0;

  /// O PAINEL PEDE SO O QUE PRECISA, ate o teto. Com altura fixa, tres
  /// cartoes deixavam quase cem pixels de vazio — e vazio sobreposto
  /// tapa a linha do tempo sem motivo.
  static double alturaAberta(int itens) {
    final linhas = (itens / 2).ceil();
    final pedida =
        _alturaDoCabecalho + linhas * (_alturaDoCartao + 8) + _folgaDaGrade;
    return pedida < alturaMaxima ? pedida : alturaMaxima;
  }
}

/// A FAIXA FIXA, sempre no rodape.
///
/// Fechada, o painel e SO isto: uma barra de 52 px com o titulo e o `+`.
/// Ela nao cresce, nao empurra e nao tira altura da linha do tempo — que
/// e a area de trabalho e precisa do espaco.
class FaixaDoPainel extends ConsumerWidget {
  const FaixaDoPainel({super.key, required this.playback});

  final PlaybackController playback;

  static const altura = PainelDaCamada.alturaRecolhido;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(painelDaCamadaLigadoProvider)) {
      return const SizedBox.shrink();
    }
    final project = ref.watch(editorControllerProvider);
    final id = ref.watch(selectedLayerProvider);
    final camada = project.layers.where((l) => l.id == id).firstOrNull;
    return SizedBox(
      height: altura,
      child: ColoredBox(
        color: AmColors.panelHigh,
        child: _FaixaRecolhida(
          camada: camada,
          projetoVazio: project.layers.isEmpty,
          playback: playback,
        ),
      ),
    );
  }
}

/// O PAINEL ABERTO, sobreposto ao rodape.
///
/// Ele sobe por cima em vez de empurrar a tela: reflowar preview e
/// timeline a cada abertura mudaria de lugar o que estava debaixo do
/// dedo, no meio da edicao.
class PainelSobreposto extends ConsumerWidget {
  const PainelSobreposto({super.key, required this.playback});

  final PlaybackController playback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(painelDaCamadaLigadoProvider)) {
      return const SizedBox.shrink();
    }
    final estado = ref.watch(estadoDoPainelProvider);
    if (estado == EstadoDoPainel.recolhido) return const SizedBox.shrink();

    final project = ref.watch(editorControllerProvider);
    final id = ref.watch(selectedLayerProvider);
    final camada = project.layers.where((l) => l.id == id).firstOrNull;

    // A SELECAO E POR IDENTIDADE. Se a camada sumiu (exclusao,
    // desfazer), o painel se recolhe em vez de segurar uma referencia
    // morta. Adicionar escapa disto: ele nao depende de camada.
    if (camada == null && estado != EstadoDoPainel.adicionar) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!ref.context.mounted) return;
        ref.read(estadoDoPainelProvider.notifier).state =
            EstadoDoPainel.recolhido;
        ref.read(categoriaAbertaProvider.notifier).state = null;
      });
      return const SizedBox.shrink();
    }

    final itens = estado == EstadoDoPainel.adicionar
        ? tiposDeConteudo.length
        : camada == null
        ? 0
        : categoriasDaCamada(camada).length;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: estado == EstadoDoPainel.categoria
          ? PainelDaCamada.alturaMaxima
          : PainelDaCamada.alturaAberta(itens),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AmColors.panelHigh,
          border: Border(top: BorderSide(color: AmColors.hairline)),
        ),
        child: estado == EstadoDoPainel.adicionar
            ? _Adicionar()
            : _Aberto(camada: camada!, estado: estado),
      ),
    );
  }
}

/// O MENU DE ADICAO, com o cabecalho de voltar.
class _Adicionar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        height: 44,
        child: Row(
          children: [
            Semantics(
              container: true,
              excludeSemantics: true,
              button: true,
              label: 'Voltar',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => ref.read(estadoDoPainelProvider.notifier).state =
                    EstadoDoPainel.recolhido,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.chevron_left_rounded,
                    size: 22,
                    color: AmColors.text,
                  ),
                ),
              ),
            ),
            const Expanded(
              child: Text(
                'Adicionar conteudo',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AmColors.text,
                ),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: MenuDeAdicao(
          instanteDeInsercao: ref.watch(instanteDeInsercaoProvider),
          aoAdicionar: () {
            // Depois de criar, as ferramentas da camada nova. O criador
            // ja a selecionou.
            ref.read(estadoDoPainelProvider.notifier).state =
                EstadoDoPainel.categorias;
          },
        ),
      ),
    ],
  );
}

/// A FAIXA RECOLHIDA: o nome do que ha, e o `+`.
///
/// Os dois ficam separados de proposito. O `+` cria conteudo; a faixa
/// abre ferramentas do que ja existe. Encostar um no outro convida ao
/// toque errado.
class _FaixaRecolhida extends ConsumerWidget {
  const _FaixaRecolhida({
    required this.camada,
    required this.projetoVazio,
    required this.playback,
  });

  final Layer? camada;
  final bool projetoVazio;
  final PlaybackController playback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // PROJETO VAZIO: a acao e CRIAR, e ela ocupa a faixa inteira. Nao
    // adianta oferecer ferramentas de uma camada que nao existe.
    if (projetoVazio) {
      return Row(
        children: [
          Expanded(
            child: Semantics(
              container: true,
              excludeSemantics: true,
              button: true,
              label: 'Adicionar conteudo',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _abrirAdicao(ref, playback),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        size: 20,
                        color: AmColors.action,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Seu projeto esta vazio',
                              key: ValueKey('painel-projeto-vazio'),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AmColors.text,
                              ),
                            ),
                            Text(
                              'Toque para adicionar conteudo',
                              style: TextStyle(
                                fontSize: 11,
                                color: AmColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Semantics(
            container: true,
            excludeSemantics: true,
            button: camada != null,
            label: camada == null
                ? 'Selecione uma camada para editar'
                : 'Ferramentas da camada',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: camada == null
                  ? null
                  : () => ref.read(estadoDoPainelProvider.notifier).state =
                        EstadoDoPainel.categorias,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      camada == null
                          ? Icons.touch_app_outlined
                          : Icons.tune_rounded,
                      size: 18,
                      color: camada == null ? AmColors.muted : AmColors.text,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        camada == null
                            ? 'Selecione uma camada para editar'
                            : 'Ferramentas da camada',
                        key: camada == null
                            ? const ValueKey('painel-sem-selecao')
                            : null,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: camada == null
                              ? AmColors.muted
                              : AmColors.text,
                        ),
                      ),
                    ),
                    if (camada != null)
                      const Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 20,
                        color: AmColors.muted,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // O `+` TEM LUGAR RESERVADO, E NAO DEPENDE DA SELECAO.
        //
        // Adicionar precisa de um projeto editavel e de um tipo
        // suportado — nada mais. Amarrar isso a haver camada escolhida
        // e o que fecha a porta de entrada do editor. (Duplicar, sim,
        // depende de selecao: por isso ele vive no transporte.)
        _BotaoAdicionar(aoTocar: () => _abrirAdicao(ref, playback)),
      ],
    );
  }

  /// ABRIR O FLUXO DE ADICAO: pausa e REGISTRA O INSTANTE.
  ///
  /// O instante e capturado aqui, e nao no toque que escolhe o tipo:
  /// assim que o relogio anda, os dois deixam de ser a mesma coisa, e o
  /// lugar que a pessoa escolheu foi o de quando abriu.
  ///
  /// Pausar antes evita o caso em que o cabecote passa por cima da
  /// camada nova enquanto ela esta sendo criada.
  static void _abrirAdicao(WidgetRef ref, PlaybackController playback) {
    playback.pause();
    ref.read(instanteDeInsercaoProvider.notifier).state = playback.time.value;
    ref.read(estadoDoPainelProvider.notifier).state = EstadoDoPainel.adicionar;
  }
}

/// O `+` COMPACTO, que aparece quando ja ha conteudo.
///
/// No projeto vazio quem convida e a faixa inteira, com texto; aqui, com
/// camadas na tela, basta o simbolo. Os dois chamam o MESMO fluxo — nao
/// ha duas implementacoes de adicionar.
class _BotaoAdicionar extends StatelessWidget {
  const _BotaoAdicionar({required this.aoTocar});

  final VoidCallback aoTocar;

  static const largura = 56.0;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    label: 'Adicionar conteudo',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aoTocar,
      child: const SizedBox(
        width: largura,
        height: PainelDaCamada.alturaRecolhido,
        // NA COR DE ACAO, e nao no cinza dos controles desligados. Um
        // botao que parece morto nao e tocado, e este e o unico caminho
        // para comecar a editar.
        child: Icon(Icons.add_rounded, size: 24, color: AmColors.action),
      ),
    ),
  );
}

class _Aberto extends ConsumerWidget {
  const _Aberto({required this.camada, required this.estado});

  final Layer camada;
  final EstadoDoPainel estado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aberta = ref.watch(categoriaAbertaProvider);
    final categorias = categoriasDaCamada(camada);
    final atual = categorias.where((c) => c.id == aberta).firstOrNull;
    final naCategoria = estado == EstadoDoPainel.categoria && atual != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Cabecalho(camada: camada, categoria: naCategoria ? atual : null),
        Expanded(
          child: naCategoria
              ? _ConteudoDaCategoria(categoria: atual, camada: camada)
              : _GradeDeCategorias(categorias: categorias),
        ),
      ],
    );
  }
}

/// O CABECALHO diz onde se esta, e como sair.
///
/// Nas categorias: nome da camada e o tipo. Dentro de uma:
/// "Voltar · Opacidade · Titulo principal" — o caminho inteiro, porque
/// quem entra numa categoria perde de vista qual camada esta editando.
class _Cabecalho extends ConsumerWidget {
  const _Cabecalho({required this.camada, required this.categoria});

  final Layer camada;
  final CategoriaDaCamada? categoria;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
    height: 44,
    child: Row(
      children: [
        if (categoria != null)
          Semantics(
            container: true,
            excludeSemantics: true,
            button: true,
            label: 'Voltar',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                ref.read(estadoDoPainelProvider.notifier).state =
                    EstadoDoPainel.categorias;
                ref.read(categoriaAbertaProvider.notifier).state = null;
              },
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.chevron_left_rounded,
                  size: 22,
                  color: AmColors.text,
                ),
              ),
            ),
          )
        else
          const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                categoria?.rotulo ?? camada.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AmColors.text,
                ),
              ),
              Text(
                categoria == null
                    ? tipoDaCamadaEmPalavras(camada)
                    : camada.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AmColors.muted),
              ),
            ],
          ),
        ),
        Semantics(
          container: true,
          excludeSemantics: true,
          button: true,
          label: 'Recolher painel',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // RECOLHER NAO TIRA A SELECAO nem mexe no tempo. Fechar uma
            // gaveta nao e desfazer o que se escolheu.
            onTap: () {
              ref.read(estadoDoPainelProvider.notifier).state =
                  EstadoDoPainel.recolhido;
              ref.read(categoriaAbertaProvider.notifier).state = null;
            },
            child: const SizedBox(
              width: 48,
              height: 44,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 22,
                color: AmColors.text,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _GradeDeCategorias extends ConsumerWidget {
  const _GradeDeCategorias({required this.categorias});

  final List<CategoriaDaCamada> categorias;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (categorias.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Esta camada ainda nao tem ferramentas neste painel.',
            key: ValueKey('painel-sem-categorias'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AmColors.muted, height: 1.4),
          ),
        ),
      );
    }
    // DUAS COLUNAS no celular: com tres, os rotulos comecam a truncar, e
    // um cartao que nao se le nao serve de atalho.
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        mainAxisExtent: 56,
      ),
      itemCount: categorias.length,
      itemBuilder: (context, i) => _Cartao(
        // A CHAVE E ANCORADOURO DE TESTE, e ela e necessaria: o rotulo
        // sozinho nao distingue o cartao "Texto" do tipo "Texto" que o
        // cabecalho mostra logo acima.
        key: ValueKey('cartao-${categorias[i].id}'),
        categoria: categorias[i],
      ),
    );
  }
}

class _Cartao extends ConsumerWidget {
  const _Cartao({super.key, required this.categoria});

  final CategoriaDaCamada categoria;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    enabled: categoria.disponivel,
    label: categoria.rotulo,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      // ABRIR UMA CATEGORIA NAO ESCREVE NADA. Entrar em "Opacidade" nao
      // inicializa a camada em 100% nem insere keyframe: navegar e
      // consultar, e consultar nao muda o projeto.
      onTap: categoria.disponivel
          ? () {
              ref.read(categoriaAbertaProvider.notifier).state = categoria.id;
              ref.read(estadoDoPainelProvider.notifier).state =
                  EstadoDoPainel.categoria;
            }
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: AmColors.chip.withValues(alpha: categoria.disponivel ? 1 : .4),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(
              categoria.icone,
              size: 19,
              color: categoria.disponivel
                  ? AmColors.text
                  : AmColors.muted.withValues(alpha: .5),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoria.rotulo,
                    maxLines: categoria.disponivel ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      color: categoria.disponivel
                          ? AmColors.text
                          : AmColors.muted.withValues(alpha: .7),
                    ),
                  ),
                  // O MOTIVO FICA NO CARTAO. Um controle apagado sem
                  // explicacao vira suspeita de defeito.
                  if (!categoria.disponivel && categoria.porQueNao != null)
                    Text(
                      categoria.porQueNao!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        height: 1.3,
                        color: AmColors.muted.withValues(alpha: .5),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// O CONTEUDO DE UMA CATEGORIA — vazio na 2A, de proposito.
///
/// Ligar os controles aos comandos e a 2B, e ela tem contrato proprio:
/// um gesto confirmado vira UMA operacao de desfazer, cancelar restaura,
/// e propriedade animada nao vira estatica por causa de um slider. Pendurar
/// controles aqui agora, sem esse contrato, e o caminho mais curto para
/// estragar o historico.
class _ConteudoDaCategoria extends StatelessWidget {
  const _ConteudoDaCategoria({required this.categoria, required this.camada});

  final CategoriaDaCamada categoria;
  final Layer camada;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Os controles de ${categoria.rotulo.toLowerCase()} chegam na '
          'proxima entrega.',
          key: const ValueKey('categoria-sem-controles'),
          style: const TextStyle(
            fontSize: 12,
            color: AmColors.muted,
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}
