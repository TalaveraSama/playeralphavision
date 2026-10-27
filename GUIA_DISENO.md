# 🎨 GUÍA DE DISEÑO — cómo mover/editar las piezas del Home

> Todo el Home está en **`lib/features/home/nova_discover_page.dart`**.
> Los colores están en **`lib/core/theme/nova_theme.dart`**.
> El menú inferior está en **`lib/features/home/nova_shell.dart`**.

---

## 1. Mapa de archivos

| Archivo | Qué controla |
| --- | --- |
| `nova_discover_page.dart` | **Toda la portada** (hero, tiles, filas) |
| `nova_theme.dart` | Colores, tamaños, tipografía |
| `nova_shell.dart` | Barra inferior + barra lateral TV + menú ≡ |
| `nova_ui.dart` / `nova_art.dart` | Botones, badges, imágenes |
| `media_grid.dart` (`NeonFocus`) | El foco/borde al navegar con el mando |

---

## 2. Mover las piezas (orden de las secciones)

En `nova_discover_page.dart` hay **dos métodos**:

- **`_buildCompact(...)`** → móvil / tablet
- **`_buildWide(...)`** → TV / escritorio

Cada sección es un bloque. **Para mover una pieza, corta y pega su bloque** en otro orden.

### Orden actual (compact)

```dart
// dentro de _buildCompact, en la lista de slivers:

if (_heroPool.isNotEmpty)
  SliverToBoxAdapter( ... _BigCarousel ... )      // HERO

if (_brandCategories.isNotEmpty)
  SliverToBoxAdapter( ... _CategoryTiles ... )    // TILES DE CATEGORÍAS

SliverToBoxAdapter( ... _PosterRow('Recomendados para ti') ... )

if (resume.isNotEmpty) ...                        // CONTINUAR VIENDO

if (showSeries && _series.isNotEmpty)
  ... _PosterRow('Series')

if (showMovies && _movies.isNotEmpty)
  ... _PosterRow('Películas')

if (showLiveSection && _live.isNotEmpty)
  ... _PosterRow('En vivo ahora')
```

### Ejemplo: poner "En vivo ahora" justo después del hero

Corta el bloque `if (showLiveSection ...)` y pégalo antes de `if (_brandCategories ...)`.

### En `_buildWide` es igual

Las secciones están dentro de `SliverChildListDelegate(<Widget>[ ... ])`.
Mueve los bloques `if (...)` en el orden que quieras.

---

## 3. Colores (fondo, tarjetas, textos)

En **`nova_theme.dart`** busca el esquema de color. Los valores del mockup:

| Uso | Color |
| --- | --- |
| Fondo | `#0C111B` |
| Superficie | `#151C2C` |
| Tarjeta | `#1E2432` |
| Tarjeta hover/foco | `#273044` |
| Texto | `#FFFFFF` |
| Texto secundario | `#B7C0D0` |
| Acento | `#6EE7D8` |

Si quieres cambiar el fondo a otro, edita el `scaffoldBackgroundColor` / el `ColorScheme.dark(...)` del tema.

---

## 4. Tamaños del hero

En el widget **`_BigCarousel`** (al final del archivo):

```dart
final double heroHeight =
    (MediaQuery.sizeOf(context).height * 0.30).clamp(150.0, 380.0);
```

- `0.30` = 30 % de la altura de la pantalla. **Bájalo** (0.26) para hero más pequeño.
- `380.0` = altura máxima. **Súbelo** si quieres más grande en TV.

Título del hero:

```dart
fontSize: 24,   // más pequeño = 20, más grande = 30
```

---

## 5. Tamaños de las tarjetas de categoría

En el widget **`_CategoryTiles`**:

```dart
height: 78,          // alto de la fila
width: 208,          // ancho de cada tarjeta
fontSize: 15,        // tamaño del texto
```

### Para tarjetas más pequeñas

```dart
height: 60,
width: 150,
fontSize: 12,
```

### Para mostrar más o menos categorías

En el getter **`_brandCategories`**, cambia:

```dart
if (out.length >= 8) break;   // 8 = cuántas categorías mostrar
```

---

## 6. Tarjetas de "Recomendados" (filas 16:9)

Widget **`_PosterRow`** (busca `class _PosterRow`).

- `height` → alto de las tarjetas.
- `itemWidth` → ancho de cada una.
- La relación 16:9 se logra con el alto/ancho.

En `_buildCompact` / `_buildWide` se llama así:

```dart
_PosterRow(
  title: 'Recomendados para ti',
  items: _heroPool.take(12).toList(),   // 12 = cuántas tarjetas
  padding: padding,
  onOpen: _open,
)
```

Cambia el `take(12)` para más/menos tarjetas.

---

## 7. Barra inferior (tamaño)

En **`nova_shell.dart`**, método `_buildBottomBar`:

```dart
return NavigationBar(
  height: 62,          // ← alto de la barra (baja más = 56)
  ...
);
```

---

## 8. Barra superior (tabs)

En `nova_shell.dart`:
- **`_narrowTabs(...)`** → tabs de móvil
- **`_wideTabs(...)`** → tabs de TV

Cada tab es un `_NovaTab(label:, icon:, selectedIcon:, builder:)`.
**Para agregar un tab**, añade otro `_NovaTab(...)` a la lista.
**Para quitar uno**, borra su `_NovaTab(...)`.

---

## 9. Flujo de trabajo recomendado

1. Edita el `.dart` que quieras (`nova_discover_page.dart`).
2. Guarda.
3. Ejecuta en la carpeta del proyecto:
   ```bash
   flutter build apk --release --split-per-abi
   adb install -r build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
   ```
4. Abre la app en el Fire TV.

> ⚠️ Si tocas el reproductor, lee primero **`CHANGELOG.md`** (ahí están las reglas de oro para no romper el vídeo ni el audio).

---

## 10. Las 3 piezas más fáciles de mover

| Pieza | Widget | Dónde se llama |
| --- | --- | --- |
| **Hero** | `_BigCarousel` | `_buildCompact` / `_buildWide` |
| **Tiles de categorías** | `_CategoryTiles` | `_buildCompact` / `_buildWide` |
| **Filas de tarjetas** | `_PosterRow` | `_buildCompact` / `_buildWide` |

Con esos tres widgets y el orden de los bloques, puedes rearmar la portada como quieras.

## Revisión adaptativa (octubre de 2026)

- **Android TV y Fire TV:** menú lateral desplazable en todas las resoluciones,
  detección Leanback/AFT antes del primer diseño, destinos con foco explícito y
  accesos a búsqueda/perfil. Se mantiene Atrás para volver a Inicio.
- **Teléfono:** navegación Material con indicador suave y SafeArea inferior;
  controles principales de al menos 48 dp y categorías más cómodas.
- **Portada:** tarjetas editoriales más grandes, títulos con más jerarquía,
  espaciado de 20/32 dp. El carrusel conserva el orden y no avanza solo en TV,
  con movimiento reducido o cuando la pestaña está inactiva.
- **Marca blanca:** se conservan los colores y logos configurados por el panel.
  No se modifican reproductores ni protocolos IPTV.
- **Roku:** no ejecuta APK ni Flutter. Este repo no incluye un cliente Roku;
  requiere un proyecto SceneGraph/BrightScript separado y verificar formatos,
  autenticación y reproducción en equipos reales. Estas mejoras no crean ese cliente.

Validación local con Flutter instalado:

```sh
flutter pub get
flutter analyze
flutter test test/nova_design_test.dart
flutter test
```

Probar además en teléfono 360/390 dp y TV 960×540 / 1280×720: recorrer destinos
con flechas, OK y Atrás, comprobar foco visible, desplazamiento del menú,
orientación, texto aumentado y reproducción. La compatibilidad real de Fire TV
requiere instalar el APK en el dispositivo; no se deduce solo del diseño.

## Tema Nova2

Nova2 es un tema independiente inspirado en la composición cinematográfica de
los servicios premium: fondo casi negro, violeta suave, CTA blanco y carátulas
verticales. No usa nombres, logos ni material gráfico de terceros. NOVA continúa
siendo el tema activo por defecto.

**Activar:** Perfil → Apariencia → **Nova2** (requiere
`features.allowThemeSwitch: true`). Para activarlo desde el panel, elige `nova2`
como `theme.active`. El preset está en `assets/config.json` y
`admin_panel/config.json`; conserva el layout `nova`.

- Cabecera: `lib/widgets/nova/nova2_hero.dart`.
- Composición independiente: `_buildNova2` en `nova_discover_page.dart`.
- Colores, radio y botones: preset `nova2` de la configuración.
- El nombre de la app sigue siendo el configurado por la marca.
- Un panel antiguo que no enumere Nova2 no elimina el preset incluido en el APK.
- Sin cambios en reproducción ni soporte adicional de plataformas.

Validar con `flutter test test/nova2_theme_test.dart`, `flutter analyze` y pruebas
reales de mando y táctil antes de publicar un APK.

## Tema Nova3 — dashboard de mosaicos

Tema independiente basado en la referencia visual aportada: negro casi puro,
menú lateral de texto e iconos, acciones discretas y hora local arriba, dos
imágenes destacadas y una rejilla de cuatro columnas (tres en anchos intermedios).
No incluye logos ni imágenes de Xuper TV: utiliza la marca y el catálogo reales.
Nova3 conserva el menú lateral en teléfonos, tabletas y TV; la aplicación
se configura siempre en horizontal. En espacios excepcionalmente estrechos el
mosaico reduce columnas para evitar desbordamientos.

**Activar:** Perfil → Apariencia → **Nova3**. También se puede fijar
`theme.active` a `nova3` en el panel. NOVA sigue activo por defecto; Nova2 se
conserva. Compilar un APK nuevo es necesario para incluir estos widgets.

Archivos principales:
- `lib/widgets/nova/nova3_dashboard.dart`: mosaico y tarjetas.
- `lib/widgets/nova/nova3_top_bar.dart`: acciones y reloj (sin indicadores falsos).
- `lib/features/home/nova_shell.dart`: secciones y navegación adaptativa.
- `assets/config.json`: preset `nova3` (negro, acento azul violeta, radio 3 dp).

Destacados usa los elementos configurados por el proveedor y completa con el
catálogo, sin duplicados y hasta 30 elementos; la rejilla se construye de forma
perezosa. TV respeta `showLiveSection`. Kids y Anime usan las pistas de categorías
existentes del catálogo (películas infantiles y series anime, respectivamente),
con el comportamiento habitual de CatalogPage si el proveedor no tiene coincidencia.
No se cambia ningún motor de vídeo ni se añade un cliente Roku.

Validación con SDK instalado:

```sh
flutter pub get
flutter analyze
flutter test test/nova3_theme_test.dart
flutter test
flutter build apk --release
```

Probar además el shell completo en TV 960×540 / 1280×720 y teléfono 360 dp:
seleccionar Nova3, recorrer mosaicos y menú con flechas, OK y Atrás, abrir búsqueda,
favoritos y perfil, cambiar de tema y comprobar foco, recarga de catálogo y vídeo.
Las proporciones imitan la referencia; las imágenes finales dependen del proveedor.


### Nova3 horizontal — ajuste a las referencias completas

- Flutter permite solo `landscapeLeft` / `landscapeRight`.
- Android declara `sensorLandscape`; iPhone/iPad declaran solo orientaciones
  horizontales y modo de pantalla completa. Esto afecta a todos los temas,
  incluido el acceso y los reproductores: ya no se solicita modo vertical.
- Nova3 tiene menú lateral siempre, con menor ancho en teléfonos de poca altura;
  el menú se desplaza si no cabe completo. Ya no hay barra inferior Nova3.
- Películas, Series, Kids y Anime reutilizan el dashboard con dos destacados,
  cuatro miniaturas y filas de carátulas por categorías del proveedor. Hasta
  15 filas, con 36 elementos por fila para limitar la memoria.
- Explorar usa una imagen principal y hasta tres imágenes laterales, seguida
  de filas de películas por categoría. No se inventan colecciones editoriales
  como premios o plataformas que el proveedor no haya suministrado.
- Al abrir un canal en **Media3/ExoPlayer**, Nova3 muestra el vídeo junto a la
  lista de canales, con cambio por toque/OK, controles y pantalla completa.
  Atrás en pantalla completa vuelve a la lista. No se crea un segundo motor.
  La lista de canales se mantiene visible, pero el menú principal del shell
  se recupera volviendo a TV: no está superpuesto al vídeo en esta revisión.
- IJK, VLC y MPV mantienen sus pantallas anteriores; no se cambia la elección
  del motor ni las reglas de recuperación del stream.

Validación añadida: `flutter test test/landscape_layout_test.dart` comprueba
las declaraciones de orientación y el marco de TV a 640×360 y 1280×720.
Ejecutar también `flutter analyze`, las demás pruebas y reproducir canales
reales tras compilar. No se ha podido ejecutar Flutter en el entorno de edición.

Limitaciones de plataforma: algunos sistemas modernos pueden ignorar el bloqueo
de orientación en ventanas o pantallas grandes; comprobar Android 16/iPadOS en
hardware real. La app no puede girar físicamente un monitor. Roku sigue sin cliente
propio en este repositorio: estos cambios no lo convierten en una app Roku.

### Nova3 1.2.39 — lateral colapsable (sustituye las notas de navegación anteriores)

- El preset incluido en el ZIP ahora activa **Nova3 por defecto**. Si el equipo
  conserva otro tema elegido o el panel remoto fija otro, seleccionar
  **Perfil → Apariencia → Nova3**. Los otros temas conservan sus armazones.
- El lateral muestra `Nova3 · 1.2.39` para identificar el APK instalado. Nova3
  nunca construye una barra inferior: independiente del ancho, resolución o
  modo de navegación que anuncie el equipo.
- Derecha desde el menú o seleccionar una sección lo colapsa. Izquierda desde
  el borde del contenido lo abre. Atrás con el menú abierto lo cierra. El botón
  menú, el indicador lateral y el botón táctil permiten alternarlo.
- Tras seis segundos con foco en el contenido, el menú se cierra; mientras el
  usuario navega por el menú no se autooculta. Las flechas dentro de las filas
  mantienen el recorrido normal. El carrusel usa puntos seleccionables y swipe.
- Cabecera desplazable en equipos pequeños: búsqueda, filtro por sección,
  historial local (con borrado confirmado), lista, perfil, avisos y hora local.
  Avisos muestra la versión publicada por el proveedor; no es un servicio push.
- Media3 envía el estado de buffering al spinner de puntos azules y muestras
  reales de transferencia. El texto KB/s es una **estimación de la última
  muestra**, no velocidad instantánea. Antes de medir se muestra «Conectando…».
- Versión `1.2.39+1043`. El script de marca ya no rebaja esa versión si el panel
  contiene una versión anterior; `-Version` continúa siendo una elección explícita.

Validación pendiente en SDK: `flutter analyze`, `flutter test`, en especial
`test/nova3_frame_test.dart`, y APK en teléfono y TV. Las validaciones de sintaxis
no reemplazan la compilación ni verifican el funcionamiento real de Media3.


### Nova3 1.2.40 — TV y lateral un 20 % más compactos

- Lateral Nova3: ancho 80 % del anterior, logo/iconos/texto/espaciado al 80 %;
  los rótulos tienen una sola línea y ajuste al ancho (sin partir «Destacados»).
- Cabecera global Nova3: iconos y reloj reducidos; menos espacio vertical.
- TV Nova3: título, contador, filtros y rejilla al 80 % de sus medidas base;
  padding superior de la cabecera baja de 22 a 8 dp y se elimina la búsqueda
  duplicada (ya está en la cabecera global). Se mantiene Actualizar.
- El tamaño de las tarjetas de Películas/Series y otros temas no se modifica.
- La densidad `MediaGrid.density` es 1 por defecto y 0.8 solo para TV Nova3.
- Pruebas añadidas: `flutter test test/nova3_compact_test.dart`. Compilación y
  validación en TV/teléfono pendientes de ejecutar con Flutter instalado.


### Nova3 1.2.41 — ficha de película horizontal

- Nova3 usa `lib/widgets/nova/nova3_movie_details.dart` al abrir una película.
  Información a la izquierda, imagen 16:9 con botón de reproducción a la derecha,
  cuatro acciones y fila horizontal de recomendaciones. En ventanas de menos
  de 520 dp la ficha se apila para no desbordar, sin solicitar modo vertical.
- Se conservan los metadatos disponibles del catálogo cuando la ficha del
  proveedor no incluye todos los campos. No se inventan país, título original,
  idiomas, resoluciones, premios ni subtítulos disponibles.
- La sinopsis se acorta visualmente; Más abre el texto completo. Favorito usa
  el estado real de la cuenta. La imagen es una vista previa estática, no crea
  un segundo reproductor ni inicia un stream automáticamente.
- Pantalla completa y el botón de reproducción abren `openPlayer` como antes,
  respetando anuncios, motor elegido y compatibilidad. Idioma y Resolución
  informan de las opciones disponibles durante reproducción, sin simular
  selectores de pistas/calidades no recibidas en la ficha.
- Quizás te guste usa películas reales del catálogo, excluye la actual y los
  duplicados; prioriza categoría, géneros y valoración, con hasta 12 resultados.
  Si no hay catálogo descargado se intenta cargarlo sin bloquear la película.
- Los demás temas y las fichas de serie se mantienen sin cambios visuales.

Pruebas añadidas: `flutter test test/nova3_movie_details_test.dart` (recomendaciones,
640×360, 960×540 y 1440×810, reproducción y favoritos). Sintaxis comprobada, pero
compilación, `flutter analyze`, pruebas Flutter y reproducción en equipo real
pendientes de validar con el SDK instalado.


### Nova3 1.2.42 — avisos sobre Media3 y descanso

- Panel: nueva sección **Avisos y descanso**, texto editable, 240 minutos / 10 segundos,
  botón Continuar usando. Independiente de publicidad. JSON incluidos con recordatorio
  activado; JSON antiguos sin la sección conservan comportamiento sin recordatorio.
- Temporizador global de sesión en primer plano; cambiar de canal no lo reinicia.
  Continuar reinicia el plazo; vencer abandona rutas de vídeo y Android solicita salir.
  iOS queda en Inicio. No se borra la cuenta ni se elimina ningún motor.
- Conectada la franja informativa de mensajes/imágenes en Media3/ExoPlayer, con rotación,
  topes y segmentación. No reproduce un segundo vídeo ni captura OK sobre el player.
- Controladores de teclas de los motores dejan pasar el mando cuando hay un diálogo.
- Publicidad de los JSON permanece desactivada y sin creativos; no se confunde con descanso.
- Despliegue, fragmento JSON y pasos de prueba: `aapanel-alphavision/AVISOS_DESCANSO.md`.
- Añadidas pruebas `usage_reminder_test.dart` y `player_notice_rotation_test.dart`.
  Comprobadas sintaxis y estructuras JSON; analyzer, tests Flutter y APK pendientes
  en un equipo con SDK. No hay APK compilado en este release.


### 1.2.43 — preparación de iPhone / iPad

- iOS selecciona VLC y no inicializa libmpv ni abre los canales Media3 de Android.
- CocoaPods, texto de red local, controles con SafeArea y script de marca en macOS.
- Misma orientación horizontal y configuración remota; Overlay integrado con VLC iOS.
- iOS no se bloquea por actualizaciones APK del panel; firma/actualizaciones vía Apple.
- Android conserva motores y selección. Guía completa: `GUIA_IPHONE.md`.
- Sintaxis Dart, plist y shell verificadas; compilación CocoaPods/Xcode, tests Flutter,
  firma y reproducción en iPhone real pendientes (sin SDK Apple/Flutter aquí).
