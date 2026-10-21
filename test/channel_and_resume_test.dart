import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xtream_player/core/models/media_item.dart';
import 'package:xtream_player/core/models/playable_item.dart';
import 'package:xtream_player/core/models/resume_entry.dart';
import 'package:xtream_player/core/storage/prefs_store.dart';
import 'package:xtream_player/core/utils/channel_names.dart';

/// Mejoras portadas del panel de referencia: limpieza de nombres de canal y
/// posiciones de reproducción («continuar viendo»).
void main() {
  group('Nombres de canal', () {
    test('detecta separadores decorativos', () {
      expect(isSeparatorChannelName('-=Finland=-'), isTrue);
      expect(isSeparatorChannelName('── SPORTS ──'), isTrue);
      expect(isSeparatorChannelName('*** FI ***'), isTrue);
      expect(isSeparatorChannelName('================'), isTrue);
      // Estos son canales reales y no deben marcarse.
      expect(isSeparatorChannelName('FI: Yle TV1'), isFalse);
      expect(isSeparatorChannelName('Canal+'), isFalse);
      expect(isSeparatorChannelName('E!'), isFalse);
      expect(isSeparatorChannelName('24/7 Movies'), isFalse);
      expect(isSeparatorChannelName(''), isFalse);
    });

    test('detecta eventos en directo por la hora del principio', () {
      expect(looksLikeEventTitle('19:30 HJK Helsinki - Inter Turku'), isTrue);
      expect(looksLikeEventTitle('21.45 Real Madrid - Barça'), isTrue);
      expect(looksLikeEventTitle('La que se avecina'), isFalse);
      expect(looksLikeEventTitle('Canal 24h'), isFalse);
    });

    test('etiqueta la calidad anunciada en el nombre', () {
      expect(channelQualityTag('DAZN 1 FHD'), 'FHD');
      expect(channelQualityTag('ESPN 4K'), '4K');
      expect(channelQualityTag('Movistar LaLiga HD'), 'HD');
      expect(channelQualityTag('Canal SD'), 'SD');
      expect(channelQualityTag('Canal 24 Horas'), isNull);
    });

    test('limpia el sufijo de calidad para mostrarlo aparte', () {
      expect(cleanChannelName('DAZN 1 FHD'), 'DAZN 1');
      expect(cleanChannelName('ESPN [4K]'), 'ESPN');
      expect(cleanChannelName('Canal (HD)'), 'Canal');
      expect(cleanChannelName('Cine de siempre'), 'Cine de siempre');
    });
  });

  group('Continuar viendo', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    const MediaItem movie = MediaItem(
      kind: MediaKind.movie,
      id: '101',
      name: 'Película de prueba',
      icon: 'http://x/poster.jpg',
    );

    test('solo se ofrece lo que está a medias', () {
      const ResumeEntry recienEmpezada = ResumeEntry(
        key: 'movie:1',
        title: 'A',
        positionSec: 5,
        durationSec: 600,
      );
      const ResumeEntry aMedias = ResumeEntry(
        key: 'movie:2',
        title: 'B',
        positionSec: 300,
        durationSec: 600,
      );
      const ResumeEntry casiTerminada = ResumeEntry(
        key: 'movie:3',
        title: 'C',
        positionSec: 590,
        durationSec: 600,
      );

      expect(recienEmpezada.isResumable, isFalse);
      expect(aMedias.isResumable, isTrue);
      expect(casiTerminada.isResumable, isFalse);
      expect(aMedias.progress, closeTo(0.5, 0.001));
      expect(aMedias.timeLabel, contains('5 min'));
    });

    test('se guarda, se lee y sobrevive al cierre de la app', () async {
      final PrefsStore store = await PrefsStore.create();
      await store.saveResumeList(<ResumeEntry>[
        const ResumeEntry(
          key: 'movie:101',
          title: 'Película de prueba',
          subtitle: 'Acción',
          image: 'http://x/poster.jpg',
          item: movie,
          positionSec: 420,
          durationSec: 5400,
          updatedAt: 1700000000,
        ),
      ]);

      final PrefsStore again = await PrefsStore.create();
      final List<ResumeEntry> entries = again.readResumeList();

      expect(entries.length, 1);
      expect(entries.single.key, 'movie:101');
      expect(entries.single.positionSec, 420);
      expect(entries.single.item?.name, 'Película de prueba');
      expect(entries.single.item?.kind, MediaKind.movie);
      expect(entries.single.isResumable, isTrue);
    });

    test('un episodio de serie guarda su propia URL y la clave por URL',
        () async {
      final PrefsStore store = await PrefsStore.create();
      const PlayableItem episode = PlayableItem(
        title: 'T1E2 · El segundo',
        url: 'http://panel/series/demo/demo/9001.mkv',
        subtitle: 'Serie de prueba',
      );

      await store.saveResumeList(<ResumeEntry>[
        ResumeEntry(
          key: episode.progressKey,
          title: episode.title,
          subtitle: episode.subtitle,
          playable: episode,
          positionSec: 600,
          durationSec: 2700,
          updatedAt: 1700000001,
        ),
      ]);

      final ResumeEntry entry = (await PrefsStore.create()).readResumeList().single;
      expect(entry.key, 'url:http://panel/series/demo/demo/9001.mkv');
      expect(entry.playable?.url, episode.url);
      expect(entry.playable?.title, 'T1E2 · El segundo');
      expect(entry.isResumable, isTrue);
    });

    test('los datos corruptos no rompen la lista', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'xtream.resume': <String>['no es json', '{"key":"movie:1","positionSec":300,"durationSec":600}'],
      });
      final PrefsStore store = await PrefsStore.create();
      final List<ResumeEntry> entries = store.readResumeList();

      expect(entries.length, 1);
      expect(entries.single.key, 'movie:1');
    });

    test('las posiciones se pueden borrar', () async {
      final PrefsStore store = await PrefsStore.create();
      await store.saveResumeList(<ResumeEntry>[
        const ResumeEntry(
          key: 'movie:1',
          title: 'A',
          positionSec: 300,
          durationSec: 600,
        ),
      ]);
      expect(store.readResumeList(), isNotEmpty);
      await store.clearResumeList();
      expect(store.readResumeList(), isEmpty);
    });
  });
}
