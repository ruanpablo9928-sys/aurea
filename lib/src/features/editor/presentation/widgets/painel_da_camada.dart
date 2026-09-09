import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../domain/layer.dart';

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
}

/// O que o painel esta mostrando. Os estados sao MUTUAMENTE EXCLUSIVOS:
/// nunca ha dois paineis empilhados, e nenhum painel invisivel continua
/// recebendo gesto atras do outro.
final estadoDoPainelProvider = StateProvider<EstadoDoPainel>(
  (ref) => EstadoDoPainel.recolhido,
);

/// A categoria aberta, quando o estado e [EstadoDoPainel.categoria].
final categoriaAbertaProvider = StateProvider<String?>((ref) => null);

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
/// Efeitos, bordas, sombras, mascaras e modos de mistura ficam de fora
/// desta etapa por decisao, e nao por esquecimento.
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

/// O painel inferior. Ver [EstadoDoPainel] para os tres estados.
class PainelDaCamada extends ConsumerWidget {
  const PainelDaCamada({super.key});

  /// A faixa recolhida. Alta o bastante para o dedo, baixa o bastante
  /// para nao roubar o preview.
  static const alturaRecolhido = 52.0;

  /// O TETO do painel aberto. Nao muda proporcao nem resolucao do
  /// projeto: a composicao apenas se ajusta ao espaco que sobra.
  static const alturaMaxima = 232.0;

  static const _alturaDoCabecalho = 44.0;
  static const _alturaDoCartao = 56.0;
  static const _folgaDaGrade = 24.0;

  /// O PAINEL PEDE SO O QUE PRECISA, ate o teto.
  ///
  /// Com altura fixa, tres cartoes deixavam quase cem pixels de vazio
  /// embaixo — e cada pixel ali sai do preview, que e o que a pessoa
  /// esta olhando. Acima do teto o conteudo rola, em vez de empurrar a
  /// composicao para fora da tela.
  static double alturaDoEstado(
    EstadoDoPainel estado, {
    int categorias = 0,
  }) {
    if (estado == EstadoDoPainel.recolhido) return alturaRecolhido;
    if (estado == EstadoDoPainel.categoria) return alturaMaxima;
    final linhas = (categorias / 2).ceil();
    final pedida =
        _alturaDoCabecalho + linhas * (_alturaDoCartao + 8) + _folgaDaGrade;
    return pedida < alturaMaxima ? pedida : alturaMaxima;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(painelDaCamadaLigadoProvider)) {
      return const SizedBox.shrink();
    }
    final estado = ref.watch(estadoDoPainelProvider);
    final project = ref.watch(editorControllerProvider);
    final id = ref.watch(selectedLayerProvider);

    // A SELECAO E POR IDENTIDADE, e nao por posicao na lista. Se a
    // camada sumiu (exclusao, desfazer), o painel se recolhe sozinho em
    // vez de ficar segurando uma referencia morta.
    final camada = project.layers.where((l) => l.id == id).firstOrNull;
    if (camada == null && estado != EstadoDoPainel.recolhido) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!ref.context.mounted) return;
        ref.read(estadoDoPainelProvider.notifier).state =
            EstadoDoPainel.recolhido;
        ref.read(categoriaAbertaProvider.notifier).state = null;
      });
    }

    return SizedBox(
      height: alturaDoEstado(
        camada == null ? EstadoDoPainel.recolhido : estado,
        categorias: camada == null ? 0 : categoriasDaCamada(camada).length,
      ),
      child: ColoredBox(
        color: AmColors.panelHigh,
        child: camada == null || estado == EstadoDoPainel.recolhido
            ? _FaixaRecolhida(camada: camada)
            : _Aberto(camada: camada, estado: estado),
      ),
    );
  }
}

/// A FAIXA RECOLHIDA: o nome do que ha, e o `+`.
///
/// Os dois ficam separados de proposito. O `+` cria conteudo; a faixa
/// abre ferramentas do que ja existe. Encostar um no outro convida ao
/// toque errado.
class _FaixaRecolhida extends ConsumerWidget {
  const _FaixaRecolhida({required this.camada});

  final Layer? camada;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
    children: [
      Expanded(
        child: Semantics(
          container: true,
          explicitChildNodes: false,
          excludeSemantics: true,
          button: camada != null,
          label: camada == null
              ? 'Selecione uma camada'
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
                          ? 'Selecione uma camada'
                          : 'Ferramentas da camada',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: camada == null ? AmColors.muted : AmColors.text,
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
      // O `+` TEM LUGAR RESERVADO NO LAYOUT.
      //
      // Ele nao flutua sobre a linha do tempo: sobrepor um keyframe, o
      // olho, uma barra de camada ou a capsula de tempo tornaria esses
      // alvos intocaveis justamente na regiao mais disputada da tela.
      const _BotaoAdicionar(),
    ],
  );
}

/// O `+`. Na 2A ele existe, ocupa o lugar dele e explica que ainda nao
/// faz nada — em vez de sumir e reaparecer noutra entrega, mudando o
/// layout debaixo da mao de quem esta validando.
class _BotaoAdicionar extends StatelessWidget {
  const _BotaoAdicionar();

  static const largura = 56.0;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    enabled: false,
    label: 'Adicionar conteudo',
    child: Tooltip(
      message: 'Adicionar chega na proxima entrega',
      child: SizedBox(
        width: largura,
        height: PainelDaCamada.alturaRecolhido,
        child: Icon(
          Icons.add_rounded,
          size: 24,
          color: AmColors.muted.withValues(alpha: .45),
        ),
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
              child: Text(
                categoria.rotulo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: categoria.disponivel
                      ? AmColors.text
                      : AmColors.muted.withValues(alpha: .6),
                ),
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
