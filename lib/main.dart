import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app.dart';
import 'src/core/storage/prefs.dart';
import 'src/features/editor/application/font_service.dart';
import 'src/features/editor/presentation/widgets/custom_blend.dart';
import 'src/features/editor/presentation/widgets/linear_light.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // O shader das mesclas proprias sobe uma vez, no comeco: compilar no
  // meio da edicao apareceria como engasgo no primeiro quadro.
  unawaited(CustomBlendBox.warmUp());
  // A curva do sRGB: sem ela, glow e desfoque somam luz no espaco
  // errado e saem acinzentados.
  unawaited(LinearLight.warmUp());
  // As fontes importadas precisam ser registradas de novo a cada
  // abertura: o registro do Flutter vive so enquanto o processo vive.
  await FontService.instance.loadAll();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const AureaApp(),
    ),
  );
}
