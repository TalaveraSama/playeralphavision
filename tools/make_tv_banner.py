"""Genera el banner que Android TV y Fire TV usan en el lanzador (320x180).

Android TV y Fire OS exigen un banner para mostrar la app en su pantalla de
inicio; sin él aparece un hueco vacío. El texto y los colores salen de la
configuración de marca, de modo que cada versión (Alpha Vision, IBW TV...) tiene
el suyo.

Uso:
    python tools/make_tv_banner.py                        # admin_panel/config.json
    python tools/make_tv_banner.py admin_panel/config-ibwtv.json
    python tools/make_tv_banner.py --name "IBW TV"        # solo el texto
"""

from __future__ import annotations

import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_CONFIG = os.path.join(ROOT, "admin_panel", "config.json")
TARGET = os.path.join(
    ROOT, "android", "app", "src", "main", "res", "drawable", "tv_banner.png"
)

WIDTH, HEIGHT = 320, 180


def load_brand(config_path: str, name_override: str = "") -> tuple[str, str, str]:
    """Devuelve (nombre, color de fondo, color de acento)."""
    name, background, accent = "Xtream Player", "#0B0B0B", "#E50914"
    if not os.path.exists(config_path):
        config_path = os.path.join(ROOT, "assets", "config.json")
    try:
        with open(config_path, "r", encoding="utf-8") as handle:
            data = json.load(handle)
        branding = data.get("branding", {})
        name = (branding.get("appName") or name).strip() or name
        background = branding.get("primaryColor") or background
        theme = data.get("theme", {})
        active = theme.get("active")
        for spec in theme.get("available", []):
            if spec.get("id") == active:
                background = spec.get("backgroundColor") or background
                accent = spec.get("primaryColor") or accent
                break
        # El color de marca pinta la banda inferior si no es negro.
        primary = branding.get("primaryColor")
        if primary and primary.lower() not in ("#000000", "#0b0b0b"):
            accent = primary
    except Exception as error:  # pragma: no cover - herramienta auxiliar
        print(f"Aviso: no pude leer {config_path} ({error}); uso los valores por defecto.")
    if name_override:
        name = name_override
    return name, background, accent


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    text = value.strip().lstrip("#")
    if len(text) == 3:
        text = "".join(char * 2 for char in text)
    if len(text) != 6:
        return (11, 11, 11)
    try:
        return tuple(int(text[i : i + 2], 16) for i in (0, 2, 4))  # type: ignore[return-value]
    except ValueError:
        return (11, 11, 11)


def pick_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for candidate in (
        r"C:\Windows\Fonts\arialbd.ttf",
        r"C:\Windows\Fonts\segoeuib.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
    ):
        if os.path.exists(candidate):
            try:
                return ImageFont.truetype(candidate, size)
            except OSError:
                continue
    return ImageFont.load_default()


def main() -> int:
    args = sys.argv[1:]
    config_path = DEFAULT_CONFIG
    name_override = ""
    out_path = TARGET
    index = 0
    while index < len(args):
        arg = args[index]
        if arg == "--name" and index + 1 < len(args):
            name_override = args[index + 1]
            index += 2
            continue
        if arg == "--out" and index + 1 < len(args):
            out_path = args[index + 1]
            index += 2
            continue
        config_path = arg
        index += 1

    name, background, accent = load_brand(config_path, name_override)
    bg = hex_to_rgb(background)
    ac = hex_to_rgb(accent)

    image = Image.new("RGB", (WIDTH, HEIGHT), bg)
    draw = ImageDraw.Draw(image)

    # Degradado suave hacia el color de acento para dar profundidad.
    for y in range(HEIGHT):
        blend = y / HEIGHT
        row = tuple(
            int(bg[channel] + (ac[channel] - bg[channel]) * blend * 0.35)
            for channel in range(3)
        )
        draw.line([(0, y), (WIDTH, y)], fill=row)

    # Banda inferior con el color de marca.
    draw.rectangle([0, HEIGHT - 10, WIDTH, HEIGHT], fill=ac)

    # Círculo de "play" a la izquierda.
    cx, cy, radius = 52, HEIGHT // 2 - 4, 26
    draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], fill=ac)
    draw.polygon(
        [(cx - 9, cy - 13), (cx - 9, cy + 13), (cx + 14, cy)],
        fill=(255, 255, 255),
    )

    # Nombre de la marca ajustado al ancho disponible.
    text = name.upper()
    available = WIDTH - (cx + radius) - 28
    size = 30
    font = pick_font(size)
    while size > 12:
        font = pick_font(size)
        box = draw.textbbox((0, 0), text, font=font)
        if box[2] - box[0] <= available:
            break
        size -= 2

    box = draw.textbbox((0, 0), text, font=font)
    text_height = box[3] - box[1]
    draw.text(
        (cx + radius + 16, cy - text_height // 2 - box[1]),
        text,
        font=font,
        fill=(255, 255, 255),
    )

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    image.save(out_path, "PNG")
    print(f"Banner de TV generado: {out_path} ({name})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
