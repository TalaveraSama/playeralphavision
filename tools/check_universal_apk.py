"""Static checks only: does not build/execute PowerShell or validate a real APK."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
s = (root / 'tools/build_whitelabel.ps1').read_text(encoding='utf-8-sig')
assert "'--target-platform', 'android-arm,android-arm64,android-x64'" in s
assert 'if ($SplitAbi) {' in s
assert s.index('if ($SplitAbi) {') < s.index("'--split-per-abi'")
for name in ('libflutter.so', 'libvlcjni.so', 'libvlc.so'):
    assert name in s
assert '[System.IO.Compression.ZipFile]::OpenRead($universalApk)' in s
assert s.index('$archive.Dispose()') < s.index('Copy-Item -LiteralPath $universalApk')
for cmd in ('Generar APK.cmd', 'Generar APK universal.cmd'):
    assert '-SplitAbi' not in (root / 'admin_panel' / cmd).read_text()
assert 'minSdk = 24' in (root / 'android/app/build.gradle.kts').read_text()
print('OK: static single-APK default, explicit ARM32/ARM64/x86_64, native library verification and minSdk')
