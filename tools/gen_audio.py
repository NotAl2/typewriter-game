"""Synthesize the whole sound set with numpy.

    python tools/gen_audio.py

There are no recordings in this project, so every sound is built from noise,
damped sines and envelopes. The goal is a set that is *cohesive and unobtrusive*
rather than one that fools anybody: these are honest placeholders, and swapping
in real recordings is a matter of dropping WAVs over these filenames.

The typewriter voice is layered the way the real machine is:

    key press   = mechanism transient (broadband, very short)
                + slug on platen      (bright, 3-5 kHz)
                + body thump          (~130 Hz, gives it weight)

Filtering is done in the frequency domain because it needs no scipy and cannot
ring or go unstable.
"""

import math
import os
import struct
import wave

import numpy as np

SR = 44100
OUT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", "assets",
                                    "audio"))

rng = np.random.default_rng(20250908)      # fixed: regeneration is deterministic


# --------------------------------------------------------------------------
# primitives
# --------------------------------------------------------------------------

def n_samples(seconds):
    return int(SR * seconds)


def noise(seconds):
    return rng.uniform(-1.0, 1.0, n_samples(seconds))


def pink(seconds):
    """1/f noise via spectral shaping - the basis of rain and room tone."""
    n = n_samples(seconds)
    spec = np.fft.rfft(rng.normal(0.0, 1.0, n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    f[0] = f[1] if len(f) > 1 else 1.0
    spec /= np.sqrt(f)
    out = np.fft.irfft(spec, n)
    return out / (np.max(np.abs(out)) + 1e-9)


def band(sig, lo, hi, edge=0.35):
    """Frequency-domain band pass with soft cosine edges."""
    n = len(sig)
    spec = np.fft.rfft(sig)
    f = np.fft.rfftfreq(n, 1.0 / SR)
    mask = np.ones_like(f)
    lo_e = max(1.0, lo * edge)
    hi_e = max(1.0, hi * edge)
    below = f < lo
    mask[below] = 0.5 * (1 - np.cos(np.pi * np.clip(
        (f[below] - (lo - lo_e)) / lo_e, 0, 1)))
    above = f > hi
    mask[above] = 0.5 * (1 + np.cos(np.pi * np.clip(
        (f[above] - hi) / hi_e, 0, 1)))
    return np.fft.irfft(spec * mask, n)


def env(seconds, attack, decay, power=2.0):
    """Percussive envelope: near-instant attack, exponential tail."""
    n = n_samples(seconds)
    t = np.arange(n) / SR
    a = np.clip(t / max(1e-5, attack), 0, 1)
    d = np.exp(-t / max(1e-5, decay)) ** power
    return a * d


def sine(freq, seconds, phase=0.0):
    t = np.arange(n_samples(seconds)) / SR
    return np.sin(2 * np.pi * freq * t + phase)


def damped(freq, seconds, decay, power=1.0):
    return sine(freq, seconds) * env(seconds, 0.0004, decay, power)


def pad(sig, seconds):
    n = n_samples(seconds)
    if len(sig) >= n:
        return sig[:n]
    return np.concatenate([sig, np.zeros(n - len(sig))])


def at(base, sig, seconds):
    """Add `sig` into `base` starting at `seconds`."""
    i = n_samples(seconds)
    j = min(len(base), i + len(sig))
    if i < len(base):
        base[i:j] += sig[:j - i]
    return base


def loopable(sig, fade=0.30):
    """Cross-fade the tail over the head so the file loops without a seam."""
    f = n_samples(fade)
    if f * 2 >= len(sig):
        return sig
    head = sig[:f].copy()
    tail = sig[-f:].copy()
    ramp = np.linspace(0.0, 1.0, f)
    sig = sig[:-f]
    sig[:f] = tail * (1 - ramp) + head * ramp
    return sig


def write(name, sig, peak=0.85):
    os.makedirs(OUT, exist_ok=True)
    sig = np.nan_to_num(sig)
    m = np.max(np.abs(sig))
    if m > 1e-9:
        sig = sig / m * peak
    data = (sig * 32767).astype("<i2")
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    return path, len(sig) / float(SR)


# --------------------------------------------------------------------------
# the typewriter
# --------------------------------------------------------------------------

def key_clack(variant):
    """One keystroke. Six variants so repeated typing never sounds looped."""
    dur = 0.11
    jitter = 1.0 + (variant - 2.5) * 0.055
    out = np.zeros(n_samples(dur))

    # mechanism: a very short broadband tick
    mech = band(noise(0.02), 1200 * jitter, 6500 * jitter) * env(0.02, 0.0002,
                                                                 0.004)
    out = at(out, mech * 0.9, 0.0)

    # slug striking the platen, a hair later and much brighter
    slug = band(noise(0.05), 2600 * jitter, 7200 * jitter) * env(0.05, 0.0003,
                                                                 0.010)
    out = at(out, slug * 0.75, 0.004)

    # body thump - this is what gives the machine mass
    thump = (damped(126 * jitter, 0.09, 0.020) * 0.55 +
             damped(197 * jitter, 0.09, 0.014) * 0.25)
    out = at(out, thump, 0.003)
    return out


def key_dead():
    """Margin reached: the key moves, nothing prints. A dull, wrong sound."""
    out = np.zeros(n_samples(0.10))
    out = at(out, band(noise(0.03), 200, 1400) * env(0.03, 0.001, 0.010) * 0.8,
             0.0)
    out = at(out, damped(88, 0.09, 0.022) * 0.6, 0.002)
    return out


def carriage_advance():
    """The escapement letting the carriage slip one column."""
    out = np.zeros(n_samples(0.035))
    out = at(out, band(noise(0.012), 3000, 9000) * env(0.012, 0.0002, 0.0025),
             0.0)
    out = at(out, damped(1750, 0.03, 0.005) * 0.35, 0.0005)
    return out


def bell():
    """Margin bell. Two inharmonic partials is what makes it a bell, not a beep."""
    dur = 1.4
    out = (damped(2110, dur, 0.34, power=0.9) * 0.70 +
           damped(3170, dur, 0.22, power=0.9) * 0.42 +
           damped(4830, dur, 0.11, power=0.9) * 0.18 +
           damped(6290, dur, 0.05, power=0.9) * 0.08)
    out = at(out, band(noise(0.01), 3000, 11000) * env(0.01, 0.0002, 0.002) * 0.5,
             0.0)
    return out


def carriage_return():
    """Ratchet zip that accelerates, then the carriage slamming into its stop."""
    dur = 0.62
    out = np.zeros(n_samples(dur))
    t = 0.0
    gap = 0.020
    while t < 0.36:
        click = band(noise(0.010), 2400, 8500) * env(0.010, 0.0002, 0.0018)
        out = at(out, click * rng.uniform(0.35, 0.6), t)
        t += gap
        gap = max(0.0055, gap * 0.885)          # accelerating as it flies back
    # the stop
    slam = np.zeros(n_samples(0.26))
    slam = at(slam, band(noise(0.06), 90, 2600) * env(0.06, 0.0004, 0.013) * 0.95,
              0.0)
    slam = at(slam, damped(104, 0.24, 0.045) * 0.8, 0.0)
    slam = at(slam, damped(163, 0.20, 0.030) * 0.4, 0.0)
    slam = at(slam, damped(2300, 0.10, 0.012) * 0.2, 0.001)
    out = at(out, slam, 0.36)
    return out


def platen_ratchet():
    """One notch of the platen knob."""
    out = np.zeros(n_samples(0.05))
    out = at(out, band(noise(0.016), 1500, 6000) * env(0.016, 0.0003, 0.004), 0.0)
    out = at(out, damped(640, 0.04, 0.008) * 0.3, 0.0)
    return out


def jam_clunk():
    """Two typebars colliding: metallic, ugly, and abruptly stopped."""
    dur = 0.42
    out = np.zeros(n_samples(dur))
    out = at(out, band(noise(0.05), 700, 5200) * env(0.05, 0.0002, 0.011) * 1.0,
             0.0)
    for f, a, d in ((1420, 0.34, 0.10), (2270, 0.26, 0.07), (3610, 0.16, 0.04),
                    (98, 0.55, 0.06)):
        out = at(out, damped(f, dur, d) * a, 0.001)
    # a short buzzing rattle as the bars settle against each other
    rattle = band(noise(0.16), 900, 3400) * env(0.16, 0.01, 0.045) * 0.22
    out = at(out, rattle * (0.6 + 0.4 * np.sin(
        np.arange(len(rattle)) / SR * 2 * np.pi * 47)), 0.05)
    return out


def jam_clear():
    """The bars snapping free and dropping home - relief, in one sound."""
    out = np.zeros(n_samples(0.30))
    out = at(out, band(noise(0.02), 1800, 7000) * env(0.02, 0.0002, 0.005) * 0.7,
             0.0)
    out = at(out, damped(2650, 0.26, 0.055) * 0.5, 0.002)
    out = at(out, damped(1760, 0.22, 0.040) * 0.3, 0.002)
    out = at(out, band(noise(0.03), 200, 1800) * env(0.03, 0.001, 0.008) * 0.5,
             0.10)
    return out


# --------------------------------------------------------------------------
# paper, wax, seal
# --------------------------------------------------------------------------

def _paper_texture(dur, lo, hi, roughness):
    """Filtered noise whose amplitude follows a slow random walk.

    The walk is what makes it read as paper: a flat noise burst sounds like
    static, while an uneven one sounds like a sheet being handled.
    """
    n = n_samples(dur)
    walk = rng.normal(0, 1, max(2, int(n / (SR * 0.004))))
    walk = np.cumsum(walk)
    walk = walk - walk.mean()
    walk = walk / (np.max(np.abs(walk)) + 1e-9)
    walk = np.interp(np.linspace(0, len(walk) - 1, n), np.arange(len(walk)), walk)
    amp = np.clip(0.5 + roughness * walk, 0.05, 1.5)
    return band(noise(dur), lo, hi) * amp


def paper_rustle():
    return _paper_texture(0.42, 1400, 9000, 0.85) * env(0.42, 0.02, 0.14, 1.0)


def paper_slide():
    sig = _paper_texture(0.55, 900, 7000, 0.6)
    t = np.linspace(0, 1, len(sig))
    return sig * np.sin(np.pi * t) ** 1.3          # swells then fades


def paper_feed():
    """Sheet being drawn in around the platen: rustle plus ratchet notches."""
    out = pad(_paper_texture(0.7, 1100, 8000, 0.7) * 0.55, 0.7)
    for k in range(7):
        out = at(out, platen_ratchet() * 0.5, 0.05 + k * 0.085)
    return out


def paper_crease():
    """A fold being pressed flat: short, dry, with a crisp snap at the end."""
    out = np.zeros(n_samples(0.30))
    out = at(out, _paper_texture(0.18, 1200, 8000, 0.9) *
             env(0.18, 0.01, 0.05, 1.0) * 0.7, 0.0)
    snap = band(noise(0.04), 2200, 11000) * env(0.04, 0.0004, 0.008)
    out = at(out, snap * 0.9, 0.15)
    return out


def paper_tear():
    """The failure sound. Deliberately unpleasant."""
    dur = 0.55
    sig = band(noise(dur), 1600, 12000)
    n = len(sig)
    # a stuttering amplitude, because tearing is a series of small failures
    stut = rng.uniform(0.25, 1.0, max(2, int(n / (SR * 0.006))))
    stut = np.interp(np.linspace(0, len(stut) - 1, n), np.arange(len(stut)), stut)
    ramp = np.concatenate([np.linspace(0.3, 1.0, int(n * 0.7)),
                           np.linspace(1.0, 0.0, n - int(n * 0.7))])
    return sig * stut * ramp


def wax_sizzle():
    """Loop played while the stick is held in the flame."""
    sig = band(pink(2.4), 700, 6500)
    n = len(sig)
    lfo = 0.65 + 0.35 * np.sin(np.arange(n) / SR * 2 * np.pi * 3.1)
    lfo *= 0.8 + 0.2 * np.sin(np.arange(n) / SR * 2 * np.pi * 0.7 + 1.1)
    return loopable(sig * lfo * 0.5)


def wax_drip():
    """A bead of wax landing: a soft, pitched-down blip."""
    dur = 0.16
    t = np.arange(n_samples(dur)) / SR
    glide = 520 * np.exp(-t * 22) + 130
    phase = 2 * np.pi * np.cumsum(glide) / SR
    out = np.sin(phase) * env(dur, 0.0008, 0.026)
    out += band(noise(dur), 400, 3000) * env(dur, 0.0006, 0.010) * 0.35
    return out


def stamp_press():
    """Brass into soft wax: a low squelch under a compressed thud."""
    dur = 0.34
    out = np.zeros(n_samples(dur))
    squelch = band(noise(0.20), 150, 2200) * env(0.20, 0.010, 0.055, 1.0)
    n = len(squelch)
    # sweep the band down over time by amplitude-shaping two filtered copies
    lowish = band(noise(0.20), 90, 700) * env(0.20, 0.010, 0.06, 1.0)
    ramp = np.linspace(0, 1, n)
    out = at(out, squelch * (1 - ramp) * 0.7 + lowish * ramp * 0.9, 0.0)
    out = at(out, damped(78, 0.26, 0.05) * 0.6, 0.02)
    out = at(out, band(noise(0.02), 800, 4000) * env(0.02, 0.0005, 0.005) * 0.4,
             0.0)
    return out


def stamp_peel():
    """Lifting the die away: a sticky release with a small tick."""
    dur = 0.30
    sig = band(noise(dur), 600, 5200)
    n = len(sig)
    grip = rng.uniform(0.15, 1.0, max(2, int(n / (SR * 0.008))))
    grip = np.interp(np.linspace(0, len(grip) - 1, n), np.arange(len(grip)), grip)
    out = sig * grip * env(dur, 0.02, 0.07, 1.0) * 0.7
    out = at(out, band(noise(0.02), 2000, 9000) * env(0.02, 0.0004, 0.004) * 0.5,
             0.22)
    return out


# --------------------------------------------------------------------------
# room
# --------------------------------------------------------------------------

def candle_crackle():
    """Sparse micro-transients over a very quiet bed."""
    dur = 4.0
    out = band(pink(dur), 300, 2600) * 0.05
    for _ in range(22):
        t = rng.uniform(0.0, dur - 0.05)
        tick = band(noise(0.03), 900, 7000) * env(0.03, 0.0003, 0.005)
        out = at(out, tick * rng.uniform(0.06, 0.30), t)
    return loopable(out, 0.5)


def clock_tick():
    out = np.zeros(n_samples(0.09))
    out = at(out, band(noise(0.02), 1800, 8000) * env(0.02, 0.0002, 0.004), 0.0)
    out = at(out, damped(1180, 0.06, 0.010) * 0.4, 0.0)
    out = at(out, damped(320, 0.05, 0.008) * 0.25, 0.0)
    return out


def rain():
    dur = 6.0
    sig = band(pink(dur), 420, 9000)
    n = len(sig)
    gust = 0.72
    for f, a in ((0.13, 0.16), (0.31, 0.09), (0.07, 0.12)):
        gust = gust + a * np.sin(np.arange(n) / SR * 2 * np.pi * f +
                                 rng.uniform(0, 6))
    out = sig * np.clip(gust, 0.15, 1.4) * 0.5
    for _ in range(90):                     # individual drops on the glass
        t = rng.uniform(0, dur - 0.03)
        d = band(noise(0.018), 2000, 11000) * env(0.018, 0.0004, 0.003)
        out = at(out, d * rng.uniform(0.05, 0.22), t)
    return loopable(out, 0.8)


def room_tone():
    dur = 8.0
    sig = band(pink(dur), 30, 420)
    n = len(sig)
    lfo = 0.8 + 0.2 * np.sin(np.arange(n) / SR * 2 * np.pi * 0.06)
    return loopable(sig * lfo * 0.35, 1.0)


def thunder():
    """Distant, felt more than heard."""
    dur = 3.2
    sig = band(pink(dur), 25, 260)
    t = np.linspace(0, 1, len(sig))
    shape = np.clip(np.sin(np.pi * t ** 0.55), 0, 1) ** 1.6
    rumble = 1.0 + 0.35 * np.sin(t * 2 * np.pi * 1.7) * np.exp(-t * 2)
    return sig * shape * rumble * 0.6


def chime_complete():
    """The letter is sealed. A quiet, warm two-note figure - not a fanfare."""
    dur = 2.6
    out = np.zeros(n_samples(dur))
    for i, f in enumerate((523.25, 783.99)):
        v = (damped(f, dur, 0.75, power=0.85) * 0.5 +
             damped(f * 2, dur, 0.34, power=0.85) * 0.16 +
             damped(f * 3.01, dur, 0.15, power=0.85) * 0.06)
        out = at(out, v, i * 0.20)
    return out


# --------------------------------------------------------------------------

SOUNDS = {
    "key_dead": key_dead,
    "typebar_strike": lambda: key_clack(2) * 1.0,
    "carriage_advance": carriage_advance,
    "bell": bell,
    "carriage_return": carriage_return,
    "platen_ratchet": platen_ratchet,
    "jam_clunk": jam_clunk,
    "jam_clear": jam_clear,
    "paper_rustle": paper_rustle,
    "paper_slide": paper_slide,
    "paper_feed": paper_feed,
    "paper_crease": paper_crease,
    "paper_tear": paper_tear,
    "wax_sizzle": wax_sizzle,
    "wax_drip": wax_drip,
    "stamp_press": stamp_press,
    "stamp_peel": stamp_peel,
    "candle_crackle": candle_crackle,
    "clock_tick": clock_tick,
    "rain": rain,
    "room_tone": room_tone,
    "thunder": thunder,
    "chime_complete": chime_complete,
}


def main():
    total = 0.0
    made = []
    for i in range(6):
        _, dur = write("key_clack_%d" % (i + 1), key_clack(i), peak=0.72)
        made.append("key_clack_%d" % (i + 1))
        total += dur
    for name, fn in sorted(SOUNDS.items()):
        peak = 0.55 if name in ("room_tone", "rain", "candle_crackle",
                                "wax_sizzle") else 0.85
        _, dur = write(name, fn(), peak=peak)
        made.append(name)
        total += dur
    print("%d sounds, %.1fs total -> %s" % (len(made), total, OUT))


if __name__ == "__main__":
    main()
