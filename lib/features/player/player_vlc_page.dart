import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:provider/provider.dart';

import '../../core/models/epg_entry.dart';
import '../../core/models/playable_item.dart';
import '../../core/state/app_state.dart';
import '../../widgets/nova/nova_ui.dart';

/// Reproductor basado en **libVLC** (el mismo motor que usan las apps IPTV
/// de escritorio). Todo por software con FFmpeg: lee MP2/AC3/EAC3/DTS/HEVC y
/// hace el cambio de canal muy rapido reutilizando la misma instancia de VLC.
class PlayerVlcPage extends StatefulWidget {
  const PlayerVlcPage({
    super.key,
    required this.playlist,
    this.initialIndex = 0,
    this.headers,
  });

  final List<PlayableItem> playlist;
  final int initialIndex;
  final Map<String, String>? headers;

  @override
  State<PlayerVlcPage> createState() => _PlayerVlcPageState();
}

class _PlayerVlcPageState extends State<PlayerVlcPage> {
  late final int _start = widget.initialIndex
      .clamp(0, widget.playlist.isEmpty ? 0 : widget.playlist.length - 1);
  late int _index = _start;
  late VlcPlayerController _controller;
  bool _showBar = true;
  bool _ready = false;
  String? _error;
  Timer? _hideTimer;
  Timer? _initTimer;

  PlayableItem get _current => widget.playlist[_index];
  bool get _isLive => _current.isLive;

  @override
  void initState() {
    super.initState();
    _controller = _buildController(widget.playlist[_start].url);
    _controller.addListener(_onValue);
    _restartHide();
    // Si libVLC no arranca en 15 s, se reabre el canal con ExoPlayer.
    _initTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted || _ready) return;
      Navigator.of(context).pop('exo');
    });
  }

  VlcPlayerController _buildController(String url) {
    final Map<String, String>? h = widget.headers;
    final String ua = (h != null && h.isNotEmpty)
        ? (h['User-Agent'] ?? h['user-agent'] ?? 'AlphaVision-Player')
        : 'AlphaVision-Player';
    return VlcPlayerController.network(
      url,
      // Todo por software: el hardware da problemas en Fire TV / TV box.
      hwAcc: HwAcc.disabled,
      autoPlay: true,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions(<String>[
          // Cache mas generoso: antes se quedaba en "cargando" en vivo.
          VlcAdvancedOptions.networkCaching(_isLive ? 2500 : 4000),
          VlcAdvancedOptions.liveCaching(1500),
        ]),
        http: VlcHttpOptions(<String>[
          VlcHttpOptions.httpReconnect(true),
          VlcHttpOptions.httpContinuous(true),
          VlcHttpOptions.httpUserAgent(ua),
        ]),
        extras: <String>[
          '--no-video-title-show',
          '--no-drop-late-frames',
          '--no-skip-frames',
          '--clock-jitter=0',
          '--clock-synchro=0',
          '--avcodec-hw=none',
        ],
      ),
    );
  }

  void _onValue() {
    if (!mounted) return;
    final VlcPlayerValue v = _controller.value;
    final bool changed = _ready != v.isInitialized || _error != v.errorDescription;
    _ready = v.isInitialized;
    if (_ready) _initTimer?.cancel();
    _error = v.errorDescription;
    if (changed) setState(() {});
  }

  void _restartHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showBar = false);
    });
  }

  void _wake() {
    if (!_showBar) setState(() => _showBar = true);
    _restartHide();
  }

  void _tapWake() {
    if (_showBar) {
      _restartHide();
    } else {
      _wake();
    }
  }

  Future<void> _togglePlay() async {
    if (_controller.value.isPlaying) {
      await _controller.pause();
    } else {
      await _controller.play();
    }
    setState(() {});
    _restartHide();
  }

  Future<void> _seekRelative(int seconds) async {
    if (_isLive) {
      _wake();
      return;
    }
    final Duration total = _controller.value.duration;
    if (total.inSeconds <= 0) return;
    final Duration pos = _controller.value.position;
    final int target = (pos.inSeconds + seconds).clamp(0, total.inSeconds);
    await _controller.seekTo(Duration(seconds: target));
    _restartHide();
  }

  Future<void> _seekTo(Duration at) async {
    if (_isLive) return;
    await _controller.seekTo(at);
  }

  Future<void> _playChannel(int offset) async {
    if (widget.playlist.length < 2) return;
    setState(() {
      _index =
          (_index + offset + widget.playlist.length) % widget.playlist.length;
      _ready = false;
      _error = null;
    });
    _wake();
    try {
      // Reutiliza la instancia de VLC: cambio de canal casi instantaneo.
      await _controller.setMediaFromNetwork(
        _current.url,
        autoPlay: true,
        hwAcc: HwAcc.disabled,
      );
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo cambiar de canal: $e');
    }
  }

  List<int> _trackIds(dynamic tracks) {
    final List<int> out = <int>[];
    if (tracks is Map) {
      for (final dynamic key in tracks.keys) {
        final int? id = int.tryParse('$key');
        if (id != null) out.add(id);
      }
    }
    out.sort();
    return out;
  }

  Future<void> _cycleAudio() async {
    try {
      final dynamic tracks = await _controller.getAudioTracks();
      final List<int> ids = _trackIds(tracks);
      if (ids.length < 2) return;
      final int current = _controller.value.activeAudioTrack ?? ids.first;
      final int next = ids[(ids.indexOf(current) + 1) % ids.length];
      await _controller.setAudioTrack(next);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 1),
            content: Text('Audio: pista $next de ${ids.length}'),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _cycleSubs() async {
    try {
      final dynamic tracks = await _controller.getSpuTracks();
      final List<int> ids = _trackIds(tracks)..removeWhere((int id) => id < 0);
      final List<int> cycle = <int>[-1, ...ids];
      final int current = _controller.value.activeSpuTrack ?? -1;
      final int next = cycle[(cycle.indexOf(current) + 1) % cycle.length];
      await _controller.setSpuTrack(next);
    } catch (_) {}
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

  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final LogicalKeyboardKey k = event.logicalKey;
    if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.goBack) {
      Navigator.of(context).pop();
      return true;
    }
    if (_showBar) {
      if (k == LogicalKeyboardKey.arrowUp ||
          k == LogicalKeyboardKey.arrowDown ||
          k == LogicalKeyboardKey.arrowLeft ||
          k == LogicalKeyboardKey.arrowRight ||
          k == LogicalKeyboardKey.select ||
          k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.numpadEnter) {
        return false;
      }
    }
    if (k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.arrowDown) {
      setState(() => _showBar = true);
      _restartHide();
      return true;
    }
    if (k == LogicalKeyboardKey.mediaPlayPause) {
      _togglePlay();
      return true;
    }
    if (k == LogicalKeyboardKey.channelUp) {
      _playChannel(1);
      return true;
    }
    if (k == LogicalKeyboardKey.channelDown) {
      _playChannel(-1);
      return true;
    }
    if (k == LogicalKeyboardKey.mediaRewind) {
      if (_isLive) {
        _playChannel(-1);
      } else {
        _seekRelative(-10);
      }
      return true;
    }
    if (k == LogicalKeyboardKey.mediaFastForward) {
      if (_isLive) {
        _playChannel(1);
      } else {
        _seekRelative(10);
      }
      return true;
    }
    if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter) {
      setState(() => _showBar = true);
      _restartHide();
      return true;
    }
    return false;
  }

  static String _fmt(Duration d) {
    final int h = d.inHours;
    final int m = d.inMinutes.remainder(60);
    final int s = d.inSeconds.remainder(60);
    final String mm = m.toString().padLeft(2, '0');
    final String ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _initTimer?.cancel();
    _controller.removeListener(_onValue);
    _controller.dispose();
    super.dispose();
  }

  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: Row(
        children: <Widget>[
          _pbtn(Icons.close, () => Navigator.of(context).pop()),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _current.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          if (!_ready && _error == null)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white70),
            ),
          if (_isLive) _pbtn(Icons.event_note_outlined, _showEpg),
          _pbtn(Icons.audiotrack_outlined, _cycleAudio),
          _pbtn(Icons.subtitles, _cycleSubs),
          if (widget.playlist.length > 1) ...<Widget>[
            _pbtn(Icons.skip_previous, () => _playChannel(-1)),
            _pbtn(Icons.skip_next, () => _playChannel(1)),
          ],
        ],
      ),
    );
  }

  Widget _bottomBar() {
    final VlcPlayerValue v = _controller.value;
    final bool seekable = !_isLive && v.duration.inSeconds > 0;
    final double posSec = v.position.inSeconds
        .clamp(0, seekable ? v.duration.inSeconds : 0)
        .toDouble();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
          if (seekable)
            Row(
              children: <Widget>[
                Text(_fmt(v.position),
                    style:
                        const TextStyle(color: Colors.white, fontSize: 12)),
                Expanded(
                  child: ExcludeFocus(
                    child: Slider(
                      value: posSec,
                      max: v.duration.inSeconds.toDouble(),
                      onChanged: (double value) =>
                          _seekTo(Duration(seconds: value.round())),
                    ),
                  ),
                ),
                Text(_fmt(v.duration),
                    style:
                        const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ),
          Row(
            children: <Widget>[
              _pbtn(
                v.isPlaying ? Icons.pause : Icons.play_arrow,
                _togglePlay,
                autofocus: true,
              ),
              const SizedBox(width: 8),
              const Spacer(),
              Text(
                _isLive ? 'EN VIVO' : 'PELÍCULA',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: KeyboardListener(
        focusNode: FocusNode(),
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _tapWake,
              child: LayoutBuilder(
                builder: (BuildContext ctx, BoxConstraints c) => VlcPlayer(
                  controller: _controller,
                  aspectRatio: c.maxWidth / c.maxHeight,
                  placeholder: const Center(
                    child: CircularProgressIndicator(color: Colors.white70),
                  ),
                ),
              ),
            ),
            if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'libVLC: $_error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            if (_showBar) ...<Widget>[
              Positioned(left: 0, right: 0, top: 0, child: _topBar()),
              Positioned(left: 0, right: 0, bottom: 0, child: _bottomBar()),
            ],
          ],
        ),
      ),
    );
  }
}
