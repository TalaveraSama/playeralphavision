import '../utils/parse_utils.dart';

/// Recordatorio de descanso: independiente de publicidad y sus límites.
class UsageReminderConfig {
  const UsageReminderConfig({this.enabled = false, this.intervalMinutes = 240,
    this.countdownSeconds = 10, this.title = 'Consejos',
    this.message = defaultMessage, this.buttonLabel = 'Continuar usando'});
  static const defaultMessage = 'Ya usaste la app por {hours} horas. Te recomendamos descansar un poco por tu salud. La reproducción se cerrará después de {seconds} segundos. Pulsa «Continuar usando» si quieres seguir.';
  final bool enabled;
  final int intervalMinutes;
  final int countdownSeconds;
  final String title;
  final String message;
  final String buttonLabel;
  String get signature => '$enabled|$intervalMinutes|$countdownSeconds|$title|$message|$buttonLabel';
  String get displayMessage {
    final hours = intervalMinutes / 60;
    return message.replaceAll('{hours}', hours == hours.roundToDouble()
        ? hours.toInt().toString() : hours.toStringAsFixed(1))
      .replaceAll('{minutes}', '$intervalMinutes')
      .replaceAll('{seconds}', '$countdownSeconds');
  }
  factory UsageReminderConfig.fromJson(Map<String, dynamic> json) => UsageReminderConfig(
    enabled: asBool(json['enabled']),
    intervalMinutes: asInt(json['intervalMinutes'], 240).clamp(1, 1440),
    countdownSeconds: asInt(json['countdownSeconds'], 10).clamp(5, 120),
    title: asStringOr(json['title'], 'Consejos'),
    message: asStringOr(json['message'], defaultMessage),
    buttonLabel: asStringOr(json['buttonLabel'], 'Continuar usando'),
  );
  Map<String, dynamic> toJson() => <String, dynamic>{
    'enabled': enabled, 'intervalMinutes': intervalMinutes,
    'countdownSeconds': countdownSeconds, 'title': title,
    'message': message, 'buttonLabel': buttonLabel,
  };
}
