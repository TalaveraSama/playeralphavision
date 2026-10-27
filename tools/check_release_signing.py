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

assistant = (root / 'tools/setup_android_signing.ps1').read_text()
assert 'Read-Host $Prompt -AsSecureString' in assistant
assert '-storepass:env' in assistant and '-keypass:env' in assistant
assert '[IO.File]::Move($tempKey, $KeystorePath)' in assistant
assert '[IO.File]::Move($tempProperties, $propertiesPath)' in assistant
assert 'Test-Path -LiteralPath $propertiesPath' in assistant
assert '[Environment]::SetEnvironmentVariable($secretName, $null' in assistant
assert 'ZeroFreeBSTR' in assistant
assert '-storepass $password' not in assistant
print('OK: setup assistant uses hidden prompts, env passwords, refusal/atomic moves and cleanup (static checks).')

assert "'-J-Duser.language=en'" in assistant
assert "'-J-Duser.country=US'" in assistant
assert "@('-list', '-v'" not in assistant
assert assistant.index('[IO.File]::Move($tempKey, $KeystorePath)') < assistant.index("@('-list', '-keystore'")
assert '@($tempKey, $tempProperties)' not in assistant
print('OK: English Java locale, non-verbose verification, generated private keys retained on failures.')
