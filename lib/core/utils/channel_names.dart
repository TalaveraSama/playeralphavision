/// Utilidades para limpiar y clasificar nombres de canales IPTV.
///
/// Portadas de la lógica de `packages/core/src/channel-name.ts` del panel de
/// referencia: los proveedores meten separadores decorativos (`-=Finland=-`,
/// `*** FI ***`) entre canales reales y entradas de eventos en directo con la
/// hora delante (`19:30 HJK Helsinki - Inter Turku`).
library;

final RegExp _decorationRun = RegExp(r'[^\p{L}\p{N}\s]{2,}', unicode: true);
final RegExp _leadingDecoration =
    RegExp(r'^[^\p{L}\p{N}]*?([^\p{L}\p{N}\s]{2,})\s*(?=[\p{L}\p{N}])', unicode: true);
final RegExp _trailingDecoration =
    RegExp(r'(?<=[\p{L}\p{N}])\s*([^\p{L}\p{N}\s]{2,})[^\p{L}\p{N}]*$', unicode: true);
final RegExp _eventTimePrefix =
    RegExp(r'^\s*(?:[01]?\d|2[0-3])[:.][0-5]\d(?:\s|$)', unicode: true);

/// Detecta los separadores decorativos que algunos proveedores insertan entre
/// canales reales. Nunca llevan guía de programación, así que se pueden quitar
/// de la lista.
bool isSeparatorChannelName(String name) {
  final String trimmed = name.trim();
  if (trimmed.isEmpty) return false;
  final bool hasLettersOrDigits =
      RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(trimmed);
  if (!hasLettersOrDigits) return _decorationRun.hasMatch(trimmed);
  return _leadingDecoration.hasMatch(trimmed) &&
      _trailingDecoration.hasMatch(trimmed);
}

/// Detecta nombres de eventos en directo (empiezan por una hora).
bool looksLikeEventTitle(String name) => _eventTimePrefix.hasMatch(name.trim());

/// Calidad que anuncia el nombre del canal, si la indica.
String? channelQualityTag(String name) {
  final String value = name.toUpperCase();
  if (RegExp(r'\b(4K|UHD)\b').hasMatch(value)) return '4K';
  if (RegExp(r'\b(FHD|FULL\s?HD|1080[PI]?)\b').hasMatch(value)) return 'FHD';
  if (RegExp(r'\b(HD|720[PI]?)\b').hasMatch(value)) return 'HD';
  if (RegExp(r'\b(SD|480[PI]?|360[PI]?)\b').hasMatch(value)) return 'SD';
  return null;
}

/// Nombre del canal sin el sufijo de calidad, para mostrarlo más limpio.
String cleanChannelName(String name) {
  return name
      .replaceAll(
        RegExp(r'\s*[\[\(]?\b(4K|UHD|FHD|FULL\s?HD|HD|SD)\b[\]\)]?\s*$',
            caseSensitive: false),
        '',
      )
      .trim();
}
