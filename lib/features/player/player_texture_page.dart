import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/models/epg_entry.dart';
import '../../core/models/media_item.dart';
import '../../core/config/ads_config.dart';
import '../../widgets/player_notice.dart';
import '../../widgets/player_subtitles.dart';
import '../../core/config/app_config.dart' show parseHexColor;
import '../../widgets/nova/nova_ui.dart';
import '../../widgets/nova/nova3_live_layout.dart';
import '../../widgets/nova/nova3_loading.dart';
import '../../core/models/playable_item.dart';
import '../../core/config/config_controller.dart';
import '../../core/state/app_state.dart';
import '../../core/api/xtream_client.dart';

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
  late final AppState _securityApp;
  Timer? _heartbeatTimer;
  Future<bool>? _heartbeatTask;
  bool _authorizationBlocked = false;
  bool _securityRetryUsed = false;
  DateTime? _playbackRetryUntil;
  String? _playbackError;
  void _sessionChanged() {
    final reason = _securityApp.playbackBlock;
    if (reason != null && mounted) {
      _authorizationBlocked = true;
      _cancelPlaybackTimers();
      final id = _playerId;
      _playerId = 0;
      _channel?.setMethodCallHandler(null);
      _channel = null;
      if (id > 0) unawaited(_releaseNative(id));
      setState(() { _textureId = null; _buffering = false; _unavailable = true; _playbackError = reason; });
    }
  }
  void _cancelPlaybackTimers() {
    _heartbeatTimer?.cancel(); _retryTimer?.cancel(); _watchdog?.cancel();
    _autoSwitchTimer?.cancel(); _posTimer?.cancel();
  }
  Future<bool> _checkHeartbeat() {
    return _heartbeatTask ??= _performHeartbeat().whenComplete(() => _heartbeatTask = null);
  }
  Future<bool> _performHeartbeat() async {
    if (!mounted || !_foreground || _authorizationBlocked) return false;
    var delay = const Duration(seconds: 90);
    bool allowed = true;
    try { await _securityApp.playbackHeartbeat(); }
    on XtreamException catch (error) {
      allowed = false;
      if (error.statusCode == 429) {
        final retry = error.retryAfter ?? const Duration(seconds: 180);
        delay = retry > const Duration(seconds: 180) ? retry : const Duration(seconds: 180);
        _playbackRetryUntil = DateTime.now().add(delay);
      }
    } catch (_) { allowed = false; }
    if (mounted && _foreground && !_authorizationBlocked && !_paused) {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer(delay, () {
        if (_foreground && !_authorizationBlocked) unawaited(_resumeNativePlayback());
      });
    }
    return allowed && mounted && _foreground && !_authorizationBlocked;
  }

  bool _foreground = true;
  int _loadVersion = 0;
  List<PlayerSubtitleCue> _subtitleCues = const <PlayerSubtitleCue>[];
  Timer? _autoSwitchTimer;
  int _index = 0;
  int _failCount = 0;
  Timer? _retryTimer;
  Timer? _watchdog;
  Timer? _hideTimer;
  bool _showBar = true;
  bool _nova3Fullscreen = true;
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
    _securityApp = context.read<AppState>();
    _securityApp.addListener(_sessionChanged);
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
    if (state == AppLifecycleState.resumed) {
      _foreground = true;
      _forceImmersive();
      unawaited(_resumeNativePlayback());
      _startPosPolling();
      _scheduleHide();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _foreground = false;
      _heartbeatTimer?.cancel();
      _loadVersion++;
      _retryTimer?.cancel(); _watchdog?.cancel(); _autoSwitchTimer?.cancel();
      _hideTimer?.cancel(); _posTimer?.cancel();
      unawaited(_nativeLifecycle('suspendPlayback'));
    }
  }

  Future<void> _nativeLifecycle(String method) async {
    try { await _channel?.invokeMethod<void>(method); } catch (_) { /* Native activity also guards lifecycle. */ }
  }
  Future<void> _resumeNativePlayback() async {
    if (!await _checkHeartbeat()) return;
    await _nativeLifecycle('resumePlayback');
    if (mounted && _foreground && !_paused) await _nativeLifecycle('resume');
  }
  Future<void> _releaseNative(int id) async {
    try { await _host.invokeMethod<void>('release', <String, dynamic>{'id': id}); }
    catch (_) { /* Activity cleanup may already have released it. */ }
  }

  void _forceImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _createPlayer() async {
    try {
      final Map<dynamic, dynamic>? res = await _host.invokeMethod<Map<dynamic, dynamic>>('create', <String, dynamic>{
          'decoderMode': context.read<AppState>().videoDecodeMode.id,
          'bufferSeconds': context.read<AppState>().bufferSeconds,
        });
      if (res == null) throw StateError('ExoPlayer no devolvió una instancia');
      if (!mounted || _authorizationBlocked) {
        await _host.invokeMethod('release', <String, dynamic>{'id': res['id']});
        return;
      }
      final int id = (res['id'] as num).toInt();
      final int textureId = (res['textureId'] as num).toInt();
      _playerId = id;
      _channel = MethodChannel('media3_player_$id');
      _channel?.setMethodCallHandler(_onMethod);
      if (!mounted) return;
      setState(() => _textureId = textureId);
      await _load(_current);
    } catch (_) {
      if (mounted) {
        setState(() { _unavailable = true; _buffering = false; });
        _watchdog?.cancel();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No se pudo iniciar ExoPlayer. Vuelve a abrir el canal.')));
      }
    }
  }

  Future<void> _load(PlayableItem item) async {
    if (!mounted || _authorizationBlocked) return;
    final until = _playbackRetryUntil;
    if (until != null && until.isAfter(DateTime.now())) {
      setState(() { _unavailable = true; _buffering = false; _playbackError = 'Espera antes de volver a conectar. El panel limitó las peticiones.'; });
      return;
    }
    if (mounted) setState(() { _buffering = true; _networkSample = null; _subtitleCues = const <PlayerSubtitleCue>[]; });
    if (_unavailable && mounted) setState(() => _unavailable = false);
    _watchdog?.cancel();
    final version = ++_loadVersion;
    final channel = _channel;
    try {
      await channel?.invokeMethod<void>('stopPlayback');
      await _securityApp.preparePlayback();
      if (Uri.tryParse(item.url)?.scheme != 'https') {
        throw const XtreamException('Este canal necesita una URL HTTPS válida del proveedor.', statusCode: 400);
      }
      await _securityApp.checkMediaDrm(item);
      if (!mounted || version != _loadVersion || !_foreground || _authorizationBlocked) return;
      await channel?.invokeMethod('setUrl', <String, dynamic>{'url': item.url, 'headers': _securityApp.headers, 'isLive': item.isLive});
    if (!mounted || version != _loadVersion || !_foreground) return;
    await channel?.invokeMethod<void>('resumePlayback');
    if (!mounted || version != _loadVersion || !_foreground || _authorizationBlocked) return;
    _startWatchdog();
    await channel?.invokeMethod('start');
    if (_heartbeatTimer == null || !_heartbeatTimer!.isActive) {
      _heartbeatTimer = Timer(const Duration(seconds: 90), () => unawaited(_checkHeartbeat().then<void>((_) {})));
    }
    } on XtreamException catch (error) {
      _cancelPlaybackTimers();
      if (error.statusCode == 429) _playbackRetryUntil = DateTime.now().add(error.retryAfter ?? const Duration(seconds: 600));
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _securityApp.blockPlayback(error.message);
      } else {
        if (mounted) setState(() { _unavailable = true; _buffering = false; _playbackError = error.message; });
      }
    } catch (_) {
      if (mounted && _foreground && !_authorizationBlocked) _retry();
    }
  }

  Future<void> _onMethod(MethodCall call) async {
    switch (call.method) {
      case 'onCues':
        if (mounted) setState(() => _subtitleCues = PlayerSubtitleCue.decode(call.arguments));
        break;
      case 'onError':
        await _handlePlaybackError(call.arguments);
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

  Future<void> _handlePlaybackError(dynamic payload) async {
    if (!mounted || !_foreground || _authorizationBlocked) return;
    final data = payload is Map ? payload : const {};
    final status = (data['status'] as num?)?.toInt();
    final code = data['code'];
    if (status == 403 && !_securityRetryUsed &&
        (['device_required', 'device_invalid'].contains(code) || data['drm'] == true)) {
      _securityRetryUsed = true;
      _cancelPlaybackTimers();
      try {
        await _securityApp.preparePlayback(renewDevice: data['drm'] != true);
        if (mounted && _foreground && !_authorizationBlocked) await _load(_current);
      } catch (_) { await _securityApp.blockPlayback('No se pudo autorizar este aparato. Contacta con tu proveedor.'); }
      return;
    }
    if (status == 401 || status == 403) {
      await _securityApp.blockPlayback(code == 'device_revoked'
        ? 'Este aparato fue desvinculado. Contacta con tu proveedor.'
        : 'El panel no autoriza la cuenta o esta red. Contacta con tu proveedor.');
      return;
    }
    if (status == 429 || status == 503) {
      _cancelPlaybackTimers();
      if (status == 429) _playbackRetryUntil = DateTime.now().add(Duration(seconds: (data['retryAfter'] as num?)?.toInt() ?? 600));
      setState(() { _unavailable = true; _buffering = false;
        _playbackError = status == 429 ? 'Límite de conexiones o peticiones. Espera antes de volver a conectar.' : 'Canal temporalmente no disponible.'; });
      return; // No automatic channel switch or retry on panel denials.
    }
    _retry();
  }

  void _startWatchdog() {
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 12), () {
      if (mounted) _retry();
    });
  }

  void _retry() {
    if (!mounted || !_foreground || _authorizationBlocked) return;
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
    if (_authorizationBlocked || widget.playlist.length < 2) return;
    _securityRetryUsed = false;
    _playbackError = null;
    _failCount = 0;
    _retryTimer?.cancel();
    _autoSwitchTimer?.cancel();
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

  Future<void> _openTracks({bool subtitles = false}) async {
    _wakeControls();
    final Map<dynamic, dynamic>? res =
        await _channel?.invokeMethod<Map<dynamic, dynamic>>('getTracks');
    if (res == null || !mounted) return;

    final List<dynamic> audio = (res['audio'] as List<dynamic>?) ?? <dynamic>[];
    final List<dynamic> text = (res['text'] as List<dynamic>?) ?? <dynamic>[];
    final bool textDisabled = (res['textDisabled'] as bool?) ?? false;

    final List<Widget> options = <Widget>[];
    if (!subtitles && audio.isNotEmpty) {
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
    if (subtitles && text.isNotEmpty) {
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

    if (options.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(subtitles
          ? 'Este contenido no ofrece pistas de subtítulos compatibles.'
          : 'Este contenido no ofrece pistas de audio disponibles.')));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(subtitles ? 'Subtítulos' : 'Audio / idioma'),
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
    if (mounted) setState(() {
      _showBar = true;
      if (_nova3Live) _nova3Fullscreen = false;
    });
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() {
        _showBar = false;
        if (_nova3Live) _nova3Fullscreen = true;
      });
    });
  }

  void _onBackPressed() {
    if (_nova3Live) {
      if (_nova3Fullscreen) {
        _wakeControls();
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
    if (_authorizationBlocked) return;
    if (_paused) {
      await _channel?.invokeMethod('resume');
    } else {
      await _channel?.invokeMethod('pause');
    }
    if (!mounted) return;
    setState(() => _paused = !_paused);
    if (_paused) { _heartbeatTimer?.cancel(); } else { unawaited(_checkHeartbeat().then<void>((_) {})); }
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
    if (event is KeyRepeatEvent && _nova3Live && !_nova3Fullscreen &&
        <LogicalKeyboardKey>{LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.arrowDown,
          LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowRight}.contains(event.logicalKey)) {
      _scheduleHide();
      return false;
    }
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
          k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.arrowDown)) {
        if (_nova3Fullscreen) { _wakeControls(); return true; }
        _scheduleHide();
        return false;
      }
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
    _securityApp.removeListener(_sessionChanged);
    _heartbeatTimer?.cancel();
    _foreground = false;
    _loadVersion++;
    _channel?.setMethodCallHandler(null);
    _channel = null;
    _posTimer?.cancel();
    _retryTimer?.cancel();
    _watchdog?.cancel();
    _hideTimer?.cancel();
    _autoSwitchTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_onKey);
    WakelockPlus.disable();
    if (_playerId > 0) {
      final id = _playerId;
      _playerId = 0;
      unawaited(_releaseNative(id));
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

  Widget _videoWithSubtitles({required double bottomInset}) {
    final app = context.watch<AppState>();
    return Stack(fit: StackFit.expand, children: <Widget>[
      Texture(textureId: _textureId!),
      PlayerSubtitles(cues: _subtitleCues,
        color: parseHexColor(app.subtitleColor, Colors.white),
        fontSize: app.subtitleSize, bottomInset: bottomInset),
    ]);
  }

  Widget _buildPlayer(BuildContext context) {
    if (_nova3Live) {
      return PopScope(
        canPop: !_nova3Fullscreen,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _wakeControls();
        },
        child: Scaffold(backgroundColor: Colors.black, body: Nova3LiveLayout(
          playlist: widget.playlist,
          index: _index,
          fullscreen: _nova3Fullscreen,
          onBack: () => Navigator.of(context).pop(),
          onFullscreen: () {
            if (_nova3Fullscreen) {
              _wakeControls();
            } else {
              _hideTimer?.cancel();
              setState(() { _nova3Fullscreen = true; _showBar = false; });
            }
          },
          onSelect: (index) { if (index != _index) _playRelative(index - _index); },
          video: ColoredBox(color: Colors.black, child: _unavailable
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_playbackError ?? 'Canal no disponible', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white))))
              : _textureId == null
                  ? Nova3Loading(bytesPerSecond: _networkSample)
                  : Stack(fit: StackFit.expand, children: <Widget>[
                      _videoWithSubtitles(bottomInset: _nova3Fullscreen ? 24 : 104),
                      if (_buffering) Nova3Loading(bytesPerSecond: _networkSample),
                    ])),
          controls: Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
            _pbtn(Icons.skip_previous, () => _playRelative(-1)),
            _pbtn(_paused ? Icons.play_arrow : Icons.pause, _togglePlay),
            _pbtn(Icons.skip_next, () => _playRelative(1)),
            _pbtn(Icons.event_note_outlined, _showEpg),
            _pbtn(Icons.audiotrack, _openTracks),
            _pbtn(Icons.subtitles, () => _openTracks(subtitles: true)),
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
                  : _videoWithSubtitles(bottomInset: _showBar ? 100 : 24),
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
                      Text(
                        _playbackError ?? 'Canal no disponible (sin emisión)',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _playbackError == null ? 'Cambiando al siguiente canal\u2026' : 'Vuelve atrás o contacta con soporte.',
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
                      _pbtn(Icons.audiotrack, _openTracks),
            _pbtn(Icons.subtitles, () => _openTracks(subtitles: true)),
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
