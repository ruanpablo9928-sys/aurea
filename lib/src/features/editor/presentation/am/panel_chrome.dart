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
///   ACOES FIXAS      as cinco acoes de keyframe sempre na mesma posicao,
///                    na mesma ordem. Memoria muscular so existe se o
///                    botao nao anda.
///   TRILHA TOCAVEL   diz onde a pessoa esta e volta um nivel.
class AmPanelChrome extends StatelessWidget {
  const AmPanelChrome({
    super.key,
    required this.trilha,
    required this.onBack,
    required this.corpo,
    this.abas = const [],
    this.abaAtiva,
    this.onAba,
    this.acoes,
  });

  /// "Estrela 2 · Mover e transformar".
  final String trilha;
  final VoidCallback onBack;
  final Widget corpo;

  final List<ParamTab> abas;
  final String? abaAtiva;
  final ValueChanged<String>? onAba;

  /// A fileira fixa de acoes. Normalmente [AmKeyframeActions].
  final Widget? acoes;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AmColors.panel,
      child: Column(
        children: [
          _Trilha(texto: trilha, onBack: onBack),
          if (abas.isNotEmpty)
            AmParamTabs(
              abas: abas,
              ativa: abaAtiva,
              onAba: onAba ?? (_) {},
            ),
          Expanded(child: corpo),
          ?acoes,
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

/// A trilha: onde a pessoa esta, e o caminho de volta.
class _Trilha extends StatelessWidget {
  const _Trilha({required this.texto, required this.onBack});

  final String texto;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onBack,
      // Deslizar para baixo tambem fecha. O corpo do painel fica de
      // fora do gesto de proposito: la dentro vertical e arrastar
      // valor, e roubar esse gesto seria pior que nao ter o atalho.
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) > 300) onBack();
      },
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AmColors.hairline)),
        ),
        child: Row(
          children: [
            const Icon(CupertinoIcons.chevron_back,
                size: 15, color: AmColors.muted),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AmColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
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

/// AS CINCO ACOES DE KEYFRAME, sempre nesta ordem e nesta posicao.
///
/// `‹◆  ◆  ◆›  ∿  ↺` — keyframe anterior, cravar aqui, proximo, curva,
/// resetar. Acao indisponivel fica ESMAECIDA, nunca some: botao que
/// aparece e some troca o lugar dos vizinhos, e ai a memoria muscular
/// vira chute.
class AmKeyframeActions extends StatelessWidget {
  const AmKeyframeActions({
    super.key,
    required this.animado,
    required this.temKfAqui,
    required this.onAnterior,
    required this.onCravar,
    required this.onProximo,
    required this.onCurva,
    required this.onResetar,
  });

  final bool animado;
  final bool temKfAqui;
  final VoidCallback? onAnterior;
  final VoidCallback onCravar;
  final VoidCallback? onProximo;
  final VoidCallback? onCurva;
  final VoidCallback onResetar;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AmColors.hairline)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Acao(
            onTap: animado ? onAnterior : null,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.chevron_left, size: 13),
                Icon(CupertinoIcons.rhombus, size: 13),
              ],
            ),
          ),
          _Acao(
            onTap: onCravar,
            destaque: true,
            child: AmDiamondAdd(active: animado, filled: temKfAqui),
          ),
          _Acao(
            onTap: animado ? onProximo : null,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.rhombus, size: 13),
                Icon(CupertinoIcons.chevron_right, size: 13),
              ],
            ),
          ),
          _Acao(
            onTap: animado ? onCurva : null,
            child: AmCurveIcon(
                color: animado ? AmColors.text : AmColors.muted),
          ),
          _Acao(
            onTap: onResetar,
            child: const Icon(CupertinoIcons.arrow_counterclockwise, size: 17),
          ),
        ],
      ),
    );
  }
}

class _Acao extends StatelessWidget {
  const _Acao({required this.child, this.onTap, this.destaque = false});

  final Widget child;
  final VoidCallback? onTap;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final ligado = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 56,
        height: 46,
        alignment: Alignment.center,
        child: Opacity(
          opacity: ligado ? 1 : 0.32,
          child: IconTheme(
            data: IconThemeData(
                color: destaque ? AmColors.text : AmColors.muted),
            child: child,
          ),
        ),
      ),
    );
  }
}
