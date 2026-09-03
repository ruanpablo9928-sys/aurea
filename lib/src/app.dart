import 'package:flutter/material.dart';

import 'core/navigation.dart';
import 'core/theme/app_theme.dart';
import 'features/laboratory/application/laboratory_app_bridge.dart';
import 'features/laboratory/presentation/laboratory_acceptance_host.dart';
import 'features/laboratory/presentation/laboratory_touch_counter.dart';
import 'features/projects/presentation/home_shell.dart';

class AureaApp extends StatelessWidget {
  const AureaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aurea',
      debugShowCheckedModeBanner: false,
      navigatorKey: aureaNavigatorKey,
      theme: AppTheme.dark,
      home: const HomeShell(),
      // A FAIXA DO PASSO vive acima de qualquer tela: a tarefa de aceite
      // atravessa o app (ajustes -> editor -> exportar) sem se perder, e
      // o contador de toques conta em todo lugar, sem o testador fazer
      // nada. O print sai desta raiz, com a faixa junto.
      builder: (context, child) => RepaintBoundary(
        key: laboratoryCaptureKey,
        child: LaboratoryTouchCounter(
          child: Stack(
            children: [
              if (child != null) Positioned.fill(child: child),
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: SafeArea(bottom: false, child: LaboratoryAcceptanceHost()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
