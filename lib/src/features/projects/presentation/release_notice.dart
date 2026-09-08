import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../editor/presentation/am/am_colors.dart';

// Change this revision when publishing a new set of release notes.
const releaseNoticeRevision = '2026-09-08-editor-3d-audio';
const releaseNoticeSeenKey = 'aurea.releaseNotice.seen';

const releaseHighlights = <(IconData, String, String)>[
  (
    CupertinoIcons.music_note_2,
    'Áudio',
    'Correções ao importar e extrair som. Vídeo mudo não silencia outras faixas.',
  ),
  (
    CupertinoIcons.move,
    'Animação',
    'Keyframes no eixo Z corrigidos e botão de vincular a objeto nulo mais visível.',
  ),
  (
    CupertinoIcons.cube_box,
    '3D',
    'Importação de modelos grandes otimizada, sólidos mais suaves, reflexos de ambiente e partículas como estrelas.',
  ),
  (
    CupertinoIcons.wand_stars,
    'Efeitos e transições',
    'Oscilar, S_Shake, Motion Tile ajustado, novos efeitos de áudio e transições opcionais entre camadas.',
  ),
  (
    CupertinoIcons.slider_horizontal_3,
    'Editor',
    'Controles Pro sempre disponíveis e ajustes de espaço nos painéis.',
  ),
  (
    CupertinoIcons.folder,
    'Projetos',
    'Salvamento em segundo plano e correções para preservar suas últimas edições.',
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
