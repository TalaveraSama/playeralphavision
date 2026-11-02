import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../ads/ad_engine.dart';
import '../security/secure_session.dart';
import '../models/media_item.dart';
import '../models/playback_buffer.dart';
import '../models/video_decode_mode.dart';
import '../models/resume_entry.dart';
import '../models/stream_format.dart';
import '../models/xtream_credentials.dart';
import '../utils/parse_utils.dart';

/// Persistencia local: credenciales, formato de directo, favoritos e historial.
class PrefsStore {
  PrefsStore._(this._prefs, this.secure);
  final SecureSession secure;

  final SharedPreferences _prefs;

  static const String _kServer = 'xtream.server';
  static const String _kUsername = 'xtream.username';
  static const String _kPassword = 'xtream.password';
  static const String _kUserAgent = 'xtream.user_agent';
  static const String _kPreferHttps = 'xtream.prefer_https';
  static const String _kFormat = 'xtream.stream_format';
  static const String _kBufferSeconds = 'player.buffer_seconds';
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

  static Future<PrefsStore> create({SecureSession? secureSession}) async {
    final prefs = await SharedPreferences.getInstance();
    final secure = secureSession ?? await SecureSession.open();
    // Copy first, delete only after successful encrypted commit.
    for (final key in [_kServer, _kUsername, _kPassword, _kRemoteConfig, _kFavorites, _kRecent, _kResume]) {
      final value = prefs.get(key);
      if (value != null) {
        if (!secure.values.containsKey(key)) {
          await secure.write(key, value is List ? jsonEncode(value) : value.toString());
        }
        await prefs.remove(key);
      }
    }
    await prefs.remove(_kLastError); // Old diagnostics might contain a credential URL.
    return PrefsStore._(prefs, secure);
  }

  List<String>? _secureList(String key) {
    final raw = secure.values[key];
    if (raw == null) return null;
    try { return (jsonDecode(raw) as List).cast<String>(); } catch (_) { return null; }
  }
  Future<void> _writeSecureList(String key, List<String> values) => secure.write(key, jsonEncode(values));

  VideoDecodeMode get videoDecodeMode => VideoDecodeMode.parse(
      _prefs.getString('player.exo_decoder_mode'));
  Future<void> saveVideoDecodeMode(VideoDecodeMode mode) =>
      _prefs.setString('player.exo_decoder_mode', mode.id);

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
    final server = secure.values[_kServer];
    final username = secure.values[_kUsername];
    final password = secure.values[_kPassword];
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
    await secure.write(_kServer, credentials.server);
    await secure.write(_kUsername, credentials.username);
    await secure.write(_kPassword, credentials.password);
    await _prefs.setString(_kUserAgent, credentials.userAgent);
    await _prefs.setBool(_kPreferHttps, credentials.preferHttps);
  }

  Future<void> clearCredentials() async {
    await secure.write(_kServer, null);
    await secure.write(_kUsername, null);
    await secure.write(_kPassword, null);
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

  /// Ignora los antiguos MB: no se pueden convertir a tiempo sin el bitrate.
  int get bufferSeconds => PlaybackBuffer.normalize(_prefs.getInt(_kBufferSeconds));
  Future<void> saveBufferSeconds(int value) =>
      _prefs.setInt(_kBufferSeconds, PlaybackBuffer.normalize(value));

  List<MediaItem> get favorites {
    final raw = _secureList(_kFavorites) ?? const <String>[];
    return raw.map(_decodeItem).whereType<MediaItem>().toList();
  }

  Future<void> saveFavorites(Iterable<MediaItem> items) {
    return _writeSecureList(
      _kFavorites,
      items.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  List<MediaItem> get recent {
    final raw = _secureList(_kRecent) ?? const <String>[];
    return raw.map(_decodeItem).whereType<MediaItem>().toList();
  }

  Future<void> saveRecent(Iterable<MediaItem> items) {
    return _writeSecureList(
      _kRecent,
      items.map((item) => jsonEncode(item.toJson())).toList(),
    );
  }

  Future<void> clearLists() async {
    await secure.write(_kFavorites, null);
    await secure.write(_kRecent, null);
  }

  // ------------------------------------------------- configuración remota
  Map<String, dynamic> readRemoteConfig() {
    final String? raw = secure.values[_kRemoteConfig];
    if (raw == null || raw.isEmpty) return <String, dynamic>{};
    try {
      return asMap(jsonDecode(raw));
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> saveRemoteConfig(Map<String, dynamic> value) =>
      secure.write(_kRemoteConfig, jsonEncode(value));

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
  String? readLastError() => secure.values[_kLastError];

  Future<void> saveLastError(String message) {
    return secure.write(_kLastError, 'Se detectó un error interno. Contacta con soporte.');
  }

  Future<void> clearLastError() => secure.write(_kLastError, null);

  // ---------------------------------------------------- continuar viendo
  List<ResumeEntry> readResumeList() {
    final List<String> raw =
        _secureList(_kResume) ?? const <String>[];
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
      _writeSecureList(
        _kResume,
        entries.map((ResumeEntry entry) => jsonEncode(entry.toJson())).toList(),
      );

  Future<void> clearResumeList() => secure.write(_kResume, null);

  MediaItem? _decodeItem(String raw) {
    try {
      return MediaItem.fromJson(asMap(jsonDecode(raw)));
    } catch (_) {
      return null;
    }
  }
}
