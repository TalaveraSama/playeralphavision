import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/config/config_controller.dart';
import 'core/state/app_state.dart';
import 'core/storage/prefs_store.dart';
import 'core/utils/device_profile.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // La app se usa siempre en horizontal (teléfono, tableta y TV).
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Pantalla completa real: oculta la barra de notificaciones (estado) y la
  // barra de atras/inicio/menu (navegacion) del telefono/tablet. En TV no hay
  // barras, asi que no cambia nada. 'immersiveSticky' las deja ocultas aunque
  // el usuario deslice el dedo desde el borde.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Equipos con poca memoria (Fire TV Stick, cajas baratas): se limita la caché
  // de imágenes decodificadas para que el sistema no cierre la app.
  PaintingBinding.instance.imageCache.maximumSize = 60;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 20 << 20; // 20 MB

  // El Fire TV Stick tiene ~1 GB de RAM: cada 5 min se liberan las imagenes
  // decodificadas para que la app aguante sesiones de TV en vivo de horas.
  Timer.periodic(const Duration(minutes: 5), (_) {
    PaintingBinding.instance.imageCache
      ..clear()
      ..clearLiveImages();
  });

  final PrefsStore store;
  try { store = await PrefsStore.create(); }
  catch (_) {
    runApp(const MaterialApp(home: Scaffold(body: Center(child: Padding(
      padding: EdgeInsets.all(24), child: Text('No se pudo abrir el almacenamiento seguro. No se guardarán credenciales sin cifrar. Contacta con soporte.'))))));
    return;
  }
  final ConfigController config = ConfigController(store: store);
  final AppState appState = AppState(store, config);

  // Cualquier fallo inesperado se guarda para verlo luego en Ajustes.
  FlutterError.onError = (FlutterErrorDetails details) {
    // Do not print arbitrary exceptions: they may contain authenticated URLs.
    unawaited(store.saveLastError(details.exceptionAsString()));
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    unawaited(store.saveLastError(error.toString()));
    return true;
  };

  // Configuración de marca: asset del APK + caché local (rápido).
  await config.load();
  // Detectar Fire TV/Leanback antes del primer diseño, incluso si el sistema
  // no anuncia NavigationMode.directional.
  await DeviceProfile.load();

  runApp(XtreamPlayerApp(appState: appState, config: config));

  // La sesión guardada se valida contra el panel después del primer frame
  // para no dejar la pantalla en blanco mientras responde la red.
  await appState.restore();
}
