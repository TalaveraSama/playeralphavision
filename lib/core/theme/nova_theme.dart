import 'package:flutter/material.dart';

import '../utils/device_profile.dart';

/// Puntos de corte del diseño NOVA.
///
/// Por encima de [wide] la app usa la barra de navegación **superior** (web,
/// escritorio y tabletas en horizontal); por debajo, la barra **inferior** del
/// móvil.
class NovaBreakpoints {
  const NovaBreakpoints._();

  static const double wide = 1000;
  static const double details = 980;
  static const double narrowHero = 720;
}

/// Clase de tamaño de la pantalla actual.
enum NovaSizeClass { compact, phone, tablet, desktop, wide, tv }

/// Ajuste fino global del diseno: 1.0 = tamano base, 0.8 = todo un 20 % mas
/// pequeno (texto, separaciones y alturas). La barra inferior no se toca.
const double designScale = 1.0;

/// Medidas de la pantalla: clase de tamaño, si es un televisor y un **factor de
/// escala único** que multiplica tipografías, alturas y separaciones.
///
/// El diseño ya no usa tamaños fijos: el mismo código sirve para un móvil de
/// 360 dp, una tableta de 800×1280 dp y un televisor de 1920×1080 dp.
class NovaMetrics {
  const NovaMetrics({
    required this.scale,
    required this.sizeClass,
    required this.isTv,
  });

  final double scale;
  final NovaSizeClass sizeClass;

  /// Android TV / Fire TV: se navega con el mando (interfaz "a 3 metros").
  final bool isTv;

  bool get isNarrow =>
      sizeClass == NovaSizeClass.compact ||
      sizeClass == NovaSizeClass.phone ||
      sizeClass == NovaSizeClass.tablet;

  factory NovaMetrics.of(BuildContext context) {
    final MediaQueryData mq = MediaQuery.of(context);
    final double width = mq.size.width;

    // Flutter marca la navegación por mando como "direccional": es la señal
    // fiable de televisor, sin adivinar por el tamaño.
    final bool tv = mq.navigationMode == NavigationMode.directional ||
        (DeviceProfile.current?.isTv ?? false);

    final NovaSizeClass sizeClass;
    if (tv) {
      sizeClass = NovaSizeClass.tv;
    } else if (width < 380) {
      sizeClass = NovaSizeClass.compact;
    } else if (width < 600) {
      sizeClass = NovaSizeClass.phone;
    } else if (width < 1000) {
      sizeClass = NovaSizeClass.tablet;
    } else if (width < 1400) {
      sizeClass = NovaSizeClass.desktop;
    } else {
      sizeClass = NovaSizeClass.wide;
    }

    // Tipografía algo mayor para lectura a distancia, sin escalar toda la
    // pantalla como si fuera un teléfono gigante.
    final double base = tv ? (width >= 1400 ? 1.15 : 1.05) : 1.0;

    final double scale = (base * designScale).clamp(0.72, 1.2);

    return NovaMetrics(scale: scale, sizeClass: sizeClass, isTv: tv);
  }

  /// Escala un valor (tipografía, separación, altura).
  double sp(double value) => value * scale;
}

/// Tokens del diseño NOVA.
///
/// Todo sale del tema activo (colores de marca blanca) y del tamaño de la
/// pantalla ([NovaMetrics]): el acento, el fondo y las superficies los fija
/// `assets/config.json`, y las medidas las calcula la clase de tamaño.
class NovaTokens {
  const NovaTokens({
    required this.accent,
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.text,
    required this.muted,
    required this.live,
    required this.radius,
    required this.scale,
    required this.isTv,
  });

  /// Color de acento (mint en la marca NOVA).
  final Color accent;
  final Color background;
  final Color surface;

  /// Superficie un punto más clara, para tarjetas y fichas dentro del fondo.
  final Color surfaceHigh;

  final Color text;

  /// Texto secundario (metadatos, descripciones).
  final Color muted;

  /// Rojo de las emisiones en directo.
  final Color live;

  final double radius;

  /// Factor de escala de la pantalla actual.
  final double scale;

  final bool isTv;

  static const Color liveRed = Color(0xFFF2564B);

  factory NovaTokens.of(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color surface = scheme.surface;
    final NovaMetrics metrics = NovaMetrics.of(context);

    final ShapeBorder shape =
        theme.cardTheme.shape ?? const RoundedRectangleBorder();
    final BorderRadiusGeometry? geometry =
        shape is RoundedRectangleBorder ? shape.borderRadius : null;
    final Radius? cardRadius =
        geometry is BorderRadius ? geometry.topLeft : null;

    return NovaTokens(
      accent: scheme.primary,
      background: theme.scaffoldBackgroundColor,
      surface: surface,
      surfaceHigh: Color.alphaBlend(
        Colors.white.withValues(alpha: 0.04),
        surface,
      ),
      text: scheme.onSurface,
      muted: scheme.onSurface.withValues(alpha: 0.62),
      live: liveRed,
      radius: metrics.sp(cardRadius?.x ?? 14),
      scale: metrics.scale,
      isTv: metrics.isTv,
    );
  }

  /// Línea divisoria muy tenue.
  Color get hairline => text.withValues(alpha: 0.08);

  // --------------------------------------------------------------- medidas
  /// Las alturas acompanan al diseno (con un minimo para que el contenido no
  /// se apriete demasiado en pantallas pequenas).
  double get _heightScale => scale.clamp(0.85, 1.2);

  /// Altura del héroe en pantallas anchas.
  double get heroHeightWide => 428 * _heightScale;

  /// Altura del héroe en el móvil.
  double get heroHeightCompact => 210 * _heightScale;

  /// Altura del reproductor de las fichas.
  double get detailHero => 180;

  // ------------------------------------------------------------- tipografía
  TextStyle get heroTitle => TextStyle(
        fontSize: 54 * scale,
        height: 1.02,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        color: text,
      );

  TextStyle get heroTitleCompact => TextStyle(
        fontSize: 29 * scale,
        height: 1.05,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
        color: text,
      );

  TextStyle get sectionTitle => TextStyle(
        fontSize: 20 * scale,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: text,
      );

  TextStyle get cardTitle => TextStyle(
        fontSize: 14 * scale,
        fontWeight: FontWeight.w700,
        color: text,
      );

  TextStyle get body => TextStyle(
        fontSize: 14.5 * scale,
        height: 1.5,
        color: muted,
      );

  TextStyle get meta => TextStyle(
        fontSize: 13 * scale,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        color: muted,
      );

  TextStyle get eyebrow => TextStyle(
        fontSize: 12 * scale,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: accent,
      );

  TextStyle get link => TextStyle(
        fontSize: 13 * scale,
        fontWeight: FontWeight.w600,
        color: text.withValues(alpha: 0.78),
      );
}
