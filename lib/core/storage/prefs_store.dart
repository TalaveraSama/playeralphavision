import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../ads/ad_engine.dart';
import '../models/media_item.dart';
import '../models/resume_entry.dart';
import '../models/stream_format.dart';
import '../models/xtream_credentials.dart';
import '../utils/parse_utils.dart';

/// Persistencia local: credenciales, formato de directo, favoritos e historial.
class PrefsStore {
  PrefsStore._(this._prefs);

  final SharedPreferences _prefs;

  static const String _kServer = 'xtream.server';
  static const String _kUsername = 'xtream.username';
  static const String _kPassword = 'xtream.password';
  static const String _kUserAgent = 'xtream.user_agent';
  static const String _kPreferHttps = 'xtream.prefer_https';
  static const String _kFormat = 'xtream.stream_format';
  static const String _kVideoDecoder = 'player.video_decoder';
  static const String _kPlayerEngine = 'player.engine';
  static const String _kBufferMb = 'player.buffer_mb';
  static const String _kCompatibleBroken = 'player.compatible_broken';
  static const String _kFavorites = 'xtream.favorites';
  static const String _kRecent = 'xtream.recent';
  static const String _kRemember = 'xtream.remember';
  static const String _kRemoteConfig = 'xtream.remote_config';
  static const String _kThemeOverride = 'xtream.theme_override';
  static const String _kDismissedUpdate = 'xtream.dismissed_update';
  static const String _kAdCounters = 'xtream.ad_counters';
  static const String _kLastError = 'xtream.last_error';
  static const String _kResume = 'xtream.resume';
  static const String _kSubtitleColor = 'player.subtitle_color';
  static const String _kSubtitleSize = 'player.subtitle_size';

  static Future<PrefsStore> create() async {
    return PrefsStore._(await SharedPreferences.getInstance());
  }

  String get subtitleColor => _prefs.getString(_kSubtitleColor) ?? '#FFFFFF';

  Future<void> setSubtitleColor(String value) =>
      _prefs.setString(_kSubtitleColor, value);

  double get subtitleSize => _prefs.getDouble(_kSubtitleSize) ?? 22;

  Future<void> setSubtitleSize(double value) =>
      _prefs.setDouble(_kSubtitleSize, value);

  bool get rememberSession => _prefs.getBool(_kRemember) ?? true;

  Future<void> setRememberSession(bool value) =>
      _prefs.setBool(_kRemember, value);

  XtreamCredentials? get credentials {
    final server = _prefs.getString(_kServer);
    final username = _prefs.getString(_kUsername);
    final password = _prefs.getString(_kPassword);
    if (server == null || username == null || password == null) return null;
    if (server.isEmpty || username.isEmpty) return null;
    return XtreamCredentials(
      server: server,
      username: username,
      password: password,
      userAgent: _prefs.getString(_kUserAgent) ?? kDefaultUserAgent,
      preferHttps: _prefs.getBool(_kPreferHttps) ?? false,
    );
  }

  Future<void> saveCredentials(XtreamCredentials credentials) async {
    await _prefs.setString(_kServer, credentials.server);
    await _prefs.setString(_kUsername, credentials.username);
    await _prefs.setString(_kPassword, credentials.password);
    await _prefs.setString(_kUserAgent, credentials.userAgent);
    await _prefs.setBool(_kPreferHttps, credentials.preferHttps);
  }

  Future<void> clearCredentials() async {
    await _prefs.remove(_kServer);
    await _prefs.remove(_kUsername);
    await _prefs.remove(_kPassword);
  }

  StreamFormat get streamFormat {
    final stored = _prefs.getString(_kFormat);
    return StreamFormat.values.firstWhere(
      (format) => format.name == stored,
      orElse: () => StreamFormat.auto,
    );
  }

  Future<void> saveStreamFormat(StreamFormat format) =>
      _prefs.setString(_kFormat, format.name);

  /// true cuando el motor compatible (libmpv) ya falló en este equipo.
  bool get compatiblePlayerBroken =>
      _prefs.getBool(_kCompatibleBroken) ?? false;

  Future<void> saveCompatiblePlayerBroken(bool value) =>
      _prefs.setBool(_kCompatibleBroken, value);

  /// Decodificacion de video: 'software' (FFmpeg, por defecto) o 'hardware'.
  String get videoDecoder => _prefs.getString(_kVideoDecoder) ?? 'software';

  Future<void> saveVideoDecoder(String mode) =>
      _prefs.setString(_kVideoDecoder, mode);

  /// Motor del reproductor: 'exo' (por defecto), 'ijk', 'mpv' o 'vlc'.
  /// Si el valor guardado no es valido se vuelve a ExoPlayer, que es el mas
  /// estable en TV/Fire TV.
  String get playerEngine {
    final String value = _prefs.getString(_kPlayerEngine) ?? 'exo';
    return const <String>['exo', 'ijk', 'mpv', 'vlc'].contains(value)
        ? value
        : 'exo';
  }

  Future<void> savePlayerEngine(String engine) =>
      _prefs.setString(_kPlayerEngine, engine);

  /// Precarga (búfer) del directo, en MB.
  int get bufferMb => _prefs.getInt(_kBufferMb) ?? 32;

  Future<void> saveBufferMb(int value) => _prefs.setInt(_kBufferMb, value);

  List<MediaItem> get favorites {
    final raw = _prefs.getStringList(_kFavorites) ?? const <String>[];
    return raw.map(_decodeItem).whereType<MediaItem>().toList();
  }

  Future<void> saveFavorites(Iterable<MediaItem> items) {
    return _prefs.setStringList(
      _kFavorites,
      items.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  List<MediaItem> get recent {
    final raw = _prefs.getStringList(_kRecent) ?? const <String>[];
    return raw.map(_decodeItem).whereType<MediaItem>().toList();
  }

  Future<void> saveRecent(Iterable<MediaItem> items) {
    return _prefs.setStringList(
      _kRecent,
      items.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  Future<void> clearLists() async {
    await _prefs.remove(_kFavorites);
    await _prefs.remove(_kRecent);
  }

  // ------------------------------------------------- configuración remota
  Map<String, dynamic> readRemoteConfig() {
    final String? raw = _prefs.getString(_kRemoteConfig);
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      return asMap(jsonDecode(raw));
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> saveRemoteConfig(Map<String, dynamic> value) =>
      _prefs.setString(_kRemoteConfig, jsonEncode(value));

  String? readThemeOverride() => _prefs.getString(_kThemeOverride);

  Future<void> saveThemeOverride(String? themeId) async {
    if (themeId == null || themeId.isEmpty) {
      await _prefs.remove(_kThemeOverride);
    } else {
      await _prefs.setString(_kThemeOverride, themeId);
    }
  }

  String? readDismissedUpdate() => _prefs.getString(_kDismissedUpdate);

  Future<void> saveDismissedUpdate(String version) =>
      _prefs.setString(_kDismissedUpdate, version);

  // ------------------------------------------------------------- anuncios
  AdCounters readAdCounters() {
    final String? raw = _prefs.getString(_kAdCounters);
    if (raw == null || raw.isEmpty) return const AdCounters();
    try {
      return AdCounters.fromJson(asMap(jsonDecode(raw)));
    } catch (_) {
      return const AdCounters();
    }
  }

  Future<void> saveAdCounters(AdCounters counters) =>
      _prefs.setString(_kAdCounters, jsonEncode(counters.toJson()));


  // ------------------------------------------------------- diagnostico
  /// Ultimo error inesperado (se muestra en Ajustes para soporte).
  String? readLastError() => _prefs.getString(_kLastError);

  Future<void> saveLastError(String message) {
    final String clean = message.length > 400 ? message.substring(0, 400) : message;
    return _prefs.setString(_kLastError, clean);
  }

  Future<void> clearLastError() => _prefs.remove(_kLastError);

  // ---------------------------------------------------- continuar viendo
  List<ResumeEntry> readResumeList() {
    final List<String> raw =
        _prefs.getStringList(_kResume) ?? const <String>[];
    final List<ResumeEntry> entries = <ResumeEntry>[];
    for (final String line in raw) {
      try {
        final ResumeEntry entry =
            ResumeEntry.fromJson(asMap(jsonDecode(line)));
        if (entry.key.isNotEmpty) entries.add(entry);
      } catch (_) {
        // Entrada corrupta: se ignora.
      }
    }
    return entries;
  }

  Future<void> saveResumeList(Iterable<ResumeEntry> entries) =>
      _prefs.setStringList(
        _kResume,
        entries.map((ResumeEntry entry) => jsonEncode(entry.toJson())).toList(),
      );

  Future<void> clearResumeList() => _prefs.remove(_kResume);

  MediaItem? _decodeItem(String raw) {
    try {
      return MediaItem.fromJson(asMap(jsonDecode(raw)));
    } catch (_) {
      return null;
    }
  }
}
