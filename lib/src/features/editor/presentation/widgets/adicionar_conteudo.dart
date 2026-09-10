import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../domain/element3d.dart';
import '../../domain/shape.dart';

/// O QUE DA PARA CRIAR, arrumado em DOIS niveis.
///
/// O primeiro nivel e a familia — 3D, Texto, Formas, Imagens, Videos,
/// Audio, Ferramentas — e mora numa barra de icones que abre em cima do
/// `+`. O segundo e o que a familia tem dentro, e abre num painel no
/// meio da tela.
///
/// Dois niveis, e nao uma lista so, porque a lista so ja passa de vinte
/// itens e vai crescer: um grid de vinte icones sem agrupamento e uma
/// caca ao tesouro. Agrupado, quem procura um cubo olha o cubo.
///
/// TUDO AQUI E COMANDO QUE EXISTE no `EditorController`. Nada de item
/// aceso que abre o nada — o que ainda nao tem caminho aparece apagado e
/// diz por que.
@immutable
class ItemDeAdicao {
  const ItemDeAdicao({
    required this.id,
    required this.rotulo,
    required this.icone,
    this.criar,
    this.filhos,
    this.porQueNao,
  });

  final String id;
  final String rotulo;
  final IconData icone;

  /// Cria a camada NO INSTANTE dado. Assincrono quando o caminho passa
  /// pelo seletor do sistema (imagem, video, audio) — quem chama espera,
  /// para saber quando fechar o painel.
  final FutureOr<void> Function(EditorController c, Duration em)? criar;

  /// Quando existe, o toque nao cria nada: abre MAIS UM nivel dentro do
  /// mesmo painel. E o caso dos objetos 3D, que sao dezessete.
  final List<ItemDeAdicao>? filhos;

  /// Preenchido quando o item existe no desenho mas ainda nao no app.
  final String? porQueNao;

  bool get disponivel => criar != null || (filhos?.isNotEmpty ?? false);
}

@immutable
class CategoriaDeAdicao {
  const CategoriaDeAdicao({
    required this.id,
    required this.rotulo,
    required this.icone,
    required this.itens,
  });

  final String id;
  final String rotulo;

  /// O ICONE E A FAMILIA INTEIRA. Todo o 3D do app cabe atras de um
  /// cubo; toda a midia de som, atras de uma onda.
  final IconData icone;
  final List<ItemDeAdicao> itens;
}

/// UM GLIFO POR PRIMITIVA.
///
/// Dezessete cartoes com o mesmo icone nao sao icones: sao dezessete
/// rotulos com uma decoracao igual em cima. O conjunto do Material nao
/// tem solidos 3D, entao cada primitiva pegou o glifo cuja SILHUETA
/// mais se parece com ela vista de frente — um cone e um triangulo, uma
/// esfera e um circulo, uma rampa e um triangulo retangulo.
///
/// Onde nem isso existe, o glifo repete de proposito dentro da mesma
/// familia de formato (coroa e coroa fina), porque duas coisas parecidas
/// devem parecer parecidas.
IconData _icone3D(Element3DKind k) => switch (k) {
  Element3DKind.cube => Icons.view_in_ar_rounded,
  Element3DKind.pyramid => Icons.change_history_rounded,
  Element3DKind.cone => Icons.details_rounded,
  Element3DKind.sphere => Icons.circle_outlined,
  Element3DKind.cylinder => Icons.crop_portrait_rounded,
  Element3DKind.prism => Icons.hexagon_outlined,
  Element3DKind.diamond => Icons.diamond_outlined,
  Element3DKind.torus => Icons.donut_large_rounded,
  Element3DKind.star => Icons.star_outline_rounded,
  Element3DKind.plane => Icons.crop_landscape_rounded,
  Element3DKind.capsule => Icons.crop_16_9_rounded,
  Element3DKind.tube => Icons.panorama_vertical_outlined,
  Element3DKind.octahedron => Icons.diamond_rounded,
  Element3DKind.wedge => Icons.signal_cellular_alt_rounded,
  Element3DKind.dome => Icons.brightness_3_rounded,
  Element3DKind.crown => Icons.workspace_premium_outlined,
  Element3DKind.crownFine => Icons.workspace_premium_rounded,
};

List<ItemDeAdicao> _objetos3D() => [
  for (final k in Element3DKind.values)
    ItemDeAdicao(
      id: 'obj3d-${k.name}',
      rotulo: element3DLabel(k),
      icone: _icone3D(k),
      criar: (c, em) => c.addElement3DLayer(em, k),
    ),
];

final categoriasDeAdicao = <CategoriaDeAdicao>[
  CategoriaDeAdicao(
    id: '3d',
    rotulo: '3D',
    icone: Icons.view_in_ar_rounded,
    itens: [
      ItemDeAdicao(
        id: 'cena3d',
        rotulo: 'Cena 3D',
        icone: Icons.deblur_rounded,
        criar: (c, em) => c.addScene3DLayer(em),
      ),
      ItemDeAdicao(
        id: 'nulo3d',
        rotulo: 'Nulo 3D',
        icone: Icons.control_camera_rounded,
        criar: (c, em) => c.addNullLayer(em),
      ),
      ItemDeAdicao(
        id: 'objetos3d',
        rotulo: 'Objetos 3D',
        icone: Icons.view_in_ar_outlined,
        filhos: _objetos3D(),
      ),
      ItemDeAdicao(
        id: 'particulas',
        rotulo: 'Particulas',
        icone: Icons.grain_rounded,
        criar: (c, em) => c.addParticlesLayer(em),
      ),
    ],
  ),
  CategoriaDeAdicao(
    id: 'texto',
    rotulo: 'Texto',
    icone: Icons.text_fields_rounded,
    itens: [
      ItemDeAdicao(
        id: 'texto',
        rotulo: 'Texto',
        icone: Icons.text_fields_rounded,
        criar: (c, em) => c.addTextLayer(em),
      ),
    ],
  ),
  CategoriaDeAdicao(
    id: 'formas',
    rotulo: 'Formas',
    icone: Icons.category_rounded,
    itens: [
      ItemDeAdicao(
        id: 'retangulo',
        rotulo: 'Retangulo',
        icone: Icons.crop_square_rounded,
        criar: (c, em) =>
            c.addShapeLayer(em, contents: ShapePresets.paramRect()),
      ),
      ItemDeAdicao(
        id: 'elipse',
        rotulo: 'Elipse',
        icone: Icons.circle_outlined,
        criar: (c, em) =>
            c.addShapeLayer(em, contents: ShapePresets.paramEllipse()),
      ),
      ItemDeAdicao(
        id: 'poligono',
        rotulo: 'Poligono',
        icone: Icons.hexagon_outlined,
        criar: (c, em) =>
            c.addShapeLayer(em, contents: ShapePresets.paramPolygon()),
      ),
      ItemDeAdicao(
        id: 'estrela',
        rotulo: 'Estrela',
        icone: Icons.star_outline_rounded,
        criar: (c, em) =>
            c.addShapeLayer(em, contents: ShapePresets.paramStar()),
      ),
      ItemDeAdicao(
        id: 'setor',
        rotulo: 'Setor',
        icone: Icons.pie_chart_outline_rounded,
        criar: (c, em) =>
            c.addShapeLayer(em, contents: ShapePresets.paramSector()),
      ),
      ItemDeAdicao(
        id: 'anel',
        rotulo: 'Anel',
        icone: Icons.donut_large_rounded,
        criar: (c, em) =>
            c.addShapeLayer(em, contents: ShapePresets.paramRing()),
      ),
    ],
  ),
  CategoriaDeAdicao(
    id: 'imagens',
    rotulo: 'Imagens',
    icone: Icons.image_rounded,
    itens: [
      ItemDeAdicao(
        id: 'imagem-galeria',
        rotulo: 'Da galeria',
        icone: Icons.photo_library_rounded,
        criar: (c, em) => c.importImageFromGallery(em),
      ),
    ],
  ),
  CategoriaDeAdicao(
    id: 'videos',
    rotulo: 'Videos',
    icone: Icons.videocam_rounded,
    itens: [
      ItemDeAdicao(
        id: 'video-galeria',
        rotulo: 'Da galeria',
        icone: Icons.video_library_rounded,
        criar: (c, em) => c.importVideoFromGallery(em),
      ),
    ],
  ),
  CategoriaDeAdicao(
    id: 'audio',
    rotulo: 'Audio',
    icone: Icons.graphic_eq_rounded,
    itens: [
      ItemDeAdicao(
        id: 'audio-arquivo',
        rotulo: 'Arquivo',
        icone: Icons.audio_file_rounded,
        criar: (c, em) => c.importAudioFile(em),
      ),
      ItemDeAdicao(
        id: 'audio-de-video',
        rotulo: 'De um video',
        icone: Icons.movie_filter_rounded,
        criar: (c, em) => c.importAudioFile(em, fromVideo: true),
      ),
    ],
  ),
  CategoriaDeAdicao(
    id: 'ferramentas',
    rotulo: 'Ferramentas',
    icone: Icons.build_rounded,
    itens: [
      ItemDeAdicao(
        id: 'ajuste',
        rotulo: 'Camada de ajuste',
        icone: Icons.tune_rounded,
        criar: (c, em) => c.addAdjustmentLayer(em),
      ),
    ],
  ),
];

/// A CATEGORIA ABERTA no painel do meio, e o item aberto DENTRO dela.
///
/// Nulos quando o painel do meio esta fechado. Dois provedores, e nao um
/// caminho de lista, porque so ha dois niveis — uma lista atrairia um
/// terceiro sem ninguem decidir que ele deve existir.
final categoriaDeAdicaoProvider = StateProvider<String?>((ref) => null);
final subItemDeAdicaoProvider = StateProvider<String?>((ref) => null);

void fecharAdicao(WidgetRef ref) {
  ref.read(categoriaDeAdicaoProvider.notifier).state = null;
  ref.read(subItemDeAdicaoProvider.notifier).state = null;
}

/// A BARRA DE FAMILIAS, que abre em cima do `+`.
///
/// So icones. O rotulo embaixo e minusculo de proposito: quem ja sabe le
/// o icone, quem nao sabe le a palavra, e nenhum dos dois paga o preco
/// do outro.
class BarraDeCategoriasDeAdicao extends ConsumerWidget {
  const BarraDeCategoriasDeAdicao({super.key, required this.aoEscolher});

  final void Function(String categoria) aoEscolher;

  static const altura = 66.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Container(
    height: altura,
    decoration: BoxDecoration(
      color: AmColors.panelHigh,
      borderRadius: BorderRadius.circular(altura / 2),
      border: Border.all(color: AmColors.hairline),
    ),
    child: ListView(
      // A BARRA ROLA. Sete familias hoje, mais amanha — e uma barra que
      // aperta os icones ate ninguem acertar o dedo e pior que uma que
      // rola.
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      children: [
        for (final c in categoriasDeAdicao)
          Semantics(
            container: true,
            excludeSemantics: true,
            button: true,
            label: 'Adicionar ${c.rotulo}',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => aoEscolher(c.id),
              child: SizedBox(
                width: 62,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(c.icone, size: 24, color: AmColors.text),
                    const SizedBox(height: 4),
                    Text(
                      c.rotulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.1,
                        color: AmColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

/// O PAINEL DO MEIO, com o resto da tela desfocado.
///
/// Ele cobre a tela inteira de proposito: escolher o que criar e uma
/// decisao, e enquanto ela esta aberta nao ha o que fazer atras. O
/// desfoque diz isso sem apagar o contexto — da para ver qual projeto
/// esta embaixo.
///
/// O DESFOQUE CUSTA UM PASSE DE GPU, e por isso a reproducao para antes
/// de ele aparecer: desfocar sessenta quadros por segundo de composicao
/// seria pagar caro por um fundo que ninguem esta olhando.
class PainelCentralDeAdicao extends ConsumerWidget {
  const PainelCentralDeAdicao({
    super.key,
    required this.instanteDeInsercao,
    required this.aoAdicionar,
  });

  final Duration instanteDeInsercao;

  /// Chamado depois de criar, com o id da familia. Quem fecha o fluxo e
  /// a tela — este painel nao sabe o que mais precisa ser recolhido.
  final void Function(String categoria, String item) aoAdicionar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final idCategoria = ref.watch(categoriaDeAdicaoProvider);
    if (idCategoria == null) return const SizedBox.shrink();
    final categoria = categoriasDeAdicao
        .where((c) => c.id == idCategoria)
        .firstOrNull;
    if (categoria == null) return const SizedBox.shrink();

    final idSub = ref.watch(subItemDeAdicaoProvider);
    final sub = idSub == null
        ? null
        : categoria.itens.where((i) => i.id == idSub).firstOrNull;
    final itens = sub?.filhos ?? categoria.itens;
    final titulo = sub?.rotulo ?? categoria.rotulo;

    return Positioned.fill(
      child: Stack(
        children: [
          // O FUNDO INTEIRO E O BOTAO DE FECHAR. Tocar fora e o gesto
          // que a mao faz sozinha para desistir.
          Positioned.fill(
            child: Semantics(
              container: true,
              excludeSemantics: true,
              button: true,
              label: 'Fechar',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => fecharAdicao(ref),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: ColoredBox(color: Colors.black.withValues(alpha: .45)),
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 340,
                  maxHeight: 420,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AmColors.panelHigh,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AmColors.hairline),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Cabecalho(
                        titulo: titulo,
                        // O VOLTAR SO EXISTE QUANDO HA PARA ONDE.
                        aoVoltar: sub == null
                            ? null
                            : () =>
                                  ref
                                          .read(
                                            subItemDeAdicaoProvider.notifier,
                                          )
                                          .state =
                                      null,
                        aoFechar: () => fecharAdicao(ref),
                      ),
                      Flexible(
                        child: GridView.count(
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                          shrinkWrap: true,
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: .92,
                          children: [
                            for (final item in itens)
                              _Cartao(
                                item: item,
                                aoTocar: () async {
                                  if (item.filhos != null) {
                                    ref
                                            .read(
                                              subItemDeAdicaoProvider.notifier,
                                            )
                                            .state =
                                        item.id;
                                    return;
                                  }
                                  final criar = item.criar;
                                  if (criar == null) return;
                                  await criar(
                                    ref.read(editorControllerProvider.notifier),
                                    instanteDeInsercao,
                                  );
                                  aoAdicionar(categoria.id, item.id);
                                },
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
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  const _Cabecalho({
    required this.titulo,
    required this.aoVoltar,
    required this.aoFechar,
  });

  final String titulo;
  final VoidCallback? aoVoltar;
  final VoidCallback aoFechar;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Row(
      children: [
        if (aoVoltar != null)
          Semantics(
            container: true,
            excludeSemantics: true,
            button: true,
            label: 'Voltar',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: aoVoltar,
              child: const SizedBox(
                width: 44,
                height: 48,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: AmColors.text,
                ),
              ),
            ),
          )
        else
          const SizedBox(width: 16),
        Expanded(
          child: Text(
            titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AmColors.text,
            ),
          ),
        ),
        Semantics(
          container: true,
          excludeSemantics: true,
          button: true,
          label: 'Fechar o menu',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: aoFechar,
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(Icons.close_rounded, size: 20, color: AmColors.muted),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Cartao extends StatelessWidget {
  const _Cartao({required this.item, required this.aoTocar});

  final ItemDeAdicao item;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: item.disponivel,
    enabled: item.disponivel,
    label: item.rotulo,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: item.disponivel ? aoTocar : null,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AmColors.chip,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.icone,
              size: 26,
              color: item.disponivel
                  ? AmColors.text
                  : AmColors.muted.withValues(alpha: .5),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                item.rotulo,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  color: item.disponivel
                      ? AmColors.text
                      : AmColors.muted.withValues(alpha: .6),
                ),
              ),
            ),
            // O MOTIVO FICA NO CARTAO. Um controle apagado sem
            // explicacao vira suspeita de defeito.
            if (!item.disponivel && item.porQueNao != null)
              Padding(
                padding: const EdgeInsets.only(top: 3, left: 6, right: 6),
                child: Text(
                  item.porQueNao!,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    color: AmColors.muted.withValues(alpha: .5),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
