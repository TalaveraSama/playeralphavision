@echo off
setlocal
chcp 65001 >nul
title Generar APK universal - NOVA

for %%I in ("%~dp0..") do set "PROJECT=%%~fI"
cd /d "%PROJECT%"

echo ============================================================
echo  APK UNIVERSAL - un solo archivo para TODO
echo  Fire TV Stick / Cube, TV box y telefonos Android
echo  Proyecto: %PROJECT%
echo ============================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJECT%\tools\build_whitelabel.ps1" ^
  -ConfigPath "%PROJECT%\admin_panel\config.json"

echo.
echo Listo. Los APK estan en la carpeta dist\:
echo   - Alpha-Vision-<version>.apk        universal (arm32 + arm64 + x86_64, ~140 MB)
echo   - Alpha-Vision-<version>-arm32.apk  Fire TV Stick / TV box 32 bits (~41 MB)
echo   - Alpha-Vision-<version>-arm64.apk  64 bits (~46 MB)
echo   - Alpha-Vision-<version>-x86_64.apk emuladores (~57 MB)
pause
endlocal
