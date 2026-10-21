import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Descarga e instala una actualización **desde la propia app**.
///
/// Se baja el APK a la caché privada de la app (la que comparte el
/// `FileProvider`) y se abre el instalador de Android, que solo pide confirmar.
///
/// Antes de abrir el instalador se comprueba que el archivo esté **completo**:
/// tamaño anunciado, cabecera ZIP y cierre del ZIP. Un APK a medias es lo que
/// hace que Android diga «no se puede analizar el paquete».
class ApkInstaller {
  const ApkInstaller._();

  static const String _fileName = 'nova-update.apk';

  /// Último motivo de fallo (se muestra en el aviso al usuario).
  static String? lastError;

  /// `true` si se abrió el instalador de Android.
  static Future<bool> downloadAndInstall(
    String url, {
    ValueChanged<double>? onProgress,
  }) async {
    if (!Platform.isAndroid) return false;
    lastError = null;

    final String dir = await _downloadDir();
    final File file = File('$dir/$_fileName');

    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        if (await file.exists()) await file.delete();

        final HttpClient client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 20);
        final HttpClientResponse response =
            await (await client.getUrl(Uri.parse(url))).close();
        if (response.statusCode != 200) {
          lastError = 'el servidor respondió HTTP ${response.statusCode}';
          client.close();
          continue;
        }

        final int total = response.contentLength;
        int received = 0;
        final IOSink sink = file.openWrite();
        await for (final List<int> chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) onProgress?.call(received / total);
        }
        await sink.flush();
        await sink.close();
        client.close();

        final String? problem = await _checkApk(file, total);
        if (problem == null) {
          final bool opened = await openInstaller(file);
          if (!opened) lastError = 'no se pudo abrir el instalador de Android';
          return opened;
        }
        lastError = problem;
      } catch (error) {
        lastError = 'error de descarga: $error';
      }
    }
    return false;
  }

  /// Carpeta de archivos de la app (files dir): es la que comparte el
  /// `FileProvider` de forma fiable. En Fire OS la carpeta temporal/caché no
  /// siempre coincide con la raíz que expone el FileProvider (y eso provocaba
  /// «no se puede analizar el paquete»).
  static Future<String> _downloadDir() async {
    try {
      final Directory dir = await getApplicationSupportDirectory();
      return dir.path;
    } catch (_) {
      return Directory.systemTemp.path;
    }
  }

  /// Devuelve `null` si el APK está completo o el motivo del fallo.
  static Future<String?> _checkApk(File file, int total) async {
    if (!await file.exists()) return 'no se descargó ningún archivo';
    final int length = await file.length();
    final String mb = (length / 1048576).toStringAsFixed(1);
    if (length < 1024 * 1024) {
      return 'el archivo descargado es demasiado pequeño ($mb MB)';
    }
    if (total > 0 && length != total) {
      return 'la descarga quedó incompleta ($mb MB de '
          '${(total / 1048576).toStringAsFixed(1)} MB)';
    }

    final RandomAccessFile handle = await file.open();
    try {
      final Uint8List head = await handle.read(4);
      if (head.length < 4 || head[0] != 0x50 || head[1] != 0x4B) {
        return 'el archivo descargado no es un APK ($mb MB)';
      }

      final int from = length > 66 ? length - 66 : 0;
      await handle.setPosition(from);
      final Uint8List tail = await handle.read(length - from);
      for (int i = 0; i + 4 <= tail.length; i++) {
        if (tail[i] == 0x50 &&
            tail[i + 1] == 0x4B &&
            tail[i + 2] == 0x05 &&
            tail[i + 3] == 0x06) {
          return null;
        }
      }
      return 'el APK llegó cortado ($mb MB)';
    } finally {
      await handle.close();
    }
  }

  static const MethodChannel _installer = MethodChannel('nova/installer');

  /// Abre el instalador de Android para el archivo descargado.
  static Future<bool> openInstaller(File file) async {
    // Vía nativa: FileProvider.getUriForFile + setDataAndType resuelven la ruta
    // y el tipo juntos (el intent manual fallaba en Fire OS / Android TV).
    try {
      final bool ok = await _installer.invokeMethod<bool>(
        'installApk',
        <String, dynamic>{'path': file.path},
      ) ?? false;
      if (ok) return true;
    } catch (_) {
      // Sin canal nativo: se cae al intent clásico.
    }
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      final AndroidIntent intent = AndroidIntent(
        action: 'android.intent.action.VIEW',
        data: 'content://${info.packageName}.fileprovider/$_fileName',
        type: 'application/vnd.android.package-archive',
        flags: <int>[
          1, // FLAG_GRANT_READ_URI_PERMISSION
          268435456, // FLAG_ACTIVITY_NEW_TASK
        ],
      );
      await intent.launch();
      return true;
    } catch (error) {
      lastError = 'error al abrir el instalador: $error';
      return false;
    }
  }

  /// Abre los ajustes de «instalar apps desconocidas» de esta app.
  static Future<void> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) return;
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      await AndroidIntent(
        action: 'android.settings.MANAGE_UNKNOWN_APP_SOURCES',
        data: 'package:${info.packageName}',
      ).launch();
    } catch (_) {
      // Sin ajustes disponibles: se ignora.
    }
  }
}
