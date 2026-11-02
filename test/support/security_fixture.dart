import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xtream_player/core/api/xtream_api.dart';
import 'package:xtream_player/core/api/xtream_client.dart';
import 'package:xtream_player/core/security/secure_session.dart';

/// Tests only: HTTPS virtual panel; catalog payloads come from the local fixture.
SecureSession testSecureSession() => SecureSession(identityProvider: () async => {
  'device_id': 'PA-test0001', 'device_name': 'Fixture', 'platform': 'Android',
});
XtreamClient testPanelClient(XtreamApi api) => XtreamClient(api: api,
  httpClient: MockClient((request) async {
    switch (request.url.queryParameters['action']) {
      case 'register_device': return http.Response(jsonEncode({'registered': true,
        'device_token': 'fixture-not-real', 'token_ttl_seconds': 2592000}), 200);
      case 'heartbeat': return http.Response(jsonEncode({'status': 'active',
        'server_time': 100, 'exp_date': '200'}), 200);
    }
    final local = http.Client();
    try { return await local.get(request.url.replace(scheme: 'http'), headers: request.headers); }
    finally { local.close(); }
  }));
