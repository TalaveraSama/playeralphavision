import '../utils/parse_utils.dart';

/// Los tres catálogos que expone la API de Xtream.
enum MediaKind { live, movie, series }

extension MediaKindX on MediaKind {
  String get label {
    switch (this) {
      case MediaKind.live:
        return 'En vivo';
      case MediaKind.movie:
        return 'Películas';
      case MediaKind.series:
        return 'Series';
    }
  }

  String get singular {
    switch (this) {
      case MediaKind.live:
        return 'Canal';
      case MediaKind.movie:
        return 'Película';
      case MediaKind.series:
        return 'Serie';
    }
  }

  /// `action` para listar el catálogo.
  String get streamsAction {
    switch (this) {
      case MediaKind.live:
        return 'get_live_streams';
      case MediaKind.movie:
        return 'get_vod_streams';
      case MediaKind.series:
        return 'get_series';
    }
  }

  /// `action` para listar las categorías.
  String get categoriesAction {
    switch (this) {
      case MediaKind.live:
        return 'get_live_categories';
      case MediaKind.movie:
        return 'get_vod_categories';
      case MediaKind.series:
        return 'get_series_categories';
    }
  }
}

/// Elemento unificado de catálogo: canal, película o serie.
///
/// Se serializa a JSON para poder guardar favoritos e historial en el
/// dispositivo sin volver a pedir el catálogo al servidor.
class MediaItem {
  const MediaItem({
    required this.kind,
    required this.id,
    required this.name,
    this.icon,
    this.categoryId,
    this.rating,
    this.containerExtension,
    this.plot,
    this.genre,
    this.releaseDate,
    this.cast,
    this.director,
    this.backdrop,
    this.epgChannelId,
    this.tvArchive = 0,
    this.added,
    this.episodeRunTime,
    this.youtubeTrailer,
    this.duration,
    this.order,
  });

  final MediaKind kind;

  /// `stream_id` para canales y películas, `series_id` para series.
  final String id;
  final String name;
  final String? icon;
  final String? categoryId;
  final double? rating;
  final String? containerExtension;
  final String? plot;
  final String? genre;
  final String? releaseDate;
  final String? cast;
  final String? director;
  final String? backdrop;
  final String? epgChannelId;
  final int tvArchive;
  final DateTime? added;
  final String? episodeRunTime;
  final String? youtubeTrailer;
  final String? duration;
  final int? order;

  /// Clave única para favoritos e historial.
  String get favoriteKey => '${kind.name}:$id';

  String get subtitle {
    final parts = <String>[];
    if (genre != null) parts.add(genre!);
    if (releaseDate != null) parts.add(releaseDate!);
    if (rating != null && rating! > 0) parts.add('★ ${rating!.toStringAsFixed(1)}');
    if (containerExtension != null) parts.add(containerExtension!.toUpperCase());
    return parts.join(' · ');
  }

  factory MediaItem.fromLive(Map<String, dynamic> json) {
    return MediaItem(
      kind: MediaKind.live,
      id: asStringOr(json['stream_id'], ''),
      name: asStringOr(json['name'], 'Canal sin nombre'),
      icon: asString(json['stream_icon']),
      categoryId: asString(json['category_id']),
      epgChannelId: asString(json['epg_channel_id']),
      tvArchive: asInt(json['tv_archive']),
      added: dateFromEpoch(json['added']),
      order: asIntOrNull(json['num']),
    );
  }

  factory MediaItem.fromVod(Map<String, dynamic> json) {
    return MediaItem(
      kind: MediaKind.movie,
      id: asStringOr(json['stream_id'], ''),
      name: asStringOr(json['name'], 'Película sin título'),
      icon: asString(json['stream_icon']) ?? asString(json['movie_image']),
      categoryId: asString(json['category_id']),
      rating: asDoubleOrNull(json['rating']),
      containerExtension: asString(json['container_extension']),
      plot: asString(json['plot']),
      genre: asString(json['genre']),
      releaseDate: asString(json['releaseDate']) ?? asString(json['releasedate']),
      cast: asString(json['cast']),
      director: asString(json['director']),
      backdrop: asString(json['backdrop_path']),
      // La API de XUI.one devuelve el trailer en 'youtube_trailer'.
      youtubeTrailer: asString(json['youtube_trailer']) ??
          asString(json['youtubeTrailer']),
      added: dateFromEpoch(json['added']),
      duration: asString(json['duration']),
      order: asIntOrNull(json['num']),
    );
  }

  factory MediaItem.fromSeries(Map<String, dynamic> json) {
    final backdrops = asStringList(json['backdrop_path']);
    return MediaItem(
      kind: MediaKind.series,
      id: asStringOr(json['series_id'], ''),
      name: asStringOr(json['name'], 'Serie sin título'),
      icon: asString(json['cover']) ?? asString(json['stream_icon']),
      categoryId: asString(json['category_id']),
      rating: asDoubleOrNull(json['rating']),
      plot: asString(json['plot']),
      genre: asString(json['genre']),
      releaseDate: asString(json['releaseDate']) ?? asString(json['release_date']),
      cast: asString(json['cast']),
      director: asString(json['director']),
      backdrop: backdrops.isEmpty ? null : backdrops.first,
      added: dateFromEpoch(json['last_modified']),
      episodeRunTime: asString(json['episode_run_time']),
      youtubeTrailer: asString(json['youtube_trailer']),
      order: asIntOrNull(json['num']),
    );
  }

  /// Reconstruye un elemento guardado en el dispositivo.
  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final kindName = asStringOr(json['kind'], MediaKind.live.name);
    final kind = MediaKind.values.firstWhere(
      (value) => value.name == kindName,
      orElse: () => MediaKind.live,
    );
    return MediaItem(
      kind: kind,
      id: asStringOr(json['id'], ''),
      name: asStringOr(json['name'], 'Sin nombre'),
      icon: asString(json['icon']),
      categoryId: asString(json['categoryId']),
      rating: asDoubleOrNull(json['rating']),
      containerExtension: asString(json['containerExtension']),
      plot: asString(json['plot']),
      genre: asString(json['genre']),
      releaseDate: asString(json['releaseDate']),
      cast: asString(json['cast']),
      director: asString(json['director']),
      backdrop: asString(json['backdrop']),
      epgChannelId: asString(json['epgChannelId']),
      tvArchive: asInt(json['tvArchive']),
      added: dateFromEpoch(json['added']),
      episodeRunTime: asString(json['episodeRunTime']),
      youtubeTrailer: asString(json['youtubeTrailer']),
      duration: asString(json['duration']),
      order: asIntOrNull(json['order']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'kind': kind.name,
      'id': id,
      'name': name,
      'icon': icon,
      'categoryId': categoryId,
      'rating': rating,
      'containerExtension': containerExtension,
      'plot': plot,
      'genre': genre,
      'releaseDate': releaseDate,
      'cast': cast,
      'director': director,
      'backdrop': backdrop,
      'epgChannelId': epgChannelId,
      'tvArchive': tvArchive,
      'added': added?.millisecondsSinceEpoch != null
          ? added!.millisecondsSinceEpoch ~/ 1000
          : null,
      'episodeRunTime': episodeRunTime,
      'youtubeTrailer': youtubeTrailer,
      'duration': duration,
      'order': order,
    };
  }

  MediaItem copyWith({
    MediaKind? kind,
    String? id,
    String? name,
    String? icon,
    String? categoryId,
    double? rating,
    String? containerExtension,
    String? plot,
    String? genre,
    String? releaseDate,
    String? cast,
    String? director,
    String? backdrop,
    String? epgChannelId,
    int? tvArchive,
    DateTime? added,
    String? episodeRunTime,
    String? youtubeTrailer,
    String? duration,
    int? order,
  }) {
    return MediaItem(
      kind: kind ?? this.kind,
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      categoryId: categoryId ?? this.categoryId,
      rating: rating ?? this.rating,
      containerExtension: containerExtension ?? this.containerExtension,
      plot: plot ?? this.plot,
      genre: genre ?? this.genre,
      releaseDate: releaseDate ?? this.releaseDate,
      cast: cast ?? this.cast,
      director: director ?? this.director,
      backdrop: backdrop ?? this.backdrop,
      epgChannelId: epgChannelId ?? this.epgChannelId,
      tvArchive: tvArchive ?? this.tvArchive,
      added: added ?? this.added,
      episodeRunTime: episodeRunTime ?? this.episodeRunTime,
      youtubeTrailer: youtubeTrailer ?? this.youtubeTrailer,
      duration: duration ?? this.duration,
      order: order ?? this.order,
    );
  }
}
