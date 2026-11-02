"""Static architecture checks, not an Android build/performance test."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
base = root / 'android/app/src/main/kotlin/com/xtreamplayer/xtream_player'
gradle = (root / 'android/app/build.gradle.kts').read_text()
assert 'org.videolan.android:libvlc-all:3.6.3' in gradle
assert 'implementation("androidx.media3:' not in gradle
assert not list(base.glob('Media3*.kt'))
for path in base.glob('*.kt'):
    assert 'import androidx.media3' not in path.read_text()
page = (root / 'lib/features/player/player_texture_page.dart').read_text()
assert "MethodChannel('vlc_player')" in page
assert "MethodChannel('vlc_player_$id')" in page
native = (base / 'VlcTexturePlayer.kt').read_text()
for marker in ['LibVLC(context', 'setVideoSurface', 'setHWDecoderEnabled', 'player.setSpuTrack', 'VlcStreamGateway', 'entry.release()']:
    assert marker in native, marker
relay = (base / 'VlcStreamGateway.kt').read_text()
assert 'InetAddress.getByName("127.0.0.1")' in relay
assert 'URI=' in relay and 'instanceFollowRedirects = false' in relay
assert 'origin(url) == trustedPanelOrigin' in relay
assert 'profile' in (root / 'lib/features/player/player_texture_page.dart').read_text().lower() or 'AppState' in page
print('OK: VLC is the only IPTV engine; direct Media3 removed. video_player/ExoPlayer may remain for video ads.')
