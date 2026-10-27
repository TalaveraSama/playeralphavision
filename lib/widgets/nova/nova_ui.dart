import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/config/config_controller.dart';
import '../../core/theme/nova_theme.dart';
import '../net_image.dart';

/// Logotipo textual de la marca (NOVA por defecto).
class NovaLogo extends StatelessWidget {
  const NovaLogo({super.key, this.fontSize = 24, this.color});

  final double fontSize;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final NovaTokens tokens = NovaTokens.of(context);
    final BrandingConfig branding =
        context.watch<ConfigController>().config.branding;

    // Logo de la cabecera subido desde el panel; si no hay, el nombre en texto.
    final String logo = branding.effectiveHeaderLogo.trim();
    if (logo.isNotEmpty) {
      return SizedBox(
        height: fontSize * 1.9,
        child: NetImage(
          url: logo,
          fit: BoxFit.contain,
          icon: Icons.play_circle_fill_rounded,
          backgroundColor: Colors.transparent,
        ),
      );
    }

    final String name = branding.appName.trim();
    return Text(
      name.isEmpty ? 'NOVA' : name.toUpperCase(),
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        letterSpacing: fontSize * 0.06,
        color: color ?? tokens.accent,
      ),
    );
  }
}

/// Etiqueta pequeña en mayúsculas («ORIGINAL NOVA», «EN VIVO»).
class NovaBadge extends StatelessWidget {
  const NovaBadge({
    super.key,
    required this.label,
    this.background,
    this.foreground,
    this.dot = false,
  });

  final String label;
  final Color? background;
  final Color? foreground;

  /// Punto de emisión en directo a la izquierda.
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final NovaTokens tokens = NovaTokens.of(context);
    final Color bg = background ?? tokens.accent;
    final Color fg = foreground ?? tokens.background;

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: 10 * tokens.scale,
          vertical: 5 * tokens.scale,
        ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (dot) ...<Widget>[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón principal (acento con texto oscuro).

/// Zona táctil que además responde al mando de TV (OK/enter) y muestra un
/// borde cuando está enfocada, para poder llegar con las flechas.
class NovaFocusable extends StatefulWidget {
  const NovaFocusable({super.key, required this.onTap, required this.child, this.borderRadius = const BorderRadius.all(Radius.circular(10)), this.autofocus = false});
  final VoidCallback? onTap;
  final Widget child;
  final BorderRadius borderRadius;
  final bool autofocus;
  @override
  State<NovaFocusable> createState() => _NovaFocusableState();
}
class _NovaFocusableState extends State<NovaFocusable> {
  final FocusNode _node = FocusNode();
  bool _focused = false;
  @override
  void dispose() { _node.dispose(); super.dispose(); }
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.space)) {
      widget.onTap?.call();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _node, autofocus: widget.autofocus, canRequestFocus: widget.onTap != null,
      onFocusChange: (bool v) {
        setState(() => _focused = v);
        if (v) {
          Scrollable.ensureVisible(context,
              alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero : const Duration(milliseconds: 180));
        }
      }, onKeyEvent: _onKey,
      // TOUCH: en telefonos/tablets el toque debe activar igual que OK del mando.
      child: MouseRegion(
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap == null
              ? null
              : () {
                  _node.requestFocus();
                  widget.onTap!.call();
                },
          child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          // Foco MUY visible: borde blanco + halo cian + fondo tenue.
          border: Border.all(
            color: _focused ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: _focused
              ? <BoxShadow>[
                  BoxShadow(
                    // El halo usa el color del tema activo (antes era cian fijo
                    // y no coincidia con el color de la marca).
                    color: NovaTokens.of(context)
                        .accent
                        .withValues(alpha: 0.22),
                    blurRadius: 12,
                    spreadRadius: 0,
                  ),
                ]
              : null,
        ),
        child: widget.child,
          ),
        ),
      ),
    );
  }
}
class NovaPrimaryButton extends StatelessWidget {
  const NovaPrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.compact = false,
    this.autofocus = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool compact;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final NovaTokens tokens = NovaTokens.of(context);
    final bool enabled = onPressed != null;

    return NovaFocusable(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      autofocus: autofocus,
      child: ExcludeFocus(child: Material(
        color: enabled ? tokens.accent : tokens.accent.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: (compact ? 16 : 24) * tokens.scale,
            vertical: (compact ? 11 : 14) * tokens.scale,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: compact ? 18 : 20, color: tokens.background),
                const SizedBox(width: 9),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: compact ? 14 : 15,
                  fontWeight: FontWeight.w800,
                  color: tokens.background,
                ),
              ),
            ],
          ),
          ),
        ),
      )),
    );
  }
}

/// Botón cuadrado con icono (añadir a mi lista, compartir…).
class NovaSquareButton extends StatelessWidget {
  const NovaSquareButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.selected = false,
    this.size = 46,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final NovaTokens tokens = NovaTokens.of(context);

    final Widget button = NovaFocusable(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(10),
      child: ExcludeFocus(child: Material(
        color: selected
            ? tokens.accent.withValues(alpha: 0.18)
            : tokens.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? tokens.accent : tokens.hairline,
            ),
          ),
          child: Icon(
            icon,
            size: size * 0.45,
            color: selected ? tokens.accent : tokens.text,
          ),
          ),
        ),
      )),
    );

    final String? text = tooltip;
    if (text == null) return button;
    return Tooltip(message: text, child: button);
  }
}

/// Título de sección con acción opcional («Ver todo»).
class NovaSectionHeader extends StatelessWidget {
  const NovaSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.leadingDot = false,
    this.padding = const EdgeInsets.fromLTRB(0, 0, 0, 14),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool leadingDot;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final NovaTokens tokens = NovaTokens.of(context);
    final String? action = actionLabel;

    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          if (leadingDot) ...<Widget>[
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: tokens.live, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(title, style: tokens.sectionTitle),
          ),
          if (action != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: tokens.link.color,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(48, 48),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(action, style: tokens.link),
            ),
        ],
      ),
    );
  }
}

/// Barra de progreso fina (lo que queda por ver).
class NovaProgressLine extends StatelessWidget {
  const NovaProgressLine({super.key, required this.value, this.height = 3});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final NovaTokens tokens = NovaTokens.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            ColoredBox(color: tokens.text.withValues(alpha: 0.16)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0),
              child: ColoredBox(color: tokens.accent),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila de filtros tipo píldora (Todo · Series · Películas · En vivo).
class NovaFilterBar extends StatelessWidget {
  const NovaFilterBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.padding = EdgeInsets.zero,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final NovaTokens tokens = NovaTokens.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: <Widget>[
          for (int i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Material(
                color: i == selectedIndex ? tokens.accent : tokens.surfaceHigh,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  onTap: () => onSelected(i),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 15 * tokens.scale, vertical: 13 * tokens.scale),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: i == selectedIndex
                            ? tokens.accent
                            : tokens.hairline,
                      ),
                    ),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: i == selectedIndex
                            ? tokens.background
                            : tokens.text.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Tarjeta con el fondo de superficie del diseño.
class NovaCard extends StatelessWidget {
  const NovaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 14,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final NovaTokens tokens = NovaTokens.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tokens.surfaceHigh,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: tokens.hairline),
      ),
      child: child,
    );
  }
}
