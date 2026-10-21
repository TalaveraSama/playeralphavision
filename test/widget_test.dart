import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xtream_player/app.dart';
import 'package:xtream_player/core/config/config_controller.dart';
import 'package:xtream_player/core/models/xtream_credentials.dart';
import 'package:xtream_player/core/state/app_state.dart';
import 'package:xtream_player/core/storage/prefs_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('normaliza la dirección del servidor escrita por el usuario', () {
    const XtreamCredentials credentials = XtreamCredentials(
      server: 'midominio.com:8080/',
      username: 'usuario',
      password: 'clave',
    );

    expect(credentials.baseUri.scheme, 'http');
    expect(credentials.baseUri.host, 'midominio.com');
    expect(credentials.baseUri.port, 8080);
    expect(credentials.baseUri.path, '');
  });

  test('elimina player_api.php y conserva https', () {
    const XtreamCredentials credentials = XtreamCredentials(
      server: 'https://panel.example.com/player_api.php',
      username: 'usuario',
      password: 'clave',
    );

    expect(credentials.baseUri.toString(), 'https://panel.example.com');
  });

  test('rechaza direcciones vacías', () {
    const XtreamCredentials credentials = XtreamCredentials(
      server: '   ',
      username: 'usuario',
      password: 'clave',
    );

    expect(() => credentials.baseUri, throwsFormatException);
  });

  testWidgets('sin sesión guardada se muestra la pantalla de acceso',
      (WidgetTester tester) async {
    final PrefsStore store = await PrefsStore.create();
    // Marca conocida: la prueba no depende del config.json que se edite en el
    // panel de administración.
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
            <String, dynamic>{'id': 'theme1', 'name': 'Netflix', 'layout': 'rows'},
          ],
        },
        'xtream': <String, dynamic>{'server': ''},
      },
    );
    await config.load();

    final AppState app = AppState(store, config);
    await app.restore();

    await tester.pumpWidget(
      XtreamPlayerApp(appState: app, config: config),
    );
    await tester.pump();

    expect(find.text('Xtream Player'), findsOneWidget);
    expect(find.text('Servidor'), findsOneWidget);
    expect(find.text('Usuario'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
  });

  testWidgets('con el servidor grabado el login solo pide usuario y contraseña',
      (WidgetTester tester) async {
    final PrefsStore store = await PrefsStore.create();

    // Esto es exactamente lo que el panel de administración escribe en
    // assets/config.json antes de compilar el APK de marca blanca.
    final ConfigController config = ConfigController(
      store: store,
      bundledJson: <String, dynamic>{
        'branding': <String, dynamic>{
          'appName': 'Mi Tele',
          'loginTitle': 'Bienvenido',
          'hideServerField': true,
        },
        'xtream': <String, dynamic>{'server': 'http://panel.grabado.com:8080'},
        'theme': <String, dynamic>{
          'active': 'theme1',
          'available': <dynamic>[
            <String, dynamic>{'id': 'theme1', 'name': 'Netflix', 'layout': 'rows'},
          ],
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

    // La marca se aplica y la dirección no se muestra en ningún sitio.
    expect(find.text('Mi Tele'), findsOneWidget);
    expect(find.text('Bienvenido'), findsOneWidget);
    expect(find.text('Servidor'), findsNothing);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('Usuario'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
  });
}
