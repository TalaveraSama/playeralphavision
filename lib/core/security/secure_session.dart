import 'dart:io';
import 'package:flutter/services.dart';

/// Android Keystore backed storage. No plaintext fallback on Android.
class SecureSession {
  SecureSession({this.identityProvider});
  final Future<Map<String, String>> Function()? identityProvider;
  static const channel = MethodChannel('alphavision/security');
  final Map<String, String> values = {};
  static Future<SecureSession> open() async {
    final store = SecureSession();
    if (Platform.isAndroid) {
      final raw = await channel.invokeMapMethod<String, String>('readAll');
      store.values.addAll(raw ?? {});
    }
    return store;
  }
  Future<void> write(String key, String? value) async {
    if (Platform.isAndroid) {
      await channel.invokeMethod<void>('write', {'key': key, 'value': value});
    }
    if (value == null) { values.remove(key); } else { values[key] = value; }
  }
  Future<Map<String, String>> identity() async {
    if (identityProvider != null) return identityProvider!();
    if (!Platform.isAndroid) throw UnsupportedError('Android requerido');
    return await channel.invokeMapMethod<String, String>('identity') ?? {};
  }
}
