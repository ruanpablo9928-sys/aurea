import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/post_da_comunidade.dart';

/// A COMUNIDADE, do arquivo ate a tela.
///
/// COMO ISTO FUNCIONA HOJE, sem meias palavras: o app LE um feed publico
/// (um gist) e ESCREVE localmente. Um post escrito aqui aparece na hora
/// para quem escreveu, marcado como "so voce ve", e vai para publicacao
/// pelo mesmo caminho que os relatos de bug ja usam.
///
/// Por que assim: publicar direto do aparelho exige um servidor com
/// conta e senha, e nao ha nenhum. A alternativa seria embutir uma chave
/// de escrita no APK — o que, na pratica, e dar a chave para qualquer um
/// que abra o arquivo. Ler de um endereco publico funciona hoje, para
/// todo mundo, sem segredo nenhum.
///
/// O endereco e trocavel ([endereco]). No dia em que existir um
/// servico de verdade, muda-se uma linha e o resto do app nao percebe.
class ComunidadeService {
  ComunidadeService({HttpClient? http, this.endereco = enderecoPadrao})
    : _http = http ?? (HttpClient()..connectionTimeout = _tempoLimite);

  static const _tempoLimite = Duration(seconds: 10);

  /// O FEED PUBLICO DO PROJETO.
  ///
  /// Um gist publico, e nao um arquivo no repositorio, porque o
  /// repositorio do app e privado — de la o aparelho de ninguem
  /// conseguiria ler. O gist e publico, serve por CDN, nao pede conta e
  /// se edita numa linha para publicar um post novo.
  static const enderecoPadrao =
      'https://gist.githubusercontent.com/ueeruan/'
      '6d8c4adf3d31d6061a54fcfc13e55487/raw/feed.json';

  static final instance = ComunidadeService();

  final HttpClient _http;
  final String endereco;

  /// Sobe quando o conteudo muda — a aba escuta.
  final ValueNotifier<int> revisao = ValueNotifier(0);

  List<PostDaComunidade>? _feed;
  List<PostDaComunidade>? _meus;

  /// A ultima falha de rede, em palavras. Nulo = deu certo.
  String? ultimoErro;

  Future<Directory> _pasta() async {
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}/comunidade');
    if (!d.existsSync()) d.createSync(recursive: true);
    return d;
  }

  File _arquivo(Directory d, String nome) => File('${d.path}/$nome');

  /// O QUE APARECE NA ABA: os meus primeiro, depois o feed.
  ///
  /// Os meus vem na frente de proposito. Quem acabou de escrever quer ver
  /// o que escreveu; um post que some no meio de uma lista parece perdido.
  Future<List<PostDaComunidade>> carregar({bool daRede = true}) async {
    final meus = await meusPosts();
    if (daRede || _feed == null) {
      await _buscarFeed();
    }
    return [...meus, ...(_feed ?? const [])];
  }

  Future<void> _buscarFeed() async {
    try {
      final req = await _http.getUrl(Uri.parse(endereco));
      final res = await req.close().timeout(_tempoLimite);
      if (res.statusCode != 200) {
        throw HttpException('resposta ${res.statusCode}');
      }
      final corpo = await res.transform(utf8.decoder).join();
      final posts = lerFeed(corpo);
      _feed = posts;
      ultimoErro = null;
      // GRAVA O QUE CHEGOU. Comunidade que so existe com internet nao
      // serve para quem edita no onibus.
      try {
        final d = await _pasta();
        await _arquivo(d, 'feed.json').writeAsString(corpo, flush: true);
      } catch (_) {}
    } catch (e) {
      ultimoErro = e is SocketException || e is HttpException
          ? 'Sem conexão com a comunidade.'
          : 'Não consegui ler a comunidade agora.';
      // Cai para o que ja foi lido antes.
      if (_feed == null) {
        try {
          final f = _arquivo(await _pasta(), 'feed.json');
          if (f.existsSync()) _feed = lerFeed(await f.readAsString());
        } catch (_) {}
      }
    }
    revisao.value++;
  }

  /// Os posts escritos neste aparelho.
  Future<List<PostDaComunidade>> meusPosts() async {
    if (_meus != null) return _meus!;
    try {
      final f = _arquivo(await _pasta(), 'meus.json');
      _meus = f.existsSync() ? lerFeed(await f.readAsString()) : [];
    } catch (_) {
      _meus = [];
    }
    return _meus!;
  }

  Future<void> _gravarMeus() async {
    try {
      final f = _arquivo(await _pasta(), 'meus.json');
      await f.writeAsString(escreverFeed(_meus ?? const []), flush: true);
    } catch (_) {}
    revisao.value++;
  }

  Future<void> publicar(PostDaComunidade post) async {
    final lista = [...await meusPosts()];
    lista.removeWhere((p) => p.id == post.id);
    lista.insert(0, post);
    _meus = lista;
    await _gravarMeus();
  }

  Future<void> apagar(String id) async {
    final lista = [...await meusPosts()]..removeWhere((p) => p.id == id);
    _meus = lista;
    await _gravarMeus();
  }

  Future<void> marcarEnviado(String id) async {
    final lista = [
      for (final p in await meusPosts())
        p.id == id ? p.copyWith(estado: EstadoDoPost.enviado) : p,
    ];
    _meus = lista;
    await _gravarMeus();
  }

  /// O post no formato em que ele entra no feed — e o que a pessoa manda
  /// para publicacao.
  String comoJson(PostDaComunidade post) =>
      const JsonEncoder.withIndent('  ').convert(post.toJson());
}
