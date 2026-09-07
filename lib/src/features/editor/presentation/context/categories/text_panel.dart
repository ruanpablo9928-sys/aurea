import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/tokens.dart';
import '../../../application/editor_controller.dart';
import '../../../application/playback_controller.dart';
import '../../../domain/layer.dart';
import '../../am/am_colors.dart';
import '../../am/color_picker_sheet.dart';
import '../../am/font_sheet.dart';
import '../parameter_row.dart';

/// E3 · EDITAR TEXTO (Fase 3): conteudo, fonte, tamanho, negrito, cor e
/// a porta para as animacoes. Tudo em `ParameterRow`, sem folha modal.
class TextPanel extends ConsumerWidget {
  const TextPanel({
    super.key,
    required this.playback,
    required this.onAnimar,
  });

  final PlaybackController playback;
  final VoidCallback onAnimar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AureaTokens.of(context);
    final project = ref.watch(editorControllerProvider);
    final id = ref.watch(selectedLayerProvider);
    final layer = id == null ? null : project.layerById(id);
    if (layer is! TextLayer || id == null) {
      return const ColoredBox(color: AmColors.panel);
    }
    final controller = ref.read(editorControllerProvider.notifier);

    return ColoredBox(
      color: AmColors.panel,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(6, 6, 10, 10),
        children: [
          _CampoDeTexto(
            key: ValueKey('texto-conteudo-$id'),
            texto: layer.text,
            onChanged: (v) => controller.editTextLayer(id, text: v),
          ),
          const SizedBox(height: 6),
          ParameterCustomRow(
            label: 'Fonte',
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                key: const ValueKey('texto-fonte'),
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  playback.pause();
                  showFontSheet(context, ref, id);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: t.chip,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Abc',
                        style: TextStyle(
                          fontFamily: layer.fontFamily,
                          fontSize: 14,
                          fontWeight: layer.bold
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: t.text,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        layer.fontFamily ?? 'Padrão',
                        style: TextStyle(fontSize: 12.5, color: t.muted),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 13,
                        color: t.muted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ParameterRow(
            label: 'Tamanho',
            value: layer.fontSize,
            min: 6,
            max: 400,
            unitsPerPixel: 0.5,
            decimals: 0,
            unit: ' pt',
            valueKey: const ValueKey('texto-tamanho'),
            onReset: () => controller.editTextLayer(id, fontSize: 72),
            onChanged: (v) => controller.editTextLayer(id, fontSize: v),
          ),
          ParameterToggleRow(
            label: 'Negrito',
            value: layer.bold,
            valueKey: const ValueKey('texto-negrito'),
            onChanged: (v) => controller.editTextLayer(id, bold: v),
          ),
          ParameterColorRow(
            label: 'Cor',
            color: layer.color,
            valueKey: const ValueKey('texto-cor'),
            onTap: () async {
              playback.pause();
              final picked = await showColorPicker(
                context,
                initial: layer.color,
                onChanged: (c) => controller.editTextLayer(id, color: c),
              );
              if (picked != null) controller.editTextLayer(id, color: picked);
            },
          ),
          ParameterCustomRow(
            label: 'Animação',
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                key: const ValueKey('texto-animar'),
                behavior: HitTestBehavior.opaque,
                onTap: onAnimar,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AmColors.action,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        CupertinoIcons.sparkles,
                        size: 14,
                        color: AmColors.onAction,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Animar texto',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AmColors.onAction,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// O CONTEUDO: campo que escreve na camada a cada letra e acompanha o
/// desfazer (o texto de fora muda, o campo segue).
class _CampoDeTexto extends StatefulWidget {
  const _CampoDeTexto({super.key, required this.texto, required this.onChanged});

  final String texto;
  final ValueChanged<String> onChanged;

  @override
  State<_CampoDeTexto> createState() => _CampoDeTextoState();
}

class _CampoDeTextoState extends State<_CampoDeTexto> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.texto,
  );

  @override
  void didUpdateWidget(_CampoDeTexto old) {
    super.didUpdateWidget(old);
    if (widget.texto != old.texto && widget.texto != _ctrl.text) {
      _ctrl.value = TextEditingValue(
        text: widget.texto,
        selection: TextSelection.collapsed(offset: widget.texto.length),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AureaTokens.of(context);
    return CupertinoTextField(
      key: const ValueKey('texto-conteudo'),
      controller: _ctrl,
      maxLines: 3,
      minLines: 1,
      style: TextStyle(fontSize: 15, color: t.text),
      placeholder: 'Escreva o texto',
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.chip,
        borderRadius: BorderRadius.circular(10),
      ),
      onChanged: widget.onChanged,
    );
  }
}
