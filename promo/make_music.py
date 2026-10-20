#!/usr/bin/env python3
"""Synthesize the 30s corporate-electronic music bed for the Alpha Visision Digital promo.

Timeline (seconds):
  0.0 - 4.4   gloomy minor pad + slow pulse (problem)
  3.5 - 5.0   noise/sweep riser into the white-flash transition
  5.0 - 20.0  energetic 120 BPM drop: kick, clap, hats, bass, 16th arps (Ultra Fiber + IPTV)
 20.0 - 25.0  half-time, steady chords (stability)
 25.0 - 30.0  major resolve + final impact, fade-out (CTA)
"""
import os
import wave

import numpy as np

SR = 48000
DUR = 30.0
N = int(SR * DUR)
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "audio", "music.wav")

rng = np.random.default_rng(7)


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def add(buf, sig, at, gain=1.0):
    i = int(at * SR)
    if i >= len(buf):
        return
    n = min(len(sig), len(buf) - i)
    buf[i:i + n] += sig[:n] * gain


def kick(dur=0.5, f0=125.0, f1=44.0, amp=1.0):
    n = int(dur * SR)
    tt = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-tt * 30)
    ph = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(ph) * np.exp(-tt * 7.0)
    click = rng.standard_normal(n) * np.exp(-tt * 220) * 0.30
    return (body + click) * amp


def hp_noise(n, smooth=24):
    x = rng.standard_normal(n)
    k = np.ones(smooth) / smooth
    return x - np.convolve(x, k, mode="same")


def clap(amp=1.0):
    n = int(0.32 * SR)
    tt = np.arange(n) / SR
    x = np.zeros(n)
    for d in (0.0, 0.011, 0.023):
        i = int(d * SR)
        seg = hp_noise(n - i, 20) * np.exp(-np.arange(n - i) / SR * 60)
        x[i:] += seg
    tail = hp_noise(n, 28) * np.exp(-tt * 14) * 0.35
    return (x * 0.5 + tail) * amp


def hat(amp=1.0, dec=90.0):
    n = int(0.08 * SR)
    tt = np.arange(n) / SR
    return hp_noise(n, 8) * np.exp(-tt * dec) * amp


def crash(amp=1.0):
    n = int(1.8 * SR)
    tt = np.arange(n) / SR
    return hp_noise(n, 10) * np.exp(-tt * 2.6) * amp


def riser(dur=1.4, amp=1.0):
    n = int(dur * SR)
    tt = np.arange(n) / SR
    f = 280 * np.exp(np.log(2200 / 280) * tt / dur)
    sweep = np.sin(2 * np.pi * np.cumsum(f) / SR) * 0.55
    nz = hp_noise(n, 12) * 0.45
    ramp = (tt / dur) ** 1.6
    return (sweep + nz) * ramp * amp


def pluck(freq, dur=0.22, amp=1.0):
    n = int(dur * SR)
    tt = np.arange(n) / SR
    x = np.zeros(n)
    for h, ha in ((1, 1.0), (2, 0.35), (3, 0.18), (4, 0.08)):
        x += ha * np.sin(2 * np.pi * freq * h * tt)
    return x * np.exp(-tt * 16) * amp


def saw(freq, dur, amp=1.0, det=0.006):
    n = int(dur * SR)
    tt = np.arange(n) / SR
    x = np.zeros(n)
    for h in range(1, 9):
        x += np.sin(2 * np.pi * freq * h * (1 + det) * tt) / h
        x += np.sin(2 * np.pi * freq * h * (1 - det) * tt) / h
    x *= 0.5
    a = int(0.02 * SR)
    r = int(min(0.12, dur / 3) * SR)
    e = np.ones(n)
    e[:a] = np.linspace(0, 1, a)
    e[n - r:] *= np.linspace(1, 0, r)
    return x * e * amp


def pad(midis, dur, amp=1.0, attack=0.6, release=0.8):
    n = int(dur * SR)
    tt = np.arange(n) / SR
    x = np.zeros(n)
    for m in midis:
        f = midi(m)
        for h, ha in ((1, 1.0), (2, 0.42), (3, 0.22), (4, 0.12), (5, 0.06)):
            x += ha * np.sin(2 * np.pi * f * h * tt + h * 0.7)
    x /= max(1, len(midis) * 2.0)
    e = np.ones(n)
    a = int(attack * SR)
    r = int(release * SR)
    e[:a] = np.linspace(0, 1, a) ** 1.5
    e[n - r:] *= np.linspace(1, 0, r) ** 1.2
    return x * e * amp


def main():
    L = np.zeros(N)
    R = np.zeros(N)

    # ---- Intro (0-4.4): problem, gloomy ----
    p = pad([45, 57, 60, 64], 5.2, amp=0.16, attack=1.2, release=1.0)
    add(L, p, 0.0)
    add(R, p, 0.004)
    sub = pad([33], 5.4, amp=0.12, attack=1.5, release=1.0)
    add(L, sub, 0.0)
    add(R, sub, 0.0)
    for i in range(4):
        k = kick(0.6, 100, 42, 0.35)
        add(L, k, i * 1.1)
        add(R, k, i * 1.1)

    # riser into the drop at 5.0 (white-flash 4.4-5.0)
    rz = riser(1.5, 0.5)
    add(L, rz, 3.5)
    add(R, rz, 3.5)

    # ---- Drop / Ultra Fiber (5.0-20.0): 120 BPM ----
    BEAT = 0.5
    chords = [(5.0, [45, 57, 60, 64]), (9.0, [41, 53, 57, 60]),
              (13.0, [48, 55, 60, 64]), (17.0, [43, 55, 59, 62])]
    roots = {5.0: 33, 9.0: 29, 13.0: 36, 17.0: 31}

    c = crash(0.5)
    add(L, c, 5.0)
    add(R, c, 5.002)
    for i in range(int((20.0 - 5.0) / BEAT)):
        t0 = 5.0 + i * BEAT
        k = kick(0.5, 125, 44, 0.95)
        add(L, k, t0)
        add(R, k, t0)
        if i % 2 == 1:
            cl = clap(0.5)
            add(L, cl, t0)
            add(R, cl, t0)
        for j, sub_t in enumerate((0.0, 0.25)):
            h = hat(0.22 if j == 0 else 0.13, 110)
            add(L, h, t0 + sub_t, 1.0 if j == 0 else 0.9)
            add(R, h, t0 + sub_t, 0.85 if j == 0 else 1.0)
        root = 33
        for ct, _ in chords:
            if t0 >= ct - 1e-6:
                root = roots[ct]
        b = saw(midi(root), 0.24, 0.24)
        add(L, b, t0)
        add(R, b, t0)
        b2 = saw(midi(root), 0.20, 0.14)
        add(L, b2, t0 + 0.25)
        add(R, b2, t0 + 0.25)

    for ct, ch in chords:
        dur = 4.0 if ct < 17.0 else 3.0
        p = pad(ch, dur + 0.4, 0.14, 0.25, 0.7)
        add(L, p, ct)
        add(R, p, ct + 0.006)
        step = 0.125
        nsteps = int(dur / step)
        seq = [ch[1], ch[2], ch[3], ch[2] + 12, ch[3], ch[2], ch[1] + 12, ch[2]]
        for s in range(nsteps):
            m = seq[s % len(seq)]
            pl = pluck(midi(m), 0.22, 0.20)
            if s % 2 == 0:
                add(L, pl, ct + s * step, 1.0)
                add(R, pl, ct + s * step, 0.55)
            else:
                add(L, pl, ct + s * step, 0.55)
                add(R, pl, ct + s * step, 1.0)

    # ---- Stability (20-25): half time ----
    p = pad([41, 53, 57, 60], 2.8, 0.15, 0.3, 0.6)
    add(L, p, 20.0)
    add(R, p, 20.006)
    p = pad([48, 55, 60, 64], 2.8, 0.15, 0.3, 0.6)
    add(L, p, 22.5)
    add(R, p, 22.506)
    for i in range(5):
        t0 = 20.0 + i * 1.0
        k = kick(0.7, 115, 43, 0.8)
        add(L, k, t0)
        add(R, k, t0)
        if i % 2 == 1:
            cl = clap(0.32)
            add(L, cl, t0)
            add(R, cl, t0)
        for j in range(2):
            h = hat(0.12, 100)
            add(L, h, t0 + j * 0.5, 1.0 if j == 0 else 0.7)
            add(R, h, t0 + j * 0.5, 0.7 if j == 0 else 1.0)
    root_seq = [29, 29, 36, 36, 36]
    for i, rr in enumerate(root_seq):
        b = saw(midi(rr), 0.9, 0.20)
        add(L, b, 20.0 + i * 1.0)
        add(R, b, 20.0 + i * 1.0)
    for s in range(int(5.0 / 0.25)):
        ch = [41, 53, 57, 60] if s < 10 else [48, 55, 60, 64]
        m = ch[s % 4] + (12 if (s // 4) % 2 else 0)
        pl = pluck(midi(m), 0.24, 0.13)
        add(L, pl, 20.0 + s * 0.25, 1.0 if s % 2 == 0 else 0.6)
        add(R, pl, 20.0 + s * 0.25, 0.6 if s % 2 == 0 else 1.0)

    # ---- CTA resolve (25-30) ----
    c = crash(0.55)
    add(L, c, 25.0)
    add(R, c, 25.003)
    p = pad([48, 55, 60, 64, 67], 5.2, 0.17, 0.35, 2.2)
    add(L, p, 25.0)
    add(R, p, 25.008)
    sub = pad([36], 5.0, 0.12, 0.4, 2.0)
    add(L, sub, 25.0)
    add(R, sub, 25.0)
    for t0 in (25.0, 26.0, 27.0):
        k = kick(0.8, 110, 42, 0.55)
        add(L, k, t0)
        add(R, k, t0)
    for s in range(int(4.0 / 0.5)):
        pl = pluck(midi([60, 64, 67, 72][s % 4]), 0.4, 0.10)
        add(L, pl, 25.0 + s * 0.5, 1.0)
        add(R, pl, 25.0 + s * 0.5, 0.8)

    # ---- master ----
    mix = np.stack([L, R], axis=1)
    mix = np.tanh(mix * 1.25) * 0.9
    tt = np.arange(N) / SR
    fade = np.ones(N)
    tail = tt >= 28.4
    fade[tail] = np.clip(1 - (tt[tail] - 28.4) / 1.5, 0, 1) ** 1.3
    mix *= fade[:, None]
    peak = float(np.max(np.abs(mix))) or 1.0
    mix = mix / peak * 0.92
    pcm = (mix * 32767).astype("<i2")
    with wave.open(OUT, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"wrote {OUT} ({N / SR:.2f}s)")


if __name__ == "__main__":
    main()
