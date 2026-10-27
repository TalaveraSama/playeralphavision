import 'dart:async';

import 'package:flutter/material.dart';

import 'nova_ui.dart';
import '../../core/theme/nova_theme.dart';

/// Acciones reales y hora local. No simula Wi-Fi ni notificaciones del sistema.
class Nova3TopBar extends StatefulWidget {
  const Nova3TopBar({super.key, this.onSearch, required this.onProfile,
    this.onFavorites, this.showLogo = false});
  final VoidCallback? onSearch;
  final VoidCallback onProfile;
  final VoidCallback? onFavorites;
  final bool showLogo;

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
        width: 48, height: 48,
        child: Icon(icon, size: 24, color: NovaTokens.of(context).muted),
      )),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final String time = '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 20, 12),
      child: Row(children: <Widget>[
        if (widget.showLogo)
          const Expanded(child: Align(alignment: Alignment.centerLeft,
            child: FittedBox(fit: BoxFit.scaleDown, child: NovaLogo(fontSize: 20, color: Colors.white))))
        else const Spacer(),
        if (widget.onSearch != null)
          _action(Icons.search, 'Buscar', widget.onSearch!),
        if (widget.onFavorites != null) ...<Widget>[
          const SizedBox(width: 6),
          _action(Icons.bookmark_outline, 'Mi lista', widget.onFavorites!),
        ],
        const SizedBox(width: 6),
        _action(Icons.person_outline, 'Perfil', widget.onProfile),
        if (!widget.showLogo) ...<Widget>[
          const SizedBox(width: 20),
          Container(width: 1, height: 22, color: Colors.white24),
          const SizedBox(width: 20),
          Text(time, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w400, color: Colors.white70)),
        ],
      ]),
    );
  }
}
