import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../core/ui/am_colors.dart';

// Change this revision when publishing a new set of release notes.
const releaseNoticeRevision = '2026-09-12-beta-panels';
const releaseNoticeSeenKey = 'aurea.releaseNotice.seen';

const releaseHighlights = <(IconData, String, String)>[
  (
    CupertinoIcons.play_rectangle,
    'Prévia e exportação',
    'Painel de edição maior e prévia fixa. Full, 1/2, 1/4 e 1/8 reduzem a resolução dos efeitos e do 3D na prévia.',
  ),
  (
    CupertinoIcons.cube_box,
    'Cena 3D',
    'Corrigimos luzes que impediam abrir cenas, a seleção de câmeras e controles de objetos e materiais.',
  ),
  (
    CupertinoIcons.move,
    'Animação',
    'Eixo Z liberado nas imagens, cantos editáveis, guias vermelhas no movimento e vídeo reverso ao tocar.',
  ),
  (
    CupertinoIcons.folder,
    'Importação',
    'Modelos 3D são lidos fora da interface. A lista mostra os objetos reais e explica falhas ao importar.',
  ),
  (
    CupertinoIcons.music_note_2,
    'Áudio e controles',
    'Correção no modulador de áudio e ajustes para os controles caberem em telas menores.',
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
