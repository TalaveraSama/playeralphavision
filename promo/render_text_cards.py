#!/usr/bin/env python3
"""Render the on-screen text cards (1920x1080 RGBA PNG) for the Alpha Vision Digital promo.

The static ffmpeg build shipped with imageio-ffmpeg has no drawtext filter, so all
typography is rendered here with PIL as transparent cards, then composited over the
scenes with ffmpeg overlay + alpha fades.
"""
import os

from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1920, 1080
FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
HERE = os.path.dirname(os.path.abspath(__file__))
TXT = os.path.join(HERE, "text")


def hx(s):
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def read(name):
    with open(os.path.join(TXT, name), encoding="utf-8") as f:
        return f.read().strip()


def gradient_img(w, h, top, bot):
    img = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        img.putpixel((0, y), tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    return img.resize((w, h))


def spaced_mask(text, font, cx, cy, spacing):
    mask = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(mask)
    widths = [font.getlength(c) for c in text]
    total = sum(widths) + spacing * max(0, len(text) - 1)
    x = cx - total / 2
    asc, desc = font.getmetrics()
    y = cy - (asc + desc) / 2
    for c, w in zip(text, widths):
        d.text((x, y), c, font=font, fill=255)
        x += w + spacing
    return mask


def add_line(card, text, size, cx, cy, spacing, top, bot, glow):
    font = ImageFont.truetype(FONT_BOLD, size)
    mask = spaced_mask(text, font, cx, cy, spacing)
    # dark halo first (readability over bright scenes)
    dark = mask.filter(ImageFilter.GaussianBlur(9))
    dark_layer = Image.new("RGBA", (W, H), hx("#050A1E") + (0,))
    dark_layer.putalpha(dark.point(lambda v: int(v * 0.65)))
    card.alpha_composite(dark_layer)
    # colored neon glow
    halo = mask.filter(ImageFilter.GaussianBlur(16))
    halo_layer = Image.new("RGBA", (W, H), glow + (0,))
    halo_layer.putalpha(halo.point(lambda v: int(v * 0.55)))
    card.alpha_composite(halo_layer)
    # gradient text fill
    card.paste(gradient_img(W, H, top, bot), (0, 0), mask)


def add_scrim(card, start=600, full=760, alpha=140):
    strip = Image.new("RGBA", (1, H), (4, 10, 28, 0))
    for y in range(H):
        t = 0.0 if y < start else min(1.0, (y - start) / max(1, full - start))
        strip.putpixel((0, y), (4, 10, 28, int(alpha * t)))
    card.alpha_composite(strip.resize((W, H)))


WHITE = (hx("#FFFFFF"), hx("#BFE9FF"))
CYAN = (hx("#B8FBFF"), hx("#1E9DFF"))
ORANGE = (hx("#FFD98A"), hx("#FF7A2F"))

SCENES = {
    "s1": dict(scrim=(560, 720, 150), glow="#5FA8FF", lines=[
        dict(f="s1_main.txt", size=58, cx=W // 2, cy=880, spacing=3, colors=WHITE)]),
    "s2": dict(scrim=(620, 780, 140), glow="#2FD4FF", lines=[
        dict(f="s2_main.txt", size=76, cx=W // 2, cy=800, spacing=8, colors=CYAN),
        dict(f="s2_sub.txt", size=40, cx=W // 2, cy=910, spacing=4, colors=WHITE)]),
    "s3": dict(scrim=(620, 780, 140), glow="#FF4FD8", lines=[
        dict(f="s3_main.txt", size=72, cx=W // 2, cy=800, spacing=7, colors=WHITE),
        dict(f="s3_sub.txt", size=42, cx=W // 2, cy=910, spacing=3, colors=ORANGE)]),
    "s4": dict(scrim=(620, 780, 140), glow="#2FD4FF", lines=[
        dict(f="s4_badge.txt", size=30, cx=W // 2, cy=706, spacing=5, colors=CYAN),
        dict(f="s4_main.txt", size=74, cx=W // 2, cy=800, spacing=8, colors=CYAN),
        dict(f="s4_sub.txt", size=44, cx=W // 2, cy=912, spacing=4, colors=WHITE)]),
    "s5": dict(scrim=(640, 820, 160), glow="#FFA23D", lines=[
        dict(f="s5_main.txt", size=52, cx=W // 2, cy=800, spacing=3, colors=WHITE),
        dict(f="s5_sub.txt", size=38, cx=W // 2, cy=892, spacing=2, colors=ORANGE)]),
}


def main():
    for key, cfg in SCENES.items():
        card = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        add_scrim(card, *cfg["scrim"])
        for ln in cfg["lines"]:
            add_line(
                card, read(ln["f"]), ln["size"], ln["cx"], ln["cy"], ln["spacing"],
                ln["colors"][0], ln["colors"][1], hx(cfg["glow"]),
            )
        out = os.path.join(TXT, f"{key}_card.png")
        card.save(out)
        print("wrote", out)


if __name__ == "__main__":
    main()
