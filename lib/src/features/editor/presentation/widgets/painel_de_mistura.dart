import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../domain/blend_extra.dart';
import '../../domain/layer.dart';
import '../../domain/mask.dart';

/// UM MODO DE MISTURA na lista, nativo do Flutter ou proprio do app.
///
/// Os dois convivem porque metade da lista que todo editor de motion
/// tem NAO existe no Flutter: Linear Burn, Vivid Light, Pin Light, Hard
/// Mix, Dividir, Subtrair, as duas "cor mais" e Dissolver passam pelo
/// compositor de dois andares (`custom_blend.dart`). Para quem usa, os
/// dois grupos sao a mesma lista — e e por isso que aqui eles sao um
/// tipo so.
@immutable
class ModoDeMistura {
  const ModoDeMistura.nativo(this.rotulo, this.nativo) : proprio = null;
  const ModoDeMistura.proprio(this.proprio)
    : rotulo = '',
      nativo = BlendMode.srcOver;

  final String rotulo;
  final BlendMode nativo;
  final AureaBlend? proprio;

  String get nome => proprio == null ? rotulo : aureaBlendLabel(proprio!);
}

/// A LISTA, na ordem e nas familias que todo editor de motion usa.
///
/// A ordem nao e decorativa: quem procura "escurecer um pouco" desce
/// ate a familia de escurecer e experimenta os cinco vizinhos. Uma
/// lista alfabetica poria Multiplicar entre Matiz e Normal, e quem
/// procura por efeito — nao por nome — teria de conhecer a lista de
/// cor para achar o que quer.
const familiasDeMistura = <(String, List<ModoDeMistura>)>[
  (
    'Normal',
    [
      ModoDeMistura.nativo('Normal', BlendMode.srcOver),
      ModoDeMistura.proprio(AureaBlend.dissolve),
    ],
  ),
  (
    'Escurecer',
    [
      ModoDeMistura.nativo('Escurecer', BlendMode.darken),
      ModoDeMistura.nativo('Multiplicar', BlendMode.multiply),
      ModoDeMistura.nativo('Subexposicao de cor', BlendMode.colorBurn),
      ModoDeMistura.proprio(AureaBlend.linearBurn),
      ModoDeMistura.proprio(AureaBlend.darkerColor),
    ],
  ),
  (
    'Clarear',
    [
      ModoDeMistura.nativo('Clarear', BlendMode.lighten),
      ModoDeMistura.nativo('Divisao', BlendMode.screen),
      ModoDeMistura.nativo('Superexposicao de cor', BlendMode.colorDodge),
      ModoDeMistura.nativo('Somar', BlendMode.plus),
      ModoDeMistura.proprio(AureaBlend.lighterColor),
    ],
  ),
  (
    'Contraste',
    [
      ModoDeMistura.nativo('Sobrepor', BlendMode.overlay),
      ModoDeMistura.nativo('Luz suave', BlendMode.softLight),
      ModoDeMistura.nativo('Luz forte', BlendMode.hardLight),
      ModoDeMistura.proprio(AureaBlend.vividLight),
      ModoDeMistura.proprio(AureaBlend.linearLight),
      ModoDeMistura.proprio(AureaBlend.pinLight),
      ModoDeMistura.proprio(AureaBlend.hardMix),
    ],
  ),
  (
    'Comparar',
    [
      ModoDeMistura.nativo('Diferenca', BlendMode.difference),
      ModoDeMistura.nativo('Exclusao', BlendMode.exclusion),
      ModoDeMistura.proprio(AureaBlend.subtract),
      ModoDeMistura.proprio(AureaBlend.divide),
    ],
  ),
  (
    'Cor',
    [
      ModoDeMistura.nativo('Matiz', BlendMode.hue),
      ModoDeMistura.nativo('Saturacao', BlendMode.saturation),
      ModoDeMistura.nativo('Cor', BlendMode.color),
      ModoDeMistura.nativo('Luminosidade', BlendMode.luminosity),
    ],
  ),
];

String rotuloDoMatte(MatteMode m) => switch (m) {
  MatteMode.none => 'Nenhum',
  MatteMode.alpha => 'Alfa',
  MatteMode.alphaInvert => 'Alfa invertido',
  MatteMode.luma => 'Luma',
  MatteMode.lumaInvert => 'Luma invertido',
};

/// MISTURA E RECORTE: como esta camada se combina com o que esta atras,
/// e como a de cima pode recorta-la.
///
/// As duas coisas dividem cartao porque sao a mesma pergunta feita por
/// dois lados — o que acontece no encontro desta camada com a vizinha.
/// E porque nenhuma das duas, sozinha, enche um painel.
///
/// Os dois motores estavam prontos e sem porta: `setBlendMode`,
/// `setCustomBlend`, `setMatte` e `setMatteFromAbove` existiam, o palco
/// ja desenhava os 27 modos e o matte com o grupo isolado e a conversao
/// de canal — e nenhum widget chamava nenhum deles.
class PainelDeMistura extends ConsumerWidget {
  const PainelDeMistura({super.key, required this.camada});

  final Layer camada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(editorControllerProvider.notifier);
    final proprio = camada.customBlend;
    final nativo = camada.blendMode;
    final fonte = c.matteSourceAbove(camada.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (familia, modos) in familiasDeMistura) ...[
          _Titulo(familia),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in modos)
                _Chip(
                  rotulo: m.nome,
                  // O NOME DA FAMILIA E O DE UM DOS MODOS DELA sao o
                  // mesmo em quase toda familia — "Escurecer" e o
                  // titulo e tambem um chip. Para o olho, o peso do
                  // texto separa os dois; para quem ouve a tela, nao
                  // separava nada.
                  nome: 'Modo ${m.nome}',
                  aceso: m.proprio != null
                      ? proprio == m.proprio
                      : proprio == null && nativo == m.nativo,
                  aoTocar: () => m.proprio != null
                      ? c.setCustomBlend(camada.id, m.proprio)
                      : c.setBlendMode(camada.id, m.nativo),
                ),
            ],
          ),
        ],
        const _Titulo('Recortar pela camada de cima'),
        // O MATTE USA A VIZINHA DE CIMA, e so ela. Escolher qualquer
        // camada da cena e possivel no motor (`setMatte`), mas exigiria
        // um seletor; a vizinha de cima e como todo editor faz, e e o
        // que `setMatteFromAbove` ja resolve sozinho.
        if (fonte == null)
          const _Aviso(
            'Nao ha camada com imagem acima desta. Suba uma para usa-la '
            'como recorte.',
          )
        else
          _Aviso('Recorta usando "${fonte.name}", logo acima.'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final m in MatteMode.values)
              _Chip(
                rotulo: rotuloDoMatte(m),
                nome: 'Recorte ${rotuloDoMatte(m)}',
                aceso: camada.matteMode == m,
                apagado: fonte == null && m != MatteMode.none,
                aoTocar: () => c.setMatteFromAbove(camada.id, m),
              ),
          ],
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.rotulo,
    required this.nome,
    required this.aceso,
    required this.aoTocar,
    this.apagado = false,
  });

  final String rotulo;

  /// O que a leitura de tela anuncia. Difere de [rotulo] porque o texto
  /// desenhado vive dentro de uma secao que ja diz a familia, e a
  /// leitura nao tem essa secao por perto.
  final String nome;

  final bool aceso;
  final bool apagado;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: !apagado,
    enabled: !apagado,
    selected: aceso,
    label: nome,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: apagado ? null : aoTocar,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: aceso ? AmColors.chip : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          rotulo,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: apagado
                ? AmColors.muted.withValues(alpha: .4)
                : aceso
                ? AmColors.accent
                : AmColors.text,
          ),
        ),
      ),
    ),
  );
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 0, 6),
    child: Text(
      texto,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AmColors.muted,
      ),
    ),
  );
}

class _Aviso extends StatelessWidget {
  const _Aviso(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(
      texto,
      style: const TextStyle(fontSize: 11, color: AmColors.muted, height: 1.4),
    ),
  );
}
