import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/prefs.dart';
import '../am/am_colors.dart';

/// AS QUATRO DICAS DE PRIMEIRO USO (Fase 6): o que o editor precisa que a
/// pessoa saiba, e nada mais. Aparecem uma vez, no alto do preview, e
/// voltam por ⚙ Projeto › "Ver as dicas de novo".
const dicasDoEditor = [
  'Toque no + (na barra de transporte) para adicionar mídia, texto ou forma.',
  'Toque numa camada na timeline: as ações e as categorias dela aparecem embaixo.',
  'Toque no número de um parâmetro para digitar o valor exato; arraste a régua para ajustar.',
  'O ◆ na barra de transporte crava um keyframe no instante do cabeçote.',
];

/// Lembrado por aparelho.
class OnboardingPrefs {
  static const kVistas = 'editor.dicasVistas';

  static bool vistas(WidgetRef ref) {
    try {
      return ref.read(sharedPreferencesProvider).getBool(kVistas) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> marcar(WidgetRef ref, bool vistas) async {
    try {
      await ref.read(sharedPreferencesProvider).setBool(kVistas, vistas);
    } catch (_) {}
  }
}

/// O cartao de dicas: uma por vez, Proxima e Entendi.
class OnboardingCoach extends StatefulWidget {
  const OnboardingCoach({super.key, required this.onFechar});

  final VoidCallback onFechar;

  @override
  State<OnboardingCoach> createState() => _OnboardingCoachState();
}

class _OnboardingCoachState extends State<OnboardingCoach> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final ultima = _i == dicasDoEditor.length - 1;
    return Container(
      key: const ValueKey('editor-dica'),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
      decoration: BoxDecoration(
        color: AmColors.panel.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AmColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            dicasDoEditor[_i],
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: AmColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${_i + 1}/${dicasDoEditor.length}',
                style: const TextStyle(fontSize: 11, color: AmColors.muted),
              ),
              const Spacer(),
              if (!ultima)
                CupertinoButton(
                  key: const ValueKey('editor-dica-proxima'),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: const Size(0, 30),
                  onPressed: () => setState(() => _i++),
                  child: const Text(
                    'Próxima',
                    style: TextStyle(fontSize: 13, color: AmColors.text),
                  ),
                ),
              CupertinoButton(
                key: const ValueKey('editor-dica-entendi'),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 30),
                onPressed: widget.onFechar,
                child: const Text(
                  'Entendi',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AmColors.action,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
