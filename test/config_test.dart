import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xtream_player/core/app_info.dart';
import 'package:xtream_player/core/config/ads_config.dart';
import 'package:xtream_player/core/config/app_config.dart';
import 'package:xtream_player/core/config/config_controller.dart';
import 'package:xtream_player/core/storage/prefs_store.dart';

/// Pruebas de la configuración de marca blanca.
///
/// Ninguna prueba depende del `assets/config.json` real del proyecto: la marca
/// que se edite en el panel (nombre, servidor, anuncios...) no puede romper la
/// batería de pruebas. Solo hay una comprobación de que ese archivo es válido.
Map<String, dynamic> testBundle({
  String appName = 'Marca de prueba',
  String server = '',
  String remoteConfigUrl = '',
  bool updateEnabled = false,
  String latestVersion = '1.0.0',
}) {
  return <String, dynamic>{
    'schemaVersion': 1,
    'remoteConfigUrl': remoteConfigUrl,
    'branding': <String, dynamic>{
      'appName': appName,
      'primaryColor': '#E50914',
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
    'xtream': <String, dynamic>{
      'server': server,
      'userAgent': 'VLC/3.0.20 LibVLC/3.0.20',
    },
    'ads': <String, dynamic>{'enabled': false},
    'update': <String, dynamic>{
      'enabled': updateEnabled,
      'latestVersion': latestVersion,
      'minVersion': '1.0.0',
    },
    'features': <String, dynamic>{'search': true, 'favorites': true},
  };
}

http.Client jsonClient(Object payload, {int status = 200}) {
  return MockClient(
    (http.Request request) async => http.Response(
      jsonEncode(payload),
      status,
      headers: <String, String>{'content-type': 'application/json'},
    ),
  );
}

void main() {
  // Necesario para poder leer los assets del APK desde las pruebas.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppConfig', () {
    test('lee marca, temas y anuncios del JSON', () {
      final AppConfig config = AppConfig.fromJson(<String, dynamic>{
        'branding': <String, dynamic>{
          'appName': 'Mi Tele',
          'primaryColor': '#00C853',
          'loginBackgrounds': <String>['https://x/bg1.jpg'],
        },
        'theme': <String, dynamic>{
          'active': 'theme2',
          'available': <dynamic>[
            <String, dynamic>{'id': 'theme1', 'name': 'Netflix', 'layout': 'rows'},
            <String, dynamic>{'id': 'theme2', 'name': 'Aurora', 'layout': 'grid'},
          ],
        },
        'ads': <String, dynamic>{
          'enabled': true,
          'banner': <String, dynamic>{
            'creatives': <dynamic>[
              <String, dynamic>{'imageUrl': 'https://x/ad.png', 'clickUrl': 'https://x'},
              <String, dynamic>{'imageUrl': '', 'clickUrl': 'https://y'},
            ],
          },
        },
        'update': <String, dynamic>{
          'enabled': true,
          'latestVersion': '2.0.0',
          'minVersion': '1.5.0',
        },
      });

      expect(config.branding.appName, 'Mi Tele');
      expect(config.branding.primaryColor.toARGB32(), 0xFF00C853);
      expect(config.branding.loginBackgrounds.single, 'https://x/bg1.jpg');
      expect(config.theme.available.length, 2);
      expect(config.theme.resolve(null).id, 'theme2');
      expect(config.theme.resolve(null).isRows, isFalse);
      expect(config.theme.resolve('theme1').isRows, isTrue);
      // El formato antiguo (`banner.creatives`) se migra al nuevo: la
      // creatividad sin imagen no cuenta y el emplazamiento queda activo.
      expect(config.ads.usableAds.length, 1);
      expect(config.adPlacement(AdPlacement.banner).enabled, isTrue);
      expect(config.update.hasUpdate, isTrue);
      expect(config.update.isMandatory, isTrue);
    });

    test('con servidor grabado el login oculta el campo de dirección', () {
      final AppConfig withServer = AppConfig.fromJson(<String, dynamic>{
        'xtream': <String, dynamic>{'server': 'http://panel.example.com:8080'},
      });
      expect(withServer.showsServerField, isFalse);

      final AppConfig editable = AppConfig.fromJson(<String, dynamic>{
        'branding': <String, dynamic>{'hideServerField': false},
        'xtream': <String, dynamic>{'server': 'http://panel.example.com:8080'},
      });
      expect(editable.showsServerField, isTrue);

      const AppConfig empty = AppConfig();
      expect(empty.showsServerField, isTrue);
    });

    test('deepMerge respeta listas y no borra con valores nulos', () {
      final Map<String, dynamic> merged = deepMerge(
        <String, dynamic>{
          'branding': <String, dynamic>{
            'appName': 'Base',
            'tagline': 'Hola',
          },
          'theme': <String, dynamic>{
            'available': <dynamic>[
              <String, dynamic>{'id': 'theme1'},
            ],
          },
        },
        <String, dynamic>{
          'branding': <String, dynamic>{'appName': 'Remoto', 'tagline': null},
          'theme': <String, dynamic>{
            'available': <dynamic>[
              <String, dynamic>{'id': 'theme2'},
            ],
          },
        },
      );

      final AppConfig config = AppConfig.fromJson(merged);
      expect(config.branding.appName, 'Remoto');
      expect(config.branding.tagline, 'Hola');
      expect(config.theme.available.single.id, 'theme2');
    });

    test('compara versiones como un instalador', () {
      expect(isVersionNewer('1.0.1', '1.0.0'), isTrue);
      expect(isVersionNewer('1.1.0', '1.0.9'), isTrue);
      expect(isVersionNewer('2.0', '1.9.9'), isTrue);
      expect(isVersionNewer('1.0.0', '1.0.0'), isFalse);
      expect(isVersionNewer('0.9.9', '1.0.0'), isFalse);
      expect(isVersionNewer('1.0.0', '1.0'), isFalse);
      expect(isVersionNewer('1.0.10', '1.0.9'), isTrue);

      expect(versionParts(kAppVersion).length, greaterThanOrEqualTo(2));
      expect(isVersionNewer(kAppVersion, kAppVersion), isFalse);
    });

    test('serializa y vuelve a leer sin perder datos', () {
      final AppConfig original = AppConfig.fromJson(<String, dynamic>{
        'branding': <String, dynamic>{'appName': 'Ida y vuelta'},
        'theme': <String, dynamic>{
          'active': 'theme1',
          'available': <dynamic>[
            <String, dynamic>{
              'id': 'theme1',
              'name': 'Netflix',
              'layout': 'rows',
              'primaryColor': '#E50914',
            },
          ],
        },
      });
      final AppConfig restored = AppConfig.fromJson(original.toJson());

      expect(restored.branding.appName, 'Ida y vuelta');
      expect(restored.theme.resolve(null).primaryColor.toARGB32(), 0xFFE50914);
      expect(restored.theme.resolve(null).isRows, isTrue);
    });
  });

  group('ConfigController', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('carga el paquete y aplica el tema de la marca', () async {
      final PrefsStore store = await PrefsStore.create();
      final ConfigController controller = ConfigController(
        store: store,
        bundledJson: testBundle(),
      );
      await controller.load();

      expect(controller.loading, isFalse);
      expect(controller.config.branding.appName, 'Marca de prueba');
      expect(controller.config.theme.available.length, 2);
      expect(controller.theme.id, 'theme1');
      expect(controller.theme.isRows, isTrue);
      // Sin URL remota no se descarga nada.
      expect(controller.config.hasRemoteConfig, isFalse);
      expect(await controller.refreshRemote(), isFalse);
      expect(controller.remoteStatus, 'sin-url');
      controller.dispose();
    });

    test('el tema elegido por el usuario gana sobre el de la marca', () async {
      final PrefsStore store = await PrefsStore.create();
      final ConfigController controller = ConfigController(
        store: store,
        bundledJson: testBundle(),
      );
      await controller.load();

      await controller.setTheme('theme2');
      expect(controller.theme.id, 'theme2');
      expect(controller.theme.isRows, isFalse);

      // Y sobrevive a un reinicio de la app.
      final ConfigController again = ConfigController(
        store: store,
        bundledJson: testBundle(),
      );
      await again.load();
      expect(again.themeOverrideId, 'theme2');
      expect(again.theme.isRows, isFalse);

      await again.clearThemeOverride();
      expect(again.theme.id, 'theme1');

      controller.dispose();
      again.dispose();
    });

    test('la caché remota define anuncios y no puede cambiar la URL remota',
        () async {
      final PrefsStore store = await PrefsStore.create();
      await store.saveRemoteConfig(<String, dynamic>{
        'remoteConfigUrl': 'https://otro-servidor/config.json',
        'branding': <String, dynamic>{'appName': 'Marca remota'},
        'ads': <String, dynamic>{
          'enabled': true,
          'interstitial': <String, dynamic>{
            'enabled': true,
            'imageUrl': 'https://x/full.png',
            'clickUrl': 'https://x',
            'everyNMinutes': 8,
            'skipAfterSeconds': 0,
          },
          'banner': <String, dynamic>{
            'creatives': <dynamic>[
              <String, dynamic>{'imageUrl': 'https://x/banner.png'},
            ],
          },
        },
      });

      final ConfigController controller = ConfigController(
        store: store,
        bundledJson: testBundle(),
      );
      await controller.load();

      expect(controller.config.branding.appName, 'Marca remota');
      // La URL remota la manda siempre el APK, nunca la respuesta.
      expect(controller.config.remoteConfigUrl, '');
      // Los dos anuncios del formato antiguo se migran al nuevo.
      expect(controller.config.ads.usableAds.length, 2);
      expect(
        controller.config.adPlacement(AdPlacement.interstitial).enabled,
        isTrue,
      );
      expect(
        controller.config.adPlacement(AdPlacement.interstitial).maxPerHour,
        7,
      );
      controller.dispose();
    });

    test('descarga la configuración remota publicada por la marca', () async {
      final PrefsStore store = await PrefsStore.create();
      final ConfigController controller = ConfigController(
        store: store,
        bundledJson: testBundle(
          remoteConfigUrl: 'https://panel.test/config.json',
        ),
        httpClient: jsonClient(<String, dynamic>{
          'branding': <String, dynamic>{
            'appName': 'Remoto',
            'tagline': 'Desde el panel',
          },
          'ads': <String, dynamic>{
            'enabled': true,
            'interstitial': <String, dynamic>{
              'enabled': true,
              'imageUrl': 'https://x/a.png',
            },
          },
        }),
      );
      await controller.load();
      // Se espera la descarga para que la prueba sea determinista.
      await controller.refreshRemote();

      expect(controller.config.hasRemoteConfig, isTrue);
      expect(controller.remoteStatus, 'ok');
      expect(controller.config.branding.appName, 'Remoto');
      expect(controller.config.branding.tagline, 'Desde el panel');
      expect(controller.config.ads.usableAds, isNotEmpty);
      expect(
        controller.config.adPlacement(AdPlacement.interstitial).enabled,
        isTrue,
      );
      controller.dispose();
    });

    test('un servidor remoto caído no rompe la marca del paquete', () async {
      final PrefsStore store = await PrefsStore.create();
      final ConfigController controller = ConfigController(
        store: store,
        bundledJson: testBundle(
          remoteConfigUrl: 'https://panel.test/config.json',
        ),
        httpClient: jsonClient(<String, dynamic>{}, status: 500),
      );
      await controller.load();
      expect(await controller.refreshRemote(), isFalse);
      expect(controller.remoteStatus, 'error');
      expect(controller.config.branding.appName, 'Marca de prueba');
      controller.dispose();
    });

    test('deepMerge no rompe si la configuración trae basura', () async {
      final PrefsStore store = await PrefsStore.create();
      await store.saveRemoteConfig(<String, dynamic>{
        'branding': 'esto no es un objeto',
        'theme': <String, dynamic>{'available': 'tampoco es una lista'},
      });

      final ConfigController controller = ConfigController(
        store: store,
        bundledJson: testBundle(),
      );
      await controller.load();

      // Se conserva el tema del paquete y no se lanza ninguna excepción.
      expect(controller.config.theme.available, isNotEmpty);
      expect(controller.theme.id, isNotEmpty);
      expect(controller.config.branding.appName, 'Marca de prueba');
      controller.dispose();
    });

    test('el config.json del proyecto es válido', () async {
      final PrefsStore store = await PrefsStore.create();
      final ConfigController controller = ConfigController(
        store: store,
        httpClient: jsonClient(<String, dynamic>{}),
      );
      await controller.load();

      final AppConfig config = controller.config;
      expect(config.schemaVersion, greaterThanOrEqualTo(1));
      expect(config.branding.appName.trim(), isNotEmpty);
      expect(config.theme.available, isNotEmpty);
      expect(config.xtream.userAgent.trim(), isNotEmpty);
      expect(config.theme.resolve(null).id, isNotEmpty);
      controller.dispose();
    });
  });
}
