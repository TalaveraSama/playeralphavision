# Firmar Alpha Vision para producción (Windows)

El proyecto ahora usa una clave de producción para APK y AAB. **Nunca vuelve a
firmar release con la clave debug**: si faltan datos, detiene la compilación.
Las compilaciones de depuración conservan la firma debug habitual.

## Instalar esta corrección

El parche incluye `android/app/build.gradle.kts`. Respalda tu archivo actual y
copia el nuevo en esa misma ruta. Si personalizaste `applicationId`, conserva el
identificador de tu app existente; no lo cambies para una actualización. No copies
ni reemplaces tus configuraciones de marca con las del código fuente completo.

## Asistente automatico (recomendado para tu primera clave)

Extrae el paquete del asistente en la raiz `alphavision_tv`, respetando las
carpetas `admin_panel`, `tools` y `android/app`. Conserva tu `applicationId` si
habias personalizado Gradle. No reemplaces tus JSON de marca.

1. Abre `admin_panel/Crear firma de produccion.cmd`.
2. Confirma escribiendo `CREAR` solo si NO tienes una firma previa que conservar.
3. Introduce dos veces una contrasena de al menos 12 caracteres ASCII sin espacios.
   No se muestra al escribirla. Se usa la misma para almacen y clave.
4. Genera el almacen en `%USERPROFILE%/AlphaVisionKeys/alphavision-release.jks`,
   alias `alphavision`, y crea `android/key.properties` como UTF-8 sin BOM.
5. Comprueba el mensaje LISTO y ejecuta tu `admin_panel/Generar APK.cmd` habitual.
   El asistente no compila ni publica: tu generador aplica la firma al compilar.

Busca keytool en PATH, JAVA_HOME y rutas habituales del JDK de Android Studio.
No sobrescribe claves ni configuracion existentes. Si se detiene porque encuentra
una, conserva esos archivos y revisa los pasos manuales siguientes. Si ya creo
el JKS pero fallo al escribir propiedades, NO borres el JKS para empezar de nuevo:
completa key.properties manualmente con esa misma clave y contrasena.

No imprime contrasenas ni las pasa como argumentos de proceso. keytool recibe
una variable de entorno temporal del proceso; se elimina al terminar. El archivo
key.properties SI contiene las contrasenas en texto plano, como requiere esta
configuracion local. No compartas ese archivo. No se cambian permisos del equipo
ni se cifra automaticamente el almacen: debes protegerlo y hacer respaldos.

El nombre del certificado generado es una etiqueta local (`Alpha Vision Android
Release`), no acredita una identidad legal. Puedes personalizarlo mediante el
procedimiento manual si necesitas otros datos.

Validacion del asistente: sintaxis y reglas comprobadas estaticamente; no se pudo
ejecutar en Windows/PowerShell ni generar/verificar una firma real aqui.

## 0. Antes de crear una clave

- Si ya publicaste esta app, usa la clave correspondiente existente, no generes
  otra arbitrariamente. En Google Play puede tratarse de tu clave de carga.
- Si instalaste las versiones anteriores de este repositorio, pueden estar
  firmadas con debug: una nueva firma no puede reemplazarlas como actualización
  directa con el mismo identificador. En equipos de prueba tendrás que desinstalar
  la anterior (puede perder datos) o planificar otro identificador. Cambiar el
  identificador crea otra app, no una actualización de la existente.
- Decide cómo distribuirás: APK directo, Google Play o ambos. Con Play App Signing
  la clave de carga no es necesariamente la firma que reciben los usuarios.
  No asumas que el APK local podrá actualizar la instalación de Play: sus
  certificados de firma finales deben coincidir.

## 1. Crear tu clave EN TU COMPUTADORA

En PowerShell, crea una carpeta fuera del proyecto:

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\AlphaVisionKeys"
keytool -genkeypair -v -keystore "$env:USERPROFILE\AlphaVisionKeys\alphavision-release.jks" -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias alphavision
```

`keytool` te pedirá contraseña y datos del certificado de forma interactiva.
Guarda el alias y ambas contraseñas. Si eliges la misma para clave y almacén,
se repite en ambos campos del paso siguiente. No pongas las contraseñas en el
comando ni en el chat. Si el archivo ya existe, **no lo sobrescribas**: identifica
primero si es la clave que debes reutilizar.

Si no existe `keytool` en PATH y tienes Android Studio, normalmente está aquí:

```powershell
& 'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe' -genkeypair -v -keystore "$env:USERPROFILE\AlphaVisionKeys\alphavision-release.jks" -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias alphavision
```

La ruta depende de dónde instalaste Android Studio/JDK.

## 2. Crear `android/key.properties`

Crea el archivo local **android/key.properties** con el Bloc de notas y guárdalo
como UTF-8 **sin BOM** (no como key.properties.txt):

```properties
storeFile=C:/Users/TU_USUARIO/AlphaVisionKeys/alphavision-release.jks
storePassword=TU_CONTRASENA_DEL_ALMACEN
keyAlias=alphavision
keyPassword=TU_CONTRASENA_DE_LA_CLAVE
```

Sustituye los valores por los tuyos. No uses comillas alrededor de los valores.
Usa `/` en la ruta Windows: las barras `\` son escapes en archivos properties.
Las contraseñas que contengan una barra `\` necesitan escribirla duplicada `\\`
en este archivo; no cambies la contraseña real del almacén.
Una ruta relativa se resuelve respecto a la carpeta `android`, no a `android/app`.
Este archivo contiene secretos en texto plano: protege tu cuenta/equipo y limita
el acceso. **Está excluido de Git, al igual que los archivos .jks/.keystore.**

No añadas `key.properties` ni el almacén a un ZIP del proyecto para compartirlo.
No cambies el alias, archivo o contraseñas entre compilaciones sin un motivo.

## 3. Compilar APK firmado

Ejecuta tu generador habitual de NOVA; los builds release ya tomarán esta firma.
O, desde la raíz del proyecto:

```powershell
flutter pub get
flutter build apk --release
```

Resultado habitual:
`build\app\outputs\flutter-apk\app-release.apk`.
El generador de marca también copia los resultados a `dist` como antes.
No hace falta cambiar motores ni reinstalar todas las dependencias para firmar.

## 4. Para Google Play: generar AAB

Primero prepara la marca con tu generador habitual (o su opción `-SkipBuild`).
Después:

```powershell
flutter build appbundle --release
```

Resultado habitual: `build\app\outputs\bundle\release\app-release.aab`.
La misma configuración de firma sirve para ambos formatos. Play App Signing se
configura en Play Console y distingue clave de carga y clave de firma de la app.
No publiques hasta revisar políticas, privacidad, permisos y versión de la app.
Firmar no equivale a aprobación de la tienda.

## 5. Verificar ANTES de repartir

Localiza `apksigner.bat` en tu Android SDK, dentro de
`build-tools\NUMERO_DE_VERSION`, y ejecuta (ajusta la ruta):

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\build-tools\TU_VERSION\apksigner.bat" verify --verbose --print-certs .\build\app\outputs\flutter-apk\app-release.apk
keytool -list -v -keystore "$env:USERPROFILE\AlphaVisionKeys\alphavision-release.jks" -alias alphavision
```

Verifica que el SHA-256 del certificado del APK coincida con tu certificado de
producción, no solo que el verificador diga que el archivo es válido. Un APK debug
también puede tener firma criptográficamente válida. No debe aparecer el típico
certificado de depuración Android Debug.

Para verificar la firma de carga de un AAB, usa `jarsigner -verify -verbose -certs`
y revisa el certificado con `keytool -printcert -jarfile` sobre el archivo AAB.
No uses apksigner para verificar un AAB como si fuera APK.

## 6. Copias de seguridad: imprescindible

Conserva dos copias cifradas del almacén fuera del repositorio y guarda contraseñas
por separado, por ejemplo en tu gestor de contraseñas. Registra el alias, huella
SHA-256, identificador de app y para qué marca se usa cada clave.

Si pierdes la clave de firma de APK distribuidos directamente, normalmente no
podrás publicar actualizaciones compatibles de esa app. Play App Signing tiene
procedimientos distintos para claves de carga/firma: consulta Play Console antes
de reemplazarlas. No prestes tu clave a quien solo necesita subir una publicación.

## Estado de esta preparación

Se modificó Gradle y se comprobaron reglas de forma estática. Aquí no se creó
ninguna clave privada, no se recibieron contraseñas y no se firmó ni compiló un
APK: esas operaciones se ejecutan en tu equipo con tu SDK/JDK y secretos locales.


## Error keytool `MissingFormatArgumentException: Format specifier %2$s`

El registro recibido muestra que la generacion termino y el fallo ocurrio en
`keytool -list -v`, al formatear el certificado. El asistente corregido fija el
idioma Java a ingles y verifica sin `-v`, evitando esa ruta de formateo localizado.
El aviso de JKS propietario no es por si mismo un error ni obliga a cambiar la clave.

Reemplaza `tools/setup_android_signing.ps1` por la version corregida y abre el
mismo `admin_panel/Crear firma de produccion.cmd`. Si no existen la clave final
ni key.properties y nunca distribuiste con esa clave, puedes repetir la creacion.
La version anterior limpiaba su archivo temporal cuando fallaba la verificacion;
comprueba los archivos locales antes de decidir si necesitas crear una nueva.

Si ya existe `alphavision-release.jks`, NO lo borres ni crees otra firma. Verifica
el almacen existente con (ajusta la ruta si usas otro keytool):

```powershell
keytool -J-Duser.language=en -J-Duser.country=US -list -keystore "$env:USERPROFILE\AlphaVisionKeys\alphavision-release.jks" -alias alphavision
```

Te pedira la contrasena localmente. Si funciona y falta key.properties, completalo
con los pasos manuales de esta guia, usando la MISMA clave/alias/contrasena.
Si el archivo conservado tiene nombre `.nova-....jks`, verifica esa ruta primero;
no lo reemplaces con una clave diferente sin saber si ya se uso.

La version corregida conserva la clave en su ruta final antes de verificar y
nunca elimina archivos de clave en la limpieza, incluso ante un error posterior.
Solo elimina el archivo temporal de propiedades incompleto. La configuracion se
escribe unicamente si la verificacion devuelve exito. No modifica el idioma global
de Windows ni cambia automaticamente el formato del almacen.

El arreglo y las reglas se comprobaron estaticamente; el JDK/Windows afectados
no estan disponibles aqui para reproducir la ejecucion real.
