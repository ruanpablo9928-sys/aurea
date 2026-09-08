import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aurea/src/features/community/application/comunidade_service.dart';
import 'package:aurea/src/features/community/domain/post_da_comunidade.dart';
import 'package:flutter_test/flutter_test.dart';

class _Headers implements HttpHeaders {
  final values = <String, Object>{};
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) =>
      values[name] = value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  @override
  int get statusCode => 201;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(utf8.encode('{}')).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Request implements HttpClientRequest {
  @override
  final _Headers headers = _Headers();
  final body = <int>[];
  @override
  void add(List<int> data) => body.addAll(data);
  @override
  Future<HttpClientResponse> close() async => _Response();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Http implements HttpClient {
  final requests = <_Request>[];
  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    final request = _Request();
    requests.add(request);
    return request;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Service extends ComunidadeService {
  _Service(_Http http, {this.fail = false}) : super(http: http);
  final bool fail;
  String? uploadCode;
  String? uploadType;
  PostDaComunidade? cached;
  @override
  Future<ArquivoNoMural> subirArquivo(
    File file,
    String tipo,
    String codigo,
  ) async {
    uploadCode = codigo;
    uploadType = tipo;
    return fail
        ? const ArquivoNoMural(erro: 'Falha simulada')
        : const ArquivoNoMural(url: 'https://example.invalid/midia/test.png');
  }

  @override
  Future<void> publicar(PostDaComunidade post) async => cached = post;
}

void main() {
  for (final fail in [false, true]) {
    test(
      'local attachment is uploaded before posting, failure=$fail',
      () async {
        final http = _Http();
        final service = _Service(http, fail: fail);
        final post = PostDaComunidade(
          id: 'test',
          autor: 'Ana',
          texto: 'Teste',
          quando: DateTime(2026),
          imagem: '/local/photo.png',
          imagemLocal: true,
        );
        final error = await service.enviar(post, 'test-credential');
        expect(service.uploadCode, 'test-credential');
        expect(service.uploadType, 'image/png');
        if (fail) {
          expect(error, 'Falha simulada');
          expect(http.requests, isEmpty);
        } else {
          expect(error, isNull);
          final request = http.requests.single;
          expect(
            request.headers.values['authorization'],
            'Bearer test-credential',
          );
          final body = jsonDecode(utf8.decode(request.body)) as Map;
          expect(body['imagem'], 'https://example.invalid/midia/test.png');
          expect(
            body['imagemLocal'],
            isNot(true),
            reason: 'remote media omits the local flag',
          );
          expect(service.cached?.imagemLocal, isFalse);
        }
      },
    );
  }
}
