import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart' as fs;
import 'package:vector_math/vector_math.dart' as vm;

import '../domain/camera3d.dart';
import '../domain/element3d.dart';
import '../domain/geometria_gpu.dart';
import '../domain/orcamento_render.dart';
import '../domain/scene3d.dart';
import '../domain/preview_quality.dart';
import 'motor3d_modo.dart';
import 'preview_stats.dart';
import 'qualidade3d_controller.dart';
import 'texture_cache.dart';

/// O MOTOR 3D EM GPU.
///
/// A cena do dominio (`Scene3D`, `SceneNode`, `Material3D`, `Light3D`,
/// `Camera3D`) continua sendo a verdade — e o que o editor edita, o que o
/// projeto salva, o que o pintor em CPU desenha. Esta classe e a PONTE:
/// traduz essa cena para o `flutter_scene` (Flutter GPU / Impeller), que
/// renderiza com buffer de profundidade, materiais fisicos, luz por
/// imagem, sombras em cascata, neblina e profundidade de campo — o que o
/// pintor em CPU nao tem como fazer.
///
/// O que fica do lado de ca: a geometria dos nos vira `MeshGeometry`
/// (uma primitiva por material), a transformacao de cada no vira a
/// matriz local, as texturas sobem para a GPU uma vez, as luzes viram
/// componentes, o ambiente vira ceu procedural ou mapa equiretangular.
/// Tudo e cacheado por assinatura: um quadro novo so mexe nas matrizes;
/// geometria e material so sao reconstruidos quando o que os descreve
/// muda.
///
/// A RECEITA DE QUALIDADE ([ReceitaDeQualidade]) entra em tudo que custa
/// memoria ou tempo de GPU: resolucao e numero de sombras, MSAA, bloom,
/// profundidade de campo, teto de textura, LOD e escala do alvo. Quem
/// escolhe a receita e o [ControladorDeQualidade3D], pelo orcamento do
/// aparelho e pelos sinais de pressao — este arquivo so obedece.
///
/// Quando o Flutter GPU nao esta disponivel (aparelho sem suporte, ou
/// os testes, que rodam em Skia) [Scene3DGpu.pronto] nunca vira true e
/// quem desenha e o pintor de sempre.
class Scene3DGpu {
  Scene3DGpu();

  static Future<void>? _preparo;
  static bool _prontoParaRender = false;
  static bool _falhou = false;
  static String _motivo = '';
  // Uploads include an RGBA readback and mip generation. Serializing them
  // across views prevents a textured import from allocating all copies at once.
  static Future<void> _uploads = Future<void>.value();

  /// Carrega os shaders e recursos estaticos do motor. Falha em silencio
  /// (com log) onde nao ha GPU: [pronto] fica false e o pintor em CPU
  /// continua sendo usado.
  static Future<void> preparar() => _preparo ??= _prepararDeVerdade();

  static Future<void> _prepararDeVerdade() async {
    // Nos testes (Skia) e fora de iOS/Android o Flutter GPU nao existe:
    // nem tentar, para nao vazar a excecao do motor no laco de teste.
    if (kIsWeb ||
        Platform.environment.containsKey('FLUTTER_TEST') ||
        !(Platform.isIOS || Platform.isAndroid)) {
      _falhou = true;
      return;
    }
    // A MIGALHA: se a sessao anterior nao voltou de um quadro em GPU,
    // esta desenha em CPU. Ver Motor3DPreferencia.
    final pref = Motor3DPreferencia.instancia;
    if (pref != null && !pref.permiteGpu) {
      _falhou = true;
      _motivo = pref.motivoDeNaoTentar;
      return;
    }
    try {
      // initializeStaticResources engole a falha (sem GPU) e devolve
      // normalmente; a verdade esta em isReadyToRender.
      await fs.Scene.initializeStaticResources();
      _prontoParaRender = fs.Scene.isReadyToRender;
      _falhou = !_prontoParaRender;
      if (_falhou) {
        _motivo = 'os recursos do motor nao carregaram';
        debugPrint('Motor 3D em GPU indisponivel; fica o pintor em CPU.');
      }
    } catch (e, st) {
      _falhou = true;
      _motivo = '$e';
      debugPrint('Motor 3D em GPU indisponivel; pintor em CPU: $e\n$st');
    }
  }

  /// COMO A CENA 3D ESTA SENDO DESENHADA, em duas letras.
  ///
  /// Isto aparece no app de proposito. Um motor que cai para o pintor em
  /// CPU nao pode ser segredo: a diferenca entre os dois e a diferenca
  /// entre uma cena que roda e uma que engasga, e quem esta com o
  /// aparelho na mao e a unica pessoa que consegue ver qual dos dois
  /// esta valendo.
  static String get comoDesenha => _prontoParaRender
      ? 'GPU'
      : _falhou
      ? 'CPU'
      : '...';

  /// Por que caiu para o pintor em CPU, quando caiu.
  static String get motivo => _motivo;

  /// O motor esta pronto para desenhar?
  static bool get pronto => _prontoParaRender;

  /// A preparacao ja foi tentada e falhou (sem GPU).
  static bool get indisponivel => _falhou;

  final fs.Scene cena = fs.Scene();

  final Map<String, _NoGpu> _nos = {};
  final Map<String, fs.Texture2D> _texturas = {};
  final Map<String, Future<void>> _texturasACaminho = {};
  final List<fs.Node> _luzes = [];

  /// Um objeto de luz do motor por luz da cena (nulo para as que nao
  /// viram objeto, como a ambiente), na ordem de `scene.lights`.
  final List<Object?> _luzObjetos = [];
  String? _assinaturaLuzes;
  String? _chaveAmbiente;
  int _epocaAmbiente = 0;
  bool _descartado = false;

  ReceitaDeQualidade _receita = ReceitaDeQualidade.alta;
  int _capDasTexturas = ReceitaDeQualidade.alta.texturaMax;
  fs.AntiAliasingMode? _aaAplicado;
  Scene3D? _ultimaCena;
  Duration _ultimoT = Duration.zero;
  Scene3D? _cenaRegistrada;
  ui.Size _areaRegistrada = ui.Size.zero;
  bool _dofPedido = false;
  int _tilesDeSombra = 0;
  ui.Size _ultimoAlvo = ui.Size.zero;
  double _ultimaEscala = 1;

  /// A receita em vigor neste motor.
  ReceitaDeQualidade get receita => _receita;

  /// Os objetos de luz do motor, para os testes provarem que uma
  /// intensidade animada NAO recria a luz (e o mapa de sombra dela).
  @visibleForTesting
  List<Object?> get luzesDoMotor => List.unmodifiable(_luzObjetos);

  /// Sincroniza a cena da GPU com [scene] no instante [t].
  ///
  /// Devolve na hora com o que ja esta pronto. Texturas e o ambiente por
  /// imagem chegam depois, em segundo plano, e chamam [onMudou] para o
  /// quadro ser redesenhado.
  ///
  /// [receita] e o nivel de qualidade; sem ela vale a do controlador.
  void sincronizar(
    Scene3D scene,
    Duration t, {
    VoidCallback? onMudou,
    bool rascunho = false,
    ReceitaDeQualidade? receita,
  }) {
    if (_descartado) return;
    final nova = receita ?? ControladorDeQualidade3D.instancia.receita;
    if (nova.nivel != _receita.nivel) {
      _receita = nova;
      // Sombras e MSAA mudam com o nivel: as luzes sao refeitas.
      _assinaturaLuzes = null;
    }
    _ultimaCena = scene;
    _ultimoT = t;
    _aplicarAntialias();
    if (_capDasTexturas != _receita.texturaMax) {
      _retrocarregarTexturas(onMudou);
    }
    _sincronizarNos(scene, t, onMudou);
    _sincronizarLuzes(scene, t);
    _sincronizarAmbiente(scene, t, onMudou);
    _sincronizarNevoa(scene);
    _sincronizarPos(scene, rascunho);
  }

  /// Camera do motor a partir da camera resolvida do dominio, para uma
  /// area de [tamanho] pixels. O campo de visao do dominio e HORIZONTAL;
  /// o do motor, vertical.
  fs.PerspectiveCamera camera(RenderCamera cam, ui.Size tamanho) {
    final basis = cameraBasis(cam);
    final aspecto = tamanho.height <= 0
        ? 16 / 9
        : tamanho.width / tamanho.height;
    final fovX = cam.orthographic ? 0.6 : cam.fovRadians;
    final fovY = 2 * math.atan(math.tan(fovX / 2) / aspecto);
    return fs.PerspectiveCamera(
      position: _v(cam.position),
      target: _v(cam.target),
      up: _v(basis.up),
      fovRadiansY: fovY.clamp(0.05, 3.0),
      fovNear: math.max(1.0, cam.near),
      // Uma cena espacial poe estrelas a dezenas de milhares de
      // unidades; o plano distante do dominio e 100 mil.
      fovFar: math.min(cam.far, 120000),
    );
  }

  /// Profundidade de campo do motor a partir da da camera do dominio.
  ///
  /// A receita manda: abaixo de "media" a profundidade de campo nao
  /// entra — sao dois alvos a mais por quadro.
  void configurarProfundidadeDeCampo(
    Camera3D camera,
    Duration t, {
    bool rascunho = false,
  }) {
    final dof = camera.dof;
    _dofPedido = dof.enabled;
    final ligada = dof.enabled && !rascunho && _receita.dof;
    cena.depthOfField.enabled = ligada;
    if (!ligada) return;
    final focal = camera.focalLength.valueAt(t);
    cena.depthOfField
      ..focusDistance = math.max(1.0, dof.focusDistance.valueAt(t))
      ..fStop = dof.fStopFor(focal, t).clamp(0.5, 32.0)
      ..blurScale = (dof.blurLevel.valueAt(t) / 100).clamp(0.0, 2.0)
      ..bladeCount = irisSides(dof.irisShape)
      ..bladeRotation = dof.irisRotation.valueAt(t) * math.pi / 180;
  }

  /// Desenha a cena em [canvas], dentro de [area].
  ///
  /// No preview a escala do alvo e a menor entre a do rascunho (720 no
  /// lado maior enquanto toca), a da receita e o teto de 1080/1440. Na
  /// EXPORTACAO a resolucao e a da composicao, salvo quando nem a
  /// receita de emergencia cabe na memoria — ai a escala desce ate
  /// caber, e o quadro e ampliado de volta: um quadro menos nitido vale
  /// mais que um app morto no meio da exportacao.
  void desenhar(
    ui.Canvas canvas,
    ui.Rect area,
    fs.Camera camera, {
    bool rascunho = false,
    bool exporting = false,
  }) {
    if (!pronto) return;
    _registrarSeMudou(area.size);
    final controlador = ControladorDeQualidade3D.instancia;
    double escala;
    if (exporting) {
      final ex = controlador.paraExportacao(area.width, area.height);
      if (ex.nivel != _receita.nivel) {
        _receita = ReceitaDeQualidade.de(ex.nivel);
        _assinaturaLuzes = null;
        final cena3d = _ultimaCena;
        if (cena3d != null) {
          _aplicarAntialias();
          _sincronizarLuzes(cena3d, _ultimoT);
          _sincronizarPos(cena3d, false);
        }
      }
      escala = ex.escala;
    } else {
      escala = math.min(
        scenePreviewScale(
          area.width,
          area.height,
          interacting: rascunho,
          exporting: false,
        ),
        escalaDoPreview(area.width, area.height, _receita),
      );
    }
    cena.renderScale = escala;
    _ultimoAlvo = area.size;
    _ultimaEscala = escala;
    cena.render(camera, canvas, viewport: area, pixelRatio: 1.0);
    _publicarEstatisticas();
  }

  /// Conta a cena para o controlador quando a cena (ou a area) muda.
  void _registrarSeMudou(ui.Size area) {
    final cena3d = _ultimaCena;
    if (cena3d == null || area.isEmpty) return;
    final mudouArea =
        (area.width - _areaRegistrada.width).abs() > 2 ||
        (area.height - _areaRegistrada.height).abs() > 2;
    if (identical(cena3d, _cenaRegistrada) && !mudouArea) return;
    _cenaRegistrada = cena3d;
    _areaRegistrada = area;
    ControladorDeQualidade3D.instancia.registrarCena(
      PerfilDaCena.de(cena3d, lod: _receita.lod).comDof(_dofPedido),
      area.width,
      area.height,
    );
  }

  void _publicarEstatisticas() {
    var tri = 0;
    var chamadas = 0;
    for (final n in _nos.values) {
      tri += n.triangulos;
      chamadas += n.geometrias.length;
    }
    final e = Estatisticas3D(
      motor: 'GPU',
      nivel: _receita.nivel,
      triangulos: tri,
      chamadas: chamadas,
      texturas: _texturas.length,
      tilesDeSombra: _tilesDeSombra,
      larguraPx: (_ultimoAlvo.width * _ultimaEscala).round(),
      alturaPx: (_ultimoAlvo.height * _ultimaEscala).round(),
      escala: _ultimaEscala,
    );
    if (PreviewStats.cena3d.value != e) PreviewStats.cena3d.value = e;
  }

  void _aplicarAntialias() {
    final modo = _receita.msaa
        ? fs.AntiAliasingMode.auto
        : fs.AntiAliasingMode.fxaa;
    if (_aaAplicado == modo) return;
    _aaAplicado = modo;
    cena.antiAliasingMode = modo;
  }

  void descartar() {
    _descartado = true;
    _epocaAmbiente++;
    for (final n in _nos.values) {
      n.remover(cena);
    }
    _nos.clear();
    for (final l in _luzes) {
      cena.remove(l);
    }
    _luzes.clear();
    _luzObjetos.clear();
    _texturas.clear();
    _texturasACaminho.clear();
    cena.environment = null;
    cena.skyEnvironment = null;
    cena.skybox = null;
    cena.directionalLight = null;
  }

  // ------------------------------------------------------------- nos

  void _sincronizarNos(Scene3D scene, Duration t, VoidCallback? onMudou) {
    final vivos = <String>{};
    for (final node in scene.nodes) {
      if (!node.visible || node.isNull) continue;
      final xf = resolveNodeTransform(scene, node, t);
      final malha = _malhaDe(node, t);
      if (malha == null) continue;
      vivos.add(node.id);
      var g = _nos[node.id];
      if (g == null || g.assinatura != malha.assinatura) {
        g?.remover(cena);
        g = _construir(node, malha, onMudou);
        _nos[node.id] = g;
      } else if (malha.dinamica && !identical(g.ultimaMalha, malha.malha)) {
        _construir(node, malha, onMudou, existente: g);
      }
      g.transformar(xf, node);
    }
    for (final id in _nos.keys.toList()) {
      if (!vivos.contains(id)) {
        _nos.remove(id)!.remover(cena);
      }
    }
    final usadas = {for (final n in _nos.values) ...n.aplicadores.keys};
    _texturas.removeWhere((path, _) => !usadas.contains(path));
  }

  /// A malha do no neste instante: vertices, faces, normais e UVs por
  /// vertice quando existem (modelos), e o material de cada face.
  _MalhaFonte? _malhaDe(SceneNode node, Duration t) {
    final asset = node.modelAsset;
    if (asset != null) {
      final motion = node.modelMotion;
      final animado =
          motion.keys.isNotEmpty ||
          (motion.clip >= 0 && motion.clip < asset.clips.length);
      final frame = asset.evaluate(t, motion);
      final materiais = node.useModelMaterials
          ? frame.materials
          : List<Material3D>.filled(frame.mesh.faces.length, node.material);
      return _MalhaFonte(
        malha: frame.mesh,
        normais: frame.normals,
        uvs: frame.uvs,
        materiais: materiais,
        dinamica: animado,
        assinatura:
            'm${identityHashCode(asset)}:${identityHashCode(motion)}:${node.instances.isNotEmpty}:'
            '${node.useModelMaterials ? 'a' : _assinaturaMaterial(node.material)}',
      );
    }
    // O LOD: a escolha do no, e no automatico a da receita. A assinatura
    // leva a identidade da malha, entao trocar de LOD refaz o no.
    final escolhida = switch (node.lod) {
      MeshLod3D.low => node.lowMesh ?? node.mediumMesh ?? node.mesh,
      MeshLod3D.medium => node.mediumMesh ?? node.mesh,
      MeshLod3D.high => node.mesh,
      MeshLod3D.auto => _lodPelaReceita(node),
    };
    final mesh = escolhida ?? element3DMesh(node.kind);
    return _MalhaFonte(
      malha: mesh,
      normais: null,
      uvs: null,
      materiais: List<Material3D>.filled(mesh.faces.length, node.material),
      assinatura:
          'p${node.kind.index}:${identityHashCode(mesh)}:${node.instances.isNotEmpty}:${_assinaturaMaterial(node.material)}',
    );
  }

  Element3DMesh? _lodPelaReceita(SceneNode node) => switch (_receita.lod) {
    MeshLod3D.high => node.mesh,
    MeshLod3D.medium => node.mediumMesh ?? node.mesh,
    MeshLod3D.low => node.lowMesh ?? node.mediumMesh ?? node.mesh,
    MeshLod3D.auto => lodAutomatico(node, false),
  };

  static String _assinaturaMaterial(Material3D m) =>
      '${m.baseColor.toARGB32()}:${m.metallic}:${m.roughness}:${m.emissive}:'
      '${m.opacity}:${m.kind.index}:${m.imagePath}:${m.doubleSided}:'
      '${m.alphaCutoff}';

  _NoGpu _construir(
    SceneNode node,
    _MalhaFonte fonte,
    VoidCallback? onMudou, {
    _NoGpu? existente,
  }) {
    // Faces agrupadas por material, em buffers tipados: uma primitiva
    // (uma chamada) por grupo. Ver geometria_gpu.dart.
    final grupos = montarGruposGpu(
      malha: fonte.malha,
      materiais: fonte.materiais,
      normais: fonte.normais,
      uvs: fonte.uvs,
    );

    final no = existente ?? _NoGpu(fonte.assinatura, fs.Node(name: node.name));
    no.ultimaMalha = fonte.malha;
    final instanciado = node.instances.isNotEmpty;
    var triangulos = 0;
    for (final e in grupos.entries) {
      final g = e.value;
      triangulos += g.triangulos;
      final antiga = no.geometrias[e.key];
      if (g.indices == 0 && antiga == null) continue;
      if (antiga != null) {
        final positions = g.positions;
        if (listEquals(no.indices[e.key], g.indexList) &&
            no.tamanhos[e.key] == positions.length) {
          antiga.updatePositions(positions);
          antiga.updateNormals(g.normals);
          antiga.updateTexCoords(g.texCoords);
        } else {
          antiga.rebuild(
            positions: positions,
            normals: g.normals,
            texCoords: g.texCoords,
            indices: g.indexList,
          );
          no.indices[e.key] = g.indexList;
          no.tamanhos[e.key] = positions.length;
        }
        continue;
      }
      final material = _materialGpu(e.key, onMudou, no);
      final geometria = fs.MeshGeometry.fromArrays(
        storage: fonte.dinamica
            ? fs.GeometryStorage.updatable
            : fs.GeometryStorage.fixed,
        positions: g.positions,
        normals: g.normals,
        texCoords: g.texCoords,
        indices: g.indexList,
      );
      no.geometrias[e.key] = geometria;
      no.indices[e.key] = g.indexList;
      no.tamanhos[e.key] = g.positions.length;
      if (instanciado) {
        final im = fs.InstancedMesh(geometry: geometria, material: material);
        no.instancias.add(im);
        final filho = fs.Node()..addComponent(fs.InstancedMeshComponent(im));
        no.no.add(filho);
      } else {
        no.no.add(
          fs.Node()..addComponent(
            fs.MeshComponent(
              fs.Mesh.primitives(
                primitives: [fs.MeshPrimitive(geometria, material)],
              ),
            ),
          ),
        );
      }
    }
    no.triangulos = triangulos;
    if (existente == null) cena.add(no.no);
    return no;
  }

  // ------------------------------------------------------- materiais

  fs.Material _materialGpu(Material3D m, VoidCallback? onMudou, _NoGpu no) {
    final cor = _linear(m.baseColor);
    final opacidade = (m.baseColor.a * m.opacity).clamp(0.0, 1.0);
    final fator = vm.Vector4(cor.x, cor.y, cor.z, opacidade);
    if (m.kind == MaterialKind.unlit) {
      final u = fs.UnlitMaterial();
      u.baseColorFactor = fator;
      u.doubleSided = m.doubleSided;
      if (opacidade < .999) u.alphaMode = fs.AlphaMode.blend;
      _ligarTextura(m.imagePath, onMudou, no, (tex) => u.baseColorTexture = tex);
      return u;
    }
    final p = fs.PhysicallyBasedMaterial();
    p.baseColorFactor = fator;
    p.metallicFactor = m.metallic.clamp(0.0, 1.0);
    p.roughnessFactor = m.roughness.clamp(0.04, 1.0);
    // EMISSIVO forte o bastante para o bloom pegar: o dominio guarda 0..1,
    // e um quadro de HDR acima de 1 e o que separa "claro" de "acende".
    if (m.emissive > 0) {
      final k = m.emissive * 6;
      p.emissiveFactor = vm.Vector4(cor.x * k, cor.y * k, cor.z * k, 1);
    }
    p.doubleSided = m.doubleSided;
    p.alphaMode = switch (m.kind) {
      MaterialKind.transparent => fs.AlphaMode.blend,
      MaterialKind.cutout => fs.AlphaMode.mask,
      _ => opacidade < .999 ? fs.AlphaMode.blend : fs.AlphaMode.opaque,
    };
    p.alphaCutoff = m.alphaCutoff;
    _ligarTextura(m.imagePath, onMudou, no, (tex) => p.baseColorTexture = tex);
    return p;
  }

  /// A textura de [path] sobe para a GPU uma vez; quem precisa dela
  /// recebe pelo [aplicar] — agora, se ja esta la, ou quando chegar.
  ///
  /// O [aplicar] fica guardado no no: quando a receita troca o teto de
  /// textura, a textura sobe de novo no tamanho novo e e reaplicada em
  /// todos os materiais que a usam, sem refazer geometria.
  void _ligarTextura(
    String? path,
    VoidCallback? onMudou,
    _NoGpu no,
    void Function(fs.Texture2D) aplicar,
  ) {
    if (path == null || path.isEmpty) return;
    (no.aplicadores[path] ??= []).add(aplicar);
    final pronta = _texturas[path];
    if (pronta != null) {
      aplicar(pronta);
      return;
    }
    _subirTextura(path, onMudou);
  }

  bool _alguemUsa(String path) =>
      _nos.values.any((n) => n.aplicadores.containsKey(path));

  void _subirTextura(String path, VoidCallback? onMudou) {
    if (_texturasACaminho.containsKey(path)) return;
    final teto = _receita.texturaMax;
    final upload = _uploads.then((_) async {
      try {
        if (_descartado || !_alguemUsa(path)) return;
        final imagem = await _decodificarComTeto(path, teto);
        if (imagem == null || _descartado) return;
        late final fs.Texture2D tex;
        try {
          tex = await fs.Texture2D.fromImage(imagem);
        } finally {
          imagem.dispose();
        }
        if (_descartado || !_alguemUsa(path)) return;
        _texturas[path] = tex;
        for (final n in _nos.values) {
          for (final f in n.aplicadores[path] ?? const <void Function(fs.Texture2D)>[]) {
            f(tex);
          }
        }
        onMudou?.call();
      } catch (e) {
        debugPrint('Textura 3D nao subiu para a GPU ($path): $e');
      } finally {
        _texturasACaminho.remove(path);
      }
    });
    _uploads = upload;
    _texturasACaminho[path] = upload;
  }

  /// A imagem de [path] com no maximo [teto] pixels no lado maior.
  ///
  /// Em 1024 (o teto do TextureCache) a decodificacao e reaproveitada;
  /// nos outros tetos decodifica direto no tamanho pedido — uma textura
  /// de 4096 decodificada inteira e 64 MB antes de qualquer GPU.
  Future<ui.Image?> _decodificarComTeto(String path, int teto) async {
    if (teto == 1024) {
      var imagem = TextureCache.instance.imageFor(path);
      if (imagem == null) {
        await TextureCache.instance.prepare(path);
        imagem = TextureCache.instance.imageFor(path);
      }
      // A decode eviction must not invalidate an upload that is in flight.
      return imagem?.clone();
    }
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      final bytes = path.startsWith('data:')
          ? UriData.parse(path).contentAsBytes()
          : await File(path).readAsBytes();
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final escala = math.min(
        1.0,
        teto / math.max(descriptor.width, descriptor.height),
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * escala).round()),
        targetHeight: math.max(1, (descriptor.height * escala).round()),
      );
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  /// O teto de textura mudou: tudo sobe de novo no tamanho novo.
  void _retrocarregarTexturas(VoidCallback? onMudou) {
    _capDasTexturas = _receita.texturaMax;
    final caminhos = _texturas.keys.toList();
    _texturas.clear();
    for (final p in caminhos) {
      _subirTextura(p, onMudou);
    }
  }

  // ------------------------------------------------------------ luzes

  /// O que muda a ESTRUTURA das luzes (e pede objetos novos). A
  /// intensidade fica de fora de proposito: animada, ela muda a cada
  /// quadro, e refazer a luz a cada quadro refazia o cache de sombra
  /// dela junto — era um atlas de sombra novo por quadro.
  /// O lado do tile de sombra para o alvo do ultimo quadro (a receita,
  /// limitada pelo que o alvo aproveita — ver [sombraEfetiva]).
  int get _ladoDaSombra {
    final maior = (math.max(_ultimoAlvo.width, _ultimoAlvo.height) * _ultimaEscala).round();
    return sombraEfetiva(_receita, maior);
  }

  String _assinaturaDasLuzes(Scene3D scene) {
    final b = StringBuffer('${_receita.nivel.index}:$_ladoDaSombra;');
    for (final l in scene.lights) {
      b.write(
        '${l.kind.index}:${l.castsShadow}:${l.color.toARGB32()}:'
        '${l.direction.x},${l.direction.y},${l.direction.z}:'
        '${l.position.x},${l.position.y},${l.position.z}:'
        '${l.range}:${l.coneDegrees}:${l.softness};',
      );
    }
    return b.toString();
  }

  void _sincronizarLuzes(Scene3D scene, Duration t) {
    final assinatura = _assinaturaDasLuzes(scene);
    if (assinatura == _assinaturaLuzes &&
        _luzObjetos.length == scene.lights.length) {
      _atualizarIntensidades(scene, t);
      return;
    }
    _assinaturaLuzes = assinatura;
    for (final l in _luzes) {
      cena.remove(l);
    }
    _luzes.clear();
    _luzObjetos.clear();
    _tilesDeSombra = 0;

    // A principal e a primeira direcional que faz sombra (ou a primeira
    // direcional): so ela tem cascatas; as outras entram como componentes.
    fs.DirectionalLight? principal;
    var spotsComSombra = 0;
    final ladoDaSombra = math.max(256, _ladoDaSombra);
    for (final l in scene.lights) {
      final i = math.max(0.0, l.intensity.valueAt(t));
      final cor = _linear3(l.color);
      switch (l.kind) {
        case Light3DKind.directional:
          final sombra = l.castsShadow && _receita.sombras;
          final d = fs.DirectionalLight(
            direction: _v(l.direction).normalized(),
            color: cor,
            intensity: i * 2.6,
            castsShadow: sombra && i > 0,
            shadowSoftness: 3 + l.softness.clamp(0.0, 1.0) * 14,
            shadowMaxDistance: 5000,
            shadowCascadeCount: math.max(1, _receita.cascatas),
            shadowMapResolution: ladoDaSombra,
            shadowDepthBias: 0.8,
            shadowNormalBias: 0.8,
            shadowFadeRange: 400,
          );
          if (principal == null || (sombra && !principal.castsShadow)) {
            if (principal != null) {
              _luzes.add(_noDeLuz(fs.DirectionalLightComponent(principal)));
            }
            principal = d;
          } else {
            _luzes.add(_noDeLuz(fs.DirectionalLightComponent(d)));
          }
          _luzObjetos.add(d);
        case Light3DKind.point:
          final alcance = l.range <= 0 ? 1200.0 : l.range;
          final p = fs.PointLight(
            color: cor,
            // O dominio atenua (1 - d/alcance)^2; o motor, 1/d^2. Igualar
            // no meio do alcance: I = i * alcance^2 / 16.
            intensity: i * alcance * alcance / 16,
            range: alcance,
          );
          _luzes.add(_noDeLuz(fs.PointLightComponent(p), posicao: l.position));
          _luzObjetos.add(p);
        case Light3DKind.spot:
          final alcance = l.range <= 0 ? 1200.0 : l.range;
          final externo = l.coneDegrees.clamp(1.0, 179.0) * math.pi / 360;
          // SOMBRA DE SPOT E CARA: cada uma e um tile inteiro no atlas.
          // A receita diz quantas cabem; as outras iluminam sem sombra.
          final sombra =
              l.castsShadow &&
              _receita.sombras &&
              spotsComSombra < _receita.sombrasSpotMax;
          if (sombra) spotsComSombra++;
          final s = fs.SpotLight(
            color: cor,
            intensity: i * alcance * alcance / 16,
            range: alcance,
            direction: _v(l.direction).normalized(),
            innerConeAngle: externo * (1 - l.softness.clamp(0.0, 1.0) * .9),
            outerConeAngle: externo,
            castsShadow: sombra && i > 0,
            shadowMapResolution: math.min(512, ladoDaSombra),
            shadowSoftness: 2 + l.softness * 6,
          );
          _luzes.add(_noDeLuz(fs.SpotLightComponent(s), posicao: l.position));
          _luzObjetos.add(s);
        case Light3DKind.ambient:
          // Entra no ambiente (ver _sincronizarAmbiente).
          _luzObjetos.add(null);
      }
    }
    cena.directionalLight = principal;
    if (principal != null && principal.castsShadow) {
      _tilesDeSombra += principal.shadowCascadeCount;
    }
    _tilesDeSombra += spotsComSombra;
    for (final n in _luzes) {
      cena.add(n);
    }
  }

  /// So o que muda por quadro: a intensidade — e a sombra de quem
  /// apagou, que nao precisa ser desenhada.
  void _atualizarIntensidades(Scene3D scene, Duration t) {
    for (var k = 0; k < scene.lights.length; k++) {
      final l = scene.lights[k];
      final o = _luzObjetos[k];
      final i = math.max(0.0, l.intensity.valueAt(t));
      switch (o) {
        case fs.DirectionalLight d:
          d.intensity = i * 2.6;
          d.castsShadow = l.castsShadow && _receita.sombras && i > 0;
        case fs.PointLight p:
          final alcance = l.range <= 0 ? 1200.0 : l.range;
          p.intensity = i * alcance * alcance / 16;
        case fs.SpotLight s:
          final alcance = l.range <= 0 ? 1200.0 : l.range;
          s.intensity = i * alcance * alcance / 16;
          if (i <= 0) s.castsShadow = false;
        default:
          break;
      }
    }
  }

  fs.Node _noDeLuz(fs.Component componente, {Vec3? posicao}) {
    final no = fs.Node(
      localTransform: posicao == null
          ? null
          : vm.Matrix4.translation(_v(posicao)),
    );
    no.addComponent(componente);
    return no;
  }

  // --------------------------------------------------------- ambiente

  void _sincronizarAmbiente(Scene3D scene, Duration t, VoidCallback? onMudou) {
    var extra = 0.0;
    for (final l in scene.lights) {
      if (l.kind == Light3DKind.ambient) extra += l.intensity.valueAt(t);
    }
    final pano = scene.panorama;
    cena.environmentIntensity =
        ((scene.ambient + extra) / .28) * pano.intensity.clamp(0.0, 4.0);
    final caminho = pano.hasImage ? pano.sourcePath : null;
    final chave = caminho != null
        ? 'img:$caminho:${pano.showBackground}:${pano.backgroundBlur}'
        : 'ceu:${scene.environment.index}:${scene.skyColor.toARGB32()}:'
              '${scene.groundColor.toARGB32()}:${pano.showBackground}';
    if (chave == _chaveAmbiente) return;
    _chaveAmbiente = chave;
    final epoca = ++_epocaAmbiente;

    if (caminho != null) {
      () async {
        try {
          final bytes = await File(caminho).readAsBytes();
          final mapa = await fs.EnvironmentMap.fromEquirectImageBytes(
            bytes: bytes,
            maxWidth: 2048,
          );
          if (_descartado || epoca != _epocaAmbiente) return;
          cena.skyEnvironment = null;
          cena.environment = mapa;
          cena.skybox = pano.showBackground
              ? fs.Skybox(
                  fs.EnvironmentSkySource(
                    blurriness: (pano.backgroundBlur / 30).clamp(0.0, 1.0),
                  ),
                )
              : null;
          onMudou?.call();
        } catch (e) {
          debugPrint('Panorama nao carregou na GPU ($caminho): $e');
        }
      }();
      return;
    }

    // CEU PROCEDURAL a partir das cores do dominio: zenite = ceu, chao =
    // chao, horizonte no meio, e o sol na direcao da luz principal.
    final ceu = _linear3(scene.skyColor);
    final chao = _linear3(scene.groundColor);
    final horizonte = (ceu + chao) * .5;
    vm.Vector3 sol = vm.Vector3(0.4, 0.5, 0.6);
    vm.Vector3 corDoSol = vm.Vector3(3.0, 2.7, 2.2);
    for (final l in scene.lights) {
      if (l.kind == Light3DKind.directional && l.intensity.valueAt(t) > 0) {
        sol = (_v(l.direction) * -1).normalized();
        corDoSol = _linear3(l.color) * 3.0;
        break;
      }
    }
    final fonte = fs.GradientSkySource(
      zenithColor: ceu,
      horizonColor: horizonte,
      groundColor: chao,
      sunDirection: sol,
      sunColor: corDoSol,
    );
    cena.environment = null;
    cena.skyEnvironment = fs.SkyEnvironment(fonte);
    cena.skybox = pano.showBackground ? fs.Skybox(fonte) : null;
  }

  // ----------------------------------------------------------- neblina

  void _sincronizarNevoa(Scene3D scene) {
    final f = cena.fog;
    f.enabled = scene.fogDensity > 0;
    if (!f.enabled) return;
    f
      ..mode = fs.FogMode.exponential
      ..density = scene.fogDensity
      ..start = scene.fogStart
      ..color = _linear3(scene.fogColor)
      ..maxOpacity = 1.0;
  }

  // --------------------------------------------------------------- pos

  void _sincronizarPos(Scene3D scene, bool rascunho) {
    var emissivo = false;
    for (final n in scene.nodes) {
      if (n.material.emissive > 0) {
        emissivo = true;
        break;
      }
      final mats = n.modelAsset?.data['materials'] as List? ?? const [];
      for (final m in mats) {
        if (((m as Map)['emissive'] as num? ?? 0) > 0) {
          emissivo = true;
          break;
        }
      }
      if (emissivo) break;
    }
    // O bloom monta uma cadeia de mips do tamanho da tela a cada
    // quadro. Enquanto toca, isso e memoria e banda de GPU trocadas por
    // um brilho que ninguem esta olhando parado — e abaixo de "media" a
    // receita o tira de vez.
    cena.postProcess.bloom
      ..enabled = emissivo && !rascunho && _receita.bloom
      ..threshold = 1.0
      ..intensity = .45
      ..scatter = .7;
    cena.toneMapping = fs.ToneMappingMode.pbrNeutral;
  }

  // ---------------------------------------------------------- utilidades

  static vm.Vector3 _v(Vec3 v) => vm.Vector3(v.x, v.y, v.z);

  static double _lin(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  static vm.Vector3 _linear3(ui.Color c) =>
      vm.Vector3(_lin(c.r), _lin(c.g), _lin(c.b));

  static vm.Vector3 _linear(ui.Color c) => _linear3(c);
}

/// Um no do dominio ja traduzido: o no do motor e a assinatura do que
/// ele contem. Quando a assinatura muda, o no e refeito.
class _NoGpu {
  _NoGpu(this.assinatura, this.no);

  final String assinatura;
  final fs.Node no;
  final List<fs.InstancedMesh> instancias = [];
  final Map<Material3D, fs.MeshGeometry> geometrias = {};
  final Map<Material3D, List<int>> indices = {};
  final Map<Material3D, int> tamanhos = {};

  /// Por caminho de textura, quem a recebe (os materiais deste no).
  final Map<String, List<void Function(fs.Texture2D)>> aplicadores = {};
  int triangulos = 0;
  Element3DMesh? ultimaMalha;
  List<Vec3>? _ultimasInstancias;
  double? _ultimoTamanho;

  void transformar(NodeTransform xf, SceneNode node) {
    final rad = math.pi / 180;
    final m = vm.Matrix4.translation(
      vm.Vector3(xf.position.x, xf.position.y, xf.position.z),
    );
    m.multiply(vm.Matrix4.rotationZ(xf.rotZ * rad));
    m.multiply(vm.Matrix4.rotationY(xf.rotY * rad));
    m.multiply(vm.Matrix4.rotationX(xf.rotX * rad));
    if (instancias.isEmpty) {
      final s = node.size * xf.scale;
      m.multiply(vm.Matrix4.diagonal3Values(s, s, s));
      no.localTransform = m;
      return;
    }
    // Instancias: o no leva posicao, rotacao e escala; cada instancia
    // leva o deslocamento e o tamanho da malha unitaria.
    m.multiply(vm.Matrix4.diagonal3Values(xf.scale, xf.scale, xf.scale));
    no.localTransform = m;
    if (!identical(_ultimasInstancias, node.instances) ||
        _ultimoTamanho != node.size) {
      _ultimasInstancias = node.instances;
      _ultimoTamanho = node.size;
      for (final im in instancias) {
        im.clearInstances();
        for (final p in node.instances) {
          im.addInstance(
            vm.Matrix4.translation(vm.Vector3(p.x, p.y, p.z))..multiply(
              vm.Matrix4.diagonal3Values(node.size, node.size, node.size),
            ),
          );
        }
      }
    }
  }

  void remover(fs.Scene cena) => cena.remove(no);
}

class _MalhaFonte {
  _MalhaFonte({
    required this.malha,
    required this.normais,
    required this.uvs,
    required this.materiais,
    required this.assinatura,
    this.dinamica = false,
  });

  final Element3DMesh malha;
  final List<Vec3?>? normais;
  final List<ui.Offset?>? uvs;
  final List<Material3D> materiais;
  final String assinatura;
  final bool dinamica;
}
