import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

/// IMAGENS QUE VESTEM OBJETOS 3D, decodificadas uma vez e guardadas.
///
/// O pintor pede a imagem de forma SINCRONA no meio do paint: se ela ja
/// esta aqui, pinta com ela; se nao, pinta a cor lisa e dispara a
/// leitura. Quando a leitura termina, [revision] muda e quem escuta
/// repinta — a textura "chega" sem ninguem ter de esperar por ela.
///
/// Decodifica no maximo a 1024 px de largura: e textura de face, nao
/// foto de galeria, e cada face em tela raramente passa de algumas
/// centenas de pixels.
class TextureCache {
  TextureCache._();

  static final TextureCache instance = TextureCache._();

  /// Sobe a cada imagem que termina de carregar.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  final Map<String, ui.Image> _images = {};
  final Set<String> _loading = {};
  final Set<String> _failed = {};
  final Map<String, Future<void>> _pending = {};

  /// A imagem de [path], ou null se ainda nao chegou (ou falhou).
  ui.Image? imageFor(String path) {
    final img = _images[path];
    if (img != null) return img;
    if (!_failed.contains(path)) {
      unawaited(_loadOnce(path));
    }
    return null;
  }

  /// Decodifica [path] e so conclui quando a imagem pode ser usada pelo
  /// pintor. Chamadas concorrentes compartilham a mesma leitura.
  Future<bool> prepare(String path) async {
    if (path.isEmpty) return false;
    if (_images.containsKey(path)) return true;
    if (_failed.contains(path)) return false;
    await _loadOnce(path);
    return _images.containsKey(path);
  }

  /// Para testes e para trocar a imagem de um caminho reaproveitado.
  void put(String path, ui.Image image) {
    _images[path]?.dispose();
    _images[path] = image;
    _failed.remove(path);
    revision.value++;
  }

  Future<void> _loadOnce(String path) {
    final running = _pending[path];
    if (running != null) return running;
    final future = _load(path);
    _pending[path] = future;
    return future.whenComplete(() {
      _pending.remove(path);
    });
  }

  Future<void> _load(String path) async {
    _loading.add(path);
    try {
      final bytes = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 1024);
      final frame = await codec.getNextFrame();
      codec.dispose();
      _images[path] = frame.image;
      revision.value++;
    } catch (_) {
      _failed.add(path);
    } finally {
      _loading.remove(path);
    }
  }

  void clear() {
    for (final img in _images.values) {
      img.dispose();
    }
    _images.clear();
    _failed.clear();
  }
}
