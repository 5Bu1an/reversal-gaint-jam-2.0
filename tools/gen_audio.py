#!/usr/bin/env python3
"""Synthesizes Tenet's placeholder sound effects and music loop.

Writes 16-bit mono WAVs into assets/audio. Deterministic, so rerunning gives
the same files. Any file can be replaced by a real sound with the same name
(.wav or .ogg); the game loads whichever exists.

    python3 tools/gen_audio.py
"""
import math
import os
import random
import struct
import wave
from array import array

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
rng = random.Random(1337)


# ---------- building blocks ----------

def osc(shape, phase):
    p = phase % 1.0
    if shape == "sine":
        return math.sin(2 * math.pi * p)
    if shape == "square":
        return 1.0 if p < 0.5 else -1.0
    if shape == "pulse":
        return 1.0 if p < 0.25 else -1.0
    if shape == "saw":
        return 2.0 * p - 1.0
    if shape == "tri":
        return 4.0 * abs(p - 0.5) - 1.0
    raise ValueError(shape)


def voice(dur, freq, shape="square", decay=10.0, attack=0.004, vol=0.5, vibrato=0.0, vib_rate=0.0):
    """freq is a constant or a function of t (seconds)."""
    n = int(dur * SR)
    out = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / SR
        f = freq(t) if callable(freq) else freq
        if vibrato:
            f *= 1.0 + vibrato * math.sin(2 * math.pi * vib_rate * t)
        phase += f / SR
        env = min(1.0, t / attack) * math.exp(-decay * t) if attack > 0 else math.exp(-decay * t)
        out[i] = osc(shape, phase) * env * vol
    return out


def noise(dur, decay=20.0, vol=0.5, cutoff=None, highpass=False, attack=0.002):
    n = int(dur * SR)
    out = [0.0] * n
    y = 0.0
    for i in range(n):
        t = i / SR
        x = rng.uniform(-1, 1)
        if cutoff:
            fc = cutoff(t) if callable(cutoff) else cutoff
            a = 1 - math.exp(-2 * math.pi * fc / SR)
            y += a * (x - y)
            x = x - y if highpass else y * 2.5
        env = min(1.0, t / attack) * math.exp(-decay * t)
        out[i] = x * env * vol
    return out


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for track in tracks:
        for i, s in enumerate(track):
            out[i] += s
    return out


def seq(*parts):
    """Concatenate (start_seconds, samples) pairs into one buffer."""
    n = max(int(start * SR) + len(s) for start, s in parts)
    out = [0.0] * n
    for start, samples in parts:
        o = int(start * SR)
        for i, s in enumerate(samples):
            out[o + i] += s
    return out


def lowpass(samples, fc):
    a = 1 - math.exp(-2 * math.pi * fc / SR)
    y = 0.0
    out = []
    for x in samples:
        y += a * (x - y)
        out.append(y)
    return out


def save(name, samples, peak=0.85):
    top = max(1e-9, max(abs(s) for s in samples))
    gain = peak / top if top > peak else 1.0
    data = array("h", (int(max(-1.0, min(1.0, s * gain)) * 32767) for s in samples))
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"{name}.wav  {len(samples) / SR:.2f}s")


def glide(f0, f1, dur, curve=1.0):
    return lambda t: f0 + (f1 - f0) * min(1.0, t / dur) ** curve


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


# ---------- sound effects ----------

def effects():
    save("jump", voice(0.14, glide(220, 560, 0.12), "square", decay=16, vol=0.35))
    save("dash", mix(
        noise(0.22, decay=12, vol=0.5, cutoff=glide(3000, 400, 0.2)),
        voice(0.2, glide(320, 70, 0.2), "saw", decay=14, vol=0.25)))
    save("slash", mix(
        noise(0.1, decay=35, vol=0.6, cutoff=1500, highpass=True),
        voice(0.1, glide(1100, 300, 0.1), "sine", decay=30, vol=0.35)))
    save("hit", mix(
        voice(0.12, glide(200, 55, 0.1), "square", decay=25, vol=0.5),
        noise(0.05, decay=60, vol=0.5)))
    save("kill", mix(
        voice(0.14, glide(220, 50, 0.12), "square", decay=20, vol=0.5),
        noise(0.35, decay=10, vol=0.45, cutoff=glide(5000, 300, 0.3)),
        voice(0.3, glide(700, 90, 0.3), "sine", decay=9, vol=0.3)))
    save("hurt", mix(
        voice(0.3, glide(320, 85, 0.28), "saw", decay=9, vol=0.5, vibrato=0.08, vib_rate=30),
        noise(0.12, decay=25, vol=0.4)))
    save("death", mix(
        voice(1.0, glide(420, 35, 0.95, 0.6), "saw", decay=3, vol=0.5, vibrato=0.1, vib_rate=11),
        noise(0.8, decay=4, vol=0.3, cutoff=glide(4000, 150, 0.8))))
    save("shard", seq(
        (0.0, voice(0.18, 880, "tri", decay=18, vol=0.35)),
        (0.05, voice(0.18, 1320, "tri", decay=18, vol=0.3)),
        (0.1, voice(0.3, 1760, "sine", decay=12, vol=0.3))))
    save("rewind_end", mix(
        voice(0.18, glide(180, 1300, 0.15, 2.0), "saw", decay=14, vol=0.35),
        noise(0.04, decay=80, vol=0.4)))
    save("gate", mix(
        voice(0.45, 90, "square", decay=6, vol=0.35, vibrato=0.05, vib_rate=14),
        noise(0.15, decay=25, vol=0.5, cutoff=800)))
    save("boss_slam", mix(
        voice(0.7, glide(90, 32, 0.6), "sine", decay=5, vol=0.9),
        noise(0.6, decay=7, vol=0.6, cutoff=glide(2000, 120, 0.5))))
    save("ui_move", voice(0.05, 660, "pulse", decay=40, vol=0.25))
    save("ui_select", seq(
        (0.0, voice(0.08, 660, "pulse", decay=25, vol=0.3)),
        (0.07, voice(0.2, 990, "pulse", decay=14, vol=0.3))))
    save("win", seq(*[(i * 0.11, voice(0.5 if i == 4 else 0.14, midi(n), "pulse", decay=4 if i == 4 else 14, vol=0.3))
                      for i, n in enumerate([69, 72, 76, 79, 81])]))

    # Seamless 1 s tape-rewind whir: whole cycles of every periodic part.
    n = SR
    whir = [0.0] * n
    phase = 0.0
    for i in range(n):
        t = i / SR
        f = 140 * (1 + 0.06 * math.sin(2 * math.pi * 8 * t))
        phase += f / SR
        whir[i] = osc("saw", phase) * 0.3 + rng.uniform(-1, 1) * 0.12
    save("rewind_loop", lowpass(whir, 1800), peak=0.6)


# ---------- music: 8-bar A-minor synthwave loop ----------

def music():
    bpm = 100
    step = 60 / bpm / 4  # sixteenth note
    steps = 128
    n = int(steps * step * SR)
    buf = [0.0] * n

    def add(start_step, samples, gain=1.0):
        o = int(start_step * step * SR)
        for i, s in enumerate(samples):
            buf[(o + i) % n] += s * gain  # wrap tails so the loop is seamless

    chords = [[57, 60, 64], [53, 57, 60], [55, 60, 64], [55, 59, 62]]  # Am F C G
    roots = [45, 41, 48, 43]
    kick = voice(0.3, glide(130, 42, 0.12), "sine", decay=12, vol=0.9)
    snare = mix(noise(0.18, decay=18, vol=0.45, cutoff=4000), voice(0.1, 190, "tri", decay=30, vol=0.3))
    hat = noise(0.035, decay=90, vol=0.18, cutoff=6000, highpass=True)

    for s in range(steps):
        bar = s // 16
        chord = chords[(bar // 2) % 4]
        root = roots[(bar // 2) % 4]
        beat_step = s % 16
        if beat_step % 4 == 0:
            add(s, kick)
        if beat_step in (4, 12):
            add(s, snare)
        if beat_step % 2 == 1:
            add(s, hat)
        if s % 2 == 0:
            note = root + (12 if beat_step in (6, 14) else 0)
            add(s, lowpass(voice(step * 1.9, midi(note), "saw", decay=6, vol=0.38), 700))
        arp = chord[s % 3] + 12 * (1 + (s // 3) % 2)
        tone = voice(step * 1.5, midi(arp), "pulse", decay=14, vol=0.1)
        add(s, tone)
        add(s + 3, tone, 0.35)  # echo
        add(s + 6, tone, 0.15)
        if beat_step == 0 and bar % 2 == 0:
            for note in chord:
                pad = voice(step * 32, midi(note) * 1.003, "saw", decay=0.35, attack=0.3, vol=0.05)
                add(s, lowpass(pad, 1200))
    save("music_level", buf, peak=0.8)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    effects()
    music()
