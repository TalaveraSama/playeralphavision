import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config/usage_reminder_config.dart';

/// Acumula tiempo en primer plano; cambiar de canal/ruta no reinicia el plazo.
/// El contador es de esta sesión: cerrar completamente la app lo reinicia.
class UsageReminderHost extends StatefulWidget {
  const UsageReminderHost({super.key, required this.config, required this.active,
    required this.navigatorKey, required this.child, this.onTimeout});
  final UsageReminderConfig config;
  final bool active;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final VoidCallback? onTimeout;
  @override
  State<UsageReminderHost> createState() => _UsageReminderHostState();
}
class _UsageReminderHostState extends State<UsageReminderHost> with WidgetsBindingObserver {
  Timer? _timer;
  final Stopwatch _clock = Stopwatch();
  late Duration _remaining;
  bool _showing = false;
  DialogRoute<bool>? _dialogRoute;
  bool _foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _remaining = Duration(minutes: widget.config.intervalMinutes);
    _start();
  }
  void _pause() {
    _timer?.cancel();
    _clock.stop();
    _remaining -= _clock.elapsed;
    if (_remaining.isNegative) _remaining = Duration.zero;
    _clock.reset();
  }
  void _start() {
    if (_showing || !_foreground || !widget.active || !widget.config.enabled) return;
    _clock.start();
    _timer = Timer(_remaining, _show);
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _pause();
    _start();
  }
  @override
  void didUpdateWidget(covariant UsageReminderHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.signature == widget.config.signature && oldWidget.active == widget.active) return;
    _pause();
    if (_showing) {
      final route = _dialogRoute;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && route != null && identical(route, _dialogRoute) && route.isCurrent) {
          widget.navigatorKey.currentState?.pop(true);
        }
      });
    }
    if (oldWidget.config.signature != widget.config.signature || !widget.active) {
      _remaining = Duration(minutes: widget.config.intervalMinutes);
    }
    _start();
  }
  Future<void> _show() async {
    _clock.stop(); _clock.reset();
    final navigator = widget.navigatorKey.currentState;
    if (!mounted || !_foreground || !widget.active || !widget.config.enabled) return;
    if (navigator == null) {
      _timer = Timer(const Duration(seconds: 1), _show);
      return;
    }
    _showing = true;
    final route = DialogRoute<bool>(context: navigator.context,
      barrierDismissible: false,
      builder: (_) => UsageReminderDialog(config: widget.config));
    _dialogRoute = route;
    final bool? continued = await navigator.push<bool>(route);
    _dialogRoute = null;
    if (!mounted) return;
    _showing = false;
    _remaining = Duration(minutes: widget.config.intervalMinutes);
    if (!widget.active || !widget.config.enabled) return;
    if (continued == true) {
      _start();
    } else {
      // Salir de las rutas de vídeo permite liberar el motor antes de salir.
      navigator.popUntil((route) => route.isFirst);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      if (widget.onTimeout != null) {
        widget.onTimeout!();
      } else if (Platform.isAndroid) {
        await SystemNavigator.pop();
      }
      // iOS no permite cerrar la app: queda en Inicio sin reproducción.
    }
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel(); _clock.stop();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => widget.child;
}

class UsageReminderDialog extends StatefulWidget {
  const UsageReminderDialog({super.key, required this.config});
  final UsageReminderConfig config;
  @override
  State<UsageReminderDialog> createState() => _UsageReminderDialogState();
}
class _UsageReminderDialogState extends State<UsageReminderDialog> {
  late int _seconds = widget.config.countdownSeconds;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || (WidgetsBinding.instance.lifecycleState != null &&
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed)) return;
      if (_seconds <= 1) {
        _timer?.cancel(); Navigator.of(context).pop(false);
      } else { setState(() => _seconds--); }
    });
  }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) => PopScope(canPop: false, child: AlertDialog(
    backgroundColor: const Color(0xED353A3D),
    title: Text(widget.config.title, textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
    content: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Text(widget.config.displayMessage, textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.4)),
        const SizedBox(height: 12),
        Text('Cierre en $_seconds s', style: const TextStyle(color: Colors.white70)),
      ]))),
    actionsAlignment: MainAxisAlignment.center,
    actions: <Widget>[FilledButton(autofocus: true,
      onPressed: () { _timer?.cancel(); Navigator.of(context).pop(true); },
      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF00A9E8), foregroundColor: Colors.white),
      child: Text(widget.config.buttonLabel))],
  ));
}
