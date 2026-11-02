import 'dart:convert';
import '../api/xtream_client.dart';
import '../app_info.dart';
import 'secure_session.dart';

/// Panel is authoritative. A denied registration never falls back to tokenless playback.
class DeviceSession {
  DeviceSession(this.storage);
  final SecureSession storage;
  Future<void>? _registering;
  int _generation = 0;
  String _scope(XtreamClient client) => '${client.api.origin}${client.api.basePath}|${client.api.username}';
  Future<void> attach(XtreamClient client, {bool force = false}) async {
    if (!force) {
      try {
        final saved = jsonDecode(storage.values['device.session'] ?? '{}') as Map;
        final until = DateTime.tryParse(saved['until'] as String? ?? '');
        final token = saved['token'] as String? ?? '';
        if (saved['scope'] == _scope(client) && until != null && until.isAfter(DateTime.now()) && token.isNotEmpty) {
          client.api.deviceToken = token;
          return;
        }
      } catch (_) {}
    }
    if (_registering != null) return _registering!;
    final task = _register(client);
    _registering = task;
    try { await task; } finally { _registering = null; }
  }
  Future<void> _register(XtreamClient client) async {
    final generation = _generation;
    final identity = await storage.identity();
    if (!RegExp(r'^[A-Za-z0-9._:-]{8,128}$').hasMatch(identity['device_id'] ?? '')) {
      throw const XtreamException('Identificador de aparato inválido.', statusCode: 400, code: 'device_invalid');
    }
    client.api.deviceToken = '';
    final data = await client.securityAction('register_device', {...identity, 'app_version': kAppVersion});
    if (generation != _generation) throw const XtreamException('Sesión finalizada.');
    final token = data['device_token'] as String? ?? '';
    if (data['registered'] != true || token.isEmpty) {
      throw const XtreamException('El panel no confirmó la vinculación de este aparato.', statusCode: 403);
    }
    final ttl = int.tryParse('${data['token_ttl_seconds']}') ?? 2592000;
    if (ttl <= 0) throw const XtreamException('El panel devolvió una sesión de aparato inválida.', statusCode: 403);
    await storage.write('device.session', jsonEncode({'scope': _scope(client), 'token': token,
      'until': DateTime.now().add(Duration(seconds: ttl > 2592000 ? 2592000 : ttl)).toIso8601String()}));
    if (generation != _generation) { await storage.write('device.session', null); throw const XtreamException('Sesión finalizada.'); }
    client.api.deviceToken = token;
  }
  Future<void> clear() async { _generation++; await storage.write('device.session', null); }
  Future<void> unlink(XtreamClient client) async {
    final identity = await storage.identity();
    final data = await client.securityAction('unlink_device', {'device_id': identity['device_id']!});
    if (data['unlinked'] != true) throw const XtreamException('El panel no confirmó la desvinculación.');
    await clear();
  }
  Future<void> heartbeat(XtreamClient client) async {
    final data = await client.securityAction('heartbeat');
    if (data['status'] != 'active') throw const XtreamException('Cuenta suspendida.', statusCode: 403, code: 'account_inactive');
    final expiry = int.tryParse('${data['exp_date']}');
    final now = int.tryParse('${data['server_time']}');
    if (now == null) throw const XtreamException('El panel no proporcionó la hora del servidor.');
    if (expiry != null && expiry > 0 && expiry <= now) {
      throw const XtreamException('Suscripción vencida.', statusCode: 403, code: 'account_expired');
    }
  }
}
