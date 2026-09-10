import 'package:flutter/material.dart';

import '../../../../core/ui/am_colors.dart';

/// A PROPRIEDADE QUE O RAIL ESQUERDO ESTA MIRANDO.
///
/// O rail e o mesmo em toda ferramenta — voltar, marcar keyframe, abrir
/// a curva —, mas a propriedade muda: na transformacao e o modo vigente
/// (posicao, rotacao...), nos efeitos e o parametro escolhido. Em vez de
/// o rail conhecer camada, modo e efeito, ele recebe isto pronto e nao
/// sabe de onde veio.
@immutable
class AlvoDoRail {
  const AlvoDoRail({
    this.temKeyframeAqui = false,
    this.animado = false,
    this.aoAlternarKeyframe,
    this.aoAbrirCurva,
  });

  /// Ha marca EXATAMENTE no cabecote?
  final bool temKeyframeAqui;

  /// A propriedade tem alguma marca, em qualquer instante?
  final bool animado;

  final VoidCallback? aoAlternarKeyframe;

  /// Nulo quando o cabecote nao esta dentro de um trecho entre duas
  /// marcas — nao ha caminho para curvar.
  final VoidCallback? aoAbrirCurva;
}

/// O RAIL ESQUERDO: voltar, keyframe, curva.
///
/// Sempre nesta ordem, em toda ferramenta, porque a mao aprende posicao
/// antes de aprender icone. Largura de 46 px, medida na referencia
/// (`docs/painel-de-transformacao-alight.md`).
///
/// O `‹` DAQUI VOLTA UM NIVEL — para a grade de categorias. O `‹` do
/// cabecalho da tela fecha a ferramenta inteira. Sao duas perguntas
/// diferentes, e por isso dois botoes.
class RailEsquerdo extends StatelessWidget {
  const RailEsquerdo({
    super.key,
    required this.aoVoltar,
    required this.alvo,
  });

  final VoidCallback aoVoltar;
  final AlvoDoRail alvo;

  static const largura = 46.0;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: largura,
    child: Column(
      children: [
        _BotaoDoRail(
          icone: Icons.chevron_left_rounded,
          rotulo: 'Voltar as ferramentas',
          tamanho: 24,
          aoTocar: aoVoltar,
        ),
        _BotaoDoRail(
          // O LOSANGO E O SIMBOLO DE KEYFRAME em todo editor de
          // animacao que existe. Cheio quando ha marca no cabecote,
          // vazado quando a propriedade anima mas nao aqui, apagado
          // quando nao anima nada.
          icone: alvo.temKeyframeAqui
              ? Icons.change_history_rounded
              : Icons.change_history_outlined,
          rotulo: alvo.temKeyframeAqui
              ? 'Tirar o keyframe daqui'
              : 'Marcar keyframe aqui',
          aoTocar: alvo.aoAlternarKeyframe,
          aceso: alvo.temKeyframeAqui,
          meioAceso: alvo.animado,
        ),
        _BotaoDoRail(
          icone: Icons.timeline_rounded,
          rotulo: 'Abrir a curva',
          aoTocar: alvo.aoAbrirCurva,
          meioAceso: alvo.animado,
        ),
      ],
    ),
  );
}

/// O RAIL DIREITO: os quatro modos de transformacao.
///
/// Empilhados na ordem da referencia — mover, girar, escalar, inclinar —
/// e o vigente aceso. Sao MODOS, e nao abas: cada um troca a superficie
/// do miolo inteira, porque cada grandeza pede um gesto diferente. Ver
/// `docs/painel-de-transformacao-alight.md`, "A regra que muda tudo".
class RailDireito extends StatelessWidget {
  const RailDireito({
    super.key,
    required this.modos,
    required this.vigente,
    required this.aoEscolher,
  });

  /// Cada modo: o icone e o rotulo de acessibilidade.
  final List<(IconData, String)> modos;
  final int vigente;
  final void Function(int) aoEscolher;

  static const largura = 40.0;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: largura,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        for (var i = 0; i < modos.length; i++)
          Semantics(
            container: true,
            excludeSemantics: true,
            button: true,
            selected: i == vigente,
            label: modos[i].$2,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => aoEscolher(i),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: i == vigente ? AmColors.chip : null,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  modos[i].$1,
                  size: 20,
                  color: i == vigente ? AmColors.accent : AmColors.muted,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _BotaoDoRail extends StatelessWidget {
  const _BotaoDoRail({
    required this.icone,
    required this.rotulo,
    required this.aoTocar,
    this.tamanho = 20,
    this.aceso = false,
    this.meioAceso = false,
  });

  final IconData icone;
  final String rotulo;
  final VoidCallback? aoTocar;
  final double tamanho;

  /// A propriedade tem marca EXATAMENTE aqui.
  final bool aceso;

  /// A propriedade anima, mas nao neste instante.
  final bool meioAceso;

  @override
  Widget build(BuildContext context) {
    final ativo = aoTocar != null;
    return Expanded(
      child: Semantics(
        container: true,
        excludeSemantics: true,
        button: ativo,
        enabled: ativo,
        label: rotulo,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: aoTocar,
          child: SizedBox(
            width: RailEsquerdo.largura,
            child: Icon(
              icone,
              size: tamanho,
              color: !ativo
                  // APAGADO NAO E CINZA CLARO: e quase invisivel. Um
                  // controle que nao age precisa parecer que nao age
                  // antes do dedo descobrir.
                  ? AmColors.muted.withValues(alpha: .28)
                  : aceso
                  ? AmColors.accent
                  : meioAceso
                  ? AmColors.accent.withValues(alpha: .5)
                  : AmColors.text,
            ),
          ),
        ),
      ),
    );
  }
}
