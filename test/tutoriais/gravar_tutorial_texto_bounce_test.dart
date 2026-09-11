// O GRAVADOR DO TUTORIAL "TEXTO QUE QUICA".
//
// O terceiro tutorial: uma animacao de texto bounce feita a mao. Nao e
// so escolher o preset — e entender as tres coisas que fazem o quique
// ser SEU: a mola (amplitude, frequencia, decaimento), a unidade (letra
// ou palavra, com o atraso entre elas) e a distancia de onde a letra
// vem. No fim, o mesmo texto com duas caras diferentes.
//
// Como os outros: gravacao de tela feita pelo proprio app, quadro a
// quadro (ver test/tutoriais/gravador.dart e docs/tutorial-em-video.md).
//
// Rodar (so quando se quer regravar; a suite normal pula):
//   AUREA_GRAVAR_TUTORIAL=1 flutter test test/tutoriais/gravar_tutorial_texto_bounce_test.dart
// Depois:  python test/tutoriais/montar_tutorial.py texto-bounce
import 'dart:io';

import 'package:aurea/src/core/storage/prefs.dart';
import 'package:aurea/src/core/theme/app_theme.dart';
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/font_service.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/text_anim.dart';
import 'package:aurea/src/features/editor/domain/text_animator.dart';
import 'package:aurea/src/features/editor/presentation/am/am_widgets.dart';
import 'package:aurea/src/features/projects/application/projects_controller.dart';
import 'package:aurea/src/features/projects/presentation/home_shell.dart';
import 'package:aurea/src/features/projects/presentation/release_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'gravador.dart';

const _saida = 'build/tutorial/texto-bounce';

void main() {
  final gravar = Platform.environment['AUREA_GRAVAR_TUTORIAL'] == '1';

  testWidgets('grava o tutorial do texto que quica', (tester) async {
    if (!gravar) return;

    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await carregarFontes();

    SharedPreferences.setMockInitialValues({
      releaseNoticeSeenKey: releaseNoticeRevision,
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        projectsControllerProvider.overrideWith(ProjetosNaMemoria.new),
        projectRepositoryProvider.overrideWithValue(RepositorioNulo()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(
          key: chaveDaGravacao,
          child: MaterialApp(
            theme: AppTheme.dark,
            debugShowCheckedModeBanner: false,
            home: const HomeShell(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // A FONTE DO PALCO. O texto da camada nasce sem familia escolhida e
    // cai no padrao do aparelho; no teste esse padrao desenha um
    // quadradinho por letra — e o video ficaria mostrando uma barra
    // branca no lugar da palavra. Registrando a fonte do app no servico
    // de fontes, a camada pode usa-la e o palco desenha letras.
    FontService.instance.registrarSemArquivo('Aurea Motion Sans');

    final g = Gravador(tester, saida: _saida);
    await g.preparar();
    TextLayer texto() => container
        .read(editorControllerProvider)
        .layers
        .whereType<TextLayer>()
        .single;
    TextAnim entrada() => texto().anims.firstWhere(
      (a) => a.slot == TextAnimSlot.entrada,
    );

    /// A REGUA de um parametro, achada pelo rotulo da linha.
    ///
    /// A linha MAIS PROXIMA do rotulo, e nao a de fora: o painel inteiro
    /// e uma pilha de linhas, e a de fora traria a regua da vizinha —
    /// foi assim que o primeiro arrasto mexeu em tudo menos na
    /// amplitude. Aqui a regua e arrastavel (neste painel ela e a
    /// superficie; nas linhas de parametro do editor, quem arrasta e a
    /// linha inteira).
    Finder linhaDe(String rotulo) => find.descendant(
      of: find
          .ancestor(of: find.text(rotulo), matching: find.byType(Row))
          .first,
      matching: find.byType(AmTickRuler),
    );

    // 1. Projeto e texto.
    g.cena('Novo projeto 9:16 — o texto que quica é coisa de Reels.');
    await g.segurar(1.4);
    await g.tocar(find.byKey(const ValueKey('novo-projeto')));
    await g.assentar(quadros: 6);
    await g.tocar(find.byKey(const ValueKey('formato-9:16')));
    await g.assentar(quadros: 4);
    await g.tocar(find.byKey(const ValueKey('criar-projeto')));
    await g.assentar(quadros: 8);

    g.cena('No menu de adicionar, o Texto fica na coluna da direita.');
    await g.segurar(1.0);
    if (find.text('Texto').evaluate().isEmpty) {
      await g.tocar(find.byKey(const ValueKey('estado-vazio-cta')));
      await g.assentar(quadros: 5);
    }
    await g.tocar(find.text('Texto'));
    await g.assentar(quadros: 8);
    expect(
      container.read(editorControllerProvider).layers.whereType<TextLayer>(),
      hasLength(1),
    );
    await g.segurar(.8);

    g.cena('Escreva o seu — aqui, AUREA.');
    await g.segurar(.8);
    if (find.byKey(const ValueKey('texto-conteudo')).evaluate().isEmpty) {
      await g.tocar(find.text('Editar\ntexto'));
      await g.assentar(quadros: 6);
    }
    await tester.enterText(
      find.byKey(const ValueKey('texto-conteudo')),
      'AUREA',
    );
    await g.assentar(quadros: 5);
    if (find.byKey(const ValueKey('texto-fechar-teclado')).evaluate().isNotEmpty) {
      await g.tocar(find.byKey(const ValueKey('texto-fechar-teclado')));
    }
    tester.view.resetViewInsets();
    await g.assentar(quadros: 6);
    expect(texto().text, 'AUREA');
    container
        .read(editorControllerProvider.notifier)
        .editTextLayer(texto().id, fontFamily: 'Aurea Motion Sans');
    await g.assentar(quadros: 4);
    await g.segurar(1.0);

    // 2. A animacao.
    g.cena('Animar texto abre as animações: entrada, ênfase e saída.');
    await g.segurar(1.0);
    await g.rolarAte(find.byKey(const ValueKey('texto-animar')));
    await g.tocar(find.byKey(const ValueKey('texto-animar')));
    await g.assentar(quadros: 8);
    await g.segurar(1.2);

    g.cena('Quicar por letra: cada letra entra de baixo, com mola.');
    await g.segurar(1.0);
    await g.rolarAte(find.text('Quicar por letra'));
    await g.tocar(find.text('Quicar por letra'));
    await g.assentar(quadros: 8);
    expect(entrada().specId, 'bounceLetter');
    expect(entrada().ease, TextAnimEase.mola);
    await g.segurar(1.4);

    // 3. Personalizar a mola.
    g.cena('Daqui para baixo é seu: a mola tem amplitude, frequência e decaimento.');
    await g.segurar(1.2);
    await g.rolarAte(find.text('Amplitude'));
    await g.segurar(.8);

    g.cena('Amplitude é o tamanho do quique — arraste para a esquerda e ele fica maior.');
    await g.segurar(.8);
    final amplitude0 = entrada().amplitude;
    await g.valorDaRegua(linhaDe('Amplitude'), amplitude0, 2.2);
    expect(
      entrada().amplitude,
      isNot(amplitude0),
      reason: 'a regua mexeu na amplitude',
    );
    await g.segurar(1.0);

    g.cena('Frequência é quantas vezes ele quica antes de parar.');
    await g.segurar(.8);
    await g.rolarAte(find.text('Frequencia'));
    final freq0 = entrada().frequency;
    await g.valorDaRegua(linhaDe('Frequencia'), freq0, 4.5);
    expect(entrada().frequency, isNot(freq0));
    await g.segurar(1.0);

    g.cena('Decaimento é a rapidez com que o quique morre. Menos decaimento, mais balanço.');
    await g.segurar(.8);
    await g.rolarAte(find.text('Decaimento'));
    final dec0 = entrada().decay;
    await g.valorDaRegua(linhaDe('Decaimento'), dec0, 3.5, passos: 6);
    expect(entrada().decay, isNot(dec0));
    await g.segurar(1.2);

    // 4. Distancia, duracao e atraso.
    g.cena('Distância é de onde a letra vem: quanto maior, mais longe o salto começa.');
    await g.segurar(.8);
    await g.rolarAte(find.text('Distancia'));
    await g.valorDaRegua(
      linhaDe('Distancia'),
      entrada().params['distancia'] ?? 90,
      260,
      passos: 7,
    );
    await g.segurar(1.0);

    g.cena('Atraso é o intervalo entre uma letra e a outra — é ele que faz a onda.');
    await g.segurar(.8);
    await g.rolarAte(find.text('Atraso'));
    final atraso0 = entrada().stagger;
    await g.valorDaRegua(
      linhaDe('Atraso'),
      atraso0.inMilliseconds.toDouble(),
      110,
      passos: 7,
    );
    expect(entrada().stagger, isNot(atraso0));
    await g.segurar(1.2);

    // 5. Trocar a unidade e a ordem.
    g.cena('A mesma animação por PALAVRA, e não por letra: outro ritmo, um toque.');
    await g.segurar(1.0);
    await g.rolarAte(find.text('Unidade'));
    await g.tocar(find.text('Palavras'));
    await g.assentar(quadros: 6);
    expect(entrada().unit, TextAnimUnit.word);
    await g.segurar(1.2);

    g.cena('E de volta para letra, com a ordem invertida: entra da última para a primeira.');
    await g.segurar(.8);
    await g.tocar(find.text('Letras'));
    await g.assentar(quadros: 5);
    await g.rolarAte(find.text('Ordem'));
    await g.tocar(find.text('Do fim'));
    await g.assentar(quadros: 6);
    expect(entrada().order, TextAnimOrder.reverse);
    await g.segurar(1.2);

    // 6. Ver tocando.
    g.cena('Feche o painel e dê o play: o texto quica do seu jeito.');
    await g.segurar(.8);
    if (find.byKey(const ValueKey('painel-fechar')).evaluate().isNotEmpty) {
      await g.tocar(find.byKey(const ValueKey('painel-fechar')));
      await g.assentar(quadros: 6);
    }
    await g.tocar(find.byKey(const ValueKey('transport-start')));
    await g.assentar(quadros: 3);
    await g.tocar(find.byKey(const ValueKey('transport-play')));
    for (var i = 0; i < 44; i++) {
      await tester.pump(const Duration(milliseconds: 66));
      await g.quadro(dur: .066);
    }
    await g.tocar(find.byKey(const ValueKey('transport-play')));

    g.cena('Guardado no projeto: a animação viaja junto com a camada de texto.');
    await g.segurar(2.5);

    await g.salvar();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }, timeout: const Timeout(Duration(minutes: 20)));
}
