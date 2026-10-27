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
En teléfono, los destacados se apilan, la rejilla tiene dos columnas y las
secciones se desplazan horizontalmente abajo.

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
