import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../application/playback_controller.dart';
import '../../domain/layer.dart';
import 'controles_da_camada.dart';
import 'editor_de_curva.dart';

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
  /// Fechado. NAO ha faixa nenhuma no rodape.
  ///
  /// A faixa "Ferramentas da camada" existiu e foi removida: ela comia
  /// 52 px de altura o tempo todo para oferecer um caminho que o toque
  /// na propria camada ja oferece. Quem abre as ferramentas hoje e um
  /// toque na camada JA selecionada, na pilha.
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
  // O QUE SE FAZ COM A CAMADA INTEIRA — dividir, duplicar, apagar — nao
  // e propriedade dela, e por isso tem cartao proprio em vez de virar
  // mais um deslizante perdido no meio dos outros.
  const CategoriaDaCamada(
    id: 'camada',
    rotulo: 'Camada',
    icone: Icons.layers_rounded,
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
  ),
  // MASCARA SO EM QUEM TEM IMAGEM.
  //
  // Audio nao desenha nada e nulo existe justamente para nao desenhar:
  // recortar qualquer um dos dois nao muda um pixel. O cartao ficaria
  // aceso prometendo um efeito que nunca apareceria.
  if (camada is! AudioLayer && camada is! NullLayer)
    const CategoriaDaCamada(
      id: 'mascara',
      rotulo: 'Mascara',
      icone: Icons.crop_free_rounded,
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
  /// O TETO do painel aberto. Ele SOBREPOE, entao esta altura sai da
  /// tela e nao do espaco dos outros.
  ///
  /// Subiu de 260 para 300 quando os controles de verdade entraram:
  /// transformar tem quatro deslizantes mais o interruptor de keyframe,
  /// e em 260 o ultimo ficava sempre abaixo da dobra. Acima de 300 ele
  /// comeca a tapar a previa, que e o que se esta ajustando.
  static const alturaMaxima = 300.0;

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
    // A CURVA E UMA FERRAMENTA, e nao um modal por cima de outra.
    //
    // Ela era um painel flutuante com a tela desfocada atras, e isso
    // escondia a previa — que e o unico lugar onde da para ver se a
    // curva ficou boa. Aqui ela ocupa a MESMA faixa das outras
    // ferramentas, e a previa continua a vista.
    if (ref.watch(curvaEmEdicaoProvider) != null) {
      return Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: PainelDaCamada.alturaMaxima,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            color: AmColors.panelHigh,
            border: Border(top: BorderSide(color: AmColors.hairline)),
          ),
          child: EditorDeCurva(),
        ),
      );
    }

    final estado = ref.watch(estadoDoPainelProvider);
    if (estado == EstadoDoPainel.recolhido) return const SizedBox.shrink();

    final project = ref.watch(editorControllerProvider);
    final id = ref.watch(selectedLayerProvider);
    final camada = project.layers.where((l) => l.id == id).firstOrNull;

    // A SELECAO E POR IDENTIDADE. Se a camada sumiu (exclusao,
    // desfazer), o painel se recolhe em vez de segurar uma referencia
    // morta.
    if (camada == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!ref.context.mounted) return;
        ref.read(estadoDoPainelProvider.notifier).state =
            EstadoDoPainel.recolhido;
        ref.read(categoriaAbertaProvider.notifier).state = null;
      });
      return const SizedBox.shrink();
    }

    final itens = categoriasDaCamada(camada).length;

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
        child: _Aberto(camada: camada, estado: estado, playback: playback),
      ),
    );
  }
}

/// ABRE AS FERRAMENTAS DA CAMADA SELECIONADA.
///
/// Chamado pelo toque na camada que JA esta selecionada, na pilha — que
/// e o caminho que sobrou depois de a faixa do rodape ser removida. E o
/// mesmo gesto do Alight: tocar na camada mostra o que da para fazer com
/// ela.
void abrirFerramentasDaCamada(WidgetRef ref) {
  ref.read(estadoDoPainelProvider.notifier).state = EstadoDoPainel.categorias;
  ref.read(categoriaAbertaProvider.notifier).state = null;
}

/// ABRE O FLUXO DE ADICAO: a barra de familias, em cima do `+`.
///
/// PAUSA ANTES, e guarda o instante AGORA. O lugar onde o conteudo novo
/// entra e o que a pessoa escolheu quando abriu o menu — assim que o
/// relogio anda, esse instante e o do toque deixam de ser a mesma coisa.
/// Pausar tambem evita o caso em que o cabecote passa por cima da camada
/// nova enquanto ela esta sendo criada.
void abrirAdicaoDeConteudo(WidgetRef ref, PlaybackController playback) {
  playback.pause();
  ref.read(instanteDeInsercaoProvider.notifier).state = playback.time.value;
  ref.read(estadoDoPainelProvider.notifier).state = EstadoDoPainel.recolhido;
  ref.read(barraDeAdicaoAbertaProvider.notifier).state = true;
}

/// A BARRA DE FAMILIAS ESTA ABERTA?
///
/// Vive aqui, e nao no widget, porque tres pecas em telas diferentes
/// precisam concordar sobre ela: o `+` (que a abre e fecha), a barra em
/// si, e o painel do meio (que so aparece por cima dela).
final barraDeAdicaoAbertaProvider = StateProvider<bool>((ref) => false);

class _Aberto extends ConsumerWidget {
  const _Aberto({
    required this.camada,
    required this.estado,
    required this.playback,
  });

  final Layer camada;
  final EstadoDoPainel estado;

  /// O RELOGIO DESCE ATE OS CONTROLES. Uma propriedade animada vale
  /// coisas diferentes em instantes diferentes, e o que o deslizante
  /// mostra tem de ser o que a previa mostra.
  final PlaybackController playback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aberta = ref.watch(categoriaAbertaProvider);
    final categorias = categoriasDaCamada(camada);
    final atual = categorias.where((c) => c.id == aberta).firstOrNull;
    final naCategoria = estado == EstadoDoPainel.categoria && atual != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // DENTRO DE UMA FERRAMENTA NAO HA CABECALHO AQUI.
        //
        // Ele existia e dizia "‹ Opacidade · Titulo principal". Virou
        // repeticao quando a barra da TELA passou a ser tomada pela
        // ferramenta aberta: o nome ja esta la em cima, e o `‹` ja esta
        // no rail. Duas linhas de 44 px dizendo a mesma coisa, num
        // painel de 300, e espaco tirado do controle.
        if (!naCategoria)
          _Cabecalho(camada: camada, categoria: null),
        Expanded(
          child: naCategoria
              ? ControlesDaCategoria(
                  categoriaId: atual.id,
                  camada: camada,
                  playback: playback,
                  aoVoltar: () {
                    ref.read(estadoDoPainelProvider.notifier).state =
                        EstadoDoPainel.categorias;
                    ref.read(categoriaAbertaProvider.notifier).state = null;
                  },
                )
              : _GradeDeCategorias(categorias: categorias),
        ),
      ],
    );
  }
}

/// O TITULO QUE A FERRAMENTA ABERTA DA AO CABECALHO DA TELA.
///
/// Na referencia, abrir uma ferramenta TOMA a barra de cima: o nome do
/// projeto sai e entra "Movimentacao e...", "Efeitos", "Curva de
/// gradacao". Nao e enfeite — e o que responde "onde eu estou" sem
/// gastar uma linha dentro do painel, que e onde falta espaco.
String tituloDaFerramenta(String categoriaId) => switch (categoriaId) {
  'transformar' => 'Movimentacao e transformacao',
  'opacidade' => 'Opacidade',
  'texto' => 'Texto',
  'forma' => 'Forma',
  'volume' => 'Volume',
  'efeitos' => 'Efeitos',
  'midia' => 'Informacoes da midia',
  'camada' => 'Camada',
  _ => 'Ferramentas',
};

/// A ALTURA QUE A FERRAMENTA ABERTA OCUPA, para a tela descontar.
///
/// Ela SOBREPOE o rodape, e o espaco dela sai do PREVIEW — nunca da
/// linha do tempo. Cobrir a linha do tempo esconderia o cabecote e o
/// clipe que se esta editando, que e justamente o que a pessoa olha
/// enquanto mexe no controle. Quem cede e a composicao, que so fica
/// menor.
double alturaDaFerramentaAberta(WidgetRef ref) {
  if (!ref.watch(painelDaCamadaLigadoProvider)) return 0;
  if (ref.watch(curvaEmEdicaoProvider) != null) {
    return PainelDaCamada.alturaMaxima;
  }
  final estado = ref.watch(estadoDoPainelProvider);
  if (estado == EstadoDoPainel.recolhido) return 0;
  if (estado == EstadoDoPainel.categoria) return PainelDaCamada.alturaMaxima;
  final project = ref.watch(editorControllerProvider);
  final id = ref.watch(selectedLayerProvider);
  final camada = project.layers.where((l) => l.id == id).firstOrNull;
  if (camada == null) return 0;
  return PainelDaCamada.alturaAberta(categoriasDaCamada(camada).length);
}

/// FECHA A FERRAMENTA e devolve a tela ao projeto.
///
/// E o que o `‹` do CABECALHO faz. O `‹` do rail esquerdo, dentro do
/// painel, e outro: aquele volta um nivel, para a grade de categorias.
/// Dois caminhos de volta porque sao duas perguntas diferentes — "sair
/// daqui" e "voltar um passo".
void fecharFerramenta(WidgetRef ref) {
  ref.read(estadoDoPainelProvider.notifier).state = EstadoDoPainel.recolhido;
  ref.read(categoriaAbertaProvider.notifier).state = null;
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
