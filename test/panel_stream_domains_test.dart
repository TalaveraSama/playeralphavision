import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/core/api/xtream_api.dart';
import 'package:xtream_player/core/models/xtream_account.dart';

void main() {
  XtreamApi api() => XtreamApi(baseUri: Uri.parse('https://panel.example'), username: 'demo', password: 'fake');
  test('video uses advertised HTTPS host, API and EPG stay on the login host', () {
    final a = api();
    a.configureStreams(const XtreamServerInfo(url: 'video.example', protocol: 'https', port: '80', httpsPort: '443'));
    expect(a.apiUri().host, 'panel.example');
    expect(a.xmltvUri.host, 'panel.example');
    expect(a.playlistUri.host, 'panel.example');
    for (final url in [a.liveUrl('1'), a.movieUrl('2'), a.seriesUrl('3'),
      a.timeshiftUrl(streamId: '1', durationMinutes: 60, start: DateTime(2026, 1, 1))]) {
      expect(Uri.parse(url).host, 'video.example');
      expect(Uri.parse(url).scheme, 'https');
    }
  });
  test('explicit video URL preserves its protocol/port without silent HTTPS downgrade', () {
    final a = api();
    a.configureStreams(const XtreamServerInfo(url: 'http://video.example:8080', protocol: 'https'));
    expect(a.liveUrl('1'), 'http://video.example:8080/live/demo/fake/1.m3u8');
    expect(a.apiUri().scheme, 'https'); // HTTP stream is subsequently rejected by player policy.
  });
  test('missing/invalid video host retains login origin', () {
    final a = api();
    a.configureStreams(const XtreamServerInfo());
    expect(Uri.parse(a.liveUrl('1')).host, 'panel.example');
    a.configureStreams(const XtreamServerInfo(url: 'https://user:pass@invalid.example'));
    expect(Uri.parse(a.liveUrl('1')).host, 'panel.example');
  });
}
