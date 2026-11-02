"""Static Windows ZIP-overlay regression checks; not a PowerShell/Gradle run."""
from pathlib import Path
root = Path(__file__).resolve().parents[1]
build = (root / 'tools/build_whitelabel.ps1').read_text(encoding='utf-8-sig')
for name in ('VlcPlayerHost.kt', 'VlcTexturePlayer.kt', 'VlcStreamGateway.kt',
             'Media3TexturePlayer.kt', 'Media3PlayerHost.kt'):
    assert name in build
assert 'Rename-Item -LiteralPath $obsoletePath -NewName $backupName -ErrorAction Stop' in build
assert "'.bak-vlc-'" in build
assert build.index('Rename-Item -LiteralPath $obsoletePath') < build.index("Info 'Compilando APK universal")
assert '[Guid]::NewGuid()' in build
cmd = (root / 'admin_panel/Generar APK universal.cmd').read_text()
assert 'set "RESULT=%ERRORLEVEL%"' in cmd
assert 'if not "%RESULT%"=="0"' in cmd
assert 'endlocal & exit /b %RESULT%' in cmd
assert 'echo Listo.' not in cmd
gradle = (root / 'android/app/build.gradle.kts').read_text()
assert 'Mixed source versions' in gradle
assert 'implementation("androidx.media3:' not in gradle
print('OK: static ZIP-overlay backup, incomplete-update guard and universal CMD failure handling')
