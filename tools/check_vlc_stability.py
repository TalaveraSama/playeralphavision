"""Static policy check; does not measure playback or installation on Fire TV."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
s = (root/'android/app/src/main/kotlin/com/xtreamplayer/xtream_player/VlcTexturePlayer.kt').read_text()
assert 'private const val STABLE_NETWORK_CACHE_MS = 2000' in s
for prefix in ('--', ':'):
    for cache in ('network-caching', 'live-caching'):
        assert f'{prefix}{cache}=$STABLE_NETWORK_CACHE_MS' in s
assert 'caching=300' not in s
assert '--adaptive-maxbuffer=' in s
assert 'minSdk = 24' in (root/'android/app/build.gradle.kts').read_text()
print('OK: stable 2000ms VLC caches, independent HLS reserve and unchanged minimum SDK (static)')
