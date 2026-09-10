import 'package:flutter/material.dart' hide Easing;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../application/playback_controller.dart';
import '../../domain/effect.dart';
import '../../domain/keyframe.dart';
import '../../domain/layer.dart';
import '../../domain/shape.dart';
import 'editor_de_curva.dart';
import 'escolha_de_cor.dart';
import 'linha_de_parametro.dart';
import 'painel_de_mascaras.dart';
import 'painel_de_mistura.dart';
import 'painel_de_som.dart';
import 'painel_de_velocidade.dart';
import 'painel_da_camada.dart';
import 'painel_de_transformacao.dart';
import 'rails_do_painel.dart';

/// OS CONTROLES DE VERDADE, e nenhum deslizante.
///
/// A versao anterior usava `Slider` em tudo. A referencia medida
/// (`docs/painel-de-transformacao-alight.md`) nao tem um unico
/// deslizante, e o motivo nao e estetico: o deslizante desenha "onde no
/// intervalo", e posicao, escala e quase todo parametro de efeito NAO
/// TEM intervalo. Onde tem, o limite e uma borda de seguranca da tabela
/// e nao uma escala — e mapear o dedo nela faz o controle mentir.
///
/// No lugar entraram quatro superficies, cada uma pela grandeza que ela
/// serve: almofada (2D), dial (circular), fita (relativa e infinita) e
/// campo (o numero exato, digitavel).
///
/// TRES REGRAS VALEM PARA TODO CONTROLE DAQUI:
///
///   1. UM GESTO, UM DESFAZER — `beginGesture`/`endGesture` embrulham
///      todos os valores entre o toque e o solte.
///   2. O VALOR E LIDO NO CABECOTE, porque uma propriedade animada vale
///      coisas diferentes em instantes diferentes.
///   3. QUEM DECIDE SE VIRA KEYFRAME E O MOTOR, pelo losango do rail e
///      pelo interruptor do keyframe automatico.
class ControlesDaCategoria extends ConsumerWidget {
  const ControlesDaCategoria({
    super.key,
    required this.categoriaId,
    required this.camada,
    required this.playback,
    required this.aoVoltar,
  });

  final String categoriaId;
  final Layer camada;
  final PlaybackController playback;
  final VoidCallback aoVoltar;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ValueListenableBuilder<Duration>(
        valueListenable: playback.time,
        builder: (context, tempo, _) => ProvedorDoRelogio(
          playback: playback,
          child: categoriaId == 'transformar'
              // A TRANSFORMACAO MONTA OS PROPRIOS RAILS: e a unica com
              // rail direito, e a unica em que o alvo do rail esquerdo
              // muda conforme o modo escolhido.
              ? PainelDeTransformacao(
                  camada: camada,
                  tempo: tempo,
                  playback: playback,
                  aoVoltar: aoVoltar,
                  alvoDoRail: (m) => alvoDaPropriedade(
                    ref,
                    camada,
                    propDoModo(m),
                    nomeDoModo(m),
                    tempo,
                    playback,
                  ),
                )
              : _ComRail(
                  aoVoltar: aoVoltar,
                  alvo: _alvoDaCategoria(ref, tempo),
                  child: _conteudo(tempo),
                ),
        ),
      );

  Widget _conteudo(Duration tempo) => switch (categoriaId) {
    'opacidade' => _Opacidade(camada: camada, tempo: tempo),
    'texto' => _Texto(camada: camada),
    'forma' => _Forma(camada: camada, tempo: tempo),
    'som' => PainelDeSom(camada: camada),
    'velocidade' => PainelDeVelocidade(camada: camada),
    'efeitos' => _Efeitos(camada: camada, tempo: tempo),
    'midia' => _Midia(camada: camada),
    'camada' => _AcoesDaCamada(camada: camada, playback: playback),
    'mascara' => PainelDeMascaras(camada: camada, tempo: tempo),
    'mistura' => PainelDeMistura(camada: camada),
    _ => const _AindaNao(),
  };

  /// O QUE O RAIL MIRA em cada categoria.
  ///
  /// Opacidade tem propriedade propria; efeito mira o parametro
  /// escolhido; o resto nao anima nada, e ai o rail fica so com o
  /// voltar — os dois outros botoes apagados, dizendo que nao ha o que
  /// marcar.
  AlvoDoRail _alvoDaCategoria(WidgetRef ref, Duration tempo) {
    if (categoriaId == 'opacidade') {
      return alvoDaPropriedade(
        ref,
        camada,
        LayerProp.opacity,
        'Opacidade',
        tempo,
        playback,
      );
    }
    if (categoriaId == 'efeitos') {
      return alvoDoParametroDeEfeito(ref, camada, tempo);
    }
    if (categoriaId == 'forma') {
      return alvoDoParametroDaForma(ref, camada, tempo);
    }
    if (categoriaId == 'mascara') {
      return alvoDoParametroDaMascara(ref, camada, tempo);
    }
    return const AlvoDoRail();
  }
}

/// A propriedade que cada modo de transformacao anima.
LayerProp propDoModo(ModoDeTransformacao m) => switch (m) {
  ModoDeTransformacao.mover => LayerProp.position,
  ModoDeTransformacao.girar => LayerProp.rotation,
  ModoDeTransformacao.escalar => LayerProp.scale,
  ModoDeTransformacao.inclinar => LayerProp.skew,
};

String nomeDoModo(ModoDeTransformacao m) => switch (m) {
  ModoDeTransformacao.mover => 'Posicao',
  ModoDeTransformacao.girar => 'Rotacao',
  ModoDeTransformacao.escalar => 'Escala',
  ModoDeTransformacao.inclinar => 'Inclinacao',
};

/// A moldura das ferramentas que nao tem rail direito.
class _ComRail extends StatelessWidget {
  const _ComRail({
    required this.aoVoltar,
    required this.alvo,
    required this.child,
  });

  final VoidCallback aoVoltar;
  final AlvoDoRail alvo;
  final Widget child;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      RailEsquerdo(aoVoltar: aoVoltar, alvo: alvo),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(4, 6, 12, 12),
          child: child,
        ),
      ),
    ],
  );
}

/// O RELOGIO, disponivel para quem esta fundo na arvore.
///
/// Os controles precisam dele, e passa-lo a mao por cinco niveis de
/// widget so para chegar num campo era ruido em toda assinatura do
/// caminho.
class ProvedorDoRelogio extends InheritedWidget {
  const ProvedorDoRelogio({
    super.key,
    required this.playback,
    required super.child,
  });

  final PlaybackController playback;

  static PlaybackController of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ProvedorDoRelogio>()!
      .playback;

  @override
  bool updateShouldNotify(ProvedorDoRelogio o) => o.playback != playback;
}

/// O ALVO DO RAIL para uma propriedade de transformacao.
///
/// Junta as duas coisas que o rail faz — marcar keyframe e abrir a
/// curva — porque as duas saem da MESMA lista de instantes. Separadas,
/// cada uma percorreria a lista de novo.
AlvoDoRail alvoDaPropriedade(
  WidgetRef ref,
  Layer camada,
  LayerProp prop,
  String titulo,
  Duration tempo,
  PlaybackController playback,
) {
  final c = ref.read(editorControllerProvider.notifier);
  final locais = c.propKeyframeTimes(camada, prop);
  final local = camada.localTime(tempo);
  // O LOSANGO TEM DE DIZER O QUE O TOQUE VAI FAZER.
  //
  // Ele comparava o instante EXATO com a lista, e o `toggleKeyframe` do
  // motor usa a tolerancia da propria trilha. Com o cabecote a alguns
  // milissegundos de uma marca, o rail mostrava "marcar aqui" e o toque
  // APAGAVA a marca existente. Perguntar a mesma trilha que vai
  // responder acaba com a discordancia.
  final temAqui = switch (prop) {
    LayerProp.position => camada.position.hasKeyframeAt(local),
    LayerProp.scale => camada.scaleX.hasKeyframeAt(local),
    LayerProp.rotation => camada.rotation.hasKeyframeAt(local),
    LayerProp.opacity => camada.opacity.hasKeyframeAt(local),
    LayerProp.skew => camada.skewX.hasKeyframeAt(local),
    LayerProp.pivot => camada.pivot.hasKeyframeAt(local),
    LayerProp.parent => false,
  };

  Duration? inicioDoTrecho;
  Duration? depois;
  for (final t in locais) {
    if (t <= local) inicioDoTrecho = t;
    if (t > local && depois == null) depois = t;
  }
  // O TRECHO E O QUE COMECA NA MARCA ANTERIOR e acaba na proxima. Curva
  // pertence ao TRECHO, e nao ao ponto: e o caminho entre duas marcas
  // que acelera ou freia.
  final temTrecho = inicioDoTrecho != null && depois != null;
  final comeca = inicioDoTrecho ?? Duration.zero;

  final atual = switch (prop) {
    LayerProp.position => camada.position.easeAt(comeca),
    LayerProp.scale => camada.scaleX.easeAt(comeca),
    LayerProp.rotation => camada.rotation.easeAt(comeca),
    LayerProp.opacity => camada.opacity.easeAt(comeca),
    LayerProp.skew => camada.skewX.easeAt(comeca),
    LayerProp.pivot => camada.pivot.easeAt(comeca),
    LayerProp.parent => Easing.linear,
  };

  return AlvoDoRail(
    temKeyframeAqui: temAqui,
    animado: locais.isNotEmpty,
    aoAlternarKeyframe: () => c.toggleKeyframe(camada.id, tempo, prop),
    aoAbrirCurva: !temTrecho
        ? null
        : () => ref.read(curvaEmEdicaoProvider.notifier).state = CurvaEmEdicao(
            titulo: titulo,
            atual: atual,
            aoAplicar: (e) => c.setSegmentEase(camada.id, prop, comeca, e),
            aoAplicarEmTodos: locais.length > 2
                ? (e) => c.applyEaseToAllSegments(camada.id, prop, e)
                : null,
          ),
  );
}

/// QUAL EFEITO ESTA ABERTO, e qual parametro dele o rail mira.
final efeitoAbertoProvider = StateProvider<String?>((ref) => null);
final parametroAbertoProvider = StateProvider<String?>((ref) => null);
final catalogoDeEfeitosProvider = StateProvider<bool>((ref) => false);

/// O ALVO DO RAIL quando a ferramenta aberta e a de efeitos.
AlvoDoRail alvoDoParametroDeEfeito(
  WidgetRef ref,
  Layer camada,
  Duration tempo,
) {
  final idEfeito = ref.watch(efeitoAbertoProvider);
  final chave = ref.watch(parametroAbertoProvider);
  if (idEfeito == null || chave == null) return const AlvoDoRail();
  final efeito = camada.effects.where((e) => e.id == idEfeito).firstOrNull;
  final trilha = efeito?.params[chave];
  if (efeito == null || trilha == null) return const AlvoDoRail();

  final c = ref.read(editorControllerProvider.notifier);
  final local = camada.localTime(tempo);

  return AlvoDoRail(
    temKeyframeAqui: trilha.hasKeyframeAt(local),
    animado: trilha.isAnimated,
    aoAlternarKeyframe: () =>
        c.toggleEffectParamKeyframe(camada.id, efeito.id, chave, tempo),
    // O EFEITO NAO TEM CURVA POR TRECHO no motor de hoje: o comando que
    // existe e por keyframe da trilha, e nao por segmento. Prometer a
    // curva aqui abriria um editor sem onde escrever.
    aoAbrirCurva: null,
  );
}

/// O ALVO DO RAIL quando a ferramenta aberta e a de forma.
///
/// Sem isto, tocar numa linha da forma acendia o realce de "escolhida" e
/// o losango do rail continuava apagado: o gesto prometia mirar e nao
/// mirava nada. Em Opacidade e em Efeitos ele mira; aqui tinha de mirar
/// tambem.
AlvoDoRail alvoDoParametroDaForma(
  WidgetRef ref,
  Layer camada,
  Duration tempo,
) {
  if (camada is! ShapeLayer) return const AlvoDoRail();
  final chave = ref.watch(parametroAbertoProvider);
  if (chave == null) return const AlvoDoRail();
  final s = camada.contents.whereType<ShapeParametric>().firstOrNull;
  final trilha = s == null ? null : shapeParamTrackOf(s, chave);
  if (trilha == null) return const AlvoDoRail();

  final c = ref.read(editorControllerProvider.notifier);
  final local = camada.localTime(tempo);
  return AlvoDoRail(
    temKeyframeAqui: trilha.hasKeyframeAt(local),
    animado: trilha.isAnimated,
    aoAlternarKeyframe: () =>
        c.toggleShapeParamKeyframe(camada.id, chave, tempo),
    // COMO NO EFEITO, a curva do desenho ainda nao tem comando por
    // trecho no motor: o que existe e por keyframe da trilha. Abrir o
    // editor daria uma curva sem onde escrever.
    aoAbrirCurva: null,
  );
}

class _Opacidade extends ConsumerWidget {
  const _Opacidade({required this.camada, required this.tempo});

  final Layer camada;
  final Duration tempo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(editorControllerProvider.notifier);
    final local = camada.localTime(tempo);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinhaDeParametro(
          rotulo: 'Opacidade',
          valor: camada.opacity.valueAt(local) * 100,
          casas: 0,
          sufixo: '%',
          porPixel: .4,
          escolhida: true,
          aoComecar: c.beginGesture,
          aoMudar: (v) => c.editOpacity(camada.id, tempo, v / 100),
          aoTerminar: c.endGesture,
          aoDigitar: (v) => c.editOpacity(camada.id, tempo, v / 100),
        ),
        const _AutoKeyframe(),
      ],
    );
  }
}

/// O INTERRUPTOR DO KEYFRAME AUTOMATICO.
///
/// A referencia nao tem: la o losango do rail e o unico caminho, e cada
/// marca e cravada a mao. O Aurea ja tinha o automatico antes desta
/// reforma, e tirar seria tirar funcao — entao ele fica, mas EMBAIXO do
/// controle, e nao em cima: quem edita quer mexer no valor primeiro.
class _AutoKeyframe extends ConsumerWidget {
  const _AutoKeyframe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ligado = ref.watch(autoKeyframeProvider);
    return _Interruptor(
      rotulo: 'Keyframe automatico',
      icone: ligado
          ? Icons.check_box_rounded
          : Icons.check_box_outline_blank_rounded,
      ligado: ligado,
      aoTocar: () => ref.read(autoKeyframeProvider.notifier).state = !ligado,
    );
  }
}

class _Texto extends ConsumerStatefulWidget {
  const _Texto({required this.camada});

  final Layer camada;

  @override
  ConsumerState<_Texto> createState() => _TextoState();
}

class _TextoState extends ConsumerState<_Texto> {
  late final TextEditingController _campo = TextEditingController(
    text: (widget.camada as TextLayer).text,
  );

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.camada as TextLayer;
    final c = ref.read(editorControllerProvider.notifier);
    // O CAMPO SO E REESCRITO QUANDO O TEXTO MUDOU POR FORA (desfazer,
    // troca de camada). Reescrever a cada quadro jogaria o cursor para o
    // fim no meio da digitacao.
    if (_campo.text != l.text) _campo.text = l.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TextField(
            controller: _campo,
            maxLines: 3,
            minLines: 1,
            style: const TextStyle(fontSize: 13, color: AmColors.text),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AmColors.chip,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              hintText: 'Seu texto',
              hintStyle: const TextStyle(color: AmColors.muted),
            ),
            onChanged: (t) => c.editTextLayer(l.id, text: t),
          ),
        ),
        LinhaDeParametro(
          rotulo: 'Tamanho',
          valor: l.fontSize,
          casas: 0,
          porPixel: .5,
          escolhida: true,
          aoComecar: c.beginGesture,
          aoMudar: (v) => c.editTextLayer(l.id, fontSize: v),
          aoTerminar: c.endGesture,
          aoDigitar: (v) => c.editTextLayer(l.id, fontSize: v),
        ),
        _Interruptor(
          rotulo: 'Negrito',
          icone: Icons.format_bold_rounded,
          ligado: l.bold,
          aoTocar: () => c.editTextLayer(l.id, bold: !l.bold),
        ),
      ],
    );
  }
}

class _Forma extends ConsumerWidget {
  const _Forma({required this.camada, required this.tempo});

  final Layer camada;
  final Duration tempo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = camada as ShapeLayer;
    final c = ref.read(editorControllerProvider.notifier);
    final local = l.localTime(tempo);
    final escolhida = ref.watch(parametroAbertoProvider);
    // O PRIMEIRO PARAMETRICO E O QUE O PAINEL EDITA. Uma camada de forma
    // pode ter varios desenhos dentro; o menu de adicao cria uma com um.
    // Quem tiver mais de um ve o aviso, em vez de o painel escolher em
    // silencio.
    final formas = l.contents.whereType<ShapeParametric>().toList();
    if (formas.isEmpty) {
      return const _Aviso('Esta camada nao tem forma parametrica para ajustar.');
    }
    final s = formas.first;

    // SO OS PARAMETROS QUE ESTA FORMA USA.
    //
    // A ficha mostrava os sete para toda forma, e numa estrela
    // 'Largura' e 'Altura' escreviam no projeto sem mudar nada na tela:
    // o desenho da estrela sai de raio e pontas. Um controle que aceita
    // o dedo e nao faz nada e pior que um controle ausente — o ausente
    // manda procurar noutro lugar, o inerte manda desconfiar do app.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (formas.length > 1)
          const _Aviso('Ajustando o primeiro desenho desta camada.'),
        for (final chave in parametrosDaForma(s.kind))
          if (shapeParamTrackOf(s, chave) case final trilha?)
            LinhaDeParametro(
              rotulo: fichaDoParametroDaForma(chave).rotulo,
              valor: trilha.valueAt(local),
              casas: 0,
              porPixel: fichaDoParametroDaForma(chave).teto / 300,
              escolhida: escolhida == chave,
              aoEscolher: () =>
                  ref.read(parametroAbertoProvider.notifier).state = chave,
              aoComecar: c.beginGesture,
              aoMudar: (v) => c.editShapeParam(l.id, chave, tempo, v),
              aoTerminar: c.endGesture,
              aoDigitar: (v) => c.editShapeParam(l.id, chave, tempo, v),
            ),
      ],
    );
  }
}

/// OS EFEITOS DA CAMADA.
///
/// A ficha de cada efeito e GERADA da tabela `effectSpecs`, e nao escrita
/// a mao. Sao mais de cinquenta efeitos com parametros proprios; uma tela
/// por efeito seria cinquenta telas para manter em dia, e a primeira que
/// alguem esquecesse viraria um controle que nao bate com o motor.
class _Efeitos extends ConsumerWidget {
  const _Efeitos({required this.camada, required this.tempo});

  final Layer camada;
  final Duration tempo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(catalogoDeEfeitosProvider)) {
      return _CatalogoDeEfeitos(camada: camada);
    }
    final c = ref.read(editorControllerProvider.notifier);
    final aberto = ref.watch(efeitoAbertoProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (camada.effects.isEmpty)
          const _Aviso('Esta camada ainda nao tem efeito nenhum.'),
        for (final e in camada.effects) ...[
          _TituloDoEfeito(
            efeito: e,
            aberto: e.id == aberto,
            aoAbrir: () => ref.read(efeitoAbertoProvider.notifier).state =
                e.id == aberto ? null : e.id,
            aoAlternar: () => c.toggleEffectEnabled(camada.id, e.id),
            aoRemover: () {
              ref.read(efeitoAbertoProvider.notifier).state = null;
              c.removeEffect(camada.id, e.id);
            },
          ),
          if (e.id == aberto)
            _ParametrosDoEfeito(camada: camada, efeito: e, tempo: tempo),
        ],
        _Acao(
          icone: Icons.add_rounded,
          rotulo: 'Adicionar efeito',
          aoTocar: () =>
              ref.read(catalogoDeEfeitosProvider.notifier).state = true,
        ),
      ],
    );
  }
}

/// O titulo do cartao: recolher, ligar, tirar.
class _TituloDoEfeito extends StatelessWidget {
  const _TituloDoEfeito({
    required this.efeito,
    required this.aberto,
    required this.aoAbrir,
    required this.aoAlternar,
    required this.aoRemover,
  });

  final EffectInstance efeito;
  final bool aberto;
  final VoidCallback aoAbrir;
  final VoidCallback aoAlternar;
  final VoidCallback aoRemover;

  @override
  Widget build(BuildContext context) {
    final nome = effectSpecs[efeito.type]?.name ?? efeito.type.name;
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              container: true,
              excludeSemantics: true,
              button: true,
              label: nome,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: aoAbrir,
                child: Row(
                  children: [
                    Icon(
                      aberto
                          ? Icons.arrow_drop_down_rounded
                          : Icons.arrow_right_rounded,
                      size: 22,
                      color: AmColors.text,
                    ),
                    Expanded(
                      child: Text(
                        nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: efeito.enabled
                              ? AmColors.text
                              : AmColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _IconeDoTitulo(
            icone: efeito.enabled
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded,
            rotulo: efeito.enabled ? 'Desligar $nome' : 'Ligar $nome',
            aoTocar: aoAlternar,
            aceso: efeito.enabled,
          ),
          _IconeDoTitulo(
            icone: Icons.delete_outline_rounded,
            rotulo: 'Tirar $nome',
            aoTocar: aoRemover,
          ),
        ],
      ),
    );
  }
}

class _IconeDoTitulo extends StatelessWidget {
  const _IconeDoTitulo({
    required this.icone,
    required this.rotulo,
    required this.aoTocar,
    this.aceso = false,
  });

  final IconData icone;
  final String rotulo;
  final VoidCallback aoTocar;
  final bool aceso;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    label: rotulo,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aoTocar,
      child: SizedBox(
        width: 34,
        height: 40,
        child: Icon(
          icone,
          size: 17,
          color: aceso ? AmColors.text : AmColors.muted,
        ),
      ),
    ),
  );
}

class _ParametrosDoEfeito extends ConsumerWidget {
  const _ParametrosDoEfeito({
    required this.camada,
    required this.efeito,
    required this.tempo,
  });

  final Layer camada;
  final EffectInstance efeito;
  final Duration tempo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(editorControllerProvider.notifier);
    final spec = effectSpecs[efeito.type];
    if (spec == null) return const SizedBox.shrink();
    final local = camada.localTime(tempo);
    final escolhida = ref.watch(parametroAbertoProvider);
    final semDesenho = <String>[];
    final campos = <Widget>[];

    for (final entrada in spec.params.entries) {
      final chave = entrada.key;
      final def = entrada.value;
      final trilha = efeito.params[chave];
      if (trilha == null) continue;
      switch (def.kind) {
        case ParamKind.number:
        case ParamKind.seed:
          final faixa = (def.max - def.min).abs();
          campos.add(
            LinhaDeParametro(
              rotulo: def.label,
              valor: trilha.valueAt(local),
              // A FAIXA DA TABELA VIRA PASSO, e nao limite: atravessar a
              // fita uma vez cobre o intervalo util, seja ele 0..1 ou
              // 0..4000.
              porPixel: faixa / 300,
              // AS CASAS SAEM DA FAIXA, em escada.
              //
              // A regra era "faixa <= 4 ? 3 : 0", e ela mentia no meio:
              // exposicao vai de -3 a +3, faixa 6, e caia em ZERO casa —
              // o numero ficava parado em "0" enquanto o dedo arrastava.
              // Uma escada cobre os dois extremos sem buraco no meio.
              casas: casasParaFaixa(faixa),
              escolhida: escolhida == chave,
              aoEscolher: () =>
                  ref.read(parametroAbertoProvider.notifier).state = chave,
              aoComecar: c.beginGesture,
              aoMudar: (v) =>
                  c.editEffectParam(camada.id, efeito.id, chave, tempo, v),
              aoTerminar: c.endGesture,
              aoDigitar: (v) =>
                  c.editEffectParam(camada.id, efeito.id, chave, tempo, v),
            ),
          );
        case ParamKind.toggle:
          campos.add(
            _Interruptor(
              rotulo: def.label,
              icone: trilha.valueAt(local) >= .5
                  ? Icons.toggle_on_rounded
                  : Icons.toggle_off_rounded,
              ligado: trilha.valueAt(local) >= .5,
              aoTocar: () => c.editEffectParam(
                camada.id,
                efeito.id,
                chave,
                tempo,
                trilha.valueAt(local) >= .5 ? 0 : 1,
              ),
            ),
          );
        case ParamKind.choice:
          campos.add(
            _Escolha(
              rotulo: def.label,
              opcoes: def.options,
              escolhido: trilha.valueAt(local).round(),
              aoEscolher: (i) => c.editEffectParam(
                camada.id,
                efeito.id,
                chave,
                tempo,
                i.toDouble(),
              ),
            ),
          );
        case ParamKind.point:
          // PONTO E DOIS NUMEROS, e a tabela ja os separa em "Centro X"
          // e "Centro Y" com faixa 0..1. Eles caiam no balde do "ainda
          // nao desenha" sem motivo: sao numeros comuns, e como numeros
          // comuns ganham fita, campo e o losango do rail.
          //
          // Uma cruz arrastavel EM CIMA DA PREVIA seria melhor, e e o
          // que a referencia faz — mas o palco ainda nao tem gesto
          // nenhum, e prometer a cruz aqui seria prometer o palco.
          final faixaP = (def.max - def.min).abs();
          campos.add(
            LinhaDeParametro(
              rotulo: def.label,
              valor: trilha.valueAt(local),
              porPixel: faixaP / 300,
              casas: casasParaFaixa(faixaP),
              escolhida: escolhida == chave,
              aoEscolher: () =>
                  ref.read(parametroAbertoProvider.notifier).state = chave,
              aoComecar: c.beginGesture,
              aoMudar: (v) =>
                  c.editEffectParam(camada.id, efeito.id, chave, tempo, v),
              aoTerminar: c.endGesture,
              aoDigitar: (v) =>
                  c.editEffectParam(camada.id, efeito.id, chave, tempo, v),
            ),
          );
        case ParamKind.color:
          semDesenho.add(def.label);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...campos,
          // A COR AGORA MUDA. A linha mostrava os tres numeros e a
          // amostra e nao deixava trocar — metade da pergunta
          // respondida, com `setEffectColor` parado no motor sem um
          // unico chamador.
          if (spec.hasColor)
            EscolhaDeCor(
              rotulo: 'Cor',
              cor: efeito.color,
              aoComecar: c.beginGesture,
              aoTerminar: c.endGesture,
              aoMudar: (cor) => c.setEffectColor(camada.id, efeito.id, cor),
            ),
          for (var i = 0; i < spec.extraColors; i++)
            EscolhaDeCor(
              rotulo: 'Cor ${i + 2}',
              cor: efeito.extraColor(i),
              aoComecar: c.beginGesture,
              aoTerminar: c.endGesture,
              aoMudar: (cor) =>
                  c.setEffectExtraColor(camada.id, efeito.id, i, cor),
            ),
          // O QUE ESTA FICHA AINDA NAO DESENHA, DITO. Um parametro que
          // some sem explicacao faz o efeito inteiro parecer quebrado.
          if (semDesenho.isNotEmpty)
            _Aviso(
              '${semDesenho.join(", ")}: ajuste chega numa proxima entrega.',
            ),
        ],
      ),
    );
  }
}

/// A linha de cor: os tres numeros e o quadradinho.
/// QUANTAS CASAS DECIMAIS um parametro daquela faixa precisa.
///
/// Poucas casas escondem o movimento; muitas enchem a caixa de digitos
/// que nao mudam. A escada da a cada faixa a precisao que ela usa.
///
/// Publica porque ha teste em cima dela: a regra velha mentia no meio
/// da escala, e o teste existe para nao mentir de novo.
int casasParaFaixa(double faixa) {
  if (faixa <= 2) return 3;
  if (faixa <= 20) return 2;
  if (faixa <= 200) return 1;
  return 0;
}

/// Um parametro de lista: as opcoes viram chips.
class _Escolha extends StatelessWidget {
  const _Escolha({
    required this.rotulo,
    required this.opcoes,
    required this.escolhido,
    required this.aoEscolher,
  });

  final String rotulo;
  final List<String> opcoes;
  final int escolhido;
  final void Function(int) aoEscolher;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          rotulo,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AmColors.text,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < opcoes.length; i++)
              Semantics(
                container: true,
                excludeSemantics: true,
                button: true,
                selected: i == escolhido,
                label: opcoes[i],
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => aoEscolher(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: i == escolhido
                          ? AmColors.accentDim
                          : AmColors.chip,
                      borderRadius: BorderRadius.circular(8),
                      border: i == escolhido
                          ? Border.all(color: AmColors.accent)
                          : null,
                    ),
                    child: Text(
                      opcoes[i],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: i == escolhido
                            ? AmColors.accent
                            : AmColors.text,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    ),
  );
}

/// O CATALOGO, agrupado pela categoria que a propria tabela declara.
class _CatalogoDeEfeitos extends ConsumerWidget {
  const _CatalogoDeEfeitos({required this.camada});

  final Layer camada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(editorControllerProvider.notifier);
    final porCategoria = <String, List<EffectType>>{};
    for (final e in effectSpecs.entries) {
      porCategoria.putIfAbsent(e.value.category, () => []).add(e.key);
    }
    final categorias = porCategoria.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Acao(
          icone: Icons.arrow_back_ios_new_rounded,
          rotulo: 'Voltar aos efeitos da camada',
          aoTocar: () =>
              ref.read(catalogoDeEfeitosProvider.notifier).state = false,
        ),
        for (final cat in categorias) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 0, 6),
            child: Text(
              cat,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AmColors.muted,
              ),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in porCategoria[cat]!)
                Semantics(
                  container: true,
                  excludeSemantics: true,
                  button: true,
                  label: effectSpecs[t]!.name,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      c.addEffect(camada.id, t);
                      ref.read(catalogoDeEfeitosProvider.notifier).state =
                          false;
                      // O EFEITO NOVO ABRE JA COM A FICHA A VISTA, e com
                      // o primeiro parametro escolhido: quem acabou de
                      // escolher quer ajustar, e nao procurar de novo o
                      // que acabou de adicionar.
                      final novo = ref
                          .read(editorControllerProvider)
                          .layers
                          .firstWhere((l) => l.id == camada.id)
                          .effects
                          .last;
                      ref.read(efeitoAbertoProvider.notifier).state = novo.id;
                      ref.read(parametroAbertoProvider.notifier).state =
                          effectSpecs[t]!.params.keys.firstOrNull;
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AmColors.chip,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        effectSpecs[t]!.name,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AmColors.text,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Midia extends StatelessWidget {
  const _Midia({required this.camada});

  final Layer camada;

  @override
  Widget build(BuildContext context) {
    final caminho = switch (camada) {
      ImageLayer(:final sourcePath) => sourcePath,
      VideoLayer(:final sourcePath) => sourcePath,
      AudioLayer(:final sourcePath) => sourcePath,
      _ => null,
    };
    final arquivo = caminho?.split(RegExp(r'[\\/]')).last ?? '—';
    String tempo(Duration d) =>
        '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:'
        '${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Linha(rotulo: 'Arquivo', valor: arquivo),
        _Linha(rotulo: 'Duracao', valor: tempo(camada.duration)),
        _Linha(rotulo: 'Entra em', valor: tempo(camada.startTime)),
      ],
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({required this.rotulo, required this.valor});

  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            rotulo,
            style: const TextStyle(fontSize: 12, color: AmColors.muted),
          ),
        ),
        Expanded(
          child: Text(
            valor,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AmColors.text,
            ),
          ),
        ),
      ],
    ),
  );
}

/// AS ACOES QUE MUDAM A CAMADA INTEIRA.
///
/// Elas nao sao propriedade — sao o que se faz COM a camada — e por isso
/// tem categoria propria em vez de virarem mais uma linha no meio dos
/// parametros.
/// A CAMADA ESTA ESCOLHENDO UM PAI?
///
/// Um estado da propria categoria "Camada", e nao um painel novo: o
/// painel tem 300 px e ja sobrepoe a previa, e uma segunda folha por
/// cima taparia justamente a composicao onde se ve o resultado do
/// vinculo.
final escolhendoPaiProvider = StateProvider<bool>((ref) => false);

class _AcoesDaCamada extends ConsumerWidget {
  const _AcoesDaCamada({required this.camada, required this.playback});

  final Layer camada;
  final PlaybackController playback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(editorControllerProvider.notifier);
    final agora = playback.time.value;
    if (ref.watch(escolhendoPaiProvider)) {
      return _EscolhaDePai(camada: camada, playback: playback);
    }
    // DIVIDIR SO FAZ SENTIDO COM O CABECOTE DENTRO DA CAMADA. Fora dela
    // nao ha o que cortar, e um corte na borda produziria uma camada de
    // duracao zero.
    final podeDividir = agora > camada.startTime && agora < camada.endTime;
    final meta = ref.watch(editorControllerProvider).metaOf(camada.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // SOLO E TRAVA ESTAVAM PRONTOS NO MOTOR E SEM PORTA NENHUMA.
        //
        // `toggleSolo` e `toggleLocked` existem, sao salvos no arquivo e
        // o `rendersInPreview` ja respeita o solo — mas nenhum widget
        // chamava. Ficam aqui, e nao na pilula: a pilula tem 62 px e
        // dois alvos; um terceiro e um quarto la dentro seriam alvos que
        // o dedo erra. Aqui sao linhas inteiras.
        _Interruptor(
          rotulo: meta.solo ? 'So esta camada (solo ligado)' : 'Ouvir e ver so esta',
          icone: meta.solo
              ? Icons.headphones_rounded
              : Icons.headphones_outlined,
          ligado: meta.solo,
          aoTocar: () => c.toggleSolo(camada.id),
        ),
        _Interruptor(
          rotulo: meta.locked ? 'Destravar a camada' : 'Travar a camada',
          icone: meta.locked ? Icons.lock_rounded : Icons.lock_open_rounded,
          ligado: meta.locked,
          aoTocar: () => c.toggleLocked(camada.id),
        ),
        _Acao(
          icone: Icons.content_cut_rounded,
          rotulo: 'Dividir no cabecote',
          porQueNao: podeDividir
              ? null
              : 'Leve o cabecote para dentro da camada',
          aoTocar: () => c.splitLayer(camada.id, agora),
        ),
        _Acao(
          icone: Icons.copy_all_rounded,
          rotulo: 'Duplicar',
          aoTocar: () => c.duplicarCamada(camada.id),
        ),
        // O PAI, O GRUPO E A ENTRADA NO GRUPO estavam prontos no motor e
        // sem porta nenhuma: `linkProperty(..., LayerProp.parent, ...)`,
        // `groupLayer`, `enterGroup` e `exitGroup` — nenhum com um unico
        // chamador na interface.
        _Pai(camada: camada),
        if (camada is GroupLayer)
          _Acao(
            icone: Icons.login_rounded,
            rotulo: 'Entrar no grupo',
            aoTocar: () {
              fecharFerramenta(ref);
              c.enterGroup(camada.id);
            },
          )
        else
          _Acao(
            icone: Icons.folder_open_rounded,
            rotulo: 'Agrupar',
            aoTocar: () => c.groupLayer(camada.id),
          ),
        _Acao(
          icone: Icons.delete_outline_rounded,
          rotulo: 'Apagar',
          perigo: true,
          aoTocar: () => c.removeLayer(camada.id),
        ),
      ],
    );
  }
}

/// QUEM ESTA CAMADA SEGUE.
///
/// Parentesco e o comando que troca "mover cinco camadas juntas" por
/// "mover o nulo". Ele existia inteiro — `linkProperty` captura o
/// transform EFETIVO do pai no instante do vinculo, entao nada pula na
/// hora de parear — e nao tinha porta.
class _Pai extends ConsumerWidget {
  const _Pai({required this.camada});

  final Layer camada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projeto = ref.watch(editorControllerProvider);
    final vinculo = projeto.linkFor(camada.id, LayerProp.parent);
    final pai = vinculo == null
        ? null
        : projeto.layers.where((l) => l.id == vinculo.sourceLayerId).firstOrNull;
    if (pai == null) {
      return _Acao(
        icone: Icons.link_rounded,
        rotulo: 'Seguir outra camada',
        porQueNao: projeto.layers.length < 2
            ? 'E preciso ter outra camada para seguir'
            : null,
        aoTocar: () => ref.read(escolhendoPaiProvider.notifier).state = true,
      );
    }
    return Row(
      children: [
        Expanded(
          child: _Acao(
            icone: Icons.link_rounded,
            rotulo: 'Segue "${pai.name}"',
            aoTocar: () => ref.read(escolhendoPaiProvider.notifier).state = true,
          ),
        ),
        Semantics(
          container: true,
          excludeSemantics: true,
          button: true,
          label: 'Parar de seguir',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => ref
                .read(editorControllerProvider.notifier)
                .unlinkProperty(camada.id, LayerProp.parent),
            child: const SizedBox(
              width: 40,
              height: 44,
              child: Icon(
                Icons.link_off_rounded,
                size: 18,
                color: AmColors.muted,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A LISTA DE CANDIDATOS A PAI.
///
/// Toda camada da cena, menos ela mesma. O motor recusa o ciclo direto
/// (`targetId == sourceId`), e a cadeia longa e resolvida por
/// `effectiveTransform`, que ja anda pelo pai do pai.
class _EscolhaDePai extends ConsumerWidget {
  const _EscolhaDePai({required this.camada, required this.playback});

  final Layer camada;
  final PlaybackController playback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projeto = ref.watch(editorControllerProvider);
    final c = ref.read(editorControllerProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Acao(
          icone: Icons.arrow_back_rounded,
          rotulo: 'Voltar',
          aoTocar: () => ref.read(escolhendoPaiProvider.notifier).state = false,
        ),
        for (final l in projeto.layers)
          if (l.id != camada.id)
            _Acao(
              icone: Icons.subdirectory_arrow_right_rounded,
              rotulo: l.name,
              aoTocar: () {
                c.linkProperty(
                  camada.id,
                  LayerProp.parent,
                  l.id,
                  playback.time.value,
                );
                ref.read(escolhendoPaiProvider.notifier).state = false;
              },
            ),
      ],
    );
  }
}

class _Acao extends StatelessWidget {
  const _Acao({
    required this.icone,
    required this.rotulo,
    required this.aoTocar,
    this.porQueNao,
    this.perigo = false,
  });

  final IconData icone;
  final String rotulo;
  final VoidCallback aoTocar;
  final String? porQueNao;
  final bool perigo;

  @override
  Widget build(BuildContext context) {
    final ativo = porQueNao == null;
    final cor = !ativo
        ? AmColors.muted.withValues(alpha: .5)
        : perigo
        ? AmColors.pink
        : AmColors.text;
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: ativo,
      enabled: ativo,
      label: rotulo,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: ativo ? aoTocar : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              const SizedBox(width: 6),
              Icon(icone, size: 19, color: cor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rotulo,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cor,
                      ),
                    ),
                    // O MOTIVO FICA NA LINHA. Um controle apagado sem
                    // explicacao vira suspeita de defeito.
                    if (porQueNao != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          porQueNao!,
                          style: TextStyle(
                            fontSize: 10,
                            color: AmColors.muted.withValues(alpha: .6),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Um interruptor de linha, para o que liga e desliga sem ser valor.
class _Interruptor extends StatelessWidget {
  const _Interruptor({
    required this.rotulo,
    required this.icone,
    required this.ligado,
    required this.aoTocar,
  });

  final String rotulo;
  final IconData icone;
  final bool ligado;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: true,
    toggled: ligado,
    label: rotulo,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aoTocar,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            const SizedBox(width: 6),
            Icon(
              icone,
              size: 18,
              color: ligado ? AmColors.accent : AmColors.muted,
            ),
            const SizedBox(width: 10),
            Text(
              rotulo,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: ligado ? AmColors.text : AmColors.muted,
              ),
            ),
          ],
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
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      texto,
      style: const TextStyle(fontSize: 11, color: AmColors.muted, height: 1.4),
    ),
  );
}

class _AindaNao extends StatelessWidget {
  const _AindaNao();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 10),
    child: Text(
      'Os controles desta categoria chegam numa proxima entrega.',
      key: ValueKey('categoria-sem-controles'),
      style: TextStyle(fontSize: 12, color: AmColors.muted, height: 1.4),
    ),
  );
}
