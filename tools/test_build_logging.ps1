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
echo WARNING: Java native access 1>&2
if "%1"=="--fail" exit /b 23
exit /b 0
'@
  [System.IO.File]::WriteAllText($fakeFlutter, $fakeScript.Replace("`n", "`r`n"))
  $env:Path = "$tempRoot;$oldPath"
  $log = Join-Path $tempRoot 'build log.txt'
  $before = $Error.Count
  $code = Invoke-FlutterLogged -Arguments @('build', 'apk', '--release') -LogPath $log
  if ($code -ne 0) { throw "Expected success, got $code" }
  $text = Get-Content -LiteralPath $log -Raw
  if ($text -notmatch 'WARNING: Java native access' -or $text -notmatch 'Built fake APK') { throw 'Missing stdout/stderr' }
  if ($text -match 'NativeCommandError|CategoryInfo') { throw 'PowerShell error formatting leaked into log' }
  if ($Error.Count -ne $before) { throw 'Warnings created PowerShell errors' }
  $code = Invoke-FlutterLogged -Arguments @('--fail') -LogPath $log
  if ($code -ne 23) { throw "Expected failure code 23, got $code" }
  Write-Host 'PASS: plain warnings, real exit codes, spaced paths and ampersands.'
} finally {
  $env:Path = $oldPath
  Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
