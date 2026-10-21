import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../net_image.dart';

/// Degradado determinista a partir de un texto (título o `id`).
///
/// Los paneles de IPTV no siempre devuelven carátula; el diseño NOVA cubre esos
/// huecos con degradados estables (el mismo título pinta siempre igual) en vez
/// de un rectángulo gris.
LinearGradient novaGradientFor(String seed) {
  const List<List<Color>> palettes = <List<Color>>[
    <Color>[Color(0xFF1E3358), Color(0xFF101B2E)],
    <Color>[Color(0xFF4A2A55), Color(0xFF1F1526)],
    <Color>[Color(0xFF17503F), Color(0xFF0E2A22)],
    <Color>[Color(0xFF6B4A1E), Color(0xFF2A1D0C)],
    <Color>[Color(0xFF24344D), Color(0xFF131C2B)],
    <Color>[Color(0xFF552A34), Color(0xFF241318)],
  ];

  int hash = 7;
  for (final int unit in seed.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  final List<Color> colors = palettes[hash % palettes.length];
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: colors,
  );
}

/// Motivo de anillos concéntricos del héroe NOVA.
class RingBackdrop extends StatelessWidget {
  const RingBackdrop({
    super.key,
    this.color,
    this.rings = 3,
    this.alignment = const Alignment(0.42, 0),
    this.strokeWidth = 1.4,
    this.span = 0.13,
    this.base = 0.15,
  });

  final Color? color;
  final int rings;
  final Alignment alignment;
  final double strokeWidth;

  /// Separación entre anillos (fracción del lado corto).
  final double span;

  /// Radio del primer anillo (fracción del lado corto).
  final double base;

  @override
  Widget build(BuildContext context) {
    final Color stroke = color ??
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.55);
    return IgnorePointer(
      child: CustomPaint(
        painter: _RingsPainter(
          color: stroke,
          rings: rings,
          alignment: alignment,
          strokeWidth: strokeWidth,
          span: span,
          base: base,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  const _RingsPainter({
    required this.color,
    required this.rings,
    required this.alignment,
    required this.strokeWidth,
    required this.span,
    required this.base,
  });

  final Color color;
  final int rings;
  final Alignment alignment;
  final double strokeWidth;
  final double span;
  final double base;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || rings <= 0) return;

    final Offset center = alignment.withinRect(Offset.zero & size);
    final double shortest = math.min(size.width, size.height);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (int i = 0; i < rings; i++) {
      final double alpha = (0.85 - i * 0.22).clamp(0.12, 1.0);
      paint.color = color.withValues(alpha: color.a * alpha);
      canvas.drawCircle(center, shortest * (base + i * span), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.rings != rings ||
        oldDelegate.alignment != alignment ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.span != span ||
        oldDelegate.base != base;
  }
}

/// Carátula/fondo del diseño NOVA.
///
/// Si hay URL pinta la imagen; si no, un degradado con el motivo de anillos,
/// que es justo lo que aparece en los diseños con el material de ejemplo.
class NovaArtwork extends StatelessWidget {
  const NovaArtwork({
    super.key,
    this.url,
    this.seed = '',
    this.radius = 14,
    this.rings = 0,
    this.icon = Icons.play_circle_outline,
    this.iconSize = 30,
    this.fit = BoxFit.cover,
    this.cacheWidth,
    this.ringAlignment = const Alignment(0.42, 0),
    this.ringColor,
    this.child,
  });

  final String? url;
  final String seed;
  final double radius;
  final int rings;
  final IconData icon;
  final double iconSize;
  final BoxFit fit;
  final int? cacheWidth;
  final Alignment ringAlignment;
  final Color? ringColor;
  final Widget? child;

  bool get _hasImage => url != null && url!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final Widget art;
    if (_hasImage) {
      art = NetImage(
        url: url,
        fit: fit,
        icon: icon,
        iconSize: iconSize,
        cacheWidth: cacheWidth,
        backgroundColor: Colors.transparent,
      );
    } else {
      art = DecoratedBox(
        decoration: BoxDecoration(
          gradient: novaGradientFor(seed.isEmpty ? 'nova' : seed),
        ),
        child: rings > 0
            ? RingBackdrop(
                rings: rings,
                alignment: ringAlignment,
                color: ringColor,
              )
            : const SizedBox.expand(),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          art,
          if (child != null) child!,
        ],
      ),
    );
  }
}
