import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_mode.dart';
import '../../../../core/feature_access.dart';
import '../../application/editor_controller.dart';
import '../../application/iconify_service.dart';
import '../../application/transcription_service.dart';
import '../../domain/caption.dart';
import '../../domain/element3d.dart';
import '../../domain/layer.dart';
import '../../domain/keyframe.dart';
import '../../domain/shape.dart';
import '../../domain/shape_library.dart';
import '../am/points_panel.dart' show editPointsRequestProvider;
import 'freehand_overlay.dart' show freehandRequestProvider;
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
  final completo = ref.read(appModeProvider).isFull;
  final shapes = ref.read(featureAccessProvider(LaboratoryLevelId.shapes));
  final text = ref.read(featureAccessProvider(LaboratoryLevelId.text));
  final captions = ref.read(featureAccessProvider(LaboratoryLevelId.captions));
  final scene3d = ref.read(featureAccessProvider(LaboratoryLevelId.scene3d));
  final nullAndClone = ref.read(
    featureAccessProvider(LaboratoryLevelId.nullAndClone),
  );
  final menuPorTipo =
      completo || shapes || text || captions || scene3d || nullAndClone;
  final controller = ref.read(editorControllerProvider.notifier);
  // FORMA NA MESMA FOLHA. Criar um retangulo era "+", folha de tipos,
  // OUTRA folha com quinze formas, toque — e a segunda folha subindo por
  // cima da primeira era o que fazia parecer que o app tinha "camadas
  // demais" para uma coisa simples. Agora "Forma" troca o conteudo da
  // mesma folha por quatro formas basicas; o resto fica atras de "Mais".
  var mostrarFormas = false;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AmColors.panel,
    isScrollControlled: menuPorTipo,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // O FECHAR mora no cabecalho, ao lado da alca, e nao no fim
              // do trilho: la ele obrigava o trilho a ser mais alto que o
              // conteudo, e era o trilho que definia a altura da folha.
              Row(
                children: [
                  const SizedBox(width: 28),
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 34,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(sheetContext).pop(),
                    child: const SizedBox(
                      width: 28,
                      height: 28,
                      child: Icon(CupertinoIcons.xmark,
                          size: 20, color: AmColors.accent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (menuPorTipo)
                _AddMenuAm(
                  sheetContext: sheetContext,
                  ref: ref,
                  playhead: playhead,
                  fullStudio: completo,
                  shapesEnabled: shapes,
                  textEnabled: text,
                  captionsEnabled: captions,
                  scene3dEnabled: scene3d,
                  nullAndCloneEnabled: nullAndClone,
                )
              else if (mostrarFormas)
                _SecaoFormas(
                  onVoltar: () => setSheetState(() => mostrarFormas = false),
                  onEscolher: (build, nome) {
                    Navigator.of(sheetContext).pop();
                    controller.addShapeLayer(
                      playhead,
                      contents: build(),
                      name: nome,
                    );
                  },
                )
              else ...[
                const Text(
                  'Adicionar camada',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AmColors.text,
                  ),
                ),
                const SizedBox(height: 18),
                // NUCLEO: video, imagem e audio. O resto so no estudio
                // completo (interruptor AppMode).
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
                    if (completo)
                      _AddOption(
                        icon: CupertinoIcons.textformat,
                        label: 'Texto',
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          controller.addTextLayer(playhead);
                        },
                      ),
                    if (completo)
                      _AddOption(
                        icon: CupertinoIcons.circle_fill,
                        label: 'Forma',
                        onTap: () => setSheetState(() => mostrarFormas = true),
                      ),
                    if (completo)
                      _AddOption(
                        icon: CupertinoIcons.captions_bubble,
                        label: 'Legendas',
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          showCaptionCreationSheet(context, ref);
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
                    if (!completo) const Spacer(flex: 3),
                  ],
                ),
                if (completo) const SizedBox(height: 12),
                if (completo)
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
            ],
          ),
        ),
      ),
    ),
  );
}

/// Aba ELEMENTOS 3D: solidos nativos (cubo, esfera, diamante...) que
/// giram de verdade no espaco e se vinculam a nulos como qualquer
/// camada. Cada tile mostra o proprio solido renderizado.
Future<void> _showElement3DPickerSheet(
  BuildContext context,
  WidgetRef ref,
  Duration playhead,
) async {
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
            const Text(
              'Elementos 3D',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AmColors.text,
              ),
            ),
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
                          Text(
                            element3DLabel(kind),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AmColors.text,
                            ),
                          ),
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

/// FORMAS, na mesma folha: as quatro basicas na frente, o resto atras de
/// "Mais formas". Um toque cria a camada e fecha.
class _SecaoFormas extends StatefulWidget {
  const _SecaoFormas({required this.onVoltar, required this.onEscolher});

  final VoidCallback onVoltar;
  final void Function(List<ShapeItem> Function() build, String nome) onEscolher;

  @override
  State<_SecaoFormas> createState() => _SecaoFormasState();
}

class _SecaoFormasState extends State<_SecaoFormas> {
  bool _mais = false;

  static final _basicas = <(String, IconData, List<ShapeItem> Function())>[
    ('Retangulo', CupertinoIcons.square_fill, ShapePresets.paramRect),
    ('Circulo', CupertinoIcons.circle_fill, ShapePresets.paramEllipse),
    ('Poligono', CupertinoIcons.hexagon_fill, ShapePresets.paramPolygon),
    ('Estrela', CupertinoIcons.star_fill, ShapePresets.paramStar),
  ];

  static final _outras = <(String, IconData, List<ShapeItem> Function())>[
    ('Anel', CupertinoIcons.circle, ShapePresets.paramRing),
    ('Setor', CupertinoIcons.moon, ShapePresets.paramSector),
    ('Onda', CupertinoIcons.waveform_path, ShapePresets.wave),
    ('Coracao', CupertinoIcons.heart_fill, ShapePresets.heart),
    ('Engrenagem', CupertinoIcons.gear_alt_fill, ShapePresets.gear),
    ('Seta', CupertinoIcons.arrow_right, ShapePresets.arrow),
    ('Check', CupertinoIcons.checkmark, ShapePresets.check),
    ('Faisca', CupertinoIcons.sparkles, ShapePresets.sparkle),
    ('Gota', CupertinoIcons.drop_fill, ShapePresets.drop),
    ('Flor', CupertinoIcons.smallcircle_circle, ShapePresets.flower),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: widget.onVoltar,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(
                  CupertinoIcons.chevron_back,
                  size: 22,
                  color: AmColors.text,
                ),
              ),
            ),
            const Text(
              'Forma',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AmColors.text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final (nome, icone, build) in _basicas)
              _AddOption(
                icon: icone,
                label: nome,
                onTap: () => widget.onEscolher(build, nome),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (!_mais)
          GestureDetector(
            onTap: () => setState(() => _mais = true),
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Mais formas',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AmColors.accent,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    CupertinoIcons.chevron_down,
                    size: 14,
                    color: AmColors.accent,
                  ),
                ],
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (nome, icone, build) in _outras)
                GestureDetector(
                  onTap: () => widget.onEscolher(build, nome),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AmColors.chip,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icone, size: 15, color: AmColors.accent),
                        const SizedBox(width: 6),
                        Text(
                          nome,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AmColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Aba de ICONES (Iconify): busca com filtro de licenca; o icone entra na
/// cena como FORMA vetorial editavel, nunca como imagem.
Future<void> _showIconSheet(
  BuildContext context,
  WidgetRef ref,
  Duration playhead,
) async {
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
            final found = await service.search(
              q,
              permissiveOnly: permissiveOnly,
            );
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
            padding: EdgeInsets.fromLTRB(
              18,
              14,
              18,
              14 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Icones (Iconify)',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AmColors.text,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: CupertinoTextField(
                        controller: queryController,
                        placeholder: 'buscar...',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AmColors.text,
                        ),
                        placeholderStyle: const TextStyle(
                          fontSize: 14,
                          color: AmColors.muted,
                        ),
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
                        horizontal: 16,
                        vertical: 10,
                      ),
                      color: AmColors.accent,
                      borderRadius: BorderRadius.circular(11),
                      onPressed: busy ? null : doSearch,
                      child: const Text(
                        'Buscar',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0B0E12),
                        ),
                      ),
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
                    const Text(
                      'So conjuntos sem exigencia de credito',
                      style: TextStyle(fontSize: 12, color: AmColors.muted),
                    ),
                  ],
                ),
                Text(
                  status,
                  style: const TextStyle(fontSize: 12, color: AmColors.muted),
                ),
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
                                controller.addIconLayer(playhead, d, name);
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
                                      painter: _IconPreviewPainter(d),
                                    ),
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
                                    : const Color(0xFFFFB020),
                              ),
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
    final path = _cache ??= fitPathToBox(
      parseSvgPathData(pathData),
      size.shortestSide * 0.7,
    );
    canvas.translate(size.width / 2, size.height / 2);
    canvas.drawPath(path, Paint()..color = AmColors.accent);
  }

  @override
  bool shouldRepaint(_IconPreviewPainter old) => old.pathData != pathData;
}

/// Legendas: transcricao automatica no aparelho (Whisper) ou SRT colado.
Future<void> showCaptionCreationSheet(
  BuildContext context,
  WidgetRef ref,
) async {
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
          20,
          16,
          20,
          16 + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Legendas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AmColors.text,
                    ),
                  ),
                ),
                if (!busy)
                  GestureDetector(
                    onTap: () => Navigator.of(sheetContext).pop(),
                    child: const Icon(
                      CupertinoIcons.xmark,
                      size: 18,
                      color: AmColors.muted,
                    ),
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
                    onTap: busy ? null : () => setSheetState(() => mode = m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: mode == m ? AmColors.accentDim : AmColors.chip,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        captionModeLabel(m),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AmColors.accent,
                        ),
                      ),
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
                        final media = controller.firstTranscribableMediaPath();
                        if (media == null) {
                          setSheetState(
                            () => status =
                                'Adicione um video ao projeto primeiro.',
                          );
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
                                status = 'Nenhuma fala detectada no audio.';
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
                          color: Color(0xFF0B0E12),
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(
                          CupertinoIcons.waveform,
                          size: 18,
                          color: Color(0xFF0B0E12),
                        ),
                      ),
                    Text(
                      busy
                          ? 'Transcrevendo...'
                          : 'Transcrever com Whisper (no aparelho)',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0B0E12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  status,
                  style: const TextStyle(fontSize: 12, color: AmColors.muted),
                ),
              ),
            const SizedBox(height: 14),
            const Text(
              'ou cole um SRT:',
              style: TextStyle(fontSize: 12, color: AmColors.muted),
            ),
            const SizedBox(height: 8),
            CupertinoTextField(
              controller: textController,
              maxLines: 6,
              minLines: 3,
              enabled: !busy,
              placeholder:
                  '1\n00:00:00,000 --> 00:00:02,000\nSua primeira fala...',
              style: const TextStyle(fontSize: 13, color: AmColors.text),
              placeholderStyle: const TextStyle(
                fontSize: 13,
                color: AmColors.muted,
              ),
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
                        controller.addCaptionLayerFromSrt(textController.text);
                        Navigator.of(sheetContext).pop();
                      },
                child: const Text(
                  'Criar do SRT colado',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AmColors.accent,
                  ),
                ),
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AmColors.chip,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, color: AmColors.accent, size: 28),
              ),
              const SizedBox(height: 6),
              // 12 e nao 13: em 13 o rotulo mais longo (Elementos 3D)
              // quebra em duas linhas e a fileira inteira cresce com ele,
              // empurrando a folha por cima da linha do tempo.
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AmColors.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// As abas do menu de adicionar (modelo Alight Motion).
enum _AbaAdd { forma, midia, audio, objeto, modelo }

/// MENU DE ADICIONAR NO MODELO AM: abas horizontais (Forma · Midia ·
/// Audio · Objeto/Elemento · Modelo) e um trilho vertical a direita com
/// os MODOS de criar (Desenho livre · Desenho vetorial · Texto · fechar)
/// — desenho e texto nao sao itens de escolher, sao jeitos de comecar.
/// A grade de formas tem 7 por linha, 3 linhas, em paginas, e cada tile
/// mostra a forma de verdade.
class _AddMenuAm extends ConsumerStatefulWidget {
  const _AddMenuAm({
    required this.sheetContext,
    required this.ref,
    required this.playhead,
    required this.fullStudio,
    required this.shapesEnabled,
    required this.textEnabled,
    required this.captionsEnabled,
    required this.scene3dEnabled,
    required this.nullAndCloneEnabled,
  });

  final BuildContext sheetContext;
  final WidgetRef ref;
  final Duration playhead;
  final bool fullStudio;
  final bool shapesEnabled;
  final bool textEnabled;
  final bool captionsEnabled;
  final bool scene3dEnabled;
  final bool nullAndCloneEnabled;

  @override
  ConsumerState<_AddMenuAm> createState() => _AddMenuAmState();
}

class _AddMenuAmState extends ConsumerState<_AddMenuAm> {
  _AbaAdd _aba = _AbaAdd.forma;
  int _pagina = 0;
  final _pager = PageController();

  /// Cinco por fileira, tres fileiras. Eram sete por fileira: numa tela
  /// de celular isso dava tiles de 40 px, pequenos demais para reconhecer
  /// a forma e pequenos demais para acertar o toque.
  static const int _porLinha = 5;
  static const int _linhas = 3;
  static const int _porPagina = _porLinha * _linhas;

  EditorController get _controller =>
      ref.read(editorControllerProvider.notifier);

  List<_AbaAdd> get _abasVisiveis => [
    if (widget.shapesEnabled) _AbaAdd.forma,
    _AbaAdd.midia,
    _AbaAdd.audio,
    if (widget.fullStudio ||
        widget.scene3dEnabled ||
        widget.nullAndCloneEnabled)
      _AbaAdd.objeto,
    if (widget.fullStudio) _AbaAdd.modelo,
  ];

  _AbaAdd get _abaVisivel =>
      _abasVisiveis.contains(_aba) ? _aba : _abasVisiveis.first;

  void _fecha() => Navigator.of(widget.sheetContext).pop();

  /// Cria a camada e devolve o id dela (a nova e a que nao existia).
  String? _criaForma(List<ShapeItem> Function() build, String nome) {
    final antes = {
      for (final l in ref.read(editorControllerProvider).layers) l.id,
    };
    _controller.addShapeLayer(widget.playhead, contents: build(), name: nome);
    for (final l in ref.read(editorControllerProvider).layers) {
      if (!antes.contains(l.id)) return l.id;
    }
    return null;
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A FOLHA TEM A ALTURA DO QUE HA DENTRO DELA.
    //
    // Antes era uma fracao fixa da tela (40%, no minimo 300 px): a aba de
    // Objeto tem duas fileiras e sobrava meia tela vazia embaixo, e a
    // folha cobria a linha do tempo — que a regra 4 diz que nunca pode
    // ser coberta. Sem altura fixa, cada aba ocupa o que precisa, e o que
    // era espaco morto virou tamanho de item.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _abas(),
              const SizedBox(height: 12),
              _conteudo(),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _trilho(),
      ],
    );
  }

  Widget _abas() {
    const nomes = {
      _AbaAdd.forma: 'Forma',
      _AbaAdd.midia: 'Midia',
      _AbaAdd.audio: 'Audio',
      _AbaAdd.objeto: 'Objeto',
      _AbaAdd.modelo: 'Modelo',
    };
    return SizedBox(
      height: 36,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final a in _abasVisiveis)
              GestureDetector(
                onTap: () => setState(() => _aba = a),
                child: Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _abaVisivel == a
                        ? AmColors.accentDim
                        : AmColors.chip,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    nomes[a]!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _abaVisivel == a ? AmColors.accent : AmColors.text,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _trilho() {
    Widget item(IconData icon, String label, VoidCallback onTap) =>
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 24, color: AmColors.accent),
                const SizedBox(height: 3),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.15,
                    color: AmColors.muted,
                  ),
                ),
              ],
            ),
          ),
        );
    return SizedBox(
      width: 66,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.shapesEnabled) ...[
            item(CupertinoIcons.scribble, 'Desenho\nlivre', () {
              _fecha();
              ref.read(freehandRequestProvider.notifier).state = true;
            }),
            item(CupertinoIcons.pencil_outline, 'Desenho\nvetorial', () {
              final id = _criaForma(
                () => [
                  ShapeStroke(
                    color: const Color(0xFFFFFFFF),
                    width: AnimatedDouble(10),
                  ),
                ],
                'Desenho',
              );
              _fecha();
              if (id != null) {
                ref.read(editPointsRequestProvider.notifier).state = id;
              }
            }),
          ],
          if (widget.textEnabled)
            item(CupertinoIcons.textformat, 'Texto', () {
              _fecha();
              _controller.addTextLayer(widget.playhead);
            }),
        ],
      ),
    );
  }

  Widget _conteudo() {
    switch (_abaVisivel) {
      case _AbaAdd.forma:
        return _formas();
      case _AbaAdd.midia:
        // _AddOption e um Expanded: so vive dentro de Row.
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AddOption(
              icon: CupertinoIcons.videocam_fill,
              label: 'Video',
              onTap: () {
                _fecha();
                _controller.importVideoFromGallery(widget.playhead);
              },
            ),
            _AddOption(
              icon: CupertinoIcons.photo_fill,
              label: 'Imagem',
              onTap: () {
                _fecha();
                _controller.importImageFromGallery(widget.playhead);
              },
            ),
            if (widget.captionsEnabled)
              _AddOption(
                icon: CupertinoIcons.captions_bubble,
                label: 'Legendas',
                onTap: () {
                  _fecha();
                  showCaptionCreationSheet(context, widget.ref);
                },
              ),
            const Spacer(flex: 3),
          ],
        );
      case _AbaAdd.audio:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AddOption(
              icon: CupertinoIcons.music_note,
              label: 'Audio',
              onTap: () {
                _fecha();
                _controller.importAudioFile(widget.playhead);
              },
            ),
            const Spacer(flex: 5),
          ],
        );
      case _AbaAdd.objeto:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (widget.nullAndCloneEnabled)
                  _AddOption(
                    icon: CupertinoIcons.viewfinder,
                    label: 'Nulo 3D',
                    onTap: () {
                      _fecha();
                      _controller.addNullLayer(widget.playhead);
                    },
                  ),
                if (widget.fullStudio)
                  _AddOption(
                    icon: CupertinoIcons.sparkles,
                    label: 'Particulas',
                    onTap: () {
                      _fecha();
                      _controller.addParticlesLayer(widget.playhead);
                    },
                  ),
                if (widget.fullStudio)
                  _AddOption(
                    icon: CupertinoIcons.square_grid_2x2,
                    label: 'Icones',
                    onTap: () {
                      _fecha();
                      _showIconSheet(context, widget.ref, widget.playhead);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                if (widget.fullStudio)
                  _AddOption(
                    icon: CupertinoIcons.slider_horizontal_3,
                    label: 'Ajuste',
                    onTap: () {
                      _fecha();
                      _controller.addAdjustmentLayer(widget.playhead);
                    },
                  ),
                if (widget.scene3dEnabled)
                  _AddOption(
                    icon: CupertinoIcons.cube,
                    label: 'Elementos 3D',
                    onTap: () {
                      _fecha();
                      _showElement3DPickerSheet(
                        context,
                        widget.ref,
                        widget.playhead,
                      );
                    },
                  ),
                if (widget.scene3dEnabled)
                  _AddOption(
                    icon: CupertinoIcons.cube_box,
                    label: 'Cena 3D',
                    onTap: () {
                      _fecha();
                      _controller.addScene3DLayer(widget.playhead);
                    },
                  ),
              ],
            ),
          ],
        );
      case _AbaAdd.modelo:
        return const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            'Modelos prontos abrem pela tela inicial (Modelos) como um '
            'projeto novo, camada por camada. Templates em arquivo (.json) '
            'tambem entram por la.',
            style: TextStyle(fontSize: 13, color: AmColors.muted, height: 1.4),
          ),
        );
    }
  }

  Widget _formas() {
    final total = shapeLibrary.length;
    final paginas = (total / _porPagina).ceil();
    // A altura sai da largura: cinco tiles quadrados por fileira, tres
    // fileiras. Medir em vez de chutar e o que permite a folha encolher.
    return LayoutBuilder(builder: (context, limites) {
      final tile = (limites.maxWidth - 6 * (_porLinha - 1)) / _porLinha;
      final altura = tile * _linhas + 6 * (_linhas - 1) + 20;
      return SizedBox(
        height: altura,
        child: Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pager,
            itemCount: paginas,
            onPageChanged: (i) => setState(() => _pagina = i),
            itemBuilder: (context, pagina) {
              final ini = pagina * _porPagina;
              final fim = (ini + _porPagina).clamp(0, total);
              return GridView.count(
                crossAxisCount: _porLinha,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (var i = ini; i < fim; i++)
                    _TileForma(
                      entrada: shapeLibrary[i],
                      onTap: () {
                        final e = shapeLibrary[i];
                        _criaForma(e.build, e.nome);
                        _fecha();
                      },
                    ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < paginas; i++)
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == _pagina ? AmColors.accent : AmColors.muted,
                ),
              ),
          ],
        ),
      ],
        ),
      );
    });
  }
}

/// Um tile da grade: a forma desenhada, do tamanho do tile.
class _TileForma extends StatelessWidget {
  const _TileForma({required this.entrada, required this.onTap});

  final ShapeLibraryEntry entrada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final itens = entrada.build();
    return Tooltip(
      message: entrada.nome,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AmColors.chip,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(7),
            child: CustomPaint(
              painter: _FormaPainter(
                shapeLibraryPreviewPath(itens),
                stroke: shapeLibraryIsStrokeOnly(itens),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormaPainter extends CustomPainter {
  const _FormaPainter(this.path, {required this.stroke});

  final Path path;
  final bool stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final b = path.getBounds();
    // A linha tem altura zero: o que conta e o lado maior.
    if (b.longestSide <= 0) return;
    final k = 0.9 * (size.shortestSide / b.longestSide);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(k, k);
    canvas.translate(-b.center.dx, -b.center.dy);
    // Anel, padrao de pontos: o furo e um subcaminho — par-impar.
    path.fillType = PathFillType.evenOdd;
    final paint = Paint()..color = AmColors.accent;
    if (stroke) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14 / k
        ..strokeCap = StrokeCap.round;
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_FormaPainter old) => old.path != path;
}
