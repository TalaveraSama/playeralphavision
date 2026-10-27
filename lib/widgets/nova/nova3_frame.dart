import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Armazón exclusivo de Nova3: nunca construye navegación inferior.
class Nova3Frame extends StatefulWidget {
  const Nova3Frame({super.key, required this.sidebar, required this.topBar,
    required this.child});
  final Widget sidebar;
  final Widget topBar;
  final Widget child;

  @override
  State<Nova3Frame> createState() => Nova3FrameState();
}

class Nova3FrameState extends State<Nova3Frame> {
  final FocusScopeNode _rail = FocusScopeNode(debugLabel: 'Nova3 sidebar');
  final FocusScopeNode _content = FocusScopeNode(debugLabel: 'Nova3 content');
  final GlobalKey _contentBounds = GlobalKey();
  Timer? _timer;
  bool _open = true;
  bool get isOpen => _open;

  void toggle() => _open ? collapse() : expand();

  void expand() {
    _timer?.cancel();
    setState(() => _open = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _rail.requestFocus();
    });
  }

  void collapse() {
    _timer?.cancel();
    setState(() => _open = false);
    _content.requestFocus();
  }

  void _scheduleHide() {
    _timer?.cancel();
    if (!_open || _rail.hasFocus) return;
    _timer = Timer(const Duration(seconds: 6), () {
      if (mounted && _open && !_rail.hasFocus) collapse();
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (_open && (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack)) {
      collapse();
      return KeyEventResult.handled;
    }
    if (_rail.hasFocus && key == LogicalKeyboardKey.arrowRight) {
      collapse();
      return KeyEventResult.handled;
    }
    if (!_open && key == LogicalKeyboardKey.arrowLeft) {
      // Solo desde el borde izquierdo: no robar el scroll de las filas.
      final box = _contentBounds.currentContext?.findRenderObject();
      final focused = FocusManager.instance.primaryFocus;
      if (box is RenderBox && focused != null &&
          focused.rect.left <= box.localToGlobal(Offset.zero).dx + 40) {
        expand();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _rail.dispose();
    _content.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Focus(
    onKeyEvent: _onKey,
    child: Row(children: <Widget>[
      if (_open)
        FocusScope(node: _rail, onFocusChange: (_) => _scheduleHide(), child: widget.sidebar)
      else
        SizedBox(width: 36, child: Align(alignment: Alignment.topCenter,
          child: IconButton(key: const ValueKey('nova3-open-menu'),
            tooltip: 'Abrir menú', onPressed: expand,
            icon: const Icon(Icons.chevron_right, color: Color(0xFF456BFF))))),
      Expanded(child: FocusScope(node: _content,
        onFocusChange: (_) => _scheduleHide(),
        child: Column(key: _contentBounds, children: <Widget>[
          Row(children: <Widget>[
            IconButton(key: const ValueKey('nova3-toggle-menu'),
              tooltip: _open ? 'Ocultar menú' : 'Mostrar menú',
              onPressed: toggle, icon: Icon(_open ? Icons.menu_open : Icons.menu)),
            Expanded(child: widget.topBar),
          ]),
          Expanded(child: widget.child),
        ]),
      )),
    ]),
  );
}
