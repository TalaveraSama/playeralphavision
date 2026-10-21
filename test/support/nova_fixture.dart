import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xtream_player/app.dart';
import 'package:xtream_player/core/config/config_controller.dart';
import 'package:xtream_player/core/state/app_state.dart';
import 'package:xtream_player/core/storage/prefs_store.dart';

/// Utilidades compartidas por las pruebas del diseño NOVA y por la herramienta
/// de capturas (`tool/nova_preview.dart`): un panel Xtream simulado y una marca
/// NOVA en memoria.
Map<String, dynamic> novaConfig() {
  return <String, dynamic>{
    'branding': <String, dynamic>{
      'appName': 'NOVA',
      'primaryColor': '#2FE0C0',
      'hideServerField': true,
    },
    'theme': <String, dynamic>{
      'active': 'nova',
      'available': <dynamic>[
        <String, dynamic>{
          'id': 'nova',
          'name': 'NOVA',
          'layout': 'nova',
          'primaryColor': '#2FE0C0',
          'backgroundColor': '#0A0F1A',
          'surfaceColor': '#141D2E',
          'textColor': '#FFFFFF',
          'cardRadius': 14,
        },
      ],
    },
    // Sin servidor grabado: las pruebas escriben la dirección en el formulario.
    'xtream': <String, dynamic>{'server': ''},
    'ads': <String, dynamic>{'enabled': false},
    'update': <String, dynamic>{'enabled': false},
    'features': <String, dynamic>{
      'search': true,
      'favorites': true,
      'epg': true,
      'allowThemeSwitch': true,
      'showAccountInfo': true,
    },
  };
}

/// Preferencias iniciales con una entrada a medio ver (fila «Continuar viendo»).
Map<String, Object> novaInitialPrefs() {
  return <String, Object>{
    'xtream.resume': <String>[
      jsonEncode(<String, dynamic>{
        'key': 'movie:201',
        'title': 'Película de prueba',
        'subtitle': 'T1 · E4',
        'positionSec': 600,
        'durationSec': 3600,
        'updatedAt': 1700000000,
        'item': <String, dynamic>{
          'kind': 'movie',
          'id': '201',
          'name': 'Película de prueba',
        },
      }),
      jsonEncode(<String, dynamic>{
        'key': 'series:301',
        'title': 'Serie de prueba',
        'subtitle': 'T1 · E1',
        'positionSec': 900,
        'durationSec': 3120,
        'updatedAt': 1700000500,
        'item': <String, dynamic>{
          'kind': 'series',
          'id': '301',
          'name': 'Serie de prueba',
        },
      }),
    ],
  };
}

Future<HttpServer> startFakeXtream() async {
  final HttpServer server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((HttpRequest request) async {
    final String action = request.uri.queryParameters['action'] ?? 'auth';
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(fakeXtreamPayload(action)));
    await request.response.close();
  });
  return server;
}

/// Avanza el reloj de la prueba dejando que respondan las peticiones de red.
Future<void> settleFrames(
  WidgetTester tester, {
  int rounds = 10,
  int ms = 90,
}) async {
  for (int i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));
    await tester.pump();
  }
}

/// Monta la app con la marca NOVA y entra con el panel simulado.
Future<({ConfigController config, AppState app})> pumpNovaApp(
  WidgetTester tester, {
  required String serverUrl,
  Map<String, Object>? prefs,
}) async {
  SharedPreferences.setMockInitialValues(prefs ?? novaInitialPrefs());
  final PrefsStore store = await PrefsStore.create();
  final ConfigController config = ConfigController(
    store: store,
    bundledJson: novaConfig(),
  );
  await config.load();
  final AppState app = AppState(store, config);
  await app.restore();

  await tester.pumpWidget(XtreamPlayerApp(appState: app, config: config));
  await tester.pump();

  await tester.enterText(find.byType(TextFormField).at(0), serverUrl);
  await tester.enterText(find.byType(TextFormField).at(1), 'demo');
  await tester.enterText(find.byType(TextFormField).at(2), 'demo');
  await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
  await tester.pump();
  await settleFrames(tester, ms: 700);

  return (config: config, app: app);
}

dynamic fakeXtreamPayload(String action) {
  switch (action) {
    case 'auth':
      return <String, dynamic>{
        'user_info': <String, dynamic>{
          'username': 'demo',
          'auth': 1,
          'status': 'Active',
          'is_trial': '0',
          'active_cons': '1',
          'max_connections': '1',
          'exp_date':
              '${DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch ~/ 1000}',
          'allowed_output_formats': <String>['m3u8', 'ts'],
        },
        'server_info': <String, dynamic>{
          'url': '127.0.0.1',
          'port': '8080',
          'server_protocol': 'http',
          'timezone': 'Europe/Madrid',
        },
      };
    case 'get_live_categories':
      return <dynamic>[
        <String, dynamic>{'category_id': '1', 'category_name': 'Deportes'},
        <String, dynamic>{'category_id': '2', 'category_name': 'Noticias'},
      ];
    case 'get_live_streams':
      return <dynamic>[
        <String, dynamic>{
          'num': 1,
          'name': 'Canal 1 HD',
          'stream_id': 101,
          'category_id': '1',
          'tv_archive': 1,
        },
        <String, dynamic>{
          'num': 2,
          'name': 'Canal 2 HD',
          'stream_id': 102,
          'category_id': '2',
        },
      ];
    case 'get_vod_categories':
      return <dynamic>[
        <String, dynamic>{'category_id': '10', 'category_name': 'Estrenos'},
      ];
    case 'get_vod_streams':
      return <dynamic>[
        <String, dynamic>{
          'num': 1,
          'name': 'Película de prueba',
          'stream_id': 201,
          'category_id': '10',
          'container_extension': 'mp4',
          'rating': '7.5',
          'plot': 'Sinopsis de la película de prueba en dos líneas.',
          'genre': 'Drama',
          'cast': 'Ana Ejemplo, Luis Ejemplo',
        },
      ];
    case 'get_series_categories':
      return <dynamic>[
        <String, dynamic>{'category_id': '20', 'category_name': 'Dramas'},
      ];
    case 'get_series':
      return <dynamic>[
        <String, dynamic>{
          'num': 1,
          'name': 'Serie de prueba',
          'series_id': 301,
          'category_id': '20',
          'rating': '8.1',
          'cast': 'Ana Ejemplo, Luis Ejemplo',
          'genre': 'Drama',
          'plot': 'Sinopsis completa de la serie en tres o cuatro líneas, '
              'con el planteamiento, el tono y el gancho principal.',
        },
      ];
    case 'get_series_info':
      return <String, dynamic>{
        'info': <String, dynamic>{
          'name': 'Serie de prueba',
          'genre': 'Drama',
          'audio': 'Español',
          'subtitles': 'Español',
          'director': 'Directora Ejemplo',
          'cast': 'Ana Ejemplo, Luis Ejemplo, Marta Ejemplo, Iván Ejemplo',
          'plot': 'Sinopsis completa de la serie en tres o cuatro líneas, '
              'con el planteamiento, el tono y el gancho principal.',
        },
        'seasons': <dynamic>[
          <String, dynamic>{'season_number': 1, 'name': 'Temporada 1'},
        ],
        'episodes': <String, dynamic>{
          '1': <dynamic>[
            <String, dynamic>{
              'id': '9001',
              'episode_num': 1,
              'title': 'Episodio de prueba',
              'container_extension': 'mkv',
              'info': <String, dynamic>{'duration': '52', 'plot': 'Una línea.'},
            },
            <String, dynamic>{
              'id': '9002',
              'episode_num': 2,
              'title': 'Segundo episodio',
              'container_extension': 'mkv',
              'info': <String, dynamic>{
                'duration': '48',
                'plot': 'Otra línea de descripción.',
              },
            },
          ],
        },
      };
    default:
      return <String, dynamic>{};
  }
}
