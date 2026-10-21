import '../utils/parse_utils.dart';

/// Dónde se puede mostrar un anuncio.
enum AdPlacement { banner, interstitial, preroll, overlay }

extension AdPlacementX on AdPlacement {
  String get id {
    switch (this) {
      case AdPlacement.banner:
        return 'banner';
      case AdPlacement.interstitial:
        return 'interstitial';
      case AdPlacement.preroll:
        return 'preroll';
      case AdPlacement.overlay:
        return 'overlay';
    }
  }

  String get label {
    switch (this) {
      case AdPlacement.banner:
        return 'Franja en la app';
      case AdPlacement.interstitial:
        return 'Pantalla completa al abrir';
      case AdPlacement.preroll:
        return 'Antes de reproducir (preroll)';
      case AdPlacement.overlay:
        return 'Aviso sobre el vídeo';
    }
  }
}

/// Tipo de creatividad.
enum AdKind { image, video, message }

extension AdKindX on AdKind {
  String get id {
    switch (this) {
      case AdKind.image:
        return 'image';
      case AdKind.video:
        return 'video';
      case AdKind.message:
        return 'message';
    }
  }
}

/// Tipo de contenido al que puede apuntar un anuncio.
enum AdMediaType { live, vod, series }

/// Una creatividad publicitaria con segmentación y límites.
///
/// El motor que la elige vive en `core/ads/ad_engine.dart` y es una función
/// pura, igual que en el panel de referencia, para poder probarla sin UI.
class AdCreative {
  const AdCreative({
    this.id = '',
    this.kind = AdKind.image,
    this.label = 'Publicidad',
    this.mediaUrl = '',
    this.clickUrl = '',
    this.title = '',
    this.text = '',
    this.durationSec = 15,
    this.skipAfterSec = 5,
    this.weight = 1,
    this.frequencyCapPerDay,
    this.mediaTypes = const <AdMediaType>[],
    this.categories = const <String>[],
    this.keywords = const <String>[],
    this.hoursFrom,
    this.hoursTo,
    this.enabled = true,
  });

  final String id;
  final AdKind kind;
  final String label;

  /// Imagen o vídeo. Obligatorio salvo en los anuncios de solo texto.
  final String mediaUrl;

  /// Enlace que se abre al pulsar (opcional).
  final String clickUrl;
  final String title;
  final String text;

  /// Duración máxima en pantalla (y tope para los vídeos).
  final int durationSec;

  /// Segundos antes de poder cerrar el anuncio.
  final int skipAfterSec;

  /// Peso relativo cuando compiten varios anuncios.
  final int weight;

  /// Máximo de veces al día en este dispositivo (`null` = sin límite).
  final int? frequencyCapPerDay;

  // ------------------------------------------------------------- segmentación
  final List<AdMediaType> mediaTypes;

  /// Subcadenas del nombre de la categoría (sin acentos ni mayúsculas).
  final List<String> categories;

  /// Subcadenas del título o de la categoría.
  final List<String> keywords;

  /// Franja horaria local; `null` en cualquiera de los dos = sin restricción.
  final int? hoursFrom;
  final int? hoursTo;

  final bool enabled;

  bool get hasMedia => mediaUrl.trim().isNotEmpty;

  /// Un anuncio es utilizable si está activo y tiene algo que mostrar.
  bool get isUsable =>
      enabled && (hasMedia || (kind == AdKind.message && text.isNotEmpty));

  bool get hasTargeting =>
      mediaTypes.isNotEmpty ||
      categories.isNotEmpty ||
      keywords.isNotEmpty ||
      hoursFrom != null ||
      hoursTo != null;

  factory AdCreative.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> targeting = asMap(json['targeting']);
    final String kindName = asStringOr(json['type'], 'image').toLowerCase();

    AdKind kind;
    switch (kindName) {
      case 'video':
        kind = AdKind.video;
      case 'message':
        kind = AdKind.message;
      default:
        kind = AdKind.image;
    }

    final List<AdMediaType> mediaTypes = <AdMediaType>[];
    final dynamic rawTypes = targeting['mediaTypes'] ?? json['mediaTypes'];
    if (rawTypes is List) {
      for (final dynamic entry in rawTypes) {
        final String value = (entry?.toString() ?? '').toLowerCase();
        if (value == 'live' || value == 'vod' || value == 'series') {
          mediaTypes.add(AdMediaType.values.firstWhere((AdMediaType t) => t.name == value));
        }
      }
    }

    return AdCreative(
      id: asStringOr(json['id'], ''),
      kind: kind,
      label: asStringOr(json['label'], 'Publicidad'),
      // Se aceptan los nombres de campo del panel antiguo (imageUrl).
      mediaUrl: asString(json['mediaUrl']) ?? asString(json['imageUrl']) ?? '',
      clickUrl: asStringOr(json['clickUrl'], ''),
      title: asStringOr(json['title'], ''),
      text: asStringOr(json['text'], ''),
      durationSec: asInt(json['durationSec'], 15),
      skipAfterSec: asInt(json['skipAfterSec'], 5),
      weight: asInt(json['weight'], 1).clamp(1, 100),
      frequencyCapPerDay: asIntOrNull(json['frequencyCapPerDay']),
      mediaTypes: mediaTypes,
      categories: asStringList(targeting['categories']),
      keywords: asStringList(targeting['keywords']),
      hoursFrom: asIntOrNull(targeting['hoursFrom']),
      hoursTo: asIntOrNull(targeting['hoursTo']),
      enabled: json['enabled'] == null ? true : asBool(json['enabled']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': kind.id,
        'label': label,
        'mediaUrl': mediaUrl,
        'clickUrl': clickUrl,
        'title': title,
        'text': text,
        'durationSec': durationSec,
        'skipAfterSec': skipAfterSec,
        'weight': weight,
        'frequencyCapPerDay': frequencyCapPerDay,
        'enabled': enabled,
        'targeting': <String, dynamic>{
          'mediaTypes': mediaTypes.map((AdMediaType t) => t.name).toList(),
          'categories': categories,
          'keywords': keywords,
          'hoursFrom': hoursFrom,
          'hoursTo': hoursTo,
        },
      };

  AdCreative copyWith({
    String? id,
    AdKind? kind,
    String? label,
    String? mediaUrl,
    String? clickUrl,
    String? title,
    String? text,
    int? durationSec,
    int? skipAfterSec,
    int? weight,
    int? frequencyCapPerDay,
    List<AdMediaType>? mediaTypes,
    List<String>? categories,
    List<String>? keywords,
    int? hoursFrom,
    int? hoursTo,
    bool? enabled,
  }) {
    return AdCreative(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      label: label ?? this.label,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      clickUrl: clickUrl ?? this.clickUrl,
      title: title ?? this.title,
      text: text ?? this.text,
      durationSec: durationSec ?? this.durationSec,
      skipAfterSec: skipAfterSec ?? this.skipAfterSec,
      weight: weight ?? this.weight,
      frequencyCapPerDay: frequencyCapPerDay ?? this.frequencyCapPerDay,
      mediaTypes: mediaTypes ?? this.mediaTypes,
      categories: categories ?? this.categories,
      keywords: keywords ?? this.keywords,
      hoursFrom: hoursFrom ?? this.hoursFrom,
      hoursTo: hoursTo ?? this.hoursTo,
      enabled: enabled ?? this.enabled,
    );
  }
}

/// Ajustes de un emplazamiento publicitario.
class AdPlacementConfig {
  const AdPlacementConfig({this.enabled = false, this.maxPerHour = 6});

  final bool enabled;

  /// Tope de impresiones por hora en este dispositivo (0 = nunca).
  final int maxPerHour;

  factory AdPlacementConfig.fromJson(Map<String, dynamic> json) =>
      AdPlacementConfig(
        enabled: asBool(json['enabled']),
        maxPerHour: asInt(json['maxPerHour'], 6),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'enabled': enabled,
        'maxPerHour': maxPerHour,
      };
}

/// Configuración completa de anuncios.
///
/// Acepta el formato nuevo (`placements` + `ads`) y también el antiguo
/// (`banner.creatives` / `interstitial`) para no romper configuraciones ya
/// publicadas.
class AdsConfig {
  const AdsConfig({
    this.enabled = false,
    this.placements = const <AdPlacement, AdPlacementConfig>{},
    this.ads = const <AdCreative>[],
    this.rotationSeconds = 12,
    this.inPlayer = false,
    this.inPlayerSeconds = 0,
  });

  final bool enabled;
  final Map<AdPlacement, AdPlacementConfig> placements;
  final List<AdCreative> ads;

  /// Segundos que se muestra cada creatividad en la franja.
  final int rotationSeconds;

  /// Mostrar también la franja sobre los controles del reproductor.
  final bool inPlayer;

  /// Segundos que se mantiene visible la franja en el reproductor. 0 = fija.
  final int inPlayerSeconds;

  AdPlacementConfig placement(AdPlacement placement) =>
      placements[placement] ?? const AdPlacementConfig();

  List<AdCreative> get usableAds =>
      ads.where((AdCreative ad) => ad.isUsable).toList();

  /// ¿Hay algo que mostrar en algún emplazamiento?
  bool get hasAnyAd {
    if (!enabled || usableAds.isEmpty) return false;
    for (final AdPlacement placement in AdPlacement.values) {
      final AdPlacementConfig config = this.placement(placement);
      if (config.enabled && config.maxPerHour > 0 && _hasFor(placement)) {
        return true;
      }
    }
    return false;
  }

  bool _hasFor(AdPlacement placement) {
    switch (placement) {
      case AdPlacement.banner:
        return usableAds.isNotEmpty;
      case AdPlacement.interstitial:
      case AdPlacement.preroll:
      case AdPlacement.overlay:
        return usableAds
            .any((AdCreative ad) => ad.kind != AdKind.message);
    }
  }

  factory AdsConfig.fromJson(Map<String, dynamic> json) {
    final List<AdCreative> ads = <AdCreative>[];
    final Map<AdPlacement, AdPlacementConfig> placements =
        <AdPlacement, AdPlacementConfig>{};

    // ---------------------------------------------------------- formato nuevo
    for (final AdPlacement placement in AdPlacement.values) {
      final dynamic raw = asMap(json['placements'])[placement.id];
      if (raw is Map) {
        placements[placement] = AdPlacementConfig.fromJson(asMap(raw));
      }
    }
    final dynamic rawAds = json['ads'];
    if (rawAds is List) {
      for (final dynamic entry in rawAds) {
        if (entry is Map) ads.add(AdCreative.fromJson(asMap(entry)));
      }
    }

    // --------------------------------------------------------- formato antiguo
    final Map<String, dynamic> legacyBanner = asMap(json['banner']);
    final dynamic legacyCreatives = legacyBanner['creatives'];
    if (rawAds is! List && legacyCreatives is List) {
      for (final dynamic entry in legacyCreatives) {
        if (entry is Map) {
          ads.add(
            AdCreative.fromJson(asMap(entry)).copyWith(
              id: 'banner-${ads.length + 1}',
              kind: AdKind.image,
            ),
          );
        }
      }
      placements[AdPlacement.banner] = AdPlacementConfig(
        enabled: legacyBanner['enabled'] == null
            ? true
            : asBool(legacyBanner['enabled']),
        maxPerHour: asInt(legacyBanner['maxPerHour'], 12),
      );
    }

    final Map<String, dynamic> legacyInterstitial = asMap(json['interstitial']);
    if (legacyInterstitial.isNotEmpty &&
        !placements.containsKey(AdPlacement.interstitial)) {
      final int everyMinutes = asInt(legacyInterstitial['everyNMinutes'], 8);
      placements[AdPlacement.interstitial] = AdPlacementConfig(
        enabled: asBool(legacyInterstitial['enabled']),
        maxPerHour: everyMinutes <= 0 ? 6 : (60 ~/ everyMinutes).clamp(1, 60),
      );
      final String imageUrl = asStringOr(legacyInterstitial['imageUrl'], '');
      if (imageUrl.isNotEmpty) {
        ads.add(
          AdCreative(
            id: 'interstitial-1',
            kind: AdKind.image,
            mediaUrl: imageUrl,
            clickUrl: asStringOr(legacyInterstitial['clickUrl'], ''),
            title: asStringOr(legacyInterstitial['title'], ''),
            skipAfterSec: asInt(legacyInterstitial['skipAfterSeconds'], 5),
            durationSec: asInt(legacyInterstitial['durationSec'], 15),
          ),
        );
      }
    }

    return AdsConfig(
      enabled: asBool(json['enabled']),
      placements: placements,
      ads: ads,
      rotationSeconds: asInt(
        json['rotationSeconds'],
        asInt(legacyBanner['rotationSeconds'], 12),
      ),
      inPlayer: json['inPlayer'] == null
          ? asBool(legacyBanner['inPlayer'])
          : asBool(json['inPlayer']),
      inPlayerSeconds: asInt(json['inPlayerSeconds'], 0),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'enabled': enabled,
        'rotationSeconds': rotationSeconds,
        'inPlayer': inPlayer,
        'inPlayerSeconds': inPlayerSeconds,
        'placements': <String, dynamic>{
          for (final AdPlacement placement in AdPlacement.values)
            placement.id: this.placement(placement).toJson(),
        },
        'ads': ads.map((AdCreative ad) => ad.toJson()).toList(),
      };
}
