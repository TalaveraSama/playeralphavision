#requires -Version 5.1
# Execute Flutter through cmd so Java/Gradle stderr is redirected as plain text
# BEFORE PowerShell 5.1 can turn it into NativeCommandError records.
function Invoke-FlutterLogged {
  param(
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [Parameter(Mandatory = $true)][string]$LogPath
  )
  # Allow simple tokens and comma-separated platform lists, never shell syntax.
  foreach ($argument in $Arguments) {
    if ($argument -notmatch '\A[A-Za-z0-9_-]+(?:,[A-Za-z0-9_-]+)*\z') {
      throw "Unsupported Flutter argument: $argument"
    }
  }
  # Windows Flutter SDK contains both "flutter" (Unix launcher) and
  # "flutter.bat". Never interpolate the Source property of a command array:
  # PowerShell would send the literal "System.Object[]" to cmd.exe.
  $flutterCommand = Get-Command flutter.bat -CommandType Application -All -ErrorAction Stop |
    Select-Object -First 1
  [string]$flutterPath = $flutterCommand.Source
  if ([string]::IsNullOrWhiteSpace($flutterPath) -or
      -not (Test-Path -LiteralPath $flutterPath -PathType Leaf)) {
    throw 'No valid flutter.bat found. Check your Flutter SDK PATH.'
  }
  $fullLogPath = [System.IO.Path]::GetFullPath($LogPath)
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $fullLogPath) | Out-Null
  # Outer quotes are required by cmd /s /c when flutter.bat has a spaced path.
  $commandLine = '""{0}" {1} > "{2}" 2>&1"' -f $flutterPath, ($Arguments -join ' '), $fullLogPath
  # Also honor the actual native exit code when run from PowerShell 7.
  $PSNativeCommandUseErrorActionPreference = $false
  & $env:ComSpec /d /s /c $commandLine
  return $LASTEXITCODE
}
