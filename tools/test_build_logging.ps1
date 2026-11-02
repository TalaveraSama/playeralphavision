#requires -Version 5.1
# Windows regression test: no Flutter, Java or Android SDK required.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'flutter_logged.ps1')
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('nova logging & paths ' + [guid]::NewGuid().ToString('N'))
$oldPath = $env:Path
try {
  New-Item -ItemType Directory -Path $tempRoot | Out-Null
  $fakeFlutter = Join-Path $tempRoot 'flutter.bat'
  $fakeScript = @'
@echo off
echo Built fake APK
echo ARGS: %*
echo WARNING: Java native access 1>&2
if "%1"=="--fail" exit /b 23
exit /b 0
'@
  [System.IO.File]::WriteAllText($fakeFlutter, $fakeScript.Replace("`r`n", "`n").Replace("`n", "`r`n"))
  # Reproduce a real Flutter SDK: Unix launcher plus .bat, and multiple SDKs.
  [IO.File]::WriteAllText((Join-Path $tempRoot 'flutter'), '# Unix launcher: must not execute on Windows')
  $secondSdk = Join-Path $tempRoot 'second sdk'
  New-Item -ItemType Directory -Path $secondSdk | Out-Null
  [IO.File]::WriteAllText((Join-Path $secondSdk 'flutter.bat'), "@echo off`r`nexit /b 99`r`n")
  $env:Path = "$tempRoot;$secondSdk;$oldPath"
  $log = Join-Path $tempRoot 'build log.txt'
  $before = $Error.Count
  $code = Invoke-FlutterLogged -Arguments @('--version') -LogPath $log
  if ($code -ne 0) { throw "Version check with multiple Flutter launchers failed: $code" }
  $code = Invoke-FlutterLogged -Arguments @('build', 'apk', '--release') -LogPath $log
  if ($code -ne 0) { throw "Expected success, got $code" }
  $text = Get-Content -LiteralPath $log -Raw
  if ($text -notmatch 'WARNING: Java native access' -or $text -notmatch 'Built fake APK') { throw 'Missing stdout/stderr' }
  if ($text -match 'NativeCommandError|CategoryInfo') { throw 'PowerShell error formatting leaked into log' }
  if ($Error.Count -ne $before) { throw 'Warnings created PowerShell errors' }
  $code = Invoke-FlutterLogged -Arguments @('build', 'apk', '--release', '--target-platform', 'android-arm,android-arm64,android-x64') -LogPath $log
  if ($code -ne 0) { throw "Universal platform list failed: $code" }
  $text = Get-Content -LiteralPath $log -Raw
  if (-not $text.Contains('ARGS: build apk --release --target-platform android-arm,android-arm64,android-x64')) {
    throw 'Platform list was not passed intact to flutter.bat'
  }
  foreach ($bad in @('android-arm&whoami', 'a|whoami', 'a>file', 'a%PATH%', 'a;whoami', '$(whoami)', 'a,,b', 'a, b', ',a', 'a,', "a`n")) {
    $rejected = $false
    try { $null = Invoke-FlutterLogged -Arguments @($bad) -LogPath $log }
    catch {
      if ($_.Exception.Message -notlike 'Unsupported Flutter argument:*') { throw }
      $rejected = $true
    }
    if (-not $rejected) { throw "Unsafe or malformed token accepted: $bad" }
  }
  $code = Invoke-FlutterLogged -Arguments @('--fail') -LogPath $log
  if ($code -ne 23) { throw "Expected failure code 23, got $code" }
  Write-Host 'PASS: platform lists, rejection of unsafe tokens, plain warnings, real exit codes and multiple Flutter launchers.'
} finally {
  $env:Path = $oldPath
  Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
