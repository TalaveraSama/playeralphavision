"""Static checks only, not proof of on-device security or panel acceptance."""
from pathlib import Path
import xml.etree.ElementTree as ET
root = Path(__file__).resolve().parents[1]
def text(path): return (root / path).read_text()
native = 'android/app/src/main/kotlin/com/xtreamplayer/xtream_player/'
store = text(native + 'SecureSessionHost.kt')
assert 'EncryptedSharedPreferences.create' in store and 'AES256_GCM' in store
assert '"PA-"' in store and 'MessageDigest.getInstance("SHA-256")' in store
assert 'instanceFollowRedirects = false' in store
assert 'useCaches = false' in store
assert 'HttpsURLConnection' in store
manifest = text('android/app/src/main/AndroidManifest.xml')
assert 'android:allowBackup="false"' in manifest and 'android:usesCleartextTraffic="false"' in manifest
config = ET.fromstring(text('android/app/src/main/res/xml/network_security_config.xml'))
assert all(el.attrib.get('cleartextTrafficPermitted') != 'true' for el in config.iter())
assert all(el.attrib.get('src') != 'user' for el in config.iter('certificates'))
api = text('lib/core/api/xtream_api.dart')
assert "'X-Device-Token': deviceToken" in api
player = text(native + 'Media3TexturePlayer.kt')
assert '.setDefaultRequestProperties(headers)' in player
assert 'setLoadErrorHandlingPolicy(policy)' in player and 'C.TIME_UNSET' in player
assert 'player.clearMediaItems()' in player
for path in (root / native).glob('*.kt'):
    assert 'android.util.Log.' not in path.read_text(), path
assert 'LOG_LEVEL_OFF' in text(native + 'MainActivity.kt')
page = text('lib/features/player/player_texture_page.dart')
assert "status == 429 || status == 503" in page and 'renewDevice:' in page
assert 'Duration(seconds: 90)' in page and 'await _checkHeartbeat()' in page
assert '_securityApp.removeListener(_sessionChanged)' in page
assert "if (uri.scheme != 'https')" in text('lib/core/api/xtream_client.dart')
print('OK: static secure storage, device headers, HTTPS, error/lifecycle gates and log checks')
if not config.findall('.//pin-set'):
    print('PENDING: real panel hostname + distinct current/backup SPKI pins; do not call this security-closed.')
