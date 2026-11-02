@echo off
setlocal
chcp 65001 >nul
title Generar APK - NOVA

for %%I in ("%~dp0..") do set "PROJECT=%%~fI"
cd /d "%PROJECT%"

echo ============================================================
echo  APK UNIVERSAL - un solo archivo para movil y TV
echo  Proyecto: %PROJECT%
echo ============================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJECT%\tools\build_whitelabel.ps1" ^
  -ConfigPath "%PROJECT%\admin_panel\config.json"

set "RESULT=%ERRORLEVEL%"
echo.
if not "%RESULT%"=="0" (
  echo ERROR: no se completo la generacion. Revisa el mensaje anterior.
  echo No se confirma ningun APK nuevo; puede haber archivos de ejecuciones anteriores en dist\.
) else (
  echo Generacion completada. El APK universal esta en dist\.
)
pause
endlocal & exit /b %RESULT%
