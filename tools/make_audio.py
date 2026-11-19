"""Synthesizes every Gem Heist sound effect and character voice from scratch.

No samples, no licenses: everything is built from sine waves, filtered noise and a
tiny formant "voice" synthesizer. Run: python3 make_audio.py <out_dir>
Writes <out_dir>/sfx/*.wav and <out_dir>/voice/<role>_<n>.wav, plus voice_lines.json.
"""
import json
import os
import sys

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

SR = 44100
rng = np.random.default_rng(7)


# ------------------------------------------------------------------ building blocks

def t_(dur):
    return np.arange(int(SR * dur)) / SR


def env(n, a=0.005, d=0.1, s=0.0, r=0.05, sustain_level=0.0):
    """Attack / decay / sustain / release envelope, n samples long."""
    out = np.zeros(n)
    A, D, R = int(a * SR), int(d * SR), int(r * SR)
    S = max(0, n - A - D - R)
    i = 0
    out[i:i + A] = np.linspace(0, 1, A, endpoint=False)[: n - i]
    i += A
    seg = np.linspace(1, sustain_level, D, endpoint=False)[: max(0, n - i)]
    out[i:i + len(seg)] = seg
    i += len(seg)
    out[i:i + S] = sustain_level
    i += S
    if i < n:
        out[i:] = np.linspace(sustain_level, 0, n - i)
    return out


def expdecay(n, tau):
    return np.exp(-np.arange(n) / (SR * tau))


def bell(freq, dur, tau=0.35, partials=((1, 1.0), (2.76, 0.5), (5.40, 0.25), (8.93, 0.12)), detune=0.0):
    """Struck metal / crystal: inharmonic partials, each decaying faster as it gets higher."""
    t = t_(dur)
    out = np.zeros_like(t)
    for ratio, amp in partials:
        f = freq * ratio * (1 + detune * rng.uniform(-1, 1))
        out += amp * np.sin(2 * np.pi * f * t) * np.exp(-t / (tau / (ratio ** 0.5)))
    out *= np.minimum(1, t / 0.002)
    return out


def tone(freq, dur, shape="sine", vib=0.0, vib_rate=5.0):
    t = t_(dur)
    f = freq * (1 + vib * np.sin(2 * np.pi * vib_rate * t)) if np.isscalar(freq) else freq
    ph = 2 * np.pi * np.cumsum(np.broadcast_to(f, t.shape)) / SR
    if shape == "sine":
        return np.sin(ph)
    if shape == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    if shape == "saw":
        return 2 * ((ph / (2 * np.pi)) % 1) - 1
    if shape == "square":
        return np.sign(np.sin(ph))
    raise ValueError(shape)


def sweep(f0, f1, dur, shape="sine", curve="exp"):
    t = t_(dur)
    if curve == "exp":
        f = f0 * (f1 / f0) ** (t / dur)
    else:
        f = f0 + (f1 - f0) * t / dur
    ph = 2 * np.pi * np.cumsum(f) / SR
    if shape == "sine":
        return np.sin(ph)
    if shape == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    return 2 * ((ph / (2 * np.pi)) % 1) - 1


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def bp(x, lo, hi, order=2):
    b, a = butter(order, [lo / (SR / 2), min(hi / (SR / 2), 0.99)], btype="band")
    return lfilter(b, a, x)


def lp(x, cut, order=2):
    b, a = butter(order, min(cut / (SR / 2), 0.99), btype="low")
    return lfilter(b, a, x)


def hp(x, cut, order=2):
    b, a = butter(order, cut / (SR / 2), btype="high")
    return lfilter(b, a, x)


def mix(length, *parts):
    """parts: (signal, start_seconds, gain)."""
    out = np.zeros(int(SR * length))
    for sig, start, gain in parts:
        i = int(start * SR)
        n = min(len(sig), len(out) - i)
        if n > 0:
            out[i:i + n] += gain * sig[:n]
    return out


def room(x, wet=0.18, delays=(0.031, 0.047, 0.061, 0.083), fb=0.35):
    """A small, friendly room so sounds don't feel dry."""
    out = x.copy()
    for d in delays:
        n = int(d * SR)
        y = np.zeros(len(x) + n * 6)
        y[: len(x)] += x
        for k in range(1, 6):
            y[n * k: n * k + len(x)] += x * (fb ** k)
        out = out + wet / len(delays) * y[: len(out)]
    return out


def finish(x, peak=0.85, fade=0.01):
    x = x - np.mean(x)
    m = np.max(np.abs(x)) or 1
    x = x / m * peak
    f = int(fade * SR)
    if f and len(x) > f:
        x[-f:] *= np.linspace(1, 0, f)
    return x


def save(path, x):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    wavfile.write(path, SR, (np.clip(x, -1, 1) * 32767).astype(np.int16))


NOTE = {n: 440 * 2 ** ((i - 9) / 12) for i, n in enumerate(["C", "Cs", "D", "Ds", "E", "F", "Fs", "G", "Gs", "A", "As", "B"])}


def note(name, octave):
    return NOTE[name] * 2 ** (octave - 4)


# ------------------------------------------------------------------ sound effects

def sfx_tap():
    x = bp(noise(0.03), 2000, 6000) * expdecay(int(0.03 * SR), 0.006) + 0.4 * tone(1400, 0.03) * expdecay(int(0.03 * SR), 0.008)
    return finish(x, 0.5)


def sfx_draw():
    d = 0.22
    n = noise(d)
    e = env(len(n), a=0.06, d=0.16)
    x = bp(n, 1200, 5000) * e
    return finish(room(x, 0.1), 0.55)


def sfx_card_play():
    d = 0.35
    whoosh = bp(noise(d), 600, 3000) * env(int(d * SR), a=0.12, d=0.2)
    thump = lp(noise(0.08), 300) * expdecay(int(0.08 * SR), 0.02) + 0.6 * sweep(160, 70, 0.08) * expdecay(int(0.08 * SR), 0.03)
    return finish(room(mix(0.45, (whoosh, 0, 0.6), (thump, 0.22, 1.0)), 0.12), 0.75)


def sfx_gem():
    a = bell(note("E", 6), 0.9, tau=0.4)
    b = bell(note("B", 6), 0.8, tau=0.35)
    sparkle = sum(bell(f, 0.3, tau=0.08) * 0.25 for f in (3500, 4200, 5100))
    return finish(room(mix(1.0, (a, 0, 1.0), (b, 0.07, 0.7), (sparkle, 0.09, 0.5)), 0.25), 0.7)


def sfx_bank():
    # coin dropped on a stack: two quick metallic chings
    coin = lambda f: bell(f, 0.5, tau=0.18, partials=((1, 1), (1.51, 0.6), (2.1, 0.4), (3.3, 0.2)))
    return finish(room(mix(0.6, (coin(2300), 0, 1), (coin(2650), 0.06, 0.8), (coin(2450), 0.11, 0.5)), 0.15), 0.65)


def sfx_pay():
    coin = lambda f: bell(f, 0.35, tau=0.12, partials=((1, 1), (1.51, 0.6), (2.1, 0.4)))
    parts = [(coin(rng.uniform(2000, 3200)), 0.035 * i + rng.uniform(0, 0.02), 0.9 - 0.08 * i) for i in range(8)]
    return finish(room(mix(0.7, *parts), 0.15), 0.65)


def sfx_pawn():
    # ka-ching: drawer click, then a bright bell
    click = bp(noise(0.04), 1500, 5000) * expdecay(int(0.04 * SR), 0.008)
    clunk = lp(noise(0.06), 600) * expdecay(int(0.06 * SR), 0.02)
    ding = bell(note("C", 7), 0.9, tau=0.5, partials=((1, 1), (2.0, 0.4), (3.0, 0.2), (4.1, 0.1)))
    return finish(room(mix(1.0, (click, 0, 0.8), (clunk, 0.05, 0.8), (ding, 0.1, 1.0)), 0.2), 0.7)


def sfx_vault():
    d = 0.45
    slide = bp(noise(0.25), 500, 2500) * env(int(0.25 * SR), a=0.05, d=0.2)
    shut = lp(noise(0.12), 400) * expdecay(int(0.12 * SR), 0.03) + 0.7 * tone(95, 0.12) * expdecay(int(0.12 * SR), 0.04)
    latch = bp(noise(0.03), 2500, 7000) * expdecay(int(0.03 * SR), 0.005)
    return finish(room(mix(d, (slide, 0, 0.5), (shut, 0.2, 1.0), (latch, 0.3, 0.5)), 0.15), 0.7)


def sfx_steal():
    # sneaky slide-whistle swipe, then a pop
    whistle = sweep(1800, 500, 0.32, "sine") * env(int(0.32 * SR), a=0.01, d=0.31)
    pop = sweep(900, 200, 0.06) * expdecay(int(0.06 * SR), 0.02)
    swish = hp(noise(0.18), 3000) * env(int(0.18 * SR), a=0.04, d=0.14)
    return finish(room(mix(0.5, (swish, 0, 0.4), (whistle, 0.02, 0.8), (pop, 0.33, 1.0)), 0.15), 0.7)


def sfx_trade():
    up = sweep(400, 1200, 0.25, "tri") * env(int(0.25 * SR), a=0.02, d=0.23)
    down = sweep(1200, 400, 0.25, "tri") * env(int(0.25 * SR), a=0.02, d=0.23)
    blip = bell(note("G", 6), 0.4, tau=0.15)
    return finish(room(mix(0.65, (up, 0, 0.6), (down, 0.12, 0.6), (blip, 0.34, 0.7)), 0.2), 0.7)


def sfx_shakedown():
    # rattling pockets: amplitude-chopped noise
    d = 0.55
    n = bp(noise(d), 1500, 6000)
    chop = (np.sin(2 * np.pi * 22 * t_(d)) > 0.2).astype(float)
    x = n * chop * env(len(n), a=0.02, d=0.5)
    coins = sfx_pay() * 0.5
    return finish(room(mix(0.9, (x, 0, 0.8), (coins, 0.35, 1.0)), 0.15), 0.7)


def sfx_payup():
    a = sfx_pay()
    b = bell(note("G", 6), 0.6, tau=0.3)
    c = bell(note("C", 7), 0.7, tau=0.35)
    return finish(mix(1.0, (a, 0, 0.8), (b, 0.25, 0.6), (c, 0.36, 0.6)), 0.7)


def brass(freq, dur, bright=3000):
    s = tone(freq, dur, "saw") + 0.5 * tone(freq * 1.005, dur, "saw")
    e = env(len(s), a=0.03, d=0.15, s=dur, r=0.15, sustain_level=0.7)
    cut = lp(s, bright) * e
    return cut


def sfx_grand():
    d = 1.4
    stab = sum(brass(note(n, o), 0.9) for n, o in (("C", 3), ("G", 3), ("C", 4), ("E", 4)))
    rumble = lp(noise(1.2), 140) * env(int(1.2 * SR), a=0.05, d=1.1)
    hit = lp(noise(0.2), 250) * expdecay(int(0.2 * SR), 0.06)
    sparkle = sum(bell(f, 0.6, tau=0.2) * 0.2 for f in (2600, 3300, 3950, 5200))
    return finish(room(mix(d, (hit, 0, 1.0), (rumble, 0, 0.6), (stab, 0.02, 0.55), (sparkle, 0.25, 0.6)), 0.25), 0.8)


def sfx_shield():
    # a firm "thunk" into a metal shield, with a ringing clang
    thunk = lp(noise(0.12), 500) * expdecay(int(0.12 * SR), 0.03) + sweep(220, 90, 0.12) * expdecay(int(0.12 * SR), 0.04)
    clang = bell(330, 1.1, tau=0.45, partials=((1, 1), (2.32, 0.7), (4.25, 0.45), (6.8, 0.3), (9.1, 0.2)))
    return finish(room(mix(1.2, (thunk, 0, 1.0), (clang, 0.01, 0.7)), 0.25), 0.8)


def sfx_mirror():
    # shimmering bounce: a rising sparkle arpeggio that "reflects" back down
    notes = [note("C", 6), note("E", 6), note("G", 6), note("C", 7), note("G", 6), note("E", 6)]
    parts = [(bell(f, 0.6, tau=0.25, detune=0.003), 0.06 * i, 0.8) for i, f in enumerate(notes)]
    swell = sweep(600, 2400, 0.35, "sine") * env(int(0.35 * SR), a=0.3, d=0.05) * 0.4
    return finish(room(mix(1.1, (swell, 0, 1.0), *parts), 0.35), 0.75)


def sfx_snare():
    # snap shut, then a springy boing
    snap = bp(noise(0.03), 2000, 8000) * expdecay(int(0.03 * SR), 0.006)
    t = t_(0.6)
    f = 180 + 120 * np.exp(-t / 0.15) * np.sin(2 * np.pi * 14 * t)
    boing = np.sin(2 * np.pi * np.cumsum(f) / SR) * expdecay(len(t), 0.2)
    return finish(room(mix(0.7, (snap, 0, 1.0), (boing, 0.02, 0.8)), 0.15), 0.75)


def sfx_lockpick():
    clicks = [(bp(noise(0.02), 3000, 9000) * expdecay(int(0.02 * SR), 0.004), s, g) for s, g in ((0, 0.6), (0.12, 0.6), (0.22, 0.7))]
    clack = lp(noise(0.08), 900) * expdecay(int(0.08 * SR), 0.02)
    ding = bell(note("A", 6), 0.5, tau=0.2)
    return finish(room(mix(0.8, *clicks, (clack, 0.36, 1.0), (ding, 0.42, 0.6)), 0.15), 0.7)


def sfx_lucky():
    notes = [note(n, 6) for n in ("C", "D", "E", "G", "A")] + [note("C", 7)]
    parts = [(bell(f, 0.5, tau=0.2), 0.05 * i, 0.7) for i, f in enumerate(notes)]
    return finish(room(mix(0.9, *parts), 0.3), 0.7)


def sfx_wild():
    # magic twinkle with a rising swirl
    swirl = sweep(500, 2000, 0.4, "tri") * env(int(0.4 * SR), a=0.05, d=0.35) * 0.4
    tw = [(bell(rng.uniform(2500, 5000), 0.3, tau=0.1), 0.04 * i, 0.4) for i in range(10)]
    chord = sum(bell(note(n, 5), 0.9, tau=0.4) for n in ("C", "E", "G"))
    return finish(room(mix(1.1, (swirl, 0, 1.0), *tw, (chord, 0.35, 0.5)), 0.3), 0.7)


def sfx_set_complete():
    arp = [note("C", 5), note("E", 5), note("G", 5), note("C", 6)]
    parts = [(bell(f, 0.8, tau=0.35, partials=((1, 1), (2, 0.4), (3, 0.2), (4.2, 0.1))), 0.09 * i, 0.8) for i, f in enumerate(arp)]
    chord = sum(bell(note(n, o), 1.4, tau=0.7, partials=((1, 1), (2, 0.35), (3, 0.15))) for n, o in (("C", 5), ("E", 5), ("G", 5), ("C", 6)))
    sparkle = sum(bell(f, 0.5, tau=0.15) * 0.2 for f in (4186, 5274, 6272))
    return finish(room(mix(1.8, *parts, (chord, 0.4, 0.5), (sparkle, 0.45, 0.6)), 0.3), 0.8)


def sfx_win():
    # a short, triumphant fanfare
    seq = [("G", 4, 0.0, 0.14), ("C", 5, 0.14, 0.14), ("E", 5, 0.28, 0.14), ("G", 5, 0.42, 0.5)]
    lead = [(brass(note(n, o), d, 4000), s, 0.5) for n, o, s, d in seq]
    chord = sum(brass(note(n, o), 1.3, 3500) for n, o in (("C", 4), ("E", 4), ("G", 4), ("C", 5)))
    bells = [(bell(note(n, 6), 1.0, tau=0.4), 0.42 + 0.07 * i, 0.4) for i, n in enumerate(("C", "E", "G", "C"))]
    boom = lp(noise(0.3), 150) * expdecay(int(0.3 * SR), 0.1)
    return finish(room(mix(2.4, *lead, (chord, 0.92, 0.4), (boom, 0.92, 0.8), *bells), 0.3), 0.85)


def sfx_lose():
    # playful "wah-wah", not sad
    a = brass(note("G", 3), 0.35, 1500) * (1 + 0.3 * np.sin(2 * np.pi * 6 * t_(0.35)))
    t = t_(0.7)
    f = note("Fs", 3) * (1 - 0.06 * t / 0.7)
    b = lp(np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * 0.5 + tone(f, 0.7, "saw"), 1200) * env(len(t), a=0.02, d=0.3, s=0.2, r=0.2, sustain_level=0.6)
    return finish(room(mix(1.2, (a, 0, 0.7), (b, 0.38, 0.7)), 0.2), 0.7)


def sfx_coin_flip():
    pings = []
    t = 0.0
    gap = 0.05
    for i in range(12):
        pings.append((bell(3000 + 400 * (i % 2), 0.15, tau=0.04), t, 0.5))
        t += gap
        gap *= 1.12
    land = bell(2200, 0.6, tau=0.25, partials=((1, 1), (1.51, 0.6), (2.1, 0.4))) * 0.9
    return finish(room(mix(t + 0.8, *pings, (land, t, 1.0)), 0.2), 0.7)


def sfx_your_turn():
    a = bell(note("G", 5), 0.8, tau=0.4, partials=((1, 1), (2, 0.3), (3, 0.1)))
    b = bell(note("C", 6), 1.0, tau=0.5, partials=((1, 1), (2, 0.3), (3, 0.1)))
    return finish(room(mix(1.2, (a, 0, 0.8), (b, 0.14, 0.8)), 0.3), 0.6)


SFX = {
    "tap": sfx_tap, "draw": sfx_draw, "card_play": sfx_card_play, "gem": sfx_gem, "bank": sfx_bank,
    "pay": sfx_pay, "pawn": sfx_pawn, "vault": sfx_vault, "steal": sfx_steal, "trade": sfx_trade,
    "shakedown": sfx_shakedown, "payup": sfx_payup, "grand": sfx_grand, "shield": sfx_shield,
    "mirror": sfx_mirror, "snare": sfx_snare, "lockpick": sfx_lockpick, "lucky": sfx_lucky,
    "wild": sfx_wild, "set_complete": sfx_set_complete, "win": sfx_win, "lose": sfx_lose,
    "coin_flip": sfx_coin_flip, "your_turn": sfx_your_turn,
}


# ------------------------------------------------------------------ character voices
# A tiny formant synthesizer: a buzzy "voice box" filtered into vowel sounds, with a
# consonant burst at the start of each syllable. Each character has their own pitch,
# speed, vowel color, vibrato and quirks, so they're recognizable without real words.

VOWELS = {  # first three formants (Hz) and bandwidths
    "a": (800, 1200, 2500), "e": (500, 1900, 2600), "i": (320, 2300, 3000),
    "o": (500, 900, 2400), "u": (350, 800, 2300), "ah": (700, 1100, 2450),
}


def resonator(x, f, bw):
    r = np.exp(-np.pi * bw / SR)
    a1, a2 = -2 * r * np.cos(2 * np.pi * f / SR), r * r
    return lfilter([1 - r], [1, a1, a2], x)


def syllable(f0_curve, vowel, voice, consonant):
    n = len(f0_curve)
    ph = np.cumsum(f0_curve) / SR
    # glottal buzz: a softened sawtooth, richer for gruff voices
    src = 2 * (ph % 1) - 1
    src = lp(src, 3000 + 2000 * voice["bright"])
    if voice["breath"] > 0:
        src = src + voice["breath"] * bp(rng.uniform(-1, 1, n), 800, 6000)
    shift = voice["formant"]
    F = VOWELS[vowel]
    out = sum(resonator(src, f * shift, bw) * g for f, bw, g in zip(F, (80, 110, 160), (1.0, 0.6, 0.3)))
    out *= env(n, a=0.012, d=0.03, s=1, r=0.05, sustain_level=0.85)
    if consonant == "s":
        c = hp(rng.uniform(-1, 1, int(0.05 * SR)), 4000) * env(int(0.05 * SR), a=0.01, d=0.04) * 0.35
    elif consonant == "k":
        c = bp(rng.uniform(-1, 1, int(0.02 * SR)), 1500, 4500) * expdecay(int(0.02 * SR), 0.005) * 0.7
    elif consonant == "m":
        c = lp(src[: int(0.04 * SR)], 400) * 0.6 if n > int(0.04 * SR) else np.zeros(1)
    else:
        c = np.zeros(1)
    return np.concatenate([c, out])


def utterance(text, voice, seed):
    r = np.random.default_rng(seed)
    words = [w for w in text.replace("...", " ").split() if w]
    syllables = max(3, min(12, int(sum(max(1, sum(ch in "aeiouyAEIOUY" for ch in w)) for w in words) * 0.8)))
    excited = text.strip().endswith("!")
    question = text.strip().endswith("?")
    parts = []
    for i in range(syllables):
        dur = voice["syl"] * r.uniform(0.8, 1.25)
        n = int(dur * SR)
        t = np.arange(n) / SR
        pos = i / max(1, syllables - 1)
        # intonation: excited lines lift and land; questions rise at the end; calm lines drift down
        if excited:
            contour = 1 + 0.25 * np.sin(np.pi * pos) - (0.12 * pos if pos > 0.8 else 0)
        elif question:
            contour = 1 + 0.35 * pos ** 2
        else:
            contour = 1.05 - 0.15 * pos
        base = voice["f0"] * contour * r.uniform(0.92, 1.1)
        glide = voice["glide"] * np.sin(np.pi * t / dur)
        vib = voice["vib"] * np.sin(2 * np.pi * voice["vib_rate"] * t)
        f0 = base * (1 + glide + vib)
        vowel = r.choice(voice["vowels"])
        cons = r.choice(["", "", "k", "s", "m"] if voice["cons"] else ["", "m"])
        parts.append(syllable(f0, vowel, voice, cons))
        parts.append(np.zeros(int(voice["gap"] * SR * r.uniform(0.5, 1.5))))
    x = np.concatenate(parts)
    if voice.get("echo"):
        x = room(x, 0.35, delays=(0.09, 0.13), fb=0.4)
    else:
        x = room(x, 0.12)
    return finish(hp(x, 70), 0.8)


VOICES = {
    # Nana Bea / the player's own wild card: warm, a little wobbly, unhurried
    "you": dict(f0=230, formant=1.12, syl=0.13, gap=0.03, vib=0.035, vib_rate=5.5, glide=0.05, bright=0.4, breath=0.05, vowels=["a", "o", "e", "ah"], cons=True),
    # Pip the Pickpocket: a quick, cheeky kid
    "pickpocket": dict(f0=360, formant=1.25, syl=0.075, gap=0.015, vib=0.0, vib_rate=6, glide=0.12, bright=0.9, breath=0.0, vowels=["i", "e", "a"], cons=True),
    # Juno the Trickster: sly and sing-song
    "trickster": dict(f0=270, formant=1.15, syl=0.11, gap=0.02, vib=0.01, vib_rate=4, glide=0.22, bright=0.6, breath=0.04, vowels=["a", "o", "i"], cons=True),
    # Lou the Boss: low, gravelly, slow
    "boss": dict(f0=105, formant=0.88, syl=0.15, gap=0.04, vib=0.0, vib_rate=4, glide=0.04, bright=1.0, breath=0.12, vowels=["ah", "o", "u"], cons=True),
    # Amara the Genius: calm, smooth, confident
    "mastermind": dict(f0=205, formant=1.08, syl=0.14, gap=0.04, vib=0.008, vib_rate=4, glide=0.03, bright=0.5, breath=0.03, vowels=["a", "e", "o"], cons=False),
    # Dev the Bouncer: very deep and steady
    "bouncer": dict(f0=82, formant=0.82, syl=0.16, gap=0.05, vib=0.0, vib_rate=4, glide=0.02, bright=0.7, breath=0.05, vowels=["o", "u", "ah"], cons=False),
    # Mei the Illusionist: airy, high, with a mystical echo
    "illusionist": dict(f0=320, formant=1.2, syl=0.12, gap=0.03, vib=0.02, vib_rate=7, glide=0.15, bright=0.4, breath=0.18, vowels=["i", "u", "e"], cons=False, echo=True),
    # Rosa the Trapper: energetic and punchy
    "trapper": dict(f0=250, formant=1.14, syl=0.085, gap=0.012, vib=0.0, vib_rate=6, glide=0.1, bright=0.9, breath=0.0, vowels=["a", "e", "ah"], cons=True),
    # Kodi the Locksmith: mid, precise, clicky
    "locksmith": dict(f0=140, formant=0.97, syl=0.1, gap=0.03, vib=0.0, vib_rate=5, glide=0.05, bright=0.8, breath=0.02, vowels=["e", "o", "i"], cons=True),
}

# What each character says when their card is played. Keep lines short and friendly.
LINES = {
    "you": ["I'm wild!", "Any gem you like!", "Count me in!"],
    "pickpocket": ["Finders keepers!", "Mine now!", "Didn't see that coming!"],
    "trickster": ["Let's make a deal!", "Fair trade... ish!", "Swapsies!"],
    "boss": ["Empty those pockets!", "Pay up, pal!", "Time to settle up."],
    "mastermind": ["All according to plan.", "The whole set? Don't mind if I do.", "Checkmate."],
    "bouncer": ["Not on my watch!", "Nope. Blocked.", "You're not getting past me."],
    "illusionist": ["Right back at you!", "Mirror, mirror!", "Now you see it..."],
    "trapper": ["Gotcha!", "Caught you red-handed!", "Snap!"],
    "locksmith": ["Click! It's open.", "No lock can stop me.", "Let's see what's inside."],
}


def main(out):
    for name, fn in SFX.items():
        save(os.path.join(out, "sfx", name + ".wav"), fn())
    for role, lines in LINES.items():
        for i, line in enumerate(lines):
            save(os.path.join(out, "voice", f"{role}_{i}.wav"), utterance(line, VOICES[role], hash((role, i)) % 10000))
    with open(os.path.join(out, "voice_lines.json"), "w") as f:
        json.dump(LINES, f, indent=1)
    print("wrote", len(SFX), "effects and", sum(len(v) for v in LINES.values()), "voice lines")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "out")
