import 'package:flutter/material.dart';

import '../../../../core/theme/tokens.dart';
import '../../application/ui/editor_layout.dart';

/// ZONA E — A CASCA DO PAINEL CONTEXTUAL.
///
/// Uma superficie so, sempre no mesmo lugar (a base da tela), com uma
/// alca em cima. O CONTEUDO muda com a selecao (E1–E5); a POSICAO nunca.
/// A alca arrasta a altura entre espiada, metade e cheia; o preview nao
/// se mexe — quem cede espaco e a timeline.
class ContextSheet extends StatelessWidget {
  const ContextSheet({
    super.key,
    required this.height,
    required this.child,
    required this.onDrag,
    required this.onDragEnd,
    this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
  });

  /// Altura resolvida pelas metricas (ja inclui a alca).
  final double height;
  final Widget child;

  /// Delta vertical do dedo na alca, em pixels (para cima = negativo).
  final ValueChanged<double> onDrag;
  final VoidCallback onDragEnd;

  /// Cabecalho opcional: `‹ titulo` (categoria aberta) e a trilha.
  final String? title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  /// A FAIXA DO CABECALHO DA FOLHA.
  ///
  /// Eram 18 px, e dentro deles cabia um chevron de 16 com a palavra
  /// "Voltar" em corpo 10 — que e o que o beta chamou de "MUITO
  /// pequena". Um alvo de toque nao existe em 18 px: o dedo cobre a
  /// faixa inteira e ainda pega a alca de arrastar. Em 34 cabe um
  /// simbolo de 26 com folga, e a folha perde 16 px uma vez so.
  static const double handleHeight = 26;

  @override
  Widget build(BuildContext context) {
    final t = AureaTokens.of(context);
    return Container(
      key: const ValueKey('context-sheet'),
      height: height,
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // A ALCA E O CABECALHO SAO UMA LINHA SO (18 px): a alca no
          // meio; a esquerda, o voltar e a trilha "Projeto › Camada ·
          // Categoria" quando ha categoria aberta. Cada pixel aqui e
          // pixel que o painel de transformacao perde.
          GestureDetector(
            key: const ValueKey('context-sheet-handle'),
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (d) => onDrag(d.delta.dy),
            onVerticalDragEnd: (_) => onDragEnd(),
            child: SizedBox(
              height: handleHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: t.muted.withValues(alpha: .45),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  if (title != null)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      right: 60,
                      child: Row(
                        children: [
                          if (onBack != null)
                            // VOLTAR SO COM O SIMBOLO, E GRANDE.
                            //
                            // A palavra ao lado do chevron obrigava os
                            // dois a encolher para caber na faixa, e o
                            // resultado era um alvo que ninguem acerta.
                            // Um chevron de 26 num quadrado de 44 e
                            // maior que o par inteiro era antes, e o
                            // gesto de voltar ja e conhecido.
                            Tooltip(
                              message: 'Voltar às ferramentas da camada',
                              child: GestureDetector(
                                key: const ValueKey('painel-voltar'),
                                behavior: HitTestBehavior.opaque,
                                onTap: onBack,
                                child: SizedBox(
                                  width: 44,
                                  height: handleHeight,
                                  child: Icon(
                                    Icons.chevron_left,
                                    size: 22,
                                    color: t.text,
                                  ),
                                ),
                              ),
                            )
                          else
                            const SizedBox(width: 10),
                          if (subtitle != null)
                            Flexible(
                              child: Text(
                                subtitle!,
                                key: const ValueKey('editor-context'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  height: 1.1,
                                  color: t.muted,
                                ),
                              ),
                            ),
                          if (subtitle != null)
                            Text(
                              ' · ',
                              style: TextStyle(fontSize: 10, color: t.muted),
                            ),
                          Flexible(
                            child: Text(
                              title!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                height: 1.1,
                                fontWeight: FontWeight.w600,
                                color: t.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (trailing != null)
                    Positioned(right: 4, top: 0, bottom: 0, child: trailing!),
                ],
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// A ALCA ENTRE O PREVIEW E O TRANSPORTE: arrasta a altura do preview.
/// Duplo toque volta ao padrao.
class PreviewResizeHandle extends StatelessWidget {
  const PreviewResizeHandle({
    super.key,
    required this.onDrag,
    required this.onReset,
    required this.onExpand,
    required this.expanded,
  });

  final ValueChanged<double> onDrag;
  final VoidCallback onReset;
  final VoidCallback onExpand;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final t = AureaTokens.of(context);
    return GestureDetector(
      key: const ValueKey('preview-resize-handle'),
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: (d) => onDrag(d.delta.dy),
      onDoubleTap: onReset,
      child: Container(
        height: EditorLayoutMetrics.handleHeight,
        color: t.surface,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: t.muted.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Positioned(
              right: 4,
              child: Tooltip(
                message: expanded ? 'Voltar ao editor' : 'Expandir preview',
                child: GestureDetector(
                  key: const ValueKey('preview-expand'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onExpand,
                  child: SizedBox(
                    width: 40,
                    height: EditorLayoutMetrics.handleHeight,
                    child: Icon(
                      expanded ? Icons.fullscreen_exit : Icons.fullscreen,
                      size: 10,
                      color: t.muted,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
