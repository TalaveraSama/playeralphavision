import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xtream_player/core/config/app_config.dart';
import 'package:xtream_player/core/storage/prefs_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('flags antiguos no habilitan motores eliminados', () {
    final config = FeaturesConfig.fromJson(<String, dynamic>{
      'vlcPlayer': true, 'dkPlayer': true, 'search': false,
    });
    expect(config.search, isFalse);
    expect(config.toJson().containsKey('vlcPlayer'), isFalse);
    expect(config.toJson().containsKey('dkPlayer'), isFalse);
  });
  test('preferencias antiguas no afectan subtítulos ni búfer', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'player.engine': 'vlc', 'player.video_decoder': 'software',
      'player.subtitle_color': '#FFFF00', 'player.subtitle_size': 32.0,
    });
    final store = await PrefsStore.create();
    expect(store.subtitleColor, '#FFFF00');
    expect(store.subtitleSize, 32);
  });
}
