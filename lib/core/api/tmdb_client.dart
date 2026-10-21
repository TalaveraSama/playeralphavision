import 'dart:convert';

import 'package:http/http.dart' as http;

/// Arte (póster vertical + backdrop horizontal) resuelto desde TMDB.
class TmdbArtwork {
  const TmdbArtwork({this.poster, this.backdrop});

  /// `https://image.tmdb.org/t/p/w500...` (vertical, para carátulas).
  final String? poster;

  /// `https://image.tmdb.org/t/p/w1280...` (horizontal, para el hero).
  final String? backdrop;

  bool get isEmpty => poster == null && backdrop == null;
}

/// Ficha completa de una película según TMDB.
class TmdbMovieDetails {
  const TmdbMovieDetails({
    this.overview,
    this.runtime,
    this.genres = const <String>[],
    this.vote,
    this.cast = const <String>[],
    this.poster,
    this.backdrop,
    this.releaseDate,
  });

  final String? overview;
  final int? runtime;
  final List<String> genres;
  final double? vote;
  final List<String> cast;
  final String? poster;
  final String? backdrop;
  final String? releaseDate;
}

/// Cliente mínimo de TMDB: tráileres + arte (póster/backdrop).
///
/// Usa una API key v3 de TMDB (https://www.themoviedb.org/settings/api).
class TmdbClient {
  TmdbClient({required this.apiKey, this.language = 'es-ES'});

  final String apiKey;
  final String language;

  static const String _img = 'https://image.tmdb.org/t/p';

  bool get enabled => apiKey.trim().isNotEmpty;

  /// Devuelve la clave de YouTube del tráiler, o null si no hay.
  Future<String?> trailerKey({
    required String title,
    int? year,
    bool isSeries = false,
  }) async {
    if (!enabled || title.trim().isEmpty) return null;
    final String type = isSeries ? 'tv' : 'movie';
    try {
      final Uri search = Uri.https(
        'api.themoviedb.org',
        '/3/search/$type',
        <String, String>{
          'api_key': apiKey.trim(),
          'query': _cleanTitle(title),
          'language': language,
          if (year != null) (isSeries ? 'first_air_date_year' : 'year'): '$year',
        },
      );
      final http.Response res =
          await http.get(search).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final Map<String, dynamic> data =
          jsonDecode(res.body) as Map<String, dynamic>;
      final List<dynamic> results =
          (data['results'] as List<dynamic>?) ?? <dynamic>[];
      if (results.isEmpty) return null;
      final int id = (results.first['id'] as num).toInt();

      final Uri videos = Uri.https(
        'api.themoviedb.org',
        '/3/$type/$id/videos',
        <String, String>{
          'api_key': apiKey.trim(),
          'language': language,
        },
      );
      final http.Response vres =
          await http.get(videos).timeout(const Duration(seconds: 12));
      if (vres.statusCode != 200) return null;
      final Map<String, dynamic> vdata =
          jsonDecode(vres.body) as Map<String, dynamic>;
      final List<dynamic> vids =
          (vdata['results'] as List<dynamic>?) ?? <dynamic>[];

      for (final dynamic raw in vids) {
        final Map<String, dynamic> v = raw as Map<String, dynamic>;
        if ((v['site'] as String?) == 'YouTube' &&
            (v['type'] as String?) == 'Trailer') {
          return v['key'] as String?;
        }
      }
      for (final dynamic raw in vids) {
        final Map<String, dynamic> v = raw as Map<String, dynamic>;
        if ((v['site'] as String?) == 'YouTube') return v['key'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Póster + backdrop de una película/serie. `null` si no se encuentra.
  Future<TmdbArtwork?> artwork({
    required String title,
    int? year,
    bool isSeries = false,
  }) async {
    if (!enabled || title.trim().isEmpty) return null;
    final String type = isSeries ? 'tv' : 'movie';
    try {
      final Uri search = Uri.https(
        'api.themoviedb.org',
        '/3/search/$type',
        <String, String>{
          'api_key': apiKey.trim(),
          'query': _cleanTitle(title),
          'language': language,
          if (year != null) (isSeries ? 'first_air_date_year' : 'year'): '$year',
        },
      );
      final http.Response res =
          await http.get(search).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final Map<String, dynamic> data =
          jsonDecode(res.body) as Map<String, dynamic>;
      final List<dynamic> results =
          (data['results'] as List<dynamic>?) ?? <dynamic>[];
      if (results.isEmpty) return null;
      final Map<String, dynamic> first = results.first as Map<String, dynamic>;
      final String? posterPath = first['poster_path'] as String?;
      final String? backdropPath = first['backdrop_path'] as String?;
      return TmdbArtwork(
        poster: posterPath != null ? '$_img/w500$posterPath' : null,
        backdrop: backdropPath != null ? '$_img/w1280$backdropPath' : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// Ficha completa (Vista general + reparto + nota + duración + géneros)
  /// para la pantalla de detalles de una película.
  Future<TmdbMovieDetails?> movieDetails({
    required String title,
    int? year,
    bool isSeries = false,
  }) async {
    if (!enabled || title.trim().isEmpty) return null;
    final String type = isSeries ? 'tv' : 'movie';
    try {
      final Uri search = Uri.https(
        'api.themoviedb.org',
        '/3/search/$type',
        <String, String>{
          'api_key': apiKey.trim(),
          'query': _cleanTitle(title),
          'language': language,
          if (year != null) (isSeries ? 'first_air_date_year' : 'year'): '$year',
        },
      );
      final http.Response res =
          await http.get(search).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final Map<String, dynamic> sdata =
          jsonDecode(res.body) as Map<String, dynamic>;
      final List<dynamic> results =
          (sdata['results'] as List<dynamic>?) ?? <dynamic>[];
      if (results.isEmpty) return null;
      final int id = (results.first['id'] as num).toInt();

      final Uri detail = Uri.https(
        'api.themoviedb.org',
        '/3/$type/$id',
        <String, String>{
          'api_key': apiKey.trim(),
          'language': language,
          'append_to_response': 'credits',
        },
      );
      final http.Response dres =
          await http.get(detail).timeout(const Duration(seconds: 12));
      if (dres.statusCode != 200) return null;
      final Map<String, dynamic> d =
          jsonDecode(dres.body) as Map<String, dynamic>;

      final String? posterPath = d['poster_path'] as String?;
      final String? backdropPath = d['backdrop_path'] as String?;
      final List<String> genres = <String>[
        for (final dynamic g in (d['genres'] as List<dynamic>?) ?? <dynamic>[])
          if ((g as Map<String, dynamic>)['name'] != null)
            g['name'].toString(),
      ];
      final List<String> cast = <String>[
        for (final dynamic c
            in ((d['credits'] as Map<String, dynamic>?)?['cast']
                    as List<dynamic>?) ??
                <dynamic>[])
          if ((c as Map<String, dynamic>)['name'] != null)
            c['name'].toString(),
      ];

      return TmdbMovieDetails(
        overview: (d['overview'] as String?)?.trim().isEmpty == true
            ? null
            : d['overview'] as String?,
        runtime: (d['runtime'] as num?)?.toInt(),
        genres: genres,
        vote: (d['vote_average'] as num?)?.toDouble(),
        cast: cast.take(8).toList(),
        poster: posterPath != null ? '$_img/w500$posterPath' : null,
        backdrop: backdropPath != null ? '$_img/w1280$backdropPath' : null,
        releaseDate: (d['release_date'] ?? d['first_air_date']) as String?,
      );
    } catch (_) {
      return null;
    }
  }

  /// Limpia el nombre del panel para que TMDB lo encuentre.
  String _cleanTitle(String title) {
    String t = title;
    t = t.replaceAll(RegExp(r'\s*\(\d{4}\)\s*$'), '');
    t = t.replaceAll(RegExp(r'\s*\[[^\]]*\]\s*'), ' ');
    t = t.replaceAll(
        RegExp(r'\s+(4K|UHD|FHD|HD|SD|HDR|DV)\b.*$', caseSensitive: false), '');
    return t.trim();
  }
}
