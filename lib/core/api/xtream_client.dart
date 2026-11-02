import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/epg_entry.dart';
import '../models/media_item.dart';
import '../models/series_detail.dart';
import '../models/xtream_account.dart';
import '../models/xtream_category.dart';
import '../utils/parse_utils.dart';
import 'xtream_api.dart';
import '../security/panel_http_client.dart';

/// Error de comunicación o de negocio con el panel.
class XtreamException implements Exception {
  const XtreamException(this.message, {this.statusCode, this.code, this.retryAfter});

  final String message;
  final int? statusCode;
  final String? code;
  final Duration? retryAfter;

  @override
  String toString() => message;
}

/// Cliente HTTP de la API `player_api.php` (Xtream Codes v2 / XUI.one).
class XtreamClient {
  XtreamClient({required this.api, http.Client? httpClient})
      : _http = httpClient ?? PanelHttpClient.create();

  final XtreamApi api;
  final http.Client _http;

  static const Duration _timeout = Duration(seconds: 25);

  /// `player_api.php` sin `action`: devuelve `user_info` y `server_info`.
  Future<XtreamAccount> authenticate() async {
    final decoded = await _get(api.apiUri());
    final map = asMap(decoded);
    if (!map.containsKey('user_info')) {
      throw const XtreamException(
        'El servidor no devolvió la estructura de Xtream Codes/XUI.one. '
        'Revisa la dirección: debe ser el panel, por ejemplo https://servidor',
      );
    }
    return XtreamAccount.fromJson(map);
  }

  Future<List<XtreamCategory>> categories(MediaKind kind) async {
    final decoded = await _get(api.apiUri(<String, String>{
      'action': kind.categoriesAction,
    }));
    final categories = _extractList(decoded, const <String>['categories'])
        .map(XtreamCategory.fromJson)
        .where((category) => category.id.isNotEmpty)
        .toList();
    categories.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return categories;
  }

  Future<List<MediaItem>> items(MediaKind kind, {String? categoryId}) async {
    final params = <String, String>{'action': kind.streamsAction};
    if (categoryId != null && categoryId.isNotEmpty) {
      params['category_id'] = categoryId;
    }
    final decoded = await _get(api.apiUri(params));
    final raw = _extractList(
      decoded,
      const <String>['streams', 'series', 'movies', 'available_channels'],
    );

    final items = <MediaItem>[];
    for (final json in raw) {
      switch (kind) {
        case MediaKind.live:
          items.add(MediaItem.fromLive(json));
        case MediaKind.movie:
          items.add(MediaItem.fromVod(json));
        case MediaKind.series:
          items.add(MediaItem.fromSeries(json));
      }
    }
    items.removeWhere((item) => item.id.isEmpty);
    items.sort((a, b) {
      final orderA = a.order ?? 0;
      final orderB = b.order ?? 0;
      if (orderA != 0 && orderB != 0 && orderA != orderB) {
        return orderA.compareTo(orderB);
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return items;
  }

  /// `get_vod_info`: completa la ficha de una película.
  Future<MediaItem> vodInfo(String vodId) async {
    final decoded = await _get(api.apiUri(<String, String>{
      'action': 'get_vod_info',
      'vod_id': vodId,
    }));
    final map = asMap(decoded);
    final info = asMap(map['info']);
    final movieData = asMap(map['movie_data']);
    final merged = <String, dynamic>{...info, ...movieData};

    merged['stream_id'] = asStringOr(merged['stream_id'], vodId);
    merged['name'] = asStringOr(merged['name'], 'Película');
    merged['stream_icon'] ??= asString(info['movie_image']);
    final backdrops = asStringList(info['backdrop_path']);
    if (backdrops.isNotEmpty) merged['backdrop_path'] = backdrops.first;
    if (asString(merged['duration']) == null) {
      merged['duration'] = asString(info['duration']);
    }

    final item = MediaItem.fromVod(merged);
    return item.copyWith(id: vodId, kind: MediaKind.movie);
  }

  /// `get_series_info`: temporadas y episodios de una serie.
  Future<SeriesDetail> seriesInfo(String seriesId) async {
    final decoded = await _get(api.apiUri(<String, String>{
      'action': 'get_series_info',
      'series_id': seriesId,
    }));
    return SeriesDetail.fromJson(seriesId, asMap(decoded));
  }

  /// Guía corta del canal; si el panel no la soporta se intenta con
  /// `get_simple_data_table`.
  Future<List<EpgEntry>> shortEpg(String streamId, {int limit = 8}) async {
    final decoded = await _get(api.apiUri(<String, String>{
      'action': 'get_short_epg',
      'stream_id': streamId,
      'limit': '$limit',
    }));
    var raw = _extractList(decoded, const <String>['epg_listings']);

    if (raw.isEmpty) {
      final fallback = await _get(api.apiUri(<String, String>{
        'action': 'get_simple_data_table',
        'stream_id': streamId,
      }));
      raw = _extractList(fallback, const <String>['epg_listings']);
    }
    return raw.map(EpgEntry.fromJson).toList();
  }

  void dispose() => _http.close();

  List<Map<String, dynamic>> _extractList(
    dynamic decoded,
    List<String> keys,
  ) {
    if (decoded is List) return asMapList(decoded);
    if (decoded is Map) {
      for (final key in keys) {
        final value = decoded[key];
        if (value is List) return asMapList(value);
      }
      for (final value in decoded.values) {
        if (value is List) return asMapList(value);
      }
    }
    return const <Map<String, dynamic>>[];
  }

  DateTime? _retryUntil;
  Duration? get retryRemaining {
    final until = _retryUntil;
    if (until == null) return null;
    final remaining = until.difference(DateTime.now());
    return remaining.isNegative ? null : remaining;
  }
  Future<Map<String, dynamic>> securityAction(String action, [Map<String, String> args = const {}]) async =>
      asMap(await _get(api.apiUri({'action': action, ...args})));

  Future<dynamic> _get(Uri uri) async {
    if (uri.scheme != 'https') throw const XtreamException('Este panel requiere una dirección HTTPS válida.', statusCode: 400);
    final remaining = retryRemaining;
    if (remaining != null) throw XtreamException('Espera antes de volver a conectar.', statusCode: 429, retryAfter: remaining);
    http.Response response;
    try {
      final request = http.Request('GET', uri)..followRedirects = false;
      request.headers.addAll(api.defaultHeaders);
      response = await http.Response.fromStream(await _http.send(request)).timeout(_timeout);
    } on TimeoutException {
      throw const XtreamException(
        'El servidor tardó demasiado en responder. Comprueba tu conexión.',
      );
    } on HandshakeException {
      throw const XtreamException(
        'No se pudo verificar el certificado HTTPS del panel.',
      );
    } on SocketException catch (error) {
      throw XtreamException(
        'No se pudo conectar con el servidor'
        '${error.osError == null ? '' : ' (${error.osError!.message})'}. '
        'Comprueba la dirección y el puerto.',
      );
    } on http.ClientException {
      throw const XtreamException('No se pudo conectar con el panel.');
    } catch (_) {
      throw const XtreamException('No se pudo establecer una conexión segura con el panel.');
    }

    if (response.statusCode == 429) {
      var seconds = int.tryParse(response.headers['retry-after'] ?? '') ?? 600;
      try {
        if (int.tryParse(response.headers['retry-after'] ?? '') == null) {
          final base = response.headers['date'] == null ? DateTime.now() : HttpDate.parse(response.headers['date']!);
          seconds = HttpDate.parse(response.headers['retry-after']!).difference(base).inSeconds;
        }
      } catch (_) { /* Conservative cooldown without a valid Retry-After. */ }
      final delay = Duration(seconds: seconds < 1 ? 1 : seconds);
      _retryUntil = DateTime.now().add(delay);
      throw XtreamException('Demasiados intentos o conexiones. Espera antes de volver a conectar.', statusCode: 429, retryAfter: delay);
    }
    if (response.statusCode != 200) {
      String? code;
      try { code = asString(asMap(jsonDecode(response.body))['error']); } catch (_) {}
      throw XtreamException(_securityMessage(code, response.statusCode),
        statusCode: response.statusCode, code: code);
    }

    final body = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
    if (body.isEmpty) {
      throw const XtreamException('El servidor devolvió una respuesta vacía.');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      if (body.startsWith('<')) {
        throw const XtreamException(
          'El servidor devolvió HTML en lugar de JSON. La dirección debe '
          'apuntar al panel (por ejemplo https://servidor).',
        );
      }
      throw const XtreamException('La respuesta del servidor es ilegible.');
    }

    if (decoded is Map) {
      final error = asString(decoded['error']);
      if (error != null) throw XtreamException(_securityMessage(error, 403), statusCode: 403, code: error);
    }
    return decoded;
  }
  static String _securityMessage(String? code, int status) {
    switch (code) {
      case 'device_limit': return 'Tu cuenta ya está en uso en otro aparato. Contacta con soporte.';
      case 'device_revoked': return 'Este aparato fue desvinculado. Contacta con tu proveedor.';
      case 'device_invalid': case 'device_required': case 'device_token_required':
        return 'Es necesario vincular este aparato con tu cuenta.';
    }
    if (status == 401) return 'Usuario o contraseña inválidos.';
    if (status == 403) return 'El panel no autoriza esta cuenta o esta red. Contacta con tu proveedor.';
    if (status == 503) return 'Canal temporalmente no disponible.';
    return 'El panel respondió HTTP $status.';
  }

}
