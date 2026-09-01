import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/snack.dart';
import '../../../../core/utils/time_format.dart';
import '../../application/editor_controller.dart';
import '../../application/media_preview_service.dart';
import '../../domain/layer.dart';
import 'am_colors.dart';
import 'clip_preview_painters.dart';

/// MODO DECUPAGEM: a tela de escolher o que fica.
///
/// Na linha do tempo o clipe e uma barra de dois centimetros — decupar
/// ali e adivinhacao. Aqui ele ocupa a tela inteira: a forma de onda
/// grande mostra onde esta a respiracao entre duas falas, a tira de
/// miniaturas mostra onde a cena muda, e entrada/saida marcam o trecho
/// sem precisar de precisao de cirurgiao.
///
/// O corte por silencio aparece ANTES de acontecer, em vermelho: mexer
/// no limiar e ver as faixas nascerem e sumirem e o que dispensa o
/// "desfazer, tenta de novo".
Future<void> openDecupagem(
  BuildContext context,
  WidgetRef ref,
  String layerId,
) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => DecupagemScreen(layerId: layerId),
    ),
  );
}

class DecupagemScreen extends ConsumerStatefulWidget {
  const DecupagemScreen({super.key, required this.layerId});

  final String layerId;

  @override
  ConsumerState<DecupagemScreen> createState() => _DecupagemScreenState();
}

class _DecupagemScreenState extends ConsumerState<DecupagemScreen> {
  final _service = MediaPreviewService.instance;

  /// Posicao dentro do CLIPE (0 .. duracao), nao na linha do tempo.
  Duration _cursor = Duration.zero;
  Duration? _entrada;
  Duration? _saida;

  bool _porSilencio = false;
  double _limiar = 0.035;
  double _minPausa = 350;
  bool _arrasto = true;

  @override
  void initState() {
    super.initState();
    final l = _layer;
    if (l is AudioLayer) {
      _service.ensureWaveform(l.sourcePath);
    } else if (l is VideoLayer) {
      _service.ensureWaveform(l.sourcePath);
      _service.ensureFilmstrip(
          l.sourcePath, l.sourceOffset + l.duration);
    }
  }

  Layer? get _layer =>
      ref.read(editorControllerProvider).layerById(widget.layerId);

  Duration get _fonteInicio => switch (_layer) {
        VideoLayer v => v.sourceOffset,
        AudioLayer a => a.sourceOffset,
        _ => Duration.zero,
      };

  String? get _caminho => switch (_layer) {
        VideoLayer v => v.sourcePath,
        AudioLayer a => a.sourcePath,
        _ => null,
      };

  /// Pausas dentro deste clipe, em tempo do CLIPE (0 = inicio da barra).
  List<(Duration, Duration)> _pausas() {
    final l = _layer;
    if (l == null) return const [];
    final r = ref
        .read(editorControllerProvider.notifier)
        .silenceRangesOf(widget.layerId,
            threshold: _limiar,
            minSilence: Duration(milliseconds: _minPausa.round()));
    if (r == null) return const [];
    return [
      for (final p in r) (p.$1 - l.startTime, p.$2 - l.startTime)
    ];
  }

  void _aplicarSilencio() {
    final l = _layer;
    if (l == null) return;
    final pausas = _pausas();
    if (pausas.isEmpty) {
      AureaSnack.show(context, 'Nenhuma pausa nesse limiar');
      return;
    }
    final total = pausas.fold<Duration>(
        Duration.zero, (a, p) => a + (p.$2 - p.$1));
    final naLinha = [
      for (final p in pausas)
        (l.startTime + p.$1, l.startTime + p.$2)
    ];
    ref
        .read(editorControllerProvider.notifier)
        .cutRangesOf(widget.layerId, naLinha, ripple: _arrasto);
    if (!mounted) return;
    Navigator.of(context).pop();
    AureaSnack.show(
      context,
      '${pausas.length} ${pausas.length == 1 ? "pausa removida" : "pausas removidas"}'
      ' (${formatTime(total)})',
      actionLabel: 'Desfazer',
      onAction: ref.read(editorControllerProvider.notifier).undo,
    );
  }

  void _aplicarTrecho({required bool manter}) {
    final l = _layer;
    if (l == null) return;
    final de = _entrada ?? Duration.zero;
    final ate = _saida ?? l.duration;
    if (ate <= de) {
      AureaSnack.show(context, 'Marque a entrada antes da saida');
      return;
    }
    final ctrl = ref.read(editorControllerProvider.notifier);
    if (manter) {
      // Ficar so com o miolo: tira as duas pontas.
      ctrl.cutRangesOf(
        widget.layerId,
        [
          if (de > Duration.zero) (l.startTime, l.startTime + de),
          if (ate < l.duration) (l.startTime + ate, l.endTime),
        ],
        ripple: _arrasto,
      );
    } else {
      ctrl.cutRangesOf(
        widget.layerId,
        [(l.startTime + de, l.startTime + ate)],
        ripple: _arrasto,
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
    AureaSnack.show(
      context,
      manter ? 'Sobrou so o trecho marcado' : 'Trecho removido',
      actionLabel: 'Desfazer',
      onAction: ctrl.undo,
    );
  }

  void _cortarNoCursor() {
    final l = _layer;
    if (l == null) return;
    ref
        .read(editorControllerProvider.notifier)
        .splitLayer(widget.layerId, l.startTime + _cursor);
    if (!mounted) return;
    Navigator.of(context).pop();
    AureaSnack.show(context, 'Cortado em ${formatTime(_cursor)}',
        actionLabel: 'Desfazer',
        onAction: ref.read(editorControllerProvider.notifier).undo);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(editorControllerProvider);
    final l = _layer;
    if (l == null) return const SizedBox.shrink();

    final dur = l.duration;
    final path = _caminho;
    final pausas = _porSilencio ? _pausas() : const <(Duration, Duration)>[];

    return Scaffold(
      backgroundColor: AmColors.bg,
      appBar: AppBar(
        backgroundColor: AmColors.topBar,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.xmark, color: AmColors.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Decupagem',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AmColors.text)),
            Text(l.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 11, color: AmColors.muted)),
          ],
        ),
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: _service.revision,
        builder: (context, _, _) {
          final peaks = path == null ? null : _service.peaksOf(path);
          final strip = path == null ? null : _service.stripOf(path);

          return Column(
            children: [
              Expanded(
                child: _Visor(
                  frames: strip,
                  sourceStart: _fonteInicio,
                  sourceEnd: _fonteInicio + dur,
                  cursor: _cursor,
                  duration: dur,
                  temVideo: l is VideoLayer,
                ),
              ),
              _Trilha(
                peaks: peaks,
                sourceStart: _fonteInicio,
                sourceEnd: _fonteInicio + dur,
                duration: dur,
                cursor: _cursor,
                entrada: _entrada,
                saida: _saida,
                pausas: pausas,
                onScrub: (t) => setState(() => _cursor = t),
              ),
              _Regua(cursor: _cursor, duration: dur),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _Botao(
                              rotulo: 'Entrada',
                              detalhe: _entrada == null
                                  ? '—'
                                  : formatTime(_entrada!),
                              aceso: _entrada != null,
                              onTap: () => setState(() {
                                _entrada = _cursor;
                                if (_saida != null && _saida! <= _cursor) {
                                  _saida = null;
                                }
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _Botao(
                              rotulo: 'Saida',
                              detalhe: _saida == null
                                  ? '—'
                                  : formatTime(_saida!),
                              aceso: _saida != null,
                              onTap: () => setState(() {
                                _saida = _cursor;
                                if (_entrada != null &&
                                    _entrada! >= _cursor) {
                                  _entrada = null;
                                }
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _Botao(
                              rotulo: 'Limpar',
                              detalhe: 'marcas',
                              onTap: () => setState(() {
                                _entrada = null;
                                _saida = null;
                              }),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _Acao('Ficar so com o trecho',
                                () => _aplicarTrecho(manter: true)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _Acao('Remover o trecho',
                                () => _aplicarTrecho(manter: false)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _Acao('Cortar aqui', _cortarNoCursor),

                      const SizedBox(height: 14),
                      const Divider(color: AmColors.hairline, height: 1),
                      const SizedBox(height: 10),

                      _Chave(
                        rotulo: 'Pular silencio',
                        valor: _porSilencio,
                        onChanged: (v) => setState(() => _porSilencio = v),
                      ),
                      if (_porSilencio) ...[
                        if (peaks == null || peaks.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Lendo o som do arquivo...',
                              style: TextStyle(
                                  fontSize: 11, color: AmColors.muted),
                            ),
                          )
                        else ...[
                          _Deslize(
                            rotulo: 'Limiar',
                            valor: _limiar,
                            min: 0.005,
                            max: 0.2,
                            texto: _limiar.toStringAsFixed(3),
                            onChanged: (v) => setState(() => _limiar = v),
                          ),
                          _Deslize(
                            rotulo: 'Pausa minima',
                            valor: _minPausa,
                            min: 100,
                            max: 2000,
                            texto: '${_minPausa.round()} ms',
                            onChanged: (v) =>
                                setState(() => _minPausa = v),
                          ),
                          Text(
                            pausas.isEmpty
                                ? 'Nenhuma pausa nesse limiar.'
                                : '${pausas.length} '
                                    '${pausas.length == 1 ? "pausa" : "pausas"}'
                                    ' — sai ${formatTime(pausas.fold<Duration>(Duration.zero, (a, p) => a + (p.$2 - p.$1)))}'
                                    ' de ${formatTime(dur)}',
                            style: const TextStyle(
                                fontSize: 11, color: AmColors.muted),
                          ),
                          const SizedBox(height: 6),
                          _Acao('Remover as pausas', _aplicarSilencio),
                        ],
                      ],

                      const SizedBox(height: 10),
                      _Chave(
                        rotulo: 'Encostar o que vem depois',
                        valor: _arrasto,
                        onChanged: (v) => setState(() => _arrasto = v),
                      ),
                      const Text(
                        'Desligado, o corte deixa o buraco — e o que se '
                        'quer quando outra trilha tem de continuar no '
                        'mesmo lugar.',
                        style: TextStyle(
                            fontSize: 11,
                            height: 1.35,
                            color: AmColors.muted),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Quadro do cursor: a miniatura mais proxima da tira.
class _Visor extends StatelessWidget {
  const _Visor({
    required this.frames,
    required this.sourceStart,
    required this.sourceEnd,
    required this.cursor,
    required this.duration,
    required this.temVideo,
  });

  final List<ui.Image>? frames;
  final Duration sourceStart;
  final Duration sourceEnd;
  final Duration cursor;
  final Duration duration;
  final bool temVideo;

  @override
  Widget build(BuildContext context) {
    final lista = frames;
    if (!temVideo || lista == null || lista.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              temVideo
                  ? CupertinoIcons.film
                  : CupertinoIcons.waveform,
              size: 34,
              color: AmColors.muted,
            ),
            const SizedBox(height: 8),
            Text(
              temVideo ? 'Montando as miniaturas...' : 'Faixa de som',
              style: const TextStyle(
                  fontSize: 12, color: AmColors.muted),
            ),
          ],
        ),
      );
    }

    // As miniaturas cobrem o arquivo inteiro; o cursor anda dentro do
    // pedaco que a camada usa.
    final totalUs = sourceEnd.inMicroseconds;
    final noArquivo = sourceStart + cursor;
    final f = totalUs <= 0 ? 0.0 : noArquivo.inMicroseconds / totalUs;
    final i = (f * lista.length).floor().clamp(0, lista.length - 1);

    return Padding(
      padding: const EdgeInsets.all(10),
      child: RawImage(image: lista[i], fit: BoxFit.contain),
    );
  }
}

/// Forma de onda grande, com as marcas de entrada/saida e as pausas
/// que o corte vai tirar.
class _Trilha extends StatelessWidget {
  const _Trilha({
    required this.peaks,
    required this.sourceStart,
    required this.sourceEnd,
    required this.duration,
    required this.cursor,
    required this.entrada,
    required this.saida,
    required this.pausas,
    required this.onScrub,
  });

  final Float32List? peaks;
  final Duration sourceStart;
  final Duration sourceEnd;
  final Duration duration;
  final Duration cursor;
  final Duration? entrada;
  final Duration? saida;
  final List<(Duration, Duration)> pausas;
  final ValueChanged<Duration> onScrub;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          void toque(Offset p) {
            final f = (p.dx / c.maxWidth).clamp(0.0, 1.0);
            onScrub(Duration(
                microseconds: (duration.inMicroseconds * f).round()));
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => toque(d.localPosition),
            onHorizontalDragUpdate: (d) => toque(d.localPosition),
            child: Container(
              height: 120,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AmColors.panel,
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  if (peaks != null && peaks!.isNotEmpty)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: WaveformPainter(
                          peaks: peaks!,
                          start: sourceStart,
                          end: sourceEnd,
                          color: AmColors.tealBright,
                        ),
                      ),
                    ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _MarcasPainter(
                        duration: duration,
                        cursor: cursor,
                        entrada: entrada,
                        saida: saida,
                        pausas: pausas,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class _MarcasPainter extends CustomPainter {
  const _MarcasPainter({
    required this.duration,
    required this.cursor,
    required this.entrada,
    required this.saida,
    required this.pausas,
  });

  final Duration duration;
  final Duration cursor;
  final Duration? entrada;
  final Duration? saida;
  final List<(Duration, Duration)> pausas;

  double _x(Duration t, double w) {
    final total = duration.inMicroseconds;
    if (total <= 0) return 0;
    return (t.inMicroseconds / total).clamp(0.0, 1.0) * w;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // O que sai, em vermelho translucido: o corte se ve antes de
    // acontecer.
    final fora = Paint()..color = AmColors.pink.withValues(alpha: 0.28);
    for (final p in pausas) {
      final a = _x(p.$1, size.width);
      final b = _x(p.$2, size.width);
      if (b > a) {
        canvas.drawRect(Rect.fromLTRB(a, 0, b, size.height), fora);
      }
    }

    // Fora das marcas fica escurecido — o trecho marcado e o unico que
    // continua legivel.
    if (entrada != null || saida != null) {
      final veu = Paint()..color = const Color(0xAA0B0E12);
      final a = entrada == null ? 0.0 : _x(entrada!, size.width);
      final b = saida == null ? size.width : _x(saida!, size.width);
      if (a > 0) canvas.drawRect(Rect.fromLTRB(0, 0, a, size.height), veu);
      if (b < size.width) {
        canvas.drawRect(
            Rect.fromLTRB(b, 0, size.width, size.height), veu);
      }
      final borda = Paint()
        ..color = AmColors.accent
        ..strokeWidth = 2;
      if (entrada != null) {
        canvas.drawLine(Offset(a, 0), Offset(a, size.height), borda);
      }
      if (saida != null) {
        canvas.drawLine(Offset(b, 0), Offset(b, size.height), borda);
      }
    }

    final linha = Paint()
      ..color = AmColors.text
      ..strokeWidth = 1.5;
    final x = _x(cursor, size.width);
    canvas.drawLine(Offset(x, 0), Offset(x, size.height), linha);
  }

  @override
  bool shouldRepaint(_MarcasPainter old) =>
      old.cursor != cursor ||
      old.entrada != entrada ||
      old.saida != saida ||
      old.duration != duration ||
      old.pausas.length != pausas.length;
}

class _Regua extends StatelessWidget {
  const _Regua({required this.cursor, required this.duration});

  final Duration cursor;
  final Duration duration;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(formatTime(cursor),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AmColors.accent)),
            Text(formatTime(duration),
                style: const TextStyle(
                    fontSize: 12, color: AmColors.muted)),
          ],
        ),
      );
}

class _Botao extends StatelessWidget {
  const _Botao({
    required this.rotulo,
    required this.detalhe,
    required this.onTap,
    this.aceso = false,
  });

  final String rotulo;
  final String detalhe;
  final VoidCallback onTap;
  final bool aceso;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: aceso ? AmColors.accentDim : AmColors.chip,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Column(
            children: [
              Text(rotulo,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: aceso ? AmColors.accent : AmColors.text)),
              Text(detalhe,
                  style: const TextStyle(
                      fontSize: 10, color: AmColors.muted)),
            ],
          ),
        ),
      );
}

class _Acao extends StatelessWidget {
  const _Acao(this.rotulo, this.onTap);

  final String rotulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AmColors.panelHigh,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(rotulo,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AmColors.text)),
        ),
      );
}

class _Chave extends StatelessWidget {
  const _Chave({
    required this.rotulo,
    required this.valor,
    required this.onChanged,
  });

  final String rotulo;
  final bool valor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(rotulo,
                style: const TextStyle(
                    fontSize: 13, color: AmColors.text)),
          ),
          CupertinoSwitch(
            value: valor,
            activeTrackColor: AmColors.accent,
            onChanged: onChanged,
          ),
        ],
      );
}

class _Deslize extends StatelessWidget {
  const _Deslize({
    required this.rotulo,
    required this.valor,
    required this.min,
    required this.max,
    required this.texto,
    required this.onChanged,
  });

  final String rotulo;
  final double valor;
  final double min;
  final double max;
  final String texto;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(rotulo,
                style: const TextStyle(
                    fontSize: 12, color: AmColors.muted)),
          ),
          Expanded(
            child: CupertinoSlider(
              value: valor.clamp(min, max),
              min: min,
              max: max,
              activeColor: AmColors.accent,
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 62,
            child: Text(texto,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 11, color: AmColors.text)),
          ),
        ],
      );
}
