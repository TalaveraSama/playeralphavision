"""Architecture regression checks; not substitutes for Flutter/Android tests."""
from pathlib import Path
r = Path(__file__).resolve().parents[1]
def read(p): return (r / p).read_text()
s = read('lib/core/state/app_state.dart')
for token in ['profiles.state', '_snapshotProfile()', 'CatalogCache.clear()',
              'ProfileSource.playlist', '_profileSource != ProfileSource.tvlister',
              'if (!usesDeviceSecurity) return;', 'await logout(switchingProfile: true)']:
    assert token in s, token
page = read('lib/features/profiles/profiles_page.dart')
assert 'Autorizar HTTP' in page and 'showDialog<bool>' in page
assert "MethodChannel('alphavision/playlists')" in page
assert "'profiles.state'" in s
native = 'android/app/src/main/kotlin/com/xtreamplayer/xtream_player/'
assert '"profiles.state"' in read(native + 'SecureSessionHost.kt')
assert 'ACTION_OPEN_DOCUMENT' in read(native + 'MainActivity.kt')
assert 'HTTP no autorizado para este perfil' in read(native + 'Media3TexturePlayer.kt')
assert '.setAllowCrossProtocolRedirects(false)' in read(native + 'Media3TexturePlayer.kt')
assert "item.directUrl ?? api.liveUrl" in s
print('OK: encrypted profiles, isolated state, external provider policy, guarded HTTP and native import (static)')
