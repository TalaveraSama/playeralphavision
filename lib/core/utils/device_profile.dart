import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';

/// Tipo de equipo donde corre la app.
enum DeviceKind { tv, tablet, phone, unknown }

/// Perfil del dispositivo para adaptar la interfaz y mostrar datos de soporte.
/// La reproducción Android utiliza únicamente ExoPlayer.
///
/// Detección (Android):
/// * **TV / Fire TV / TV box**: la lista de *features* trae
///   `android.software.leanback` o `android.hardware.type.television`, o el
///   modelo empieza por `AFT` (los Fire TV: AFTMM, AFTKA, AFTSS…) o no hay
///   pantalla táctil.
/// * **Tableta**: pantalla de 600 dp o más sin ser TV.
/// * **Teléfono**: el resto.
/// * Además, Flutter marca la navegación con mando como *direccional*, que es
///   la señal más fiable de que hay un control remoto delante.
class DeviceProfile {
  const DeviceProfile({
    required this.kind,
    required this.isFireTv,
    required this.abis,
    required this.model,
  });

  final DeviceKind kind;
  final bool isFireTv;
  final List<String> abis;
  final String model;

  bool get isTv => kind == DeviceKind.tv;
  bool get isTablet => kind == DeviceKind.tablet;

  /// Solo 32 bits (Fire TV Stick antiguos): útil para avisos de rendimiento.
  bool get is32BitOnly =>
      abis.isNotEmpty && !abis.contains('arm64-v8a') && !abis.contains('x86_64');

  /// Texto corto para soporte: «Fire TV Stick (arm32)», «Teléfono arm64»…
  String get label {
    final String type;
    switch (kind) {
      case DeviceKind.tv:
        type = isFireTv ? 'Fire TV' : 'TV / TV box';
        break;
      case DeviceKind.tablet:
        type = 'Tableta';
        break;
      case DeviceKind.phone:
        type = 'Teléfono';
        break;
      case DeviceKind.unknown:
        type = 'Android';
        break;
    }
    final String arch = abis.isEmpty
        ? ''
        : ' · ${abis.first}${is32BitOnly ? ' (32 bits)' : ''}';
    return '$type$arch';
  }

  static DeviceProfile? _cached;

  /// Último perfil detectado (o `null` si todavía no se cargó).
  static DeviceProfile? get current => _cached;

  /// ¿El contexto actual navega con mando? (TV, Fire TV, TV box).
  static bool isRemoteContext(BuildContext context) =>
      MediaQuery.of(context).navigationMode == NavigationMode.directional;

  /// Detecta el perfil una sola vez por sesión.
  static Future<DeviceProfile> load({double widthDp = 400}) async {
    final DeviceProfile? cached = _cached;
    if (cached != null) return cached;

    DeviceProfile profile = DeviceProfile(
      kind: widthDp >= 600 ? DeviceKind.tablet : DeviceKind.phone,
      isFireTv: false,
      abis: const <String>[],
      model: Platform.isIOS ? 'iPhone / iPad' : 'Android',
    );

    if (Platform.isAndroid) {
      try {
        final AndroidDeviceInfo info = await DeviceInfoPlugin().androidInfo;
        final List<String> features = info.systemFeatures;
        final String model = info.model.toUpperCase();
        final bool fireTv = model.startsWith('AFT') ||
            (info.manufacturer.toLowerCase().contains('amazon') &&
                features.contains('android.software.leanback'));
        final bool tv = fireTv ||
            features.contains('android.software.leanback') ||
            features.contains('android.hardware.type.television') ||
            !features.contains('android.hardware.touchscreen');

        profile = DeviceProfile(
          kind: tv
              ? DeviceKind.tv
              : (widthDp >= 600 ? DeviceKind.tablet : DeviceKind.phone),
          isFireTv: fireTv,
          abis: info.supportedAbis,
          model: info.model,
        );
      } catch (_) {
        // Sin información del sistema: se queda lo deducido por tamaño.
      }
    }

    _cached = profile;
    return profile;
  }
}
