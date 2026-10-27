# Firmar Alpha Vision para producción (Windows)

El proyecto ahora usa una clave de producción para APK y AAB. **Nunca vuelve a
firmar release con la clave debug**: si faltan datos, detiene la compilación.
Las compilaciones de depuración conservan la firma debug habitual.

## Instalar esta corrección

El parche incluye `android/app/build.gradle.kts`. Respalda tu archivo actual y
copia el nuevo en esa misma ruta. Si personalizaste `applicationId`, conserva el
identificador de tu app existente; no lo cambies para una actualización. No copies
ni reemplaces tus configuraciones de marca con las del código fuente completo.

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
