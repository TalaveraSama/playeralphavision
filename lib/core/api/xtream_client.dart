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

/// Error de comunicación o de negocio con el panel.
class XtreamException implements Exception {
  const XtreamException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Cliente HTTP de la API `player_api.php` (Xtream Codes v2 / XUI.one).
class XtreamClient {
  XtreamClient({required this.api, http.Client? httpClient})
      : _http = httpClient ?? http.Client();

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
        'Revisa la dirección: debe ser el panel, por ejemplo http://servidor:8080',
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

  Future<dynamic> _get(Uri uri) async {
    http.Response response;
    try {
      response = await _http
          .get(uri, headers: api.defaultHeaders)
          .timeout(_timeout);
    } on TimeoutException {
      throw const XtreamException(
        'El servidor tardó demasiado en responder. Comprueba tu conexión.',
      );
    } on HandshakeException {
      throw const XtreamException(
        'Falló el handshake TLS. Prueba con http:// o revisa el certificado '
        'del panel.',
      );
    } on SocketException catch (error) {
      throw XtreamException(
        'No se pudo conectar con el servidor'
        '${error.osError == null ? '' : ' (${error.osError!.message})'}. '
        'Comprueba la dirección y el puerto.',
      );
    } on http.ClientException catch (error) {
      throw XtreamException('Error de red: ${error.message}');
    }

    if (response.statusCode != 200) {
      throw XtreamException(
        'El servidor respondió HTTP ${response.statusCode}.',
        statusCode: response.statusCode,
      );
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
          'apuntar al panel (por ejemplo http://servidor:8080).',
        );
      }
      throw const XtreamException('La respuesta del servidor es ilegible.');
    }

    if (decoded is Map) {
      final error = asString(decoded['error']);
      if (error != null) throw XtreamException(error);
    }
    return decoded;
  }
}
