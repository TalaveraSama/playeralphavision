@echo off
setlocal
chcp 65001 >nul
title Generar APK - NOVA

for %%I in ("%~dp0..") do set "PROJECT=%%~fI"
cd /d "%PROJECT%"

echo ============================================================
echo  NOVA - generar APK con el diseno nuevo
echo  Proyecto: %PROJECT%
echo ============================================================
echo.

powershell -ExecutionPolicy Bypass -File "%PROJECT%\tools\build_whitelabel.ps1" ^
  -ConfigPath "%PROJECT%\admin_panel\config.json" -SplitAbi

echo.
echo Los APK quedan en la carpeta dist\
pause
endlocal
