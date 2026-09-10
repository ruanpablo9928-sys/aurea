import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/camera3d.dart';
import '../../domain/camera_cuts.dart';
import '../../domain/estudio_ux.dart';
import '../../domain/layer.dart';
import '../../domain/scene3d.dart';

/// O QUE ESTA SELECIONADO NA CENA.
///
/// Separado da selecao de CAMADA do editor (`selectedLayerProvider`)
/// porque sao perguntas diferentes: la e "que camada da composicao",
/// aqui e "que objeto dentro da cena". Confundir as duas era o que
/// fazia o estudio antigo precisar de dois conceitos de selecao no
/// mesmo lugar.
final noSelecionadoProvider = StateProvider<String?>((ref) => null);

/// A luz escolhida na hierarquia. Luz nao se toca no viewport — ela nao
/// tem malha —, entao a selecao dela vem sempre de uma lista.
final luzSelecionadaProvider = StateProvider<String?>((ref) => null);

/// A camera escolhida para EDITAR (a ficha dela). Nao e a camera no ar:
/// essa e um corte no tempo, e mora no projeto.
final cameraSelecionadaProvider = StateProvider<String?>((ref) => null);

/// Os outros nos da selecao multipla — o principal fica no
/// [noSelecionadoProvider].
final selecaoDaCenaProvider = StateProvider<Set<String>>((ref) => const {});

/// A ferramenta da barra de baixo. `selecionar` E o modo de navegar: um
/// dedo sempre gira a camera, o toque sempre escolhe.
final ferramentaProvider = StateProvider<FerramentaDoEstudio>(
  (ref) => FerramentaDoEstudio.selecionar,
);

final encaixeProvider = StateProvider<bool>((ref) => false);
final eixoProvider = StateProvider<EixoTravado>((ref) => EixoTravado.livre);

/// SIMPLES ou AVANCADO.
///
/// No simples ficam transformar, material, camera, luz e animar. No
/// avancado, tudo. O interruptor nao esconde poder: ele adia
/// (`docs/estudio-da-cena.md`).
final avancadoProvider = StateProvider<bool>((ref) => false);

/// O recado da ultima acao — "Cubo criado", "Camera trocada". Some ao
/// proximo recado; e a microinteracao pedida, sem custo de quadro.
final recadoDoEstudioProvider = StateProvider<String?>((ref) => null);

/// Todos os alvos de um gesto de transformacao: o principal e o resto.
Set<String> alvosDaSelecao(WidgetRef ref) => {
  ?ref.read(noSelecionadoProvider),
  ...ref.read(selecaoDaCenaProvider),
};

/// DE ONDE SE OLHA, e como se navega dali.
///
/// Tres modos, e cada um navega de um jeito porque servem a coisas
/// diferentes:
///
///   camera      o que a exportacao vai gravar; navegar aqui MEXE na
///               camera do projeto
///   livre       uma vista de trabalho que nao mexe em nada; e ela que
///               o comando "alinhar camera a vista" compromete
///   ortografica frente, tras, lados, topo e base — as unicas que
///               respondem "esta atras ou e so menor?"
///
/// Fica num [ChangeNotifier], e nao num provider, porque muda a cada
/// quadro de um arrasto: um provider refaria a arvore inteira do
/// estudio sessenta vezes por segundo.
class NavegacaoDaVista extends ChangeNotifier {
  SceneView _vista = SceneView.camera;
  Vec3 _posLivre = const Vec3(700, 500, 900);
  Vec3 _alvoLivre = Vec3.zero;
  Vec3 _centroOrto = Vec3.zero;
  double _escalaOrto = 0.35;

  SceneView get vista => _vista;
  Vec3 get posLivre => _posLivre;
  Vec3 get alvoLivre => _alvoLivre;
  Vec3 get centroOrto => _centroOrto;
  double get escalaOrto => _escalaOrto;

  bool get pelaCamera => _vista == SceneView.camera;
  bool get livre =>
      _vista == SceneView.custom1 || _vista == SceneView.custom2;
  bool get ortografica => !pelaCamera && !livre;

  /// Troca a vista. Ao entrar numa vista LIVRE ela nasce onde a camera
  /// esta — assim nada pula na tela.
  void verVista(SceneView v, {Camera3D? camera, Duration? tempo}) {
    _vista = v;
    if (livre && camera != null && tempo != null) {
      _posLivre = camera.positionAt(tempo);
      _alvoLivre = camera.kind == CameraKind.twoNode
          ? camera.pointOfInterestAt(tempo)
          : _posLivre + camera.forwardAt(tempo) * 800;
    }
    notifyListeners();
  }

  void orbitarLivre(Vec3 pivo, double yawGraus, double pitchGraus) {
    final rel = _posLivre - pivo;
    final raio = rel.length;
    final a = math.atan2(rel.x, rel.z) + yawGraus * math.pi / 180;
    var p =
        math.asin((rel.y / math.max(1e-6, raio)).clamp(-1.0, 1.0)) +
        pitchGraus * math.pi / 180;
    p = p.clamp(-math.pi / 2 + 0.02, math.pi / 2 - 0.02);
    _posLivre = Vec3(
      pivo.x + raio * math.cos(p) * math.sin(a),
      pivo.y + raio * math.sin(p),
      pivo.z + raio * math.cos(p) * math.cos(a),
    );
    _alvoLivre = pivo;
    notifyListeners();
  }

  void deslizarLivre(Vec3 shift) {
    _posLivre = _posLivre + shift;
    _alvoLivre = _alvoLivre + shift;
    notifyListeners();
  }

  void deslizarOrto(Vec3 shift) {
    _centroOrto = _centroOrto + shift;
    notifyListeners();
  }

  void aproximarLivre(double fator) {
    final rel = _posLivre - _alvoLivre;
    _posLivre = _alvoLivre + rel * (1 / fator.clamp(0.2, 5.0));
    notifyListeners();
  }

  void aproximarOrto(double fator) {
    _escalaOrto = (_escalaOrto * fator).clamp(0.02, 6.0);
    notifyListeners();
  }

  void enquadrarLivre(Bounds3D b) {
    final dir = (_posLivre - b.center).normalized;
    _alvoLivre = b.center;
    _posLivre =
        b.center +
        (dir.length < 1e-6 ? const Vec3(0.6, 0.5, 0.7) : dir) *
            math.max(b.radius * 3.2, 1);
    notifyListeners();
  }

  void enquadrarOrto(Bounds3D b) {
    _centroOrto = b.center;
    _escalaOrto = b.radius <= 0 ? 0.35 : (300 / b.radius).clamp(0.02, 3.0);
    notifyListeners();
  }

  /// A camera com que o viewport DESENHA — que nao e sempre a camera do
  /// projeto.
  RenderCamera cameraDeRender(Scene3DLayer camada, Duration local) {
    if (pelaCamera) return camada.cameraAt(local);
    final ativa = cameraNoAr(camada, local);
    if (livre) {
      return RenderCamera(
        position: _posLivre,
        target: _alvoLivre,
        focalLength: ativa.focalLength.valueAt(local),
        filmWidth: ativa.filmWidth,
      );
    }
    return orthoViewCamera(
      _vista,
      scale: _escalaOrto,
      center: _centroOrto,
    );
  }
}

/// A CAMERA NO AR NESTE INSTANTE: a do ultimo corte antes do cabecote,
/// ou a da propria cena quando nao ha corte. E a mesma conta que o
/// render faz — perguntar de outro jeito faria a tela e o arquivo
/// discordarem.
Camera3D cameraNoAr(Scene3DLayer camada, Duration local) {
  final cortes = sortedShots(camada.shots);
  final corte = shotAt(cortes, local) ?? cortes.firstOrNull;
  return camada.allCameras.where((c) => c.id == corte?.cameraId).firstOrNull ??
      camada.camera;
}
