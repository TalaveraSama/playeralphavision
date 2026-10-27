# Anuncios sin complicaciones — Alpha Vision / NOVA

## Lo más importante

**Para poner una nota sobre el vídeo no necesitas rellenar todas las casillas.**
Solo hacen falta un anuncio **message**, su **Texto**, **Activo** y los tres
interruptores: **Anuncios activados**, **Avisos sobre Media3** y **Overlay activo**.
El botón **Añadir aviso de texto sobre el vídeo** activa esos interruptores.

El panel actualizado oculta opciones avanzadas y, al elegir message, no pide
archivo, imagen ni vídeo. La vista previa es ilustrativa; no publica el anuncio.

## 1. Prueba de un minuto: tres demos listas

1. Antes de probar, usa **Panel → Descargar config.json** para guardar un respaldo.
2. Abre **Anuncios → Cargar 3 avisos de demostración** y confirma.
3. Verás estos tres anuncios ya rellenados:

| Demo | Título | Mensaje |
|---|---|---|
| Bienvenida | Bienvenido a tu momento favorito | Desconecta de la rutina. Elige una historia y disfruta a tu manera. |
| Noche de cine | Hoy el mejor plan está en casa | Palomitas listas, luces bajas y una película por descubrir. ¡Que empiece la función! |
| Cuida tu vista | Una pequeña pausa también es parte del plan | Aparta la mirada de la pantalla unos segundos y relaja tus ojos. Tu bienestar también importa. |

4. Pulsa **Guardar en el servidor**. Sin guardar, solo cambias el borrador del panel.
5. Reabre la app con el panel configurado en su `remoteConfigUrl` y reproduce un
   vídeo usando **Media3 / ExoPlayer**, con APK **1.2.42 o posterior**.
6. Los avisos rotan cada **12 segundos**, durante hasta **60 segundos** desde abrir
   o cambiar el contenido. Overlay tiene un tope demo de **12 impresiones/hora**
   por dispositivo. Los topes ya consumidos siguen teniendo efecto.

**La demo no borra tus anuncios**, no cambia la marca, no modifica el descanso y
no duplica sus tres IDs al cargarla otra vez. No restaura textos demo editados.
Sí activa publicidad y Overlay y pausa Banner, Interstitial y Preroll, tal como
indica la confirmación. Si tienes otras imágenes o mensajes activos, también
pueden participar en la rotación. No necesita imágenes externas ni enlaces falsos.

## 2. Tu primer aviso real

Pulsa **Añadir aviso de texto sobre el vídeo** y completa:

- **Tipo:** `message · Solo texto`.
- **Etiqueta interna:** `Promoción del fin de semana`.
- **Título opcional:** `Tu próxima historia empieza aquí`.
- **Texto obligatorio:** `¡Hoy es noche de cine! Prepara tus palomitas y descubre una nueva historia.`
- **Activo:** marcado.

Pulsa **Actualizar vista previa** para ver el texto y después **Guardar en el
servidor**. La vista previa no comprueba conexión, límites ni la app instalada.

## 3. Qué significa cada casilla

| Campo | ¿Qué pongo? | ¿Es necesario para texto? |
|---|---|---|
| Anuncios activados | Encender para permitir publicidad | Sí |
| Avisos sobre Media3 / ExoPlayer | Encender la franja del reproductor actual | Sí |
| Overlay → Activo | Habilitar esa ubicación | Sí |
| Overlay → Tope por hora | Impresiones por dispositivo; ejemplo normal: 2/h | Sí, mayor que 0 |
| Segundos por anuncio | Tiempo de cada mensaje en la rotación; demo: 12 | Deja el valor demo |
| Franja visible | Ventana de aparición desde abrir/cambiar contenido; demo: 60 s | 0 = disponible sin plazo fijo, respetando topes |
| Tipo | message, image o video | Usa message |
| Etiqueta | Nombre para organizar anuncios en el panel | Opcional |
| Título | Encabezado que acompaña al mensaje | Opcional |
| Texto | Mensaje que verá el usuario | **Sí** |
| Activo | Permitir mostrar ese anuncio | Sí |
| URL del archivo | Dirección directa de JPG/PNG o MP4, según tipo | No para message |

### Opciones avanzadas — normalmente no las toques

| Campo | Significado |
|---|---|
| ID | Identificador único. Se genera automáticamente y sirve para los contadores. No repitas IDs. |
| Enlace | Opcional. La franja Overlay es informativa: no lo abre al pulsar OK. |
| Duración | Límite de pantalla completa; no define la rotación de Overlay. |
| Permitir cerrar | Segundos de espera antes de cerrar pantalla completa; no corresponde a la franja. |
| Peso | Favorece selección ponderada de anuncios; no ordena la rotación Overlay. |
| Máximo diario | Impresiones de ese anuncio por dispositivo. Vacío = sin límite diario; 0 impide mostrarlo en la franja. |

La segmentación por contenido/categoría/palabras/horas que ya exista en el JSON
se conserva. Las demos no tienen segmentación. No cambies IDs para evadir topes.

## 4. Dónde sale cada cosa

- **Overlay:** mensajes o imágenes sobre el vídeo actual de **Media3/ExoPlayer**.
  No detiene el vídeo ni captura el botón OK del mando. Vídeo publicitario no se
  reproduce encima. No se promete la misma franja en los motores alternativos.
- **Interstitial:** pantalla completa antes de abrir el reproductor.
- **Banner / Preroll:** opciones del esquema compartido; no todas las pantallas
  o motores las implementan. Para empezar, deja ambas apagadas y usa Overlay.
- Todas las ubicaciones comparten la lista de creativos; no hay una casilla de
  ubicación individual para cada anuncio. Si enciendes pantalla completa,
  revisa qué anuncios tienes activos.

Para imágenes: usa URL directa accesible o base64, no una página web. Medidas de
referencia: Overlay **400×225**, Banner **728×90**, pantalla completa **1920×1080**.
Para vídeo publicitario: URL directa al archivo MP4, no una página de YouTube.

## 5. Terminar la prueba

1. Pulsa **Quitar avisos demo** y confirma. Solo elimina sus tres IDs reservados.
2. Si no quedan anuncios, la publicidad se apaga automáticamente.
3. Si quedan anuncios tuyos, siguen activos y se conservan los ajustes de prueba:
   revisa Overlay, rotación, ventana visible y los topes antes de guardar.
4. Ejemplo de uso moderado: Overlay **2/h**, rotación **12 s**, ventana **24 s**.
   Si prefieres no mostrar publicidad, apaga **Anuncios activados**.
5. **Guardar en el servidor**. Los interruptores que la demo pausó no se
   restauran solos; reactívalos manualmente o restaura tu respaldo si corresponde.

El botón Quitar de cada tarjeta elimina solo ese creativo. Cargar la demo otra
vez no borra anuncios reales ni reinicia los contadores de los dispositivos.

## 6. No aparece: revisión rápida

- ¿Guardaste en el servidor y reabriste la app?
- ¿La app usa ese `remoteConfigUrl` y tiene conexión?
- ¿Instalaste APK 1.2.42 o posterior y elegiste Media3/ExoPlayer?
- ¿Están activos general, avisos en player, Overlay y el creativo?
- ¿Tiene Texto no vacío o URL válida según el tipo?
- ¿Se agotó el tope de esa hora o el máximo diario del anuncio?
- ¿Ya pasaron los 60 segundos de la ventana demo?
- ¿Hay segmentación en otros anuncios que impida mostrarlos en ese contenido?

**2/h no significa dos usuarios:** significa dos impresiones de la ubicación en
ese dispositivo durante esa hora. La tercera no saldrá hasta la siguiente hora.

## 7. El aviso de cuatro horas NO es un anuncio

`Consejos → Continuar usando` se ajusta en **Avisos y descanso**. Sigue siendo
independiente de esta publicidad, de la demo y de sus topes. La demo de cuidado
de la vista es solo una frase: no inicia una cuenta atrás ni cierra la app.

## Instalar este panel actualizado

Respalda tu panel. Conserva tu `$PASSWORD` y reemplaza solo `index.php`. No
reemplaces tu `config.json`, claves, `.htaccess` ni carpeta `updates`. Abre con
Ctrl+F5. Este cambio del panel no requiere recompilar si ya tienes APK 1.2.42+;
un APK anterior sí necesita la integración nueva del reproductor.

Validación: pruebas JavaScript de creación, cancelación, no duplicación,
conservación de anuncios, eliminación de demos y campos condicionales. Sintaxis
PHP comprobada con parser; no se ejecutó servidor PHP ni prueba en dispositivo.


### iPhone (preparación 1.2.43+)

La misma franja Overlay se conecta a VLC en iOS desde 1.2.43. Se mantiene
`ads.inPlayer`; el panel nuevo lo rotula Media3 / iPhone. En iOS, el recordatorio
vencido vuelve a Inicio, no cierra la app. Antes de distribuir, compila y valida
esta integración en un iPhone real: el código se preparó sin SDK Apple disponible.
Consulta `GUIA_IPHONE.md` para firma, CocoaPods y TestFlight.
