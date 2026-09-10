// O EDITOR GRAVA O QUE FOI EDITADO.
//
// Parece obvio demais para ter teste, e e justamente por isso que
// ficou sem: a ponte que levava cada mutacao do editor para a lista de
// projetos — e dali, com atraso, para o disco — morava na tela de
// edicao ANTIGA. Ela foi apagada com o resto daquela UI, e a tela nova
// nunca a refez.
//
// O resultado nao dava sinal nenhum: nao ha botao de salvar para
// alguem ter esquecido de apertar, porque este app sempre salvou
// sozinho. Dava para montar uma composicao inteira, sair e voltar ao
// projeto exatamente como estava antes de comecar.
import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/domain/video_project.dart';
import 'package:aurea/src/features/editor/presentation/editor_screen.dart';
import 'package:aurea/src/features/projects/application/project_repository.dart';
import 'package:aurea/src/features/projects/application/projects_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'apoio/repositorio_sem_disco.dart';

Future<ProviderContainer> _montar(
  WidgetTester tester,
  RepositorioSemDisco repo,
  VideoProject projeto,
) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      projectRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  container.read(editorControllerProvider.notifier).openProject(projeto);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: EditorScreen()),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  testWidgets('uma camada nova chega na lista de projetos', (tester) async {
    final projeto = VideoProject.empty('Teste');
    final repo = RepositorioSemDisco();
    final container = await _montar(tester, repo, projeto);

    expect(
      container.read(projectsControllerProvider).where((p) => p.id == projeto.id),
      isEmpty,
      reason: 'nada mudou ainda; nao ha o que gravar',
    );

    container
        .read(editorControllerProvider.notifier)
        .addTextLayer(Duration.zero, text: 'Um');
    await tester.pump();

    final salvo = container
        .read(projectsControllerProvider)
        .firstWhere((p) => p.id == projeto.id);
    expect(
      salvo.layers,
      hasLength(1),
      reason: 'a edicao nao chegou na lista que grava em disco',
    );

    // O SALVAMENTO E ADIADO em 900 ms de proposito: arrastar um numero
    // manda dezenas de mutacoes por segundo, e gravar cada uma seria
    // escrever o projeto inteiro dezenas de vezes por segundo.
    await tester.pump(const Duration(seconds: 1));
    expect(repo.gravados.last.layers, hasLength(1));
  });

  testWidgets('dentro de um grupo, grava o PROJETO e nao os filhos', (
    tester,
  ) async {
    final projeto = VideoProject.empty('Teste');
    final container = await _montar(tester, RepositorioSemDisco(), projeto);
    final c = container.read(editorControllerProvider.notifier);

    c.addTextLayer(Duration.zero, text: 'Um');
    await tester.pump();
    final id = container.read(editorControllerProvider).layers.single.id;
    c.groupLayer(id);
    await tester.pump();

    final grupo = container.read(editorControllerProvider).layers.single.id;
    c.enterGroup(grupo);
    await tester.pump();
    // Dentro do grupo o estado E o grupo: `state.layers` sao os filhos.
    expect(container.read(editorControllerProvider).layers, hasLength(1));

    c.addTextLayer(Duration.zero, text: 'Dois');
    await tester.pump();

    final salvo = container
        .read(projectsControllerProvider)
        .firstWhere((p) => p.id == projeto.id);
    expect(
      salvo.layers,
      hasLength(1),
      reason: 'gravar `state` de dentro do grupo trocaria o projeto pelos '
          'filhos dele — o resto da composicao sumiria do arquivo',
    );
    expect(salvo.layers.single.id, grupo);
    await tester.pump(const Duration(seconds: 1));
  });
}
