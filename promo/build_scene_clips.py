#!/usr/bin/env python3
"""Render each scene of the Alpha Visión Digital promo as a standalone clip.

Every clip keeps the exact look of the master timeline (Ken Burns motion,
typography cards, logo on scene 5) and takes its audio from the final mix
(music + voice-over) at the scene's position, with short fades so it plays
cleanly on its own.

Scene windows in the master (30 fps):
  escena1  0.000 - 5.000   problema
  escena2  4.400 - 9.733   Ultra Fiber
  escena3  9.133 - 18.800  IPTV
  escena4 18.200 - 23.933  estabilidad
  escena5 23.333 - 30.000  CTA
"""
import os
import subprocess

from build_video import FPS, HERE, N, SC, TXT, ZOOM, ffmpeg_exe, prepare_logo

MIX = os.path.join(HERE, "build", "full_mix.wav")
MASTER = os.path.join(HERE, "alpha_vision_promo_30s.mp4")
OUTDIR = os.path.join(HERE, "scene_clips")
T = 18
NAMES = [
    "escena1_problema",
    "escena2_ultra_fiber",
    "escena3_iptv",
    "escena4_estabilidad",
    "escena5_cta",
]
SCENES = ["scene1.png", "scene2.png", "scene3.png", "scene4.png", "scene5_bg.png"]
CARDS = ["s1_card.png", "s2_card.png", "s3_card.png", "s4_card.png", "s5_card.png"]


def scene_starts():
    starts = [0.0]
    cum = N[0]
    for i in range(1, 5):
        starts.append((cum - T) / FPS)
        cum += N[i] - T
    return starts


def extract_mix(ff):
    os.makedirs(os.path.dirname(MIX), exist_ok=True)
    r = subprocess.run(
        [ff, "-y", "-i", MASTER, "-vn", "-c:a", "pcm_s16le", MIX],
        check=True, capture_output=True,
    )
    print("audio mix ->", MIX)


def build_clip(ff, logo, logo_y, idx, start):
    n = N[idx]
    dur = n / FPS
    mode, amt = ZOOM[idx]
    z = f"1+{amt}*on/{n}" if mode == "in" else f"{1 + amt}-{amt}*on/{n}"
    parts = [
        f"[0:v]scale=2202:1238:flags=lanczos,setsar=1,"
        f"zoompan=z='{z}':x='(iw-iw/zoom)/2':y='(ih-ih/zoom)/2':d={n}:s=1920x1080:fps={FPS},"
        f"format=rgba[sc]"
    ]
    tin = 0.25 if idx == 0 else 0.2
    if idx < 4:
        ts, td = dur - 1.1, 0.5
    else:
        ts, td = dur - 1.4, 1.4
    parts.append(
        f"[1:v]format=rgba,loop=loop=-1:size=1:start=0,fps={FPS},"
        f"trim=duration={dur:.6f},setpts=PTS-STARTPTS,"
        f"fade=t=in:st={tin}:d=0.7:alpha=1,fade=t=out:st={ts:.6f}:d={td}:alpha=1[t]"
    )
    mix_idx = 2
    if idx == 4:
        parts.append(
            "[2:v]format=rgba,loop=loop=-1:size=1:start=0,fps=30,trim=duration=6.666667,"
            "setpts=PTS-STARTPTS,fade=t=in:st=0.35:d=0.8:alpha=1[lg]"
        )
        parts.append(f"[sc][lg]overlay=(W-w)/2:{logo_y}[sc2]")
        parts.append("[sc2][t]overlay=0:0[vout]")
        mix_idx = 3
    else:
        parts.append("[sc][t]overlay=0:0[vout]")
    afade_out = max(0.0, dur - 0.35)
    parts.append(
        f"[{mix_idx}:a]aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=stereo,"
        f"afade=t=in:st=0:d=0.25,afade=t=out:st={afade_out:.6f}:d=0.35[aout]"
    )
    graph = ";\n".join(parts)

    out = os.path.join(OUTDIR, f"{NAMES[idx]}.mp4")
    cmd = [ff, "-y", "-i", os.path.join(SC, SCENES[idx]), "-i", os.path.join(TXT, CARDS[idx])]
    if idx == 4:
        cmd += ["-i", logo]
    cmd += ["-ss", f"{start:.6f}", "-t", f"{dur:.6f}", "-i", MIX]
    cmd += [
        "-filter_complex", graph,
        "-map", "[vout]", "-map", "[aout]",
        "-c:v", "libx264", "-preset", "medium", "-crf", "18",
        "-profile:v", "high", "-pix_fmt", "yuv420p", "-r", "30",
        "-c:a", "aac", "-b:a", "192k", "-ar", "48000",
        "-movflags", "+faststart", "-t", f"{dur:.6f}", out,
    ]
    subprocess.run(cmd, check=True)
    size = os.path.getsize(out) / 1e6
    print(f"clip -> {out}  ({dur:.3f}s, master t={start:.3f}s, {size:.1f} MB)")


def main():
    os.makedirs(OUTDIR, exist_ok=True)
    ff = ffmpeg_exe()
    extract_mix(ff)
    logo, lw, lh, lpad = prepare_logo()
    logo_y = max(0, 430 - lh // 2 - lpad)
    starts = scene_starts()
    for idx in range(5):
        build_clip(ff, logo, logo_y, idx, starts[idx])
    print("done")


if __name__ == "__main__":
    main()
