> **Aviso de versión:** desde 1.2.45 se retiraron VLC/IJK/MPV por solicitud del propietario.
> La reproducción de esta edición es exclusivamente Android/Android TV con ExoPlayer.
> Los pasos iOS de abajo son históricos (1.2.43) y NO preparan un player iPhone actual.
> Para retomar iPhone hay que aprobar e integrar un backend compatible con iOS.

# Alpha Vision para iPhone — preparación iOS 1.2.43+1047

## Qué se preparó

- iOS usa **VLC / MobileVLCKit**, incluido mediante `flutter_vlc_player`.
  Media3 y sus canales nativos son exclusivos de Android; no se invocan en iOS.
- No se inicializa libmpv en iOS, porque este proyecto no incluye su binario iOS.
- Android conserva Media3/FFmpeg y todos sus motores, sin cambios de selección.
- iPhone/iPad siguen **siempre en horizontal**, con iOS mínimo del proyecto **15.0**.
- Añadidos Podfile y referencias de CocoaPods para integrar plugins nativos.
- VLC en iOS usa aceleración automática, mantiene la pantalla encendida y pausa
  al salir a segundo plano. Al volver, pulsa Play si quedó pausado.
- Los avisos de texto/imagen de Overlay se montan también sobre VLC en iOS.
  La opción `ads.inPlayer` del panel sirve para ambos, aunque paneles anteriores
  la rotulen Media3. El recordatorio de descanso es global; al vencer en iOS
  vuelve a Inicio: iOS no permite cerrar la app por código.
- iOS no muestra actualizaciones obligatorias del panel APK. Se actualiza por el
  canal iOS que configures (TestFlight/App Store); aún no se añadió un updater iOS.

**Es código preparado para compilar y probar; no es un IPA compilado ni una
certificación de compatibilidad. Aquí no hay macOS, Xcode ni Flutter SDK.**
La primera compilación puede revelar ajustes necesarios de plugins/CocoaPods.

## Necesitas

1. Un **Mac** físico o un servicio de compilación macOS, con Xcode compatible con
   tu Flutter y la versión de iOS del teléfono. Windows no puede generar este iOS.
2. Flutter estable, herramientas de línea de comandos de Xcode y CocoaPods.
3. Python 3 para el generador de marca de este repositorio.
4. Cuenta Apple configurada **localmente en Xcode**, no en el chat.
5. Para TestFlight/App Store: membresía Apple Developer y app registrada en App
   Store Connect. Firma, permisos y revisión se gestionan en tu cuenta Apple.
   La firma personal gratuita permite pruebas limitadas, no distribución general.

Un APK no funciona en iPhone. Un archivo IPA sin firma válida tampoco se instala
simplemente descargándolo. No hay un IPA listo para descargar en este release.

## 1. Preparar tu marca

Descarga y extrae el código fuente completo. Conserva tu `admin_panel/config.json`
con servidor, nombre y `remoteConfigUrl`. No uses un JSON de ejemplo encima de tu
configuración real. Haz respaldo de `assets/config.json` e `ios/Runner/Info.plist`.

En Terminal, desde la raíz del proyecto:

```sh
flutter doctor -v
flutter pub get
flutter precache --ios
cd ios
pod install
cd ..
open ios/Runner.xcworkspace
```

Abre **Runner.xcworkspace**, no solo Runner.xcodeproj. Si Xcode solicita descargar
componentes/soporte de plataforma o aceptar licencia, completa esos pasos.

## 2. Configurar firma en Xcode

Selecciona proyecto **Runner → target Runner → Signing & Capabilities**:

- `Automatically manage signing`: activado para empezar.
- `Team`: tu equipo/cuenta Apple.
- `Bundle Identifier`: uno tuyo, único; por ejemplo `com.tumarca.alphavision`.
  El identificador por defecto del repositorio es de plantilla: cámbialo.
- Si usas RunnerTests, ajusta también su identificador/equipo si Xcode lo exige.
- Conecta el iPhone, confía en el Mac y selecciona el dispositivo como destino.
  Activa Developer Mode en el teléfono si tu versión de iOS lo solicita.

No se incluyen certificados, perfiles ni claves de Apple en el repositorio.
No compartas contraseñas ni certificados en el chat.

## 3. Compilar tu marca sin firma (comprobación)

```sh
bash tools/build_ios.sh admin_panel/config.json --no-codesign
```

Copia la configuración a assets y el nombre a Info.plist; conserva una copia
inicial en `build/ios-config-backup`. Esos cambios de marca quedan en el proyecto,
igual que en el generador de Windows. No cambia Bundle Identifier ni Team.

Produce una **.app sin firma**, no un IPA instalable. Para probar en tu iPhone,
vuelve a Xcode, elige el teléfono y pulsa **Run** con tu firma configurada.

## 4. Archivo firmado / TestFlight

Con Team, Bundle Identifier y firma resueltos:

```sh
bash tools/build_ios.sh admin_panel/config.json --ipa
```

También puedes usar Xcode → **Product → Archive**, con destino de dispositivo
físico/genérico iOS, y luego Organizer → **Distribute App**. La exportación depende
de tu cuenta, perfiles y método. Para TestFlight, carga el archivo a App Store
Connect e invita a tus probadores después de su procesamiento/aprobación.
No todos los métodos permiten instalar en cualquier iPhone.

## 5. Pruebas obligatorias antes de distribuir

```sh
flutter analyze
flutter test
```

En iPhone real:

- Inicio de sesión Xtream/XUI, carga de TV, películas y series.
- Reproducción VLC: HLS (`m3u8`) primero, luego los formatos reales de tu proveedor.
  No se garantiza compatibilidad universal con códecs, DRM o todos los servidores.
- Pausa, búsqueda en película, cambio de canal, pistas de audio y subtítulos.
- Controles táctiles visibles junto a la muesca y horizontal en ambas direcciones.
- Segundo plano / vuelta a primer plano, llamadas y salida del reproductor.
- Avisos Overlay y demo; configurar descanso temporalmente a 1 minuto para probar
  Continuar y vencimiento. Restaurar 240 minutos después.
- Verificar que una actualización APK obligatoria del panel no bloquea iPhone.

El player VLC existente no equivale a toda la telemetría/interfaz Nova3 específica
de Media3. Esta preparación no incorpora mejoras de historial propias de ese motor.

## Red y publicación

Se conserva el permiso HTTP existente porque muchos proveedores sirven streams
sin HTTPS. Se añadió el texto de acceso a red local para servidores de tu LAN.
Para publicar, usa HTTPS cuando sea posible y justifica las excepciones de red
ante Apple. No se solicitan cámara, micrófono, ubicación ni reproducción en fondo.

Distribuye únicamente contenido autorizado. Preparar iOS o compilar no garantiza
aprobación de App Store: Apple revisa contenido, derechos, privacidad, SDKs y uso
de red. No se inventó una URL de App Store ni se configuró un perfil de firma.

Si falla CocoaPods o Xcode, comparte el primer error real del registro, ocultando
credenciales/servidores privados. No ejecutes `pod update` a ciegas ni elimines
motores para resolver un error de firma.
