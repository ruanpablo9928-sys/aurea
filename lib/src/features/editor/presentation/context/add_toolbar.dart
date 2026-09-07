import 'package:flutter/cupertino.dart';

import '../../../../core/theme/tokens.dart';

/// O que cada tile do E1 pede.
enum AddTarget {
  midia,
  audio,
  texto,
  forma,
  efeito,
  icone,
  grupo,
  objeto,
  legendas,
  marcas,
  batidas,
  autoEdit,
}

/// E1 — NADA SELECIONADO: a barra de ADICIONAR (Blurrr/CapCut).
///
/// Icones grandes com rotulo, rolaveis. Cada um abre o seletor certo.
/// Embaixo, a linha do projeto: legendas, marcas, batidas, AutoEdit.
class AddToolbar extends StatelessWidget {
  const AddToolbar({
    super.key,
    required this.onTarget,
    required this.pro,
    this.empty = false,
  });

  final ValueChanged<AddTarget> onTarget;
  final bool pro;

  /// Sem camada nenhuma: estado vazio com a chamada.
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final t = AureaTokens.of(context);
    final principais = <(AddTarget, IconData, String, Color)>[
      (AddTarget.midia, CupertinoIcons.photo_on_rectangle, 'Mídia', const Color(0xFF6A52E0)),
      (AddTarget.audio, CupertinoIcons.music_note, 'Áudio', const Color(0xFF1F8C93)),
      (AddTarget.texto, CupertinoIcons.textformat, 'Texto', const Color(0xFFB07A16)),
      (AddTarget.forma, CupertinoIcons.square_on_circle, 'Forma', const Color(0xFF2E9459)),
      (AddTarget.efeito, CupertinoIcons.wand_stars, 'Efeito', const Color(0xFFB0417A)),
      (AddTarget.icone, CupertinoIcons.smiley, 'Ícone', const Color(0xFF2E9459)),
      (AddTarget.grupo, CupertinoIcons.folder, 'Grupo', const Color(0xFF4C5566)),
      if (pro)
        (AddTarget.objeto, CupertinoIcons.cube, 'Objeto', const Color(0xFFC06A24)),
    ];
    final projeto = <(AddTarget, IconData, String)>[
      (AddTarget.legendas, CupertinoIcons.captions_bubble, 'Legendas'),
      (AddTarget.marcas, CupertinoIcons.bookmark, 'Marcas'),
      (AddTarget.batidas, CupertinoIcons.metronome, 'Batidas'),
      (AddTarget.autoEdit, CupertinoIcons.sparkles, 'AutoEdit'),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final compacto = c.maxHeight < 170;
        // Lista, nao Column: em altura pequena rola em vez de estourar.
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            if (empty && !compacto)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                child: Text(
                  'Comece adicionando uma mídia, um texto ou uma forma.',
                  key: const ValueKey('estado-vazio'),
                  style: TextStyle(fontSize: 12.5, color: t.muted),
                ),
              ),
            SizedBox(
              height: compacto ? 64 : 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: principais.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final (alvo, icone, rotulo, cor) = principais[i];
                  return _Tile(
                    key: ValueKey('adicionar-${alvo.name}'),
                    icone: icone,
                    rotulo: rotulo,
                    cor: cor,
                    compacto: compacto,
                    onTap: () => onTarget(alvo),
                  );
                },
              ),
            ),
            if (!compacto)
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: projeto.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final (alvo, icone, rotulo) = projeto[i];
                    return _Chip(
                      key: ValueKey('projeto-${alvo.name}'),
                      icone: icone,
                      rotulo: rotulo,
                      onTap: () => onTarget(alvo),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.icone,
    required this.rotulo,
    required this.cor,
    required this.onTap,
    required this.compacto,
  });

  final IconData icone;
  final String rotulo;
  final Color cor;
  final VoidCallback onTap;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final t = AureaTokens.of(context);
    final lado = compacto ? 48.0 : 56.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: lado,
              height: lado,
              decoration: BoxDecoration(
                color: t.chip,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icone, size: compacto ? 22 : 26, color: Color.lerp(cor, t.text, .45)),
            ),
            const SizedBox(height: 4),
            Text(
              rotulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: t.text),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.icone,
    required this.rotulo,
    required this.onTap,
  });

  final IconData icone;
  final String rotulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AureaTokens.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.chip,
          borderRadius: BorderRadius.circular(AureaTokens.radiusChip),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, size: 15, color: t.muted),
            const SizedBox(width: 6),
            Text(rotulo, style: TextStyle(fontSize: 12.5, color: t.text)),
          ],
        ),
      ),
    );
  }
}
