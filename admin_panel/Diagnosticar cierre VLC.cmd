@echo off
setlocal
chcp 65001 >nul
where adb >nul 2>&1
if errorlevel 1 (
  if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
    set "PATH=%LOCALAPPDATA%\Android\Sdk\platform-tools;%PATH%"
  ) else (
    echo No se encuentra adb. Instala Android SDK Platform-Tools.
    pause
    exit /b 1
  )
)
echo Conecta SOLO el dispositivo afectado con depuracion ADB autorizada.
echo Abre la app e intenta reproducir un stream ANTES de continuar.
pause
for %%I in ("%~dp0..") do set "PROJECT=%%~fI"
if not exist "%PROJECT%\build" mkdir "%PROJECT%\build"
adb devices
adb logcat -b crash -d -v threadtime > "%PROJECT%\build\vlc-crash.log" 2>&1
adb logcat -d -v threadtime -s AlphaVisionVLC:E >> "%PROJECT%\build\vlc-crash.log" 2>&1
echo Registro: %PROJECT%\build\vlc-crash.log
echo Revisa el archivo y oculta URLs de cuenta, usuarios, claves y tokens antes de compartirlo.
echo Si hay varios equipos conectados, usa adb -s SERIAL manualmente.
echo Si esta vacio, revisa que la depuracion este autorizada y que reprodujiste el fallo.
pause
endlocal
