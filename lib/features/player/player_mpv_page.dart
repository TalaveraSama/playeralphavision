import 'dart:async';

import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../../core/config/ads_config.dart';
import '../../core/models/epg_entry.dart';
import '../../core/models/playable_item.dart';
import '../../core/models/resume_entry.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/format_utils.dart';
import '../../widgets/state_views.dart';

/// Reproductor con **libmpv** (media_kit): el motor compatible.
///
/// Decodifica en software MP2, AC3, EAC3, DTS, HEVC, AV1… y pesa la mitad que
/// libVLC. Mantiene el comportamiento del reproductor nativo: controles con
/// autoocultado, ±10 s, siguiente/anterior, reanudar donde ibas, reintento del
/// directo alternando HLS ↔ MPEG-TS y el aviso de canal (número + nombre).
///
/// Si no arranca tras varios intentos devuelve `native` al cerrarse, para que
/// `open_player` abra el reproductor nativo (plan B).
class PlayerMpvPage extends StatefulWidget {
  const PlayerMpvPage({
    super.key,
    required this.playlist,
    this.initialIndex = 0,
    this.headers = const <String, String>{},
    this.mediaType,
    this.categoryName,
  });

  final List<PlayableItem> playlist;
  final int initialIndex;
  final Map<String, String> headers;
  final AdMediaType? mediaType;
  final String? categoryName;

  @override
  State<PlayerMpvPage> createState() => _PlayerMpvPageState();
}

class _PlayerMpvPageState extends State<PlayerMpvPage> {
  Player? _player;
  VideoController? _video;
  final List<StreamSubscription<dynamic>> _subs = <StreamSubscription<dynamic>>[];

  int _index = 0;
  bool _ready = false;
  bool _showControls = true;
  bool _playing = false;
  bool _buffering = false;
  bool _reconnecting = false;
  String? _error;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  Timer? _hideTimer;
  Timer? _progressTimer;
  Timer? _reconnectTimer;
  Timer? _watchdog;
  int _attempts = 0;
  int _initFails = 0;
  int _stallTicks = 0;


  OverlayEntry? _zapEntry;
  Timer? _zapTimer;
  int _shownIndex = -1;

  final Set<String> _formatTried = <String>{};
  String? _forcedUrl;

  PlayableItem get _current => widget.playlist.isEmpty
      ? const PlayableItem(title: 'Sin contenido', url: '')
      : widget.playlist[_index.clamp(0, widget.playlist.length - 1)];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(
      0,
      widget.playlist.isEmpty ? 0 : widget.playlist.length - 1,
    );
    HardwareKeyboard.instance.addHandler(_onKey);
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _progressTimer?.cancel();
    _reconnectTimer?.cancel();
    _watchdog?.cancel();
    _zapTimer?.cancel();
    _zapEntry?.remove();
    for (final StreamSubscription<dynamic> sub in _subs) {
      sub.cancel();
    }
    HardwareKeyboard.instance.removeHandler(_onKey);
    _player?.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- apertura
  Future<void> _open() async {
    if (!mounted) return;
    final AppState app = context.read<AppState>();
    final PlayableItem item = _current;

    _watchdog?.cancel();
    _progressTimer?.cancel();
    _stallTicks = 0;
    _position = Duration.zero;
    _duration = Duration.zero;
    setState(() {
      _ready = false;
      _error = null;
    });

    // Se cierra el motor anterior antes de abrir el nuevo.
    for (final StreamSubscription<dynamic> sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    final Player? previous = _player;
    _player = null;
    _video = null;
    await previous?.dispose();

    final int bufferMb = app.bufferMb;
    final Player player = Player(
      configuration: PlayerConfiguration(bufferSize: bufferMb * 1024 * 1024),
    );
    _player = player;
    await _detectDevice();
    _video = VideoController(
      player,
      // En el Fire TV el render HW de mpv (mediacodec/OMX) da pantalla negra.
      configuration: _videoConfig(),
    );
    // Caché de red (equivalente a libVLC --network-caching): lee por delante
    // y amortigua la red lenta para que no se quede «cargando» en negro.
    await (player.platform as dynamic).setProperty('cache', 'yes');
    await (player.platform as dynamic).setProperty('demuxer-max-bytes', '48MiB');
    await (player.platform as dynamic).setProperty('demuxer-readahead-secs', '45');
    // Subtitulos: mas grandes y mas arriba (no pegados al borde inferior).
    await (player.platform as dynamic).setProperty('sub-pos', '90');
    await (player.platform as dynamic).setProperty('sub-font-size', '72');
    await (player.platform as dynamic).setProperty('sub-border-size', '2.6');
    await (player.platform as dynamic).setProperty('sub-shadow-offset', '2');
    await (player.platform as dynamic).setProperty('sub-margin-y', '26');

    player.stream.position.listen((Duration value) {
      _position = value;
      _watched();
      // Repintar solo con los controles visibles (evita 1 rebuild/s eterno).
      if (mounted && _showControls) setState(() {});
    }).let(_subs.add);
    player.stream.duration.listen((Duration value) {
      _duration = value;
      _watched();
      if (mounted) setState(() {});
    }).let(_subs.add);
    player.stream.playing.listen((bool value) {
      _playing = value;
      if (mounted) setState(() {});
    }).let(_subs.add);
    player.stream.buffering.listen((bool value) {
      _buffering = value;
      if (value) {
        _stallTicks++;
        if (_stallTicks > 8 && _ready) {
          _stallTicks = 0;
          _scheduleReconnect();
        }
      } else {
        _stallTicks = 0;
      }
      if (mounted) setState(() {});
    }).let(_subs.add);
    player.stream.error.listen((String message) {
      if (!mounted) return;
      if (_current.isLive) {
        _scheduleReconnect();
      } else {
        _initFails++;
        if (_initFails >= 3) {
          unawaited(_fallbackNative('No se pudo abrir con el reproductor compatible.'));
        } else {
          unawaited(_open());
        }
      }
    }).let(_subs.add);

    // Vigilante: si en 15 s no hay imagen, se reintenta.
    _watchdog = Timer(const Duration(seconds: 15), () {
      if (!mounted || _ready) return;
      _initFails++;
      if (_initFails >= 3) {
        unawaited(_fallbackNative('No se pudo abrir con el reproductor compatible.'));
      } else if (_current.isLive) {
        _scheduleReconnect();
      } else {
        unawaited(_open());
      }
    });

    try {
      await player.setVolume(100);
      await player.open(
        Media(_forcedUrl ?? item.url, httpHeaders: widget.headers),
        play: true,
      );
      if (!mounted) return;

      // Reanuda donde ibas (solo VOD).
      if (!item.isLive) {
        final ResumeEntry? resume = app.resumeFor(item.progressKey);
        if (resume != null && resume.positionSec > 20) {
          await player.seek(resume.position);
        }
      }

      _attempts = 0;
      _reconnecting = false;
      setState(() => _ready = true);
      _restartHideTimer();
      _progressTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _saveProgress(),
      );
    } catch (error) {
      if (!mounted) return;
      _initFails++;
      if (_initFails >= 3) {
        await _fallbackNative('No se pudo abrir con el reproductor compatible.');
        return;
      }
      if (item.isLive) {
        _scheduleReconnect();
      } else {
        unawaited(_open());
      }
    }
  }

  /// La primera señal de vídeo cancela el vigilante de arranque.
  void _watched() {
    if (_ready) return;
    _watchdog?.cancel();
  }

  /// Reintenta el directo cada 3 s alternando HLS ↔ MPEG-TS.
  void _scheduleReconnect() {
    if (!mounted || _reconnectTimer != null) return;
    _reconnecting = true;
    _attempts++;
    if (_attempts > 4) {
      unawaited(_fallbackNative('No se pudo abrir con el reproductor compatible.'));
      return;
    }
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _reconnectTimer = null;
      if (!mounted) return;
      final PlayableItem item = _current;
      final String url = _forcedUrl ?? item.url;
      if (item.isLive && !_formatTried.contains(url)) {
        _formatTried.add(url);
        _forcedUrl = url.endsWith('.m3u8')
            ? '${url.substring(0, url.length - 5)}ts'
            : (url.endsWith('.ts')
                ? '${url.substring(0, url.length - 2)}m3u8'
                : null);
      } else {
        _forcedUrl = null;
        _formatTried.clear();
      }
      unawaited(_open());
    });
  }

  Future<void> _fallbackNative(String message) async {
    if (!mounted) return;
    setState(() {
      _error = message;
      _ready = false;
    });
    // Se recuerda que en este equipo el motor compatible no sirve, para no
    // volver a intentarlo cada vez que se abre un canal.
    await context.read<AppState>().markCompatiblePlayerBroken();
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) Navigator.of(context).pop('native');
  }

  // ------------------------------------------------------------ controles
  Future<void> _togglePlay() async {
    final Player? player = _player;
    if (player == null) return;
    await player.playOrPause();
    _restartHideTimer();
    if (mounted) setState(() => _showControls = true);
  }

  Future<void> _seekRelative(int seconds) async {
    final Player? player = _player;
    if (player == null || _current.isLive) return;
    final Duration target = _position + Duration(seconds: seconds);
    await player.seek(target.isNegative ? Duration.zero : target);
    _restartHideTimer();
  }

  Future<void> _playRelative(int offset) async {
    if (widget.playlist.length < 2) return;
    setState(() {
      _index =
          (_index + offset + widget.playlist.length) % widget.playlist.length;
      _forcedUrl = null;
      _formatTried.clear();
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _reconnecting = false;
      _attempts = 0;
    });
    await _open();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    _restartHideTimer();
  }


  /// Control remoto (Fire TV / Android TV): cambiar canal, controles, back.
  bool _onKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    final LogicalKeyboardKey k = event.logicalKey;

    // CONTROLES VISIBLES: el mando navega entre los botones (audio, subtitulos,
    // guia...). Izquierda/derecha ya NO cambian de canal en este modo.
    if (_showControls) {
      if (k == LogicalKeyboardKey.arrowLeft ||
          k == LogicalKeyboardKey.arrowRight ||
          k == LogicalKeyboardKey.arrowUp ||
          k == LogicalKeyboardKey.arrowDown ||
          k == LogicalKeyboardKey.select ||
          k == LogicalKeyboardKey.enter ||
          k == LogicalKeyboardKey.numpadEnter) {
        return false;
      }
      if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.goBack) {
        setState(() => _showControls = false);
        _restartHideTimer();
        return true;
      }
      return false;
    }

    // CONTROLES OCULTOS: izquierda/derecha / CH cambian de canal.
    if (k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.channelDown ||
        k == LogicalKeyboardKey.mediaRewind) {
      if (widget.playlist.length > 1) {
        _playRelative(-1);
        return true;
      }
    }
    if (k == LogicalKeyboardKey.arrowRight ||
        k == LogicalKeyboardKey.channelUp ||
        k == LogicalKeyboardKey.mediaFastForward) {
      if (widget.playlist.length > 1) {
        _playRelative(1);
        return true;
      }
    }
    // Arriba/abajo: mostrar u ocultar los controles.
    if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.arrowDown) {
      _toggleControls();
      return true;
    }
    // Select/OK/Play-Pausa.
    if (k == LogicalKeyboardKey.select ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.numpadEnter ||
        k == LogicalKeyboardKey.mediaPlayPause) {
      if (_current.isLive) {
        _toggleControls();
      } else {
        _togglePlay();
      }
      return true;
    }
    // Atras: primero muestra los controles; con los controles visibles, sale.
    if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.goBack) {
      setState(() => _showControls = true);
      _restartHideTimer();
      return true;
    }
    return false;
  }


  bool _menuOpen = false;
  // Fire TV (Amazon): mpv con render HW deja pantalla negra -> software.
  bool _isAmazon = true;
  bool _deviceDetected = false;

  /// Menú combinado Audio + Subtítulos (se abre con ≡ en el reproductor).
  Future<void> _showTracksMenu() async {
    final Player? p = _player;
    if (p == null || _menuOpen) return;
    _menuOpen = true;
    final List<AudioTrack> audio = p.state.tracks.audio;
    final List<SubtitleTrack> subs = p.state.tracks.subtitle;
    final String audioId = p.state.track.audio.id;
    final String subId = p.state.track.subtitle.id;
    try {
      await showModalBottomSheet<void>(
        context: context,
        builder: (BuildContext ctx) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: <Widget>[
              const ListTile(
                title: Text('Audio', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              for (final AudioTrack t in audio)
                ListTile(
                  leading: Icon(t.id == audioId
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked),
                  title: Text(_trackName(t, 'Audio')),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await p.setAudioTrack(t);
                  },
                ),
              if (audio.isEmpty)
                const ListTile(title: Text('Sin pistas de audio')),
              const Divider(),
              const ListTile(
                title: Text('Subtítulos', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: Icon(subId == 'no'
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked),
                title: const Text('Desactivados'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await p.setSubtitleTrack(SubtitleTrack.no());
                },
              ),
              for (final SubtitleTrack t in subs)
                ListTile(
                  leading: Icon(t.id == subId
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked),
                  title: Text(_trackName(t, 'Subtítulo')),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await p.setSubtitleTrack(t);
                  },
                ),
            ],
          ),
        ),
      );
    } finally {
      _menuOpen = false;
    }
  }

  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  Future<void> _saveProgress() async {
    if (!_ready || _current.isLive) return;
    if (_position.inSeconds < 5 || _duration.inSeconds <= 0) return;
    final PlayableItem item = _current;
    await context.read<AppState>().saveResume(
          ResumeEntry(
            key: item.progressKey,
            title: item.title,
            subtitle: item.subtitle,
            image: item.logo,
            playable: item,
            positionSec: _position.inSeconds,
            durationSec: _duration.inSeconds,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  /// Aviso con el número y el nombre del canal al cambiar de canal.
  void _showZapBanner() {
    if (!mounted) return;
    final PlayableItem item = _current;
    final int? number = item.channelNumber;
    final Color accent = Theme.of(context).colorScheme.primary;

    _zapEntry?.remove();
    _zapEntry = OverlayEntry(
      builder: (BuildContext context) => Positioned(
        left: 20,
        top: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (number != null && number > 0) ...<Widget>[
                  Text(
                    '$number',
                    style: TextStyle(
                      fontSize: 30,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_zapEntry!);
    _zapTimer?.cancel();
    _zapTimer = Timer(const Duration(seconds: 4), _hideZapBanner);
  }

  void _hideZapBanner() {
    _zapTimer?.cancel();
    _zapEntry?.remove();
    _zapEntry = null;
  }

  /// Un canal 4K/UHD se marca con su distintivo en la barra superior.
  bool get _is4k {
    final String upper = _current.title.toUpperCase();
    return upper.contains('4K') || upper.contains('UHD');
  }

  /// Guía de programación del canal en directo.
  Future<void> _showEpg() async {
    final String? streamId = _current.streamId;
    if (streamId == null) return;

    final AppState app = context.read<AppState>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.6,
          child: FutureBuilder<List<EpgEntry>>(
            future: app.client.shortEpg(streamId),
            builder: (
              BuildContext context,
              AsyncSnapshot<List<EpgEntry>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LoadingView(message: 'Cargando guía…');
              }
              if (snapshot.hasError) {
                return const ErrorView(message: 'No se pudo cargar la guía.');
              }
              final List<EpgEntry> entries = snapshot.data ?? const <EpgEntry>[];
              if (entries.isEmpty) {
                return const EmptyView(
                  message: 'El panel no ofrece guía para este canal.',
                  icon: Icons.event_busy_outlined,
                );
              }
              return ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (BuildContext context, int index) {
                  final EpgEntry entry = entries[index];
                  return ListTile(
                    dense: true,
                    leading: entry.nowPlaying
                        ? const Icon(Icons.play_circle_fill, size: 20)
                        : null,
                    title: Text(
                      entry.title.isEmpty ? 'Sin información' : entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      <String>[
                        if (entry.timeRange.isNotEmpty) entry.timeRange,
                        if (entry.description.isNotEmpty) entry.description,
                      ].join(' · '),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _detectDevice() async {
    if (_deviceDetected) return;
    _deviceDetected = true;
    try {
      final AndroidDeviceInfo info = await DeviceInfoPlugin().androidInfo;
      final String m = info.manufacturer.toLowerCase();
      final String b = info.brand.toLowerCase();
      final String mo = info.model.toLowerCase();
      _isAmazon = m.contains('amazon') || b.contains('amazon') || mo.startsWith('aft');
    } catch (_) {
      _isAmazon = true;
    }
  }

  VideoControllerConfiguration _videoConfig() {
    // Fire TV: software. Otros Android TV: hardware (si falla, se ve negro).
    return VideoControllerConfiguration(
      enableHardwareAcceleration: !_isAmazon,
    );
  }

  // ---------------------------------------------------------------- vista
  @override
  Widget build(BuildContext context) {
    final PlayableItem item = _current;
    final bool isLive = item.isLive;
    final VideoController? video = _video;

    if (_ready && _shownIndex != _index) {
      _shownIndex = _index;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showZapBanner());
    }

    final double progress = (_duration.inMilliseconds > 0)
        ? (_position.inMilliseconds / _duration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (video != null)
              Video(
                controller: video,
                fit: BoxFit.contain,
                controls: (VideoState state) => const SizedBox.shrink(),
              ),
            if (!_ready)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 14),
                    Text(
                      _error ??
                          (_reconnecting ? 'Reconectando…' : 'Cargando…'),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            if (_showControls || !_ready)
              _buildControls(isLive, progress),
          ],
        ),
      ),
    );
  }

    String _trackName(dynamic track, String fallback) {
    final String? title = track.title as String?;
    final String? lang = track.language as String?;
    if (title != null && title.isNotEmpty) return title;
    if (lang != null && lang.isNotEmpty) return lang.toUpperCase();
    return fallback;
  }

  /// Menú para elegir audio (español, original…) o subtítulos.
  Future<void> _showTrackMenu(String type) async {
    final Player? p = _player;
    if (p == null) return;
    final bool isAudio = type == 'audio';
    final List<dynamic> tracks = isAudio
        ? p.state.tracks.audio.cast<dynamic>()
        : p.state.tracks.subtitle.cast<dynamic>();
    if (tracks.isEmpty) return;

    final int? picked = await showModalBottomSheet<int>(
      context: context,
      builder: (BuildContext ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            if (!isAudio)
              ListTile(
                leading: const Icon(Icons.subtitles_off_outlined),
                title: const Text('Sin subtítulos'),
                onTap: () => Navigator.of(ctx).pop(-1),
              ),
            for (int i = 0; i < tracks.length; i++)
              ListTile(
                leading: Icon(isAudio
                    ? Icons.audiotrack_outlined
                    : Icons.subtitles_outlined),
                title: Text(_trackName(
                    tracks[i], isAudio ? 'Audio ${i + 1}' : 'Subtítulo ${i + 1}')),
                onTap: () => Navigator.of(ctx).pop(i),
              ),
          ],
        ),
      ),
    );

    if (picked == null) return;
    if (isAudio) {
      if (picked >= 0 && picked < tracks.length) {
        await p.setAudioTrack(tracks[picked] as AudioTrack);
        // mpv en directo a veces deja el audio out mudo tras cambiar pista:
        // se reafirman volumen, mute y salida de audio.
        try {
          final dynamic plat = p.platform;
          await plat.setProperty('mute', 'no');
          await plat.setProperty('audio', 'auto');
          await plat.setProperty('ao-volume', '100');
        } catch (_) {}
        await p.setVolume(100);
        await p.play();
      }
    } else {
      if (picked == -1) {
        await p.setSubtitleTrack(SubtitleTrack.no());
      } else if (picked < tracks.length) {
        await p.setSubtitleTrack(tracks[picked] as SubtitleTrack);
      }
    }
  }

  Widget _buildControls(bool isLive, double progress) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0x66000000),
            Color(0x00000000),
            Color(0xCC000000),
          ],
          stops: <double>[0, 0.5, 1],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                IconButton(
                  tooltip: 'Atrás',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _current.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (_is4k)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '4K',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ),
                // Audio disponible tambien en vivo: los canales HLS suelen
                // traer varias pistas de idioma.
                IconButton(
                  tooltip: 'Audio',
                  autofocus: true,
                  onPressed: () => _showTrackMenu('audio'),
                  icon: const Icon(Icons.audiotrack_outlined),
                ),
                IconButton(
                  tooltip: 'Subtítulos',
                  onPressed: () => _showTrackMenu('subtitle'),
                  icon: const Icon(Icons.subtitles_outlined),
                ),
                if (isLive && _current.streamId != null)
                  IconButton(
                    tooltip: 'Guía de programación',
                    onPressed: _showEpg,
                    icon: const Icon(Icons.event_note_outlined),
                  ),
                if (_reconnecting)
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Text(
                      'Reconectando…',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                if (!isLive)
                  IconButton(
                    iconSize: 34,
                    tooltip: 'Atrás 10 s',
                    onPressed: () => _seekRelative(-10),
                    icon: const Icon(Icons.replay_10),
                  ),
                if (widget.playlist.length > 1)
                  IconButton(
                    iconSize: 30,
                    tooltip: 'Anterior',
                    onPressed: () => _playRelative(-1),
                    icon: const Icon(Icons.skip_previous),
                  ),
                IconButton(
                  iconSize: 54,
                  tooltip: _playing ? 'Pausa' : 'Reproducir',
                  onPressed: _togglePlay,
                  icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                ),
                if (widget.playlist.length > 1)
                  IconButton(
                    iconSize: 30,
                    tooltip: 'Siguiente',
                    onPressed: () => _playRelative(1),
                    icon: const Icon(Icons.skip_next),
                  ),
                if (!isLive)
                  IconButton(
                    iconSize: 34,
                    tooltip: 'Avanzar 10 s',
                    onPressed: () => _seekRelative(10),
                    icon: const Icon(Icons.forward_10),
                  ),
              ],
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: isLive
                  ? Row(
                      children: <Widget>[
                        const Icon(
                          Icons.fiber_manual_record,
                          color: Colors.redAccent,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'EN VIVO',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        if (_buffering)
                          const Text(
                            'almacenando…',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white60,
                            ),
                          ),
                      ],
                    )
                  : Column(
                      children: <Widget>[
                        Slider(
                          value: progress,
                          onChanged: (double value) {
                            final int ms =
                                (_duration.inMilliseconds * value).round();
                            _player?.seek(Duration(milliseconds: ms));
                            _restartHideTimer();
                          },
                        ),
                        Row(
                          children: <Widget>[
                            Text(
                              formatDuration(_position),
                              style: const TextStyle(fontSize: 12),
                            ),
                            const Spacer(),
                            Text(
                              formatDuration(_duration),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pequeño atajo para encadenar `listen(...)` y guardar la suscripción.
extension _SubX on StreamSubscription<dynamic> {
  void let(void Function(StreamSubscription<dynamic>) keep) => keep(this);
}
