import '../config/ads_config.dart';

/// Contexto en el que se va a mostrar un anuncio.
class AdContext {
  const AdContext({
    required this.placement,
    required this.now,
    this.mediaType,
    this.categoryName,
    this.title,
  });

  final AdPlacement placement;
  final DateTime now;

  /// Tipo de contenido que se está viendo (para la segmentación).
  final AdMediaType? mediaType;
  final String? categoryName;
  final String? title;
}

/// Contadores de impresiones por día y por hora en este dispositivo.
class AdCounters {
  const AdCounters({
    this.dailyKey = '',
    this.daily = const <String, int>{},
    this.hourlyKey = '',
    this.hourly = const <String, int>{},
  });

  final String dailyKey;
  final Map<String, int> daily;
  final String hourlyKey;
  final Map<String, int> hourly;

  factory AdCounters.fromJson(Map<String, dynamic> json) {
    Map<String, int> read(dynamic value) {
      final Map<String, int> result = <String, int>{};
      if (value is Map) {
        value.forEach((dynamic key, dynamic count) {
          final int? parsed = int.tryParse(count?.toString() ?? '');
          if (parsed != null) result[key.toString()] = parsed;
        });
      }
      return result;
    }

    return AdCounters(
      dailyKey: json['dailyKey']?.toString() ?? '',
      daily: read(json['daily']),
      hourlyKey: json['hourlyKey']?.toString() ?? '',
      hourly: read(json['hourly']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'dailyKey': dailyKey,
        'daily': daily,
        'hourlyKey': hourlyKey,
        'hourly': hourly,
      };
}

String adDayKey(DateTime now) {
  final String month = now.month.toString().padLeft(2, '0');
  final String day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}

String adHourKey(DateTime now) =>
    '${adDayKey(now)}T${now.hour.toString().padLeft(2, '0')}';

AdCounters emptyAdCounters(DateTime now) => AdCounters(
      dailyKey: adDayKey(now),
      hourlyKey: adHourKey(now),
    );

/// Descarta los contadores de un día u hora anteriores.
AdCounters currentAdCounters(AdCounters? stored, DateTime now) {
  final AdCounters fresh = emptyAdCounters(now);
  if (stored == null) return fresh;
  return AdCounters(
    dailyKey: fresh.dailyKey,
    daily: stored.dailyKey == fresh.dailyKey
        ? Map<String, int>.from(stored.daily)
        : <String, int>{},
    hourlyKey: fresh.hourlyKey,
    hourly: stored.hourlyKey == fresh.hourlyKey
        ? Map<String, int>.from(stored.hourly)
        : <String, int>{},
  );
}

int dailyAdCount(AdCounters counters, String adId) =>
    counters.daily['ad:$adId'] ?? 0;

int hourlyPlacementCount(AdCounters counters, AdPlacement placement) =>
    counters.hourly['placement:${placement.id}'] ?? 0;

/// Devuelve los contadores con la impresión registrada.
AdCounters recordAdImpression(
  AdCounters counters,
  AdCreative ad,
  AdContext context,
) {
  final AdCounters fresh = currentAdCounters(counters, context.now);
  final String adKey = 'ad:${ad.id}';
  final String placementKey = 'placement:${context.placement.id}';
  return AdCounters(
    dailyKey: fresh.dailyKey,
    daily: <String, int>{
      ...fresh.daily,
      adKey: (fresh.daily[adKey] ?? 0) + 1,
    },
    hourlyKey: fresh.hourlyKey,
    hourly: <String, int>{
      ...fresh.hourly,
      placementKey: (fresh.hourly[placementKey] ?? 0) + 1,
    },
  );
}

/// ¿La hora actual cae dentro de la franja? (admite franjas que cruzan
/// medianoche, por ejemplo 22 → 02).
bool withinAdHours(int? from, int? to, int hour) {
  if (from == null || to == null) return true;
  return from <= to ? hour >= from && hour <= to : hour >= from || hour <= to;
}

/// Quita acentos y mayúsculas para comparar texto.
String foldAdText(String value) {
  const Map<String, String> replacements = <String, String>{
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
    'ñ': 'n', 'ç': 'c',
  };
  final StringBuffer buffer = StringBuffer();
  for (final int rune in value.toLowerCase().runes) {
    final String char = String.fromCharCode(rune);
    buffer.write(replacements[char] ?? char);
  }
  return buffer.toString();
}

bool _matchesSubstring(String? value, List<String> targets) {
  if (targets.isEmpty) return true;
  if (value == null || value.isEmpty) return false;
  final String haystack = foldAdText(value);
  return targets.any((String target) => haystack.contains(foldAdText(target)));
}

/// ¿Este anuncio encaja con el contexto actual?
bool isAdEligible(AdCreative ad, AdContext context) {
  if (!ad.isUsable) return false;

  if (ad.mediaTypes.isNotEmpty) {
    final AdMediaType? type = context.mediaType;
    if (type == null || !ad.mediaTypes.contains(type)) return false;
  }
  if (!_matchesSubstring(context.categoryName, ad.categories)) return false;
  if (ad.keywords.isNotEmpty) {
    final String haystack =
        '${context.title ?? ''} ${context.categoryName ?? ''}';
    if (!_matchesSubstring(haystack, ad.keywords)) return false;
  }
  return withinAdHours(ad.hoursFrom, ad.hoursTo, context.now.hour);
}

/// Elige un anuncio para el emplazamiento, o `null` si no toca mostrarlo.
///
/// Es una función pura: recibe los contadores y la fuente de azar, así que se
/// puede probar sin interfaz.
AdCreative? pickAd(
  AdsConfig config,
  AdContext context,
  AdCounters counters, {
  double Function()? random,
}) {
  if (!config.enabled) return null;

  final AdPlacementConfig placement = config.placement(context.placement);
  if (!placement.enabled || placement.maxPerHour <= 0) return null;

  final AdCounters fresh = currentAdCounters(counters, context.now);
  if (hourlyPlacementCount(fresh, context.placement) >= placement.maxPerHour) {
    return null;
  }

  final List<AdCreative> eligible = config.usableAds.where((AdCreative ad) {
    if (!isAdEligible(ad, context)) return false;
    final int? cap = ad.frequencyCapPerDay;
    return cap == null || dailyAdCount(fresh, ad.id) < cap;
  }).toList();

  if (eligible.isEmpty) return null;

  final double Function() rng = random ?? _defaultRandom;
  final int totalWeight = eligible.fold<int>(
    0,
    (int sum, AdCreative ad) => sum + ad.weight,
  );
  double point = rng() * totalWeight;
  for (final AdCreative ad in eligible) {
    point -= ad.weight;
    if (point < 0) return ad;
  }
  return eligible.last;
}

/// Anuncios elegibles para rotar en la franja (sin contar impresiones).
List<AdCreative> pickAdRotation(
  AdsConfig config,
  AdContext context,
  AdCounters counters, {
  int limit = 4,
}) {
  if (!config.enabled) return const <AdCreative>[];
  final AdPlacementConfig placement = config.placement(context.placement);
  if (!placement.enabled || placement.maxPerHour <= 0) {
    return const <AdCreative>[];
  }
  final AdCounters fresh = currentAdCounters(counters, context.now);
  if (hourlyPlacementCount(fresh, context.placement) >= placement.maxPerHour) {
    return const <AdCreative>[];
  }
  return config.usableAds
      .where((AdCreative ad) => isAdEligible(ad, context))
      .take(limit)
      .toList();
}

double _defaultRandom() {
  // Suficiente para repartir por pesos; no necesita ser criptográfico.
  return DateTime.now().microsecondsSinceEpoch % 1000000 / 1000000;
}
