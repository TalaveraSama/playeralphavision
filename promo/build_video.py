#!/usr/bin/env python3
"""Assemble the 30s Alpha Visision Digital promo (1080p30 H.264 + AAC).

Inputs
  scenes/scene1..4.png, scenes/scene5_bg.png   generated key art (Ken Burns via zoompan)
  text/s1..s5_card.png                         typography cards (RGBA, from render_text_cards.py)
  assets/logo_alpha.png                        brand logo (white keyed to alpha if needed)
  audio/music.wav, audio/vo.wav                music bed + voice-over

Timeline (30 fps, 900 frames)
  s1  150f  0.000-5.000   problem        fade-in text
  xfade fadewhite 18f    4.400-5.000    (explosive flash, synced with the music drop)
  s2  160f  4.400-9.733   Ultra Fiber
  xfade fade 18f          9.133-9.733
  s3  290f  9.133-18.800  IPTV
  xfade smoothleft 18f    18.200-18.800
  s4  172f  18.200-23.933 stability
  xfade fade 18f          23.333-23.933
  s5  200f  23.333-30.000 logo + CTA
"""
import os
import subprocess
import sys


def _ensure_deps():
    """Make vendored python deps importable (repo-local .tools, then legacy path)."""
    base = os.path.dirname(os.path.abspath(__file__))
    for p in (os.path.join(base, "..", ".tools", "pylibs"), "/home/user/tools/pylibs"):
        p = os.path.abspath(p)
        if os.path.isdir(p) and p not in sys.path:
            sys.path.insert(0, p)


_ensure_deps()

import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
SC = os.path.join(HERE, "scenes")
TXT = os.path.join(HERE, "text")
AST = os.path.join(HERE, "assets")
AUD = os.path.join(HERE, "audio")
BUILD = os.path.join(HERE, "build")
OUT = os.path.join(HERE, "alpha_vision_promo_30s.mp4")

FPS = 30
N = [150, 160, 290, 172, 200]
ZOOM = [("in", 0.06), ("out", 0.08), ("in", 0.07), ("out", 0.07), ("in", 0.05)]
TRANS = ["fadewhite", "fade", "smoothleft", "fade"]
T = 18  # transition length in frames (0.6s)


def ffmpeg_exe():
    _ensure_deps()
    import imageio_ffmpeg
    return imageio_ffmpeg.get_ffmpeg_exe()


def prepare_logo():
    """Use the logo as-is when it has real transparency; otherwise key out the white bg.
    Then scale it to broadcast size and put a soft white glow behind it so the dark
    navy mark stays readable on the dark scene-5 background."""
    src = os.path.join(AST, "logo_alpha.png")
    dst = os.path.join(AST, "logo_cut.png")
    im = Image.open(src)
    has_alpha = False
    if im.mode in ("RGBA", "LA") or (im.mode == "P" and "transparency" in im.info):
        im = im.convert("RGBA")
        a = np.array(im)[:, :, 3]
        has_alpha = bool(a.min() < 250)
    if not has_alpha:
        arr = np.array(im.convert("RGB")).astype(np.float32)
        dist = np.sqrt(((255.0 - arr) ** 2).sum(axis=2))
        alpha = np.clip(dist * 1.35, 0, 255).astype(np.uint8)
        im = Image.fromarray(np.dstack([arr.astype(np.uint8), alpha]), "RGBA")
    # scale to a centered lockup (native art is ~3515px wide)
    tw = 880
    th = max(1, round(im.height * tw / im.width))
    im = im.resize((tw, th), Image.LANCZOS)
    # soft white halo behind the mark
    pad = 48
    big = Image.new("RGBA", (tw + 2 * pad, th + 2 * pad), (0, 0, 0, 0))
    big.alpha_composite(im, (pad, pad))
    alpha = np.array(big.split()[3]).astype(np.uint16)
    g1 = np.array(big.split()[3].filter(ImageFilter.GaussianBlur(20))).astype(np.uint16) * 75 // 100
    g2 = np.array(big.split()[3].filter(ImageFilter.GaussianBlur(48))).astype(np.uint16) * 55 // 100
    glow = Image.new("RGBA", big.size, (255, 255, 255, 0))
    glow.putalpha(Image.fromarray(np.maximum(g1, g2).astype(np.uint8)))
    out = Image.new("RGBA", big.size, (0, 0, 0, 0))
    out.alpha_composite(glow)
    out.alpha_composite(big)
    out.save(dst)
    print(f"logo prepared -> {dst} ({out.width}x{out.height})")
    return dst, out.width, out.height, pad


def offsets():
    cum = N[0]
    offs = []
    for i in range(1, 5):
        offs.append((cum - T) / FPS)
        cum += N[i] - T
    assert cum == 900, f"timeline must be 900 frames, got {cum}"
    return offs


def build_graph(logo_y):
    f = []
    for i, (mode, amt) in enumerate(ZOOM):
        n = N[i]
        z = f"1+{amt}*on/{n}" if mode == "in" else f"{1 + amt}-{amt}*on/{n}"
        f.append(
            f"[{i}:v]scale=2202:1238:flags=lanczos,setsar=1,"
            f"zoompan=z='{z}':x='(iw-iw/zoom)/2':y='(ih-ih/zoom)/2':d={n}:s=1920x1080:fps={FPS},"
            f"format=rgba[sc{i + 1}]"
        )
    for i in range(5):
        n = N[i]
        dur = n / FPS
        tin = 0.25 if i == 0 else 0.2
        if i < 4:
            ts, td = dur - 1.1, 0.5
        else:
            ts, td = dur - 1.4, 1.4
        f.append(
            f"[{5 + i}:v]format=rgba,loop=loop=-1:size=1:start=0,fps={FPS},"
            f"trim=duration={dur:.6f},setpts=PTS-STARTPTS,"
            f"fade=t=in:st={tin}:d=0.7:alpha=1,fade=t=out:st={ts:.6f}:d={td}:alpha=1[t{i + 1}]"
        )
    f.append(
        "[10:v]format=rgba,loop=loop=-1:size=1:start=0,fps=30,trim=duration=6.666667,"
        "setpts=PTS-STARTPTS,fade=t=in:st=0.35:d=0.8:alpha=1[lg]"
    )
    f.append("[sc1][t1]overlay=0:0[v1]")
    f.append("[sc2][t2]overlay=0:0[v2]")
    f.append("[sc3][t3]overlay=0:0[v3]")
    f.append("[sc4][t4]overlay=0:0[v4]")
    f.append(f"[sc5][lg]overlay=(W-w)/2:{logo_y}[v5a]")
    f.append("[v5a][t5]overlay=0:0[v5]")
    offs = offsets()
    f.append(f"[v1][v2]xfade=transition={TRANS[0]}:duration=0.6:offset={offs[0]:.6f}[x1]")
    f.append(f"[x1][v3]xfade=transition={TRANS[1]}:duration=0.6:offset={offs[1]:.6f}[x2]")
    f.append(f"[x2][v4]xfade=transition={TRANS[2]}:duration=0.6:offset={offs[2]:.6f}[x3]")
    f.append(f"[x3][v5]xfade=transition={TRANS[3]}:duration=0.6:offset={offs[3]:.6f}[x4]")
    f.append("[x4]format=yuv420p[vout]")
    # audio: duck the music under the voice-over, normalize, fade out
    # (the VO feed must be padded to the full 30s: sidechaincompress truncates to
    # its shortest input, which would silence everything after the VO ends; and it
    # must be split explicitly since each link can only be consumed once)
    f.append("[11:a]aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo[mus]")
    f.append(
        "[12:a]aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo,"
        "adelay=4200:all=1,apad=whole_len=1440000,asplit=2[vo1][vo2]"
    )
    f.append("[mus][vo1]sidechaincompress=threshold=0.02:ratio=12:attack=10:release=400:makeup=1[duck]")
    f.append(
        "[duck][vo2]amix=inputs=2:duration=first:dropout_transition=0:normalize=0,"
        "alimiter=limit=0.97,loudnorm=I=-14:TP=-1.5:LRA=11,afade=t=out:st=28.7:d=1.3[aout]"
    )
    return ";\n".join(f)


def main():
    os.makedirs(BUILD, exist_ok=True)
    logo, lw, lh, lpad = prepare_logo()
    # center the logo's core (excluding glow padding) around y=430
    logo_y = max(0, 430 - lh // 2 - lpad)
    graph = build_graph(logo_y)
    gpath = os.path.join(BUILD, "graph.txt")
    with open(gpath, "w", encoding="utf-8") as g:
        g.write(graph)

    cmd = [ffmpeg_exe(), "-y"]
    for name in ("scene1.png", "scene2.png", "scene3.png", "scene4.png", "scene5_bg.png"):
        cmd += ["-i", os.path.join(SC, name)]
    for name in ("s1_card.png", "s2_card.png", "s3_card.png", "s4_card.png", "s5_card.png"):
        cmd += ["-i", os.path.join(TXT, name)]
    cmd += ["-i", logo]
    cmd += ["-i", os.path.join(AUD, "music.wav")]
    cmd += ["-i", os.path.join(AUD, "vo.wav")]
    cmd += [
        "-filter_complex_script", gpath,
        "-map", "[vout]", "-map", "[aout]",
        "-c:v", "libx264", "-preset", "medium", "-crf", "18",
        "-profile:v", "high", "-pix_fmt", "yuv420p", "-r", "30",
        "-c:a", "aac", "-b:a", "192k", "-ar", "48000",
        "-movflags", "+faststart", "-t", "30",
        OUT,
    ]
    print("running ffmpeg...")
    subprocess.run(cmd, check=True)
    size = os.path.getsize(OUT) / 1e6
    print(f"wrote {OUT} ({size:.1f} MB)")


if __name__ == "__main__":
    main()
