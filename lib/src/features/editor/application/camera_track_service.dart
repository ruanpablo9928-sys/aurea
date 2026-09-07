import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/camera_solver3d.dart';
import '../domain/pontos_seguidos.dart';
import '../domain/tracker2d.dart';
import 'tracking_service.dart';

/// O RASTREIO DE CAMERA 3D, do arquivo ate a solucao.
///
/// A conta em si mora no dominio e nao sabe o que e um video. Este
/// servico e o que a liga ao mundo: arranja os quadros, tira o trabalho
/// pesado da thread da interface, guarda o resultado e devolve o mesmo
/// resultado da proxima vez.
///
/// GUARDAR IMPORTA MAIS DO QUE PARECE. O solver tem sorteio dentro
/// (RANSAC); com semente fixa ele e deterministico, mas ainda assim
/// resolver de novo a cada abertura do projeto significaria esperar
/// segundos por algo que ja se sabe — e, pior, qualquer mudanca futura
/// no algoritmo moveria o objeto que a pessoa colou no plano. A solucao
/// gravada e a que vale ate ela mandar rastrear outra vez.
class CameraTrackService {
  CameraTrackService._();
  static final instance = CameraTrackService._();

  final Map<String, SolucaoCamera3D> _cache = {};
  final Set<String> _emAndamento = {};

  /// Avisa a interface quando uma analise termina.
  final ValueNotifier<int> revision = ValueNotifier(0);

  /// Progresso 0..1 e o que esta acontecendo agora, em palavras. Um
  /// rastreio leva dezenas de segundos: barra sem legenda parece travada.
  final ValueNotifier<double> progress = ValueNotifier(0);
  final ValueNotifier<String> etapa = ValueNotifier('');

  SolucaoCamera3D? dataFor(String layerId) => _cache[layerId];
  bool isRunning(String layerId) => _emAndamento.contains(layerId);

  Future<Directory> _pasta() async {
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}/camera3d');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  /// Le do disco o que ja foi resolvido antes.
  Future<void> load(String layerId) async {
    if (_cache.containsKey(layerId)) return;
    try {
      final f = File('${(await _pasta()).path}/$layerId.json');
      if (!f.existsSync()) return;
      final s = SolucaoCamera3D.decode(await f.readAsString());
      if (s != null) {
        _cache[layerId] = s;
        revision.value++;
      }
    } catch (_) {}
  }

  /// RASTREIA a camera de um clipe.
  ///
  /// Devolve a solucao, ou lanca [RastreioException] com o motivo em
  /// portugues quando o plano nao permite — que e uma resposta melhor do
  /// que uma cena inventada.
  Future<SolucaoCamera3D> rastrear({
    required String layerId,
    required String sourcePath,
    required Duration start,
    required Duration duration,
    int fps = 8,
    int maximoDePontos = 110,
    double? focalPx,
  }) async {
    if (_emAndamento.contains(layerId)) {
      throw const RastreioException(
        FalhaDoRastreio.naoConvergiu,
        'Ja tem um rastreio rodando nesse clipe.',
      );
    }
    _emAndamento.add(layerId);
    progress.value = 0;
    etapa.value = 'Lendo o vídeo...';
    try {
      final frames = await TrackingService.instance.grayFrames(
        sourcePath,
        start: start,
        duration: duration,
        fps: fps,
        maxFrames: 240,
      );
      if (frames.length < 8) {
        throw const RastreioException(
          FalhaDoRastreio.poucosPontos,
          'Esse trecho é curto demais para rastrear. '
          'Use pelo menos dois segundos de vídeo.',
        );
      }

      progress.value = .3;
      etapa.value = 'Seguindo ${frames.length} quadros...';

      // O RESTO SAI DA THREAD DA INTERFACE. Seguir cem pontos por duzentos
      // quadros e depois resolver a camera sao segundos de conta pura; na
      // thread principal isso e o app congelado, e app congelado a pessoa
      // fecha.
      final solucao = await Isolate.run(
        () => _seguirEResolver(
          frames,
          maximoDePontos: maximoDePontos,
          focalPx: focalPx,
          fps: fps,
        ),
      );

      progress.value = 1;
      etapa.value = 'Pronto';
      _cache[layerId] = solucao;
      try {
        await File('${(await _pasta()).path}/$layerId.json')
            .writeAsString(jsonEncode(solucao.toJson()), flush: true);
      } catch (_) {
        // Nao poder gravar nao invalida o que ja foi resolvido.
      }
      revision.value++;
      return solucao;
    } finally {
      _emAndamento.remove(layerId);
      etapa.value = '';
    }
  }

  /// Joga fora a solucao — para rastrear de novo com outros ajustes.
  Future<void> clear(String layerId) async {
    _cache.remove(layerId);
    try {
      final f = File('${(await _pasta()).path}/$layerId.json');
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
    revision.value++;
  }

  /// Substitui a solucao guardada — usado depois de definir o chao.
  Future<void> guardar(String layerId, SolucaoCamera3D s) async {
    _cache[layerId] = s;
    try {
      await File('${(await _pasta()).path}/$layerId.json')
          .writeAsString(jsonEncode(s.toJson()), flush: true);
    } catch (_) {}
    revision.value++;
  }
}

/// O trabalho pesado, num isolate. Precisa ser uma funcao de topo: o que
/// atravessa para o outro isolate nao pode carregar `this` junto.
SolucaoCamera3D _seguirEResolver(
  List<GrayFrame> frames, {
  required int maximoDePontos,
  required int fps,
  double? focalPx,
}) {
  final pontos = seguirPontos(
    frames,
    maximoDePontos: maximoDePontos,
    // A analise roda em 240 px de largura: 8 px de distancia entre
    // pontos e o equivalente a espalhar trinta por linha.
    distanciaMinima: 8,
    duracaoMinima: 6,
  );
  return resolverCamera3D(
    pontos,
    largura: frames.first.width,
    altura: frames.first.height,
    quadros: frames.length,
    fps: fps,
    focalPx: focalPx,
  );
}
