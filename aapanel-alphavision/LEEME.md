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
5. Cambia `$PASSWORD` en `index.php` antes de publicarlo. Al reemplazar una
   versión anterior, conserva tu contraseña personalizada. El panel usa inicio
   de sesión; también puedes proteger la carpeta desde aaPanel.

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

## Temas NOVA, Nova2 y Nova3 — actualización del index

La APK **no contiene el panel web de administración**. Incluye Perfil/Ajustes y
un selector local de apariencia. El panel de administración es este `index.php`
que se instala en tu servidor PHP y publica `config.json` para las APK enlazadas.

Para actualizar un panel que solo muestra NOVA y Ámbar:

1. Guarda una copia de tu `index.php` y `config.json` actuales.
2. En el nuevo `index.php`, conserva tu `$PASSWORD` personalizado.
3. Sustituye **solo `index.php`** en la carpeta del panel de aaPanel. No borres
   `config.json`, `.htaccess`, `updates/` ni los APK que ya publicaste.
4. Recarga el navegador (Ctrl+F5). Abre **Diseño → Tema que carga la app**.
5. Selecciona **Nova3 (nova3)** o pulsa **Nova3 · menú lateral TV**.
6. Pulsa **Guardar en el servidor**. Ese paso publica la lista actualizada de
   temas y el predeterminado en `config.json`.
7. Reinicia la app. Si elegiste un tema manualmente en ese equipo, entra en
   **Perfil → Apariencia → Volver al tema de la marca** para seguir el panel.

El panel agrega Nova2/Nova3 a configuraciones antiguas por ID, sin cambiar el tema
activo existente, los colores personalizados, el servidor IPTV ni los enlaces de
actualización. Para instalaciones nuevas, el predeterminado es Nova3. Los atajos
de colores editan el tema seleccionado, no el primer tema de la lista.

No necesitas recompilar para elegir como predeterminado un tema que ya está en
la APK. Una APK anterior a Nova2/Nova3 sí necesita actualizarse para mostrar esos
diseños. Debe estar enlazada al `remoteConfigUrl` de este panel.

Pruebas del panel:

```sh
node tools/check_panel_theme_ui.js
php tools/test_panel_themes.php
php -l aapanel-alphavision/index.php
```
