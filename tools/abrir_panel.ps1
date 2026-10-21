#requires -Version 5.1
<#
.SYNOPSIS
  Abre el panel de administración en el navegador.
#>
$toolsDir = $PSScriptRoot
if ([string]::IsNullOrEmpty($toolsDir)) { $toolsDir = (Get-Location).Path }
$projectRoot = Split-Path -Parent $toolsDir

$panel = Join-Path $projectRoot 'admin_panel\index.html'
if (-not (Test-Path -LiteralPath $panel)) {
  Write-Host "No encuentro $panel" -ForegroundColor Red
  exit 1
}

Write-Host 'Abriendo el panel de administración...' -ForegroundColor Cyan
Write-Host 'Edita tu marca, pulsa "Guardar config.json" y elige la carpeta admin_panel.' -ForegroundColor Gray
Write-Host 'Después ejecuta:  powershell -ExecutionPolicy Bypass -File .\tools\build_whitelabel.ps1' -ForegroundColor Gray
Start-Process $panel
