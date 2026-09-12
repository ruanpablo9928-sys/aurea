import 'dart:math' as math;

import 'package:flutter/material.dart' hide Easing;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../application/texture_cache.dart';
import '../../application/scene3d_gpu.dart';
import '../../domain/camera3d.dart';
import '../../domain/estudio_ux.dart';
import '../../domain/layer.dart';
import '../../domain/scene3d.dart';
import '../../domain/scene_motion.dart';
import '../widgets/scene3d_gpu_view.dart';
import '../widgets/scene3d_painter.dart';
import 'estado_do_estudio.dart';

/// O que cada alvo tinha quando o gesto comecou.
///
/// O encaixe na grade e o arrasto de varios precisam do valor BRUTO
/// acumulado desde o inicio, e nao do ultimo valor ja encaixado — senao
/// cada quadro encaixa em cima do encaixe anterior e o objeto anda aos
/// pulos para o lado.
class _BaseDoGesto {
  const _BaseDoGesto(this.pos, this.giroX, this.giroY, this.giroZ, this.escala);
  final Vec3 pos;
  final double giroX, giroY, giroZ, escala;
}

/// A VISTA DA CENA: o elemento principal do estudio.
///
/// Ela nunca encolhe para caber painel — quem precisa de espaco abre uma
/// folha por cima. E ela e o unico lugar do app onde um dedo mexe em 3D
/// de verdade: `orbitCamera`, `panCamera`, `dollyCamera` e `resolveTouch`
/// existiam, estavam testados, e nao tinham um chamador
/// (`docs/motor-3d-inventario.md`).
///
/// OS GESTOS, e por que cada um:
///
///   dedo sobre o selecionado -> move o objeto (com uma ferramenta)
///   dedo sobre outro objeto  -> seleciona ele E ja arrasta
///   dedo em area vazia       -> ORBITA a camera
///   dois dedos               -> deslizam
///   pinca                    -> aproxima; move no Z e NUNCA mexe na lente
///   toque duplo              -> enquadra (no vazio, enquadra tudo)
///   toque longo              -> entra ou sai da selecao multipla
///
/// A intencao e decidida ONDE O GESTO COMECOU e fica estavel ate soltar:
/// atravessar outro objeto no meio do arrasto nao troca arrastar por
/// orbitar.
class VistaDaCena extends ConsumerStatefulWidget {
  const VistaDaCena({
    super.key,
    required this.layerId,
    required this.navegacao,
    required this.tempo,
    required this.aoTocarVazio,
  });

  final String layerId;
  final NavegacaoDaVista navegacao;

  /// O cabecote, em tempo da COMPOSICAO.
  final Duration tempo;

  /// Um toque no nada tambem fecha o que estiver aberto por cima.
  final VoidCallback aoTocarVazio;

  @override
  ConsumerState<VistaDaCena> createState() => VistaDaCenaState();
}

class VistaDaCenaState extends ConsumerState<VistaDaCena> {
  Vec3? _pivo;
  Offset _ultimoFoco = Offset.zero;
  double _ultimaEscala = 1;
  bool _gestoAberto = false;
  bool _gestoNoControlador = false;
  TouchIntent? _intencao;
  final Map<String, _BaseDoGesto> _base = {};
  Vec3 _accMundo = Vec3.zero;
  double _accDx = 0;
  double _accDy = 0;
  Size _tamanho = Size.zero;

  EditorController get _c => ref.read(editorControllerProvider.notifier);

  Scene3DLayer? get _camada {
    final l = ref.read(editorControllerProvider).layerById(widget.layerId);
    return l is Scene3DLayer ? l : null;
  }

  Duration get _local => _camada?.localTime(widget.tempo) ?? widget.tempo;

  Set<String> get _alvos => {
    ?ref.read(noSelecionadoProvider),
    ...ref.read(selecaoDaCenaProvider),
  };

  bool get _navegando =>
      ref.read(ferramentaProvider) == FerramentaDoEstudio.selecionar;

  // ---------------------------------------------------------- selecao

  void _selecionar(String? id, {bool acumular = false}) {
    ref.read(luzSelecionadaProvider.notifier).state = null;
    ref.read(cameraSelecionadaProvider.notifier).state = null;
    if (!acumular || id == null) {
      ref.read(selecaoDaCenaProvider.notifier).state = const {};
      ref.read(noSelecionadoProvider.notifier).state = id;
      return;
    }
    final principal = ref.read(noSelecionadoProvider);
    final resto = {...ref.read(selecaoDaCenaProvider)};
    if (id == principal || resto.contains(id)) {
      resto.remove(id);
      if (id == principal) {
        final proximo = resto.isEmpty ? null : resto.first;
        resto.remove(proximo);
        ref.read(noSelecionadoProvider.notifier).state = proximo;
      }
    } else {
      if (principal != null) resto.add(principal);
      ref.read(noSelecionadoProvider.notifier).state = id;
    }
    ref.read(selecaoDaCenaProvider.notifier).state = resto;
  }

  String? _apanhar(Scene3DLayer camada, Offset ponto) {
    if (_tamanho.isEmpty) return null;
    final quadro = renderScene(
      camada.scene,
      widget.navegacao.cameraDeRender(camada, _local),
      _tamanho,
      _local,
    );
    return pickNodeAt(quadro, ponto);
  }

  // ----------------------------------------------------------- gestos

  void _abrirGesto() {
    if (_gestoAberto) return;
    setState(() => _gestoAberto = true);
  }

  /// Um gesto inteiro e UM passo de desfazer — e so vira passo se mexeu
  /// no projeto. Orbitar a vista livre nao mexe em nada, e por isso o
  /// grupo do controlador so abre quando ha o que desfazer.
  void _abrirNoControlador() {
    if (_gestoNoControlador) return;
    _gestoNoControlador = true;
    _c.beginGesture();
  }

  void _fecharGesto() {
    if (_gestoNoControlador) {
      _gestoNoControlador = false;
      _c.endGesture();
    }
    if (!_gestoAberto) return;
    setState(() {
      _gestoAberto = false;
      _intencao = null;
      _pivo = null;
    });
  }

  /// O PIVO FICA FIXO DESDE O INICIO do gesto. Trocar no meio e o que
  /// mais atrapalha: a cena parece escorregar debaixo do dedo.
  Vec3 _resolverPivo(Scene3DLayer camada) {
    if (_pivo != null) return _pivo!;
    final sel = camada.scene.nodes
        .where((n) => n.id == ref.read(noSelecionadoProvider))
        .firstOrNull;
    if (sel != null) {
      return _pivo = resolveNodeTransform(camada.scene, sel, _local).position;
    }
    final nav = widget.navegacao;
    if (nav.pelaCamera) {
      final cam = cameraNoAr(camada, _local);
      if (cam.kind == CameraKind.twoNode) {
        return _pivo = cam.pointOfInterestAt(_local);
      }
    }
    if (nav.livre) return _pivo = nav.alvoLivre;
    return _pivo = sceneBounds(camada.scene, _local).center;
  }

  void _editarCamera(Scene3DLayer camada, Camera3D Function(Camera3D) fn) {
    if (_gestoAberto) _abrirNoControlador();
    final cam = cameraNoAr(camada, _local);
    // `editCameraMotion` respeita a regra: sobre a marca atualiza, fora
    // dela a trilha volta intacta e o valor fica pendente ate o losango
    // (`docs/keyframe-explicito.md`).
    _c.updateSceneCameraById(widget.layerId, editCameraMotion(cam, _local, fn));
  }

  void _orbitar(Scene3DLayer camada, Offset delta) {
    final pivo = _resolverPivo(camada);
    final yaw = -delta.dx * 0.35;
    final pitch = delta.dy * 0.28;
    final nav = widget.navegacao;
    if (nav.pelaCamera) {
      _editarCamera(camada, (c) => orbitCamera(c, pivo, yaw, pitch, _local));
      return;
    }
    if (nav.livre) {
      nav.orbitarLivre(pivo, yaw, pitch);
      return;
    }
    // Nas vistas ortograficas um dedo DESLOCA, e nao gira: girar
    // destruiria justamente o que elas servem para mostrar.
    _deslizarOrto(delta);
  }

  void _deslizar(Scene3DLayer camada, Offset delta) {
    final nav = widget.navegacao;
    if (nav.pelaCamera) {
      _editarCamera(camada, (c) => panCamera(c, delta, _local));
      return;
    }
    if (nav.livre) {
      final base = cameraBasis(nav.cameraDeRender(camada, _local));
      nav.deslizarLivre(base.right * (-delta.dx) + base.up * delta.dy);
      return;
    }
    _deslizarOrto(delta);
  }

  void _deslizarOrto(Offset delta) {
    final nav = widget.navegacao;
    final base = cameraBasis(
      orthoViewCamera(nav.vista, scale: nav.escalaOrto, center: nav.centroOrto),
    );
    nav.deslizarOrto(
      base.right * (-delta.dx / nav.escalaOrto) +
          base.up * (delta.dy / nav.escalaOrto),
    );
  }

  /// A PINCA MOVE A CAMERA NO Z e NAO altera a distancia focal.
  /// Aproximar muda a perspectiva; o zoom muda a lente. Sao coisas
  /// diferentes, e trocar uma pela outra e o erro classico.
  void _aproximar(Scene3DLayer camada, double fator) {
    if (fator <= 0) return;
    final nav = widget.navegacao;
    if (nav.pelaCamera) {
      _editarCamera(camada, (c) => dollyCamera(c, fator, _local));
      return;
    }
    if (nav.livre) {
      nav.aproximarLivre(fator);
      return;
    }
    nav.aproximarOrto(fator);
  }

  // ------------------------------------------------------ transformar

  void _guardarBases(Scene3DLayer camada) {
    _base.clear();
    _accMundo = Vec3.zero;
    _accDx = 0;
    _accDy = 0;
    for (final id in _alvos) {
      final n = camada.scene.nodeById(id);
      if (n == null) continue;
      _base[id] = _BaseDoGesto(
        resolveNodeTransform(camada.scene, n, _local).position,
        n.rotX.valueAt(_local),
        n.rotY.valueAt(_local),
        n.rotZ.valueAt(_local),
        n.scale.valueAt(_local),
      );
    }
  }

  _BaseDoGesto _baseDe(Scene3DLayer camada, SceneNode n) =>
      _base[n.id] ??
      _BaseDoGesto(
        resolveNodeTransform(camada.scene, n, _local).position,
        n.rotX.valueAt(_local),
        n.rotY.valueAt(_local),
        n.rotZ.valueAt(_local),
        n.scale.valueAt(_local),
      );

  void _escrever(String nodeId, PropDoNo p, double v) =>
      _c.editSceneNodeProp(widget.layerId, nodeId, p, widget.tempo, v);

  void _transformar(Scene3DLayer camada, Offset delta, RenderCamera cam) {
    final alvos = [for (final id in _alvos) ?camada.scene.nodeById(id)];
    if (alvos.isEmpty) return;
    _abrirNoControlador();
    _accDx += delta.dx;
    _accDy += delta.dy;
    final encaixa = ref.read(encaixeProvider);
    final eixo = ref.read(eixoProvider);
    final ferramenta = ref.read(ferramentaProvider);

    if (ferramenta == FerramentaDoEstudio.girar) {
      for (final n in alvos) {
        final b = _baseDe(camada, n);
        var rx = b.giroX, ry = b.giroY, rz = b.giroZ;
        switch (eixo) {
          case EixoTravado.livre:
            rx = b.giroX + _accDy * .5;
            ry = b.giroY + _accDx * .5;
          case EixoTravado.x:
            rx = b.giroX + _accDx * .5;
          case EixoTravado.y:
            ry = b.giroY + _accDx * .5;
          case EixoTravado.z:
            rz = b.giroZ + _accDx * .5;
        }
        if (encaixa) {
          rx = encaixar(rx, passoDeGirar);
          ry = encaixar(ry, passoDeGirar);
          rz = encaixar(rz, passoDeGirar);
        }
        if (rx != b.giroX) _escrever(n.id, PropDoNo.giroX, rx);
        if (ry != b.giroY) _escrever(n.id, PropDoNo.giroY, ry);
        if (rz != b.giroZ) _escrever(n.id, PropDoNo.giroZ, rz);
      }
      return;
    }

    if (ferramenta == FerramentaDoEstudio.escalar) {
      final fator = math.exp((_accDx - _accDy) * .008);
      for (final n in alvos) {
        final b = _baseDe(camada, n);
        var s = (b.escala * fator).clamp(.001, 1000.0);
        if (encaixa) s = math.max(passoDeEscalar, encaixar(s, passoDeEscalar));
        _escrever(n.id, PropDoNo.escala, s);
      }
      return;
    }

    // MOVER: no plano da tela, na profundidade do objeto principal — e
    // por isso dois objetos a distancias diferentes andam juntos na
    // tela, que e o que o dedo espera.
    final base = cameraBasis(cam);
    final principal =
        camada.scene.nodeById(ref.read(noSelecionadoProvider) ?? '') ??
        alvos.first;
    final p = resolveNodeTransform(camada.scene, principal, _local).position;
    final dist = (p - cam.position).dot(base.forward).abs();
    final k = cam.orthographic ? 1 / cam.orthoScale : dist / math.max(1, 600);
    final passo = base.right * (delta.dx * k) - base.up * (delta.dy * k);
    _accMundo = _accMundo + travarEixo(passo, eixo);
    for (final n in alvos) {
      final b = _baseDe(camada, n);
      var desejado = b.pos + _accMundo;
      if (encaixa) desejado = encaixarVec3(desejado, passoDeMover);
      final atual = resolveNodeTransform(camada.scene, n, _local).position;
      final falta = desejado - atual;
      if (falta.length < 1e-9) continue;
      // O no pode ter pai: o deslocamento do MUNDO vira deslocamento no
      // espaco local dele antes de entrar na trilha.
      final shift = sceneLocalDelta(camada.scene, n, _local, falta);
      _escrever(n.id, PropDoNo.x, n.x.valueAt(_local) + shift.x);
      _escrever(n.id, PropDoNo.y, n.y.valueAt(_local) + shift.y);
      _escrever(n.id, PropDoNo.z, n.z.valueAt(_local) + shift.z);
    }
  }

  // ---------------------------------------------------------- enquadrar

  Bounds3D? _volumeDaSelecao(Scene3DLayer camada) {
    Bounds3D? total;
    for (final id in _alvos) {
      final n = camada.scene.nodeById(id);
      if (n == null) continue;
      final xf = resolveNodeTransform(camada.scene, n, _local);
      final b = Bounds3D(xf.position, n.size * xf.scale.abs() * 1.8);
      if (total == null) {
        total = b;
        continue;
      }
      final centro = (total.center + b.center) * 0.5;
      total = Bounds3D(
        centro,
        math.max(
          (total.center - centro).length + total.radius,
          (b.center - centro).length + b.radius,
        ),
      );
    }
    return total;
  }

  void _enquadrar(Scene3DLayer camada, Bounds3D b) {
    if (b.radius <= 0) return;
    final nav = widget.navegacao;
    if (nav.pelaCamera) {
      _editarCamera(camada, (c) => frameBounds(c, b, _local));
    } else if (nav.livre) {
      nav.enquadrarLivre(b);
    } else {
      nav.enquadrarOrto(b);
    }
    _pivo = b.center;
  }

  /// FOCAR: enquadra o selecionado. Sem selecao, a cena inteira.
  void focar() {
    final camada = _camada;
    if (camada == null) return;
    _c.runAsOneUndo(() {
      final b = _volumeDaSelecao(camada) ?? sceneBounds(camada.scene, _local);
      _enquadrar(camada, b);
    });
    HapticFeedback.selectionClick();
  }

  void enquadrarTudo() {
    final camada = _camada;
    if (camada == null) return;
    _c.runAsOneUndo(
      () => _enquadrar(camada, sceneBounds(camada.scene, _local)),
    );
  }

  // ------------------------------------------------------------ toques

  void _aoTocar(Scene3DLayer camada, Offset ponto) {
    final achou = _apanhar(camada, ponto);
    _selecionar(achou);
    if (achou == null) widget.aoTocarVazio();
  }

  void _aoTocarDuasVezes(Scene3DLayer camada, Offset ponto) {
    final achou = _apanhar(camada, ponto);
    if (achou == null) {
      _selecionar(null);
      enquadrarTudo();
      return;
    }
    _selecionar(achou);
    focar();
  }

  void _aoSegurar(Scene3DLayer camada, Offset ponto) {
    final achou = _apanhar(camada, ponto);
    if (achou == null) return;
    HapticFeedback.selectionClick();
    _selecionar(achou, acumular: true);
  }

  @override
  Widget build(BuildContext context) {
    final projeto = ref.watch(projetoVisivelProvider);
    final bruta = projeto.layerById(widget.layerId);
    if (bruta is! Scene3DLayer) return const SizedBox.shrink();
    final camada = bruta;
    final local = camada.localTime(widget.tempo);
    final selecionado = ref.watch(noSelecionadoProvider);

    return AnimatedBuilder(
      animation: widget.navegacao,
      builder: (context, _) {
        final viewport = LayoutBuilder(
          builder: (context, c) {
            final size = Size(c.maxWidth, c.maxHeight);
            _tamanho = size;
            final cam = widget.navegacao.cameraDeRender(camada, local);
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => _aoTocar(camada, d.localPosition),
              onDoubleTapDown: (d) =>
                  _aoTocarDuasVezes(camada, d.localPosition),
              onDoubleTap: () {},
              onLongPressStart: (d) => _aoSegurar(camada, d.localPosition),
              onScaleStart: (d) {
                final achou = _apanhar(camada, d.localFocalPoint);
                final inicio = resolveTouch(
                  onSelectedLayer: achou != null && _alvos.contains(achou),
                  onOtherLayer: achou != null && !_alvos.contains(achou),
                  navigationMode: _navegando,
                );
                if (inicio == TouchIntent.selectLayer) {
                  _selecionar(achou);
                  // A selecao acontece no INICIO: o resto do mesmo gesto
                  // ja arrasta, sem exigir um segundo toque.
                  _intencao = TouchIntent.moveLayer;
                } else {
                  _intencao = inicio;
                }
                _pivo = null;
                _abrirGesto();
                _ultimoFoco = d.localFocalPoint;
                _ultimaEscala = 1;
                _resolverPivo(camada);
                _guardarBases(camada);
              },
              onScaleUpdate: (d) {
                final delta = d.localFocalPoint - _ultimoFoco;
                _ultimoFoco = d.localFocalPoint;
                if ((d.scale - _ultimaEscala).abs() > 0.004) {
                  _aproximar(camada, d.scale / _ultimaEscala);
                  _ultimaEscala = d.scale;
                }
                if (delta == Offset.zero) return;
                if (d.pointerCount >= 2) {
                  _deslizar(camada, delta);
                  return;
                }
                switch (_intencao ?? TouchIntent.orbitCamera) {
                  case TouchIntent.moveLayer:
                    _transformar(camada, delta, cam);
                  case TouchIntent.orbitCamera:
                  case TouchIntent.selectLayer:
                    _orbitar(camada, delta);
                }
              },
              onScaleEnd: (_) => _fecharGesto(),
              child: ValueListenableBuilder<int>(
                valueListenable: TextureCache.instance.revision,
                builder: (_, _, _) => Stack(
                  fit: StackFit.expand,
                  children: [
                    const ColoredBox(color: AmColors.bg),
                    if (!Scene3DGpu.indisponivel)
                      Scene3DGpuView(
                        scene: camada.scene,
                        camera: cameraNoAr(camada, local),
                        renderCamera: cam,
                        view: widget.navegacao.vista,
                        time: local,
                        rascunho: _gestoAberto,
                        showHelpers: true,
                        selectedNodeId: selecionado,
                      )
                    else
                      CustomPaint(
                        size: size,
                        painter: Scene3DPainter(
                          scene: _gestoAberto
                              ? camada.scene.copyWith(draftMode: true)
                              : camada.scene,
                          camera: cameraNoAr(camada, local),
                          view: widget.navegacao.vista,
                          time: local,
                          showHelpers: true,
                          selectedNodeId: selecionado,
                          overrideCamera: cam,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
        if (!widget.navegacao.pelaCamera) return viewport;
        return Center(
          child: AspectRatio(
            key: const ValueKey('scene-camera-frame'),
            aspectRatio: projeto.aspectRatio,
            child: DecoratedBox(
              position: DecorationPosition.foreground,
              decoration: BoxDecoration(
                border: Border.all(color: AmColors.muted, width: 1),
              ),
              child: ClipRect(child: viewport),
            ),
          ),
        );
      },
    );
  }
}
