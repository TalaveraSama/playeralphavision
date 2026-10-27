#requires -Version 5.1
# Execute Flutter through cmd so Java/Gradle stderr is redirected as plain text
# BEFORE PowerShell 5.1 can turn it into NativeCommandError records.
function Invoke-FlutterLogged {
  param(
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [Parameter(Mandatory = $true)][string]$LogPath
  )
  # These are switches/subcommands, not an arbitrary shell command.
  foreach ($argument in $Arguments) {
    if ($argument -notmatch '^[A-Za-z0-9_-]+$') {
      throw "Unsupported Flutter argument: $argument"
    }
  }
  $flutterPath = (Get-Command flutter -CommandType Application -ErrorAction Stop).Source
  $fullLogPath = [System.IO.Path]::GetFullPath($LogPath)
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $fullLogPath) | Out-Null
  # Outer quotes are required by cmd /s /c when flutter.bat has a spaced path.
  $commandLine = '""{0}" {1} > "{2}" 2>&1"' -f $flutterPath, ($Arguments -join ' '), $fullLogPath
  # Also honor the actual native exit code when run from PowerShell 7.
  $PSNativeCommandUseErrorActionPreference = $false
  & $env:ComSpec /d /s /c $commandLine
  return $LASTEXITCODE
}
