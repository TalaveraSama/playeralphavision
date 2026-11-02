import 'package:xtream_player/core/models/media_item.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xtream_player/core/config/config_controller.dart';
import 'package:xtream_player/core/models/iptv_profile.dart';
import 'package:xtream_player/core/security/secure_session.dart';
import 'package:xtream_player/core/state/app_state.dart';
import 'package:xtream_player/core/storage/prefs_store.dart';
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('file profiles isolate favorites and survive reopening encrypted store', () async {
    SharedPreferences.setMockInitialValues({});
    final secure = SecureSession();
    final store = await PrefsStore.create(secureSession: secure);
    final config = ConfigController(store: store, bundledJson: {'xtream': {'server': 'https://brand.example'}});
    await config.load();
    final app = AppState(store, config);
    await app.restore();
    const a = IptvProfile(id: 'a', name: 'A', source: ProfileSource.playlist, server: '',
      playlistText: '#EXTM3U\n#EXTINF:-1,Canal A\nhttps://video.example/a.m3u8');
    const b = IptvProfile(id: 'b', name: 'B', source: ProfileSource.playlist, server: '',
      playlistText: '#EXTM3U\n#EXTINF:-1,Canal B\nhttps://video.example/b.m3u8');
    await app.addProfile(a); await app.addProfile(b);
    expect(await app.activateProfile(a), isTrue);
    final channel = (await app.client.items(MediaKind.live)).single;
    await app.toggleFavorite(channel);
    expect(app.favorites.length, 1);
    expect(await app.activateProfile(b), isTrue);
    expect(app.favorites, isEmpty);
    expect(await app.activateProfile(a), isTrue);
    expect(app.favorites.single.name, 'Canal A');
    expect(app.playableFrom(app.favorites.single)?.url, 'https://video.example/a.m3u8');
    await app.logout();
    final restored = AppState(store, config);
    await restored.restore();
    expect(restored.profiles.length, 2);
    expect(restored.isLoggedIn, isFalse); // Explicit profile choice after restarting.
    expect(await restored.activateProfile(a), isTrue);
    expect(restored.favorites.single.name, 'Canal A');
    await restored.removeProfile('a');
    expect(restored.favorites, isEmpty);
    expect(restored.profiles.length, 1);
    app.dispose(); restored.dispose(); config.dispose();
  });
}
