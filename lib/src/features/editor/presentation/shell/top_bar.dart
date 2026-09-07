import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../../application/editor_controller.dart';
import '../../application/ui/pro_mode.dart';
import '../am/export_sheet.dart';
import 'layer_actions.dart';
import 'project_settings_sheet.dart';

/// ZONA A — A BARRA DE CIMA, com UM estado so.
///
/// `‹ Voltar` · nome do projeto (toque = renomear) · desfazer · refazer ·
/// projeto (⚙) · Exportar · Simples/Pro. Nada aqui muda com a selecao
/// nem com o painel aberto: o que muda de conteudo e a zona E. Exportar
/// e a acao de destaque e esta SEMPRE visivel (principio 10).
class EditorTopBar extends ConsumerWidget {
  const EditorTopBar({
    super.key,
    required this.onBack,
    required this.backLabel,
  });

  final VoidCallback onBack;

  /// "Projetos" no nivel raiz; "Voltar" quando ha algo aberto.
  final String backLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AureaTokens.of(context);
    final controller = ref.read(editorControllerProvider.notifier);
    final nome = ref.watch(editorControllerProvider.select((p) => p.name));
    // Observa o projeto so para o estado de desfazer/refazer.
    ref.watch(editorControllerProvider.select((p) => p.hashCode));
    final pro = ref.watch(proModeProvider);

    Widget icone({
      required Key key,
      required IconData icon,
      required String tooltip,
      required VoidCallback? onTap,
    }) => Tooltip(
      message: tooltip,
      child: CupertinoButton(
        key: key,
        padding: EdgeInsets.zero,
        minimumSize: const Size(40, AureaTokens.minTap),
        onPressed: onTap,
        child: Icon(
          icon,
          size: 21,
          color: onTap == null ? t.muted.withValues(alpha: .5) : t.text,
        ),
      ),
    );

    return Container(
      height: AureaTokens.topBar,
      color: t.surface,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // TELA ESTREITA: os rotulos de Voltar e Exportar viram so o
          // icone (com tooltip); a posicao de cada botao nao muda.
          final compacto = constraints.maxWidth < 440;
          return Row(
        children: [
          CupertinoButton(
            key: const ValueKey('editor-back'),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(AureaTokens.minTap, AureaTokens.minTap),
            onPressed: onBack,
            child: Tooltip(
              message: backLabel == 'Projetos' ? 'Voltar aos projetos' : 'Voltar um nível',
              child: Icon(CupertinoIcons.chevron_back, size: 24, color: t.text),
            ),
          ),
          Expanded(
            child: GestureDetector(
              key: const ValueKey('editor-project-name'),
              behavior: HitTestBehavior.opaque,
              onTap: () => renomearProjeto(context, ref),
              child: Center(
                child: Text(
                  nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: t.text,
                  ),
                ),
              ),
            ),
          ),
          icone(
            key: const ValueKey('editor-undo'),
            icon: CupertinoIcons.arrow_uturn_left,
            tooltip: 'Desfazer',
            onTap: controller.canUndo ? controller.undo : null,
          ),
          icone(
            key: const ValueKey('editor-redo'),
            icon: CupertinoIcons.arrow_uturn_right,
            tooltip: 'Refazer',
            onTap: controller.canRedo ? controller.redo : null,
          ),
          icone(
            key: const ValueKey('editor-settings'),
            icon: CupertinoIcons.gear,
            tooltip: 'Projeto',
            onTap: () => showProjectSettingsSheet(context, ref),
          ),
          // SIMPLES | PRO: o chip mostra o modo e troca com um toque.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: GestureDetector(
              key: const ValueKey('editor-pro'),
              behavior: HitTestBehavior.opaque,
              onTap: () => ref.read(proModeProvider.notifier).toggle(),
              // O alvo tem 44 pt de altura (regra 6); o chip desenhado, 30.
              child: SizedBox(
                height: AureaTokens.minTap,
                child: Center(
                  child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: pro ? t.selection.withValues(alpha: .25) : t.chip,
                  borderRadius: BorderRadius.circular(AureaTokens.radiusChip),
                ),
                child: Text(
                  pro ? 'Pro' : (compacto ? 'Simp.' : 'Simples'),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: pro ? t.text : t.muted,
                  ),
                ),
              ),
                ),
              ),
            ),
          ),
          // EXPORTAR: a pilula de acao, sempre no mesmo lugar.
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 6),
            child: GestureDetector(
              key: const ValueKey('editor-export'),
              behavior: HitTestBehavior.opaque,
              onTap: () => showExportSheet(context, ref),
              child: SizedBox(
                height: AureaTokens.minTap,
                child: Center(
                  child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.accent,
                  borderRadius: BorderRadius.circular(AureaTokens.radius),
                ),
                child: Tooltip(
                  message: 'Exportar',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.square_arrow_up,
                        size: 16,
                        color: t.onAccent,
                      ),
                      if (!compacto) ...[
                        const SizedBox(width: 5),
                        Text(
                          'Exportar',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: t.onAccent,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
                ),
              ),
            ),
          ),
        ],
      );
        },
      ),
    );
  }
}
