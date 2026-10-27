"""Static regression checks; not a Gradle execution or signature verification."""
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parents[1]
gradle = (root / 'android/app/build.gradle.kts').read_text()
assert 'signingConfigs.getByName("debug")' not in gradle
assert 'signingConfigs.getByName("production")' in gradle
assert 'gradle.taskGraph.whenReady' in gradle
assert 'throw GradleException' in gradle
assert 'releaseKeystore?.isFile == true' in gradle
assert 'storePassword' in gradle and 'keyPassword' in gradle
for name in ['android/key.properties', 'android/app/local-test.jks', 'local-test.keystore']:
    result = subprocess.run(['git', 'check-ignore', '-q', name], cwd=root)
    assert result.returncode == 0, f'Signing secret not ignored: {name}'
print('OK: release has no debug fallback, credentials are checked, signing files ignored.')
