# Alpha Visión Digital — Video promocional 30s

Video promocional de 30 segundos (1080p, 30 fps, H.264 + AAC) para **Alpha Visión Digital**,
empresa de telecomunicaciones que ofrece Internet de Fibra Óptica e IPTV.

**Entregable:** `alpha_vision_promo_30s.mp4`

## Storyboard (guion final)

| Escena | Tiempo | Visual | Texto en pantalla |
|--------|--------|--------|-------------------|
| 1. El Problema | 0:00–0:05 | Familia frustrada, sala gris, TV con buffering | «¿Cansado de que tu internet falle?» |
| — | 0:04.4–0:05 | **Flash blanco explosivo** (sincronizado con el drop musical) | — |
| 2. La Solución | 0:05–0:09.7 | Hogar moderno, estelas de fibra óptica a velocidades supersónicas | «VELOCIDAD ULTRA FIBER / de Alpha Visión Digital» |
| 3. IPTV | 0:09.7–0:18.8 | Collage: deporte en vivo, cine 4K, series infantiles; control remoto flotante | «+ DE 1000 CANALES / Streaming en 4K sin cortes» |
| 4. Conexión Total | 0:18.8–0:23.9 | Router moderno + velocímetro holográfico al máximo | «1 Gbps · Fibra Simétrica / ESTABILIDAD TOTAL / Sin caídas» |
| 5. CTA | 0:23.9–0:30 | Logo de Alpha Visión Digital brillando sobre fondo high-tech | «Únete hoy y transforma tu hogar / Visita Alpha Visión Digital • Llama al 5822-4576» |

Transiciones: `fadewhite` (escena 1→2, el «drop»), `fade`, `smoothleft`, `fade`.
Movimiento: Ken Burns (zoompan) lento y alterno en cada escena.

## Audio

- **Música:** cama electrónica corporativa sintetizada (`make_music.py`), 120 BPM:
  intro sombría (0–4.4s) → riser → primer impacto en el segundo 5 (flash blanco) →
  segundo build (8.5–10s) → **drop energético en el segundo 10** (bloque IPTV, según
  el brief) → half-time de estabilidad (20–25s) → resolución mayor y fade-out (25–30s).
- **Voz en off** (español, femenina, segura y amigable), desde el segundo 4.2:
  «Con Alpha Visión Digital, olvídate del buffering. Disfruta de la mejor fibra óptica
  y la televisión más completa. Conéctate a la evolución.»
- Mezcla: sidechain (ducking) de música bajo la voz, loudnorm -14 LUFS / TP -1.5 dB,
  fade de cierre.

## Paleta y estilo

Azul eléctrico + cian brillante + blanco (tecnología y confianza); naranja/magenta en la
escena de entretenimiento (IPTV); tipografía en mayúsculas con tracking amplio, degradados
y glow neón. Estética high-tech, limpia, luminosa y de alta gama.

## Estructura de archivos

```
promo/
├── alpha_vision_promo_30s.mp4   ← ENTREGABLE FINAL
├── assets/
│   ├── logo_alpha.png           logo original (aportado por el cliente)
│   └── logo_cut.png             logo con alfa + halo (generado)
├── scenes/                      key art de las 5 escenas (generada)
├── text/                        textos .txt + tarjetas .png de tipografía
├── audio/
│   ├── vo.wav                   voz en off
│   └── music.wav                música sintetizada (30s)
├── render_text_cards.py         renderiza la tipografía (PIL → PNG RGBA)
├── make_music.py                sintetiza la música (numpy → WAV)
└── build_video.py               ensambla todo con ffmpeg (filtergraph)
```

## Cómo regenerar el video

Requisitos: Python 3.11 con `numpy`, `pillow`, `imageio-ffmpeg` y DejaVu Sans.

```bash
cd promo
python3 render_text_cards.py   # tarjetas de texto
python3 make_music.py          # música 30s
python3 build_video.py         # render final → alpha_vision_promo_30s.mp4
```

Notas técnicas: el texto se compone como PNG con canal alfa (el build estático de ffmpeg
no incluye `drawtext`); el logo se escala a 880px con halo blanco para legibilidad sobre
fondos oscuros; el timeline son exactamente 900 frames @30 fps = 30.000 s.
