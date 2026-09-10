import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/am_colors.dart';
import '../../application/editor_controller.dart';
import '../../application/playback_controller.dart';
import '../../domain/layer.dart';
import '../../domain/shape.dart';

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
        builder: (context, tempo, _) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 2, 14, 16),
          child: switch (categoriaId) {
            'transformar' => _Transformar(camada: camada, tempo: tempo),
            'opacidade' => _Opacidade(camada: camada, tempo: tempo),
            'texto' => _Texto(camada: camada),
            'forma' => _Forma(camada: camada, tempo: tempo),
            'volume' => _Volume(camada: camada),
            'midia' => _Midia(camada: camada),
            'camada' => _AcoesDaCamada(camada: camada, playback: playback),
            _ => const _AindaNao(),
          },
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
    final w = projeto.outputWidth.toDouble();
    final h = projeto.outputHeight.toDouble();

    // A FAIXA PASSA DA COMPOSICAO de proposito: entrar e sair de quadro
    // e animacao, e nao erro. Meia tela para cada lado da o espaco de
    // uma entrada inteira sem precisar digitar numero.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _AutoKeyframe(),
        ParametroDeslizante(
          rotulo: 'Posicao X',
          valor: pos.dx,
          minimo: -w * .5,
          maximo: w * 1.5,
          aoMudar: (x) => c.editPosition(camada.id, tempo, Offset(x, pos.dy)),
          aoAlternarKeyframe: () =>
              c.toggleKeyframe(camada.id, tempo, LayerProp.position),
          temKeyframeAqui: camada.position.hasKeyframeAt(local),
          animado: camada.position.isAnimated,
        ),
        ParametroDeslizante(
          rotulo: 'Posicao Y',
          valor: pos.dy,
          minimo: -h * .5,
          maximo: h * 1.5,
          aoMudar: (y) => c.editPosition(camada.id, tempo, Offset(pos.dx, y)),
          aoAlternarKeyframe: () =>
              c.toggleKeyframe(camada.id, tempo, LayerProp.position),
          temKeyframeAqui: camada.position.hasKeyframeAt(local),
          animado: camada.position.isAnimated,
        ),
        ParametroDeslizante(
          rotulo: 'Escala',
          valor: camada.scaleX.valueAt(local) * 100,
          minimo: 1,
          maximo: 400,
          formatar: (x) => '${x.toStringAsFixed(0)}%',
          aoMudar: (x) => c.editScaleUniform(camada.id, tempo, x / 100),
          aoAlternarKeyframe: () =>
              c.toggleKeyframe(camada.id, tempo, LayerProp.scale),
          temKeyframeAqui: camada.scaleX.hasKeyframeAt(local),
          animado: camada.scaleX.isAnimated,
        ),
        ParametroDeslizante(
          rotulo: 'Rotacao',
          valor: camada.rotation.valueAt(local),
          minimo: -180,
          maximo: 180,
          formatar: (x) => '${x.toStringAsFixed(0)}°',
          aoMudar: (x) => c.editRotation(camada.id, tempo, x),
          aoAlternarKeyframe: () =>
              c.toggleKeyframe(camada.id, tempo, LayerProp.rotation),
          temKeyframeAqui: camada.rotation.hasKeyframeAt(local),
          animado: camada.rotation.isAnimated,
        ),
      ],
    );
  }
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
