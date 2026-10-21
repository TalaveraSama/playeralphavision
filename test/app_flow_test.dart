import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xtream_player/app.dart';
import 'package:xtream_player/core/config/config_controller.dart';
import 'package:xtream_player/core/state/app_state.dart';
import 'package:xtream_player/core/storage/prefs_store.dart';

/// Prueba de extremo a extremo de la interfaz contra un panel Xtream simulado:
/// rellena el formulario de acceso, entra y comprueba que el catálogo del panel
/// termina pintándose en pantalla.
void main() {
  late HttpServer server;
  late String serverUrl;

  setUp(() async {
    // El binding de pruebas bloquea la red por defecto; esta prueba levanta un
    // panel real en localhost y necesita salir a la red.
    HttpOverrides.global = null;
    SharedPreferences.setMockInitialValues(<String, Object>{});
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    serverUrl = 'http://127.0.0.1:${server.port}';

    server.listen((HttpRequest request) async {
      final String action = request.uri.queryParameters['action'] ?? 'auth';
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(_payload(action)));
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  /// La prueba corre con un reloj falso, así que hay que alternar la red real
  /// ([WidgetTester.runAsync]) con repintados para que las respuestas del panel
  /// se propaguen hasta la interfaz.
  Future<void> settle(WidgetTester tester, {int rounds = 10, int ms = 60}) async {
    for (int i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(Duration(milliseconds: ms)),
      );
      await tester.pump();
    }
  }

  testWidgets('acceso al panel, Tema 1 (filas) y catálogo en pantalla',
      (WidgetTester tester) async {
    final PrefsStore store = await PrefsStore.create();
    // Marca conocida: la prueba no depende del config.json del panel.
    final ConfigController config = ConfigController(
      store: store,
      bundledJson: <String, dynamic>{
        'branding': <String, dynamic>{
          'appName': 'Xtream Player',
          'hideServerField': true,
        },
        'theme': <String, dynamic>{
          'active': 'theme1',
          'available': <dynamic>[
            <String, dynamic>{
              'id': 'theme1',
              'name': 'Netflix',
              'layout': 'rows',
              'primaryColor': '#E50914',
            },
            <String, dynamic>{
              'id': 'theme2',
              'name': 'Aurora',
              'layout': 'grid',
              'primaryColor': '#2F6BFF',
            },
          ],
        },
        // Sin servidor grabado: la prueba escribe la dirección en el formulario.
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
      },
    );
    await config.load();

    final AppState app = AppState(store, config);
    await app.restore();

    await tester.pumpWidget(
      XtreamPlayerApp(appState: app, config: config),
    );
    await tester.pump();

    // 1) Formulario de acceso. La configuración por defecto no trae servidor,
    //    así que el campo se muestra; el resto de la marca viene del asset.
    expect(find.text('Xtream Player'), findsOneWidget);
    expect(config.theme.id, 'theme1');
    expect(config.theme.isRows, isTrue);

    await tester.enterText(find.byType(TextFormField).at(0), serverUrl);
    await tester.enterText(find.byType(TextFormField).at(1), 'demo');
    await tester.enterText(find.byType(TextFormField).at(2), 'demo');

    await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
    await tester.pump();
    expect(app.loggingIn, isTrue);

    // 2) El panel responde y aparece la aplicación.
    await settle(tester, ms: 900);
    expect(app.isLoggedIn, isTrue, reason: 'lastError=${app.lastError}');
    expect(find.text('Películas'), findsWidgets);
    expect(find.text('Favoritos'), findsWidgets);

    // 3) El catálogo en vivo se carga con el Tema 1: cabecera destacada y
    //    filas horizontales, así que el canal aparece en las dos.
    await settle(tester, ms: 900);
    expect(find.text('Canal 1 HD'), findsWidgets);
    expect(find.text('Deportes'), findsOneWidget);
    expect(find.text('EN DIRECTO'), findsOneWidget);

    // 4) Cambiar a theme2 (rejilla) mantiene los datos y muestra las
    //    categorías como chips.
    await config.setTheme('theme2');
    await tester.pump();
    expect(config.theme.isRows, isFalse);
    await settle(tester, ms: 900);
    expect(find.text('Todas'), findsOneWidget);
    expect(find.text('Deportes'), findsWidgets);
    expect(find.text('1 canal'), findsOneWidget);

    // 5) La pestaña de películas también trae datos.
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Películas'),
      ),
    );
    await settle(tester, ms: 900);
    expect(find.text('Película de prueba'), findsOneWidget);

    // 6) La sesión queda guardada en el dispositivo.
    expect(store.credentials?.server, serverUrl);

    // 7) Al cerrar sesión se liberan las conexiones HTTP abiertas.
    await tester.runAsync(() => app.logout());
    await tester.pump();
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}

dynamic _payload(String action) {
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
              '${DateTime.now().add(const Duration(days: 10)).millisecondsSinceEpoch ~/ 1000}',
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
        <String, dynamic>{
          'category_id': '1',
          'category_name': 'Deportes',
          'parent_id': 0,
        },
        <String, dynamic>{
          'category_id': '2',
          'category_name': 'Cine',
          'parent_id': 0,
        },
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
        },
      ];
    default:
      return <String, dynamic>{};
  }
}
