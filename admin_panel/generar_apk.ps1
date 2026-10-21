#requires -Version 5.1
<#
.SYNOPSIS
  Genera el APK de marca blanca sin discusiones de rutas.

.DESCRIPTION
  Es un atajo del script principal: se puede ejecutar desde cualquier carpeta,
  también haciendo doble clic desde el Explorador de Windows.

.EXAMPLE
  Doble clic en este archivo, o desde PowerShell:
  powershell -ExecutionPolicy Bypass -File .\admin_panel\generar_apk.ps1
#>
$ErrorActionPreference = 'Stop'

$here = $PSScriptRoot
if ([string]::IsNullOrEmpty($here)) { $here = (Get-Location).Path }
$projectRoot = Split-Path -Parent $here

$script = Join-Path $projectRoot 'tools\build_whitelabel.ps1'
if (-not (Test-Path -LiteralPath $script)) {
  Write-Host "No encuentro $script" -ForegroundColor Red
  Write-Host 'Comprueba que este archivo sigue dentro de la carpeta admin_panel.' -ForegroundColor Gray
  exit 1
}

Write-Host 'Generando el APK de tu marca...' -ForegroundColor Cyan
Write-Host "Proyecto: $projectRoot" -ForegroundColor Gray
Write-Host ''

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $script -SplitAbi
$code = $LASTEXITCODE

Write-Host ''
if ($code -eq 0) {
  Write-Host "Listo. Los APK están en: $projectRoot\dist" -ForegroundColor Green
} else {
  Write-Host "Algo falló (código $code). Revisa los mensajes de arriba." -ForegroundColor Red
}
exit $code
