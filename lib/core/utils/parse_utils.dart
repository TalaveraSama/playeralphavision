import 'dart:convert';

/// Helpers de parseo defensivo.
///
/// Los paneles Xtream Codes / XUI.one devuelven tipos inconsistentes entre
/// versiones: los identificadores pueden venir como `int` o como `String`,
/// las listas pueden ser un `List` o un valor único, y los textos de la EPG
/// llegan codificados en Base64. Estas funciones normalizan todo eso sin
/// lanzar excepciones.
String? asString(dynamic value) {
  if (value == null) return null;
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is Map || value is Iterable || value is bool) return null;
  return value.toString();
}

String asStringOr(dynamic value, String fallback) => asString(value) ?? fallback;

int? asIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is bool) return value ? 1 : 0;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return int.tryParse(text) ?? double.tryParse(text)?.toInt();
}

int asInt(dynamic value, [int fallback = 0]) => asIntOrNull(value) ?? fallback;

double? asDoubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return double.tryParse(text) ?? double.tryParse(text.replaceAll(',', '.'));
}

double asDouble(dynamic value, [double fallback = 0]) =>
    asDoubleOrNull(value) ?? fallback;

bool asBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value.toString().trim().toLowerCase();
  return text == '1' || text == 'true' || text == 'yes' || text == 'active';
}

/// `exp_date`, `created_at`, `added`, `timestamp_now`... llegan en segundos.
DateTime? dateFromEpoch(dynamic value) {
  final seconds = asIntOrNull(value);
  if (seconds == null || seconds <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
}

/// Fechas tipo `2024-05-01 12:30:00`.
DateTime? dateFromText(dynamic value) {
  final raw = asString(value);
  if (raw == null) return null;
  return DateTime.tryParse(raw.replaceFirst(' ', 'T'));
}

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map) {
    return value.map((key, v) => MapEntry(key.toString(), v));
  }
  return <String, dynamic>{};
}

List<Map<String, dynamic>> asMapList(dynamic value) {
  if (value is List) {
    return value.whereType<Map<dynamic, dynamic>>().map(asMap).toList();
  }
  return const <Map<String, dynamic>>[];
}

List<String> asStringList(dynamic value) {
  if (value is List) {
    return value
        .map((element) => element?.toString() ?? '')
        .where((element) => element.isNotEmpty)
        .toList();
  }
  final single = asString(value);
  return single == null ? const <String>[] : <String>[single];
}

/// La EPG de Xtream devuelve `title` y `description` en Base64, pero algunos
/// paneles los mandan en texto plano. Se detecta y se decodifica con cuidado.
String decodeMaybeBase64(dynamic value) {
  final raw = asString(value);
  if (raw == null) return '';
  if (raw.length % 4 != 0 ||
      !RegExp(r'^[A-Za-z0-9+/]+={0,2}$').hasMatch(raw)) {
    return raw;
  }
  try {
    final List<int> bytes = base64.decode(raw);
    // 1) UTF-8 estricto: lo habitual.
    try {
      final String decoded = utf8.decode(bytes);
      if (_epgPrintable(decoded)) return decoded;
    } catch (_) {}
    // 2) Latin-1 / cp1252: paneles que mandan acentos en 8 bits.
    final String latin = latin1.decode(bytes, allowInvalid: true);
    if (_epgPrintable(latin)) return latin;
    // 3) UTF-8 tolerante: nunca deja el Base64 crudo en pantalla.
    final String loose = utf8.decode(bytes, allowMalformed: true);
    if (_epgPrintable(loose)) return loose;
  } catch (_) {
    // No era Base64 válido: se devuelve el texto original.
  }
  return raw;
}

bool _epgPrintable(String text) =>
    text.trim().isNotEmpty &&
    text.runes.every(
      (rune) => rune == 9 || rune == 10 || rune == 13 || rune >= 32,
    );
