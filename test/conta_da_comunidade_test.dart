import 'dart:convert';

import 'package:aurea/src/core/storage/prefs.dart';
import 'package:aurea/src/features/community/application/conta_da_comunidade.dart';
import 'package:aurea/src/features/community/application/comunidade_service.dart';
import 'package:aurea/src/features/community/domain/post_da_comunidade.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AccountService extends ComunidadeService {
  @override
  Future<RespostaDaConta> criarConta(String apelido) async =>
      RespostaDaConta(id: 'test-account', apelido: apelido, codigo: 'a' * 48);
  @override
  Future<RespostaDaConta> trocarApelido(String codigo, String apelido) async =>
      RespostaDaConta(id: 'test-account', apelido: apelido);
}

/// A MINI CONTA e o que a MIDIA carrega.
///
/// A conta e local e sem senha, entao o que se testa nao e seguranca: e
/// que ela sobrevive ao fechar o app, que o apelido passa pelo filtro uma
/// vez so, e que apagar a conta nao apaga o que a pessoa ja disse aos
/// outros.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> comPrefs([Map<String, Object> inicial = const {}]) async {
    SharedPreferences.setMockInitialValues(inicial);
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs),
        comunidadeServiceProvider.overrideWithValue(_AccountService())],
    );
    addTearDown(c.dispose);
    return c;
  }

  group('conta', () {
    test('nasce vazia e e criada em um passo', () async {
      final c = await comPrefs();
      expect(c.read(contaDaComunidadeProvider), isNull);
      final erro = await c.read(contaDaComunidadeProvider.notifier).criar('Ana Motion');
      expect(erro, isNull);
      final conta = c.read(contaDaComunidadeProvider)!;
      expect(conta.apelido, 'Ana Motion');
      expect(conta.id, isNotEmpty);
      expect(conta.inicial, 'A');
    });

    test('o apelido passa pelo filtro na criacao', () async {
      final c = await comPrefs();
      final n = c.read(contaDaComunidadeProvider.notifier);
      expect(await n.criar('ab'), isNotNull, reason: 'curto demais');
      expect(await n.criar('vai se foder'), isNotNull, reason: 'ofensa');
      expect(await n.criar('Aurea'), isNotNull, reason: 'passaria por oficial');
      expect(c.read(contaDaComunidadeProvider), isNull);
      expect(await n.criar('Aureliano'), isNull);
    });

    test('sobrevive a fechar o app', () async {
      final c = await comPrefs();
      await c.read(contaDaComunidadeProvider.notifier).criar('Dnyx');
      final gravado = c.read(contaDaComunidadeProvider)!;

      // Outra sessao, mesmas prefs.
      final c2 = await comPrefs({
        'comunidade.conta': jsonEncode(gravado.toJson()),
      });
      final volta = c2.read(contaDaComunidadeProvider)!;
      expect(volta.apelido, 'Dnyx');
      expect(volta.id, gravado.id, reason: 'o id e o mesmo');
    });

    test('trocar o apelido mantem o id', () async {
      final c = await comPrefs();
      final n = c.read(contaDaComunidadeProvider.notifier);
      await n.criar('Primeiro');
      final id = c.read(contaDaComunidadeProvider)!.id;
      expect(await n.atualizar(apelido: 'Segundo'), isNull);
      expect(c.read(contaDaComunidadeProvider)!.apelido, 'Segundo');
      expect(c.read(contaDaComunidadeProvider)!.id, id);
      // E o filtro continua valendo na troca.
      expect(await n.atualizar(apelido: 'suporte'), isNotNull);
      expect(c.read(contaDaComunidadeProvider)!.apelido, 'Segundo');
    });

    test('apagar a conta some com a identidade, nao com os posts', () async {
      final c = await comPrefs();
      await c.read(contaDaComunidadeProvider.notifier).criar('Ana');
      c.read(contaDaComunidadeProvider.notifier).sair();
      expect(c.read(contaDaComunidadeProvider), isNull);
      // O que ela publicou no mural continua sendo dela: o post carrega o
      // apelido de quando foi escrito.
      final post = PostDaComunidade(
        id: 'x',
        autor: 'Ana',
        texto: 'meu primeiro plano',
        quando: DateTime(2026, 9, 7),
      );
      expect(lerFeed(escreverFeed([post])).single.autor, 'Ana');
    });

    test('conta estragada no disco nao derruba a aba', () async {
      final c = await comPrefs({'comunidade.conta': 'isto nao e json'});
      expect(c.read(contaDaComunidadeProvider), isNull);
      final c2 = await comPrefs({'comunidade.conta': '{"apelido":"  "}'});
      expect(c2.read(contaDaComunidadeProvider), isNull);
    });
  });

  group('midia no post', () {
    test('video sobrevive a ida e volta, com duracao', () {
      final p = PostDaComunidade(
        id: 'v',
        autor: 'Ana',
        texto: 'meu render de 12 segundos',
        quando: DateTime.utc(2026, 9, 7),
        imagem: '/tmp/render.mp4',
        imagemLocal: true,
        tipoDeMidia: TipoDeMidia.video,
        duracaoDaMidia: const Duration(seconds: 12),
      );
      final volta = lerFeed(escreverFeed([p])).single;
      expect(volta.tipoDeMidia, TipoDeMidia.video);
      expect(volta.temVideo, isTrue);
      expect(volta.duracaoDaMidia, const Duration(seconds: 12));
    });

    test('feed antigo continua valendo: sem tipo, e imagem', () {
      final p = lerFeed(
        '[{"texto":"antigo","imagem":"https://x/y.png"}]',
      ).single;
      expect(p.tipoDeMidia, TipoDeMidia.imagem);
      expect(p.temVideo, isFalse);
    });
  });

  group('o filtro tambem vale para o que chega', () {
    test('post ofensivo vindo do feed nao aparece', () {
      final posts = lerFeed(jsonEncode({
        'posts': [
          {'id': 'ok', 'autor': 'Ana', 'texto': 'olha meu trabalho novo'},
          {'id': 'ofensa', 'autor': 'X', 'texto': 'vai tomar no cu'},
          {'id': 'autor ruim', 'autor': 'vai se foder', 'texto': 'oi pessoal'},
        ],
      }));
      expect([for (final p in posts) p.id], ['ok']);
    });
  });
}
