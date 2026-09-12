import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/ui/am_colors.dart';

// Change this revision when publishing a new set of release notes.
const releaseNoticeRevision = '2026-09-12-beta-77';
const releaseNoticeSeenKey = 'aurea.releaseNotice.seen';

const releaseHighlights = <(IconData, String, String)>[
  (
    CupertinoIcons.play_rectangle,
    'Melhorar qualidade',
    'Nova área na tela inicial: aumente imagens e vídeos com IA e aplique 15 estilos de cor.',
  ),
  (
    CupertinoIcons.cube_box,
    'Cena 3D',
    'Interface nova para celular, dicas, troca fácil de câmera, reflexos do ambiente e otimização dos modelos.',
  ),
  (
    CupertinoIcons.move,
    'Animação',
    'Rotação, vínculos com nulos e seleção com profundidade Z corrigidos. AutoKey ligado por padrão.',
  ),
  (
    CupertinoIcons.timer,
    'Velocidade e câmera lenta',
    'Time Remap com curvas e Optical Flow estão em Efeitos para controlar o tempo e suavizar movimentos.',
  ),
  (
    CupertinoIcons.checkmark_seal,
    'Exportação',
    'Os efeitos ficam dentro do quadro do vídeo. Ajustamos também controles e painéis para telas pequenas.',
  ),
];

Future<void> showReleaseNotice(BuildContext context) => showDialog<void>(
  context: context,
  builder: (dialogContext) => AlertDialog(
    key: const Key('release-notice'),
    backgroundColor: AmColors.panel,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    scrollable: true,
    title: const Text(
      'O que mudou no Aurea',
      style: TextStyle(
        color: AmColors.text,
        fontSize: 21,
        fontWeight: FontWeight.w700,
      ),
    ),
    content: SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (icon, title, body) in releaseHighlights)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: AmColors.accent, size: 19),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$title: ',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: body),
                        ],
                      ),
                      style: const TextStyle(
                        color: AmColors.text,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
    actions: [
      FilledButton(
        key: const Key('release-notice-dismiss'),
        style: FilledButton.styleFrom(
          backgroundColor: AmColors.action,
          foregroundColor: AmColors.onAction,
        ),
        onPressed: () => Navigator.of(dialogContext).pop(),
        child: const Text('Vamos editar'),
      ),
    ],
  ),
);
