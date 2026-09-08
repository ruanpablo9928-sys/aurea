import 'package:aurea/src/features/tutoriais/domain/tutorial.dart';
import 'package:aurea/src/features/tutoriais/presentation/tutorial_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// O TUTORIAL EM VIDEO, dentro do app.
///
/// O que se prova sem player: o JSON gravado vira passos com tempos
/// crescentes; a tela lista os passos, marca o atual e, quando o video
/// nao abre (aqui nao ha plugin), diz isso e continua util.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('o JSON vira cenas em ordem, e cenaEm acha a certa', () {
    final t = Tutorial.deJson('x', {
      'titulo': 'Cena 3D',
      'duracao': 10,
      'largura': 780,
      'altura': 1908,
      'cenas': [
        {'n': 1, 'texto': 'Um', 'inicio': 0, 'fim': 3},
        {'n': 2, 'texto': 'Dois', 'inicio': 3, 'fim': 7.5},
        {'n': 3, 'texto': 'Três', 'inicio': 7.5, 'fim': 10},
        {'n': 4, 'texto': '   ', 'inicio': 9, 'fim': 10},
      ],
    });
    expect(t.cenas.map((c) => c.n), [1, 2, 3], reason: 'vazia nao entra');
    expect(t.cenaEm(0)!.n, 1);
    expect(t.cenaEm(2.99)!.n, 1);
    expect(t.cenaEm(3)!.n, 2);
    expect(t.cenaEm(9.9)!.n, 3);
    expect(t.video, 'assets/tutoriais/x.mp4');
  });

  for (final id in ['cena3d', 'cena-completa', 'texto-bounce']) {
    test('o tutorial $id esta no pacote e faz sentido', () async {
      final t = await Tutorial.carregar(id);
      expect(t.cenas.length, greaterThanOrEqualTo(10));
      expect(t.duracao, greaterThan(30));
      var anterior = -1.0;
      for (final c in t.cenas) {
        expect(c.inicio, greaterThanOrEqualTo(anterior));
        expect(c.fim, greaterThan(c.inicio));
        anterior = c.inicio;
      }
      expect(t.cenas.first.texto, contains('projeto'));
      // O video e o poster existem como assets.
      final video = await rootBundle.load(t.video);
      expect(video.lengthInBytes, greaterThan(100 * 1024));
      final poster = await rootBundle.load(t.poster);
      expect(poster.lengthInBytes, greaterThan(5 * 1024));
    });
  }

  test('o tutorial do texto ensina o que promete', () async {
    final t = await Tutorial.carregar('texto-bounce');
    final tudo = t.cenas.map((c) => c.texto).join(' ');
    expect(tudo, contains('Quicar por letra'), reason: 'o preset de bounce');
    expect(tudo, contains('Amplitude'), reason: 'o tamanho do quique');
    expect(tudo, contains('Frequência'), reason: 'quantas vezes quica');
    expect(tudo, contains('Decaimento'), reason: 'como o quique morre');
    expect(tudo, contains('Atraso'), reason: 'a onda entre as letras');
  });

  test('o tutorial dos modelos ensina o que promete', () async {
    final t = await Tutorial.carregar('cena-completa');
    final tudo = t.cenas.map((c) => c.texto).join(' ');
    expect(tudo, contains('GLB'), reason: 'importar modelo');
    expect(tudo, contains('keyframe'), reason: 'animacao');
    expect(tudo, contains('Nova câmera'), reason: 'segunda camera');
    expect(tudo, contains('corte'), reason: 'troca de camera no tempo');
    expect(tudo, contains('Olhar para'), reason: 'a camera segue o objeto');
  });

  testWidgets('sem player, a tela mostra os passos e diz que o video nao abriu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: TutorialScreen(
          id: 'teste',
          carregar: (_) async => Tutorial.deJson('teste', {
            'titulo': 'Cena 3D',
            'duracao': 90,
            'largura': 780,
            'altura': 1908,
            'cenas': [
              {'n': 1, 'texto': 'Na Início, toque em Novo projeto.', 'inicio': 0, 'fim': 4},
              {'n': 2, 'texto': 'Escolha o formato.', 'inicio': 4, 'fim': 9},
              {'n': 3, 'texto': 'Toque em + e escolha Objeto → Cubo.', 'inicio': 9, 'fim': 20},
            ],
          }),
        ),
      ),
    );
    // Carrega o JSON e tenta o player (que nao existe no teste).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tutorial · Cena 3D'), findsOneWidget);
    expect(find.byKey(const ValueKey('tutorial-cena-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('tutorial-cena-3')), findsOneWidget);
    expect(find.byKey(const ValueKey('tutorial-erro')), findsOneWidget);
    expect(find.text('1:30'), findsOneWidget);

    // Tocar num passo marca-o como atual, mesmo sem video.
    await tester.tap(find.byKey(const ValueKey('tutorial-cena-3')));
    await tester.pump();
    final numero = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('tutorial-cena-3')),
        matching: find.text('3'),
      ),
    );
    expect(numero.style?.color, const Color(0xFF0B0E12), reason: 'aceso');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
