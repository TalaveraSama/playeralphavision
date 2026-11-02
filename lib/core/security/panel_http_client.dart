import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'secure_session.dart';

/// Android's HTTPS stack honors network_security_config (including configured pins).
class PanelHttpClient extends http.BaseClient {
  PanelHttpClient({this.allowHttp = false, this.maxResponseBytes = 64 * 1024 * 1024});
  final int maxResponseBytes;
  final bool allowHttp;
  bool _closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed || (request.url.scheme != 'https' && !(allowHttp && request.url.scheme == 'http'))) throw http.ClientException('HTTPS requerido');
    final result = await SecureSession.channel.invokeMapMethod<String, dynamic>('request', {
      'url': request.url.toString(), 'headers': request.headers, 'allowHttp': allowHttp, 'maxResponseBytes': maxResponseBytes,
    });
    if (_closed || result == null) throw http.ClientException('Petición cancelada');
    final bytes = utf8.encode(result['body'] as String? ?? '');
    return http.StreamedResponse(Stream.value(bytes), result['status'] as int,
      headers: Map<String, String>.from(result['headers'] as Map? ?? {}));
  }
  @override
  void close() { _closed = true; }
  static http.Client create({bool allowHttp = false, int maxResponseBytes = 64 * 1024 * 1024}) => Platform.isAndroid ? PanelHttpClient(allowHttp: allowHttp, maxResponseBytes: maxResponseBytes) : http.Client();
}
