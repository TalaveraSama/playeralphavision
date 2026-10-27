import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xtream_player/core/utils/player_platform.dart';

void main() {
  test('iPhone nunca selecciona canales Media3/IJK/MPV exclusivos de Android', () {
    for (final saved in <String>['exo', 'ijk', 'mpv', 'vlc', '']) {
      expect(playerEngineForPlatform(saved, TargetPlatform.iOS), 'vlc');
    }
  });
  test('Android conserva todos sus motores y la preferencia guardada', () {
    for (final saved in <String>['exo', 'ijk', 'mpv', 'vlc']) {
      expect(playerEngineForPlatform(saved, TargetPlatform.android), saved);
    }
  });
}
