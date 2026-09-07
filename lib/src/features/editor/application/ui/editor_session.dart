import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/video_project.dart' show LayerProp;

/// AS FERRAMENTAS DO PAINEL TRANSFORMAR (uma por sub-aba).
enum TransformTool { position, rotation, scale, skew, pivot, opacity }

LayerProp propOfTool(TransformTool tool) => switch (tool) {
  TransformTool.position => LayerProp.position,
  TransformTool.rotation => LayerProp.rotation,
  TransformTool.scale => LayerProp.scale,
  TransformTool.skew => LayerProp.skew,
  TransformTool.pivot => LayerProp.pivot,
  TransformTool.opacity => LayerProp.opacity,
};

/// AS SUB-ABAS DO PAINEL EDITAR FORMA.
enum ShapeTool { size, corners, points, angle, rotation, stroke, draw, nodes }

/// O QUE O PAINEL CONTEXTUAL (zona E) ESTA MOSTRANDO.
///
/// `none` = a acao segue a selecao (E1 sem selecao, E2 com selecao).
/// Os demais sao as categorias abertas (E3/E4/E5) e os dois espacos de
/// edicao direta (pontos e curva).
enum EditorPanel {
  none,
  add,
  transform,
  blending,
  colorFill,
  effects,
  curve,
  animators,
  editShape,
  editPoints,
}

/// As tres alturas do painel contextual, como fracao do espaco util.
enum SheetLevel { peek, half, full }

/// O ESTADO DE SESSAO DO EDITOR — o que era `setState` privado da tela.
///
/// Mora num provider para que a barra de cima, o transporte, a timeline
/// e o painel contextual leiam o mesmo estado sem parametro nenhum, e
/// para que um teste consiga abrir uma categoria sem tocar em pixel.
class EditorSession {
  const EditorSession({
    this.panel = EditorPanel.none,
    this.tool = TransformTool.position,
    this.shapeTool = ShapeTool.size,
    this.curveProp = LayerProp.position,
    this.curveReturn = EditorPanel.transform,
    this.pointsReturn = EditorPanel.editShape,
    this.pointsItemId,
    this.previewExpanded = false,
    this.previewFraction = 0.401,
    this.sheetLevel = SheetLevel.half,
    this.sheetFraction,
    this.timelineExpanded = false,
  });

  final EditorPanel panel;
  final TransformTool tool;
  final ShapeTool shapeTool;
  final LayerProp curveProp;

  /// Para onde "voltar" leva ao sair da curva / dos pontos.
  final EditorPanel curveReturn;
  final EditorPanel pointsReturn;
  final String? pointsItemId;

  /// Preview em tela cheia (esconde o resto).
  final bool previewExpanded;

  /// Altura do preview como fracao da altura da TELA (a alca entre o
  /// preview e o transporte muda isto). 0.30..0.60.
  final double previewFraction;

  /// Nivel do painel contextual, e a fracao livre quando a alca foi
  /// arrastada para um ponto entre niveis.
  final SheetLevel sheetLevel;
  final double? sheetFraction;

  /// Timeline em tela cheia (preview vira janela pequena).
  final bool timelineExpanded;

  bool get panelOpen => panel != EditorPanel.none && panel != EditorPanel.add;
  bool get adding => panel == EditorPanel.add;

  /// A fracao efetiva do painel contextual.
  double get effectiveSheetFraction =>
      sheetFraction ?? fractionOfLevel(sheetLevel);

  static double fractionOfLevel(SheetLevel level) => switch (level) {
    SheetLevel.peek => 0.22,
    SheetLevel.half => 0.40,
    SheetLevel.full => 0.60,
  };

  EditorSession copyWith({
    EditorPanel? panel,
    TransformTool? tool,
    ShapeTool? shapeTool,
    LayerProp? curveProp,
    EditorPanel? curveReturn,
    EditorPanel? pointsReturn,
    String? pointsItemId,
    bool clearPointsItem = false,
    bool? previewExpanded,
    double? previewFraction,
    SheetLevel? sheetLevel,
    double? sheetFraction,
    bool clearSheetFraction = false,
    bool? timelineExpanded,
  }) => EditorSession(
    panel: panel ?? this.panel,
    tool: tool ?? this.tool,
    shapeTool: shapeTool ?? this.shapeTool,
    curveProp: curveProp ?? this.curveProp,
    curveReturn: curveReturn ?? this.curveReturn,
    pointsReturn: pointsReturn ?? this.pointsReturn,
    pointsItemId: clearPointsItem ? null : (pointsItemId ?? this.pointsItemId),
    previewExpanded: previewExpanded ?? this.previewExpanded,
    previewFraction: previewFraction ?? this.previewFraction,
    sheetLevel: sheetLevel ?? this.sheetLevel,
    sheetFraction: clearSheetFraction
        ? null
        : (sheetFraction ?? this.sheetFraction),
    timelineExpanded: timelineExpanded ?? this.timelineExpanded,
  );
}

class EditorSessionNotifier extends AutoDisposeNotifier<EditorSession> {
  @override
  EditorSession build() => const EditorSession();

  /// Ao abrir outro projeto, a sessao volta ao zero.
  void reset() => state = const EditorSession();

  void openPanel(EditorPanel panel) {
    state = state.copyWith(
      panel: panel,
      // Categoria aberta pede espaco: sobe para a metade no minimo.
      sheetLevel: state.sheetLevel == SheetLevel.peek
          ? SheetLevel.half
          : state.sheetLevel,
      clearSheetFraction: true,
    );
  }

  void closePanel() => state = state.copyWith(panel: EditorPanel.none);

  void openAdd() => state = state.copyWith(
    panel: EditorPanel.add,
    sheetLevel: SheetLevel.full,
    clearSheetFraction: true,
  );

  void closeAdd() {
    if (state.panel == EditorPanel.add) {
      state = state.copyWith(panel: EditorPanel.none, sheetLevel: SheetLevel.half);
    }
  }

  void setTool(TransformTool tool) => state = state.copyWith(tool: tool);

  void setShapeTool(ShapeTool tool) => state = state.copyWith(shapeTool: tool);

  void openTransform([TransformTool? tool]) => state = state.copyWith(
    panel: EditorPanel.transform,
    tool: tool ?? state.tool,
    sheetLevel: state.sheetLevel == SheetLevel.peek
        ? SheetLevel.half
        : state.sheetLevel,
    clearSheetFraction: true,
  );

  void openShape(ShapeTool tool) => state = state.copyWith(
    panel: EditorPanel.editShape,
    shapeTool: tool,
    sheetLevel: state.sheetLevel == SheetLevel.peek
        ? SheetLevel.half
        : state.sheetLevel,
    clearSheetFraction: true,
  );

  void openCurve(LayerProp prop) => state = state.copyWith(
    curveProp: prop,
    curveReturn: state.panel == EditorPanel.curve
        ? state.curveReturn
        : state.panel,
    panel: EditorPanel.curve,
  );

  void backFromCurve() => state = state.copyWith(panel: state.curveReturn);

  void openEditPoints(String itemId, {required EditorPanel returnTo}) =>
      state = state.copyWith(
        pointsItemId: itemId,
        pointsReturn: returnTo,
        panel: EditorPanel.editPoints,
        sheetLevel: state.sheetLevel == SheetLevel.peek
            ? SheetLevel.half
            : state.sheetLevel,
        clearSheetFraction: true,
      );

  void backFromEditPoints() =>
      state = state.copyWith(panel: state.pointsReturn, clearPointsItem: true);

  void togglePreviewExpanded() =>
      state = state.copyWith(previewExpanded: !state.previewExpanded);

  void setPreviewExpanded(bool value) =>
      state = state.copyWith(previewExpanded: value);

  void toggleTimelineExpanded() =>
      state = state.copyWith(timelineExpanded: !state.timelineExpanded);

  void setPreviewFraction(double f) =>
      state = state.copyWith(previewFraction: f.clamp(0.30, 0.60));

  void setSheetLevel(SheetLevel level) =>
      state = state.copyWith(sheetLevel: level, clearSheetFraction: true);

  /// A alca arrastada para um ponto qualquer entre os niveis.
  void setSheetFraction(double f) =>
      state = state.copyWith(sheetFraction: f.clamp(0.12, 0.60));

  /// Solta a alca: encaixa no nivel mais proximo.
  void snapSheet() {
    final f = state.effectiveSheetFraction;
    var melhor = SheetLevel.half;
    var dist = double.infinity;
    for (final l in SheetLevel.values) {
      final d = (EditorSession.fractionOfLevel(l) - f).abs();
      if (d < dist) {
        dist = d;
        melhor = l;
      }
    }
    setSheetLevel(melhor);
  }
}

/// AUTO-DISPOSE: sem ninguem escutando (o editor fechou), a sessao some
/// e a proxima abertura nasce limpa — sem precisar de reset em initState
/// (que o Riverpod proibe por ser durante o build).
final editorSessionProvider =
    NotifierProvider.autoDispose<EditorSessionNotifier, EditorSession>(
      EditorSessionNotifier.new,
    );
