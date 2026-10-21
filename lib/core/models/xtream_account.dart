import '../utils/parse_utils.dart';

/// `server_info` de la respuesta de `player_api.php`.
class XtreamServerInfo {
  const XtreamServerInfo({
    this.url,
    this.port,
    this.httpsPort,
    this.protocol,
    this.timezone,
    this.timeNow,
    this.timestampNow,
  });

  final String? url;
  final String? port;
  final String? httpsPort;
  final String? protocol;
  final String? timezone;
  final String? timeNow;
  final int? timestampNow;

  factory XtreamServerInfo.fromJson(Map<String, dynamic> json) {
    return XtreamServerInfo(
      url: asString(json['url']),
      port: asString(json['port']),
      httpsPort: asString(json['https_port']),
      protocol: asString(json['server_protocol']),
      timezone: asString(json['timezone']),
      timeNow: asString(json['time_now']),
      timestampNow: asIntOrNull(json['timestamp_now']),
    );
  }
}

/// Cuenta devuelta por `player_api.php` (sin `action`).
class XtreamAccount {
  const XtreamAccount({
    required this.auth,
    this.username,
    this.status,
    this.message,
    this.expDate,
    this.createdAt,
    this.isTrial = false,
    this.activeConnections = 0,
    this.maxConnections = 0,
    this.allowedFormats = const <String>[],
    this.serverInfo = const XtreamServerInfo(),
  });

  /// 1 si las credenciales son correctas; 0 si no.
  final int auth;
  final String? username;
  final String? status;
  final String? message;
  final DateTime? expDate;
  final DateTime? createdAt;
  final bool isTrial;
  final int activeConnections;
  final int maxConnections;
  final List<String> allowedFormats;
  final XtreamServerInfo serverInfo;

  bool get isActive =>
      auth == 1 && (status == null || status!.toLowerCase() == 'active');

  int? get daysRemaining {
    final exp = expDate;
    if (exp == null) return null;
    return exp.difference(DateTime.now()).inDays;
  }

  bool get isExpired {
    final exp = expDate;
    if (exp == null) return false;
    return exp.isBefore(DateTime.now());
  }

  String get statusText {
    if (auth != 1) {
      return message ??
          status ??
          'Credenciales rechazadas por el servidor.';
    }
    if (isExpired) return 'La suscripción caducó.';
    return status ?? 'Activo';
  }

  factory XtreamAccount.fromJson(Map<String, dynamic> json) {
    final user = asMap(json['user_info']);
    final server = asMap(json['server_info']);
    return XtreamAccount(
      auth: asInt(user['auth']),
      username: asString(user['username']),
      status: asString(user['status']),
      message: asString(user['message']),
      expDate: dateFromEpoch(user['exp_date']),
      createdAt: dateFromEpoch(user['created_at']),
      isTrial: asBool(user['is_trial']),
      activeConnections: asInt(user['active_cons']),
      maxConnections: asInt(user['max_connections']),
      allowedFormats: asStringList(user['allowed_output_formats']),
      serverInfo: XtreamServerInfo.fromJson(server),
    );
  }
}
