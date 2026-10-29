import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xtream_player/core/models/video_decode_mode.dart';
import 'package:xtream_player/core/storage/prefs_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('modo seguro para valores ausentes/desconocidos', () {
    expect(VideoDecodeMode.parse(null), VideoDecodeMode.auto);
    expect(VideoDecodeMode.parse('ffmpeg'), VideoDecodeMode.auto);
    expect(VideoDecodeMode.parse('hardware'), VideoDecodeMode.hardware);
    expect(VideoDecodeMode.parse('software'), VideoDecodeMode.software);
  });
  test('guarda la elección sin reutilizar preferencias del motor retirado', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{'player.video_decoder': 'software'});
    final store = await PrefsStore.create();
    expect(store.videoDecodeMode, VideoDecodeMode.auto);
    for (final mode in VideoDecodeMode.values) {
      await store.saveVideoDecodeMode(mode);
      expect((await PrefsStore.create()).videoDecodeMode, mode);
    }
  });
}
