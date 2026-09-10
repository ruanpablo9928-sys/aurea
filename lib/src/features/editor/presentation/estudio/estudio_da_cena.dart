import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../application/playback_controller.dart';
import '../../domain/camera3d.dart';
import '../../domain/estudio_ux.dart';
import '../../domain/layer.dart';
import 'estado_do_estudio.dart';
import 'ficha_do_selecionado.dart';
import 'folhas_do_estudio.dart';
import 'gizmo_de_vista.dart';
import 'vista_da_cena.dart';

/// Abre o Estudio da Cena por cima do editor.
Future<void> abrirEstudioDaCena(
  BuildContext context, {
  required String layerId,
  required PlaybackController playback,
}) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => EstudioDaCena(layerId: layerId, playback: playback),
  ),
);

/// O ESTUDIO DA CENA 3D.
///
/// Uma tela inteira, e nao um painel de 300 px, porque o que ela mostra
/// e um ESPACO: julgar profundidade, enquadramento e luz numa faixa de
/// rodape nao e possivel. O desenho esta em `docs/estudio-da-cena.md`.
///
/// Tres niveis, nesta ordem:
///
///   ESSENCIAL   voltar, a camera no ar, a vista, as quatro ferramentas
///               e o `+` — sempre na tela, sem toque nenhum
///   CONTEXTUAL  o nome do selecionado e as acoes dele — so existe
///               quando ha selecao
///   AVANCADO    mundo, render, vistas, encaixe, eixo e a ficha inteira
///               — atras de UM toque nomeado, nunca de quatro
class EstudioDaCena extends ConsumerStatefulWidget {
  const EstudioDaCena({
    super.key,
    required this.layerId,
    required this.playback,
  });

  final String layerId;
  final PlaybackController playback;

  @override
  ConsumerState<EstudioDaCena> createState() => _EstudioDaCenaState();
}

class _EstudioDaCenaState extends ConsumerState<EstudioDaCena> {
  final _navegacao = NavegacaoDaVista();
  final _vista = GlobalKey<VistaDaCenaState>();

  @override
  void initState() {
    super.initState();
    widget.playback.pause();
  }

  @override
  void dispose() {
    _navegacao.dispose();
    super.dispose();
  }

  void _dizer(String texto) =>
      ref.read(recadoDoEstudioProvider.notifier).state = texto;

  @override
  Widget build(BuildContext context) {
    final projeto = ref.watch(projetoVisivelProvider);
    final bruta = projeto.layerById(widget.layerId);
    if (bruta is! Scene3DLayer) {
      // A camada sumiu por baixo (desfazer, exclusao): sair e a unica
      // resposta honesta — um estudio de uma cena que nao existe mais
      // mostraria um retrato.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return const Scaffold(backgroundColor: AmColors.bg, body: SizedBox());
    }
    final camada = bruta;

    return Scaffold(
      backgroundColor: AmColors.bg,
      body: SafeArea(
        child: ValueListenableBuilder<Duration>(
          valueListenable: widget.playback.time,
          builder: (context, tempo, _) {
            final local = camada.localTime(tempo);
            return Column(
              children: [
                _BarraDeCima(
                  camada: camada,
                  local: local,
                  navegacao: _navegacao,
                  playback: widget.playback,
                  aoVoltar: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: VistaDaCena(
                          key: _vista,
                          layerId: widget.layerId,
                          navegacao: _navegacao,
                          tempo: tempo,
                          aoTocarVazio: () {},
                        ),
                      ),
                      // O GIZMO DE VISTA: seis faces, um toque cada.
                      // "Nao depender apenas de gestos" e um pedido
                      // explicito — orbitar com o dedo continua valendo,
                      // mas nao pode ser o unico caminho.
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: GizmoDeVista(
                          navegacao: _navegacao,
                          camera: cameraNoAr(camada, local),
                          tempo: local,
                        ),
                      ),
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: _BotaoDeFocar(
                          temSelecao:
                              ref.watch(noSelecionadoProvider) != null,
                          aoTocar: () =>
                              _vista.currentState?.focar(),
                        ),
                      ),
                      const Positioned(
                        left: 0,
                        right: 0,
                        top: 8,
                        child: _Recado(),
                      ),
                    ],
                  ),
                ),
                _FaixaDeTempo(playback: widget.playback, camada: camada),
                BarraDeContexto(
                  layerId: widget.layerId,
                  camada: camada,
                  tempo: tempo,
                  aoFocar: () => _vista.currentState?.focar(),
                ),
                _BarraDeFerramentas(
                  layerId: widget.layerId,
                  tempo: tempo,
                  navegacao: _navegacao,
                  aoAvisar: _dizer,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// `← Cena | Camera ▾ | ⋮`
class _BarraDeCima extends ConsumerWidget {
  const _BarraDeCima({
    required this.camada,
    required this.local,
    required this.navegacao,
    required this.playback,
    required this.aoVoltar,
  });

  final Scene3DLayer camada;
  final Duration local;
  final NavegacaoDaVista navegacao;
  final PlaybackController playback;
  final VoidCallback aoVoltar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noAr = cameraNoAr(camada, local);
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          _IconeDaBarra(
            icone: Icons.chevron_left_rounded,
            rotulo: 'Sair do estudio',
            aoTocar: aoVoltar,
          ),
          const Text(
            'Cena',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AmColors.text,
            ),
          ),
          const Spacer(),
          // A CAMERA A UM TOQUE. Trocar de camera e a acao mais repetida
          // de qualquer trabalho 3D, e ela estava a cinco toques.
          AnimatedBuilder(
            animation: navegacao,
            builder: (context, _) => Semantics(
              container: true,
              excludeSemantics: true,
              button: true,
              label: 'Camera: ${navegacao.pelaCamera ? noAr.name : sceneViewLabel(navegacao.vista)}',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => abrirFolhaDeCameras(
                  context,
                  ref,
                  layerId: camada.id,
                  navegacao: navegacao,
                  tempo: playback.time.value,
                ),
                child: Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AmColors.chip,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        navegacao.pelaCamera
                            ? Icons.videocam_rounded
                            : Icons.grid_view_rounded,
                        size: 16,
                        color: AmColors.accent,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        navegacao.pelaCamera
                            ? noAr.name
                            : sceneViewLabel(navegacao.vista),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AmColors.text,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.expand_more_rounded,
                        size: 16,
                        color: AmColors.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          _IconeDaBarra(
            icone: Icons.more_vert_rounded,
            rotulo: 'Mais do estudio',
            aoTocar: () => abrirFolhaDeMais(
              context,
              ref,
              layerId: camada.id,
              navegacao: navegacao,
              tempo: playback.time.value,
            ),
          ),
        ],
      ),
    );
  }
}

/// FOCAR: um toque enquadra o selecionado. Sem selecao, a cena inteira.
class _BotaoDeFocar extends StatelessWidget {
  const _BotaoDeFocar({required this.temSelecao, required this.aoTocar});

  final bool temSelecao;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    label: temSelecao ? 'Focar no selecionado' : 'Enquadrar a cena',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aoTocar,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AmColors.panelHigh.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AmColors.hairline),
        ),
        child: Row(
          children: [
            Icon(
              Icons.center_focus_strong_rounded,
              size: 17,
              color: temSelecao ? AmColors.accent : AmColors.muted,
            ),
            const SizedBox(width: 7),
            Text(
              temSelecao ? 'Focar' : 'Tudo',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AmColors.text,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// O recado da ultima acao — "Cubo criado", "Camera trocada".
class _Recado extends ConsumerWidget {
  const _Recado();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texto = ref.watch(recadoDoEstudioProvider);
    if (texto == null) return const SizedBox.shrink();
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AmColors.panelHigh.withValues(alpha: .95),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AmColors.hairline),
        ),
        child: Text(
          texto,
          style: const TextStyle(fontSize: 12, color: AmColors.text),
        ),
      ),
    );
  }
}

/// A FAIXA DE TEMPO: sem ela nao ha como cravar duas marcas.
///
/// Nao e a linha do tempo do editor — e um cabecote para andar dentro
/// da cena e uma regua de onde estao as marcas do que esta selecionado.
class _FaixaDeTempo extends ConsumerWidget {
  const _FaixaDeTempo({required this.playback, required this.camada});

  final PlaybackController playback;
  final Scene3DLayer camada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dur = camada.duration.inMicroseconds.toDouble();
    if (dur <= 0) return const SizedBox.shrink();
    final tempo = playback.time.value;
    final local = camada.localTime(tempo).inMicroseconds.toDouble();
    final marcas = marcasDaSelecao(ref, camada);

    return SizedBox(
      height: 38,
      child: Semantics(
        container: true,
        excludeSemantics: true,
        slider: true,
        label: 'Tempo da cena',
        value: '${(local / 1000000).toStringAsFixed(2)} s',
        child: LayoutBuilder(
          builder: (context, c) {
            void irPara(double dx) {
              final f = (dx / c.maxWidth).clamp(0.0, 1.0);
              playback.seek(
                camada.startTime +
                    Duration(microseconds: (f * dur).round()),
              );
            }

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => irPara(d.localPosition.dx),
              onHorizontalDragUpdate: (d) => irPara(d.localPosition.dx),
              child: CustomPaint(
                painter: _PinturaDoTempo(
                  fracao: (local / dur).clamp(0.0, 1.0),
                  marcas: [
                    for (final m in marcas)
                      (m.inMicroseconds / dur).clamp(0.0, 1.0),
                  ],
                ),
                child: const SizedBox.expand(),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PinturaDoTempo extends CustomPainter {
  const _PinturaDoTempo({required this.fracao, required this.marcas});

  final double fracao;
  final List<double> marcas;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    canvas.drawLine(
      Offset(10, y),
      Offset(size.width - 10, y),
      Paint()
        ..color = AmColors.hairline
        ..strokeWidth = 2,
    );
    final util = size.width - 20;
    for (final m in marcas) {
      final x = 10 + m * util;
      canvas.drawCircle(
        Offset(x, y),
        4,
        Paint()..color = AmColors.accent,
      );
    }
    final x = 10 + fracao * util;
    canvas.drawLine(
      Offset(x, 6),
      Offset(x, size.height - 6),
      Paint()
        ..color = AmColors.cabecote
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_PinturaDoTempo o) =>
      o.fracao != fracao || o.marcas.length != marcas.length;
}

/// `Selecionar | Mover | Girar | Escalar | +`
class _BarraDeFerramentas extends ConsumerWidget {
  const _BarraDeFerramentas({
    required this.layerId,
    required this.tempo,
    required this.navegacao,
    required this.aoAvisar,
  });

  final String layerId;
  final Duration tempo;
  final NavegacaoDaVista navegacao;
  final void Function(String) aoAvisar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final atual = ref.watch(ferramentaProvider);
    return Container(
      height: 62,
      decoration: const BoxDecoration(
        color: AmColors.panel,
        border: Border(top: BorderSide(color: AmColors.hairline)),
      ),
      child: Row(
        children: [
          for (final f in FerramentaDoEstudio.values)
            Expanded(
              child: _Ferramenta(
                rotulo: ferramentaLabel(f),
                icone: switch (f) {
                  FerramentaDoEstudio.selecionar =>
                    Icons.touch_app_outlined,
                  FerramentaDoEstudio.mover => Icons.open_with_rounded,
                  FerramentaDoEstudio.girar => Icons.rotate_right_rounded,
                  FerramentaDoEstudio.escalar => Icons.aspect_ratio_rounded,
                },
                escolhida: f == atual,
                aoTocar: () =>
                    ref.read(ferramentaProvider.notifier).state = f,
              ),
            ),
          // O `+` E UM SO. Ele abre o menu de tudo que se pode criar, em
          // vez de espalhar cinco botoes de adicionar pela tela.
          SizedBox(
            width: 62,
            child: Semantics(
              container: true,
              excludeSemantics: true,
              button: true,
              label: 'Adicionar a cena',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => abrirFolhaDeAdicionar(
                  context,
                  ref,
                  layerId: layerId,
                  tempo: tempo,
                  navegacao: navegacao,
                  aoAvisar: aoAvisar,
                ),
                child: Center(
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: AmColors.action,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 22,
                      color: AmColors.onAction,
                    ),
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

class _Ferramenta extends StatelessWidget {
  const _Ferramenta({
    required this.rotulo,
    required this.icone,
    required this.escolhida,
    required this.aoTocar,
  });

  final String rotulo;
  final IconData icone;
  final bool escolhida;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    selected: escolhida,
    label: rotulo,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aoTocar,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icone,
            size: 20,
            color: escolhida ? AmColors.accent : AmColors.muted,
          ),
          const SizedBox(height: 3),
          // A fonte dos testes tem 1 em de largura por letra: sem o
          // `FittedBox` o rotulo quebra linha e some da altura fixa.
          FittedBox(
            child: Text(
              rotulo,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: escolhida ? AmColors.accent : AmColors.muted,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _IconeDaBarra extends StatelessWidget {
  const _IconeDaBarra({
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
        width: 46,
        height: 52,
        child: Icon(icone, size: 22, color: AmColors.text),
      ),
    ),
  );
}
