import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.card,
      ),
      scaffoldBackgroundColor: AppColors.backgroundSoft,
      fontFamily: 'SF Pro Text',
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: _textStyle(40, FontWeight.w900),
        displayMedium: _textStyle(32, FontWeight.w900),
        displaySmall: _textStyle(28, FontWeight.w900),
        headlineLarge: _textStyle(28, FontWeight.w900),
        headlineMedium: _textStyle(24, FontWeight.w800),
        titleLarge: _textStyle(20, FontWeight.w800),
        titleMedium: _textStyle(16, FontWeight.w800),
        titleSmall: _textStyle(14, FontWeight.w700),
        bodyLarge: _textStyle(16, FontWeight.w600),
        bodyMedium: _textStyle(14, FontWeight.w500, color: AppColors.muted),
        labelLarge: _textStyle(14, FontWeight.w800),
        labelSmall: _textStyle(11, FontWeight.w800, color: AppColors.muted),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
    );
  }

  static TextStyle _textStyle(
    double size,
    FontWeight weight, {
    Color color = AppColors.ink,
  }) {
    return TextStyle(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: 1.15,
      letterSpacing: -0.3,
    );
  }
}
