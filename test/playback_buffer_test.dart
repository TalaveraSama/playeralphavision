import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xtream_player/core/models/playback_buffer.dart';
import 'package:xtream_player/core/storage/prefs_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('solo ofrece 10, 20 y 30 segundos; valores inválidos usan 10', () {
    expect(PlaybackBuffer.options, <int>[10, 20, 30]);
    for (final value in <int?>[null, -1, 0, 8, 32, 64, 999]) {
      expect(PlaybackBuffer.normalize(value), 10);
    }
    expect(PlaybackBuffer.normalize(20), 20);
    expect(PlaybackBuffer.normalize(30), 30);
  });
  test('los MB antiguos no se interpretan como segundos y la selección persiste', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{'player.buffer_mb': 64});
    final store = await PrefsStore.create();
    expect(store.bufferSeconds, 10);
    for (final value in PlaybackBuffer.options) {
      await store.saveBufferSeconds(value);
      expect((await PrefsStore.create()).bufferSeconds, value);
    }
    await store.saveBufferSeconds(999);
    expect(store.bufferSeconds, 10);
  });
}
