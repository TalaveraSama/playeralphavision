/// Formateo de fechas, duraciones y horas de emisión.
String twoDigits(int value) => value.toString().padLeft(2, '0');

String formatDate(DateTime? date) {
  if (date == null) return '—';
  return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year}';
}

String formatDateTime(DateTime? date) {
  if (date == null) return '—';
  return '${formatDate(date)} ${twoDigits(date.hour)}:${twoDigits(date.minute)}';
}

/// `01:32:10` para VOD, o `12:05` para directos.
String formatDuration(Duration duration) {
  if (duration.inHours > 0) {
    return '${twoDigits(duration.inHours)}:'
        '${twoDigits(duration.inMinutes.remainder(60))}:'
        '${twoDigits(duration.inSeconds.remainder(60))}';
  }
  return '${twoDigits(duration.inMinutes.remainder(60))}:'
      '${twoDigits(duration.inSeconds.remainder(60))}';
}

String formatClock(int? epochSeconds) {
  if (epochSeconds == null || epochSeconds <= 0) return '--:--';
  final date = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
  return '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
}

/// Formato que espera el endpoint `/timeshift/` de Xtream: `2024-05-01:20-30`.
String formatTimeshiftStart(DateTime date) {
  return '${date.year}-${twoDigits(date.month)}-${twoDigits(date.day)}:'
      '${twoDigits(date.hour)}-${twoDigits(date.minute)}';
}

String formatRating(double? rating) {
  if (rating == null || rating <= 0) return '';
  return rating.toStringAsFixed(1);
}
