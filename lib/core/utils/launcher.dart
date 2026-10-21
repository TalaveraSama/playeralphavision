import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre un enlace externo (anuncios, soporte, descarga de APK...).
Future<bool> openExternal(String? url) async {
  final String raw = url?.trim() ?? '';
  if (raw.isEmpty) return false;

  var value = raw;
  if (!value.contains('://')) {
    value = value.startsWith('+') || RegExp(r'^[0-9\s\-]+$').hasMatch(value)
        ? 'https://wa.me/${value.replaceAll(RegExp(r'[^0-9]'), '')}'
        : 'https://$value';
  }

  final Uri? uri = Uri.tryParse(value);
  if (uri == null) return false;

  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}

/// Convierte `+50588888888`, `wa.me/...` o una URL en un enlace de WhatsApp.
String? whatsappLink(String? value) {
  final String raw = value?.trim() ?? '';
  if (raw.isEmpty) return null;
  if (raw.startsWith('http')) return raw;
  final String digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return null;
  return 'https://wa.me/$digits';
}
