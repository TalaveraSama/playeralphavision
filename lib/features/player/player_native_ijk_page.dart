import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/epg_entry.dart';
import '../../core/models/playable_item.dart';
import '../../core/state/app_state.dart';

/// Reproductor ijkplayer **nativo** (PlatformView + `IjkMediaPlayer`).
///
/// A diferencia del plugin `fijkplayer_plus`, aqui SI se lee la lista real de
/// pistas (`getTrackInfo`) y se pueden cambiar audio y subtitulos.
class PlayerNativeIjkPage extends StatefulWidget {
  const PlayerNativeIjkPage({
    super.key,
    required this.playlist,
    this.initialIndex = 0,
    this.headers,
  });

  final List<PlayableItem> playlist;
  final int initialIndex;
  final Map<String, String>? headers;

  @override
  State<PlayerNativeIjkPage> createState() => _PlayerNativeIjkPageState();
}

class _TrackInfo {
  _TrackInfo(this.index, this.type, this.label);
  final int index;
  final String type;
  final String label;
}

class _PlayerNativeIjkPageState extends State<PlayerNativeIjkPage> {
  static const MethodChannel _ch = MethodChannel('ijk_player');

  late int _index = widget.initialIndex.clamp(0, widget.playlist.length - 1);
  int? _playerId;
  int? _textureId;
  bool _ready = false;
  bool _playing = true;
  bool _showControls = true;
  String? _error;
  List<_TrackInfo> _tracks = <_TrackInfo>[];
  final List<Timer> _timers = <Timer>[];

  PlayableItem get _current => widget.playlist[_index];
  bool get _isLive => _current.isLive;

  @override
  void initState() {
    super.initState();
    _ch.setMethodCallHandler(_onNative);
    _boot();
  }

  Future<void> _onNative(MethodCall call) async {
    final Map<dynamic, dynamic> args =
        (call.arguments as Map<dynamic, dynamic>?) ?? <dynamic, dynamic>{};
    if (args['id'] != _playerId) return;
    switch (call.method) {
      case 'prepared':
        setState(() {
          _ready = true;
          _playing = true;
        });
        _refreshTracks();
        break;
      case 'size':
        setState(() {});
        break;
      case 'completed':
        setState(() => _playing = false);
        break;
      case 'error':
        setState(() => _error =
            'Error ijk (${args['what']}/${args['extra']})');
        break;
    }
  }

  Future<void> _boot() async {
    try {
      final Map<dynamic, dynamic> created =
          (await _ch.invokeMethod<Map<dynamic, dynamic>>('create')) ??
              <dynamic, dynamic>{};
      _playerId = (created['id'] as num).toInt();
      _textureId = (created['textureId'] as num).toInt();
      if (mounted) setState(() {});
      await _open();
      _timers.add(Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _showControls) setState(() {});
      }));
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo crear el player: $e');
    }
  }

  Future<void> _open() async {
    final int? id = _playerId;
    if (id == null) return;
    setState(() {
      _error = null;
      _ready = false;
      _tracks = <_TrackInfo>[];
    });
    try {
      await _ch.invokeMethod<void>('open', <String, dynamic>{
        'id': id,
        'url': _current.url,
        'headers': widget.headers,
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo abrir: $e');
    }
  }

  Future<void> _refreshTracks() async {
    final int? id = _playerId;
    if (id == null) return;
    try {
      final List<dynamic>? raw =
          await _ch.invokeMethod<List<dynamic>>('tracks', <String, dynamic>{
        'id': id,
      });
      final List<_TrackInfo> list = <_TrackInfo>[];
      for (final dynamic item in raw ?? <dynamic>[]) {
        final Map<dynamic, dynamic> m = item as Map<dynamic, dynamic>;
        final String lang = (m['language'] as String?) ?? '';
        final String label = (m['label'] as String?) ?? '';
        final String type = (m['type'] as String?) ?? '';
        list.add(_TrackInfo(
          (m['index'] as num).toInt(),
          type,
          '$type ${lang.isNotEmpty ? lang.toUpperCase() : label}'.trim(),
        ));
      }
      if (mounted) setState(() => _tracks = list);
    } catch (_) {}
  }

  Future<void> _selectTrack(int index) async {
    final int? id = _playerId;
    if (id == null) return;
    await _ch.invokeMethod<void>('selectTrack', <String, dynamic>{
      'id': id,
      'index': index,
    });
    if (mounted) setState(() => _showTracks = false);
  }

  bool _showTracks = false;

  Future<void> _togglePlay() async {
    final int? id = _playerId;
    if (id == null) return;
    if (_playing) {
      await _ch.invokeMethod<void>('pause', <String, dynamic>{'id': id});
    } else {
      await _ch.invokeMethod<void>('play', <String, dynamic>{'id': id});
    }
    setState(() => _playing = !_playing);
  }

  Future<void> _playRelative(int offset) async {
    if (widget.playlist.length < 2) return;
    setState(() {
      _index =
          (_index + offset + widget.playlist.length) % widget.playlist.length;
    });
    final int? id = _playerId;
    if (id != null) {
      await _ch.invokeMethod<void>('release', <String, dynamic>{'id': id});
    }
    _playerId = null;
    _textureId = null;
    await _boot();
  }

  bool _onKey(KeyEvent event) {
    if (ModalRoute.of(context)?.isCurrent != true) return false;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final LogicalKeyboardKey k = event.logicalKey;
    if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.goBack) {
      Navigator.of(context).pop();
      return true;
    }
    if (_showTracks) return false;
    if (_showControls) {
      if (k == LogicalKeyboardKey.arrowUp ||
          k == LogicalKeyboardKey.arrowDown ||
          k == LogicalKeyboardKey.arrowLeft ||
          k == LogicalKeyboardKey.arrowRight ||
          k == LogicalKeyboardKey.select ||
          k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.numpadEnter) {
        return false;
      }
    } else if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter) {
      setState(() => _showControls = true);
      return true;
    }
    if (k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.arrowDown) {
      setState(() => _showControls = true);
      return true;
    }
    if (k == LogicalKeyboardKey.arrowLeft) {
      _playRelative(-1);
      return true;
    }
    if (k == LogicalKeyboardKey.arrowRight) {
      _playRelative(1);
      return true;
    }
    if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter ||
        k == LogicalKeyboardKey.mediaPlayPause) {
      _togglePlay();
      return true;
    }
    return false;
  }

  Future<void> _showEpg() async {
    final String? id = _current.streamId;
    if (id == null) return;
    final AppState app = context.read<AppState>();
    List<EpgEntry> entries = <EpgEntry>[];
    try {
      entries = await app.client.shortEpg(id);
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
                    maxLines: 1,
                    style: const TextStyle(color: Colors.white)),
                subtitle: Text(e.timeRange,
                    style: const TextStyle(color: Colors.white54)),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final Timer t in _timers) {
      t.cancel();
    }
    final int? id = _playerId;
    if (id != null) {
      _ch.invokeMethod<void>('release', <String, dynamic>{'id': id});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int? textureId = _textureId;
    return Scaffold(
      backgroundColor: Colors.black,
      body: KeyboardListener(
        focusNode: FocusNode(),
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (textureId != null)
              Texture(textureId: textureId)
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white70),
              ),
            if (!_ready && _error == null)
              const Center(
                child: CircularProgressIndicator(color: Colors.white70),
              ),
            if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            if (_showControls) ...<Widget>[
              Positioned(left: 0, right: 0, top: 0, child: _topBar()),
              Positioned(left: 0, right: 0, bottom: 0, child: _bottomBar()),
            ],
            if (_showTracks) _tracksOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: 'Atrás',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
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
          if (!_ready)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white70),
            ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: <Color>[Color(0xE6000000), Color(0x00000000)],
        ),
      ),
      child: Row(
        children: <Widget>[
          IconButton(
            autofocus: true,
            tooltip: _playing ? 'Pausa' : 'Reproducir',
            onPressed: _togglePlay,
            icon: Icon(_playing ? Icons.pause : Icons.play_arrow,
                color: Colors.white, size: 30),
          ),
          IconButton(
            tooltip: 'Audio / Subtítulos',
            onPressed: () async {
              await _refreshTracks();
              if (mounted) setState(() => _showTracks = true);
            },
            icon: const Icon(Icons.audiotrack_outlined, color: Colors.white),
          ),
          if (_isLive && _current.streamId != null)
            IconButton(
              tooltip: 'Guía de programación',
              onPressed: _showEpg,
              icon: const Icon(Icons.event_note_outlined, color: Colors.white),
            ),
          if (_isLive) ...<Widget>[
            IconButton(
              tooltip: 'Canal anterior',
              onPressed: () => _playRelative(-1),
              icon: const Icon(Icons.skip_previous, color: Colors.white),
            ),
            IconButton(
              tooltip: 'Canal siguiente',
              onPressed: () => _playRelative(1),
              icon: const Icon(Icons.skip_next, color: Colors.white),
            ),
          ],
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
    );
  }

  Widget _tracksOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showTracks = false),
        child: ColoredBox(
          color: const Color(0xCC000000),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('PISTAS DISPONIBLES',
                      style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 12),
                  if (_tracks.isEmpty)
                    const Text('Este contenido no trae pistas extra',
                        style: TextStyle(color: Colors.white70)),
                  for (final _TrackInfo t in _tracks)
                    ListTile(
                      title: Text(t.label,
                          style: const TextStyle(color: Colors.white)),
                      subtitle: Text(t.type,
                          style: const TextStyle(color: Colors.white38)),
                      onTap: () => _selectTrack(t.index),
                    ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => setState(() => _showTracks = false),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
