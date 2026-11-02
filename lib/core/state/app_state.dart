import 'package:flutter/foundation.dart';

import '../api/xtream_api.dart';
import '../api/xtream_client.dart';
import '../config/app_config.dart';
import '../config/config_controller.dart';
import '../models/media_item.dart';
import '../models/video_decode_mode.dart';
import '../models/playable_item.dart';
import '../models/resume_entry.dart';
import '../models/stream_format.dart';
import '../models/xtream_account.dart';
import '../models/xtream_credentials.dart';
import '../storage/prefs_store.dart';
import '../security/device_session.dart';

/// Estado global: sesión, cuenta, ajustes, favoritos e historial.
class AppState extends ChangeNotifier {
  AppState(this._store, this._config, {this.clientFactory}) : _devices = DeviceSession(_store.secure);
  final XtreamClient Function(XtreamApi)? clientFactory;
  XtreamClient _newClient(XtreamApi api) => clientFactory?.call(api) ?? XtreamClient(api: api);
  final DeviceSession _devices;
  DateTime? _loginBlockedUntil;
  final Stopwatch _heartbeatAge = Stopwatch();
  String? _playbackBlock;
  String? get playbackBlock => _playbackBlock;
  Duration? get loginRetryRemaining {
    final remaining = _loginBlockedUntil?.difference(DateTime.now());
    return remaining != null && !remaining.isNegative ? remaining : null;
  }
  Future<void> preparePlayback({bool renewDevice = false}) async {
    final current = client;
    await _devices.attach(current, force: renewDevice);
    if (_client != current) throw const XtreamException('La sesión cambió. Abre de nuevo el canal.');
    if (_playbackBlock != null) throw XtreamException(_playbackBlock!, statusCode: 403);
    if (!_heartbeatAge.isRunning || _heartbeatAge.elapsed >= const Duration(seconds: 90)) {
      await playbackHeartbeat();
    }
  }
  Future<void> playbackHeartbeat() async {
    final current = client;
    try {
      try { await _devices.heartbeat(current); }
      on XtreamException catch (error) {
        if (!['device_invalid', 'device_required', 'device_token_required'].contains(error.code)) rethrow;
        await _devices.attach(current, force: true);
        await _devices.heartbeat(current); // Exactly one registration/retry.
      }
      if (_client == current) { _heartbeatAge.reset(); _heartbeatAge.start(); }
    } on XtreamException catch (error) {
      if (_client == current && (error.statusCode == 401 || error.statusCode == 403)) {
        await blockPlayback(error.message);
      }
      rethrow;
    }
  }
  Future<void> checkMediaDrm(PlayableItem item) async {
    final id = item.streamId ?? item.source?.id;
    if (id == null) return;
    final kind = item.isLive ? 'live' : item.source?.kind == MediaKind.series ? 'series' : 'movie';
    final data = await client.securityAction('get_drm');
    final streams = data['streams'];
    if (streams is! List) return;
    for (final stream in streams) {
      if (stream is! Map || '${stream['stream_id']}' != id || (stream['kind'] != null && stream['kind'] != kind)) continue;
      if (stream['requires_eme'] == true || ['clearkey', 'widevine', 'playready'].contains(stream['drm_type'])) {
        throw const XtreamException('Este contenido requiere un reproductor compatible con su DRM.', statusCode: 412);
      }
      // AES manifests/keys are fetched by ExoPlayer in memory, never persisted here.
    }
  }
  Future<void> blockPlayback(String message) async {
    _playbackBlock = message;
    notifyListeners(); // The mounted player stops before credentials are cleared.
    await logout();
    _lastError = message;
    notifyListeners();
  }
  Future<void> unlinkDevice() async {
    await _devices.unlink(client);
    await logout();
  }

  final PrefsStore _store;
  final ConfigController _config;

  XtreamCredentials? _credentials;
  XtreamApi? _api;
  XtreamClient? _client;
  XtreamAccount? _account;

  StreamFormat _format = StreamFormat.auto;
  bool _rememberSession = true;
  bool _loggingIn = false;
  bool _restoring = true;
  String? _lastError;

  final Map<String, MediaItem> _favorites = <String, MediaItem>{};
  List<MediaItem> _recent = <MediaItem>[];
  List<ResumeEntry> _resume = <ResumeEntry>[];

  // --------------------------------------------------------------- getters
  bool get isLoggedIn => _client != null && _api != null;
  bool get loggingIn => _loggingIn;
  bool get restoring => _restoring;
  String? get lastError => _lastError;
  XtreamAccount? get account => _account;
  XtreamCredentials? get credentials => _credentials;
  StreamFormat get format => _format;

  /// Reserva máxima de reproducción; no obliga a esperar todo ese tiempo.
  int get bufferSeconds => _store.bufferSeconds;
  String get bufferLabel => '$bufferSeconds segundos';
  Future<void> setBufferSeconds(int value) async {
    await _store.saveBufferSeconds(value);
    notifyListeners();
  }
  bool get rememberSession => _rememberSession;

  /// Configuración de marca blanca activa.
  AppConfig get appConfig => _config.config;

  /// Tema activo (elegido por el usuario o por la marca).
  ThemeSpec get theme => _config.theme;

  XtreamApi get api {
    final value = _api;
    if (value == null) throw StateError('No hay sesión activa.');
    return value;
  }

  XtreamClient get client {
    final value = _client;
    if (value == null) throw StateError('No hay sesión activa.');
    return value;
  }

  /// Cabeceras que se envían al reproductor.
  Map<String, String> get headers => _api?.defaultHeaders ?? const <String, String>{};

  /// Resuelve el logo/carátula de un elemento (algunos paneles los dan
  /// como ruta relativa).
  String? iconUrl(MediaItem item) => _api?.resolveIcon(item.icon);

  List<MediaItem> get favorites => _favorites.values.toList();

  List<MediaItem> favoritesOf(MediaKind kind) =>
      _favorites.values.where((item) => item.kind == kind).toList();

  List<MediaItem> get recent => List<MediaItem>.unmodifiable(_recent);

  // --------------------------------------------------------------- ciclo
  Future<void> restore() async {
    _format = _store.streamFormat;
    _rememberSession = _store.rememberSession;
    for (final item in _store.favorites) {
      _favorites[item.favoriteKey] = item;
    }
    _recent = _store.recent;
    _resume = _store.readResumeList();

    final stored = _store.credentials;
    if (stored != null) {
      // Se aplica la marca configurada (User-Agent del panel) también al
      // restaurar la sesión guardada, no solo en el login manual.
      final XtreamCredentials effective = _effectiveCredentials(stored);
      XtreamClient? restoringClient;
      try {
        final api = XtreamApi.fromCredentials(effective);
        final client = restoringClient = _newClient(api);
        final account = await client.authenticate();
        api.configureStreams(account.serverInfo);
        if (account.isActive) {
          await _devices.attach(client);
          _playbackBlock = null;
          _credentials = effective;
          _api = api;
          _client = client;
          _account = account;
        } else {
          client.dispose();
        }
      } on XtreamException catch (error) {
        _lastError = error.message;
        if (error.statusCode == 401 || error.statusCode == 403) {
          await _devices.clear();
          await _store.clearCredentials();
        }
        if (error.statusCode == 429 && error.retryAfter != null) {
          _loginBlockedUntil = DateTime.now().add(error.retryAfter!);
        }
      } catch (_) {
        _lastError = 'No se pudo restaurar la sesión segura. Vuelve a iniciar sesión.';
      } finally {
        if (restoringClient != _client) restoringClient?.dispose();
      }
    }



    _restoring = false;
    notifyListeners();
  }

  /// Devuelve `true` si la sesión se abrió correctamente; en caso contrario
  /// deja el motivo en [lastError].
  Future<bool> login(XtreamCredentials credentials) async {
    if (_loggingIn) return false;
    final remaining = loginRetryRemaining;
    if (remaining != null) { _lastError = 'Espera ${remaining.inSeconds + 1} segundos antes de volver a conectar.'; notifyListeners(); return false; }
    _loggingIn = true;
    _lastError = null;
    notifyListeners();

    final XtreamCredentials effective = _effectiveCredentials(credentials);
    XtreamClient? client;
    try {
      final api = XtreamApi.fromCredentials(effective);
      client = _newClient(api);
      final account = await client.authenticate();
      api.configureStreams(account.serverInfo);
      if (!account.isActive) {
        _lastError = account.statusText;
        client.dispose();
        return false;
      }

      await _devices.attach(client);
      _playbackBlock = null;
      _client?.dispose();
      _credentials = effective;
      _api = api;
      _client = client;
      _account = account;
      if (_rememberSession) {
        await _store.saveCredentials(effective);
      }
      return true;
    } on XtreamException catch (error) {
      client?.dispose();
      if (error.statusCode == 429 && error.retryAfter != null) _loginBlockedUntil = DateTime.now().add(error.retryAfter!);
      _lastError = error.message;
      return false;
    } on FormatException catch (error) {
      client?.dispose();
      _lastError = error.message;
      return false;
    } catch (error) {
      client?.dispose();
      _lastError = 'No se pudo iniciar la sesión de forma segura.';
      return false;
    } finally {
      _loggingIn = false;
      notifyListeners();
    }
  }

  /// Completa servidor y User-Agent con los de la marca cuando el usuario solo
  /// escribe usuario y contraseña.
  XtreamCredentials _effectiveCredentials(XtreamCredentials input) {
    final AppConfig config = _config.config;
    final String server = input.server.trim().isEmpty
        ? config.xtream.server
        : input.server.trim();
    // El User-Agent se controla SOLO desde el panel (config.json),
    // no desde la app ni los ajustes guardados en el dispositivo.
    final String userAgent = config.xtream.userAgent.trim().isEmpty
        ? kDefaultUserAgent
        : config.xtream.userAgent.trim();
    return XtreamCredentials(
      server: server,
      username: input.username.trim(),
      password: input.password,
      userAgent: userAgent,
      preferHttps: true,
      streamToken: '', // Each account authenticates itself; never share a brand-wide token.
    );
  }

  VideoDecodeMode get videoDecodeMode => _store.videoDecodeMode;
  Future<void> setVideoDecodeMode(VideoDecodeMode mode) async {
    await _store.saveVideoDecodeMode(mode);
    notifyListeners();
  }

  // ------------------------------------------------- subtítulos (perfil)
  String get subtitleColor => _store.subtitleColor;

  double get subtitleSize => _store.subtitleSize;

  Future<void> setSubtitleColor(String value) async {
    await _store.setSubtitleColor(value);
    notifyListeners();
  }

  Future<void> setSubtitleSize(double value) async {
    await _store.setSubtitleSize(value);
    notifyListeners();
  }

  Future<void> logout() async {
    _heartbeatAge.stop();
    _heartbeatAge.reset();
    _playbackBlock ??= 'Sesión finalizada.';
    notifyListeners();
    _client?.dispose();
    _client = null;
    _api = null;
    _account = null;
    _credentials = null;
    await _devices.clear();
    await _store.clearCredentials();
    notifyListeners();
  }

  /// Cambia el User-Agent (algunos paneles lo exigen) y reautentica.
  Future<bool> updateUserAgent(String userAgent) async {
    final current = _credentials;
    if (current == null) return false;
    return login(current.copyWith(userAgent: userAgent.trim()));
  }

  Future<void> setRememberSession(bool value) async {
    _rememberSession = value;
    await _store.setRememberSession(value);
    if (!value) await _store.clearCredentials();
    notifyListeners();
  }

  Future<void> setFormat(StreamFormat format) async {
    _format = format;
    await _store.saveStreamFormat(format);
    notifyListeners();
  }

  // ------------------------------------------------------------ favoritos
  bool isFavorite(MediaItem item) => _favorites.containsKey(item.favoriteKey);

  Future<void> toggleFavorite(MediaItem item) async {
    if (_favorites.containsKey(item.favoriteKey)) {
      _favorites.remove(item.favoriteKey);
    } else {
      _favorites[item.favoriteKey] = item;
    }
    await _store.saveFavorites(_favorites.values);
    notifyListeners();
  }

  Future<void> addRecent(MediaItem item) async {
    _recent.removeWhere((entry) => entry.favoriteKey == item.favoriteKey);
    _recent.insert(0, item);
    if (_recent.length > 40) {
      _recent = _recent.sublist(0, 40);
    }
    await _store.saveRecent(_recent);
    notifyListeners();
  }

  Future<void> clearRecent() async {
    _recent = <MediaItem>[];
    await _store.saveRecent(_recent);
    notifyListeners();
  }

  // ---------------------------------------------------------- actualizaciones
  String? get dismissedUpdateVersion => _store.readDismissedUpdate();

  Future<void> dismissUpdate(String version) =>
      _store.saveDismissedUpdate(version);


  /// Ultimo error inesperado, para poder reportarlo desde Ajustes.
  String? get lastUnexpectedError => _store.readLastError();

  Future<void> clearUnexpectedError() async {
    await _store.clearLastError();
    notifyListeners();
  }

  // ------------------------------------------------------ continuar viendo
  /// Entradas a medio ver, de la más reciente a la más antigua.
  List<ResumeEntry> get continueWatching {
    final List<ResumeEntry> entries =
        _resume.where((ResumeEntry entry) => entry.isResumable).toList()
          ..sort((ResumeEntry a, ResumeEntry b) =>
              b.updatedAt.compareTo(a.updatedAt));
    return entries;
  }

  ResumeEntry? resumeFor(String? key) {
    if (key == null || key.isEmpty) return null;
    for (final ResumeEntry entry in _resume) {
      if (entry.key == key) return entry;
    }
    return null;
  }

  /// Guarda (o actualiza) la posición de reproducción.
  Future<void> saveResume(ResumeEntry entry) async {
    if (!entry.isResumable) {
      await removeResume(entry.key);
      return;
    }
    _resume.removeWhere((ResumeEntry other) => other.key == entry.key);
    _resume.insert(0, entry);
    if (_resume.length > 40) {
      _resume = _resume.sublist(0, 40);
    }
    await _store.saveResumeList(_resume);
    notifyListeners();
  }

  Future<void> removeResume(String key) async {
    final int before = _resume.length;
    _resume.removeWhere((ResumeEntry entry) => entry.key == key);
    if (_resume.length == before) return;
    await _store.saveResumeList(_resume);
    notifyListeners();
  }

  Future<void> clearResume() async {
    _resume = <ResumeEntry>[];
    await _store.clearResumeList();
    notifyListeners();
  }

  // ---------------------------------------------------------- reproductor
  /// Resuelve la URL de reproducción de un canal o una película.
  PlayableItem? playableFrom(MediaItem item) {
    if (!isLoggedIn) return null;
    switch (item.kind) {
      case MediaKind.live:
        return PlayableItem(
          title: item.name,
          url: api.liveUrl(item.id, format: _format),
          subtitle: 'En directo',
          logo: api.resolveIcon(item.icon),
          isLive: true,
          streamId: item.id,
          channelNumber: item.order,
        );
      case MediaKind.movie:
        return PlayableItem(
          title: item.name,
          url: api.movieUrl(item.id, extension: item.containerExtension),
          subtitle: item.genre ?? 'Película',
          logo: api.resolveIcon(item.icon),
          resumeKey: item.favoriteKey,
          source: item,
        );
      case MediaKind.series:
        // Los episodios se resuelven en la ficha de la serie.
        return null;
    }
  }

  /// Playlist completa de un catálogo para el botón siguiente/anterior.
  List<PlayableItem> playlistFrom(List<MediaItem> items) {
    final result = <PlayableItem>[];
    for (final item in items) {
      final playable = playableFrom(item);
      if (playable != null) result.add(playable);
    }
    return result;
  }
}
