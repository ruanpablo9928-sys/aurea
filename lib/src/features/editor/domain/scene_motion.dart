import 'camera3d.dart';
import 'keyframe.dart';
import 'scene3d.dart';

/// First animation edit away from zero preserves the initial pose.
/// EDITAR UM VALOR NUNCA CRIA KEYFRAME.
///
/// Esta funcao era o keyframe automatico da cena 3D, e a ancora dela em
/// tempo zero era o pior caso do defeito: um unico arrasto num instante
/// qualquer deixava DOIS keyframes, um deles num tempo que a pessoa
/// nunca visitou. Ver `docs/keyframe-explicito.md`.
///
/// Ela continua existindo como ponto unico de edicao de trilha da cena,
/// mas agora so repassa a regra de [AnimatedDouble.edited].
AnimatedDouble editMotionValue(
  AnimatedDouble track,
  Duration time,
  double value,
) => track.edited(time, value);

List<AnimatedDouble> nodeMotionTracks(SceneNode n) => [
  n.x,
  n.y,
  n.z,
  n.rotX,
  n.rotY,
  n.rotZ,
  n.scale,
];

SceneNode mapNodeMotion(
  SceneNode n,
  AnimatedDouble Function(AnimatedDouble) f,
) => n.copyWith(
  x: f(n.x),
  y: f(n.y),
  z: f(n.z),
  rotX: f(n.rotX),
  rotY: f(n.rotY),
  rotZ: f(n.rotZ),
  scale: f(n.scale),
);

List<AnimatedDouble> cameraMotionTracks(Camera3D c) => [
  c.posX,
  c.posY,
  c.posZ,
  c.poiX,
  c.poiY,
  c.poiZ,
  c.orientX,
  c.orientY,
  c.orientZ,
  c.rotX,
  c.rotY,
  c.rotZ,
  c.focalLength,
];

Camera3D mapCameraMotion(
  Camera3D c,
  AnimatedDouble Function(AnimatedDouble) f,
) => c.copyWith(
  posX: f(c.posX),
  posY: f(c.posY),
  posZ: f(c.posZ),
  poiX: f(c.poiX),
  poiY: f(c.poiY),
  poiZ: f(c.poiZ),
  orientX: f(c.orientX),
  orientY: f(c.orientY),
  orientZ: f(c.orientZ),
  rotX: f(c.rotX),
  rotY: f(c.rotY),
  rotZ: f(c.rotZ),
  focalLength: f(c.focalLength),
);

/// Navigation helpers operate on a sampled pose; commit only changed tracks
/// back to the original animation, preserving keys before and after the edit.
Camera3D editCameraMotion(
  Camera3D camera,
  Duration time,
  Camera3D Function(Camera3D) edit,
) {
  final sampled = mapCameraMotion(
    camera,
    (v) => AnimatedDouble(v.valueAt(time)),
  );
  final next = cameraMotionTracks(edit(sampled));
  var index = 0;
  return mapCameraMotion(camera, (track) {
    final value = next[index++].base;
    if ((track.valueAt(time) - value).abs() < 1e-9) return track;
    return editMotionValue(track, time, value);
  });
}
