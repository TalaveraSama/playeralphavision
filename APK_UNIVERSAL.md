# 1.2.60+1064 — un único APK para móvil y TV

Usar **`admin_panel\Generar APK universal.cmd`** o **`admin_panel\Generar APK.cmd`**. Ambos generan por defecto un solo APK de release, firmado con la configuración existente. Se entrega en `dist\<marca>-1.2.60.apk`, sin sufijo `arm32`, `arm64` ni `x86_64`. La marca se normaliza para el nombre de archivo. No hace falta elegir arquitectura en cada dispositivo.

El APK incluye **armeabi-v7a (ARM de 32 bits), arm64-v8a (ARM de 64 bits) y x86_64**. El script pide explícitamente esas plataformas y comprueba dentro del ZIP del APK que estén `libflutter.so`, `libvlcjni.so` y `libvlc.so` para las tres. Si faltan, aborta sin entregar ese APK como universal. No es una prueba de reproducción ni comprueba todos los enlaces nativos en ejecución.

Se corrigió el comportamiento anterior que compilaba variantes separadas incluso al seleccionar universal. Ahora solo se generan si se invoca explícitamente el script PowerShell con `-SplitAbi`; los dos CMD habituales no lo activan. Se limpia el staging y las variantes de la misma marca/versión antes de entregar. Los APK de versiones anteriores que ya existan en `dist` no son entregas nuevas: distribuir únicamente el archivo de la versión actual.

## Compatibilidad prevista, no certificada por dispositivo

- Teléfonos/tabletas Android **9 o posterior**, con las arquitecturas incluidas.
- Android TV/Google TV compatibles con la app.
- Fire TV Stick/Cube con **Fire OS basado en Android y API 24 o superior**. Se conserva minSdk 24 para no excluir modelos compatibles anteriores a Android 9.
- No cubre Fire OS 5/Android 5, sistemas de Amazon no basados en Android, ni CPU de arquitecturas no incluidas. Un APK universal no elimina las diferencias de códecs/decodificadores/GPU entre equipos.
- Interfaz horizontal, funciones de mando y táctiles existentes; no se exige touchscreen ni Leanback como requisito de instalación.

**No se generó ni probó un APK aquí** (sin Flutter/JDK/SDK Android). Se revisó el script mediante checks estáticos. Se necesita compilar en Windows y probar en Fire TV, Android TV y teléfonos reales. Esto **no demuestra resuelto el cierre de VLC** reportado; si continúa, usar `admin_panel\Diagnosticar cierre VLC.cmd` y compartir el registro sin credenciales, junto con modelo y versión del sistema.

Mantener `applicationId`, configuración de marca, `android/key.properties` y la misma llave de firma para actualizar sin desinstalar.

## Corrección 1.2.60

El helper de ejecución rechazaba las comas del argumento `android-arm,android-arm64,android-x64` antes de arrancar Flutter. Ahora permite listas de tokens separadas por comas, sin admitir espacios ni metacaracteres de shell. Se ampliaron las pruebas Windows del helper para comprobar la lista completa y el rechazo de entradas peligrosas/malformadas. No se ejecutaron aquí esas pruebas Windows; se verificaron los patrones y checks estáticos.
