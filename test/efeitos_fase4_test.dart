import 'package:aurea/src/features/editor/application/editor_controller.dart';
import 'package:aurea/src/features/editor/application/effect_preset_store.dart';
import 'package:aurea/src/features/editor/application/ui/effect_favorites.dart';
import 'package:aurea/src/features/editor/application/ui/pro_mode.dart';
import 'package:aurea/src/features/editor/domain/effect.dart';
import 'package:aurea/src/features/editor/presentation/context/effects/effect_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'editor_hierarchy_test.dart' show openEditor;

/// FASE 4 DO REDESIGN — EFEITOS E GALERIA (docs/UI_REDESIGN_PLAN.md, 3.4).
///
/// - Os 47 efeitos tem Pronto (3 presets) e Ajustar (ate 3 numeros): a
///   regra 2 da constituicao vale para todos, nao so para seis.
/// - Galeria com miniatura por efeito, busca, categorias, favoritos (Pro)
///   e presets; um toque aplica.
/// - Simples: so Pronto e Ajustar no cartao; Pro acrescenta Avancado,
///   salvar preset e assar em keyframes.
void main() {
  setUpAll(() async {
    EffectThumbnailCache.semDisco = true;
    EffectPresetStore.semArquivo = true;
    for (final family in ['Aurea Motion Sans', 'Roboto']) {
      await (FontLoader(family)..addFont(
            rootBundle.load('assets/templates/dnyx/AureaMotionSans.ttf'),
          ))
          .load();
    }
  });

  test('os 47 efeitos tem as tres profundidades', () {
    expect(effectSpecs.length, 47);
    for (final spec in effectSpecs.values) {
      expect(spec.temProfundidades, isTrue, reason: spec.name);
      expect(spec.presets.length, 3, reason: spec.name);
      expect(spec.montar.length, inInclusiveRange(1, 3), reason: spec.name);
      for (final k in spec.montar) {
        expect(spec.params.containsKey(k), isTrue,
            reason: '${spec.name}: montar cita "$k"');
      }
      for (final p in spec.presets) {
        expect(p.nome, isNotEmpty, reason: spec.name);
        for (final e in p.valores.entries) {
          final param = spec.params[e.key];
          expect(param, isNotNull, reason: '${spec.name}/${p.nome}: "${e.key}"');
          expect(e.value, inInclusiveRange(param!.min, param.max),
              reason: '${spec.name}/${p.nome}: ${e.key}=${e.value} fora de ${param.min}..${param.max}');
        }
      }
    }
  });

  test('favoritos: alterna e lembra em memoria', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(effectFavoritesProvider), isEmpty);
    c.read(effectFavoritesProvider.notifier).toggle('gaussian_blur');
    expect(c.read(effectFavoritesProvider), {'gaussian_blur'});
    c.read(effectFavoritesProvider.notifier).toggle('gaussian_blur');
    expect(c.read(effectFavoritesProvider), isEmpty);
  });

  test('a cartela da miniatura poe o efeito nas duas camadas de cima', () {
    final p = cartelaDoEfeito(EffectType.lightGlow);
    expect(p.layers.length, 3);
    expect(p.layers[0].effects.single.type, EffectType.lightGlow);
    expect(p.layers[1].effects.single.type, EffectType.lightGlow);
    expect(p.layers[2].effects, isEmpty);
    expect(p.aspectRatio, 1);
  });

  testWidgets('galeria: miniaturas, busca, categoria, um toque aplica', (tester) async {
    final c = await openEditor(tester);
    final id = c.read(editorControllerProvider).layers.first.id;
    c.read(selectedLayerProvider.notifier).state = id;
    await tester.pumpAndSettle();
    await tester.tap(find.text('Efeitos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adicionar efeito'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('galeria-grade')), findsOneWidget);
    expect(find.byKey(const ValueKey('galeria-favoritos')), findsNothing, reason: 'favoritos e Pro');
    expect(find.byKey(const ValueKey('efeito-gaussian_blur')), findsOneWidget);
    expect(find.byType(EffectThumbnail), findsWidgets);

    await tester.ensureVisible(find.byKey(const ValueKey('galeria-cat-Glitch')));
    await tester.tap(find.byKey(const ValueKey('galeria-cat-Glitch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('efeito-gaussian_blur')), findsNothing);
    expect(find.byKey(const ValueKey('efeito-glitch')), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('galeria-busca')), 'desfoque');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('efeito-gaussian_blur')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('efeito-gaussian_blur')));
    await tester.pumpAndSettle();
    final camada = c.read(editorControllerProvider).layerById(id)!;
    expect(camada.effects.single.type, EffectType.gaussianBlur);
    expect(camada.effects.single.depth, EffectDepth.pronto, reason: 'nasce no Pronto');
    expect(tester.takeException(), isNull);
  });

  testWidgets('cartao: Simples so Pronto/Ajustar; Pro acrescenta Avancado, preset e assar', (tester) async {
    final c = await openEditor(tester);
    final id = c.read(editorControllerProvider).layers.first.id;
    c.read(editorControllerProvider.notifier).addEffect(id, EffectType.tremor);
    c.read(selectedLayerProvider.notifier).state = id;
    await tester.pumpAndSettle();
    await tester.tap(find.text('Efeitos'));
    await tester.pumpAndSettle();
    expect(find.text('Ajustar'), findsOneWidget);
    expect(find.text('Avancado'), findsNothing, reason: 'Simples nao mostra a ficha inteira');
    expect(find.byKey(const ValueKey('efeito-salvar-preset')), findsNothing);
    expect(find.byKey(const ValueKey('efeito-assar')), findsNothing);

    c.read(proModeProvider.notifier).set(true);
    await tester.pumpAndSettle();
    expect(find.text('Avancado'), findsOneWidget);
    expect(find.byKey(const ValueKey('efeito-salvar-preset')), findsOneWidget);
    expect(find.byKey(const ValueKey('efeito-assar')), findsOneWidget, reason: 'Tremor e procedural');

    // Favoritar na galeria (Pro).
    await tester.tap(find.text('Adicionar efeito'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('galeria-favoritos')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('favorito-gaussian_blur')));
    await tester.pumpAndSettle();
    expect(c.read(effectFavoritesProvider), contains('gaussian_blur'));
    await tester.tap(find.byKey(const ValueKey('galeria-favoritos')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('efeito-gaussian_blur')), findsOneWidget);
    expect(find.byKey(const ValueKey('efeito-glitch')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
