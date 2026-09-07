import 'dart:convert';

/// UM POST DA COMUNIDADE.
///
/// O que a comunidade de um app de edicao precisa carregar e pouco: quem
/// fez, o que escreveu, uma imagem do trabalho e quando. Tudo o mais
/// (curtidas, comentarios, seguidores) e infraestrutura social que so
/// faz sentido depois que ha gente postando — e ainda nao ha.
class PostDaComunidade {
  const PostDaComunidade({
    required this.id,
    required this.autor,
    required this.texto,
    required this.quando,
    this.imagem,
    this.imagemLocal = false,
    this.link,
    this.etiquetas = const [],
    this.estado = EstadoDoPost.publicado,
  });

  final String id;
  final String autor;
  final String texto;
  final DateTime quando;

  /// Endereco da imagem: uma URL quando veio do feed, um caminho de
  /// arquivo quando e um post ainda nao publicado.
  final String? imagem;
  final bool imagemLocal;

  /// Link opcional (um video publicado, um perfil).
  final String? link;

  final List<String> etiquetas;
  final EstadoDoPost estado;

  bool get meu => estado != EstadoDoPost.publicado;

  /// "agora", "há 3 h", "há 2 d" — data cheia so acima de uma semana.
  ///
  /// Quem abre uma comunidade quer saber se a coisa esta viva, e "há 3 h"
  /// responde isso; "07/09/2026 14:12" faz a pessoa calcular.
  String quandoEmPalavras([DateTime? agora]) {
    final d = (agora ?? DateTime.now()).difference(quando);
    if (d.inMinutes < 1) return 'agora';
    if (d.inMinutes < 60) return 'há ${d.inMinutes} min';
    if (d.inHours < 24) return 'há ${d.inHours} h';
    if (d.inDays < 7) return 'há ${d.inDays} d';
    final dd = quando.day.toString().padLeft(2, '0');
    final mm = quando.month.toString().padLeft(2, '0');
    return '$dd/$mm/${quando.year}';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'autor': autor,
    'texto': texto,
    'quando': quando.toUtc().toIso8601String(),
    if (imagem != null) 'imagem': imagem,
    if (imagemLocal) 'imagemLocal': true,
    if (link != null) 'link': link,
    if (etiquetas.isNotEmpty) 'etiquetas': etiquetas,
    if (estado != EstadoDoPost.publicado) 'estado': estado.name,
  };

  /// Um post do feed. Devolve null quando falta o essencial — um item
  /// estragado no meio do arquivo nao pode derrubar o feed inteiro.
  static PostDaComunidade? deJson(Object? bruto) {
    if (bruto is! Map) return null;
    final m = bruto.cast<String, dynamic>();
    final texto = m['texto'];
    if (texto is! String || texto.trim().isEmpty) return null;
    DateTime quando;
    try {
      quando = DateTime.parse('${m['quando']}').toLocal();
    } catch (_) {
      quando = DateTime.now();
    }
    return PostDaComunidade(
      id: '${m['id'] ?? quando.microsecondsSinceEpoch}',
      autor: '${m['autor'] ?? 'Anônimo'}',
      texto: texto,
      quando: quando,
      imagem: m['imagem'] as String?,
      imagemLocal: m['imagemLocal'] == true,
      link: m['link'] as String?,
      etiquetas: [
        for (final e in (m['etiquetas'] as List? ?? const [])) '$e',
      ],
      estado: EstadoDoPost.values.firstWhere(
        (e) => e.name == m['estado'],
        orElse: () => EstadoDoPost.publicado,
      ),
    );
  }

  PostDaComunidade copyWith({EstadoDoPost? estado}) => PostDaComunidade(
    id: id,
    autor: autor,
    texto: texto,
    quando: quando,
    imagem: imagem,
    imagemLocal: imagemLocal,
    link: link,
    etiquetas: etiquetas,
    estado: estado ?? this.estado,
  );
}

enum EstadoDoPost {
  /// Esta no feed que todo mundo ve.
  publicado,

  /// Escrito aqui e ainda nao enviado.
  rascunho,

  /// Enviado para publicacao, esperando entrar no feed.
  enviado,
}

/// LE UM FEED INTEIRO.
///
/// Aceita as duas formas que um arquivo de feed costuma ter: a lista
/// direta e o objeto com a lista dentro de `posts`. Custa tres linhas e
/// evita que uma escolha de formato do servidor quebre o app.
List<PostDaComunidade> lerFeed(String fonte) {
  try {
    final bruto = jsonDecode(fonte);
    final lista = bruto is List
        ? bruto
        : (bruto is Map ? bruto['posts'] as List? ?? const [] : const []);
    final posts = <PostDaComunidade>[];
    for (final item in lista) {
      final p = PostDaComunidade.deJson(item);
      if (p != null) posts.add(p);
    }
    // O mais novo primeiro: e a ordem que uma comunidade tem.
    posts.sort((a, b) => b.quando.compareTo(a.quando));
    return posts;
  } catch (_) {
    return const [];
  }
}

String escreverFeed(List<PostDaComunidade> posts) =>
    jsonEncode({'posts': [for (final p in posts) p.toJson()]});
