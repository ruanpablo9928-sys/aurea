import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/editor_controller.dart';
import '../../application/iconify_service.dart';
import '../../application/transcription_service.dart';
import '../../domain/caption.dart';
import '../../domain/element3d.dart';
import '../../domain/layer.dart';
import '../../domain/shape.dart';
import '../../domain/svg_path.dart';
import '../am/am_colors.dart';
import '../am/am_widgets.dart';
import 'element3d_painter.dart';

/// Sheet "+" do editor: escolher o tipo de camada.
Future<void> showAddLayerSheet(
  BuildContext context,
  WidgetRef ref,
  Duration playhead,
) {
  final controller = ref.read(editorControllerProvider.notifier);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AmColors.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Adicionar camada',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AmColors.text)),
            const SizedBox(height: 18),
            Row(
              children: [
                _AddOption(
                  icon: CupertinoIcons.videocam_fill,
                  label: 'Video',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    controller.importVideoFromGallery(playhead);
                  },
                ),
                _AddOption(
                  icon: CupertinoIcons.photo_fill,
                  label: 'Imagem',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    controller.importImageFromGallery(playhead);
                  },
                ),
                _AddOption(
                  icon: CupertinoIcons.textformat,
                  label: 'Texto',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    controller.addTextLayer(playhead);
                  },
                ),
                _AddOption(
                  icon: CupertinoIcons.circle_fill,
                  label: 'Forma',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _showShapePresetSheet(context, ref, playhead);
                  },
                ),
                _AddOption(
                  icon: CupertinoIcons.captions_bubble,
                  label: 'Legendas',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _showSrtSheet(context, ref);
                  },
                ),
                _AddOption(
                  icon: CupertinoIcons.music_note,
                  label: 'Audio',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    controller.importAudioFile(playhead);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _AddOption(
                  icon: CupertinoIcons.viewfinder,
                  label: 'Nulo 3D',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    controller.addNullLayer(playhead);
                  },
                ),
                _AddOption(
                  icon: CupertinoIcons.sparkles,
                  label: 'Particulas',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    controller.addParticlesLayer(playhead);
                  },
                ),
                _AddOption(
                  icon: CupertinoIcons.square_grid_2x2,
                  label: 'Icones',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _showIconSheet(context, ref, playhead);
                  },
                ),
                _AddOption(
                  icon: CupertinoIcons.slider_horizontal_3,
                  label: 'Ajuste',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    controller.addAdjustmentLayer(playhead);
                  },
                ),
                _AddOption(
                  icon: CupertinoIcons.cube,
                  label: 'Elementos 3D',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _showElement3DPickerSheet(context, ref, playhead);
                  },
                ),
                _AddOption(
                  icon: CupertinoIcons.cube_box,
                  label: 'Cena 3D',
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    controller.addScene3DLayer(playhead);
                  },
                ),
                const Spacer(),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Aba ELEMENTOS 3D: solidos nativos (cubo, esfera, diamante...) que
/// giram de verdade no espaco e se vinculam a nulos como qualquer
/// camada. Cada tile mostra o proprio solido renderizado.
Future<void> _showElement3DPickerSheet(
    BuildContext context, WidgetRef ref, Duration playhead) async {
  final controller = ref.read(editorControllerProvider.notifier);
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AmColors.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Elementos 3D',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AmColors.text)),
            const SizedBox(height: 4),
            const Text(
              'Solidos de verdade: giram no espaco e seguem um nulo 3D.',
              style: TextStyle(fontSize: 12, color: AmColors.muted),
            ),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.15,
              children: [
                for (final kind in Element3DKind.values)
                  GestureDetector(
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      controller.addElement3DLayer(playhead, kind);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: AmColors.chip,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(58, 58),
                            painter: Element3DPainter(
                              layer: Element3DLayer(
                                name: '',
                                startTime: Duration.zero,
                                duration: const Duration(seconds: 1),
                                kind: kind,
                                size: 21,
                              ),
                              rotXDeg: -22,
                              rotYDeg: 34,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(element3DLabel(kind),
                              style: const TextStyle(
                                  fontSize: 12, color: AmColors.text)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Biblioteca de formas vetoriais.
Future<void> _showShapePresetSheet(
    BuildContext context, WidgetRef ref, Duration playhead) async {
  final controller = ref.read(editorControllerProvider.notifier);
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AmColors.panel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      Widget option(String label, IconData icon,
          List<ShapeItem> Function() build, String name) {
        return _AddOption(
          icon: icon,
          label: label,
          onTap: () {
            Navigator.of(sheetContext).pop();
            controller.addShapeLayer(playhead,
                contents: build(), name: name);
          },
        );
      }

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Formas vetoriais',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AmColors.text)),
              const SizedBox(height: 16),
              // Primitivas PARAMETRICAS: Tamanho/Arredondamento/Pontas
              // animaveis no caminho (spec parametros-de-forma).
              Row(
                children: [
                  option('Circulo', CupertinoIcons.circle_fill,
                      ShapePresets.paramEllipse, 'Circulo'),
                  option('Retangulo', CupertinoIcons.square_fill,
                      ShapePresets.paramRect, 'Retangulo'),
                  option('Estrela', CupertinoIcons.star_fill,
                      ShapePresets.paramStar, 'Estrela'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  option('Anel', CupertinoIcons.circle,
                      ShapePresets.paramRing, 'Anel'),
                  option('Setor', CupertinoIcons.moon,
                      ShapePresets.paramSector, 'Setor'),
                  option('Onda', CupertinoIcons.waveform_path,
                      ShapePresets.wave, 'Onda'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  option('Poligono', CupertinoIcons.hexagon_fill,
                      ShapePresets.paramPolygon, 'Poligono'),
                  option('Coracao', CupertinoIcons.heart_fill,
                      ShapePresets.heart, 'Coracao'),
                  option('Engrenagem', CupertinoIcons.gear_alt_fill,
                      ShapePresets.gear, 'Engrenagem'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  option('Seta', CupertinoIcons.arrow_right,
                      ShapePresets.arrow, 'Seta'),
                  option('Check', CupertinoIcons.checkmark,
                      ShapePresets.check, 'Check'),
                  option('Faisca', CupertinoIcons.sparkles,
                      ShapePresets.sparkle, 'Faisca'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  option('Gota', CupertinoIcons.drop_fill,
                      ShapePresets.drop, 'Gota'),
                  option('Flor', CupertinoIcons.smallcircle_circle,
                      ShapePresets.flower, 'Flor'),
                  const Spacer(),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Aba de ICONES (Iconify): busca com filtro de licenca; o icone entra na
/// cena como FORMA vetorial editavel, nunca como imagem.
Future<void> _showIconSheet(
    BuildContext context, WidgetRef ref, Duration playhead) async {
  final controller = ref.read(editorControllerProvider.notifier);
  final service = ref.read(iconifyServiceProvider);
  final queryController = TextEditingController();
  var permissiveOnly = true;
  var busy = false;
  var status = 'Busque um icone (ex.: rocket, heart, arrow).';
  var results = <(String, String)>[];
  var paths = <String, String>{};

  await showParamSheet(
    context,
    heightFactor: 0.55,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        Future<void> doSearch() async {
          final q = queryController.text.trim();
          if (q.isEmpty) return;
          setSheetState(() {
            busy = true;
            status = 'Buscando...';
          });
          try {
            final found =
                await service.search(q, permissiveOnly: permissiveOnly);
            final data = await service.pathDataFor(found);
            if (!sheetContext.mounted) return;
            setSheetState(() {
              results = [
                for (final r in found)
                  if (data.containsKey('${r.$1}:${r.$2}')) r,
              ];
              paths = data;
              status = results.isEmpty
                  ? 'Nada encontrado — sem internet? Tente de novo.'
                  : '${results.length} icone(s) — toque para inserir.'
                      '${service.collectionsLoaded ? '' : '  (licencas indisponiveis)'}';
            });
          } catch (e) {
            if (sheetContext.mounted) {
              setSheetState(() => status = 'Erro na busca: $e');
            }
          } finally {
            if (sheetContext.mounted) {
              setSheetState(() => busy = false);
            }
          }
        }

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, 14, 18,
                14 + MediaQuery.of(sheetContext).viewInsets.bottom),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Icones (Iconify)',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AmColors.text)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoTextField(
                        controller: queryController,
                        placeholder: 'buscar...',
                        style: const TextStyle(
                            fontSize: 14, color: AmColors.text),
                        placeholderStyle: const TextStyle(
                            fontSize: 14, color: AmColors.muted),
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: AmColors.chip,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        onSubmitted: (_) => doSearch(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      color: AmColors.accent,
                      borderRadius: BorderRadius.circular(11),
                      onPressed: busy ? null : doSearch,
                      child: const Text('Buscar',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0B0E12))),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Transform.scale(
                      scale: 0.68,
                      child: CupertinoSwitch(
                        value: permissiveOnly,
                        activeTrackColor: AmColors.accent,
                        onChanged: (v) =>
                            setSheetState(() => permissiveOnly = v),
                      ),
                    ),
                    const Text('So conjuntos sem exigencia de credito',
                        style: TextStyle(
                            fontSize: 12, color: AmColors.muted)),
                  ],
                ),
                Text(status,
                    style: const TextStyle(
                        fontSize: 12, color: AmColors.muted)),
                const SizedBox(height: 8),
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final (prefix, name) = results[i];
                      final d = paths['$prefix:$name'];
                      final lic = service.licenseOf(prefix);
                      return GestureDetector(
                        onTap: d == null
                            ? null
                            : () {
                                controller.addIconLayer(
                                    playhead, d, name);
                                Navigator.of(sheetContext).pop();
                              },
                        child: Column(
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: AmColors.chip,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: d == null
                                  ? null
                                  : CustomPaint(
                                      painter: _IconPreviewPainter(d)),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              lic.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 8,
                                  color: lic.permissive
                                      ? AmColors.muted
                                      : const Color(0xFFFFB020)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  queryController.dispose();
}

class _IconPreviewPainter extends CustomPainter {
  _IconPreviewPainter(this.pathData);

  final String pathData;
  ui.Path? _cache;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _cache ??=
        fitPathToBox(parseSvgPathData(pathData), size.shortestSide * 0.7);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.drawPath(path, Paint()..color = AmColors.accent);
  }

  @override
  bool shouldRepaint(_IconPreviewPainter old) =>
      old.pathData != pathData;
}

/// Legendas: transcricao automatica no aparelho (Whisper) ou SRT colado.
Future<void> _showSrtSheet(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(editorControllerProvider.notifier);
  final textController = TextEditingController();
  var busy = false;
  var status = '';
  var mode = CaptionMode.frases;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AmColors.panel,
    isScrollControlled: true,
    isDismissible: false,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, 16 + MediaQuery.of(sheetContext).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Legendas',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AmColors.text)),
                ),
                if (!busy)
                  GestureDetector(
                    onTap: () => Navigator.of(sheetContext).pop(),
                    child: const Icon(CupertinoIcons.xmark,
                        size: 18, color: AmColors.muted),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Config da legenda: como o texto e segmentado no tempo.
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in CaptionMode.values)
                  GestureDetector(
                    onTap: busy
                        ? null
                        : () => setSheetState(() => mode = m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: mode == m
                            ? AmColors.accentDim
                            : AmColors.chip,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(captionModeLabel(m),
                          style: const TextStyle(
                              fontSize: 12, color: AmColors.accent)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Whisper on-device: analisa o audio do video do projeto.
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: AmColors.accent,
                borderRadius: BorderRadius.circular(12),
                onPressed: busy
                    ? null
                    : () async {
                        final media =
                            controller.firstTranscribableMediaPath();
                        if (media == null) {
                          setSheetState(() => status =
                              'Adicione um video ao projeto primeiro.');
                          return;
                        }
                        setSheetState(() {
                          busy = true;
                          status = 'Preparando...';
                        });
                        try {
                          final cues = await ref
                              .read(transcriptionServiceProvider)
                              .transcribeMedia(
                                media,
                                mode: mode,
                                onStatus: (s) =>
                                    setSheetState(() => status = s),
                              );
                          final n = controller.addCaptionLayer(cues);
                          if (sheetContext.mounted) {
                            if (n == 0) {
                              setSheetState(() {
                                busy = false;
                                status =
                                    'Nenhuma fala detectada no audio.';
                              });
                            } else {
                              Navigator.of(sheetContext).pop();
                            }
                          }
                        } catch (e) {
                          setSheetState(() {
                            busy = false;
                            status = 'Erro ao transcrever: $e';
                          });
                        }
                      },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (busy)
                      const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: CupertinoActivityIndicator(
                            color: Color(0xFF0B0E12)),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(CupertinoIcons.waveform,
                            size: 18, color: Color(0xFF0B0E12)),
                      ),
                    Text(
                      busy
                          ? 'Transcrevendo...'
                          : 'Transcrever com Whisper (no aparelho)',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0B0E12)),
                    ),
                  ],
                ),
              ),
            ),
            if (status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(status,
                    style: const TextStyle(
                        fontSize: 12, color: AmColors.muted)),
              ),
            const SizedBox(height: 14),
            const Text('ou cole um SRT:',
                style: TextStyle(fontSize: 12, color: AmColors.muted)),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: textController,
              maxLines: 6,
              minLines: 3,
              enabled: !busy,
              placeholder:
                  '1\n00:00:00,000 --> 00:00:02,000\nSua primeira fala...',
              style: const TextStyle(fontSize: 13, color: AmColors.text),
              placeholderStyle:
                  const TextStyle(fontSize: 13, color: AmColors.muted),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AmColors.chip,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: CupertinoButton(
                color: AmColors.chip,
                borderRadius: BorderRadius.circular(12),
                onPressed: busy
                    ? null
                    : () {
                        controller
                            .addCaptionLayerFromSrt(textController.text);
                        Navigator.of(sheetContext).pop();
                      },
                child: const Text('Criar do SRT colado',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AmColors.accent)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  textController.dispose();
}

class _AddOption extends StatelessWidget {
  const _AddOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.35,
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AmColors.chip,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AmColors.accent, size: 24),
              ),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AmColors.text)),
            ],
          ),
        ),
      ),
    );
  }
}
