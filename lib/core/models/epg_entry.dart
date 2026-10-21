import '../utils/parse_utils.dart';

/// Entrada de la guía corta (`get_short_epg` / `get_simple_data_table`).
class EpgEntry {
  const EpgEntry({
    required this.title,
    required this.description,
    this.startTimestamp,
    this.stopTimestamp,
    this.nowPlaying = false,
    this.hasArchive = false,
  });

  final String title;
  final String description;
  final int? startTimestamp;
  final int? stopTimestamp;
  final bool nowPlaying;
  final bool hasArchive;

  DateTime? get start => startTimestamp == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(startTimestamp! * 1000);

  DateTime? get stop => stopTimestamp == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(stopTimestamp! * 1000);

  String get timeRange {
    if (start == null || stop == null) return '';
    String fmt(DateTime value) =>
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    return '${fmt(start!)} - ${fmt(stop!)}';
  }

  factory EpgEntry.fromJson(Map<String, dynamic> json) {
    return EpgEntry(
      // Xtream devuelve título y descripción en Base64.
      title: decodeMaybeBase64(json['title']),
      description: decodeMaybeBase64(json['description']),
      startTimestamp: asIntOrNull(json['start_timestamp']),
      stopTimestamp: asIntOrNull(json['stop_timestamp']),
      nowPlaying: asBool(json['now_playing']),
      hasArchive: asBool(json['has_archive']),
    );
  }
}
