import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Paleta extraida do logo: fundo grafite, verde-lima e violeta.
///
/// TEMA CLARO (Fase 6, decisao Q6): os mesmos NOMES trocam de valor com
/// [modoClaro]. Quem pintava com AppColors continua pintando com o papel
/// certo — fundo, superficie, texto — e o app inteiro (fora do editor,
/// que fica escuro por ser palco de video) acompanha o ajuste.
abstract final class AppColors {
  /// Ligado pelo tema em vigor (ver [AppTheme.tema]).
  static bool modoClaro = false;

  static Color get background =>
      modoClaro ? const Color(0xFFF4F5F7) : const Color(0xFF12151A);
  static Color get surface =>
      modoClaro ? const Color(0xFFFFFFFF) : const Color(0xFF171C23);
  static Color get surfaceHigh =>
      modoClaro ? const Color(0xFFEDEFF3) : const Color(0xFF1E242E);
  static Color get lime =>
      modoClaro ? const Color(0xFF7BC300) : const Color(0xFFB8FF3D);
  static Color get violet =>
      modoClaro ? const Color(0xFF6A4FF0) : const Color(0xFF7C62FF);
  static Color get onDark =>
      modoClaro ? const Color(0xFF14171C) : const Color(0xFFE9EDF2);
  static Color get muted =>
      modoClaro ? const Color(0xFF6B7280) : const Color(0xFF8B94A3);
  static Color get outline =>
      modoClaro ? const Color(0xFFD5D9E0) : const Color(0xFF2A313C);

  /// O verde da marca APAGADO, para fundo de chip aceso — o mesmo papel
  /// que `AmColors.accentDim` faz no editor.
  static Color get accentDim =>
      modoClaro ? const Color(0xFFE3F5C2) : const Color(0xFF2A3A16);

  /// Linha fina estilo iOS (separadores e borda do chrome translucido).
  static Color get hairline => modoClaro
      ? Colors.black.withValues(alpha: 0.08)
      : Colors.white.withValues(alpha: 0.08);
}

abstract final class AppTheme {
  static const Color timelineBackground = Color(0xFF171C23);

  static ThemeData get dark => tema(claro: false);
  static ThemeData get light => tema(claro: true);

  /// O tema em vigor. Liga [AppColors.modoClaro] antes de montar, para
  /// as cores fixas das telas de Projetos e Ajustes acompanharem.
  static ThemeData tema({required bool claro}) {
    AppColors.modoClaro = claro;
    final scheme = ColorScheme(
      brightness: claro ? Brightness.light : Brightness.dark,
      primary: AppColors.lime,
      onPrimary: Color(0xFF0B0E12),
      secondary: AppColors.violet,
      onSecondary: Colors.white,
      error: Color(0xFFFF6B6B),
      onError: Colors.white,
      surface: AppColors.background,
      onSurface: AppColors.onDark,
      surfaceContainerHighest: AppColors.surfaceHigh,
      surfaceContainerHigh: AppColors.surfaceHigh,
      surfaceContainer: AppColors.surface,
      surfaceContainerLow: AppColors.surface,
      onSurfaceVariant: AppColors.muted,
      outline: AppColors.outline,
      outlineVariant: AppColors.outline,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,

      // Feedback estilo iOS: sem ripple do Material, realce sutil no toque.
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: (claro ? Colors.black : Colors.white).withValues(alpha: 0.05),

      // Navegacao com a fisica/transicao do iOS em todas as plataformas.
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: claro ? Brightness.light : Brightness.dark,
        primaryColor: AppColors.lime,
      ),

      // Tipografia estilo SF: tracking negativo cresce junto com o corpo.
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.8,
          height: 1.1,
          color: AppColors.onDark,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: AppColors.onDark,
        ),
        titleMedium: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: AppColors.onDark,
        ),
        bodyLarge: TextStyle(
          fontSize: 17,
          letterSpacing: -0.2,
          color: AppColors.onDark,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          letterSpacing: -0.1,
          height: 1.35,
          color: AppColors.onDark,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          letterSpacing: 0,
          color: AppColors.muted,
        ),
        labelLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          color: AppColors.onDark,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.lime,
          foregroundColor: const Color(0xFF0B0E12),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.lime),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.hairline,
        thickness: 0.5,
        space: 0.5,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceHigh,
        contentTextStyle: TextStyle(color: AppColors.onDark),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
