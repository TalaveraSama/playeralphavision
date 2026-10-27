import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/config_controller.dart';
import 'core/state/app_state.dart';
import 'core/theme/app_themes.dart';
import 'features/auth/login_page.dart';
import 'features/home/home_shell.dart';
import 'features/home/nova_shell.dart';
import 'features/update/update_dialog.dart';
import 'widgets/net_image.dart';
import 'features/reminders/usage_reminder_host.dart';

class XtreamPlayerApp extends StatefulWidget {
  const XtreamPlayerApp({
    super.key,
    required this.appState,
    required this.config,
  });

  final AppState appState;
  final ConfigController config;

  @override
  State<XtreamPlayerApp> createState() => _XtreamPlayerAppState();
}

class _XtreamPlayerAppState extends State<XtreamPlayerApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ConfigController>.value(value: widget.config),
        ChangeNotifierProvider<AppState>.value(value: widget.appState),
      ],
      child: Consumer<ConfigController>(
        builder: (BuildContext context, ConfigController controller, _) {
          return MaterialApp(
            navigatorKey: _navigatorKey,
            title: controller.config.branding.appName,
            debugShowCheckedModeBanner: false,
            theme: buildThemeData(controller.theme),
            // El tamaño de fuente del sistema se respeta, pero con tope: en
            // televisores y móviles con fuente muy grande era lo que hacía que
            // todo se viera enorme.
            builder: (BuildContext context, Widget? child) {
              final MediaQueryData mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(
                  textScaler: mq.textScaler.clamp(
                    minScaleFactor: 0.9,
                    maxScaleFactor: 1.25,
                  ),
                ),
                child: UsageReminderHost(
                  config: controller.config.usageReminder,
                  active: context.watch<AppState>().isLoggedIn &&
                      !context.watch<AppState>().restoring && !controller.loading,
                  navigatorKey: _navigatorKey,
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
            home: const _RootGate(),
          );
        },
      ),
    );
  }
}

/// Decides whether to show the splash, the login or the app, and checks for
/// updates published from the admin panel.
class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  String _lastUpdateKey = '';

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final ConfigController config = context.watch<ConfigController>();

    if (app.restoring || config.loading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              if (config.config.branding.effectiveSplashLogo
                  .trim()
                  .isNotEmpty)
                SizedBox(
                  height: 90,
                  child: NetImage(
                    url: config.config.branding.effectiveSplashLogo,
                    fit: BoxFit.contain,
                    backgroundColor: Colors.transparent,
                  ),
                )
              else
                Text(config.config.branding.appName),
            ],
          ),
        ),
      );
    }

    final update = config.config.update;
    final String key =
        '${update.enabled}|${update.latestVersion}|${config.remoteStatus}';
    if (key != _lastUpdateKey) {
      _lastUpdateKey = key;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) maybeShowUpdateDialog(context, config, app);
      });
    }

    // El tema decide el armazón: la portada NOVA usa su propio contenedor
    // (barra superior en pantallas anchas y barra inferior en el móvil); el
    // resto de temas siguen con las pestañas de siempre.
    if (!app.isLoggedIn) return const LoginPage();
    return config.theme.isNova ? NovaShell(key: ValueKey<String>(config.theme.id)) : const HomeShell();
  }
}
