import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import 'linha_de_parametro.dart';
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
    // O NOME DA FAMILIA E O DA REFERENCIA: "Diferenca", e nao
    // "Comparar". Era o unico rotulo desta lista que divergia.
    'Diferenca',
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
/// QUAL CATEGORIA DE MISTURA ESTA ABERTA no accordion.
///
/// Vive fora do widget porque o estado do painel tem de SOBREVIVER a ida
/// e volta: sair da familia e reabrir tem de devolver a mesma categoria
/// aberta, e nao a lista inteira fechada.
final categoriaDeMisturaProvider = StateProvider<String?>((ref) => 'Normal');

/// HOMOGENEIZACAO E OPACIDADE (V 00:53).
///
/// UMA familia, e nao duas. O Aurea tinha "Opacidade" e "Mistura e
/// recorte" como tiles separados da grade; no AM as duas coisas moram no
/// mesmo painel, com a opacidade FIXA no topo e as categorias de blend
/// num accordion que rola por baixo dela. Faz sentido: as duas respondem
/// a mesma pergunta — como esta camada se junta com o que esta atras.
///
/// A OPACIDADE NAO ROLA. Ela e o controle mais usado do painel, e
/// perde-la de vista ao descer a lista custaria uma rolagem de volta a
/// cada ajuste.
class PainelDeMistura extends ConsumerWidget {
  const PainelDeMistura({
    super.key,
    required this.camada,
    required this.tempo,
  });

  final Layer camada;
  final Duration tempo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(editorControllerProvider.notifier);
    final visivel =
        ref.watch(projetoVisivelProvider).layerById(camada.id) ?? camada;
    final proprio = camada.customBlend;
    final nativo = camada.blendMode;
    final fonte = c.matteSourceAbove(camada.id);
    final aberta = ref.watch(categoriaDeMisturaProvider);
    final opacidade = visivel.opacity.valueAt(visivel.localTime(tempo));

    String? nomeDoModoEm(List<ModoDeMistura> modos) {
      for (final m in modos) {
        final aceso = m.proprio != null
            ? proprio == m.proprio
            : proprio == null && nativo == m.nativo;
        if (aceso) return m.nome;
      }
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // O BLOCO DE OPACIDADE, no topo e fora da rolagem.
        LinhaDeParametro(
          rotulo: 'Opacidade',
          nome: 'Opacidade',
          valor: opacidade * 100,
          casas: 1,
          sufixo: '%',
          porPixel: 0.5,
          aoComecar: c.beginGesture,
          aoMudar: (v) => c.editOpacity(camada.id, tempo, v / 100),
          aoTerminar: c.endGesture,
          aoDigitar: (v) => c.editOpacity(camada.id, tempo, v / 100),
        ),
        const Divider(height: 1, color: AmColors.hairline),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              for (final (familia, modos) in familiasDeMistura)
                _Categoria(
                  nome: familia,
                  escolhido: nomeDoModoEm(modos),
                  aberta: aberta == familia,
                  aoAlternar: () =>
                      ref.read(categoriaDeMisturaProvider.notifier).state =
                          aberta == familia ? null : familia,
                  filhos: [
                    for (final m in modos)
                      _Opcao(
                        rotulo: m.nome,
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
              // A CATEGORIA "MASCARA" DA LISTA DO AM: aqui ela guarda o
              // recorte pela camada de cima, que e o unico recorte que o
              // Aurea faz sem seletor de origem.
              _Categoria(
                nome: 'Mascara',
                escolhido: camada.matteMode == MatteMode.none
                    ? null
                    : rotuloDoMatte(camada.matteMode),
                aberta: aberta == 'Mascara',
                aoAlternar: () =>
                    ref.read(categoriaDeMisturaProvider.notifier).state =
                        aberta == 'Mascara' ? null : 'Mascara',
                filhos: [
                  if (fonte == null)
                    const _Aviso(
                      'Nao ha camada com imagem acima desta. Suba uma para '
                      'usa-la como recorte.',
                    )
                  else
                    _Aviso('Recorta usando "${fonte.name}", logo acima.'),
                  for (final m in MatteMode.values)
                    _Opcao(
                      rotulo: rotuloDoMatte(m),
                      nome: 'Recorte ${rotuloDoMatte(m)}',
                      aceso: camada.matteMode == m,
                      apagado: fonte == null && m != MatteMode.none,
                      aoTocar: () => c.setMatteFromAbove(camada.id, m),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// UMA LINHA DE CATEGORIA com triangulo, que expande no proprio lugar.
///
/// O que estava escolhido dentro dela aparece na propria linha: com a
/// categoria fechada, essa e a unica forma de saber onde o modo atual
/// mora sem abrir as sete.
class _Categoria extends StatelessWidget {
  const _Categoria({
    required this.nome,
    required this.escolhido,
    required this.aberta,
    required this.aoAlternar,
    required this.filhos,
  });

  final String nome;
  final String? escolhido;
  final bool aberta;
  final VoidCallback aoAlternar;
  final List<Widget> filhos;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        container: true,
        excludeSemantics: true,
        button: true,
        expanded: aberta,
        label: 'Categoria $nome',
        value: escolhido,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: aoAlternar,
          child: SizedBox(
            height: 42,
            child: Row(
              children: [
                const SizedBox(width: 6),
                Icon(
                  aberta
                      ? Icons.arrow_drop_down_rounded
                      : Icons.arrow_right_rounded,
                  size: 22,
                  color: AmColors.muted,
                ),
                const SizedBox(width: 2),
                Text(
                  nome,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AmColors.text,
                  ),
                ),
                const Spacer(),
                if (escolhido != null) ...[
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        escolhido!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AmColors.accent,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.check_rounded,
                    size: 15,
                    color: AmColors.accent,
                  ),
                ],
                const SizedBox(width: 10),
              ],
            ),
          ),
        ),
      ),
      if (aberta)
        Padding(
          padding: const EdgeInsets.only(left: 22, right: 8, bottom: 6),
          child: Wrap(spacing: 6, runSpacing: 6, children: filhos),
        ),
    ],
  );
}

class _Opcao extends StatelessWidget {
  const _Opcao({
    required this.rotulo,
    required this.nome,
    required this.aceso,
    required this.aoTocar,
    this.apagado = false,
  });

  final String rotulo;
  final String nome;
  final bool aceso;
  final bool apagado;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => _Chip(
    rotulo: rotulo,
    nome: nome,
    aceso: aceso,
    apagado: apagado,
    aoTocar: aoTocar,
  );
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
