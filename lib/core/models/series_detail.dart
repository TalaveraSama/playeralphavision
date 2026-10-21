import '../utils/parse_utils.dart';

/// Respuesta de `get_series_info`.
class SeriesDetail {
  const SeriesDetail({
    required this.seriesId,
    required this.info,
    required this.seasons,
    required this.episodes,
  });

  final String seriesId;

  /// Bloque `info` completo (sin compactar) para mostrar metadatos variados.
  final Map<String, dynamic> info;
  final List<SeasonInfo> seasons;

  /// Todos los episodios, aplanados y ordenados por temporada y número.
  final List<EpisodeInfo> episodes;

  List<EpisodeInfo> episodesOf(int season) =>
      episodes.where((episode) => episode.season == season).toList();

  factory SeriesDetail.fromJson(String seriesId, Map<String, dynamic> json) {
    final seasons = <SeasonInfo>[];
    final rawSeasons = json['seasons'];
    if (rawSeasons is List) {
      for (final entry in rawSeasons) {
        if (entry is Map) {
          seasons.add(SeasonInfo.fromJson(asMap(entry)));
        } else {
          final number = asIntOrNull(entry);
          if (number != null) seasons.add(SeasonInfo(number: number));
        }
      }
    }

    final episodes = <EpisodeInfo>[];
    final grouped = json['episodes'];
    if (grouped is Map) {
      grouped.forEach((key, value) {
        final seasonNumber = asIntOrNull(key) ?? 0;
        for (final raw in asMapList(value)) {
          episodes.add(EpisodeInfo.fromJson(raw, fallbackSeason: seasonNumber));
        }
      });
    } else if (grouped is List) {
      for (final raw in asMapList(grouped)) {
        episodes.add(EpisodeInfo.fromJson(raw));
      }
    }

    episodes.sort((a, b) {
      final bySeason = a.season.compareTo(b.season);
      return bySeason != 0 ? bySeason : a.episodeNum.compareTo(b.episodeNum);
    });

    if (seasons.isEmpty && episodes.isNotEmpty) {
      final numbers = episodes.map((episode) => episode.season).toSet().toList()
        ..sort();
      seasons.addAll(numbers.map((number) => SeasonInfo(number: number)));
    }

    return SeriesDetail(
      seriesId: seriesId,
      info: asMap(json['info']),
      seasons: seasons,
      episodes: episodes,
    );
  }
}

class SeasonInfo {
  const SeasonInfo({
    required this.number,
    this.name,
    this.cover,
    this.episodeCount,
  });

  final int number;
  final String? name;
  final String? cover;
  final int? episodeCount;

  String get title => (name != null && name!.isNotEmpty) ? name! : 'Temporada $number';

  factory SeasonInfo.fromJson(Map<String, dynamic> json) {
    return SeasonInfo(
      number: asInt(json['season_number'], asInt(json['season'], 0)),
      name: asString(json['name']),
      cover: asString(json['cover']) ?? asString(json['cover_big']),
      episodeCount: asIntOrNull(json['episode_count']),
    );
  }
}

class EpisodeInfo {
  const EpisodeInfo({
    required this.id,
    required this.title,
    required this.season,
    required this.episodeNum,
    this.containerExtension = 'mkv',
    this.plot,
    this.duration,
    this.image,
    this.rating,
  });

  /// `id` del episodio: es el que se usa en la URL `/series/...`.
  final String id;
  final String title;
  final int season;
  final int episodeNum;
  final String containerExtension;
  final String? plot;
  final String? duration;
  final String? image;
  final double? rating;

  String get label {
    final cleanTitle = title.replaceFirst(
      RegExp(r'^S\d+\s*E\d+\s*[-:·]?\s*', caseSensitive: false),
      '',
    );
    return cleanTitle.isEmpty ? 'Episodio $episodeNum' : cleanTitle;
  }

  factory EpisodeInfo.fromJson(Map<String, dynamic> json,
      {int fallbackSeason = 0}) {
    final info = asMap(json['info']);
    return EpisodeInfo(
      id: asStringOr(json['id'], ''),
      title: asStringOr(json['title'], 'Episodio'),
      season: asInt(json['season'], fallbackSeason),
      episodeNum: asInt(json['episode_num']),
      containerExtension: asStringOr(json['container_extension'], 'mkv'),
      plot: asString(info['plot']) ?? asString(json['plot']),
      duration: asString(info['duration']) ??
          asString(info['duration_secs']) ??
          asString(json['duration']),
      image: asString(info['movie_image']) ?? asString(json['movie_image']),
      rating: asDoubleOrNull(info['rating']) ?? asDoubleOrNull(json['rating']),
    );
  }
}
