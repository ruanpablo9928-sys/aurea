import 'dart:math' as math;

import '../../../../core/theme/tokens.dart';

/// AS ALTURAS DAS CINCO ZONAS, resolvidas de uma vez.
///
/// A regra que os testes cobram: o preview so muda de tamanho pela alca
/// (ou ao expandir); abrir uma categoria, adicionar ou trocar de aba
/// NUNCA move o preview. O painel contextual tira espaco da timeline, e
/// a timeline nunca fica abaixo de [timelineMin].
class EditorLayoutMetrics {
  const EditorLayoutMetrics({
    required this.topBar,
    required this.preview,
    required this.handle,
    required this.transport,
    required this.timeline,
    required this.sheet,
  });

  static const double timelineMin = 88;
  static const double previewMin = 96;
  static const double handleHeight = 8;

  final double topBar;
  final double preview;
  final double handle;
  final double transport;
  final double timeline;
  final double sheet;

  double get total => topBar + preview + handle + transport + timeline + sheet;

  /// Espaco que sobra para preview + timeline + painel.
  static double workspace(double totalHeight) => math.max(
    0,
    totalHeight -
        AureaTokens.topBar -
        AureaTokens.transport -
        handleHeight,
  );

  static EditorLayoutMetrics solve({
    required double totalHeight,
    required double previewFraction,
    required double sheetFraction,
    bool previewExpanded = false,
    bool timelineExpanded = false,
    bool sheetVisible = true,
    bool sheetMayCoverTimeline = false,
  }) {
    if (previewExpanded) {
      return EditorLayoutMetrics(
        topBar: 0,
        preview: math.max(0, totalHeight - AureaTokens.transport),
        handle: 0,
        transport: AureaTokens.transport,
        timeline: 0,
        sheet: 0,
      );
    }
    final ws = workspace(totalHeight);
    // O PREVIEW e uma fracao da altura da TELA (o prompt pede 40–45%),
    // nunca abaixo do minimo nem acima do que deixa a timeline viva.
    var preview = timelineExpanded
        ? previewMin
        : (totalHeight * previewFraction.clamp(0.30, 0.60))
              .clamp(previewMin, math.max(previewMin, ws - timelineMin))
              .toDouble();
    var sheet = sheetVisible ? ws * sheetFraction.clamp(0.0, 0.60) : 0.0;
    // A timeline fica com o resto, nunca abaixo do minimo: se nao cabe,
    // o painel encolhe. O preview NAO cede: abrir categoria, adicionar
    // ou trocar de aba nunca move o preview. Ao ADICIONAR, o menu pode
    // cobrir a timeline (e um seletor, nao um ajuste): minimo zero.
    final piso = sheetMayCoverTimeline ? 0.0 : timelineMin;
    var timeline = ws - preview - sheet;
    if (timeline < piso) {
      sheet = math.max(0, sheet - (piso - timeline));
      timeline = ws - preview - sheet;
    }
    return EditorLayoutMetrics(
      topBar: AureaTokens.topBar,
      preview: preview,
      handle: handleHeight,
      transport: AureaTokens.transport,
      timeline: math.max(0, timeline),
      sheet: math.max(0, sheet),
    );
  }
}
