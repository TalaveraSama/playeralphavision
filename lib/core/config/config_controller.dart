import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../ads/ad_engine.dart';
import '../storage/prefs_store.dart';
import '../utils/parse_utils.dart';
import 'ads_config.dart';
import 'app_config.dart';

/// Carga y mantiene la configuración de marca blanca.
///
/// Orden de prioridad:
/// 1. `assets/config.json` (lo que va grabado en el APK, incluido el servidor).
/// 2. Configuración remota opcional (`remoteConfigUrl`), que sobrescribe campo a
///    campo: sirve para cambiar anuncios, fondos, logo o la versión mínima sin
///    volver a compilar.
/// 3. Caché local de la última configuración remota, para que la app arranque
///    igual sin conexión.
class ConfigController extends ChangeNotifier {
  ConfigController({
    required PrefsStore store,
    this.assetPath = 'assets/config.json',
    http.Client? httpClient,
    Map<String, dynamic>? bundledJson,
  })  : _store = store,
        _http = httpClient ?? http.Client(),
        _bundledOverride = bundledJson;

  final PrefsStore _store;
  final http.Client _http;
  final String assetPath;

  /// Permite fijar la configuración "del paquete" sin leer el asset
  /// (pruebas y herramientas de desarrollo).
  final Map<String, dynamic>? _bundledOverride;

  AppConfig _config = const AppConfig();
  Map<String, dynamic> _bundledJson = <String, dynamic>{};
  Map<String, dynamic> _remoteJson = <String, dynamic>{};
  bool _loading = true;
  bool _disposed = false;
  String? _themeOverrideId;
  String? _remoteStatus;
  AdCounters _adCounters = const AdCounters();

  AppConfig get config => _config;
  bool get loading => _loading;

  /// Tema efectivo: el elegido por el usuario si lo hay, si no el de la marca.
  ThemeSpec get theme => _config.theme.resolve(_themeOverrideId);
  String? get themeOverrideId => _themeOverrideId;

  /// `null` si aún no se comprobó, `ok`, `error` o `sin-url`.
  String? get remoteStatus => _remoteStatus;
  bool get hasRemoteError => _remoteStatus == 'error';

  Future<void> load() async {
    _bundledJson = await _readBundled();
    _remoteJson = _store.readRemoteConfig();
    _themeOverrideId = _store.readThemeOverride();
    _adCounters = currentAdCounters(_store.readAdCounters(), DateTime.now());
    _recompute();
    _loading = false;
    _safeNotify();

    // La comprobación remota nunca bloquea el arranque.
    unawaited(refreshRemote());
  }

  /// Descarga la configuración remota. Devuelve `true` si se aplicó.
  Future<bool> refreshRemote() async {
    final String url = _config.remoteConfigUrl.trim();
    if (url.isEmpty) {
      _remoteStatus = 'sin-url';
      _safeNotify();
      return false;
    }

    final Uri? uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      _remoteStatus = 'error';
      _safeNotify();
      return false;
    }

    try {
      // Solo la app descarga el config: se identifica con un User-Agent propio
      // y el servidor (.htaccess) bloquea a los navegadores. Es ofuscacion, no
      // seguridad real: el UA va dentro de la app y se puede extraer.
      // El config.json se descarga con un User-Agent propio (gate del
      // .htaccess), distinto del que se manda a los streams (XUI.one).
      const String appAgent = 'AlphaVision-Player';
      final http.Response response = await _http.get(
        uri,
        headers: <String, String>{
          'Cache-Control': 'no-cache',
          'User-Agent': appAgent,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        _remoteStatus = 'error';
        _safeNotify();
        return false;
      }

      final dynamic decoded =
          jsonDecode(utf8.decode(response.bodyBytes, allowMalformed: true));
      final Map<String, dynamic> map = asMap(decoded);
      if (map.isEmpty) {
        _remoteStatus = 'error';
        _safeNotify();
        return false;
      }

      _remoteJson = map;
      await _store.saveRemoteConfig(map);
      _recompute();
      _remoteStatus = 'ok';
      _safeNotify();
      return true;
    } catch (_) {
      _remoteStatus = 'error';
      _safeNotify();
      return false;
    }
  }

  /// Cambia el tema activo en este dispositivo.
  Future<void> setTheme(String themeId) async {
    if (_themeOverrideId == themeId) return;
    _themeOverrideId = themeId;
    await _store.saveThemeOverride(themeId);
    _safeNotify();
  }

  /// Vuelve al tema definido por la marca.
  Future<void> clearThemeOverride() async {
    _themeOverrideId = null;
    await _store.saveThemeOverride(null);
    _safeNotify();
  }

  // --------------------------------------------------------------- anuncios
  AdCounters get adCounters => _adCounters;

  /// Anuncios que pueden rotar en la franja (todavía sin contar impresiones).
  List<AdCreative> bannerRotation({
    AdMediaType? mediaType,
    String? categoryName,
    String? title,
  }) {
    return pickAdRotation(
      _config.ads,
      AdContext(
        placement: AdPlacement.banner,
        now: DateTime.now(),
        mediaType: mediaType,
        categoryName: categoryName,
        title: title,
      ),
      _adCounters,
      limit: 4,
    );
  }

  List<AdCreative> playerNoticeRotation({AdMediaType? mediaType, String? title, String? categoryName}) =>
      pickAdRotation(_config.ads, AdContext(placement: AdPlacement.overlay,
        now: DateTime.now(), mediaType: mediaType, title: title, categoryName: categoryName),
        _adCounters, limit: _config.ads.ads.length,
        kinds: const <AdKind>{AdKind.image, AdKind.message});

  /// Anuncio de pantalla completa (interstitial o preroll). Cuenta impresión.
  AdCreative? pickFullScreenAd(
    AdPlacement placement, {
    AdMediaType? mediaType,
    String? categoryName,
    String? title,
  }) {
    final AdContext context = AdContext(
      placement: placement,
      now: DateTime.now(),
      mediaType: mediaType,
      categoryName: categoryName,
      title: title,
    );
    final AdCreative? ad = pickAd(_config.ads, context, _adCounters);
    if (ad != null) unawaited(registerImpression(ad, context));
    return ad;
  }

  /// Suma una impresión: la franja llama aquí cada vez que cambia el anuncio.
  Future<void> registerImpression(AdCreative ad, AdContext context) async {
    _adCounters = recordAdImpression(_adCounters, ad, context);
    await _store.saveAdCounters(_adCounters);
    _safeNotify();
  }

  Future<void> resetAdCounters() async {
    _adCounters = emptyAdCounters(DateTime.now());
    await _store.saveAdCounters(_adCounters);
    _safeNotify();
  }

  @override
  void dispose() {
    _disposed = true;
    _http.close();
    super.dispose();
  }

  /// Notifica solo si el controlador sigue vivo: la configuración remota se
  /// descarga en segundo plano y puede terminar después de cerrar la app.
  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  void _recompute() {
    final Map<String, dynamic> merged = deepMerge(_bundledJson, _remoteJson);
    // Mantener los presets locales aunque un panel antiguo no los enumere.
    final Map<String, dynamic> theme = asMap(merged['theme']);
    final List<dynamic> available = List<dynamic>.of(
        theme['available'] is List ? theme['available'] as List : <dynamic>[]);
    final dynamic bundledAvailable = asMap(_bundledJson['theme'])['available'];
    if (bundledAvailable is List) {
      for (final dynamic entry in bundledAvailable) {
        if (entry is Map &&
            const <String>['nova2', 'nova3'].contains(entry['id']) &&
            !available.any((existing) => existing is Map && existing['id'] == entry['id'])) {
          available.add(entry);
        }
      }
    }
    merged['theme'] = <String, dynamic>{...theme, 'available': available};
    final AppConfig parsed = AppConfig.fromJson(merged);
    // La URL remota la fija siempre el paquete, nunca la propia respuesta.
    final String bundledUrl = asString(_bundledJson['remoteConfigUrl']) ?? '';
    _config = parsed.copyWith(remoteConfigUrl: bundledUrl);
  }

  Future<Map<String, dynamic>> _readBundled() async {
    final Map<String, dynamic>? override = _bundledOverride;
    if (override != null) return override;
    try {
      final String raw = await rootBundle.loadString(assetPath);
      return asMap(jsonDecode(raw));
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}
