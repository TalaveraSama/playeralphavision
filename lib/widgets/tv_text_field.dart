import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Campo de texto pensado para TV (Fire TV, Android TV y TV box).
///
/// Las flechas del mando mueven el foco entre campos **sin** abrir el teclado:
/// el teclado de pantalla aparece solo cuando el usuario pulsa OK sobre el campo
/// (o lo toca con el dedo). Pulsando OK otra vez (o Atrás) se cierra el teclado
/// y se sigue navegando con las flechas.
///
/// El campo real se marca con `skipTraversal: true` para que el foco nunca caiga
/// en él al moverse con el mando; este widget es el que recibe el foco y abre el
/// teclado cuando toca.
class TvTextField extends StatefulWidget {
  const TvTextField({
    super.key,
    required this.fieldFocus,
    required this.child,
    this.margin = EdgeInsets.zero,
  });

  /// Nodo real del campo de texto (el que abre el teclado).
  final FocusNode fieldFocus;

  final Widget child;
  final EdgeInsets margin;

  @override
  State<TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<TvTextField> {
  final FocusNode _navFocus = FocusNode(debugLabel: 'tv-field');
  bool _selected = false;

  @override
  void initState() {
    super.initState();
    _navFocus.addListener(_onNavFocus);
    widget.fieldFocus.addListener(_onFieldFocus);
  }

  @override
  void dispose() {
    _navFocus.removeListener(_onNavFocus);
    widget.fieldFocus.removeListener(_onFieldFocus);
    _navFocus.dispose();
    super.dispose();
  }

  void _onNavFocus() {
    if (mounted) setState(() => _selected = _navFocus.hasFocus);
  }

  void _onFieldFocus() {
    if (mounted) setState(() {});
  }

  bool get _typing => widget.fieldFocus.hasFocus;

  /// OK abre el teclado; OK (o Atrás) otra vez lo cierra y devuelve el foco a la
  /// navegación para poder seguir bajando al botón de entrar.
  void _toggleTyping() {
    if (_typing) {
      widget.fieldFocus.unfocus();
      _navFocus.requestFocus();
    } else {
      widget.fieldFocus.requestFocus();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final LogicalKeyboardKey key = event.logicalKey;
    final bool select = key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA;

    if (select) {
      _toggleTyping();
      return KeyEventResult.handled;
    }

    if (_typing &&
        (key == LogicalKeyboardKey.escape ||
            key == LogicalKeyboardKey.goBack)) {
      _toggleTyping();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = Theme.of(context).colorScheme.primary;

    return Focus(
      focusNode: _navFocus,
      onKeyEvent: _onKey,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: widget.margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selected ? accent : Colors.transparent,
            width: 1.4,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}
