import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'laboratory_session_controller.dart';

/// Registra automaticamente os toques feitos na area testada.
///
/// Deve envolver somente a area do editor, sem a faixa de decisao, para os
/// botoes Passou/Falhou/Pular nao entrarem na contagem do passo.
class LaboratoryTouchCounter extends ConsumerWidget {
  const LaboratoryTouchCounter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(
      laboratorySessionControllerProvider.select((value) => value.isRunning),
    );
    if (!active) return child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => ref
          .read(laboratorySessionControllerProvider.notifier)
          .recordTouch(),
      child: child,
    );
  }
}
