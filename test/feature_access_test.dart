import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aurea/src/core/app_mode.dart';
import 'package:aurea/src/core/feature_access.dart';
import 'package:aurea/src/core/storage/prefs.dart';
import 'package:aurea/src/features/laboratory/application/laboratory_controller.dart';
import 'package:aurea/src/features/editor/presentation/widgets/add_layer_sheet.dart';

void main() {
  Future<ProviderContainer> containerWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('nucleo revela somente os niveis ligados no laboratorio', () async {
    final container = await containerWith({});

    expect(container.read(appModeProvider), AppMode.core);
    expect(
      container.read(featureAccessProvider(LaboratoryLevelId.shapes)),
      isFalse,
    );

    container
        .read(laboratoryControllerProvider.notifier)
        .setEnabled(LaboratoryLevelId.shapes, true);

    expect(
      container.read(featureAccessProvider(LaboratoryLevelId.shapes)),
      isTrue,
    );
    expect(
      container.read(featureAccessProvider(LaboratoryLevelId.effects)),
      isFalse,
    );
  });

  test('estudio completo continua liberando todos os niveis', () async {
    final container = await containerWith({'app.mode': 'full'});

    for (final level in LaboratoryLevelId.values) {
      expect(
        container.read(featureAccessProvider(level)),
        isTrue,
        reason: level.name,
      );
    }
  });

  testWidgets('ligar Shapes revela a UI do nivel sem ligar o estudio', (
    tester,
  ) async {
    final container = await containerWith({});
    container
        .read(laboratoryControllerProvider.notifier)
        .setEnabled(LaboratoryLevelId.shapes, true);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showAddLayerSheet(context, ref, Duration.zero),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Forma'), findsOneWidget);
    expect(find.text('Midia'), findsOneWidget);
    expect(find.text('Audio'), findsOneWidget);
    expect(find.text('Objeto'), findsNothing);
    expect(find.text('Modelo'), findsNothing);
    expect(find.text('Texto'), findsNothing);
  });

  testWidgets('tipos habilitados aparecem sem vazar recursos de outros niveis', (
    tester,
  ) async {
    final container = await containerWith({});
    final laboratory = container.read(laboratoryControllerProvider.notifier);
    laboratory.setEnabled(LaboratoryLevelId.text, true);
    laboratory.setEnabled(LaboratoryLevelId.captions, true);
    // Nulo liga Cena 3D automaticamente, conforme a dependencia do nivel 9.
    laboratory.setEnabled(LaboratoryLevelId.nullAndClone, true);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showAddLayerSheet(
                  context,
                  ref,
                  Duration.zero,
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    expect(find.text('Texto'), findsOneWidget);
    expect(find.text('Forma'), findsNothing);
    expect(find.text('Modelo'), findsNothing);
    expect(find.text('Legendas'), findsOneWidget);

    await tester.tap(find.text('Objeto'));
    await tester.pumpAndSettle();
    expect(find.text('Nulo 3D'), findsOneWidget);
    expect(find.text('Elementos 3D'), findsOneWidget);
    expect(find.text('Cena 3D'), findsOneWidget);
    expect(find.text('Particulas'), findsNothing);
    expect(find.text('Ajuste'), findsNothing);
  });
}
