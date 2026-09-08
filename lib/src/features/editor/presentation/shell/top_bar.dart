import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../../application/editor_controller.dart';
import '../am/export_sheet.dart';
import 'layer_actions.dart';
import 'project_settings_sheet.dart';

/// Cabeçalho da referência: voltar, nome e ações do contexto.
class EditorTopBar extends ConsumerWidget {
  const EditorTopBar({
    super.key,
    required this.onBack,
    required this.backLabel,
    this.title,
  });
  final VoidCallback onBack;
  final String backLabel;
  final String? title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AureaTokens.of(context);
    final project = ref.watch(editorControllerProvider);
    final selected = ref.watch(selectedLayerProvider);
    final layer = selected == null ? null : project.layerById(selected);
    Widget button(
      String key,
      IconData icon,
      String label,
      VoidCallback onTap,
    ) => IconButton(
      key: ValueKey(key),
      tooltip: label,
      onPressed: onTap,
      icon: Icon(icon, size: 22, color: t.text),
    );
    return Container(
      height: AureaTokens.topBar,
      color: t.surface,
      child: Row(
        children: [
          button('editor-back', CupertinoIcons.chevron_back, backLabel, onBack),
          Expanded(
            child: GestureDetector(
              key: const ValueKey('editor-project-name'),
              behavior: HitTestBehavior.opaque,
              onTap: () => layer == null
                  ? renomearProjeto(context, ref)
                  : renomearCamada(context, ref, layer),
              child: Text(
                title ?? layer?.name ?? project.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: t.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          if (layer == null) ...[
            button(
              'editor-settings',
              CupertinoIcons.gear,
              'Projeto',
              () => showProjectSettingsSheet(context, ref),
            ),
            button(
              'editor-export',
              CupertinoIcons.square_arrow_up,
              'Exportar',
              () => showExportSheet(context, ref),
            ),
          ] else ...[
            button(
              'camada-excluir',
              CupertinoIcons.trash,
              'Excluir camada',
              () => excluirCamadas(context, ref, {layer.id}),
            ),
            button(
              'editor-settings',
              CupertinoIcons.gear,
              'Projeto',
              () => showProjectSettingsSheet(context, ref),
            ),
          ],
        ],
      ),
    );
  }
}
