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
