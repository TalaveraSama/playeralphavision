@echo off
setlocal
chcp 65001 >nul
title NOVA - crear firma de produccion
for %%I in ("%~dp0..") do set "PROJECT=%%~fI"
cd /d "%PROJECT%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%PROJECT%\tools\setup_android_signing.ps1"
set "RESULT=%ERRORLEVEL%"
echo.
if not "%RESULT%"=="0" echo No se completo la configuracion. Revisa el mensaje anterior.
pause
endlocal & exit /b %RESULT%
