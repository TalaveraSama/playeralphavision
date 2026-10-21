# aapanel-novatv · panel de NOVA TV

Panel con **PHP**: guarda la configuración y los APK **en el servidor**. Todo lo
que necesita está en esta carpeta.

## Flujo de trabajo (paso a paso)

1. **Editas en el panel** (marca, colores, anuncios…) y pulsas **Guardar en el
   servidor**. Eso deja `config.json` en tu web: es lo que descargan las apps ya
   instaladas al arrancar (anuncios, avisos, versión…). No hay que recompilar.
2. **Para hacer un APK nuevo**: pulsa **Descargar config.json** y guarda ese
   archivo como `assets\config.json` dentro de `nova_tv\` (con la URL del panel
   ya puesta en `remoteConfigUrl`).
3. **Compilas en Windows**: `Generar APK.cmd` → el APK sale en `dist\`.
4. **Subes el APK** en la pestaña *Versión y APK* → se publica solo con la
   versión siguiente.
5. Listo: las apps instaladas avisan de la actualización y descargan ese APK.

Después de la primera compilación, el día a día son **solo los pasos 1 y 4**
(anuncios y versiones nuevos) — sin tocar el proyecto ni recompilar para los
anuncios.

```
aapanel-novatv/
  index.php      el panel
  config.json    lo crea/actualiza él solo (la app lo descarga)
  updates/       aquí se guardan los APK (lo crea él solo)
```

## 1. Subirlo a aaPanel

1. aaPanel → **Website** → tu sitio → **File** → entra en la carpeta pública
   (por ejemplo `www/tusitio/web` o `www/carpetaanel/web`).
2. Sube la carpeta `aapanel-novatv` completa.
3. Permisos de escritura para el usuario del sitio (`www`) en la carpeta:
   `chown -R www:www aapanel-novatv` y `chmod -R 775 aapanel-novatv`
   (si no, no podrá guardar `config.json` ni subir APK).
4. Abre `https://tudominio.com/aapanel-novatv/` en el navegador.
5. Opcional: en `index.php`, pon una clave en `$KEY = 'tu-clave';` y entra con
   `.../aapanel-novatv/index.php?k=tu-clave`. También puedes proteger la carpeta
   con contraseña desde aaPanel.

## 2. Enlazar la app con el panel (una sola vez)

En el proyecto de la app (`assets/config.json`) pon:

```json
"remoteConfigUrl": "https://tudominio.com/aapanel-novatv/config.json"
```

y compila. La app descargará ese archivo al arrancar. A partir de ahí, **todo lo
que cambies en el panel** (colores, anuncios, versión…) llega a las apps
instaladas sin volver a compilar.

## 3. Actualizaciones (siguiente versión automática)

1. Compila el APK en Windows (abajo) y entra en la pestaña **Versión y APK**.
2. Elige el `.apk` y pulsa **Subir y publicar**.
3. El panel lo guarda como `updates/nova-<siguiente>.apk` (1.2.0 → **1.2.1**),
   escribe `latestVersion` y `apkUrl`, y activa el aviso.
4. Las apps instaladas, al arrancar, ven que hay versión nueva y ofrecen
   descargar el APK. Si marcas **Obligatoria**, no dejan continuar sin actualizar.
5. Con la tabla **APK en el servidor** puedes volver a publicar o borrar
   cualquier versión anterior.

## 4. Generar el APK en Windows (qué se necesita)

Requisitos (una sola vez):

- **Windows 10/11** de 64 bits.
- **Flutter SDK** (en este equipo: `C:\src\flutter`). Comprueba con
  `flutter doctor` desde una consola nueva.
- **JDK 17** (el que trae Android Studio vale) y **Android SDK** con
  *platform-tools* y *build-tools*; `ANDROID_HOME` configurado.
  En este equipo el SDK está en `%LOCALAPPDATA%\Android\Sdk`.
- **Git** (Flutter lo necesita; aquí está portable en `C:\src\PortableGit`).

Compilar:

```bat
cd C:\Users\Dororo\Documents\deepseek-harness\ott_apixcode\nova_tv
flutter pub get
Generar APK.cmd
```

El APK queda en `dist\` (y el de depuración en
`build\app\outputs\flutter-apk\app-debug.apk`). Para probarlo rápido:

```bat
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

> Para publicar en Google Play o en tu web hay que firmar con un almacén de
> claves propio: crea el `.jks`, sustituye la firma `debug` en
> `android/app/build.gradle.kts` (bloque `buildTypes → release`) y vuelve a
> generar con `Generar APK.cmd`.

## 5. Identificador de la app

`com.nova.ott`. Si ya tienes otra app instalada con otro identificador, cada
una se instala por su cuenta; si cambias de identificador, el móvil la trata
como una app nueva.

## 6. Seguridad

- El panel **pide clave** para entrar (constante `$PASSWORD` dentro de
  `index.php`: cámbiala por la tuya y vuelve a subir el archivo). La sesión dura
  12 horas y se cierra con el enlace **Salir**.
- Tras **6 intentos fallidos** se bloquea 15 minutos.
- Recomendado: activar **HTTPS** en el sitio (aaPanel → SSL) y, para doble
  barrera, proteger la carpeta con contraseña desde aaPanel
  (Website → tu sitio → Password protection).
- `config.json` y `updates/*.apk` siguen siendo públicos a propósito: son los que
  descargan la app y las actualizaciones. Lo privado es el panel (`index.php`).