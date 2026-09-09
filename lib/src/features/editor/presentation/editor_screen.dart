import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/time_format.dart';
import '../application/editor_controller.dart';
import '../application/playback_controller.dart';
import '../application/video_layer_manager.dart';
import 'widgets/palco_de_previa.dart';

/// A TELA DE EDICAO, no osso.
///
/// A UI de edicao anterior — timeline, paineis, folhas, menus, barras,
/// edicao no palco — foi apagada por inteiro para ser refeita. O que
/// sobrou aqui e o minimo que ainda merece o nome de editor: a
/// composicao desenhada, e um cabecote para andar no tempo.
///
/// O MOTOR NAO FOI TOCADO. O projeto, as camadas, os efeitos, a cena 3D,
/// o desfazer, a gravacao e a exportacao continuam inteiros em
/// `domain/` e `application/`. O que saiu foi so a casca. Construir a
/// interface nova e ligar controles novos ao mesmo `EditorController`
/// que ja esta aqui.
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen>
    with SingleTickerProviderStateMixin {
  late final PlaybackController _playback;
  final VideoLayerManager _videos = VideoLayerManager();

  @override
  void initState() {
    super.initState();
    _playback = PlaybackController(
      vsync: this,
      durationOf: () => ref.read(editorControllerProvider).duration,
    );
    _playback.time.addListener(_syncVideos);
    _playback.playing.addListener(_syncVideos);
    // ABRIR UM PROJETO precisa montar os tocadores AGORA: o relogio esta
    // parado no zero e o sync so aconteceria quando ele andasse.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncVideos();
    });
  }

  void _syncVideos() {
    final project = ref.read(editorControllerProvider);
    final master = _videos.sync(
      project.layers,
      _playback.time.value,
      _playback.playing.value,
      seekRevision: _playback.seekRevision,
    );
    if (master != null) _playback.anchorToMedia(master);
  }

  @override
  void dispose() {
    _playback.dispose();
    _videos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(editorControllerProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0D),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio:
                      project.outputWidth / project.outputHeight,
                  child: ColoredBox(
                    color: const Color(0xFF000000),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: project.outputWidth.toDouble(),
                        height: project.outputHeight.toDouble(),
                        child: CompositionView(
                          time: _playback.time,
                          videos: _videos,
                          selectedId: null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _Cabecote(playback: _playback, duracao: project.duration),
          ],
        ),
      ),
    );
  }
}

/// A REGUA E O CABECOTE.
///
/// O unico controle que sobrou. Arrastar anda no tempo; a marca de cada
/// segundo da a escala. Nao ha barras de camada aqui de proposito: a
/// linha do tempo inteira faz parte do que vai ser redesenhado.
class _Cabecote extends StatefulWidget {
  const _Cabecote({required this.playback, required this.duracao});

  final PlaybackController playback;
  final Duration duracao;

  @override
  State<_Cabecote> createState() => _CabecoteState();
}

class _CabecoteState extends State<_Cabecote> {
  static const _altura = 64.0;

  void _irPara(double dx, double largura) {
    if (largura <= 0) return;
    final fracao = (dx / largura).clamp(0.0, 1.0);
    widget.playback.pause();
    widget.playback.seek(widget.duracao * fracao);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _altura,
    child: LayoutBuilder(
      builder: (context, limites) {
        final largura = limites.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _irPara(d.localPosition.dx, largura),
          onHorizontalDragStart: (d) => _irPara(d.localPosition.dx, largura),
          onHorizontalDragUpdate: (d) =>
              _irPara(d.localPosition.dx, largura),
          child: ValueListenableBuilder<Duration>(
            valueListenable: widget.playback.time,
            builder: (context, t, _) => CustomPaint(
              painter: _ReguaPainter(
                tempo: t,
                duracao: widget.duracao,
              ),
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10, top: 6),
                  child: Text(
                    formatTime(t),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _ReguaPainter extends CustomPainter {
  const _ReguaPainter({required this.tempo, required this.duracao});

  final Duration tempo;
  final Duration duracao;

  @override
  void paint(Canvas canvas, Size size) {
    final us = duracao.inMicroseconds;
    if (us <= 0) return;

    // As marcas de segundo, com a do multiplo de cinco mais alta.
    final risco = Paint()..color = const Color(0xFF2C2C2E);
    final segundos = duracao.inSeconds;
    // Nunca mais que uma marca a cada tres pixels: numa composicao longa
    // as marcas viram uma mancha e custam caro.
    final passo = segundos <= 0 ? 1 : ((segundos * 3) / size.width).ceil();
    for (var s = 0; s <= segundos; s += passo < 1 ? 1 : passo) {
      final x = size.width * (s / (us / 1000000));
      final alta = s % 5 == 0;
      canvas.drawRect(
        Rect.fromLTWH(x, alta ? 8 : 14, 1, alta ? 14 : 8),
        risco,
      );
    }

    // A linha de base.
    canvas.drawRect(
      Rect.fromLTWH(0, 30, size.width, 1),
      Paint()..color = const Color(0xFF1C1C1E),
    );

    // O cabecote.
    final x = size.width * (tempo.inMicroseconds / us).clamp(0.0, 1.0);
    final cor = Paint()..color = const Color(0xFFFF375F);
    canvas.drawRect(Rect.fromLTWH(x - 1, 4, 2, size.height - 8), cor);
    canvas.drawCircle(Offset(x, 4), 5, cor);
  }

  @override
  bool shouldRepaint(_ReguaPainter old) =>
      old.tempo != tempo || old.duracao != duracao;
}
