import '../utils/parse_utils.dart';
import 'media_item.dart';
import 'playable_item.dart';

/// Posición de reproducción guardada, para la fila «Continuar viendo».
///
/// Se guarda lo justo para poder reanudar: el elemento de catálogo (películas y
/// canales) o el episodio ya resuelto (series) y el segundo por el que iba.
class ResumeEntry {
  const ResumeEntry({
    required this.key,
    required this.title,
    this.subtitle,
    this.image,
    this.item,
    this.playable,
    this.positionSec = 0,
    this.durationSec = 0,
    this.updatedAt = 0,
  });

  /// Clave única (`movie:123`, `series:9001`...).
  final String key;
  final String title;
  final String? subtitle;
  final String? image;

  /// Elemento de catálogo, si lo hay (permite volver a construir la URL).
  final MediaItem? item;

  /// Episodio ya resuelto, para series.
  final PlayableItem? playable;

  final int positionSec;
  final int durationSec;
  final int updatedAt;

  Duration get position => Duration(seconds: positionSec);
  Duration get duration => Duration(seconds: durationSec);

  /// Progreso entre 0 y 1.
  double get progress {
    if (durationSec <= 0) return 0;
    return (positionSec / durationSec).clamp(0.0, 1.0);
  }

  /// ¿Merece la pena ofrecer «continuar»? (ni recién empezado ni terminado).
  bool get isResumable {
    if (positionSec < 20) return false;
    if (durationSec > 0 && positionSec > durationSec - 45) return false;
    return true;
  }

  String get timeLabel {
    final Duration left = duration - position;
    if (durationSec <= 0 || left.isNegative) return '';
    final int minutes = left.inMinutes;
    if (minutes >= 60) {
      return 'Quedan ${left.inHours} h ${minutes.remainder(60)} min';
    }
    return 'Quedan $minutes min';
  }

  factory ResumeEntry.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> rawItem = asMap(json['item']);
    final Map<String, dynamic> rawPlayable = asMap(json['playable']);
    return ResumeEntry(
      key: asStringOr(json['key'], ''),
      title: asStringOr(json['title'], ''),
      subtitle: asString(json['subtitle']),
      image: asString(json['image']),
      item: rawItem.isEmpty ? null : MediaItem.fromJson(rawItem),
      playable: rawPlayable.isEmpty
          ? null
          : PlayableItem(
              title: asStringOr(rawPlayable['title'], ''),
              url: asStringOr(rawPlayable['url'], ''),
              subtitle: asString(rawPlayable['subtitle']),
              logo: asString(rawPlayable['logo']),
              isLive: asBool(rawPlayable['isLive']),
              streamId: asString(rawPlayable['streamId']),
            ),
      positionSec: asInt(json['positionSec']),
      durationSec: asInt(json['durationSec']),
      updatedAt: asInt(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': key,
        'title': title,
        'subtitle': subtitle,
        'image': image,
        'item': item?.toJson(),
        'playable': playable == null
            ? null
            : <String, dynamic>{
                'title': playable!.title,
                'url': playable!.url,
                'subtitle': playable!.subtitle,
                'logo': playable!.logo,
                'isLive': playable!.isLive,
                'streamId': playable!.streamId,
              },
        'positionSec': positionSec,
        'durationSec': durationSec,
        'updatedAt': updatedAt,
      };

  ResumeEntry copyWith({
    String? key,
    String? title,
    String? subtitle,
    String? image,
    MediaItem? item,
    PlayableItem? playable,
    int? positionSec,
    int? durationSec,
    int? updatedAt,
  }) {
    return ResumeEntry(
      key: key ?? this.key,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      image: image ?? this.image,
      item: item ?? this.item,
      playable: playable ?? this.playable,
      positionSec: positionSec ?? this.positionSec,
      durationSec: durationSec ?? this.durationSec,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
