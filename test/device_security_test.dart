import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xtream_player/core/storage/prefs_store.dart';
import 'package:xtream_player/core/api/xtream_api.dart';
import 'package:xtream_player/core/api/xtream_client.dart';
import 'package:xtream_player/core/security/device_session.dart';
import 'package:xtream_player/core/security/secure_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  XtreamApi api() => XtreamApi(baseUri: Uri.parse('https://panel.example'), username: 'test', password: 'not-real');
  SecureSession storage() => SecureSession(identityProvider: () async => {'device_id': 'PA-test0001', 'device_name': 'Test', 'platform': 'Android'});
  test('legacy credentials and credential URLs migrate out of plaintext preferences', () async {
    SharedPreferences.setMockInitialValues({'xtream.server': 'https://panel.example',
      'xtream.username': 'test', 'xtream.password': 'not-real',
      'xtream.resume': <String>['{"key":"url:https://panel.example/movie/test/not-real/1.mp4"}'],
      'xtream.last_error': 'old secret URL'});
    final secure = storage();
    final prefs = await PrefsStore.create(secureSession: secure);
    final plain = await SharedPreferences.getInstance();
    expect(prefs.credentials?.username, 'test');
    for (final key in ['xtream.username', 'xtream.password', 'xtream.resume', 'xtream.last_error']) {
      expect(plain.containsKey(key), isFalse);
    }
    expect(secure.values['xtream.password'], 'not-real');
    await prefs.clearCredentials();
    expect(secure.values['xtream.password'], isNull);
  });
  test('registration is reused, and token is sent in all playback headers', () async {
    int registrations = 0;
    final a = api();
    final client = XtreamClient(api: a, httpClient: MockClient((req) async {
      expect(req.url.queryParameters['action'], 'register_device');
      registrations++;
      return http.Response(jsonEncode({'registered': true, 'device_token': 'fake-device-token', 'token_ttl_seconds': 2592000}), 200);
    }));
    final store = storage();
    final devices = DeviceSession(store);
    await devices.attach(client);
    await devices.attach(client);
    expect(registrations, 1);
    expect(a.defaultHeaders['X-Device-Token'], 'fake-device-token');
    final restored = DeviceSession(store);
    final second = XtreamClient(api: api(), httpClient: MockClient((_) async => throw StateError('No second registration')));
    await restored.attach(second);
    expect(second.api.deviceToken, 'fake-device-token');
    await devices.clear();
    expect(store.values['device.session'], isNull);
    client.dispose(); second.dispose();
  });
  test('revoked devices never fall back to tokenless playback', () async {
    final client = XtreamClient(api: api(), httpClient: MockClient((_) async => http.Response('{"error":"device_revoked"}', 403)));
    await expectLater(DeviceSession(storage()).attach(client), throwsA(isA<XtreamException>().having((e) => e.code, 'code', 'device_revoked')));
    expect(client.api.deviceToken, isEmpty);
    client.dispose();
  });
  test('unlink sends the stable device ID and clears the device token', () async {
    final secure = storage();
    secure.values['device.session'] = '{}';
    final client = XtreamClient(api: api(), httpClient: MockClient((request) async {
      expect(request.url.queryParameters['action'], 'unlink_device');
      expect(request.url.queryParameters['device_id'], 'PA-test0001');
      return http.Response('{"unlinked":true}', 200);
    }));
    await DeviceSession(secure).unlink(client);
    expect(secure.values['device.session'], isNull);
    client.dispose();
  });
  test('429 blocks subsequent API requests and honors Retry-After', () async {
    int calls = 0;
    final client = XtreamClient(api: api(), httpClient: MockClient((_) async {
      calls++;
      return http.Response('{}', 429, headers: {'retry-after': '900'});
    }));
    await expectLater(client.securityAction('heartbeat'), throwsA(isA<XtreamException>().having((e) => e.retryAfter?.inSeconds, 'delay', 900)));
    await expectLater(client.securityAction('heartbeat'), throwsA(isA<XtreamException>()));
    expect(calls, 1);
    client.dispose();
  });
  test('expiry uses server time, not the client clock', () async {
    final client = XtreamClient(api: api(), httpClient: MockClient((_) async => http.Response('{"status":"active","server_time":100,"exp_date":"101"}', 200)));
    await DeviceSession(storage()).heartbeat(client);
    client.dispose();
    final expired = XtreamClient(api: api(), httpClient: MockClient((_) async => http.Response('{"status":"active","server_time":102,"exp_date":"101"}', 200)));
    await expectLater(DeviceSession(storage()).heartbeat(expired), throwsA(isA<XtreamException>().having((e) => e.code, 'expiry', 'account_expired')));
    expired.dispose();
  });
  test('HTTP login is rejected before sending credentials', () async {
    final a = XtreamApi(baseUri: Uri.parse('http://panel.example'), username: 'test', password: 'not-real');
    final client = XtreamClient(api: a, httpClient: MockClient((_) async => throw StateError('Must not send')));
    await expectLater(client.authenticate(), throwsA(isA<XtreamException>()));
    client.dispose();
  });
}
