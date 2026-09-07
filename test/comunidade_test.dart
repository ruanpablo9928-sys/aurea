import 'dart:convert';

import 'package:aurea/src/features/community/domain/post_da_comunidade.dart';
import 'package:flutter_test/flutter_test.dart';

/// A COMUNIDADE: o que precisa aguentar sem quebrar.
///
/// Desde que o mural virou publico, LER TAMBEM FILTRA: um texto que nao
/// passaria na publicacao tambem nao aparece quando chega de fora. Por
/// isso os textos daqui sao frases de verdade, e nao "a", "b", "c" — o
/// filtro recusaria os tres por serem curtos demais.
///
/// O feed vem de fora, escrito a mao por quem publica. Um arquivo assim
/// SEMPRE tem um item errado um dia — data em outro formato, campo que
/// falta, alguem que colou uma virgula a mais. O que nao pode acontecer e
/// a aba inteira ficar em branco por causa de um post.
void main() {
  group('ler o feed', () {
    test('le a lista dentro de posts e a lista direta', () {
      const dentro = '{"posts":[{"id":"1","autor":"Ana","texto":"post de teste",'
          '"quando":"2026-09-01T10:00:00Z"}]}';
      const direta = '[{"id":"1","autor":"Ana","texto":"post de teste",'
          '"quando":"2026-09-01T10:00:00Z"}]';
      for (final fonte in [dentro, direta]) {
        final posts = lerFeed(fonte);
        expect(posts.length, 1);
        expect(posts.single.autor, 'Ana');
        expect(posts.single.texto, 'post de teste');
      }
    });

    test('o mais novo vem primeiro', () {
      final posts = lerFeed(
        jsonEncode({
          'posts': [
            {'id': 'velho', 'texto': 'o mais antigo do mural', 'quando': '2026-01-01T00:00:00Z'},
            {'id': 'novo', 'texto': 'o mais recente do mural', 'quando': '2026-09-01T00:00:00Z'},
            {'id': 'meio', 'texto': 'o do meio do mural', 'quando': '2026-05-01T00:00:00Z'},
          ],
        }),
      );
      expect([for (final p in posts) p.id], ['novo', 'meio', 'velho']);
    });

    test('um item estragado nao derruba os outros', () {
      final posts = lerFeed(
        jsonEncode({
          'posts': [
            {'id': 'bom', 'texto': 'vale', 'quando': '2026-09-01T00:00:00Z'},
            {'id': 'sem texto', 'quando': '2026-09-01T00:00:00Z'},
            {'id': 'texto vazio', 'texto': '   '},
            'isto nem e um objeto',
            {'id': 'data ruim', 'texto': 'ainda vale', 'quando': 'ontem'},
          ],
        }),
      );
      expect([for (final p in posts) p.id], contains('bom'));
      expect([for (final p in posts) p.id], contains('data ruim'));
      expect(posts.length, 2);
    });

    test('json invalido devolve lista vazia em vez de estourar', () {
      expect(lerFeed('nao e json'), isEmpty);
      expect(lerFeed(''), isEmpty);
      expect(lerFeed('{"posts": "isto devia ser lista"}'), isEmpty);
    });

    test('o que falta ganha um padrao, sem campo obrigatorio alem do texto', () {
      final p = lerFeed('[{"texto":"so isso"}]').single;
      expect(p.autor, 'Anônimo');
      expect(p.texto, 'so isso');
      expect(p.id, isNotEmpty);
      expect(p.etiquetas, isEmpty);
      expect(p.estado, EstadoDoPost.publicado);
    });
  });

  group('o post', () {
    test('ida e volta pelo json', () {
      final p = PostDaComunidade(
        id: 'x',
        autor: 'Ana',
        texto: 'linha 1\nlinha 2',
        quando: DateTime.utc(2026, 9, 7, 12, 30),
        imagem: '/tmp/foto.png',
        imagemLocal: true,
        link: 'https://exemplo.com',
        etiquetas: const ['3d', 'motion'],
        estado: EstadoDoPost.rascunho,
      );
      final volta = lerFeed(escreverFeed([p])).single;
      expect(volta.id, p.id);
      expect(volta.autor, p.autor);
      expect(volta.texto, p.texto);
      expect(volta.quando.toUtc(), p.quando.toUtc());
      expect(volta.imagem, p.imagem);
      expect(volta.imagemLocal, isTrue);
      expect(volta.link, p.link);
      expect(volta.etiquetas, p.etiquetas);
      expect(volta.estado, EstadoDoPost.rascunho);
      expect(volta.meu, isTrue);
    });

    test('o tempo em palavras', () {
      final agora = DateTime(2026, 9, 7, 12, 0);
      PostDaComunidade quando(Duration atras) => PostDaComunidade(
        id: 'x',
        autor: 'a',
        texto: 't',
        quando: agora.subtract(atras),
      );
      expect(quando(const Duration(seconds: 20)).quandoEmPalavras(agora), 'agora');
      expect(quando(const Duration(minutes: 5)).quandoEmPalavras(agora), 'há 5 min');
      expect(quando(const Duration(hours: 3)).quandoEmPalavras(agora), 'há 3 h');
      expect(quando(const Duration(days: 2)).quandoEmPalavras(agora), 'há 2 d');
      // Acima de uma semana vira data: "há 43 d" nao ajuda ninguem.
      expect(
        quando(const Duration(days: 40)).quandoEmPalavras(agora),
        '29/07/2026',
      );
    });

    test('so o publicado nao e meu', () {
      PostDaComunidade com(EstadoDoPost e) => PostDaComunidade(
        id: 'x',
        autor: 'a',
        texto: 't',
        quando: DateTime(2026),
        estado: e,
      );
      expect(com(EstadoDoPost.publicado).meu, isFalse);
      expect(com(EstadoDoPost.rascunho).meu, isTrue);
      expect(com(EstadoDoPost.enviado).meu, isTrue);
    });
  });
}
