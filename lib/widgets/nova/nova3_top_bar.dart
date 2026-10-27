import 'dart:async';

import 'package:flutter/material.dart';

import 'nova_ui.dart';
import '../../core/theme/nova_theme.dart';

/// Acciones reales y hora local. No simula Wi-Fi ni notificaciones del sistema.
class Nova3TopBar extends StatefulWidget {
  const Nova3TopBar({super.key, this.onSearch, required this.onProfile,
    this.onFavorites, this.onFilter, this.onHistory, this.onNotifications,
    this.showLogo = false});
  final VoidCallback? onSearch;
  final VoidCallback onProfile;
  final VoidCallback? onFavorites;
  final bool showLogo;
  final VoidCallback? onFilter;
  final VoidCallback? onHistory;
  final VoidCallback? onNotifications;

  @override
  State<Nova3TopBar> createState() => _Nova3TopBarState();
}

class _Nova3TopBarState extends State<Nova3TopBar> {
  Timer? _timer;
  DateTime _now = DateTime.now();
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
  Widget _action(IconData icon, String label, VoidCallback onTap) => Tooltip(
    message: label,
    child: Semantics(label: label, button: true,
      child: NovaFocusable(onTap: onTap, child: SizedBox(
        width: 40, height: 40,
        child: Icon(icon, size: 19.2, color: NovaTokens.of(context).muted),
      )),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final String time = '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(3.2, 6.4, 9.6, 6.4),
      child: Align(alignment: Alignment.centerRight,
        child: SingleChildScrollView(scrollDirection: Axis.horizontal, reverse: true,
          child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
            if (widget.onSearch != null) _action(Icons.search, 'Buscar', widget.onSearch!),
            if (widget.onFilter != null) _action(Icons.filter_list, 'Filtrar por sección', widget.onFilter!),
            if (widget.onHistory != null) _action(Icons.history, 'Historial', widget.onHistory!),
            if (widget.onFavorites != null) _action(Icons.bookmark_outline, 'Mi lista', widget.onFavorites!),
            _action(Icons.person_outline, 'Perfil', widget.onProfile),
            if (widget.onNotifications != null) _action(Icons.notifications_none, 'Notificaciones', widget.onNotifications!),
            const SizedBox(width: 12),
            Container(width: 1, height: 22, color: Colors.white24),
            const SizedBox(width: 12),
            Text(time, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.white70)),
          ]),
        ),
      ),
    );
  }
}
