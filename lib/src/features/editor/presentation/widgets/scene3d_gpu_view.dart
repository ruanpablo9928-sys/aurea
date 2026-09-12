import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/ui/preview_resolution.dart';

import '../../application/motor3d_modo.dart';
import '../../application/preview_stats.dart';
import '../../application/qualidade3d_controller.dart';
import '../../application/registro_de_travadas.dart';
import '../../application/scene3d_gpu.dart';
import '../../domain/orcamento_render.dart';
import '../../domain/camera3d.dart';
import '../../domain/scene3d.dart';
import 'scene3d_painter.dart';

/// A CENA 3D DESENHADA PELA GPU — e, ate a GPU estar pronta, pelo pintor
/// de sempre, para nunca haver quadro vazio.
///
/// Na timeline a cena e um quadro 2D como qualquer camada: este widget
/// renderiza o instante [time] pela camera [renderCamera] e entrega o
/// resultado no canvas da composicao (o que a exportacao captura). O
/// Estudio usa o mesmo widget com a camera livre dele.
class Scene3DGpuView extends ConsumerStatefulWidget {
  const Scene3DGpuView({
    super.key,
    required this.scene,
    required this.camera,
    required this.renderCamera,
    required this.time,
    this.view = SceneView.camera,
    this.rascunho = false,
    this.showHelpers = false,
    this.showModelRig = false,
    this.selectedNodeId,
    this.exporting = false,
  });

  final Scene3D scene;
  final Camera3D camera;
  final RenderCamera renderCamera;
  final Duration time;
  final SceneView view;

  /// Durante um gesto no Estudio: sem profundidade de campo, para navegar
  /// liso.
  final bool rascunho;
  final bool showHelpers;

  /// O esqueleto do modelo por cima do quadro. A tela de Animacao de
  /// modelo vive disto: e por ele que a pose e editada.
  final bool showModelRig;
  final String? selectedNodeId;
  final bool exporting;

  @override
  ConsumerState<Scene3DGpuView> createState() => _Scene3DGpuViewState();
}

class _Scene3DGpuViewState extends ConsumerState<Scene3DGpuView> {
  Scene3DGpu? _gpu;
  var _pronto = Scene3DGpu.pronto;

  /// Esta view ja contou como cena em GPU na tela? (Ver [MarcaGpuViva].)
  var _marcado = false;
  bool _preparingLegacy = false;

  @override
  void initState() {
    super.initState();
    // Uma cena 3D na tela liga as sondas do controlador de qualidade
    // (tempo de quadro, memoria, termico).
    ControladorDeQualidade3D.instancia.entrou();
    _prepareLegacy();
  }

  void _prepareLegacy() {
    if (_pronto) {
      _marcar();
    } else if (!Scene3DGpu.indisponivel && !_preparingLegacy) {
      _preparingLegacy = true;
      Scene3DGpu.preparar().then((_) {
        _preparingLegacy = false;
        if (!mounted) return;
        setState(() => _pronto = Scene3DGpu.pronto);
        if (_pronto) _marcar();
      });
    }
  }

  @override
  void didUpdateWidget(covariant Scene3DGpuView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _prepareLegacy();
  }

  void _marcar() {
    if (_marcado) return;
    _marcado = true;
    MarcaGpuViva.entrou();
  }

  @override
  void dispose() {
    if (_marcado) MarcaGpuViva.saiu();
    ControladorDeQualidade3D.instancia.saiu();
    if (_gpu != null) PreviewStats.cena3d.value = null;
    _gpu?.descartar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final previewScale = ref.watch(previewResolutionProvider).scale;
    // SO ENQUANTO A GPU NAO ESTA PRONTA. A camera ortografica ficava
    // aqui tambem — e era o caminho das vistas fixas do Estudio, que
    // desenhavam a cena inteira no processador. Agora o motor tem lente
    // ortografica (camera_ortografica.dart) e elas seguem pela GPU.
    if (!_pronto) {
      return CustomPaint(
        painter: Scene3DPainter(
          scene: widget.rascunho
              ? widget.scene.copyWith(draftMode: true)
              : widget.scene,
          camera: widget.camera,
          view: widget.view,
          time: widget.time,
          overrideCamera: widget.renderCamera,
          showHelpers: widget.showHelpers,
          selectedNodeId: widget.selectedNodeId,
        ),
        size: Size.infinite,
      );
    }
    final gpu = _gpu ??= Scene3DGpu();
    final controlador = ControladorDeQualidade3D.instancia;
    // A RECEITA DE QUALIDADE muda por fora (orcamento, tempo de quadro,
    // memoria, termico): ouvir o nivel e o que faz a troca valer no
    // quadro seguinte, sem esperar a cena mudar.
    return ValueListenableBuilder<Qualidade3D>(
      valueListenable: controlador.nivel,
      builder: (context, _, _) {
        gpu.sincronizar(
          widget.scene,
          widget.time,
          rascunho: widget.rascunho,
          receita: controlador.receita,
          onMudou: () {
            if (mounted) setState(() {});
          },
        );
        gpu.configurarProfundidadeDeCampo(
          widget.camera,
          widget.time,
          rascunho: widget.rascunho || widget.view != SceneView.camera,
        );
        final quadro = CustomPaint(
          painter: _PintorGpu(
            gpu,
            widget.renderCamera,
            widget.scene.background,
            widget.rascunho,
            widget.exporting,
            previewScale,
          ),
          size: Size.infinite,
        );
        if (!widget.showHelpers && !widget.showModelRig) return quadro;
        // AS AJUDAS POR CIMA DA GPU, como no caminho do Filament: o
        // pintor em modo `helpersOnly` nunca avalia triangulo nenhum —
        // desenha grade, frustum e caixa do selecionado, e so.
        return Stack(
          fit: StackFit.expand,
          children: [
            quadro,
            IgnorePointer(
              child: CustomPaint(
                painter: Scene3DPainter(
                  scene: widget.scene,
                  camera: widget.camera,
                  view: widget.view,
                  time: widget.time,
                  overrideCamera: widget.renderCamera,
                  showHelpers: widget.showHelpers,
                  showModelRig: widget.showModelRig,
                  helpersOnly: true,
                  selectedNodeId: widget.selectedNodeId,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PintorGpu extends CustomPainter {
  _PintorGpu(
    this.gpu,
    this.camera,
    this.fundo,
    this.rascunho,
    this.exporting,
    this.previewScale,
  );
  final double previewScale;
  final bool rascunho, exporting;

  final Scene3DGpu gpu;
  final RenderCamera camera;

  /// O FUNDO da cena. O motor em GPU limpa para transparente e desenha o
  /// ceu so quando ha panorama; uma cena com cor de fundo (o preto do
  /// espaco) precisa dela pintada aqui, senao o que aparece atras e a
  /// composicao.
  final Color? fundo;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final area = Offset.zero & size;
    canvas.save();
    canvas.clipRect(area);
    if (fundo != null) canvas.drawRect(area, Paint()..color = fundo!);
    // O DESENHO DA GPU E CHAMADO DAQUI, na fase de PINTURA — que o
    // Flutter contabiliza como `constroi`, e nao como `desenha`. Um
    // registro com `desenha 0` nao inocenta o motor 3D; so diz que a
    // rasterizacao do quadro composto foi barata.
    RegistroDeTravadas.marcando(
      'cena 3D: desenhar na GPU',
      () => gpu.desenhar(
        canvas,
        area,
        gpu.camera(camera, size),
        rascunho: rascunho,
        exporting: exporting,
        previewScale: previewScale,
      ),
    );
    canvas.restore();
  }

  // O adaptador ja decide o que mudou; o quadro e sempre redesenhado
  // quando o widget e reconstruido (tempo ou cena novos).
  @override
  bool shouldRepaint(covariant _PintorGpu old) => true;
}
