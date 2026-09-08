import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/post_da_comunidade.dart';

/// A COMUNIDADE, do arquivo ate a tela.
///
/// COMO ISTO FUNCIONA: o app le e escreve num servidor proprio. Publicar
/// e direto — sem e-mail, sem ninguem no meio.
///
/// A chave de escrita mora NO SERVIDOR, e nao aqui. Um APK e um zip:
/// qualquer chave dentro dele e publica, e quem a extrai reescreve ou
/// apaga o mural inteiro. O aplicativo so conversa com o servidor; quem
/// escreve e ele.
///
/// O FILTRO EXISTE DOS DOIS LADOS de proposito. O daqui e cortesia: diz
/// a pessoa o que esta errado enquanto ela escreve. O de la e o que vale,
/// porque quem chama o endereco direto nao passa por este.
///
/// O POST APARECE NA HORA PARA QUEM ESCREVEU, mesmo que o servidor leve
/// ate um minuto para publica-lo para os outros (o armazenamento e
/// distribuido e propaga nesse ritmo). A copia local some sozinha quando
/// a do servidor chega — as duas tem o mesmo id.
class ComunidadeService {
  ComunidadeService({HttpClient? http, this.endereco = enderecoPadrao})
    : _http = http ?? (HttpClient()..connectionTimeout = _tempoLimite);

  static const _tempoLimite = Duration(seconds: 10);

  /// O SERVIDOR DO MURAL. O codigo dele esta em servidor/comunidade.
  static const enderecoPadrao = 'https://mural-do-aurea.aureaapp.workers.dev';

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
    final feed = _feed ?? const <PostDaComunidade>[];
    // O MESMO POST NAO APARECE DUAS VEZES.
    //
    // Ao publicar, a copia local entra na hora e a do servidor chega ate
    // um minuto depois — com o mesmo id, porque e o aplicativo que o
    // gera. Sem esta limpeza, o mural mostraria o post repetido nesse
    // intervalo, e quem escreveu acharia que publicou sem querer duas
    // vezes.
    final noServidor = {for (final p in feed) p.id};
    final pendentes = [
      for (final p in meus)
        if (!noServidor.contains(p.id)) p,
    ];
    if (pendentes.length != meus.length) {
      _meus = pendentes;
      await _gravarMeus();
    }
    return [...pendentes, ...feed];
  }

  Future<void> _buscarFeed() async {
    try {
      final req = await _http.getUrl(Uri.parse('$endereco/feed'));
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

  /// MANDA O POST PARA O SERVIDOR.
  ///
  /// Devolve null se entrou, ou o motivo em portugues se nao entrou. O
  /// motivo vem do proprio servidor quando ele recusa (ofensa, dado
  /// pessoal, limite por hora), porque quem sabe a regra e ele — repetir
  /// a regra aqui so criaria duas versoes da verdade.
  Future<String?> enviar(PostDaComunidade post, String contaId) async {
    try {
      final req = await _http.postUrl(Uri.parse('$endereco/post'));
      req.headers.set('content-type', 'application/json; charset=utf-8');
      // NAO E IDENTIDADE: e so um numero para o servidor contar quantos
      // posts vieram do mesmo lugar na ultima hora.
      req.headers.set('x-aurea-conta', contaId);
      req.add(utf8.encode(jsonEncode(post.toJson())));
      final res = await req.close().timeout(_tempoLimite);
      final corpo = await res.transform(utf8.decoder).join();
      if (res.statusCode == 201) return null;
      try {
        final m = (jsonDecode(corpo) as Map).cast<String, dynamic>();
        final erro = m['erro'];
        if (erro is String && erro.isNotEmpty) return erro;
      } catch (_) {}
      return 'O mural recusou o post (${res.statusCode}).';
    } on SocketException {
      return 'Sem conexão. O post ficou guardado aqui e você pode '
          'tentar de novo.';
    } catch (_) {
      return 'Não consegui falar com o mural agora. O post ficou '
          'guardado aqui.';
    }
  }

  /// O post no formato em que ele entra no feed — usado pelo caminho de
  /// reserva, quando o servidor nao responde.
  String comoJson(PostDaComunidade post) =>
      const JsonEncoder.withIndent('  ').convert(post.toJson());
}
