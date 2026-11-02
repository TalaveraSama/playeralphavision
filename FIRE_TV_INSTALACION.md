# Fire TV: «App no instalada» y estabilidad — 1.2.61+1065

## Reproducción estable

Caché de red y live de VLC: **2000 ms (2 segundos)**, tanto en la instancia como en cada medio. Se abandona la configuración agresiva de 300 ms. Puede aumentar el tiempo de arranque y la latencia; no garantiza eliminar cortes ni recupera paquetes perdidos. La reserva máxima adaptativa HLS 10/20/30 segundos sigue siendo independiente. No es transcodificación ni una espera obligatoria de 10–30 segundos.

## La instalación es un problema separado

«App no instalada» no identifica la causa. No lo corrige la caché de VLC. El APK universal incluye ARM32/ARM64/x86_64; mantener la misma marca, identificador y llave de firma. No desinstalar ni cambiar el identificador para ocultar el problema: se pueden perder sesiones/configuración y la capacidad de actualizar instalaciones anteriores.

Este proyecto mantiene **minSdk 24** por los requisitos actuales de Flutter/plugins. Teléfonos Android 9+ quedan dentro de ese mínimo. Fire TV requiere Fire OS basado en Android con API 24 o superior; Fire OS 5 (Android 5/API 22) no es compatible con esta compilación. No se debe bajar el mínimo sin migrar y comprobar todo el stack. Los dispositivos Amazon que no ejecutan Android tampoco aceptan este APK.

## Obtener el motivo exacto con Android SDK Platform-Tools

Activar depuración ADB y autorizar el equipo. Para Wi-Fi, conectar primero con `adb connect IP_DEL_FIRE_TV:5555` usando la IP real. Conectar **solo el equipo afectado**, o usar `adb -s SERIAL` en cada comando si hay varios.

```bat
adb devices
adb shell getprop ro.product.model
adb shell getprop ro.build.version.sdk
adb shell getprop ro.product.cpu.abilist
adb shell dumpsys package com.alphavision.ott | findstr versionCode
adb install -r "dist\Alpha-Vision-1.2.61.apk"
```

Ajustar el nombre/ruta al archivo universal realmente generado y el identificador si la marca es distinta. `install -r` intenta actualizar conservando datos; no usar `-d`, no borrar la app ni cambiar la firma como primer paso. Enviar la línea `Failure [INSTALL_FAILED_...]`, modelo y API, sin credenciales.

| Resultado | Qué revisar |
|---|---|
| `INSTALL_FAILED_OLDER_SDK` | API del Fire TV inferior al mínimo; este APK no sirve en ese modelo/OS. |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | La app instalada y la actualización no tienen la misma firma. Usar la llave original. |
| `INSTALL_FAILED_VERSION_DOWNGRADE` | El versionCode instalado es mayor, posible al pasar de APK por ABI a universal. Comparar el valor real antes de decidir el próximo código de actualización. |
| `INSTALL_FAILED_NO_MATCHING_ABIS` | Arquitectura no incluida o se transfirió un APK incorrecto/incompleto. Usar el universal verificado. |
| `INSTALL_FAILED_INSUFFICIENT_STORAGE` | Liberar espacio de forma segura. |
| `INSTALL_PARSE_FAILED_*` / `INSTALL_FAILED_INVALID_APK` | Revisar el código completo, integridad de la transferencia y firma del archivo. |

No hay prueba de instalación ni reproducción en Fire TV ejecutada en este entorno. El perfil de estabilidad y sus checks son cambios de fuente; el diagnóstico del rechazo de instalación sigue pendiente del resultado real del dispositivo.
