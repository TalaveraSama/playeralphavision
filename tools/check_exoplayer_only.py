"""Static architecture checks. Does not replace Flutter/Gradle/device tests."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
for filename in ['pubspec.yaml', 'pubspec.lock', 'android/app/build.gradle.kts']:
    text = (root / filename).read_text()
    for package in ['fijkplayer', 'flutter_vlc', 'media_kit', 'nextlib', 'com.befovy']:
        assert package not in text, (filename, package)
for folder in ['lib', 'android/app/src/main/kotlin']:
    for file in (root / folder).rglob('*'):
        if file.suffix in ['.dart', '.kt']:
            text = file.read_text()
            for token in ['PlayerVlcPage', 'PlayerMpvPage', 'PlayerNativeIjkPage',
                          'NextRenderersFactory', 'IjkPlayerHost', 'setDecoderMode']:
                assert token not in text, (file, token)
player = (root / 'lib/features/player/open_player.dart').read_text()
assert player.count('PlayerTexturePage(') == 1
assert 'Platform.isAndroid' in player
assert "pop('mpv')" not in (root / 'lib/features/player/player_texture_page.dart').read_text()
native = (root / 'android/app/src/main/kotlin/com/xtreamplayer/xtream_player/Media3TexturePlayer.kt').read_text()
assert 'DefaultRenderersFactory(context)' in native
assert 'EXTENSION_RENDERER_MODE_OFF' in native
assert 'override fun onCues' in native
assert 'PlayerSubtitles(' in (root / 'lib/features/player/player_texture_page.dart').read_text()
print('OK: one Android ExoPlayer route, removed engines/dependencies, subtitle bridge retained')
