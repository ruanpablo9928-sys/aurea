import 'package:flutter/cupertino.dart';

import 'am_colors.dart';
import 'am_widgets.dart';

/// A CASCA DE TODO PAINEL DE PARAMETRO.
///
/// Motion e um ciclo apertado: rolar o tempo, olhar o preview, ajustar o
/// valor, cravar o keyframe, rolar de novo. As tres coisas que o ciclo
/// precisa — preview, controle do parametro e a linha de keyframes
/// DAQUELE parametro — tem de estar visiveis ao mesmo tempo. Se uma sai
/// da tela, a pessoa passa a navegar em vez de animar.
///
/// Dai as regras desta casca:
///
///   ALTURA FIXA      igual entre tipos de camada e entre secoes. Painel
///                    que muda de tamanho redimensiona o preview, e o
///                    enquadramento pula debaixo do dedo.
///   ABAS EM FILEIRA  trocar de parametro e UM toque lateral, nao
///                    voltar-e-entrar. Com indicador de que ha mais.
///   TRILHO FIXO      voltar, keyframe, curva e mais num trilho vertical
///                    a esquerda, na mesma posicao em toda aba. Memoria
///                    muscular so existe se o botao nao anda.
class AmPanelChrome extends StatelessWidget {
  const AmPanelChrome({
    super.key,
    required this.onBack,
    required this.corpo,
    required this.animado,
    required this.temKfAqui,
    required this.onCravar,
    this.onCurva,
    this.onMais,
    this.abas = const [],
    this.abaAtiva,
    this.onAba,
  });

  final VoidCallback onBack;
  final Widget corpo;

  /// O parametro em edicao tem keyframes / tem keyframe neste instante.
  final bool animado;
  final bool temKfAqui;
  final VoidCallback onCravar;
  final VoidCallback? onCurva;
  final VoidCallback? onMais;

  final List<ParamTab> abas;
  final String? abaAtiva;
  final ValueChanged<String>? onAba;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AmColors.panel,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // TRILHO ESQUERDO FIXO. Troca-se de aba pela fileira e o
          // diamante nao sai do lugar — e o que faz memoria muscular.
          AmLeftRail(
            onBack: onBack,
            animado: animado,
            temKfAqui: temKfAqui,
            onCravar: onCravar,
            onCurva: onCurva,
            onMais: onMais,
          ),
          Expanded(
            child: Column(
              children: [
                if (abas.isNotEmpty)
                  AmParamTabs(
                    abas: abas,
                    ativa: abaAtiva,
                    onAba: onAba ?? (_) {},
                  ),
                Expanded(child: corpo),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// O TRILHO ESQUERDO: `← ◆ ⌇ ⋯`, na mesma posicao em todo painel.
///
/// Voltar, cravar keyframe, curva de easing, mais. Acao indisponivel
/// fica esmaecida, nunca some: botao que aparece e some troca o lugar
/// dos vizinhos, e a memoria muscular vira chute. Navegar entre
/// keyframes nao mora aqui: e tocar no diamante da barra da camada.
class AmLeftRail extends StatelessWidget {
  const AmLeftRail({
    super.key,
    required this.onBack,
    required this.animado,
    required this.temKfAqui,
    required this.onCravar,
    this.onCurva,
    this.onMais,
  });

  final VoidCallback onBack;
  final bool animado;
  final bool temKfAqui;
  final VoidCallback onCravar;
  final VoidCallback? onCurva;
  final VoidCallback? onMais;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      child: Column(
        children: [
          AmRailButton(
            onTap: onBack,
            child: const Icon(CupertinoIcons.chevron_back,
                size: 24, color: AmColors.text),
          ),
          AmRailButton(
            onTap: onCravar,
            child: AmDiamondAdd(active: animado, filled: temKfAqui),
          ),
          AmRailButton(
            onTap: animado ? onCurva : null,
            child: Opacity(
              opacity: animado && onCurva != null ? 1 : 0.32,
              child: AmCurveIcon(
                  color: animado ? AmColors.text : AmColors.muted),
            ),
          ),
          const Spacer(),
          AmRailButton(
            onTap: onMais,
            child: Opacity(
              opacity: onMais != null ? 1 : 0.32,
              child: const Icon(CupertinoIcons.ellipsis,
                  size: 20, color: AmColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// Uma aba da fileira de parametros.
class ParamTab {
  const ParamTab({
    required this.id,
    required this.label,
    this.animated = false,
  });

  final String id;
  final String label;

  /// Tem keyframes: a aba ganha um ponto, para se achar o que ja foi
  /// animado sem entrar em cada uma.
  final bool animated;
}

/// FILEIRA DE ABAS horizontal e rolavel, com indicador nas pontas.
///
/// O indicador nao e enfeite: fileira que corta a ultima aba no meio
/// avisa que ha mais; fileira que corta rente parece completa, e a
/// pessoa nunca descobre o que existe do lado.
class AmParamTabs extends StatefulWidget {
  const AmParamTabs({
    super.key,
    required this.abas,
    required this.ativa,
    required this.onAba,
  });

  final List<ParamTab> abas;
  final String? ativa;
  final ValueChanged<String> onAba;

  @override
  State<AmParamTabs> createState() => _AmParamTabsState();
}

class _AmParamTabsState extends State<AmParamTabs> {
  final _scroll = ScrollController();
  bool _temEsquerda = false;
  bool _temDireita = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_mede);
    WidgetsBinding.instance.addPostFrameCallback((_) => _mede());
  }

  @override
  void didUpdateWidget(AmParamTabs old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) => _mede());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _mede() {
    if (!mounted || !_scroll.hasClients) return;
    final p = _scroll.position;
    final esq = p.pixels > 2;
    final dir = p.pixels < p.maxScrollExtent - 2;
    if (esq != _temEsquerda || dir != _temDireita) {
      setState(() {
        _temEsquerda = esq;
        _temDireita = dir;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Stack(
        children: [
          ListView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            children: [
              for (final aba in widget.abas)
                _Aba(
                  aba: aba,
                  selecionada: aba.id == widget.ativa,
                  onTap: () => widget.onAba(aba.id),
                ),
            ],
          ),
          if (_temEsquerda) const _Ponta(esquerda: true),
          if (_temDireita) const _Ponta(esquerda: false),
        ],
      ),
    );
  }
}

class _Ponta extends StatelessWidget {
  const _Ponta({required this.esquerda});

  final bool esquerda;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: esquerda ? 0 : null,
      right: esquerda ? null : 0,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Container(
          width: 26,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: esquerda ? Alignment.centerLeft : Alignment.centerRight,
              end: esquerda ? Alignment.centerRight : Alignment.centerLeft,
              colors: const [AmColors.panel, Color(0x00171C23)],
            ),
          ),
        ),
      ),
    );
  }
}

class _Aba extends StatelessWidget {
  const _Aba({
    required this.aba,
    required this.selecionada,
    required this.onTap,
  });

  final ParamTab aba;
  final bool selecionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        constraints: const BoxConstraints(minWidth: 64),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selecionada ? AmColors.accentDim : AmColors.chip,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              aba.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selecionada ? FontWeight.w700 : FontWeight.w500,
                color: selecionada ? AmColors.accent : AmColors.text,
              ),
            ),
            if (aba.animated) ...[
              const SizedBox(width: 5),
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: AmColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
