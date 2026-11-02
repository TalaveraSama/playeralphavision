import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/core/api/xtream_api.dart';
import 'package:xtream_player/core/api/xtream_client.dart';
import 'package:xtream_player/core/models/media_item.dart';
import 'package:xtream_player/core/models/series_detail.dart';
import 'package:xtream_player/core/models/stream_format.dart';
import 'package:xtream_player/core/models/xtream_account.dart';

/// Estas pruebas simulan respuestas HTTPS sin conexiones reales y comprueban
/// que el cliente entiende las respuestas reales de `player_api.php`:
/// autenticación, catálogos, ficha de película, series y EPG en Base64.
void main() {
  late XtreamApi api;
  late dynamic Function(String action) responder;
  final List<String> requests = <String>[];

  String b64(String value) => base64.encode(utf8.encode(value));

  XtreamClient clientFor() => XtreamClient(api: api, httpClient: MockClient((request) async {
    final action = request.url.queryParameters['action'] ?? 'auth';
    requests.add(action);
    return http.Response(jsonEncode(responder(action)), 200, headers: {'content-type': 'application/json'});
  }));
  setUp(() {
    requests.clear();
    responder = (String action) => <String, dynamic>{};
    api = XtreamApi(baseUri: Uri.parse('https://panel.example:443'), username: 'demo', password: 'demo');
  });

  test('autentica y lee la cuenta del abonado', () async {
    responder = (String action) => <String, dynamic>{
          'user_info': <String, dynamic>{
            'username': 'demo',
            'auth': 1,
            'status': 'Active',
            'is_trial': '0',
            'active_cons': '1',
            'max_connections': '2',
            'exp_date': '${DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch ~/ 1000}',
            'allowed_output_formats': <String>['m3u8', 'ts'],
          },
          'server_info': <String, dynamic>{
            'url': '127.0.0.1',
            'port': '443',
            'server_protocol': 'http',
            'timezone': 'Europe/Madrid',
          },
        };

    final XtreamClient client = clientFor();
    final XtreamAccount account = await client.authenticate();

    expect(account.isActive, isTrue);
    expect(account.username, 'demo');
    expect(account.maxConnections, 2);
    expect(account.allowedFormats, <String>['m3u8', 'ts']);
    expect(account.daysRemaining, greaterThan(25));
    expect(account.serverInfo.timezone, 'Europe/Madrid');
    client.dispose();
  });

  test('detecta credenciales rechazadas', () async {
    responder = (String action) => <String, dynamic>{
          'user_info': <String, dynamic>{'auth': 0, 'status': 'Disabled'},
        };

    final XtreamClient client = clientFor();
    final XtreamAccount account = await client.authenticate();

    expect(account.isActive, isFalse);
    expect(account.statusText, 'Disabled');
    client.dispose();
  });

  test('lee categorías y canales en directo', () async {
    responder = (String action) {
      switch (action) {
        case 'get_live_categories':
          return <dynamic>[
            <String, dynamic>{
              'category_id': '1',
              'category_name': 'Deportes',
              'parent_id': 0,
            },
          ];
        case 'get_live_streams':
          return <dynamic>[
            <String, dynamic>{
              'num': 1,
              'name': 'Canal 1 HD',
              'stream_id': 101,
              'stream_icon': 'http://logo/1.png',
              'category_id': '1',
              'epg_channel_id': 'canal1',
              'tv_archive': 1,
              'added': '1700000000',
            },
          ];
        default:
          return <String, dynamic>{};
      }
    };

    final XtreamClient client = clientFor();
    final categories = await client.categories(MediaKind.live);
    final items = await client.items(MediaKind.live, categoryId: '1');

    expect(categories.single.name, 'Deportes');
    expect(items.single.id, '101');
    expect(items.single.name, 'Canal 1 HD');
    expect(items.single.tvArchive, 1);
    expect(items.single.epgChannelId, 'canal1');

    expect(
      requests,
      containsAll(<String>['get_live_categories', 'get_live_streams']),
    );
    client.dispose();
  });

  test('construye las URLs de streaming y de la lista M3U', () {
    final String base = 'https://panel.example';

    expect(api.liveUrl('101'), '$base/live/demo/demo/101.m3u8');
    expect(
      api.liveUrl('101', format: StreamFormat.mpegTs),
      '$base/live/demo/demo/101.ts',
    );
    expect(api.movieUrl('202', extension: 'mkv'), '$base/movie/demo/demo/202.mkv');
    expect(api.seriesUrl('303', extension: 'mp4'), '$base/series/demo/demo/303.mp4');
    expect(
      api.timeshiftUrl(
        streamId: '101',
        durationMinutes: 60,
        start: DateTime(2024, 5, 1, 20, 30),
      ),
      '$base/timeshift/demo/demo/60/2024-05-01:20-30/101.ts',
    );
    expect(api.playlistUri.toString(), contains('get.php'));
    expect(api.playlistUri.queryParameters['type'], 'm3u_plus');
    expect(api.playlistUri.queryParameters['username'], 'demo');
  });

  test('completa la ficha de una película con get_vod_info', () async {
    responder = (String action) => <String, dynamic>{
          'info': <String, dynamic>{
            'plot': 'Sinopsis de la película',
            'genre': 'Acción',
            'duration': '01:52:00',
            'rating': '7.5',
            'movie_image': 'http://logo/poster.jpg',
            'backdrop_path': <String>['http://logo/back.jpg'],
            'cast': 'Actor A, Actor B',
          },
          'movie_data': <String, dynamic>{
            'stream_id': 202,
            'name': 'Película de prueba',
            'container_extension': 'mkv',
            'category_id': '3',
          },
        };

    final XtreamClient client = clientFor();
    final MediaItem item = await client.vodInfo('202');

    expect(item.name, 'Película de prueba');
    expect(item.plot, 'Sinopsis de la película');
    expect(item.containerExtension, 'mkv');
    expect(item.backdrop, 'http://logo/back.jpg');
    expect(item.rating, 7.5);
    expect(item.duration, '01:52:00');
    client.dispose();
  });

  test('lee temporadas y episodios de una serie', () async {
    responder = (String action) => <String, dynamic>{
          'seasons': <dynamic>[
            <String, dynamic>{
              'season_number': 1,
              'name': 'Temporada 1',
              'cover': 'http://logo/s1.jpg',
              'episode_count': 2,
            },
          ],
          'info': <String, dynamic>{'plot': 'Una serie de prueba'},
          'episodes': <String, dynamic>{
            '1': <dynamic>[
              <String, dynamic>{
                'id': '9001',
                'episode_num': 2,
                'title': 'S01 E02 Segundo',
                'container_extension': 'mkv',
                'info': <String, dynamic>{'plot': 'Capítulo dos', 'duration': '45'},
              },
              <String, dynamic>{
                'id': '9000',
                'episode_num': 1,
                'title': 'S01 E01 Piloto',
                'container_extension': 'mkv',
              },
            ],
          },
        };

    final XtreamClient client = clientFor();
    final SeriesDetail detail = await client.seriesInfo('500');

    expect(detail.seasons.single.title, 'Temporada 1');
    expect(detail.episodes.length, 2);
    // Se ordenan por número de episodio, no como llegan.
    expect(detail.episodes.first.id, '9000');
    expect(detail.episodes.first.label, 'Piloto');
    expect(detail.episodes.last.plot, 'Capítulo dos');
    client.dispose();
  });

  test('decodifica la EPG que llega en Base64', () async {
    responder = (String action) => <String, dynamic>{
          'epg_listings': <dynamic>[
            <String, dynamic>{
              'title': b64('Noticias 20h'),
              'description': b64('Informativo diario'),
              'start_timestamp': '1700000000',
              'stop_timestamp': '1700003600',
              'now_playing': 1,
            },
          ],
        };

    final XtreamClient client = clientFor();
    final entries = await client.shortEpg('101');

    expect(entries.single.title, 'Noticias 20h');
    expect(entries.single.description, 'Informativo diario');
    expect(entries.single.nowPlaying, isTrue);
    expect(entries.single.timeRange, isNotEmpty);
    // get_short_epg debe pedirse con el id del canal.
    expect(requests.single, 'get_short_epg');
    client.dispose();
  });

  test('informa de un error legible si el servidor no es un panel', () async {
    final XtreamClient client = XtreamClient(api: api, httpClient: MockClient((_) async =>
      http.Response('<html><body>Not found</body></html>', 200)));

    await expectLater(
      client.authenticate(),
      throwsA(
        isA<XtreamException>().having(
          (XtreamException error) => error.message,
          'message',
          contains('HTML'),
        ),
      ),
    );
    client.dispose();
  });
}
