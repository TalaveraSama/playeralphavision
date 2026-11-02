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
assert 'HttpURLConnection' in store
assert 'call.argument<Boolean>("allowHttp") == true' in store
manifest = text('android/app/src/main/AndroidManifest.xml')
assert 'android:allowBackup="false"' in manifest
assert 'android:usesCleartextTraffic="true"' in manifest
config = ET.fromstring(text('android/app/src/main/res/xml/network_security_config.xml'))
assert config.find('base-config').attrib['cleartextTrafficPermitted'] == 'true'
assert all(el.attrib.get('src') != 'user' for el in config.iter('certificates'))
api = text('lib/core/api/xtream_api.dart')
assert "'X-Device-Token': deviceToken" in api
player = text(native + 'VlcTexturePlayer.kt')
relay = text(native + 'VlcStreamGateway.kt')
assert 'conn.setRequestProperty(name, value)' in relay
assert 'report(conn, status)' in relay and 'errorSent' in player
assert 'gateway?.close()' in player
for path in (root / native).glob('*.kt'):
    assert 'android.util.Log.' not in path.read_text(), path
assert '"--quiet"' in player
page = text('lib/features/player/player_texture_page.dart')
assert "status == 429 || status == 503" in page and 'renewDevice:' in page
assert 'Duration(seconds: 90)' in page and 'await _checkHeartbeat()' in page
assert '_securityApp.removeListener(_sessionChanged)' in page
assert "!(api.allowHttp && uri.scheme == 'http')" in text('lib/core/api/xtream_client.dart')
state = text('lib/core/state/app_state.dart')
assert '_profileSource != ProfileSource.tvlister' in state
assert 'allowHttp && url.protocol == "http"' in relay
assert 'url.protocol == "https" && next.protocol != "https"' in relay
print('OK: static secure storage, device headers, HTTPS, error/lifecycle gates and log checks')
if not config.findall('.//pin-set'):
    print('PENDING: real panel hostname + distinct current/backup SPKI pins; do not call this security-closed.')
