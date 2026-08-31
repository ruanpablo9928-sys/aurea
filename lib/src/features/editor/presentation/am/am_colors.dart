import 'dart:ui';

/// Paleta do editor: o tema da LOGO do Aurea (grafite + lima + violeta),
/// mantendo o layout do editor de motion.
abstract final class AmColors {
  static const Color bg = Color(0xFF12151A);
  static const Color topBar = Color(0xFF171C23);
  static const Color panel = Color(0xFF171C23);
  static const Color panelHigh = Color(0xFF1E242E);
  static const Color chip = Color(0xFF232A36);

  /// Acento principal: o verde-lima da logo.
  static const Color accent = Color(0xFFB8FF3D);
  static const Color accentDim = Color(0xFF3A4A17);

  /// Barras de camada: o violeta da logo.
  static const Color teal = Color(0xFF7C62FF);
  static const Color tealBright = Color(0xFF9F8CFF);

  /// Playhead em contexto de keyframe/efeito.
  static const Color pink = Color(0xFFFF6B6B);

  static const Color text = Color(0xFFE9EDF2);
  static const Color muted = Color(0xFF8B94A3);
  static const Color hairline = Color(0x14FFFFFF);
}
