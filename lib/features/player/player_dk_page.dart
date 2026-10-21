import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/models/playable_item.dart';

/// Reproductor Media3 (ExoPlayer moderno) + audio FFmpeg (MP2/AC3/DTS).
class PlayerDkPage extends StatefulWidget {
  const PlayerDkPage({super.key, required this.playlist, this.initialIndex = 0, this.headers = const <String, String>{}});
  final List<PlayableItem> playlist;
  final int initialIndex;
  final Map<String, String> headers;
  @override
  State<PlayerDkPage> createState() => _PlayerDkPageState();
}

class _PlayerDkPageState extends State<PlayerDkPage> {
  MethodChannel? _channel;
  int _index = 0;
  int _failCount = 0;
  Timer? _retryTimer;
  Timer? _watchdog;
  Timer? _hideTimer;
  bool _showBar = true;
  DateTime? _lastBack;

  PlayableItem get _current => widget.playlist.isEmpty
      ? const PlayableItem(title: 'Sin contenido', url: '')
      : widget.playlist[_index.clamp(0, widget.playlist.length - 1)];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.playlist.isEmpty ? 0 : widget.playlist.length - 1);
    WakelockPlus.enable();
    HardwareKeyboard.instance.addHandler(_onKey);
    _scheduleHide();
  }

  void _onViewCreated(int id) {
    _channel = MethodChannel('dk_video_player_$id');
    _channel?.setMethodCallHandler(_onMethod);
    _load(_current);
  }

  Future<void> _load(PlayableItem item) async {
    _startWatchdog();
    await _channel?.invokeMethod('setUrl', <String, dynamic>{'url': item.url, 'headers': widget.headers});
    await _channel?.invokeMethod('start');
  }

  Future<void> _onMethod(MethodCall call) async {
    switch (call.method) {
      case 'onError':
        _retry();
        break;
      case 'onReady':
        _failCount = 0;
        _watchdog?.cancel();
        break;
    }
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 10), () {
      if (mounted) _retry();
    });
  }

  void _retry() {
    _failCount++;
    if (_failCount >= 5) {
      _failCount = 0;
      if (widget.playlist.length > 1) {
        _playRelative(1);
      } else if (mounted) {
        Navigator.of(context).pop('native');
      }
      return;
    }
    _retryTimer?.cancel();
    _retryTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) _load(_current);
    });
  }

  Future<void> _playRelative(int offset) async {
    if (widget.playlist.length < 2) return;
    _failCount = 0;
    _retryTimer?.cancel();
    setState(() => _index = (_index + offset + widget.playlist.length) % widget.playlist.length);
    _wakeControls();
    await _load(_current);
  }

  // ---- controles / auto-ocultar / doble back ----------------------------

  void _wakeControls() {
    _lastBack = null;
    if (mounted) setState(() => _showBar = true);
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showBar = false);
    });
  }

  void _onBackPressed() {
    if (!_showBar) {
      _wakeControls();
      return;
    }
    final DateTime now = DateTime.now();
    if (_lastBack != null && now.difference(_lastBack!).inSeconds < 2) {
      Navigator.of(context).pop();
      return;
    }
    _lastBack = now;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pulsa atrás otra vez para salir'), duration: Duration(seconds: 2)),
    );
    _scheduleHide();
  }

  bool _onKey(KeyEvent event) {
    if (event is KeyDownEvent) {
      final LogicalKeyboardKey k = event.logicalKey;
      if (k == LogicalKeyboardKey.mediaRewind) { _playRelative(-1); return true; }
      if (k == LogicalKeyboardKey.mediaFastForward) { _playRelative(1); return true; }
      if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.goBack) {
        _onBackPressed();
        return true;
      }
      if (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.mediaPlayPause) {
        _wakeControls();
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _watchdog?.cancel();
    _hideTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    WakelockPlus.disable();
    _channel?.invokeMethod('release');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: AndroidView(viewType: 'dk_video_player', onPlatformViewCreated: _onViewCreated),
          ),
          if (_showBar)
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(24)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      IconButton(
                        tooltip: 'Salir',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Text(_current.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                      if (widget.playlist.length > 1) ...<Widget>[
                        IconButton(tooltip: 'Anterior', onPressed: () => _playRelative(-1), icon: const Icon(Icons.skip_previous, color: Colors.white)),
                        IconButton(tooltip: 'Siguiente', onPressed: () => _playRelative(1), icon: const Icon(Icons.skip_next, color: Colors.white)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
