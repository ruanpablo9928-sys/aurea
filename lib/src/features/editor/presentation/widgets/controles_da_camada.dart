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

/// OS CONTROLES DE VERDADE.
///
/// Ate aqui o painel era estrutura: as categorias existiam, abriam e nao
/// faziam nada. Este arquivo liga cada uma ao comando do
/// `EditorController` que ja existia — o motor nunca foi tocado, o que
/// faltava era a porta.
///
/// TRES REGRAS VALEM PARA TODO CONTROLE DAQUI:
///
///   1. UM GESTO, UM DESFAZER. O deslizante manda dezenas de valores
///      entre o toque e o solte; `beginGesture`/`endGesture` embrulham
///      todos num passo so. Sem isso, arrastar a opacidade e desfazer
///      devolvia um pedaco do movimento.
///   2. O VALOR E LIDO NO CABECOTE. Uma propriedade animada vale coisas
///      diferentes em instantes diferentes, e o que o controle mostra
///      tem de ser o que a previa mostra.
///   3. QUEM DECIDE SE VIRA KEYFRAME E O MOTOR. Com o keyframe
///      automatico ligado, editar crava a marca no cabecote; desligado,
///      muda o valor base. O controle nao sabe a diferenca, e nem
///      precisa.
/// O RELOGIO, disponivel para quem esta fundo na arvore.
///
/// Os controles precisam dele para navegar entre marcas, e passa-lo a
/// mao por cinco niveis de widget so para chegar num deslizante era
/// ruido em toda assinatura do caminho.
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

class ControlesDaCategoria extends ConsumerWidget {
  const ControlesDaCategoria({
    super.key,
    required this.categoriaId,
    required this.camada,
    required this.playback,
  });

  final String categoriaId;
  final Layer camada;
  final PlaybackController playback;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      ValueListenableBuilder<Duration>(
        valueListenable: playback.time,
        builder: (context, tempo, _) => ProvedorDoRelogio(
          playback: playback,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 16),
            child: switch (categoriaId) {
              'transformar' => _Transformar(camada: camada, tempo: tempo),
              'opacidade' => _Opacidade(camada: camada, tempo: tempo),
              'texto' => _Texto(camada: camada),
              'forma' => _Forma(camada: camada, tempo: tempo),
              'volume' => _Volume(camada: camada),
              'efeitos' => _Efeitos(camada: camada, tempo: tempo),
              'midia' => _Midia(camada: camada),
              'camada' => _AcoesDaCamada(camada: camada, playback: playback),
              _ => const _AindaNao(),
            },
          ),
        ),
      );
}

/// O INTERRUPTOR DO KEYFRAME AUTOMATICO.
///
/// Fica no topo das categorias que animam, e nao escondido em ajustes:
/// e a diferenca entre "mudar a camada" e "animar a camada", e quem
/// edita precisa ver em qual dos dois modos esta ANTES de mexer.
class _AutoKeyframe extends ConsumerWidget {
  const _AutoKeyframe();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ligado = ref.watch(autoKeyframeProvider);
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      toggled: ligado,
      label: 'Keyframe automatico',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            ref.read(autoKeyframeProvider.notifier).state = !ligado,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(
                ligado
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 18,
                color: ligado ? AmColors.accent : AmColors.muted,
              ),
              const SizedBox(width: 8),
              Text(
                'Keyframe automatico',
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
}

/// O QUE UMA PROPRIEDADE ANIMADA OFERECE ALEM DO VALOR.
///
/// Sao tres coisas que so existem quando ha marca: pular para a marca
/// anterior, pular para a proxima, e abrir a curva do trecho em que o
/// cabecote esta. Montadas juntas porque as tres saem da MESMA lista de
/// instantes — separadas, cada uma percorreria a lista de novo.
({VoidCallback? anterior, VoidCallback? proximo, VoidCallback? curva})
navegacaoDaPropriedade(
  WidgetRef ref,
  Layer camada,
  LayerProp prop,
  String titulo,
  Duration tempo,
  PlaybackController playback,
) {
  final c = ref.read(editorControllerProvider.notifier);
  final locais = c.propKeyframeTimes(camada, prop);
  if (locais.isEmpty) {
    return (anterior: null, proximo: null, curva: null);
  }
  final local = camada.localTime(tempo);
  Duration? antes;
  Duration? depois;
  for (final t in locais) {
    if (t < local) antes = t;
    if (t > local && depois == null) depois = t;
  }

  // O TRECHO E O QUE COMECA NA MARCA ANTERIOR (ou na propria, se o
  // cabecote esta em cima dela). Curva pertence ao trecho, e nao ao
  // ponto: e o caminho ENTRE duas marcas que acelera ou freia.
  Duration? inicioDoTrecho;
  for (final t in locais) {
    if (t <= local) inicioDoTrecho = t;
  }
  final temTrecho = inicioDoTrecho != null && depois != null;
  // Promovido a nao-nulo para o fecho abaixo: o Dart nao carrega a
  // promocao de um campo local para dentro de uma lambda.
  final trechoComeca = inicioDoTrecho ?? Duration.zero;

  final trilha = switch (prop) {
    LayerProp.position => camada.position.easeAt(inicioDoTrecho ?? local),
    LayerProp.scale => camada.scaleX.easeAt(inicioDoTrecho ?? local),
    LayerProp.rotation => camada.rotation.easeAt(inicioDoTrecho ?? local),
    LayerProp.opacity => camada.opacity.easeAt(inicioDoTrecho ?? local),
    LayerProp.skew => camada.skewX.easeAt(inicioDoTrecho ?? local),
    LayerProp.pivot => camada.pivot.easeAt(inicioDoTrecho ?? local),
    LayerProp.parent => Easing.linear,
  };

  return (
    anterior: antes == null
        ? null
        : () => playback.seek(camada.startTime + antes!),
    proximo: depois == null
        ? null
        : () => playback.seek(camada.startTime + depois!),
    curva: !temTrecho
        ? null
        : () => ref.read(curvaEmEdicaoProvider.notifier).state = CurvaEmEdicao(
            titulo: titulo,
            atual: trilha,
            aoAplicar: (e) =>
                c.setSegmentEase(camada.id, prop, trechoComeca, e),
            aoAplicarEmTodos: locais.length > 2
                ? (e) => c.applyEaseToAllSegments(camada.id, prop, e)
                : null,
          ),
  );
}

/// UM PARAMETRO: nome, valor, deslizante e o losango do keyframe.
class ParametroDeslizante extends ConsumerStatefulWidget {
  const ParametroDeslizante({
    super.key,
    required this.rotulo,
    required this.valor,
    required this.minimo,
    required this.maximo,
    required this.aoMudar,
    this.formatar,
    this.aoAlternarKeyframe,
    this.temKeyframeAqui = false,
    this.animado = false,
    this.aoIrParaAnterior,
    this.aoIrParaProximo,
    this.aoAbrirCurva,
  });

  final String rotulo;
  final double valor;
  final double minimo;
  final double maximo;
  final void Function(double) aoMudar;
  final String Function(double)? formatar;

  /// Nulo quando a propriedade nao aceita keyframe.
  final VoidCallback? aoAlternarKeyframe;
  final bool temKeyframeAqui;
  final bool animado;

  /// SO EXISTEM QUANDO HA MARCA. Um controle aceso que nao leva a lugar
  /// nenhum ensina errado, e numa propriedade sem keyframe nao ha marca
  /// anterior, proxima nem trecho para curvar.
  final VoidCallback? aoIrParaAnterior;
  final VoidCallback? aoIrParaProximo;
  final VoidCallback? aoAbrirCurva;

  @override
  ConsumerState<ParametroDeslizante> createState() =>
      _ParametroDeslizanteState();
}

class _ParametroDeslizanteState extends ConsumerState<ParametroDeslizante> {
  /// O VALOR SOB O DEDO.
  ///
  /// Enquanto o dedo arrasta, quem manda no numero e ele — nao o
  /// projeto. Sao a mesma coisa em condicoes normais, mas nao quando o
  /// motor prende o valor (opacidade nao passa de 1) ou quando a
  /// propriedade tem expressao: ai o deslizante pularia de volta
  /// debaixo do dedo a cada quadro.
  double? _dedo;

  @override
  Widget build(BuildContext context) {
    final v = _dedo ?? widget.valor;
    final formatar = widget.formatar ?? (double x) => x.toStringAsFixed(0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (widget.aoAlternarKeyframe != null)
                Semantics(
                  container: true,
                  excludeSemantics: true,
                  button: true,
                  label: widget.temKeyframeAqui
                      ? 'Tirar keyframe de ${widget.rotulo}'
                      : 'Marcar keyframe de ${widget.rotulo}',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.aoAlternarKeyframe,
                    child: SizedBox(
                      width: 30,
                      height: 30,
                      child: Icon(
                        Icons.change_history_rounded,
                        size: 15,
                        color: widget.temKeyframeAqui
                            ? AmColors.accent
                            : widget.animado
                            ? AmColors.accent.withValues(alpha: .45)
                            : AmColors.muted.withValues(alpha: .55),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(width: 30),
              Expanded(
                child: Text(
                  widget.rotulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AmColors.text,
                  ),
                ),
              ),
              Text(
                formatar(v),
                style: const TextStyle(
                  fontSize: 12,
                  color: AmColors.muted,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              if (widget.animado) ...[
                _MiniBotao(
                  icone: Icons.keyboard_arrow_left_rounded,
                  rotulo: 'Marca anterior de ${widget.rotulo}',
                  aoTocar: widget.aoIrParaAnterior,
                ),
                _MiniBotao(
                  icone: Icons.keyboard_arrow_right_rounded,
                  rotulo: 'Proxima marca de ${widget.rotulo}',
                  aoTocar: widget.aoIrParaProximo,
                ),
                _MiniBotao(
                  icone: Icons.timeline_rounded,
                  rotulo: 'Curva de ${widget.rotulo}',
                  aoTocar: widget.aoAbrirCurva,
                ),
              ],
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              activeTrackColor: AmColors.accent,
              inactiveTrackColor: AmColors.chip,
              thumbColor: AmColors.text,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: v.clamp(widget.minimo, widget.maximo),
              min: widget.minimo,
              max: widget.maximo,
              // UM GESTO, UM DESFAZER: o grupo abre no toque e fecha no
              // solte, com todos os valores do meio dentro dele.
              onChangeStart: (x) {
                ref.read(editorControllerProvider.notifier).beginGesture();
                setState(() => _dedo = x);
              },
              onChanged: (x) {
                setState(() => _dedo = x);
                widget.aoMudar(x);
              },
              onChangeEnd: (x) {
                widget.aoMudar(x);
                ref.read(editorControllerProvider.notifier).endGesture();
                setState(() => _dedo = null);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Um alvo pequeno de 28 px, para os controles que acompanham o valor.
///
/// Vinte e oito e menos que o piso de 48, e aqui isso e aceitavel: sao
/// controles SECUNDARIOS, ao lado de um deslizante que ocupa a largura
/// inteira e e o alvo de verdade. Errar um deles custa um toque, e nao
/// uma edicao.
class _MiniBotao extends StatelessWidget {
  const _MiniBotao({
    required this.icone,
    required this.rotulo,
    required this.aoTocar,
  });

  final IconData icone;
  final String rotulo;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    excludeSemantics: true,
    button: aoTocar != null,
    enabled: aoTocar != null,
    label: rotulo,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aoTocar,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Icon(
          icone,
          size: 17,
          color: aoTocar == null
              ? AmColors.muted.withValues(alpha: .3)
              : AmColors.muted,
        ),
      ),
    ),
  );
}

/// A ESCALA ESTA TRAVADA em X e Y?
///
/// Travada e o padrao porque e o que quase toda edicao quer: aumentar
/// sem esticar. Destravar e a excecao, e por isso e um interruptor e nao
/// dois deslizantes sempre a vista.
final escalaUniformeProvider = StateProvider<bool>((ref) => true);

class _Transformar extends ConsumerWidget {
  const _Transformar({required this.camada, required this.tempo});

  final Layer camada;
  final Duration tempo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(editorControllerProvider.notifier);
    final projeto = ref.watch(editorControllerProvider);
    final local = camada.localTime(tempo);
    final pos = camada.position.valueAt(local);
    final piv = camada.pivot.valueAt(local);
    final w = projeto.outputWidth.toDouble();
    final h = projeto.outputHeight.toDouble();
    final uniforme = ref.watch(escalaUniformeProvider);
    final playback = ProvedorDoRelogio.of(context);

    /// Monta um deslizante ja com navegacao entre marcas e curva.
    ParametroDeslizante campo({
      required String rotulo,
      required double valor,
      required double minimo,
      required double maximo,
      required void Function(double) aoMudar,
      required LayerProp prop,
      required bool temAqui,
      required bool animado,
      String Function(double)? formatar,
    }) {
      final nav = navegacaoDaPropriedade(
        ref,
        camada,
        prop,
        rotulo,
        tempo,
        playback,
      );
      return ParametroDeslizante(
        rotulo: rotulo,
        valor: valor,
        minimo: minimo,
        maximo: maximo,
        formatar: formatar,
        aoMudar: aoMudar,
        aoAlternarKeyframe: () => c.toggleKeyframe(camada.id, tempo, prop),
        temKeyframeAqui: temAqui,
        animado: animado,
        aoIrParaAnterior: nav.anterior,
        aoIrParaProximo: nav.proximo,
        aoAbrirCurva: nav.curva,
      );
    }

    // A FAIXA PASSA DA COMPOSICAO de proposito: entrar e sair de quadro
    // e animacao, e nao erro. Meia tela para cada lado da o espaco de
    // uma entrada inteira sem precisar digitar numero.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _AutoKeyframe(),
        campo(
          rotulo: 'Posicao X',
          valor: pos.dx,
          minimo: -w * .5,
          maximo: w * 1.5,
          aoMudar: (x) => c.editPosition(camada.id, tempo, Offset(x, pos.dy)),
          prop: LayerProp.position,
          temAqui: camada.position.hasKeyframeAt(local),
          animado: camada.position.isAnimated,
        ),
        campo(
          rotulo: 'Posicao Y',
          valor: pos.dy,
          minimo: -h * .5,
          maximo: h * 1.5,
          aoMudar: (y) => c.editPosition(camada.id, tempo, Offset(pos.dx, y)),
          prop: LayerProp.position,
          temAqui: camada.position.hasKeyframeAt(local),
          animado: camada.position.isAnimated,
        ),
        if (camada.is3D)
          campo(
            rotulo: 'Posicao Z',
            valor: camada.positionZ.valueAt(local),
            minimo: -2000,
            maximo: 2000,
            aoMudar: (z) => c.editPositionZ(camada.id, tempo, z),
            prop: LayerProp.position,
            temAqui: camada.positionZ.hasKeyframeAt(local),
            animado: camada.positionZ.isAnimated,
          ),
        _Travinha(
          rotulo: 'Escala travada em X e Y',
          ligado: uniforme,
          aoTocar: () =>
              ref.read(escalaUniformeProvider.notifier).state = !uniforme,
        ),
        if (uniforme)
          campo(
            rotulo: 'Escala',
            valor: camada.scaleX.valueAt(local) * 100,
            minimo: 1,
            maximo: 400,
            formatar: (x) => '${x.toStringAsFixed(0)}%',
            aoMudar: (x) => c.editScaleUniform(camada.id, tempo, x / 100),
            prop: LayerProp.scale,
            temAqui: camada.scaleX.hasKeyframeAt(local),
            animado: camada.scaleX.isAnimated,
          )
        else ...[
          campo(
            rotulo: 'Escala X',
            valor: camada.scaleX.valueAt(local) * 100,
            minimo: 1,
            maximo: 400,
            formatar: (x) => '${x.toStringAsFixed(0)}%',
            aoMudar: (x) => c.editScaleX(camada.id, tempo, x / 100),
            prop: LayerProp.scale,
            temAqui: camada.scaleX.hasKeyframeAt(local),
            animado: camada.scaleX.isAnimated,
          ),
          campo(
            rotulo: 'Escala Y',
            valor: camada.scaleY.valueAt(local) * 100,
            minimo: 1,
            maximo: 400,
            formatar: (x) => '${x.toStringAsFixed(0)}%',
            aoMudar: (x) => c.editScaleY(camada.id, tempo, x / 100),
            prop: LayerProp.scale,
            temAqui: camada.scaleY.hasKeyframeAt(local),
            animado: camada.scaleY.isAnimated,
          ),
        ],
        campo(
          rotulo: 'Rotacao',
          valor: camada.rotation.valueAt(local),
          minimo: -180,
          maximo: 180,
          formatar: (x) => '${x.toStringAsFixed(0)}°',
          aoMudar: (x) => c.editRotation(camada.id, tempo, x),
          prop: LayerProp.rotation,
          temAqui: camada.rotation.hasKeyframeAt(local),
          animado: camada.rotation.isAnimated,
        ),
        if (camada.is3D) ...[
          campo(
            rotulo: 'Rotacao X',
            valor: camada.rotationX.valueAt(local),
            minimo: -180,
            maximo: 180,
            formatar: (x) => '${x.toStringAsFixed(0)}°',
            aoMudar: (x) => c.editRotationX(camada.id, tempo, x),
            prop: LayerProp.rotation,
            temAqui: camada.rotationX.hasKeyframeAt(local),
            animado: camada.rotationX.isAnimated,
          ),
          campo(
            rotulo: 'Rotacao Y',
            valor: camada.rotationY.valueAt(local),
            minimo: -180,
            maximo: 180,
            formatar: (x) => '${x.toStringAsFixed(0)}°',
            aoMudar: (x) => c.editRotationY(camada.id, tempo, x),
            prop: LayerProp.rotation,
            temAqui: camada.rotationY.hasKeyframeAt(local),
            animado: camada.rotationY.isAnimated,
          ),
        ],
        // A ANCORAGEM E O PONTO EM TORNO DO QUAL TUDO GIRA E ESCALA.
        // Ela vem depois da rotacao de proposito: quem procura ancoragem
        // ja tentou girar e nao gostou de onde o giro aconteceu.
        campo(
          rotulo: 'Ancoragem X',
          valor: piv.dx,
          minimo: -w * .5,
          maximo: w * .5,
          aoMudar: (x) => c.editPivot(camada.id, tempo, Offset(x, piv.dy)),
          prop: LayerProp.pivot,
          temAqui: camada.pivot.hasKeyframeAt(local),
          animado: camada.pivot.isAnimated,
        ),
        campo(
          rotulo: 'Ancoragem Y',
          valor: piv.dy,
          minimo: -h * .5,
          maximo: h * .5,
          aoMudar: (y) => c.editPivot(camada.id, tempo, Offset(piv.dx, y)),
          prop: LayerProp.pivot,
          temAqui: camada.pivot.hasKeyframeAt(local),
          animado: camada.pivot.isAnimated,
        ),
        campo(
          rotulo: 'Inclinacao X',
          valor: camada.skewX.valueAt(local),
          minimo: -60,
          maximo: 60,
          formatar: (x) => '${x.toStringAsFixed(0)}°',
          aoMudar: (x) => c.editSkewX(camada.id, tempo, x),
          prop: LayerProp.skew,
          temAqui: camada.skewX.hasKeyframeAt(local),
          animado: camada.skewX.isAnimated,
        ),
        campo(
          rotulo: 'Inclinacao Y',
          valor: camada.skewY.valueAt(local),
          minimo: -60,
          maximo: 60,
          formatar: (x) => '${x.toStringAsFixed(0)}°',
          aoMudar: (y) => c.editSkewY(camada.id, tempo, y),
          prop: LayerProp.skew,
          temAqui: camada.skewY.hasKeyframeAt(local),
          animado: camada.skewY.isAnimated,
        ),
      ],
    );
  }
}

/// Um interruptor de linha, para o que liga e desliga sem ser valor.
class _Travinha extends StatelessWidget {
  const _Travinha({
    required this.rotulo,
    required this.ligado,
    required this.aoTocar,
  });

  final String rotulo;
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const SizedBox(width: 4),
            Icon(
              ligado ? Icons.link_rounded : Icons.link_off_rounded,
              size: 17,
              color: ligado ? AmColors.accent : AmColors.muted,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                rotulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: ligado ? AmColors.text : AmColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
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
    final nav = navegacaoDaPropriedade(
      ref,
      camada,
      LayerProp.opacity,
      'Opacidade',
      tempo,
      ProvedorDoRelogio.of(context),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _AutoKeyframe(),
        ParametroDeslizante(
          rotulo: 'Opacidade',
          valor: camada.opacity.valueAt(local) * 100,
          minimo: 0,
          maximo: 100,
          formatar: (x) => '${x.toStringAsFixed(0)}%',
          aoMudar: (x) => c.editOpacity(camada.id, tempo, x / 100),
          aoAlternarKeyframe: () =>
              c.toggleKeyframe(camada.id, tempo, LayerProp.opacity),
          temKeyframeAqui: camada.opacity.hasKeyframeAt(local),
          animado: camada.opacity.isAnimated,
          aoIrParaAnterior: nav.anterior,
          aoIrParaProximo: nav.proximo,
          aoAbrirCurva: nav.curva,
        ),
      ],
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
          padding: const EdgeInsets.only(top: 4, bottom: 10),
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
        ParametroDeslizante(
          rotulo: 'Tamanho',
          valor: l.fontSize,
          minimo: 8,
          maximo: 320,
          aoMudar: (x) => c.editTextLayer(l.id, fontSize: x),
        ),
        Semantics(
          container: true,
          excludeSemantics: true,
          button: true,
          toggled: l.bold,
          label: 'Negrito',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => c.editTextLayer(l.id, bold: !l.bold),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  const SizedBox(width: 30),
                  Icon(
                    Icons.format_bold_rounded,
                    size: 18,
                    color: l.bold ? AmColors.accent : AmColors.muted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Negrito',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: l.bold ? AmColors.text : AmColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
    // O PRIMEIRO PARAMETRICO E O QUE O PAINEL EDITA.
    //
    // Uma camada de forma pode ter varios desenhos dentro; o menu de
    // adicao cria uma com UM. Editar "o primeiro" e verdade para tudo
    // que nasce aqui, e nao mente sobre o resto: quem tiver mais de um
    // ve o aviso.
    final formas = l.contents.whereType<ShapeParametric>().toList();
    if (formas.isEmpty) {
      return const _Aviso(
        'Esta camada nao tem forma parametrica para ajustar.',
      );
    }
    final s = formas.first;

    Widget par(String chave, String rotulo, double max) {
      final track = shapeParamTrackOf(s, chave);
      if (track == null) return const SizedBox.shrink();
      return ParametroDeslizante(
        rotulo: rotulo,
        valor: track.valueAt(local),
        minimo: 0,
        maximo: max,
        aoMudar: (x) => c.editShapeParam(l.id, chave, tempo, x),
        aoAlternarKeyframe: () =>
            c.toggleShapeParamKeyframe(l.id, chave, tempo),
        temKeyframeAqui: track.hasKeyframeAt(local),
        animado: track.isAnimated,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (formas.length > 1)
          const _Aviso('Ajustando o primeiro desenho desta camada.'),
        par('sizeX', 'Largura', 2000),
        par('sizeY', 'Altura', 2000),
        par('roundness', 'Cantos', 400),
        par('points', 'Pontas', 20),
        par('outerRadius', 'Raio externo', 1000),
        par('innerRadius', 'Raio interno', 1000),
        par('sweep', 'Abertura', 360),
      ],
    );
  }
}

/// QUAL EFEITO ESTA ABERTO na lista, e o catalogo.
final efeitoAbertoProvider = StateProvider<String?>((ref) => null);
final catalogoDeEfeitosProvider = StateProvider<bool>((ref) => false);

/// OS EFEITOS DA CAMADA.
///
/// A ficha de cada efeito e GERADA da tabela `effectSpecs`, e nao
/// escrita a mao. Sao mais de cinquenta efeitos com parametros
/// proprios; uma tela por efeito seria cinquenta telas para manter em
/// dia, e a primeira que alguem esquecesse viraria um controle que nao
/// bate com o que o motor faz.
///
/// O que a tabela nao sabe desenhar aparece dito, e nao escondido: cor e
/// ponto tem tipo proprio e chegam noutra entrega. Um parametro invisivel
/// e um efeito que a pessoa acha quebrado.
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
          _LinhaDoEfeito(
            efeito: e,
            aberto: e.id == aberto,
            aoAbrir: () =>
                ref.read(efeitoAbertoProvider.notifier).state =
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

class _LinhaDoEfeito extends StatelessWidget {
  const _LinhaDoEfeito({
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
    return Row(
      children: [
        Semantics(
          container: true,
          excludeSemantics: true,
          button: true,
          toggled: efeito.enabled,
          label: efeito.enabled ? 'Desligar $nome' : 'Ligar $nome',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: aoAlternar,
            child: SizedBox(
              width: 34,
              height: 40,
              child: Icon(
                efeito.enabled
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                size: 17,
                color: efeito.enabled ? AmColors.text : AmColors.muted,
              ),
            ),
          ),
        ),
        Expanded(
          child: Semantics(
            container: true,
            excludeSemantics: true,
            button: true,
            label: nome,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: aoAbrir,
              child: SizedBox(
                height: 40,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: efeito.enabled
                              ? AmColors.text
                              : AmColors.muted,
                        ),
                      ),
                    ),
                    Icon(
                      aberto
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: AmColors.muted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Semantics(
          container: true,
          excludeSemantics: true,
          button: true,
          label: 'Tirar $nome',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: aoRemover,
            child: const SizedBox(
              width: 34,
              height: 40,
              child: Icon(
                Icons.close_rounded,
                size: 16,
                color: AmColors.muted,
              ),
            ),
          ),
        ),
      ],
    );
  }
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
          campos.add(
            ParametroDeslizante(
              rotulo: def.label,
              valor: trilha.valueAt(local),
              minimo: def.min,
              maximo: def.max,
              aoMudar: (v) =>
                  c.editEffectParam(camada.id, efeito.id, chave, tempo, v),
              aoAlternarKeyframe: () => c.toggleEffectParamKeyframe(
                camada.id,
                efeito.id,
                chave,
                tempo,
              ),
              temKeyframeAqui: trilha.hasKeyframeAt(local),
              animado: trilha.isAnimated,
            ),
          );
        case ParamKind.toggle:
          campos.add(
            _Travinha(
              rotulo: def.label,
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
        case ParamKind.color:
        case ParamKind.point:
          semDesenho.add(def.label);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...campos,
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
                      // O EFEITO NOVO ABRE JA COM A FICHA A VISTA: quem
                      // acabou de escolher quer ajustar, e nao procurar
                      // de novo o que acabou de adicionar.
                      final novo = ref
                          .read(editorControllerProvider)
                          .layers
                          .firstWhere((l) => l.id == camada.id)
                          .effects
                          .last;
                      ref.read(efeitoAbertoProvider.notifier).state = novo.id;
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

class _Volume extends ConsumerWidget {
  const _Volume({required this.camada});

  final Layer camada;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = camada as VideoLayer;
    final c = ref.read(editorControllerProvider.notifier);
    return ParametroDeslizante(
      rotulo: 'Volume',
      valor: l.volume * 100,
      minimo: 0,
      maximo: 200,
      formatar: (x) => '${x.toStringAsFixed(0)}%',
      aoMudar: (x) => c.editVideoVolume(l.id, x / 100),
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
/// tem categoria propria em vez de virarem mais um deslizante perdido no
/// meio dos outros.
class _AcoesDaCamada extends ConsumerWidget {
  const _AcoesDaCamada({required this.camada, required this.playback});

  final Layer camada;
  final PlaybackController playback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(editorControllerProvider.notifier);
    final agora = playback.time.value;
    // DIVIDIR SO FAZ SENTIDO COM O CABECOTE DENTRO DA CAMADA. Fora dela
    // nao ha o que cortar, e um corte no vazio produziria uma camada de
    // duracao zero.
    final podeDividir =
        agora > camada.startTime && agora < camada.endTime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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

class _Aviso extends StatelessWidget {
  const _Aviso(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      texto,
      style: const TextStyle(fontSize: 11, color: AmColors.muted, height: 1.4),
    ),
  );
}

class _AindaNao extends StatelessWidget {
  const _AindaNao();

  @override
  Widget build(BuildContext context) => const Text(
    'Os controles desta categoria chegam numa proxima entrega.',
    key: ValueKey('categoria-sem-controles'),
    style: TextStyle(fontSize: 12, color: AmColors.muted, height: 1.4),
  );
}
