import 'dart:ui';

/// Shared Aurea palette for the editor, its controls and the 3D studio.
abstract final class AmColors {
  static const Color bg = Color(0xFF12151A);
  static const Color topBar = Color(0xFF171C23);
  static const Color panel = Color(0xFF171C23);
  static const Color panelHigh = Color(0xFF1E242E);
  static const Color chip = Color(0xFF262C36);

  /// Keyframe, curva e realce de contexto (teal).
  static const Color accent = Color(0xFF1ED6B1);
  static const Color accentDim = Color(0xFF183F3C);

  /// ACAO (o lima da logo): Exportar, o "+", chips de acao. O teal fica
  /// com keyframe e curva; a acao e outra cor para nao se confundir com
  /// "esta animado".
  static const Color action = Color(0xFFB8FF3D);
  static const Color onAction = Color(0xFF0B0E12);
  static const Color actionDim = Color(0xFF2A3A16);

  /// Selecao e grupos (violeta da logo).
  static const Color selection = Color(0xFF7C62FF);

  /// Barras de camada com contraste para texto e keyframes.
  static const Color teal = Color(0xFF43B7C6);
  static const Color tealBright = Color(0xFF81D8E0);

  /// Playhead em contexto de keyframe/efeito.
  static const Color pink = Color(0xFFFF6B6B);

  static const Color text = Color(0xFFE9EDF2);
  static const Color muted = Color(0xFF8B94A3);
  static const Color hairline = Color(0x14FFFFFF);
}
