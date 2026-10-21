# NOVA · cliente OTT de marca blanca

Cliente **IPTV/OTT multiplataforma** en Flutter/Dart sobre la API de **Xtream
Codes v2** y paneles **XUI.one** (`player_api.php`).

`app_ott2/` es una copia completa del proyecto `xtream_player` con el **diseño
NOVA** implementado a partir de los tres diseños de referencia (portada de
escritorio, ficha de serie y portada de móvil). Toda la lógica —API, estado,
anuncios, reproductor, panel de administración y herramientas— es la misma:
aquí solo cambia la capa de presentación y se añade el nuevo armazón.

---

## 1. Diseño NOVA

### Portada de descubrimiento («Inicio»)

- **Héroe** con el motivo de anillos concéntricos, insignia `ORIGINAL NOVA`,
  título grande, metadatos reales del panel y sinopsis, con los botones
  *Ver ahora* y *Mi lista*.
- **Continuar viendo** con barra de progreso sobre la carátula y «Ver todo».
- **En vivo ahora** con tarjetas 16:9 e insignia `EN VIVO`.
- **Tendencias en tu país** con carátulas numeradas del 1 al N.
- **Pie** con el logotipo y los enlaces legales (Ayuda, Dispositivos,
  Términos, Privacidad) que abren la URL de soporte de la marca.

### Adaptación al ancho (responsive)

| Ancho | Navegación | Contenido |
| --- | --- | --- |
| ≥ 1000 px (web, escritorio, tableta horizontal) | Barra **superior**: Inicio · Series · Películas · En vivo · Deportes · Infantil, buscador y avatar | Portada en dos columnas, filas de tarjetas y tendencias a 6 columnas |
| < 1000 px (móvil) | Barra **inferior**: Inicio · Explorar · En vivo · Mi lista · Perfil | Portada compacta con filtros **Todo · Series · Películas · En vivo** |

«Deportes» e «Infantil» abren el catálogo ya filtrado por la categoría que
coincida con el nombre (acentos incluidos); si el panel no tiene esa categoría,
se muestra el catálogo completo.

### Ficha de serie y de película

- Reproductor destacado con anillos y botón central; etiqueta de *Tráiler*
  cuando el panel informa del `youtube_trailer`.
- Insignia, título, metadatos, sinopsis, botón principal (*Ver T1 · E1* en
  series, *Ver ahora* en películas), botones cuadrados de *Mi lista* y
  *Compartir*.
- Tabla de información (Género, Audio, Subtítulos, Dirección, Emisión…) y
  **Reparto** con avatares circulares.
- Pestañas **Episodios / Más como esto / Detalles**; los episodios muestran
  número, miniatura, descripción, duración y la barra de progreso si quedó a
  medio ver, y el selector de temporada cuando hay más de una.

### Sistema de diseño

| Archivo | Contenido |
| --- | --- |
| `lib/core/theme/nova_theme.dart` | Tokens (colores, radios, tipografía) y puntos de corte |
| `lib/widgets/nova/nova_art.dart` | Degradados estables y pintor de anillos |
| `lib/widgets/nova/nova_ui.dart` | Logotipo, insignias, botones, filtros, barras de progreso y tarjetas |
| `lib/widgets/nova/nova_detail_parts.dart` | Reproductor, tabla de información, reparto y rejilla de carátulas |
| `lib/features/home/nova_shell.dart` | Armazón responsivo (barra superior / inferior) |
| `lib/features/home/nova_discover_page.dart` | Portada de descubrimiento y «Continuar viendo» completo |
| `lib/features/catalog/nova_browse_page.dart` | «Explorar» del móvil con filtros de tipo y categoría |

Los colores salen siempre del tema activo (`assets/config.json`), así que el
diseño sigue siendo de marca blanca: el acento, el fondo y las superficies los
elige la marca. Cuando el panel no devuelve carátula, la app pinta un degradado
estable a partir del título (el mismo título pinta siempre igual) y el motivo de
anillos, nunca un rectángulo gris.

### Capturas

En `doc/preview/` (generadas con la herramienta de capturas):

- `nova_inicio_escritorio.png` — portada de escritorio.
- `nova_inicio_movil.png` — portada de móvil.
- `nova_ficha_serie.png` — ficha de serie.

```powershell
flutter test tool/nova_preview.dart --update-goldens
```

---

## 2. Cambiar de diseño

El armazón lo decide el `layout` del tema activo (`lib/app.dart`):

| `layout` | Armazón |
| --- | --- |
| `nova` | Portada NOVA (este diseño) |
| `rows` | Cabecera destacada + una fila por categoría |
| `grid` | Rejilla de carátulas con filtros |

```jsonc
"theme": {
  "active": "nova",
  "available": [
    { "id": "nova", "name": "NOVA", "layout": "nova",
      "primaryColor": "#2FE0C0", "backgroundColor": "#0A0F1A",
      "surfaceColor": "#141D2E", "textColor": "#FFFFFF",
      "cardRadius": 14, "useHero": true }
  ]
}
```

El **panel de administración** es propio de este diseño: un solo archivo,
[`admin_panel/index.html`](admin_panel/index.html) (pestañas Marca · Diseño ·
Anuncios · Actualización · Publicar, con vista previa y descarga de
`config.json`). Se puede subir a un sitio de **aaPanel** para publicar el
`config.json` remoto y cambiar anuncios o avisos sin recompilar; los detalles
están en [`admin_panel/LEEME.md`](admin_panel/LEEME.md) y la compilación se hace
con `admin_panel\Generar APK.cmd`.

En esta marca el `remoteConfigUrl` va vacío para que la portada NOVA sea la
activa al instalar; si se informa una configuración remota con otro tema, esa
mandará (comportamiento de marca blanca de siempre).

---

## 3. Estructura (lo que cambia)

```
lib/
  core/theme/nova_theme.dart      Tokens y puntos de corte del diseño NOVA
  widgets/nova/                   Piezas reutilizables del diseño
  features/home/nova_shell.dart   Barra superior (ancho) / inferior (móvil)
  features/home/nova_discover_page.dart
  features/catalog/nova_browse_page.dart
  features/details/               Fichas de serie y película rediseñadas
  features/catalog/catalog_page.dart  Modo «embedded» y pistas de categoría
test/
  nova_layout_test.dart           Pruebas del diseño NOVA
  support/nova_fixture.dart       Panel Xtream simulado y marca NOVA
tool/
  nova_preview.dart               Capturas del diseño (goldens)
```

El resto de la estructura es idéntica al proyecto original: `core/api`,
`core/models`, `core/state`, `core/ads`, `features/player`,
`features/auth`, `features/search`, `features/favorites`,
`features/settings`, `admin_panel/`, `tools/` y `assets/config.json`.

---

## 4. Arrancar y comprobar

```powershell
cd app_ott2

flutter pub get
flutter analyze          # 0 avisos
flutter test             # suite completa (incluye las pruebas del diseño NOVA)

flutter run              # con un móvil, tableta o emulador conectado
flutter build apk --release --split-per-abi
```

Para el APK de una marca concreta se usan los mismos scripts del proyecto
original (`admin_panel\Generar APK.cmd` o
`tools\build_whitelabel.ps1 -ConfigPath ...`).

---

## 5. Lo demás sigue igual

- **Acceso** de marca blanca: usuario y contraseña, servidor grabado en el APK.
- **Catálogos** en vivo, películas y series con categorías, búsqueda global,
  favoritos e historial.
- **Reproductor** con VLC externo opcional, foco de Android TV y teclas del
  mando.
- **Anuncios** con pesos, topes por hora, límite diario y segmentación.
- **Actualizaciones** controladas desde el panel, con modo obligatorio.
- **Panel de administración** web y scripts de compilación.

Los temas `rows` y `grid`, los anuncios y las actualizaciones siguen
funcionando exactamente como antes: el diseño NOVA es un `layout` más.
