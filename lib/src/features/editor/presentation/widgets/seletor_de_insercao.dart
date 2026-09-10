import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../application/freehand_session.dart';
import '../../../media/application/media_import_service.dart';
import '../../application/playback_controller.dart';
import '../../domain/element3d.dart';
import '../../domain/shape_library.dart';
import 'painel_da_camada.dart';

/// O SELETOR DE INSERCAO DO ALIGHT MOTION (V 00:02–00:16).
///
/// UMA moldura ancorada no rodape, com cinco abas fixas no topo e um
/// trilho fixo a direita. Antes eram DOIS artefatos empilhados: uma
/// barra flutuante de sete familias sobre o `+` e, por cima dela, um
/// modal CENTRADO com a tela desfocada atras. Dois estados de abertura
/// que davam para desincronizar, e um desfoque que escondia justamente a
/// composicao em que o conteudo novo vai entrar.
///
/// A ORDEM DAS ABAS E NORMATIVA (pagina 8): Forma, Midia, Audio,
/// Objeto / Elemento, Modelo. Cinco, sem rolagem — uma barra que rola
/// esconde o que existe atras da borda, e a primeira pergunta de quem
/// abre o `+` e "o que da para colocar aqui?".
enum AbaDeInsercao { forma, midia, audio, objeto, modelo }

String rotuloDaAba(AbaDeInsercao a) => switch (a) {
  AbaDeInsercao.forma => 'Forma',
  AbaDeInsercao.midia => 'Midia',
  AbaDeInsercao.audio => 'Audio',
  AbaDeInsercao.objeto => 'Objeto / Elemento',
  AbaDeInsercao.modelo => 'Modelo',
};

IconData _iconeDaAba(AbaDeInsercao a) => switch (a) {
  AbaDeInsercao.forma => Icons.category_rounded,
  AbaDeInsercao.midia => Icons.perm_media_rounded,
  AbaDeInsercao.audio => Icons.graphic_eq_rounded,
  AbaDeInsercao.objeto => Icons.view_in_ar_rounded,
  AbaDeInsercao.modelo => Icons.grid_view_rounded,
};

/// A aba ativa. Nasce em Forma, que e a aba aberta na referencia.
final abaDeInsercaoProvider = StateProvider<AbaDeInsercao>(
  (ref) => AbaDeInsercao.forma,
);

/// A sub-lista aberta DENTRO de uma aba (os elementos, por exemplo).
/// Nula quando a aba mostra o proprio corpo.
final subListaDeInsercaoProvider = StateProvider<String?>((ref) => null);

/// FECHA O SELETOR INTEIRO numa acao so.
///
/// Era isto que faltava: com dois artefatos, o X do modal fechava so o
/// modal e a barra de familias continuava aberta atras. Aqui nao ha dois
/// estados para desincronizar.
void fecharSeletor(WidgetRef ref) {
  ref.read(barraDeAdicaoAbertaProvider.notifier).state = false;
  ref.read(subListaDeInsercaoProvider.notifier).state = null;
  ref.read(abaDeInsercaoProvider.notifier).state = AbaDeInsercao.forma;
}

class SeletorDeInsercao extends ConsumerWidget {
  const SeletorDeInsercao({
    super.key,
    required this.instanteDeInsercao,
    required this.playback,
    required this.aoInserir,
  });

  /// O instante em que o conteudo novo entra: capturado quando o menu
  /// ABRE, e nao no toque do tipo — assim que o relogio anda, os dois
  /// deixam de ser a mesma coisa, e o lugar que a pessoa escolheu foi o
  /// de quando abriu.
  final Duration instanteDeInsercao;
  final PlaybackController playback;

  /// Chamado depois de criar. Quem fecha o fluxo e leva ao contexto do
  /// objeto novo e a tela.
  final VoidCallback aoInserir;

  /// A altura da moldura. A mesma do painel de camada: a area inferior e
  /// uma so, e trocar de altura entre "escolher o que criar" e "editar o
  /// que criei" faria a composicao pular no meio do fluxo.
  static const double altura = PainelDaCamada.alturaMaxima;

  static const double _alturaDasAbas = 46;
  static const double _larguraDoTrilho = 52;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(barraDeAdicaoAbertaProvider)) return const SizedBox.shrink();
    final aba = ref.watch(abaDeInsercaoProvider);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: altura,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AmColors.panelHigh,
          border: Border(top: BorderSide(color: AmColors.hairline)),
        ),
        child: Column(
          children: [
            _Abas(aba: aba),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // TROCAR A ABA SUBSTITUI APENAS O CORPO. O trilho, as
                  // abas e a moldura ficam onde estao.
                  Expanded(
                    child: _Corpo(
                      aba: aba,
                      em: instanteDeInsercao,
                      aoInserir: aoInserir,
                    ),
                  ),
                  const VerticalDivider(width: 1, color: AmColors.hairline),
                  SizedBox(
                    width: _larguraDoTrilho,
                    child: _Trilho(em: instanteDeInsercao, aoInserir: aoInserir),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// AS CINCO ABAS, largura repartida, sem rolagem.
class _Abas extends ConsumerWidget {
  const _Abas({required this.aba});

  final AbaDeInsercao aba;

  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
    height: SeletorDeInsercao._alturaDasAbas,
    child: Row(
      children: [
        for (final a in AbaDeInsercao.values)
          Expanded(
            child: Semantics(
              container: true,
              excludeSemantics: true,
              button: true,
              selected: a == aba,
              label: 'Inserir ${rotuloDaAba(a)}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  ref.read(abaDeInsercaoProvider.notifier).state = a;
                  ref.read(subListaDeInsercaoProvider.notifier).state = null;
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _iconeDaAba(a),
                      size: 19,
                      // O LIMA DA AUREA OCUPA O LUGAR DO VERDE DO AM: a
                      // estrutura se copia, a identidade nao.
                      color: a == aba ? AmColors.action : AmColors.muted,
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                          rotuloDaAba(a),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 9.5,
                            height: 1.1,
                            fontWeight: FontWeight.w600,
                            color: a == aba ? AmColors.action : AmColors.muted,
                          ),
                        ),
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

/// O TRILHO DA DIREITA: desenho a mao livre, desenho vetorial, texto e X.
///
/// Permanente entre as abas, como na referencia. TEXTO NAO E UMA
/// FAMILIA: ele estava numa aba propria com um unico item dentro —
/// exatamente o submenu generico que a pagina 8 proibe.
class _Trilho extends ConsumerWidget {
  const _Trilho({required this.em, required this.aoInserir});

  final Duration em;
  final VoidCallback aoInserir;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      // O DESENHO A MAO LIVRE ESTAVA IMPLEMENTADO E SEM PORTA: o
      // `FreehandOverlay` inteiro, com simplificacao do traco e criacao
      // da camada, nunca foi montado em tela nenhuma.
      _AlvoDoTrilho(
        icone: Icons.gesture_rounded,
        rotulo: 'Desenho a mao livre',
        aoTocar: () {
          fecharSeletor(ref);
          ref.read(freehandRequestProvider.notifier).state = true;
        },
      ),
      _AlvoDoTrilho(
        icone: Icons.polyline_rounded,
        rotulo: 'Desenho vetorial',
        aoTocar: () {
          fecharSeletor(ref);
          ref.read(desenhoVetorialProvider.notifier).state = true;
        },
      ),
      _AlvoDoTrilho(
        icone: Icons.title_rounded,
        rotulo: 'Texto',
        aoTocar: () {
          ref.read(editorControllerProvider.notifier).addTextLayer(em);
          aoInserir();
        },
      ),
      const Spacer(),
      // FECHAR NAO CRIA OBJETO NEM ALTERA O PROJETO.
      _AlvoDoTrilho(
        icone: Icons.close_rounded,
        rotulo: 'Fechar o seletor',
        aoTocar: () => fecharSeletor(ref),
      ),
    ],
  );
}

class _AlvoDoTrilho extends StatelessWidget {
  const _AlvoDoTrilho({
    required this.icone,
    required this.rotulo,
    required this.aoTocar,
  });

  final IconData icone;
  final String rotulo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    label: rotulo,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aoTocar,
      child: SizedBox(
        width: SeletorDeInsercao._larguraDoTrilho,
        height: 52,
        child: Icon(icone, size: 21, color: AmColors.text),
      ),
    ),
  );
}

class _Corpo extends ConsumerWidget {
  const _Corpo({required this.aba, required this.em, required this.aoInserir});

  final AbaDeInsercao aba;
  final Duration em;
  final VoidCallback aoInserir;

  @override
  Widget build(BuildContext context, WidgetRef ref) => switch (aba) {
    AbaDeInsercao.forma => _CatalogoDeFormas(em: em, aoInserir: aoInserir),
    AbaDeInsercao.midia => _Midia(em: em, aoInserir: aoInserir),
    AbaDeInsercao.audio => _Audio(em: em, aoInserir: aoInserir),
    AbaDeInsercao.objeto => _Objetos(em: em, aoInserir: aoInserir),
    AbaDeInsercao.modelo => const _Modelos(),
  };
}

/// O CATALOGO DE FORMAS: paginas de 3 x 5, com indicadores.
///
/// Os GLIFOS das proprias formas sao a referencia visual — nao icones
/// genericos do Material. A familia "Formas" antiga oferecia seis
/// parametricas desenhadas com `Icons.crop_square_rounded` e amigos,
/// enquanto `shapeLibrary` ja tinha trinta entradas com o caminho de
/// amostra pronto (`shapeLibraryPreviewPath`) e nenhuma porta.
class _CatalogoDeFormas extends ConsumerStatefulWidget {
  const _CatalogoDeFormas({required this.em, required this.aoInserir});

  final Duration em;
  final VoidCallback aoInserir;

  @override
  ConsumerState<_CatalogoDeFormas> createState() => _CatalogoDeFormasState();
}

class _CatalogoDeFormasState extends ConsumerState<_CatalogoDeFormas> {
  final _paginas = PageController();
  int _pagina = 0;

  static const _porPagina = 15;

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = (shapeLibrary.length + _porPagina - 1) ~/ _porPagina;
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _paginas,
            itemCount: total,
            onPageChanged: (i) => setState(() => _pagina = i),
            itemBuilder: (context, pagina) {
              final inicio = pagina * _porPagina;
              final fim = (inicio + _porPagina).clamp(0, shapeLibrary.length);
              return GridView.count(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: [
                  for (var i = inicio; i < fim; i++)
                    _TileDeForma(
                      entrada: shapeLibrary[i],
                      aoTocar: () {
                        ref
                            .read(editorControllerProvider.notifier)
                            .addShapeLayer(
                              widget.em,
                              contents: shapeLibrary[i].build(),
                              name: shapeLibrary[i].nome,
                            );
                        widget.aoInserir();
                      },
                    ),
                ],
              );
            },
          ),
        ),
        // OS INDICADORES DIZEM QUANTAS PAGINAS EXISTEM DE VERDADE.
        //
        // A referencia mostra cinco porque o catalogo de la tem cinco
        // paginas. Desenhar cinco aqui seria inventar tres paginas
        // vazias: o numero sai do catalogo, nao do desenho.
        SizedBox(
          height: 18,
          child: Semantics(
            container: true,
            excludeSemantics: true,
            label: 'Pagina ${_pagina + 1} de $total',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < total; i++)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _pagina ? AmColors.action : AmColors.chip,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TileDeForma extends StatelessWidget {
  const _TileDeForma({required this.entrada, required this.aoTocar});

  final ShapeLibraryEntry entrada;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final itens = entrada.build();
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      label: entrada.nome,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: aoTocar,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AmColors.chip,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: CustomPaint(
              painter: _PintorDaForma(
                caminho: shapeLibraryPreviewPath(itens),
                soTraco: shapeLibraryIsStrokeOnly(itens),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

class _PintorDaForma extends CustomPainter {
  const _PintorDaForma({required this.caminho, required this.soTraco});

  final Path caminho;
  final bool soTraco;

  @override
  void paint(Canvas canvas, Size size) {
    final b = caminho.getBounds();
    if (b.isEmpty) return;
    final k = (size.width / b.width) < (size.height / b.height)
        ? size.width / b.width
        : size.height / b.height;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(k);
    canvas.translate(-b.center.dx, -b.center.dy);
    canvas.drawPath(
      caminho,
      Paint()
        ..color = AmColors.text
        ..style = soTraco ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = 6 / k,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PintorDaForma old) =>
      old.caminho != caminho || old.soTraco != soTraco;
}

/// A ABA MIDIA: o que ja entrou neste aparelho, mais os dois caminhos
/// para trazer coisa nova.
///
/// "Recentes" mostra a pasta `imported_media` — a midia que a Aurea ja
/// copiou para si. E conteudo REAL do app; nao ha invencao de galeria
/// nenhuma. Trazer de fora continua passando pelo seletor do sistema,
/// que e quem tem permissao para ler o carretel.
class _Midia extends ConsumerStatefulWidget {
  const _Midia({required this.em, required this.aoInserir});

  final Duration em;
  final VoidCallback aoInserir;

  @override
  ConsumerState<_Midia> createState() => _MidiaState();
}

class _MidiaState extends ConsumerState<_Midia> {
  List<File>? _recentes;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final arquivos = await midiaRecente();
    if (mounted) setState(() => _recentes = arquivos);
  }

  bool _ehImagem(String caminho) {
    final p = caminho.toLowerCase();
    return p.endsWith('.png') ||
        p.endsWith('.jpg') ||
        p.endsWith('.jpeg') ||
        p.endsWith('.webp') ||
        p.endsWith('.gif');
  }

  @override
  Widget build(BuildContext context) {
    final c = ref.read(editorControllerProvider.notifier);
    final recentes = _recentes ?? const <File>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      children: [
        Row(
          children: [
            Expanded(
              child: _Entrada(
                icone: Icons.image_rounded,
                rotulo: 'Imagem',
                aoTocar: () async {
                  await c.importImageFromGallery(widget.em);
                  widget.aoInserir();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Entrada(
                icone: Icons.videocam_rounded,
                rotulo: 'Video',
                aoTocar: () async {
                  await c.importVideoFromGallery(widget.em);
                  widget.aoInserir();
                },
              ),
            ),
          ],
        ),
        const _Titulo('Recentes'),
        if (_recentes == null)
          const _Aviso('Procurando o que ja foi importado...')
        else if (recentes.isEmpty)
          const _Aviso(
            'Nada importado ainda. O que vier pela galeria aparece aqui '
            'na proxima vez.',
          )
        else
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 5,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (final f in recentes)
                _TileDeMidia(
                  arquivo: f,
                  imagem: _ehImagem(f.path),
                  aoTocar: () async {
                    final nome = f.path.split(RegExp(r'[\\/]')).last;
                    if (_ehImagem(f.path)) {
                      c.addImageLayer(widget.em, f.path, nome);
                    } else {
                      // A DURACAO VEM DO PROBE ANTES DE ENTRAR: um
                      // arquivo que ja esta no aparelho nao tem por que
                      // aparecer com quatro segundos provisorios.
                      await c.importVideoAwaitingDuration(
                        widget.em,
                        f.path,
                        nome,
                      );
                    }
                    widget.aoInserir();
                  },
                ),
            ],
          ),
      ],
    );
  }
}

class _TileDeMidia extends StatelessWidget {
  const _TileDeMidia({
    required this.arquivo,
    required this.imagem,
    required this.aoTocar,
  });

  final File arquivo;
  final bool imagem;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    label: arquivo.path.split(RegExp(r'[\\/]')).last,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aoTocar,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: ColoredBox(
          color: AmColors.chip,
          child: imagem
              ? Image.file(
                  arquivo,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.broken_image_rounded,
                    size: 18,
                    color: AmColors.muted,
                  ),
                )
              : const Icon(
                  Icons.movie_rounded,
                  size: 20,
                  color: AmColors.muted,
                ),
        ),
      ),
    ),
  );
}

class _Audio extends ConsumerWidget {
  const _Audio({required this.em, required this.aoInserir});

  final Duration em;
  final VoidCallback aoInserir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(editorControllerProvider.notifier);
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      children: [
        _Entrada(
          icone: Icons.library_music_rounded,
          rotulo: 'Ver todos',
          aoTocar: () async {
            await c.importAudioFile(em);
            aoInserir();
          },
        ),
        const SizedBox(height: 8),
        _Entrada(
          icone: Icons.audio_file_rounded,
          rotulo: 'Arquivo',
          aoTocar: () async {
            await c.importAudioFile(em);
            aoInserir();
          },
        ),
        const SizedBox(height: 8),
        _Entrada(
          icone: Icons.movie_filter_rounded,
          rotulo: 'De um video',
          aoTocar: () async {
            await c.importAudioFile(em, fromVideo: true);
            aoInserir();
          },
        ),
      ],
    );
  }
}

/// A ABA OBJETO / ELEMENTO: grade 2 x 2 (V 00:08).
///
/// Camera, Grupo Vazio, Nulo e Elemento / Projeto. Os objetos entram
/// pelo seletor de insercao, sem trocar o editor por uma nova area de
/// trabalho — que e a regra que a pagina 10 poe em letra grande.
class _Objetos extends ConsumerWidget {
  const _Objetos({required this.em, required this.aoInserir});

  final Duration em;
  final VoidCallback aoInserir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(editorControllerProvider.notifier);
    final sub = ref.watch(subListaDeInsercaoProvider);
    if (sub == 'elemento') {
      return _Elementos(em: em, aoInserir: aoInserir);
    }
    return GridView.count(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      crossAxisCount: 2,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 2.1,
      children: [
        _Entrada(
          icone: Icons.videocam_rounded,
          rotulo: 'Camera',
          aoTocar: () {
            c.addCameraLayer(em);
            aoInserir();
          },
        ),
        _Entrada(
          icone: Icons.folder_open_rounded,
          rotulo: 'Grupo Vazio',
          aoTocar: () {
            c.addEmptyGroup(em);
            aoInserir();
          },
        ),
        _Entrada(
          icone: Icons.control_camera_rounded,
          rotulo: 'Nulo',
          aoTocar: () {
            c.addNullLayer(em);
            aoInserir();
          },
        ),
        _Entrada(
          icone: Icons.category_outlined,
          rotulo: 'Elemento / Projeto',
          aoTocar: () =>
              ref.read(subListaDeInsercaoProvider.notifier).state = 'elemento',
        ),
      ],
    );
  }
}

/// OS ELEMENTOS DA AUREA, dentro da familia contextual que lhes cabe.
///
/// Cena 3D, objetos 3D, particulas e camada de ajuste sao EXTENSOES do
/// Aurea: o Alight Motion nao tem nenhuma delas. A especificacao manda
/// dar-lhes acesso na familia correspondente, identificado como extensao
/// — e nao esconde-las para o inventario ficar menor.
class _Elementos extends ConsumerWidget {
  const _Elementos({required this.em, required this.aoInserir});

  final Duration em;
  final VoidCallback aoInserir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(editorControllerProvider.notifier);
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      children: [
        Row(
          children: [
            Semantics(
              container: true,
              excludeSemantics: true,
              button: true,
              label: 'Voltar aos objetos',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () =>
                    ref.read(subListaDeInsercaoProvider.notifier).state = null,
                child: const SizedBox(
                  width: 40,
                  height: 34,
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 15,
                    color: AmColors.text,
                  ),
                ),
              ),
            ),
            const Expanded(
              child: Text(
                'Elementos da Aurea',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AmColors.text,
                ),
              ),
            ),
          ],
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.1,
          children: [
            _Entrada(
              icone: Icons.deblur_rounded,
              rotulo: 'Cena 3D',
              aoTocar: () {
                c.addScene3DLayer(em);
                aoInserir();
              },
            ),
            _Entrada(
              icone: Icons.grain_rounded,
              rotulo: 'Particulas',
              aoTocar: () {
                c.addParticlesLayer(em);
                aoInserir();
              },
            ),
            _Entrada(
              icone: Icons.tune_rounded,
              rotulo: 'Camada de ajuste',
              aoTocar: () {
                c.addAdjustmentLayer(em);
                aoInserir();
              },
            ),
            _Entrada(
              icone: Icons.movie_creation_outlined,
              rotulo: 'Grupo (pre-composicao)',
              aoTocar: () {
                c.addEmptyGroup(em);
                aoInserir();
              },
            ),
          ],
        ),
        const _Titulo('Objetos 3D'),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 5,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [
            for (final k in Element3DKind.values)
              _TileCompacto(
                icone: Icons.view_in_ar_rounded,
                rotulo: element3DLabel(k),
                aoTocar: () {
                  c.addElement3DLayer(em, k);
                  aoInserir();
                },
              ),
          ],
        ),
      ],
    );
  }
}

/// A ABA MODELO: os modelos que a Aurea tem de verdade.
///
/// A referencia mostra "Ver todos" e "Descobrir mais modelos" com um
/// cracha NEW. O cracha NAO entra: ele so existiria com uma regra real
/// de novidade por tras, e inventa-lo seria decorar a tela com uma
/// promessa vazia.
class _Modelos extends ConsumerWidget {
  const _Modelos();

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
    children: [
      const _Aviso(
        'Os modelos da Aurea comecam um projeto novo, e nao uma camada. '
        'Eles vivem na tela de projetos.',
      ),
      const SizedBox(height: 8),
      _Entrada(
        icone: Icons.grid_view_rounded,
        rotulo: 'Ver todos',
        aoTocar: () {
          fecharSeletor(ref);
          Navigator.of(ref.context).popUntil((r) => r.isFirst);
        },
      ),
    ],
  );
}

class _Entrada extends StatelessWidget {
  const _Entrada({
    required this.icone,
    required this.rotulo,
    required this.aoTocar,
  });

  final IconData icone;
  final String rotulo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    label: rotulo,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aoTocar,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: AmColors.chip,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(icone, size: 19, color: AmColors.text),
            const SizedBox(width: 10),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  rotulo,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AmColors.text,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
        ),
      ),
    ),
  );
}

class _TileCompacto extends StatelessWidget {
  const _TileCompacto({
    required this.icone,
    required this.rotulo,
    required this.aoTocar,
  });

  final IconData icone;
  final String rotulo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    label: rotulo,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aoTocar,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AmColors.chip,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 18, color: AmColors.text),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  rotulo,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 8.5,
                    color: AmColors.muted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 12, 2, 6),
    child: Text(
      texto,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AmColors.muted,
      ),
    ),
  );
}

class _Aviso extends StatelessWidget {
  const _Aviso(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
    child: Text(
      texto,
      style: const TextStyle(
        fontSize: 11,
        height: 1.3,
        color: AmColors.muted,
      ),
    ),
  );
}
