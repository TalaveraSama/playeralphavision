"""Static removal/security regression check, not a packet-capture resistance test."""
from pathlib import Path
import re
import xml.etree.ElementTree as ET
root = Path(__file__).resolve().parents[1]
for folder, suffix in [('lib', '.dart'), ('android/app/src/main/kotlin', '.kt')]:
    for path in (root / folder).rglob('*' + suffix):
        assert not re.search(r'get_drm|checkMediaDrm|DrmConfiguration|clearkey|widevine|playready', path.read_text(), re.I), path
activity = (root / 'android/app/src/main/kotlin/com/xtreamplayer/xtream_player/MainActivity.kt').read_text()
assert 'window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)' in activity
xml = ET.parse(root / 'android/app/src/main/res/xml/network_security_config.xml').getroot()
required = {'tvadmin.alphadigitalnic.xyz', 'live-stream.alphadigitalnic.xyz'}
protected = {d.text for c in xml.findall('domain-config') if c.get('cleartextTrafficPermitted') == 'false' for d in c.findall('domain')}
assert required <= protected
print('OK: no app DRM integration; secure window and brand HTTPS-only domain policies (static)')
