import 'dart:math' as math;
import 'dart:ui' as ui;

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/editor_controller.dart';
import '../../application/iconify_service.dart';
import '../../application/transcription_service.dart';
import '../../application/transcricao_em_andamento.dart';
import '../../../settings/application/settings_controller.dart';
import '../../domain/caption.dart';
import '../../domain/scene3d.dart';
import '../../domain/element3d.dart';
import '../../domain/layer.dart';
import '../../domain/keyframe.dart';
import '../../../../core/ui/snack.dart';
import '../../domain/shape.dart';
import '../../domain/svg_document.dart';
import '../../domain/shape_library.dart';
import '../am/points_panel.dart' show editPointsRequestProvider;
import 'freehand_overlay.dart' show freehandRequestProvider;
import '../../domain/svg_path.dart';
import '../am/am_colors.dart';
import '../am/am_widgets.dart';
import 'element3d_painter.dart';
import 'gallery_panel.dart';
import '../context/add_toolbar.dart' show AddTarget;

/// Sheet "+" do editor: escolher o tipo de camada.
Future<void> showAddLayerSheet(
  BuildContext context,
  WidgetRef ref,
  Duration playhead,
) {
  // FORMA NA MESMA FOLHA. Criar um retangulo era "+", folha de tipos,
  // OUTRA folha com quinze formas, toque — e a segunda folha subindo por
  // cima da primeira era o que fazia parecer que o app tinha "camadas
  // demais" para uma coisa simples. Agora "Forma" troca o conteudo da
  // mesma folha por quatro formas basicas; o resto fica atras de "Mais".
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AmColors.panel,
    isScrollControlled: true,
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
                      child: Icon(
                        CupertinoIcons.xmark,
                        size: 20,
                        color: AmColors.accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                // A FOLHA NAO PODE COBRIR A LINHA DO TEMPO.
                //
                // A altura fixa de 270 nasceu de um aparelho grande. Numa
                // tela baixa a folha passava de 40% dela, e o que fica
                // atras — a timeline — e justamente o que a pessoa esta
                // olhando quando escolhe onde inserir a camada. A grade
                // encolhe antes de a folha invadir.
                height: math.min(
                  270.0,
                  MediaQuery.sizeOf(context).height * 0.31,
                ),
                child: AddLayerPanel(
                  onClose: () => Navigator.of(sheetContext).pop(),
                  playhead: playhead,
                ),
              ),
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
                                closeParamSheet(sheetContext);
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

/// Legendas: transcricao automatica — na nuvem (Groq Whisper, pelo
/// servidor do Aurea) ou no aparelho (whisper.cpp) — ou SRT colado.
///
/// A transcricao nao trava o editor: roda num [TranscricaoEmAndamento]
/// que sobrevive ao fechamento desta folha. Quem fecha a folha no meio
/// ve a camada de legenda aparecer na timeline quando ficar pronta; quem
/// reabre ve o andamento (ou o erro) de onde parou.
///
/// O audio so sai do aparelho quando a pessoa toca em Transcrever com a
/// nuvem escolhida — nunca sozinho.
Future<void> showCaptionCreationSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final controller = ref.read(editorControllerProvider.notifier);
  final textController = TextEditingController();
  final job = TranscricaoEmAndamento.instance;
  // Uma transcricao pronta de antes ja virou camada: comeca limpo.
  if (job.estado.value is TranscricaoPronta) job.limpar();
  var mode = CaptionMode.frases;
  var modo = ref.read(settingsControllerProvider).modoDeTranscricao;

  Future<void> transcrever(
    BuildContext sheetContext, {
    ModoDeTranscricao? forcar,
  }) async {
    final media = controller.firstTranscribableMediaPath();
    if (media == null) {
      job.falhar('Adicione um vídeo ao projeto primeiro.');
      return;
    }
    final entrou = await job.rodar(
      () => ref
          .read(transcriptionServiceProvider)
          .transcribeMedia(
            media,
            mode: mode,
            modo: forcar ?? modo,
            onStatus: job.status,
          ),
      aoTerminar: (falas) => controller.addCaptionLayer(falas) == 0
          ? 'Nenhuma fala detectada no áudio.'
          : null,
    );
    // Deu certo e a folha ainda esta aberta: fecha. Se a pessoa a fechou
    // no meio, a camada ja esta na timeline.
    if (entrou && sheetContext.mounted) Navigator.of(sheetContext).pop();
  }

  Widget chip({
    Key? key,
    required String rotulo,
    required bool selected,
    required VoidCallback? onTap,
  }) => GestureDetector(
    key: key,
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? AmColors.accentDim : AmColors.chip,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        rotulo,
        style: const TextStyle(fontSize: 12, color: AmColors.accent),
      ),
    ),
  );

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AmColors.panel,
    isScrollControlled: true,
    builder: (sheetContext) => ValueListenableBuilder<EstadoDaTranscricao>(
      valueListenable: job.estado,
      builder: (sheetContext, estado, _) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final busy = estado is TranscricaoRodando;
          final falha = estado is TranscricaoFalhou ? estado : null;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              16,
              20,
              16 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: SingleChildScrollView(
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
                        chip(
                          rotulo: captionModeLabel(m),
                          selected: mode == m,
                          onTap: busy
                              ? null
                              : () => setSheetState(() => mode = m),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // ONDE TRANSCREVER. A escolha fica nos Ajustes tambem;
                  // aqui e onde ela importa.
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final m in ModoDeTranscricao.values)
                        chip(
                          key: ValueKey('transcricao-modo-${m.name}'),
                          rotulo: m.emPalavras,
                          selected: modo == m,
                          onTap: busy
                              ? null
                              : () {
                                  setSheetState(() => modo = m);
                                  ref
                                      .read(settingsControllerProvider.notifier)
                                      .setModoDeTranscricao(m);
                                },
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    modo.explicacao,
                    style: const TextStyle(fontSize: 11, color: AmColors.muted),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      key: const ValueKey('transcrever'),
                      color: AmColors.accent,
                      borderRadius: BorderRadius.circular(12),
                      onPressed: busy ? null : () => transcrever(sheetContext),
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
                            busy ? 'Transcrevendo...' : 'Transcrever',
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
                  if (estado is TranscricaoRodando) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        estado.status,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AmColors.muted,
                        ),
                      ),
                    ),
                    // NAO TRAVA O EDITOR: da para fechar e continuar
                    // mexendo; a legenda entra na timeline quando ficar
                    // pronta.
                    CupertinoButton(
                      key: const ValueKey('segundo-plano'),
                      padding: EdgeInsets.zero,
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text(
                        'Continuar em segundo plano',
                        style: TextStyle(fontSize: 12, color: AmColors.accent),
                      ),
                    ),
                  ],
                  if (falha != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        falha.mensagem,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AmColors.pink,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (!falha.semInternet)
                          chip(
                            key: const ValueKey('tentar-de-novo'),
                            rotulo: 'Tentar de novo',
                            selected: false,
                            onTap: () => transcrever(sheetContext),
                          ),
                        if (falha.ofereceLocal)
                          chip(
                            key: const ValueKey('usar-local'),
                            rotulo: 'Usar o Whisper do aparelho',
                            selected: true,
                            onTap: () => transcrever(
                              sheetContext,
                              forcar: ModoDeTranscricao.local,
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (estado is TranscricaoPronta)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Legendas prontas: ${estado.falas} falas.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AmColors.accent,
                        ),
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
                    placeholder: '1\n00:00:00,000 --> 00:00:02,000\nSua primeira fala...',
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
                              controller.addCaptionLayerFromSrt(
                                textController.text,
                              );
                              Navigator.of(sheetContext).pop();
                            },
                      child: const Text(
                        'Criar do SRT colado',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AmColors.text,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
enum _AbaAdd { forma, midia, audio, objeto, mais }

/// MENU DE ADICIONAR NO MODELO AM: abas horizontais (Forma · Midia ·
/// Audio · Objeto · Modelo) e um trilho vertical a direita com os MODOS
/// de criar (Desenho livre · Desenho vetorial · Texto) — desenho e texto
/// nao sao itens de escolher, sao jeitos de comecar.
/// A aba em que o menu de adicionar abre (o E1 aponta para uma delas).
enum AddTab { forma, midia, audio, objeto }

class AddLayerPanel extends ConsumerStatefulWidget {
  const AddLayerPanel({
    super.key,
    required this.onClose,
    required this.playhead,
    this.initialTab,
    this.onProjectAction,
  });

  final VoidCallback onClose;
  final Duration playhead;
  final AddTab? initialTab;
  final ValueChanged<AddTarget>? onProjectAction;

  @override
  ConsumerState<AddLayerPanel> createState() => _AddMenuAmState();
}

class _AddMenuAmState extends ConsumerState<AddLayerPanel> {
  bool _importingAudio = false;

  Future<void> _importAudio({bool fromVideo = false}) async {
    if (_importingAudio) return;
    setState(() => _importingAudio = true);
    final controller = _controller;
    final at = widget.playhead;
    try {
      await controller.importAudioFile(at, fromVideo: fromVideo);
      if (mounted) _fecha();
    } catch (error) {
      if (mounted) {
        AureaSnack.show(
          context,
          error is FormatException
              ? error.message.toString()
              : 'Nao consegui importar esse audio. Tente outro arquivo.',
        );
      }
    } finally {
      if (mounted) setState(() => _importingAudio = false);
    }
  }

  late _AbaAdd _aba = switch (widget.initialTab) {
    AddTab.midia => _AbaAdd.midia,
    AddTab.audio => _AbaAdd.audio,
    AddTab.objeto => _AbaAdd.objeto,
    AddTab.forma || null => _AbaAdd.forma,
  };
  int _pagina = 0;
  final _pager = PageController();

  /// O QUE A FAIXA DO RODAPE ESTA EXPLICANDO AGORA.
  ///
  /// Objeto conceitual precisa de explicacao; forma nao precisa — o icone
  /// ja diz tudo. Descricao fixa no card ensina na primeira vez e vira
  /// ruido na centesima, entao ela mora numa faixa fina que mostra o item
  /// sob o dedo. Nulo quando ninguem esta segurando nada.
  String? _explicando;

  /// Six silhouettes per row, as in the supplied reference.
  static const int _porLinha = 6;
  static const int _linhas = 3;
  static const int _porPagina = _porLinha * _linhas;

  EditorController get _controller =>
      ref.read(editorControllerProvider.notifier);

  /// Toda funcionalidade esta no aplicativo: as abas nao dependem de
  /// interruptor nenhum.
  List<_AbaAdd> get _abasVisiveis => _AbaAdd.values;

  void _fecha() => widget.onClose();

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

  /// A cena 3D da composicao, se houver. Camera e Luz so fazem sentido
  /// dentro de uma — fora dela seriam controles inertes.
  Scene3DLayer? get _cena {
    for (final l in ref.read(editorControllerProvider).layers) {
      if (l is Scene3DLayer) return l;
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
    return ColoredBox(
      color: AmColors.panel,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              children: [
                _abas(),
                Expanded(
                  child: _abaVisivel == _AbaAdd.midia
                      ? _conteudo()
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(6),
                          child: _conteudo(),
                        ),
                ),
                if (_abaVisivel == _AbaAdd.objeto && _explicando != null)
                  _faixaDeDescricao(),
              ],
            ),
          ),
          SizedBox(
            width: 52,
            child: Column(
              children: [
                _atalho(CupertinoIcons.scribble, 'Desenho à\nmão livre', () {
                  _fecha();
                  ref.read(freehandRequestProvider.notifier).state = true;
                }),
                _atalho(CupertinoIcons.pencil_outline, 'Desenho\nvetorial', () {
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
                _atalho(CupertinoIcons.textformat, 'Texto', () {
                  _fecha();
                  _controller.addTextLayer(widget.playhead);
                }),
                SizedBox(
                  height: 44,
                  child: IconButton(
                    tooltip: 'Fechar adicionar',
                    onPressed: _fecha,
                    icon: const Icon(
                      CupertinoIcons.xmark,
                      size: 20,
                      color: AmColors.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A FAIXA DE DESCRICAO — a peca que deixa os cards compactos sem
  /// perder a didatica. Nunca fica vazia: sem ninguem segurando nada, ela
  /// diz o que a aba faz.
  Widget _faixaDeDescricao() {
    const nomes = {
      _AbaAdd.forma: 'Formas para animar. Toque para adicionar.',
      _AbaAdd.midia: 'Video, imagem e legenda do seu aparelho.',
      _AbaAdd.audio: 'Musica e locucao.',
      _AbaAdd.objeto: 'Controladores, cena 3D e solidos.',
      _AbaAdd.mais: 'Desenho e ferramentas do projeto.',
    };
    final texto = _explicando ?? nomes[_abaVisivel]!;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _explicando == null
                ? CupertinoIcons.info_circle
                : CupertinoIcons.info_circle_fill,
            size: 14,
            color: _explicando == null ? AmColors.muted : AmColors.accent,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              texto,
              maxLines: 2,
              style: TextStyle(
                fontSize: 11,
                height: 1.25,
                color: _explicando == null ? AmColors.muted : AmColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _AbaAdd get _abaVisivel =>
      _abasVisiveis.contains(_aba) ? _aba : _abasVisiveis.first;

  Widget _abas() {
    // ICONE EM CIMA, ROTULO EMBAIXO. So texto obriga a ler para escolher;
    // com o icone a aba se reconhece de relance, e e a mesma anatomia dos
    // tiles da grade logo abaixo.
    const nomes = {
      _AbaAdd.forma: ('Forma', CupertinoIcons.square_on_circle),
      _AbaAdd.midia: ('Midia', CupertinoIcons.photo_on_rectangle),
      _AbaAdd.audio: ('Audio', CupertinoIcons.music_note),
      _AbaAdd.objeto: ('Objeto', CupertinoIcons.cube),
      _AbaAdd.mais: ('Mais', CupertinoIcons.square_grid_2x2),
    };
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          for (final a in _abasVisiveis)
            Expanded(
              child: GestureDetector(
                key: ValueKey('add-tab-${a.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() {
                  _aba = a;
                  _explicando = null;
                }),
                child: Container(
                  decoration: const BoxDecoration(color: AmColors.panel),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        nomes[a]!.$2,
                        size: 17,
                        color: _abaVisivel == a
                            ? AmColors.accent
                            : AmColors.text,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nomes[a]!.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _abaVisivel == a
                              ? AmColors.accent
                              : AmColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _atalho(IconData icon, String label, VoidCallback onTap) => Expanded(
    child: InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AmColors.text),
          const SizedBox(height: 2),
          Flexible(
            child: Text(
              label,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9, color: AmColors.text),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _mais() {
    Widget item(IconData icon, String label, VoidCallback onTap) => ListTile(
      dense: true,
      leading: Icon(icon, color: AmColors.text, size: 21),
      title: Text(
        label,
        style: const TextStyle(color: AmColors.text, fontSize: 14),
      ),
      onTap: onTap,
    );
    return Column(
      children: [
        item(CupertinoIcons.scribble, 'Desenho livre', () {
          _fecha();
          ref.read(freehandRequestProvider.notifier).state = true;
        }),
        item(CupertinoIcons.pencil_outline, 'Desenho vetorial', () {
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
        item(CupertinoIcons.doc_text, 'Importar SVG', _importarSvg),
        item(
          CupertinoIcons.captions_bubble,
          'Legendas',
          () => showCaptionCreationSheet(context, ref),
        ),
        if (widget.onProjectAction != null)
          for (final entry in const [
            (AddTarget.efeito, CupertinoIcons.wand_stars, 'Camada de ajuste'),
            (AddTarget.grupo, CupertinoIcons.folder, 'Agrupar camadas'),
            (AddTarget.marcas, CupertinoIcons.bookmark, 'Marcas'),
            (AddTarget.batidas, CupertinoIcons.metronome, 'Detectar batidas'),
            (AddTarget.ajuda, CupertinoIcons.question_circle, 'Como editar'),
          ])
            item(entry.$2, entry.$3, () => widget.onProjectAction!(entry.$1)),
      ],
    );
  }

  /// ARQUIVO SVG: entra como forma editavel, com a cor de cada desenho.
  Future<void> _importarSvg() async {
    String? caminho;
    try {
      final r = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['svg'],
      );
      caminho = r?.files.single.path;
    } catch (_) {
      caminho = null;
    }
    if (caminho == null || !mounted) return;
    SvgImportado svg;
    try {
      svg = lerSvg(await File(caminho).readAsString());
    } on SvgException catch (e) {
      if (mounted) AureaSnack.show(context, e.message);
      return;
    } catch (e) {
      if (mounted) AureaSnack.show(context, 'Nao consegui ler esse SVG.');
      return;
    }
    if (!mounted) return;
    final nome = caminho
        .split(RegExp(r'[\\/]'))
        .last
        .replaceAll(RegExp(r'\.svg$', caseSensitive: false), '');
    _controller.addSvgLayers(svg, widget.playhead, nome: nome);
    _fecha();
    if (!mounted) return;
    AureaSnack.show(
      context,
      svg.ignorados.isEmpty
          ? '${svg.formas.length} desenho(s) do SVG, editaveis'
          : '${svg.formas.length} desenho(s); ficou de fora: ${svg.ignorados.join(', ')}',
    );
  }

  Widget _conteudo() {
    switch (_abaVisivel) {
      case _AbaAdd.forma:
        return _formas();
      case _AbaAdd.midia:
        return GalleryPanel(
          onImport: (file, video, duration) async {
            if (video) {
              if (duration > Duration.zero) {
                _controller.addVideoLayer(
                  widget.playhead,
                  file.path,
                  file.name,
                  duration,
                );
              } else {
                await _controller.importVideoAwaitingDuration(
                  widget.playhead,
                  file.path,
                  file.name,
                );
              }
            } else {
              _controller.addImageLayer(widget.playhead, file.path, file.name);
            }
            if (mounted) _fecha();
          },
        );
      case _AbaAdd.audio:
        if (_importingAudio) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoActivityIndicator(),
                SizedBox(height: 12),
                Text(
                  'Preparando audio...',
                  style: TextStyle(color: AmColors.text),
                ),
              ],
            ),
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AddOption(
              icon: CupertinoIcons.music_note,
              label: 'Arquivo de audio',
              onTap: () => _importAudio(),
            ),
            _AddOption(
              icon: CupertinoIcons.film,
              label: 'Extrair de video',
              onTap: () => _importAudio(fromVideo: true),
            ),
            const Spacer(flex: 5),
          ],
        );
      case _AbaAdd.objeto:
        return _objetos();
      case _AbaAdd.mais:
        return _mais();
    }
  }

  // ------------------------------------------------------------ objeto

  /// A ABA OBJETO EM DUAS ZONAS.
  ///
  /// Objeto conceitual (nulo, grade, cena) e solido geometrico sao coisas
  /// diferentes: um precisa de nome e explicacao, o outro se reconhece
  /// pela silhueta. Misturar os dois numa lista so foi o que fez a aba
  /// virar cinco cards gigantes que nao cabiam na tela.
  Widget _objetos() {
    final cena = _cena;
    final cards = <_CardObjeto>[
      _CardObjeto(
        icone: CupertinoIcons.viewfinder,
        nome: 'Nulo',
        descricao: 'Controlador invisivel. Move um, move todos os filhos.',
        onTap: () {
          _fecha();
          _controller.addNullLayer(widget.playhead);
        },
      ),
      _CardObjeto(
        icone: CupertinoIcons.circle_grid_3x3,
        nome: 'Grid',
        descricao:
            'Multiplica uma camada em grade, circulo, esfera '
            'ou caminho.',
        onTap: () {
          // O Grid E um nulo com o modulo Clonar ativo: criar os dois
          // separados era o que fazia ninguem achar o Grid Builder.
          final antes = {
            for (final l in ref.read(editorControllerProvider).layers) l.id,
          };
          _controller.addNullLayer(widget.playhead);
          String? novo;
          for (final l in ref.read(editorControllerProvider).layers) {
            if (!antes.contains(l.id)) novo = l.id;
          }
          // updateGrid so altera rigs existentes; um nulo novo ainda
          // nao tem rig. Inicializa-o para o Grid abrir ja ativo.
          if (novo != null) _controller.setGridAssets(novo, const []);
          _fecha();
        },
      ),
      _CardObjeto(
        icone: CupertinoIcons.slider_horizontal_3,
        nome: 'Ajuste',
        descricao: 'Aplica efeito em tudo que estiver abaixo.',
        onTap: () {
          _fecha();
          _controller.addAdjustmentLayer(widget.playhead);
        },
      ),
      _CardObjeto(
        icone: CupertinoIcons.sparkles,
        nome: 'Particulas',
        descricao: 'Emissor de particulas com fisica e sprites.',
        onTap: () {
          _fecha();
          _controller.addParticlesLayer(widget.playhead);
        },
      ),
      _CardObjeto(
        icone: CupertinoIcons.cube_box,
        nome: 'Cena 3D',
        descricao: 'Ambiente 3D com objetos, luzes e camera.',
        onTap: () {
          _fecha();
          _controller.addScene3DLayer(widget.playhead);
        },
      ),
      _CardObjeto(
        icone: CupertinoIcons.square_grid_2x2,
        nome: 'Icones',
        descricao: 'Biblioteca de icones vetoriais para animar.',
        onTap: () {
          _fecha();
          _showIconSheet(context, ref, widget.playhead);
        },
      ),
      // CAMERA E LUZ so aparecem quando ha cena — fora dela nao teriam
      // onde entrar, e controle sem alvo nao pode existir.
      if (cena != null) ...[
        _CardObjeto(
          icone: CupertinoIcons.videocam,
          nome: 'Camera',
          descricao:
              'Enquadra a cena. Lentes, foco e profundidade '
              'de campo.',
          onTap: () {
            _fecha();
            _controller.addScene3DCamera(cena.id);
          },
        ),
        _CardObjeto(
          icone: CupertinoIcons.lightbulb,
          nome: 'Luz',
          descricao: 'Ilumina a Cena 3D. Direcional, ponto ou spot.',
          onTap: () {
            _fecha();
            _controller.addSceneLight(cena.id, Light3DKind.directional);
          },
        ),
      ],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Rotulo('OBJETOS'),
        for (var i = 0; i < cards.length; i += 3) ...[
          if (i > 0) const SizedBox(height: 6),
          Row(
            children: [
              for (var j = i; j < i + 3; j++) ...[
                if (j > i) const SizedBox(width: 6),
                if (j < cards.length)
                  Expanded(child: _cardObjeto(cards[j]))
                else
                  const Spacer(),
              ],
            ],
          ),
        ],
        const SizedBox(height: 12),
        const _Rotulo('FORMAS 3D'),
        _solidos3D(),
      ],
    );
  }

  Widget _cardObjeto(_CardObjeto c) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: c.onTap,
    // Toque adiciona; toque longo explica. Um gesto para agir, outro
    // para aprender — e soltar fora do card nao adiciona nada.
    onLongPress: () => setState(() => _explicando = c.descricao),
    onLongPressEnd: (_) => setState(() => _explicando = null),
    child: Container(
      height: 56,
      decoration: BoxDecoration(
        color: AmColors.chip,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(c.icone, size: 22, color: AmColors.accent),
          const SizedBox(height: 4),
          Text(
            c.nome,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: AmColors.text),
          ),
        ],
      ),
    ),
  );

  /// OS SOLIDOS: grade compacta, mesmo tratamento das formas 2D. Sem
  /// card e sem descricao fixa — a silhueta ja diz o que e.
  static const _solidos = <Element3DKind>[
    Element3DKind.cube,
    Element3DKind.sphere,
    Element3DKind.cone,
    Element3DKind.cylinder,
    Element3DKind.torus,
    Element3DKind.pyramid,
    Element3DKind.octahedron,
    Element3DKind.tube,
    Element3DKind.capsule,
  ];

  Widget _solidos3D() => LayoutBuilder(
    builder: (context, limites) {
      final tile = (limites.maxWidth - 6 * 4) / 5;
      // Uma fileira que rola, nao duas: a segunda fileira empurrava a
      // folha inteira por cima da linha do tempo, e nove solidos sao
      // poucos o bastante para o dedo varrer.
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final kind in _solidos)
              GestureDetector(
                onTap: () {
                  _fecha();
                  _controller.addElement3DLayer(widget.playhead, kind);
                },
                onLongPress: () =>
                    setState(() => _explicando = element3DLabel(kind)),
                onLongPressEnd: (_) => setState(() => _explicando = null),
                child: Container(
                  width: tile,
                  height: tile,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: AmColors.chip,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CustomPaint(
                    painter: Element3DPainter(
                      layer: Element3DLayer(
                        name: '',
                        startTime: Duration.zero,
                        duration: const Duration(seconds: 1),
                        kind: kind,
                        size: tile * 0.34,
                      ),
                      rotXDeg: -22,
                      rotYDeg: 34,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );

  // ------------------------------------------------------------ formas

  Widget _formas() {
    final total = shapeLibrary.length;
    final paginas = (total / _porPagina).ceil();
    // A altura sai da largura: cinco tiles quadrados por fileira, tres
    // fileiras. Medir em vez de chutar e o que permite a folha encolher.
    return LayoutBuilder(
      builder: (context, limites) {
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
      },
    );
  }
}

/// Um card da zona OBJETOS.
class _CardObjeto {
  const _CardObjeto({
    required this.icone,
    required this.nome,
    required this.descricao,
    required this.onTap,
  });

  final IconData icone;
  final String nome;
  final String descricao;
  final VoidCallback onTap;
}

/// O rotulo de uma zona dentro da aba.
class _Rotulo extends StatelessWidget {
  const _Rotulo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      texto,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AmColors.muted,
      ),
    ),
  );
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
          decoration: const BoxDecoration(color: AmColors.panel),
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
    final paint = Paint()..color = const Color(0xFFCCCCCC);
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
