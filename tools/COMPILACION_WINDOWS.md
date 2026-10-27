# Corrección del registro de compilación en Windows

El mensaje `Built ... app-release.apk (269.4MB)` confirma que el APK universal
se generó. `NativeCommandError` alrededor de un `WARNING` de Java no demuestra
un fallo de Gradle: PowerShell 5.1 formateaba stderr como un error de PowerShell.
El paso siguiente, `Compilando APK por arquitectura`, es una segunda compilación
y puede tardar varios minutos sin imprimir nada mientras se guarda el registro.

## Actualizar sin tocar la marca

Copia estos archivos del parche a la carpeta `tools` de tu proyecto:

- `build_whitelabel.ps1` (reemplazar).
- `flutter_logged.ps1` (nuevo, necesario).
- `test_build_logging.ps1` (prueba opcional).

No reemplaces `admin_panel/config.json`, `assets/config.json`, claves de firma ni
ajustes de marca. Ejecuta el mismo generador de APK que usabas antes.
La versión de la app sigue siendo 1.2.42+1046: este parche solo cambia herramientas.

## Qué cambia

- `cmd.exe` redirige stdout y stderr antes de que PowerShell los interprete.
  Los avisos se conservan como texto, sin el bloque rojo `NativeCommandError`.
- El código de salida real sigue determinando el éxito o fallo; no se ocultan
  errores reales ni se cambia Java, Gradle, Kotlin o los motores del player.
- El script se guarda con BOM UTF-8 y lee JSON/logs como UTF-8 para PowerShell 5.1.
- Se preserva la universal antes de iniciar split ABI. Si split falla, se entrega
  la universal y se indica el registro del fallo, sin copiar variantes parciales.
- Se limpian las salidas de esta misma marca/versión en `dist` para no repartir
  variantes anteriores si hoy no se pudieron generar.
- Registros separados en `build`:
  - `whitelabel-flutter-version.log`
  - `whitelabel-pub-get.log`
  - `whitelabel-build.log` (universal)
  - `whitelabel-split-abi.log` (por arquitectura)

Para ver el progreso del segundo paso desde otra ventana de PowerShell:

```powershell
Get-Content .\build\whitelabel-split-abi.log -Tail 30 -Wait -Encoding UTF8
```

Los avisos de acceso nativo de Java y de KGP de `flutter_vlc_player` pueden seguir
apareciendo: son avisos reales de compatibilidad futura, no errores actuales en
el registro recibido. No hace falta quitar VLC ni actualizar 36 paquetes para
solucionar la presentación de stderr. El parche no intenta ocultar esos avisos.

## Comprobación sin SDK (Windows)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\test_build_logging.ps1
```

La prueba crea un Flutter simulado en una ruta con espacios y `&`, comprueba que
stdout/stderr se registran sin errores PowerShell y verifica los códigos 0 y 23.
No compila APK ni necesita Android SDK. Aquí solo se verificaron estructura y
sintaxis con parser; no hay Windows/PowerShell/Flutter para ejecutar esta prueba
ni verificar una compilación real. Ejecuta la prueba en Windows y después tu
compilación habitual.
