import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/core/api/m3u_client.dart';
import 'package:xtream_player/core/models/iptv_profile.dart';
import 'package:xtream_player/core/models/media_item.dart';
void main() {
  test('M3U parses groups, logos, relative entries and titles with commas', () {
    final channels = parseM3u('#EXTM3U url-tvg="https://guide.example/epg"\n#EXTINF:-1 group-title="TV" tvg-logo="https://image.example/logo",Noticias, HD\nchannel.m3u8\n', source: Uri.parse('https://video.example/list.m3u'));
    expect(channels.single.name, 'Noticias, HD');
    expect(channels.single.categoryId, 'TV');
    expect(channels.single.directUrl, 'https://video.example/channel.m3u8');
    expect(MediaItem.fromJson(channels.single.toJson()).directUrl, channels.single.directUrl);
  });
  test('HLS manifest imports its original URL, not its segments', () {
    final list = parseM3u('#EXTM3U\n#EXT-X-TARGETDURATION:6\n#EXTINF:6,\nseg1.ts', source: Uri.parse('https://video.example/live.m3u8'));
    expect(list.length, 1);
    expect(list.single.directUrl, 'https://video.example/live.m3u8');
  });
  test('rejects relative file entries and unsupported schemes', () {
    expect(() => parseM3u('#EXTM3U\n#EXTINF:-1,Local\nsegment.ts'), throwsFormatException);
    expect(() => parseM3u('#EXTM3U\n#EXTINF:-1,Bad\nfile:///private/file'), throwsFormatException);
  });
  test('profile preserves explicit HTTP consent and encrypted payload fields', () {
    const p = IptvProfile(id: '1', name: 'Cuenta', source: ProfileSource.xtream, server: 'http://example.invalid', username: 'test', password: 'fake', allowHttp: true);
    final restored = IptvProfile.fromJson(p.toJson());
    expect(restored.allowHttp, isTrue); expect(restored.username, 'test');
    expect(restored.source, ProfileSource.xtream);
  });
}
