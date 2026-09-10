import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/layer.dart';
import '../domain/project_store.dart';

/// UM PRESET DE CAMADA: as propriedades e os keyframes dela, guardados
/// para reusar noutra camada ou noutro projeto.
@immutable
class LayerPreset {
  const LayerPreset({
    required this.id,
    required this.nome,
    required this.tipo,
    required this.dados,
  });

  final String id;
  final String nome;

  /// O tipo da camada de origem, em palavras. Serve para dizer de onde
  /// o preset veio; ele pode ser aplicado em qualquer camada, porque o
  /// que se copia sao TRANSFORMACAO, opacidade e efeitos — coisas que
  /// toda camada tem.
  final String tipo;

  /// A camada de origem serializada com a MESMA serializacao do projeto:
  /// o que o projeto sabe guardar, o preset tambem sabe.
  final Map<String, dynamic> dados;
}

/// PRESETS DE CAMADA DA PESSOA, guardados FORA do projeto.
///
/// A superficie de Presets da grade contextual (V, pagina 20) abria um
/// vazio no AM; aqui ela abre o vazio COM os dois caminhos reais que a
/// especificacao exige — salvar o que esta na camada, e trazer o que
/// veio de fora. Um preset que so existisse dentro do projeto em que
/// nasceu nao seria preset.
class LayerPresetStore {
  LayerPresetStore._();

  static final LayerPresetStore instance = LayerPresetStore._();

  /// Sobe a cada mudanca na lista.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  List<LayerPreset> _presets = const [];
  bool _carregado = false;
  Future<void>? _carregando;

  /// Para testes: guarda em memoria, sem arquivo.
  @visibleForTesting
  static bool semArquivo = false;

  List<LayerPreset> get presets => List.unmodifiable(_presets);

  Future<File> _arquivo() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/layer_presets.json');
  }

  Future<void> load() {
    if (_carregado) return Future.value();
    return _carregando ??= _load().whenComplete(() {
      _carregado = true;
      _carregando = null;
    });
  }

  Future<void> _load() async {
    if (semArquivo) return;
    try {
      final f = await _arquivo();
      if (!f.existsSync()) return;
      final raw = jsonDecode(await f.readAsString());
      if (raw is! List) return;
      _presets = [
        for (final m in raw)
          if (m is Map<String, dynamic> &&
              m['id'] is String &&
              m['nome'] is String &&
              m['dados'] is Map<String, dynamic>)
            LayerPreset(
              id: m['id'] as String,
              nome: m['nome'] as String,
              tipo: (m['tipo'] as String?) ?? '',
              dados: m['dados'] as Map<String, dynamic>,
            ),
      ];
      revision.value++;
    } on Object {
      // ARQUIVO ILEGIVEL NAO DERRUBA O EDITOR. A mesma regra tolerante
      // do projeto: o que nao abre e pulado, e o resto vale.
    }
  }

  Future<void> _persist() async {
    if (semArquivo) return;
    try {
      final f = await _arquivo();
      await f.writeAsString(
        jsonEncode([
          for (final p in _presets)
            {'id': p.id, 'nome': p.nome, 'tipo': p.tipo, 'dados': p.dados},
        ]),
      );
    } on Object {
      // Sem disco, a lista continua valendo nesta sessao.
    }
  }

  /// GUARDA UMA CAMADA COMO PRESET.
  ///
  /// O que entra e a camada inteira, com transformacao, opacidade,
  /// efeitos e todos os keyframes — a serializacao e a mesma do projeto.
  Future<LayerPreset> salvar(Layer camada, String nome, String tipo) async {
    final preset = LayerPreset(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      nome: nome,
      tipo: tipo,
      dados: layerToJson(camada),
    );
    _presets = [..._presets, preset];
    revision.value++;
    await _persist();
    return preset;
  }

  /// TRAZ UM PRESET DE FORA (o JSON que outra pessoa exportou).
  Future<LayerPreset?> importar(String json) async {
    try {
      final m = jsonDecode(json);
      if (m is! Map<String, dynamic> || m['dados'] is! Map<String, dynamic>) {
        return null;
      }
      final preset = LayerPreset(
        id: '${DateTime.now().microsecondsSinceEpoch}',
        nome: (m['nome'] as String?) ?? 'Preset importado',
        tipo: (m['tipo'] as String?) ?? '',
        dados: m['dados'] as Map<String, dynamic>,
      );
      _presets = [..._presets, preset];
      revision.value++;
      await _persist();
      return preset;
    } on Object {
      return null;
    }
  }

  /// O JSON de um preset, para mandar para outra pessoa.
  String exportar(LayerPreset p) =>
      jsonEncode({'nome': p.nome, 'tipo': p.tipo, 'dados': p.dados});

  Future<void> remover(String id) async {
    _presets = [
      for (final p in _presets)
        if (p.id != id) p,
    ];
    revision.value++;
    await _persist();
  }

  @visibleForTesting
  void limparParaTeste() {
    _presets = const [];
    _carregado = true;
    revision.value++;
  }
}
