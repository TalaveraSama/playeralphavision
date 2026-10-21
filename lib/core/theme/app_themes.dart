import 'package:flutter/material.dart';

import '../config/app_config.dart';

/// Construye el [ThemeData] de la app a partir del tema elegido en la
/// configuración de marca blanca (`theme1`, `theme2`, ...).
ThemeData buildThemeData(ThemeSpec spec) {
  final bool isDark = spec.brightness == Brightness.dark;
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: spec.primaryColor,
    brightness: spec.brightness,
  ).copyWith(
    primary: spec.primaryColor,
    surface: spec.surfaceColor,
    onSurface: spec.textColor,
  );

  final Color background = spec.backgroundColor;
  final Color surface = spec.surfaceColor;
  // En los temas con botones claros (estilo HBO Max) el CTA es blanco.
  final Color ctaBackground = spec.lightButtons ? Colors.white : spec.primaryColor;
  final Color ctaForeground = spec.lightButtons ? Colors.black : Colors.white;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: background,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: spec.textColor,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      height: 68,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      indicatorColor: spec.primaryColor.withValues(alpha: 0.24),
      labelTextStyle: WidgetStatePropertyAll<TextStyle>(
        TextStyle(fontSize: 11, color: spec.textColor.withValues(alpha: 0.85)),
      ),
    ),
    textTheme: isDark
        ? Typography.material2021().white
        : Typography.material2021().black,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.04),
      hintStyle: TextStyle(color: spec.textColor.withValues(alpha: 0.45)),
      labelStyle: TextStyle(color: spec.textColor.withValues(alpha: 0.75)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: spec.primaryColor, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ctaBackground,
        foregroundColor: ctaForeground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(spec.lightButtons ? 26 : 8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: spec.textColor,
        side: BorderSide(color: spec.textColor.withValues(alpha: 0.5)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(spec.lightButtons ? 26 : 8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.06),
      selectedColor: spec.primaryColor.withValues(alpha: 0.30),
      side: BorderSide.none,
      labelStyle: TextStyle(color: spec.textColor),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: spec.primaryColor,
      thumbColor: spec.primaryColor,
      inactiveTrackColor: Colors.white24,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: spec.primaryColor),
    dividerTheme: DividerThemeData(
      color: spec.textColor.withValues(alpha: 0.10),
      space: 1,
      thickness: 1,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(spec.cardRadius),
      ),
    ),
  );
}
