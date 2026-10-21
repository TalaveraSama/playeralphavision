import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/core/ads/ad_engine.dart';
import 'package:xtream_player/core/config/ads_config.dart';

/// El motor de anuncios es una función pura: aquí se comprueban los topes por
/// hora, el límite diario por anuncio, los pesos, la segmentación por
/// categoría/palabra clave/hora y la migración del formato antiguo.
void main() {
  AdsConfig buildConfig({
    bool enabled = true,
    int bannerMaxPerHour = 12,
    List<AdCreative> ads = const <AdCreative>[],
  }) {
    return AdsConfig(
      enabled: enabled,
      rotationSeconds: 12,
      placements: <AdPlacement, AdPlacementConfig>{
        AdPlacement.banner: AdPlacementConfig(
          enabled: true,
          maxPerHour: bannerMaxPerHour,
        ),
        AdPlacement.interstitial:
            const AdPlacementConfig(enabled: true, maxPerHour: 3),
      },
      ads: ads,
    );
  }

  AdContext context({
    AdPlacement placement = AdPlacement.banner,
    AdMediaType? mediaType,
    String? category,
    String? title,
    int hour = 12,
  }) {
    return AdContext(
      placement: placement,
      now: DateTime(2026, 1, 15, hour, 30),
      mediaType: mediaType,
      categoryName: category,
      title: title,
    );
  }

  test('el formato antiguo se migra al nuevo', () {
    final AdsConfig config = AdsConfig.fromJson(<String, dynamic>{
      'enabled': true,
      'banner': <String, dynamic>{
        'enabled': true,
        'rotationSeconds': 20,
        'inPlayer': true,
        'creatives': <dynamic>[
          <String, dynamic>{'imageUrl': 'https://x/banner.png', 'clickUrl': 'https://x'},
        ],
      },
      'interstitial': <String, dynamic>{
        'enabled': true,
        'imageUrl': 'https://x/full.png',
        'everyNMinutes': 10,
        'skipAfterSeconds': 4,
      },
    });

    expect(config.enabled, isTrue);
    expect(config.rotationSeconds, 20);
    expect(config.inPlayer, isTrue);
    expect(config.usableAds.length, 2);
    expect(config.placement(AdPlacement.banner).enabled, isTrue);
    expect(config.placement(AdPlacement.interstitial).enabled, isTrue);
    // 60 / 10 minutos = 6 impresiones por hora.
    expect(config.placement(AdPlacement.interstitial).maxPerHour, 6);
    final AdCreative interstitial =
        config.usableAds.firstWhere((AdCreative ad) => ad.id == 'interstitial-1');
    expect(interstitial.skipAfterSec, 4);
  });

  test('sin anuncios activos no se elige nada', () {
    final AdsConfig config = buildConfig(enabled: false);
    expect(pickAd(config, context(), const AdCounters()), isNull);
  });

  test('respeta el tope por hora del emplazamiento', () {
    final AdsConfig config = buildConfig(
      bannerMaxPerHour: 2,
      ads: const <AdCreative>[
        AdCreative(id: 'a', mediaUrl: 'https://x/a.png'),
      ],
    );
    final AdContext ctx = context();
    AdCounters counters = emptyAdCounters(ctx.now);

    for (int i = 0; i < 2; i++) {
      final AdCreative? ad = pickAd(config, ctx, counters);
      expect(ad, isNotNull);
      counters = recordAdImpression(counters, ad!, ctx);
    }
    expect(pickAd(config, ctx, counters), isNull);
  });

  test('respeta el límite diario por anuncio', () {
    final AdsConfig config = buildConfig(
      ads: const <AdCreative>[
        AdCreative(
          id: 'promo',
          mediaUrl: 'https://x/a.png',
          frequencyCapPerDay: 1,
        ),
      ],
    );
    final AdContext ctx = context();
    final AdCounters counters = recordAdImpression(
      emptyAdCounters(ctx.now),
      config.usableAds.first,
      ctx,
    );
    expect(pickAd(config, ctx, counters), isNull);
  });

  test('los contadores se reinician al cambiar de hora y de día', () {
    final DateTime morning = DateTime(2026, 1, 15, 9);
    final DateTime afternoon = DateTime(2026, 1, 15, 15);
    final DateTime nextDay = DateTime(2026, 1, 16, 15);

    final AdContext ctx = AdContext(placement: AdPlacement.banner, now: morning);
    final AdsConfig config = buildConfig(
      bannerMaxPerHour: 1,
      ads: const <AdCreative>[
        AdCreative(id: 'a', mediaUrl: 'https://x/a.png'),
      ],
    );

    AdCounters counters = recordAdImpression(
      emptyAdCounters(morning),
      config.usableAds.first,
      ctx,
    );
    // La misma hora sigue topada.
    expect(
      pickAd(
        config,
        AdContext(placement: AdPlacement.banner, now: morning),
        counters,
      ),
      isNull,
    );
    // A la hora siguiente vuelve a estar disponible.
    expect(
      pickAd(
        config,
        AdContext(placement: AdPlacement.banner, now: afternoon),
        counters,
      ),
      isNotNull,
    );
    // Y al día siguiente también.
    expect(
      pickAd(
        config,
        AdContext(placement: AdPlacement.banner, now: nextDay),
        counters,
      ),
      isNotNull,
    );
  });

  test('segmenta por tipo de contenido', () {
    final AdsConfig config = buildConfig(
      ads: const <AdCreative>[
        AdCreative(
          id: 'solo-vod',
          mediaUrl: 'https://x/a.png',
          mediaTypes: <AdMediaType>[AdMediaType.vod],
        ),
      ],
    );

    expect(pickAd(config, context(mediaType: AdMediaType.vod), const AdCounters()),
        isNotNull);
    expect(
      pickAd(config, context(mediaType: AdMediaType.live), const AdCounters()),
      isNull,
    );
    // Un contexto sin tipo (por ejemplo la cabecera) tampoco coincide.
    expect(pickAd(config, context(), const AdCounters()), isNull);
  });

  test('segmenta por categoría y palabra clave sin acentos ni mayúsculas', () {
    final AdsConfig config = buildConfig(
      ads: const <AdCreative>[
        AdCreative(
          id: 'deportes',
          mediaUrl: 'https://x/a.png',
          categories: <String>['Deportes'],
          keywords: <String>['futbol'],
        ),
      ],
    );

    // "futbol" debe encontrar "Fútbol" y la categoría sin acentos.
    expect(
      pickAd(
        config,
        context(category: 'FÚTBOL Y DEPORTES', title: 'Fútbol en vivo'),
        const AdCounters(),
      ),
      isNotNull,
    );
    expect(
      pickAd(config, context(category: 'Cine', title: 'Una película'),
          const AdCounters()),
      isNull,
    );
  });

  test('la franja horaria admite cruzar la medianoche', () {
    final AdsConfig config = buildConfig(
      ads: const <AdCreative>[
        AdCreative(
          id: 'noche',
          mediaUrl: 'https://x/a.png',
          hoursFrom: 22,
          hoursTo: 2,
        ),
      ],
    );

    expect(pickAd(config, context(hour: 23), const AdCounters()), isNotNull);
    expect(pickAd(config, context(hour: 1), const AdCounters()), isNotNull);
    expect(pickAd(config, context(hour: 12), const AdCounters()), isNull);
  });

  test('reparte por pesos', () {
    const AdCreative ligero =
        AdCreative(id: 'ligero', mediaUrl: 'https://x/a.png', weight: 1);
    const AdCreative pesado =
        AdCreative(id: 'pesado', mediaUrl: 'https://x/b.png', weight: 9);
    final AdsConfig config = buildConfig(ads: <AdCreative>[ligero, pesado]);
    final AdContext ctx = context();

    // Con azar 0 siempre gana el primero; con 0.99, el de más peso.
    expect(pickAd(config, ctx, const AdCounters(), random: () => 0)?.id, 'ligero');
    expect(
      pickAd(config, ctx, const AdCounters(), random: () => 0.99)?.id,
      'pesado',
    );
  });

  test('un anuncio de solo texto es válido; uno vacío no', () {
    const AdCreative texto = AdCreative(
      id: 'aviso',
      kind: AdKind.message,
      text: 'Bienvenido',
    );
    const AdCreative vacio = AdCreative(id: 'vacio');
    expect(texto.isUsable, isTrue);
    expect(vacio.isUsable, isFalse);
  });
}
