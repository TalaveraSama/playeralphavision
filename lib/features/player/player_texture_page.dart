import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/models/epg_entry.dart';
import '../../core/models/media_item.dart';
import '../../core/config/ads_config.dart';
import '../../widgets/player_notice.dart';
import '../../widgets/nova/nova_ui.dart';
import '../../widgets/nova/nova3_live_layout.dart';
import '../../widgets/nova/nova3_loading.dart';
import '../../core/models/playable_item.dart';
import '../../core/config/config_controller.dart';
import '../../core/state/app_state.dart';

/// Reproductor Media3 + FFmpeg **dibujado como textura de Flutter**
/// (SurfaceTexture). Igual que hace `video_player`/la app Purple: sin
/// SurfaceView, sin parpadeos ni cuadros congelados en Fire TV.
class PlayerTexturePage extends StatefulWidget {
  const PlayerTexturePage({
    super.key,
    required this.playlist,
    this.initialIndex = 0,
    this.headers = const <String, String>{},
    this.categoryName,
  });

  final List<PlayableItem> playlist;
  final int initialIndex;
  final Map<String, String> headers;
  final String? categoryName;

  @override
  State<PlayerTexturePage> createState() => _PlayerTexturePageState();
}

class _PlayerTexturePageState extends State<PlayerTexturePage>
    with WidgetsBindingObserver {
  static const MethodChannel _host = MethodChannel('media3_player');

  MethodChannel? _channel;
  int? _textureId;
  int _playerId = 0;
  bool _unavailable = false;
  Timer? _autoSwitchTimer;
  int _index = 0;
  int _failCount = 0;
  Timer? _retryTimer;
  Timer? _watchdog;
  Timer? _hideTimer;
  bool _showBar = true;
  bool _nova3Fullscreen = false;
  bool _buffering = true;
  double? _networkSample;
  bool get _nova3Live => _current.isLive &&
      context.read<ConfigController>().theme.isNova3;
  DateTime? _lastBack;

  PlayableItem get _current => widget.playlist.isEmpty
      ? const PlayableItem(title: 'Sin contenido', url: '')
      : widget.playlist[_index.clamp(0, widget.playlist.length - 1)];

  @override
  void initState() {
    super.initState();
    // Algunos telefonos devuelven las barras al entrar a pantalla completa:
    // se reafirma el modo inmersivo al abrir el reproductor.
    _forceImmersive();
    WidgetsBinding.instance.addObserver(this);
    _index = widget.initialIndex.clamp(0, widget.playlist.isEmpty ? 0 : widget.playlist.length - 1);
    WakelockPlus.enable();
    HardwareKeyboard.instance.addHandler(_onKey);
    _startPosPolling();
    _scheduleHide();
    _createPlayer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _forceImmersive();
  }

  void _forceImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _createPlayer() async {
    final String decMode = context.read<AppState>().videoDecoder;
    try {
      final Map<dynamic, dynamic>? res = await _host.invokeMethod<Map<dynamic, dynamic>>('create');
      if (res == null) return;
      final int id = (res['id'] as num).toInt();
      final int textureId = (res['textureId'] as num).toInt();
      _playerId = id;
      _channel = MethodChannel('media3_player_$id');
      _channel?.setMethodCallHandler(_onMethod);
      await _channel?.invokeMethod('setDecoderMode', <String, dynamic>{
        'mode': decMode,
      });
      if (!mounted) return;
      setState(() => _textureId = textureId);
      await _load(_current);
    } catch (_) {
      if (mounted) Navigator.of(context).pop('mpv');
    }
  }

  Future<void> _load(PlayableItem item) async {
    if (mounted) setState(() { _buffering = true; _networkSample = null; });
    if (_unavailable && mounted) setState(() => _unavailable = false);
    _startWatchdog();
    await _channel?.invokeMethod('setUrl', <String, dynamic>{'url': item.url, 'headers': widget.headers, 'isLive': item.isLive});
    await _channel?.invokeMethod('start');
  }

  Future<void> _onMethod(MethodCall call) async {
    switch (call.method) {
      case 'onError':
        _retry();
        break;
      case 'onBuffering':
        if (mounted) setState(() => _buffering = call.arguments == true);
        break;
      case 'onNetworkSample':
        if (mounted && call.arguments is num) {
          setState(() => _networkSample = (call.arguments as num).toDouble());
        }
        break;
      case 'onReady':
        if (mounted) setState(() => _buffering = false);
        _failCount = 0;
        _watchdog?.cancel();
        break;
    }
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 12), () {
      if (mounted) _retry();
    });
  }

  void _retry() {
    _failCount++;
    if (_failCount >= 8) {
      _failCount = 0;
      // Canal caido: se avisa y se salta solo al siguiente.
      if (mounted) setState(() => _unavailable = true);
      _autoSwitchTimer?.cancel();
      _autoSwitchTimer = Timer(const Duration(seconds: 5), () {
        if (!mounted) return;
        setState(() => _unavailable = false);
        if (widget.playlist.length > 1) {
          _playRelative(1);
        } else if (context
            .read<ConfigController>()
            .config
            .features
            .vlcPlayer) {
          // Segunda opcion disponible: se delega al motor libmpv.
          Navigator.of(context).pop('mpv');
        } else {
          // NO expulsar de la app: se queda reintentando.
          setState(() => _unavailable = false);
          _startWatchdog();
        }
      });
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

  // ---- audio / subtítulos ----------------------------------------------

  String _langName(String code) {
    switch (code.toLowerCase()) {
      case 'spa':
      case 'es':
        return 'Español';
      case 'eng':
      case 'en':
        return 'Inglés';
      case 'por':
      case 'pt':
        return 'Portugués';
      case 'fra':
      case 'fr':
        return 'Francés';
      case 'deu':
      case 'ger':
      case 'de':
        return 'Alemán';
      case 'ita':
      case 'it':
        return 'Italiano';
      default:
        return code.toUpperCase();
    }
  }

  String _trackLabel(Map<dynamic, dynamic> t) {
    final String label = (t['label'] as String?)?.trim() ?? '';
    final String lang = (t['language'] as String?)?.trim() ?? '';
    if (label.isNotEmpty) return label;
    if (lang.isNotEmpty) return _langName(lang);
    return 'Pista ${(t['index'] as num).toInt() + 1}';
  }

  Future<void> _openTracks() async {
    _wakeControls();
    final Map<dynamic, dynamic>? res =
        await _channel?.invokeMethod<Map<dynamic, dynamic>>('getTracks');
    if (res == null || !mounted) return;

    final List<dynamic> audio = (res['audio'] as List<dynamic>?) ?? <dynamic>[];
    final List<dynamic> text = (res['text'] as List<dynamic>?) ?? <dynamic>[];
    final bool textDisabled = (res['textDisabled'] as bool?) ?? false;

    final List<Widget> options = <Widget>[];
    if (audio.isNotEmpty) {
      options.add(const Padding(
        padding: EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Text('Audio', style: TextStyle(fontWeight: FontWeight.bold)),
      ));
      for (final dynamic raw in audio) {
        final Map<dynamic, dynamic> a = raw as Map<dynamic, dynamic>;
        final int idx = (a['index'] as num).toInt();
        final bool sel = (a['selected'] as bool?) ?? false;
        options.add(ListTile(
          dense: true,
          title: Text(_trackLabel(a)),
          leading: Icon(sel ? Icons.radio_button_checked : Icons.radio_button_unchecked),
          onTap: () async {
            Navigator.of(context).pop();
            await _channel?.invokeMethod('selectAudio', <String, dynamic>{'index': idx});
          },
        ));
      }
    }
    if (text.isNotEmpty) {
      options.add(const Padding(
        padding: EdgeInsets.fromLTRB(8, 12, 8, 4),
        child: Text('Subtítulos', style: TextStyle(fontWeight: FontWeight.bold)),
      ));
      options.add(ListTile(
        dense: true,
        title: const Text('Desactivados'),
        leading: Icon(textDisabled ? Icons.radio_button_checked : Icons.radio_button_unchecked),
        onTap: () async {
          Navigator.of(context).pop();
          await _channel?.invokeMethod('selectText', <String, dynamic>{'index': -1});
        },
      ));
      for (final dynamic raw in text) {
        final Map<dynamic, dynamic> t = raw as Map<dynamic, dynamic>;
        final int idx = (t['index'] as num).toInt();
        final bool sel = (t['selected'] as bool?) ?? false;
        options.add(ListTile(
          dense: true,
          title: Text(_trackLabel(t)),
          leading: Icon(sel ? Icons.radio_button_checked : Icons.radio_button_unchecked),
          onTap: () async {
            Navigator.of(context).pop();
            await _channel?.invokeMethod('selectText', <String, dynamic>{'index': idx});
          },
        ));
      }
    }

    if (options.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Audio y subtítulos'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: options,
          ),
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cerrar')),
        ],
      ),
    );
    _wakeControls();
  }

  // ---- controles / auto-ocultar / doble back ----------------------------

  /// En movil/tablet: tocar el video vuelve a mostrar los controles.
  void _tapWake() {
    if (_showBar) {
      _scheduleHide();
    } else {
      _wakeControls();
    }
  }

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
    if (_nova3Live) {
      if (_nova3Fullscreen) {
        setState(() => _nova3Fullscreen = false);
      } else {
        Navigator.of(context).pop();
      }
      return;
    }
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

  int _posMs = 0;
  int _durMs = 0;

  Future<void> _togglePlay() async {
    if (_paused) {
      await _channel?.invokeMethod('resume');
    } else {
      await _channel?.invokeMethod('pause');
    }
    setState(() => _paused = !_paused);
    _wakeControls();
  }

  Future<void> _seek(int seconds) async {
    // En directo no hay seek: se ignora (antes saltaba al minuto 0 = reinicio).
    if (widget.playlist[_index].isLive) { _wakeControls(); return; }
    if (_durMs <= 0) { _wakeControls(); return; }
    final int target = (_posMs + seconds * 1000).clamp(0, _durMs);
    await _channel?.invokeMethod('seekTo', <String, dynamic>{'ms': target});
    _posMs = target;
    setState(() {});
    _wakeControls();
  }

  bool _paused = false;

  Timer? _posTimer;

  void _startPosPolling() {
    _posTimer?.cancel();
    _posTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final int id = _playerId;
      if (id <= 0) return;
      try {
        final MethodChannel? ch = _channel;
        if (ch == null) return;
        final Map<dynamic, dynamic>? r =
            await ch.invokeMethod<Map<dynamic, dynamic>>('getPosition');
        if (r != null && mounted) {
          setState(() {
            _posMs = (r['pos'] as num?)?.toInt() ?? 0;
            _durMs = (r['dur'] as num?)?.toInt() ?? 0;
          });
        }
      } catch (_) {}
    });
  }

  Widget _pbtn(IconData icon, VoidCallback onTap, {bool autofocus = false}) {
    return NovaFocusable(
      onTap: onTap,
      autofocus: autofocus,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        child: Icon(icon, color: Colors.white, size: 23),
      ),
    );
  }

  Future<void> _showEpg() async {
    final String? sid = _current.streamId;
    if (sid == null) return;
    List<EpgEntry> entries = <EpgEntry>[];
    try {
      entries = await context.read<AppState>().client.shortEpg(sid);
    } catch (_) {}
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141D2E),
      builder: (BuildContext ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            ListTile(
              title: Text(_current.title,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800)),
            ),
            const Divider(),
            if (entries.isEmpty)
              const ListTile(
                title: Text('Sin guía disponible',
                    style: TextStyle(color: Colors.white70)),
              ),
            for (final EpgEntry e in entries)
              ListTile(
                title: Text(e.title,
                    style: const TextStyle(color: Colors.white)),
                subtitle: Text(e.timeRange,
                    style: const TextStyle(color: Colors.white54)),
              ),
          ],
        ),
      ),
    );
  }

  static String _fmt(int ms) {
    final int total = ms ~/ 1000;
    final int h = total ~/ 3600;
    final int m = (total % 3600) ~/ 60;
    final int s = total % 60;
    final String mm = m.toString().padLeft(2, '0');
    final String ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  String _epgNow = '';

  Future<void> _loadEpgNow() async {
    final String? sid = _current.streamId;
    if (sid == null) return;
    try {
      final List<EpgEntry> list =
          await context.read<AppState>().client.shortEpg(sid);
      if (!mounted || list.isEmpty) return;
      final EpgEntry e = list.first;
      setState(() => _epgNow = '${e.title}  ·  ${e.timeRange}');
    } catch (_) {}
  }

  bool _onKey(KeyEvent event) {
    if (ModalRoute.of(context)?.isCurrent != true) return false;
    if (event is KeyDownEvent) {
      final LogicalKeyboardKey k = event.logicalKey;
      // Teclas universales del mando: play/pausa y seek.
      if (k == LogicalKeyboardKey.mediaPlayPause) { _togglePlay(); return true; }
      // En VIVO: pasar canal. En PELICULA: -/+10 s.
      final bool live = widget.playlist[_index].isLive;
      if (k == LogicalKeyboardKey.mediaRewind) {
        if (live) { _playRelative(-1); } else { _seek(-10); }
        return true;
      }
      if (k == LogicalKeyboardKey.mediaFastForward) {
        if (live) { _playRelative(1); } else { _seek(10); }
        return true;
      }
      // Teclas CH+ / CH- (muchos mandos de Android TV las envian).
      if (k == LogicalKeyboardKey.channelUp) { _playRelative(1); return true; }
      if (k == LogicalKeyboardKey.channelDown) { _playRelative(-1); return true; }
      // En el marco Nova3, OK y flechas pertenecen al foco de la lista.
      if (_nova3Live && (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.arrowLeft || k == LogicalKeyboardKey.arrowRight ||
          k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.arrowDown)) return false;
      // Direccionales: navegan por los botones (no hacen seek).
      if (_showBar &&
          (k == LogicalKeyboardKey.arrowLeft ||
              k == LogicalKeyboardKey.arrowRight ||
              k == LogicalKeyboardKey.arrowUp ||
              k == LogicalKeyboardKey.arrowDown)) {
        return false;
      }
      if (!_showBar &&
          (k == LogicalKeyboardKey.arrowUp ||
              k == LogicalKeyboardKey.arrowDown ||
              k == LogicalKeyboardKey.arrowLeft ||
              k == LogicalKeyboardKey.arrowRight)) {
        _wakeControls();
        return true;
      }
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
    _autoSwitchTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    WakelockPlus.disable();
    if (_playerId > 0) {
      _host.invokeMethod('release', <String, dynamic>{'id': _playerId});
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PlayerNotice(
    mediaType: _current.isLive ? AdMediaType.live :
      _current.source?.kind == MediaKind.series ? AdMediaType.series : AdMediaType.vod,
    title: _current.title,
    categoryName: widget.categoryName,
    child: _buildPlayer(context),
  );

  Widget _buildPlayer(BuildContext context) {
    if (_nova3Live) {
      return PopScope(
        canPop: !_nova3Fullscreen,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) setState(() => _nova3Fullscreen = false);
        },
        child: Scaffold(backgroundColor: Colors.black, body: Nova3LiveLayout(
          playlist: widget.playlist,
          index: _index,
          fullscreen: _nova3Fullscreen,
          onBack: () => Navigator.of(context).pop(),
          onFullscreen: () => setState(() => _nova3Fullscreen = !_nova3Fullscreen),
          onSelect: (index) { if (index != _index) _playRelative(index - _index); },
          video: ColoredBox(color: Colors.black, child: _unavailable
              ? const Center(child: Text('Canal no disponible', style: TextStyle(color: Colors.white)))
              : _textureId == null
                  ? Nova3Loading(bytesPerSecond: _networkSample)
                  : Stack(fit: StackFit.expand, children: <Widget>[
                      Texture(textureId: _textureId!),
                      if (_buffering) Nova3Loading(bytesPerSecond: _networkSample),
                    ])),
          controls: Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
            _pbtn(Icons.skip_previous, () => _playRelative(-1)),
            _pbtn(_paused ? Icons.play_arrow : Icons.pause, _togglePlay),
            _pbtn(Icons.skip_next, () => _playRelative(1)),
            _pbtn(Icons.event_note_outlined, _showEpg),
            _pbtn(Icons.subtitles, _openTracks),
          ]),
        )),
      );
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Movil/tablet: tocar el video muestra/oculta los controles.
              onTap: _tapWake,
              child: _textureId == null
                  ? const ColoredBox(
                      color: Colors.black,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : Texture(textureId: _textureId!),
            ),
          ),
          if (_unavailable)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.86),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.tv_off_outlined,
                          color: Colors.white70, size: 52),
                      const SizedBox(height: 14),
                      const Text(
                        'Canal no disponible (sin emisión)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Cambiando al siguiente canal\u2026',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      const SizedBox(height: 18),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Salir'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_showBar && widget.playlist[_index].isLive)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 56),
                  child: Material(
                    color: const Color(0xB30C111B),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      child: Text(
                        _epgNow,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
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
                      _pbtn(Icons.close, () => Navigator.of(context).pop()),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Text(_current.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                      if (widget.playlist[_index].isLive)
                        _pbtn(Icons.event_note_outlined, _showEpg),
                      _pbtn(Icons.subtitles, _openTracks),
                      if (widget.playlist.length > 1) ...<Widget>[
                        _pbtn(Icons.skip_previous, () => _playRelative(-1)),
                        _pbtn(Icons.skip_next, () => _playRelative(1)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          if (_showBar)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: <Color>[Color(0xE6000000), Color(0x00000000)],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (_durMs > 0)
                      ExcludeFocus(
                        child: Slider(
                        value: _posMs.clamp(0, _durMs).toDouble(),
                        max: _durMs.toDouble(),
                        onChanged: (double v) {
                          setState(() => _posMs = v.round());
                        },
                          onChangeEnd: (double v) async {
                            await _channel?.invokeMethod('seekTo',
                                <String, dynamic>{'ms': v.round()});
                          },
                        ),
                      ),
                    Row(
                      children: <Widget>[
                        _pbtn(
                          _paused ? Icons.play_arrow : Icons.pause,
                          _togglePlay,
                          autofocus: true,
                        ),
                        const SizedBox(width: 8),
                        Text(_fmt(_posMs),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)),
                        const SizedBox(width: 6),
                        const Text('/',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 12)),
                        const SizedBox(width: 6),
                        Text(_fmt(_durMs),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        const Spacer(),
                        Text(
                          widget.playlist[_index].isLive ? 'EN VIVO' : 'PELÍCULA',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
