import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/core/ads/ad_engine.dart';
import 'package:xtream_player/core/config/ads_config.dart';

void main() {
  test('overlay admite mensajes, omite vídeos antes del límite y respeta topes', () {
    final now = DateTime(2026, 10, 26, 12);
    final context = AdContext(placement: AdPlacement.overlay, now: now);
    const message = AdCreative(id: 'nota', kind: AdKind.message,
        text: 'Descansa', frequencyCapPerDay: 1);
    final config = AdsConfig(enabled: true, inPlayer: true,
      placements: const <AdPlacement, AdPlacementConfig>{
        AdPlacement.overlay: AdPlacementConfig(enabled: true, maxPerHour: 2),
      }, ads: const <AdCreative>[
        AdCreative(id: 'video', kind: AdKind.video, mediaUrl: 'https://test/ad.mp4'), message,
      ]);
    expect(AdsConfig(enabled: true, placements: config.placements,
      ads: const <AdCreative>[message]).hasAnyAd, isTrue);
    final rotation = pickAdRotation(config, context, const AdCounters(),
      limit: 1, kinds: const <AdKind>{AdKind.message, AdKind.image});
    expect(rotation.map((ad) => ad.id), <String>['nota']);
    final counted = recordAdImpression(const AdCounters(), message, context);
    expect(pickAdRotation(config, context, counted,
      kinds: const <AdKind>{AdKind.message, AdKind.image}), isEmpty);
    final capped = recordAdImpression(counted, message, context);
    expect(pickAdRotation(config, context, capped), isEmpty);
  });
}
