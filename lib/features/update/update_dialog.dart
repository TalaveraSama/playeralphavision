import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_info.dart';
import '../../core/config/app_config.dart';
import '../../core/config/config_controller.dart';
import '../../core/state/app_state.dart';
import '../../core/utils/device_profile.dart';
import '../../core/utils/launcher.dart';
import 'apk_installer.dart';

/// Aviso de nueva versión publicado desde el panel de administración.
///
/// El método de actualización depende del equipo:
/// * **TV / Fire TV / TV box**: descarga e instalación **dentro de la app**
///   (el navegador de Fire TV no sirve para bajar APKs).
/// * **Móvil / tableta**: se abre el **navegador**, que descarga y el usuario
///   instala desde sus descargas.
Future<void> maybeShowUpdateDialog(
  BuildContext context,
  ConfigController config,
  AppState app,
) async {
  // El panel distribuye APK; nunca bloquear iOS con una actualización Android.
  if (Platform.isIOS) return;
  final UpdateConfig update = config.config.update;
  if (!update.hasUpdate) return;

  final bool mandatory = update.isMandatory;
  if (!mandatory && app.dismissedUpdateVersion == update.latestVersion) return;

  // El APK que se descarga es el de la arquitectura de este equipo (32 o 64
  // bits); si la marca solo publicó el universal, se usa ese.
  final DeviceProfile device = await DeviceProfile.load(
    widthDp: MediaQuery.sizeOf(context).width,
  );
  if (!context.mounted) return;
  final String downloadUrl = update.apkUrlForAbis(device.abis);
  final bool canDownload = downloadUrl.isNotEmpty && Platform.isAndroid;
  final bool isTv = device.isTv;

  final bool? wantsUpdate = await showDialog<bool>(
    context: context,
    barrierDismissible: !mandatory,
    builder: (BuildContext dialogContext) {
      final ThemeData theme = Theme.of(dialogContext);
      return PopScope(
        canPop: !mandatory,
        child: AlertDialog(
          icon: const Icon(Icons.system_update_alt, size: 34),
          title: Text('Nueva versión ${update.latestVersion}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Tienes instalada la versión $kAppVersion.',
                  style: theme.textTheme.bodyMedium,
                ),
                if (update.changelog.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      update.changelog,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
                if (canDownload) ...<Widget>[
                  const SizedBox(height: 14),
                  Text(
                    isTv
                        ? 'Se descargará dentro de la app y se abrirá el '
                            'instalador. La primera vez Android pedirá permiso '
                            'para instalar.'
                        : 'Se descargará con el navegador. Cuando termine, '
                            'abre el archivo desde las descargas para '
                            'instalarlo.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
                if (mandatory) ...<Widget>[
                  const SizedBox(height: 14),
                  Text(
                    'Esta actualización es obligatoria para seguir usando la '
                    'aplicación.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
                ],
                if (!canDownload) ...<Widget>[
                  const SizedBox(height: 14),
                  Text(
                    'El administrador todavía no publicó el enlace de descarga.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          actions: <Widget>[
            if (!mandatory)
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Más tarde'),
              ),
            if (isTv && canDownload)
              TextButton(
                onPressed: () => unawaited(
                  ApkInstaller.openInstallPermissionSettings(),
                ),
                child: const Text('Permisos'),
              ),
            FilledButton.icon(
              onPressed: canDownload
                  ? () async {
                      if (isTv) {
                        await _installInApp(context, downloadUrl);
                      } else {
                        await _openBrowser(context, downloadUrl);
                      }
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop(true);
                      }
                    }
                  : null,
              icon: Icon(isTv ? Icons.download : Icons.open_in_new),
              label: Text(isTv ? 'Actualizar' : 'Descargar'),
            ),
          ],
        ),
      );
    },
  );

  if (wantsUpdate != true && !mandatory) {
    await app.dismissUpdate(update.latestVersion);
  }
}

/// TV: descarga dentro de la app y abre el instalador de Android.
Future<void> _installInApp(BuildContext context, String url) async {
  final ValueNotifier<double> progress = ValueNotifier<double>(0);
  final NavigatorState navigator = Navigator.of(context);

  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Descargando actualización'),
          content: ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (BuildContext context, double value, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                LinearProgressIndicator(
                  value: value <= 0 ? null : value.clamp(0.0, 1.0),
                ),
                const SizedBox(height: 12),
                Text(
                  value <= 0
                      ? 'Conectando…'
                      : '${(value * 100).round()} % descargado',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Al terminar se abre el instalador de Android.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  final bool installed = await ApkInstaller.downloadAndInstall(
    url,
    onProgress: (double value) => progress.value = value,
  );

  if (context.mounted) navigator.pop(); // cierra el diálogo de progreso

  if (installed) return;

  final String reason = ApkInstaller.lastError ?? 'motivo desconocido';
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 12),
        content: Text('No se pudo instalar ($reason).'),
      ),
    );
  }
}

/// Móvil/tableta: abre el navegador para descargar el APK.
Future<void> _openBrowser(BuildContext context, String url) async {
  final bool opened = await openExternal(url);
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 14),
      content: Text(
        opened
            ? 'El APK se está descargando en el navegador. Cuando termine, '
                'ábrelo desde las descargas para instalarlo.'
            : 'No se pudo abrir el navegador. Descarga el APK desde el enlace '
                'que te dio el proveedor.',
      ),
    ),
  );
}
