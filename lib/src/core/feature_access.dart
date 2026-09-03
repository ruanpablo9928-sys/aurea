import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/laboratory/application/laboratory_controller.dart';
import '../features/laboratory/domain/laboratory_level.dart';
import 'app_mode.dart';

export '../features/laboratory/domain/laboratory_level.dart'
    show LaboratoryLevelId, LaboratoryLevelIdX;

/// Fonte unica para decidir se a UI de um nivel deve aparecer.
///
/// O modo Estudio continua liberando tudo, enquanto o modo Nucleo passa a
/// responder imediatamente aos interruptores do Laboratorio.
final featureAccessProvider = Provider.family<bool, LaboratoryLevelId>((
  ref,
  level,
) {
  final full = ref.watch(appModeProvider).isFull;
  final enabled = ref.watch(
    laboratoryControllerProvider.select((state) => state.isEnabled(level)),
  );
  return full || enabled;
});
