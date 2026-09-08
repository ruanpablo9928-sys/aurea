import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/playback_controller.dart';
import 'package:aurea/src/features/editor/domain/cut_ops.dart';
import 'package:aurea/src/features/editor/domain/keyframe.dart';
import 'package:aurea/src/features/editor/domain/layer.dart';
import 'package:aurea/src/features/editor/domain/video_project.dart';
import 'package:aurea/src/features/editor/presentation/am/speed_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// TIME REMAP DE PONTA A PONTA, pela folha de Velocidade.
///
/// "Faca o TIMEREMAP funcionar agora": o remap nascia com um keyframe em
/// cada ponta e nenhum jeito de por outro no meio — sem rampa possivel,
/// o recurso "nao funcionava". Este teste liga o remap pelo interruptor,
/// crava um keyframe no cabecote, entorta a rampa e segura um quadro, e
/// confere a cada passo QUAL instante da fonte aparece.
void main() {
  testWidgets('ligar, cravar no cabecote, entortar e segurar quadro', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final clipe = VideoLayer(
      name: 'v',
      startTime: Duration.zero,
      duration: const Duration(seconds: 4),
      sourcePath: '/x.mp4',
      position: AnimatedOffset(const Offset(960, 540)),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final editor = container.read(editorControllerProvider.notifier);
    editor.openProject(
      VideoProject(name: 'p', createdAt: DateTime(2026, 9, 8), layers: [clipe]),
    );
    final id = clipe.id;
    VideoLayer video() =>
        container.read(editorControllerProvider).layerById(id)! as VideoLayer;

    final playback = PlaybackController(
      vsync: tester,
      durationOf: () => const Duration(seconds: 4),
    );
    addTearDown(playback.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () =>
                    showSpeedSheet(context, ref, id, playback: playback),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    // 1. Liga o remap pelo interruptor da folha.
    expect(hasTimeRemap(video()), isFalse);
    final interruptor = find.descendant(
      of: find
          .ancestor(
            of: find.text('Rampa / Time Remap'),
            matching: find.byType(Row),
          )
          .first,
      matching: find.byType(CupertinoSwitch),
    );
    await tester.tap(interruptor);
    await tester.pumpAndSettle();
    expect(hasTimeRemap(video()), isTrue, reason: 'o interruptor liga o remap');
    // Nasce reto: no meio do clipe aparece o meio da fonte.
    expect(
      videoSourceTimeAt(video(), const Duration(seconds: 2)),
      const Duration(seconds: 2),
    );

    // 2. Cabecote em 1 s, "Keyframe de tempo aqui": um keyframe em 1 s com
    //    o instante da fonte que JA esta na tela (1 s) — nada muda ainda.
    playback.seek(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('remap-keyframe-aqui')));
    await tester.pumpAndSettle();
    final trilha = timeRemapTrackOf(video())!;
    final emUm = trilha.keyframes.where(
      (k) => k.time == const Duration(seconds: 1),
    );
    expect(emUm, hasLength(1), reason: 'um keyframe no cabecote');
    expect(emUm.single.value, closeTo(1.0, 1e-9));
    expect(
      videoSourceTimeAt(video(), const Duration(milliseconds: 500)),
      const Duration(milliseconds: 500),
    );

    // 3. Entorta: o keyframe de 1 s passa a mostrar o instante 3 s da
    //    fonte. Antes dele o clipe corre a 3x; depois, devagar.
    editor.setClipTimeRemapKeyframe(id, const Duration(seconds: 1), 3.0);
    expect(
      videoSourceTimeAt(video(), const Duration(milliseconds: 500)),
      const Duration(milliseconds: 1500),
    );
    expect(
      videoSourceTimeAt(video(), const Duration(milliseconds: 2500)),
      const Duration(milliseconds: 3500),
    );

    // 4. Cabecote em 2 s, "Segurar quadro por 1 s": dois keyframes iguais,
    //    em 2 s e 3 s — no meio deles o quadro nao anda.
    playback.seek(const Duration(seconds: 2));
    await tester.tap(find.byKey(const ValueKey('remap-segurar')));
    await tester.pumpAndSettle();
    final segurado = videoSourceTimeAt(video(), const Duration(seconds: 2));
    expect(
      videoSourceTimeAt(video(), const Duration(milliseconds: 2500)),
      segurado,
      reason: 'entre os dois keyframes iguais o quadro fica parado',
    );
    expect(
      videoSourceTimeAt(video(), const Duration(seconds: 3)),
      segurado,
    );
    final tempos = timeRemapTrackOf(video())!.keyframes.map((k) => k.time);
    expect(tempos, contains(const Duration(seconds: 2)));
    expect(tempos, contains(const Duration(seconds: 3)));
    // E o fim continua no fim da fonte: a rampa volta a andar depois.
    expect(
      videoSourceTimeAt(video(), const Duration(seconds: 4)),
      const Duration(seconds: 4),
    );
  });
}
