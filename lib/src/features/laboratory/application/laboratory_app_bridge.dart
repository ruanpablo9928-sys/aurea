import 'dart:io';
import 'dart:ui' as ui;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/feature_access.dart';
import '../../editor/application/preview_stats.dart';
import '../../editor/domain/am_sections.dart';
import '../../editor/domain/effect.dart';
import '../../editor/domain/shape_library.dart';
import '../domain/acceptance_task.dart';
import '../domain/laboratory_mesh_seed.dart';
import '../domain/laboratory_metrics.dart';
import '../domain/laboratory_session.dart';
import '../presentation/laboratory_runtime_bridge.dart';

/// A tela inteira, para o print do relatorio. Fica na raiz do app: o
/// print sai com a faixa do passo junto, que e o que o agente precisa
/// ver para saber em que passo o problema aconteceu.
final GlobalKey laboratoryCaptureKey = GlobalKey();

/// A PONTE ENTRE O LABORATORIO E O APP DE VERDADE.
///
/// Sem ela o laboratorio existe mas nao faz nada: nao le o aparelho, nao
/// conta fps, nao tira print, nao carrega ativo e nao compartilha. E o
/// unico lugar do laboratorio que toca em plataforma.
class LaboratoryAppBridge implements LaboratoryRuntimeBridge {
  LaboratoryAppBridge(this._ref);

  final Ref _ref;

  LaboratoryEnvironment? _ambiente;

  @override
  bool get canLoadAssets => true;

  @override
  bool get canCaptureScreenshot =>
      laboratoryCaptureKey.currentContext != null;

  @override
  bool get canShare => true;

  @override
  bool get canOpenEditor => true;

  // ----------------------------------------------------------- ambiente

  /// Le o aparelho uma vez e guarda. E chamado no meio da sessao; ler
  /// plataforma a cada passo custaria caro e nunca muda.
  @override
  LaboratoryEnvironment readEnvironment() =>
      _ambiente ??
      LaboratoryEnvironment(
        deviceModel: _modelo ?? 'Lendo o aparelho...',
        operatingSystem: '${Platform.operatingSystem} '
            '${Platform.operatingSystemVersion}',
        appVersion: _versao ?? '—',
        locale: PlatformDispatcher.instance.locale.toLanguageTag(),
      );

  String? _modelo;
  String? _versao;

  /// Chamado na abertura do laboratorio: preenche modelo e versao para
  /// que o cabecalho do relatorio saia com o aparelho certo.
  Future<void> aquecer() async {
    try {
      final info = await PackageInfo.fromPlatform();
      _versao = '${info.version}+${info.buildNumber}';
    } catch (_) {}
    try {
      final plugin = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await plugin.androidInfo;
        _modelo = '${a.manufacturer} ${a.model}'.trim();
      } else if (Platform.isIOS) {
        final i = await plugin.iosInfo;
        _modelo = i.utsname.machine;
      }
    } catch (_) {}
    _ambiente = LaboratoryEnvironment(
      deviceModel: _modelo ?? 'Aparelho desconhecido',
      operatingSystem:
          '${Platform.operatingSystem} ${Platform.operatingSystemVersion}',
      appVersion: _versao ?? '—',
      locale: PlatformDispatcher.instance.locale.toLanguageTag(),
    );
  }

  // -------------------------------------------------------- nivel visivel

  /// "Nivel ligado sem UI visivel = falha automatica."
  ///
  /// A pergunta nao e se o interruptor esta ligado — e se existe MESMO
  /// alguma coisa implementada por tras dele. Cada nivel responde
  /// olhando o proprio artefato: a biblioteca de formas tem forma? os
  /// seis efeitos tem as tres profundidades? Um nivel que so existe no
  /// documento responde nao, e o laboratorio acusa antes do teste.
  @override
  Future<bool> isUiVisible(LaboratoryLevelId level) async {
    if (!_ref.read(featureAccessProvider(level))) return false;
    return switch (level) {
      LaboratoryLevelId.core => true,
      LaboratoryLevelId.shapes => shapeLibrary.length >= 20,
      LaboratoryLevelId.effects => _seisEfeitosProntos(),
      // Estes vieram do estudio e tem tela; a especificacao propria de
      // cada um e que ainda nao foi escrita.
      LaboratoryLevelId.text => true,
      LaboratoryLevelId.mask => true,
      LaboratoryLevelId.cut => true,
      LaboratoryLevelId.captions => true,
      LaboratoryLevelId.scene3d => true,
      LaboratoryLevelId.panorama => true,
      LaboratoryLevelId.nullAndClone => true,
      // O nivel 6 (Apple) ainda nao existe em lugar nenhum do app.
      LaboratoryLevelId.apple => false,
      // A UI final nao tem tela propria: o que se verifica e que a grade
      // continua cabendo em sete secoes.
      LaboratoryLevelId.uiFinal => AmSecao.values.length <= kAmMaximoSecoes,
    };
  }

  static bool _seisEfeitosProntos() {
    const seis = [
      EffectType.gaussianBlur,
      EffectType.lightGlow,
      EffectType.levels,
      EffectType.rgbSplit,
      EffectType.tremor,
      EffectType.vignette,
    ];
    return seis.every((t) => effectSpecs[t]?.temProfundidades ?? false);
  }

  // ------------------------------------------------------------- ativos

  /// Onde cada ativo mora dentro do app.
  static const _empacotados = <LaboratoryAssetId, String>{
    LaboratoryAssetId.referenceCard: 'assets/laboratory/reference_card.png',
    LaboratoryAssetId.spokenVideo: 'assets/laboratory/spoken_ptbr.wav',
    LaboratoryAssetId.silentVideo: 'assets/laboratory/silent_60s.wav',
    LaboratoryAssetId.beatTrack: 'assets/laboratory/beat_track.wav',
    LaboratoryAssetId.equirectangularPanorama:
        'assets/laboratory/panorama_equirectangular.png',
    LaboratoryAssetId.phonePanorama:
        'assets/laboratory/panorama_phone_150.png',
    LaboratoryAssetId.extraFont:
        'assets/laboratory/RobotoSlab-VariableFont_wght.ttf',
  };

  /// Copia o ativo para um arquivo de verdade e devolve o caminho — o
  /// importador do app trabalha com arquivo, nao com asset.
  /// Os dois modelos 3D nao sao empacotados: sao gerados na primeira vez
  /// e ficam guardados. Ver [gerarEsferaGlb].
  static const _gerados = <LaboratoryAssetId, int>{
    LaboratoryAssetId.smallGlb: 3000000,
    LaboratoryAssetId.largeGlb: 40000000,
  };

  @override
  Future<String> prepareAsset(TestAssetRequirement asset) async {
    final bytesAlvo = _gerados[asset.id];
    if (bytesAlvo != null) return _semearEsfera(asset, bytesAlvo);
    final caminho = _empacotados[asset.id];
    if (caminho == null) {
      throw UnsupportedError(
          '"${asset.label}" ainda nao vem no app. O passo pode ser pulado.');
    }
    final dir = await getApplicationDocumentsDirectory();
    final destino = Directory('${dir.path}/laboratorio');
    if (!destino.existsSync()) destino.createSync(recursive: true);
    final nome = caminho.split('/').last;
    final arquivo = File('${destino.path}/$nome');
    if (arquivo.existsSync() && arquivo.lengthSync() > 0) return arquivo.path;

    final dados = await rootBundle.load(caminho);
    if (dados.lengthInBytes == 0) {
      throw StateError('"${asset.label}" veio vazio no app.');
    }
    await arquivo.writeAsBytes(dados.buffer.asUint8List(), flush: true);
    return arquivo.path;
  }

  Future<String> _semearEsfera(
      TestAssetRequirement asset, int bytesAlvo) async {
    final dir = await getApplicationDocumentsDirectory();
    final destino = Directory('${dir.path}/laboratorio');
    if (!destino.existsSync()) destino.createSync(recursive: true);
    final arquivo = File('${destino.path}/${asset.id.name}.glb');
    if (arquivo.existsSync() && arquivo.lengthSync() > 0) return arquivo.path;
    // Fora da thread da interface: a esfera grande tem milhoes de
    // triangulos e travaria o preview enquanto e montada.
    final bytes = await compute(esferaGlbNoIsolate, bytesAlvo);
    await arquivo.writeAsBytes(bytes, flush: true);
    return arquivo.path;
  }

  // -------------------------------------------------------------- print

  @override
  Future<LaboratoryAttachment> captureScreenshot({
    required LaboratoryLevelId level,
    required String stepId,
  }) async {
    final obj = laboratoryCaptureKey.currentContext?.findRenderObject();
    if (obj is! RenderRepaintBoundary) {
      throw StateError('A tela ainda nao esta pronta para o print.');
    }
    final img = await obj.toImage(pixelRatio: 1.5);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    if (png == null) throw StateError('Nao consegui ler o print.');

    final dir = await getApplicationDocumentsDirectory();
    final destino = Directory('${dir.path}/laboratorio');
    if (!destino.existsSync()) destino.createSync(recursive: true);
    final id = '${level.code}-$stepId-'
        '${DateTime.now().millisecondsSinceEpoch}';
    final arquivo = File('${destino.path}/print-$id.png');
    await arquivo.writeAsBytes(png.buffer.asUint8List(), flush: true);

    return LaboratoryAttachment(
      id: id,
      kind: LaboratoryAttachmentKind.screenshot,
      uri: arquivo.path,
      createdAt: DateTime.now(),
      label: 'Nivel ${level.code} · $stepId',
    );
  }

  // --------------------------------------------------------- desempenho

  /// "E o que faz 'travou' virar numero."
  @override
  PerformanceSample? samplePerformance() {
    final fps = PreviewStats.compsPerSec.value.toDouble();
    final gear = PreviewStats.gear.value;
    return PerformanceSample(
      fps: fps < 0 ? 0 : fps,
      gear: gear?.gear.name,
      liveDecoders: PreviewStats.layersInFrame.value,
      // Travadas da janela viram "alocacoes por frame" no relatorio: e o
      // numero que aparece junto do passo lento.
      allocationsPerFrame: PreviewStats.jankFrames.value,
    );
  }

  // ------------------------------------------------------------ enviar

  @override
  Future<void> shareReport({
    required String plainText,
    required List<LaboratoryAttachment> attachments,
  }) async {
    final arquivos = <XFile>[
      for (final a in attachments)
        if (File(a.uri).existsSync()) XFile(a.uri),
    ];
    if (arquivos.isEmpty) {
      await SharePlus.instance.share(ShareParams(text: plainText));
      return;
    }
    await SharePlus.instance.share(
      ShareParams(text: plainText, files: arquivos),
    );
  }

  // ------------------------------------------------------------- editor

  @override
  Future<void> openEditorForTask(LaboratoryLevelId level) async {
    // Quem abre o editor e a propria tela do laboratorio (ela tem o
    // Navigator na mao); aqui so confirmamos que da para abrir.
  }
}

final laboratoryAppBridgeProvider = Provider<LaboratoryAppBridge>(
  LaboratoryAppBridge.new,
);
