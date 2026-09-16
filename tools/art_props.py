"""Desk props - everything the player picks up, heats, folds or presses.

These carry more detail per pixel than the room does, because they are what the
cursor lands on. Each one is drawn so its *state* is readable at a glance: you
can tell molten wax from scorched wax, a crisp seal from a smeared one, and an
open envelope from a closed one, without a single word of UI.

The rose on the seal die is deliberate. Section 10 of the design document makes
the rose the game's recurring symbol, so every letter the player sends goes out
stamped with one.
"""

import math

import layout as L
from palette import C, shade, mix, Rand
from pixel import Canvas, sheet


# --------------------------------------------------------------------------
# paper
# --------------------------------------------------------------------------

def _paper_body(w, h, seed, lit=0.0):
    """A sheet of laid paper: warm, faintly fibrous, darker along the edges."""
    cv = Canvas(w, h)
    ramp = [C("paper_hi"), C("paper_lit"), C("paper_mid"), C("paper_dark")]
    cv.ramp_rect(0, 0, w, h, ramp, 0.18 - lit, 0.72 - lit)
    rnd = Rand(seed)
    # laid lines - the horizontal wire marks of period paper
    for j in range(0, h, 6):
        for i in range(w):
            if rnd.chance(0.55):
                cv.set(i, j, shade(cv.get(i, j), -0.022))
    cv.speckle(0, 0, w, h, seed + 1, amount=0.028, density=0.14)
    # edges catch less light
    for i in range(w):
        cv.set(i, 0, shade(cv.get(i, 0), 0.06))
        cv.set(i, h - 1, shade(cv.get(i, h - 1), -0.10))
    for j in range(h):
        cv.set(0, j, shade(cv.get(0, j), -0.05))
        cv.set(w - 1, j, shade(cv.get(w - 1, j), -0.09))
    return cv


def make_sheet():
    return _paper_body(L.SHEET_W, L.SHEET_H, 401)


def make_sheet_torn():
    """Same sheet with a ragged top edge - the punishment for a bad pull."""
    cv = _paper_body(L.SHEET_W, L.SHEET_H, 401)
    rnd = Rand(409)
    depth = 0
    for i in range(L.SHEET_W):
        depth = max(0, min(9, depth + rnd.i(-2, 2)))
        for j in range(depth):
            cv.set(i, j, (0, 0, 0, 0))
        cv.set(i, depth, shade(cv.get(i, depth), -0.16))
    return cv


def make_paper_stack():
    """The pile of blank sheets the player draws a fresh page from."""
    w, h = 92, 34
    cv = Canvas(w, h)
    rnd = Rand(419)
    for k in range(6):
        ox = rnd.i(-2, 2)
        oy = h - 8 - k * 4
        cv.round_rect(2 + ox, oy, w - 6, 10, 1, C("paper_shadow"))
        cv.round_rect(2 + ox, oy, w - 6, 9, 1,
                      C("paper_mid") if k < 5 else C("paper_lit"))
        cv.hline(3 + ox, oy, w - 8, C("paper_hi"))
    cv.outline(C("shadow_warm"))
    return cv


def make_folded_letter(stage):
    """stage 0 = flat, 1 = one fold, 2 = trifolded and ready for the envelope."""
    if stage == 0:
        w, h = 104, 130
    elif stage == 1:
        w, h = 104, 88
    else:
        w, h = 96, 48
    cv = _paper_body(w, h, 431)
    if stage >= 1:
        cv.hline(0, h - 1, w, C("paper_shadow"))
        cv.hline(2, 2, w - 4, C("paper_hi"))
    if stage >= 2:
        # visible crease lines across the folded packet
        for cy in (h // 3, 2 * h // 3):
            cv.hline(0, cy, w, shade(C("paper_dark"), -0.05))
            cv.hline(0, cy + 1, w, C("paper_hi"))
    cv.outline(C("shadow_warm"))
    return cv


# --------------------------------------------------------------------------
# envelope
# --------------------------------------------------------------------------

def _envelope_base(w, h):
    cv = Canvas(w, h)
    cv.round_rect(0, 0, w, h, 2, C("paper_shadow"))
    cv.ramp_rect(1, 1, w - 2, h - 2,
                 [C("paper_lit"), C("paper_mid"), C("paper_dark")], 0.1, 0.85)
    cv.speckle(1, 1, w - 2, h - 2, 443, amount=0.03, density=0.14)
    return cv


def make_envelope_closed():
    """Face up, flap down, waiting for wax."""
    w, h = L.ENVELOPE_W, L.ENVELOPE_H
    cv = _envelope_base(w, h)
    # the two rear folds meeting in a V, and the flap laid over them
    for i in range(w // 2):
        t = i / float(w // 2)
        y = int(h * 0.52 * (1.0 - abs(t * 2 - 1) * 0.0) * t) + 2
        cv.set(i, y, shade(C("paper_dark"), -0.06))
        cv.set(w - 1 - i, y, shade(C("paper_dark"), -0.06))
    # flap: a shallow triangle pointing down from the top edge
    apex = int(h * 0.56)
    for j in range(apex):
        t = j / float(apex)
        half = int((w // 2 - 3) * (1.0 - t))
        for i in range(w // 2 - half, w // 2 + half):
            cv.set(i, j, mix(C("paper_lit"), C("paper_mid"), t * 0.75))
        cv.set(w // 2 - half, j, C("paper_shadow"))
        cv.set(w // 2 + half - 1, j, C("paper_shadow"))
    cv.hline(2, 0, w - 4, C("paper_hi"))
    cv.outline(C("shadow_warm"))
    return cv


def make_envelope_open():
    """Flap raised, mouth open - the target for dropping the folded letter."""
    w, h = L.ENVELOPE_W, L.ENVELOPE_H + 26
    cv = Canvas(w, h)
    body = _envelope_base(L.ENVELOPE_W, L.ENVELOPE_H)
    cv.blit(body, 0, 26)
    # dark mouth
    cv.frect(4, 26, w - 8, 9, C("shadow_warm"))
    cv.ramp_rect(5, 27, w - 10, 7,
                 [C("shadow"), C("void")], 0.0, 1.0)
    # raised flap, seen from behind and slightly foreshortened
    apex = 24
    for j in range(apex):
        t = 1.0 - j / float(apex)
        half = int((w // 2 - 4) * (1.0 - t * 0.92))
        for i in range(w // 2 - half, w // 2 + half):
            cv.set(i, 26 - apex + j, mix(C("paper_dark"), C("paper_mid"), t))
        cv.set(w // 2 - half, 26 - apex + j, C("paper_shadow"))
        cv.set(w // 2 + half - 1, 26 - apex + j, C("paper_shadow"))
    cv.outline(C("shadow_warm"))
    return cv


# --------------------------------------------------------------------------
# wax
# --------------------------------------------------------------------------

WAX_STATES = ("cold", "soft", "molten", "scorched")


def make_wax_stick(state):
    w, h = L.WAX_STICK_W, L.WAX_STICK_H
    cv = Canvas(w, h)
    if state == "scorched":
        body = [C("wax_dark"), C("wax_scorch"), C("void")]
    else:
        body = [C("wax_cool"), C("wax_cold"), C("wax_dark")]
    cv.round_rect(1, 0, w - 2, h, 2, body[-1])
    cv.ramp_rect(2, 1, w - 4, h - 2, body, 0.0, 1.0, vertical=False)
    cv.vline(3, 2, h - 5, mix(body[0], C("paper_hi"), 0.25))
    cv.speckle(1, 0, w - 2, h, 457, amount=0.05, density=0.18)

    tip = h - 1
    if state == "soft":
        cv.fellipse(w // 2, tip - 3, w // 2 + 1, 4, C("wax_warm"))
        cv.fellipse(w // 2, tip - 4, w // 2 - 1, 3, C("wax_molten"))
    elif state == "molten":
        cv.fellipse(w // 2, tip - 2, w // 2 + 2, 5, C("wax_warm"))
        cv.fellipse(w // 2, tip - 3, w // 2, 4, C("wax_molten"))
        cv.fellipse(w // 2 - 1, tip - 4, 2, 2, C("wax_hot"))
        cv.fdisc(w // 2, tip + 2, 2, C("wax_molten"))       # a bead about to fall
        cv.set(w // 2, tip + 4, C("wax_hot"))
    elif state == "scorched":
        cv.fellipse(w // 2, tip - 2, w // 2 + 1, 4, C("wax_scorch"))
        for k in range(3):                                   # smoke
            cv.set(w // 2 + (k % 2), tip - 8 - k * 3, C("iron_hi"))
    cv.outline(C("shadow_warm"))
    cv.rim_light(C("flame_edge"), from_left=True, strength=0.35)
    return cv


def _wax_blob(stage, temp_cols, seed=467):
    """One growth stage of the pool. Irregular, never a circle."""
    w, h = L.WAX_POOL_W, L.WAX_POOL_H
    cv = Canvas(w, h)
    t = (stage + 1) / float(L.WAX_POOL_STAGES)
    rx = 3 + (w / 2 - 3) * t
    ry = 3 + (h / 2 - 3) * t
    rnd = Rand(seed + stage * 17)
    cx, cy = w // 2, h // 2
    # lobed outline: a base ellipse pushed in and out around its circumference
    lobes = [rnd.range(0.82, 1.18) for _ in range(9)]
    for j in range(h):
        for i in range(w):
            dx = (i - cx) / max(0.5, rx)
            dy = (j - cy) / max(0.5, ry)
            d = math.hypot(dx, dy)
            if d > 1.25:
                continue
            a = (math.atan2(dy, dx) + math.pi) / math.tau * len(lobes)
            k = int(a) % len(lobes)
            k2 = (k + 1) % len(lobes)
            f = a - int(a)
            edge = lobes[k] * (1 - f) + lobes[k2] * f
            if d <= edge:
                # domed: brightest just up-left of centre, dark at the rim
                v = 1.0 - (d / edge)
                shade_t = max(0.0, min(0.999, 1.0 - v * 1.15 +
                                       (dx * 0.18 + dy * 0.22)))
                idx = int(shade_t * (len(temp_cols) - 1) + 0.5)
                cv.set(i, j, temp_cols[min(len(temp_cols) - 1, idx)])
    cv.outline(C("shadow_warm"))
    return cv


WAX_TEMP_RAMPS = [
    [C("wax_hot"), C("wax_molten"), C("wax_warm"), C("wax_cool")],      # molten
    [C("wax_molten"), C("wax_warm"), C("wax_cool"), C("wax_cold")],     # hot
    [C("wax_warm"), C("wax_cool"), C("wax_cold"), C("wax_dark")],       # setting
    [C("wax_cool"), C("wax_cold"), C("wax_dark"), shade(C("wax_dark"), -0.1)],
]


def make_wax_pool_atlas():
    """Rows = temperature (molten -> set), columns = volume."""
    frames = []
    for ramp in WAX_TEMP_RAMPS:
        for st in range(L.WAX_POOL_STAGES):
            frames.append(_wax_blob(st, ramp))
    return sheet(frames, cols=L.WAX_POOL_STAGES)


# --------------------------------------------------------------------------
# the rose seal
# --------------------------------------------------------------------------

def _rose(cv, cx, cy, r, dark, mid, light, stem=True):
    """A five-petal rose head with a spiralled bud.

    A literal spiral reads as a smudge below about 20px, so the petals are five
    overlapping lobes instead - the silhouette is what makes it legible small.
    """
    pr = r * 0.50
    ring = []
    for k in range(5):
        a = -math.pi / 2 + k * math.tau / 5
        ring.append((cx + math.cos(a) * r * 0.58, cy + math.sin(a) * r * 0.58))
    for (px, py) in ring:
        cv.fdisc(px, py, pr, dark)
    for (px, py) in ring:
        cv.fdisc(px, py, pr - 1, mid)
    for (px, py) in ring:                      # each petal keeps a lit edge
        cv.set(px - pr * 0.4, py - pr * 0.5, light)

    cv.fdisc(cx, cy, r * 0.46, dark)           # bud
    cv.fdisc(cx, cy, r * 0.34, mid)
    cv.fdisc(cx, cy, r * 0.16, light)

    if stem:
        for sgn in (-1, 1):                    # sepals
            cv.line(cx + sgn * int(r * 0.5), cy + int(r * 0.8),
                    cx + sgn * int(r * 1.05), cy + int(r * 1.15), mid)
        cv.vline(cx, cy + int(r * 0.9), max(2, int(r * 0.7)), mid)


def _emboss(cv, draw_fn, dark, light, base):
    """Render a shape as if pressed into wax: shadow down-right, light up-left."""
    sh = Canvas(cv.w, cv.h)
    draw_fn(sh, dark, dark, dark)
    hi = Canvas(cv.w, cv.h)
    draw_fn(hi, base, base, light)
    cv.blit(sh, 1, 1)
    cv.blit(hi, 0, 0)


def make_seal_die():
    """The 20x20 face of the brass die, cut in relief."""
    s = 20
    cv = Canvas(s, s)
    cv.fdisc(s // 2, s // 2, 9, C("brass_dark"))
    cv.fdisc(s // 2, s // 2, 8, C("brass"))
    cv.disc_ring(s // 2, s // 2, 8, C("brass_hi"), 1)
    _rose(cv, s // 2, s // 2 - 1, 6, shade(C("brass_dark"), -0.14),
          C("brass_dark"), C("brass_hi"))
    return cv


def make_seal_stamp():
    """Turned wooden handle, brass shaft, rose die - shown from the side."""
    w, h = L.SEAL_STAMP_W, L.SEAL_STAMP_H
    cv = Canvas(w, h)
    cx = w // 2
    # handle
    cv.round_rect(cx - 6, 0, 12, 20, 5, C("leather_dark"))
    cv.ramp_rect(cx - 5, 1, 10, 18,
                 [C("leather"), C("leather_dark"), shade(C("leather_dark"), -0.1)],
                 0.0, 1.0, vertical=False)
    cv.fellipse(cx, 3, 6, 3, C("leather"))
    cv.hline(cx - 5, 12, 10, shade(C("leather_dark"), -0.14))
    # collar + shaft
    cv.round_rect(cx - 7, 19, 14, 5, 2, C("brass_dark"))
    cv.ramp_rect(cx - 6, 20, 12, 3, [C("brass_hi"), C("brass")], 0.0, 1.0)
    cv.frect(cx - 4, 24, 8, 10, C("brass_dark"))
    cv.ramp_rect(cx - 3, 24, 6, 10, [C("brass"), C("brass_dark")], 0.0, 1.0,
                 vertical=False)
    # die head
    cv.round_rect(cx - 9, 33, 18, 10, 3, C("brass_dark"))
    cv.ramp_rect(cx - 8, 34, 16, 8, [C("brass_hi"), C("brass"), C("brass_dark")],
                 0.0, 1.0)
    cv.hline(cx - 7, 42, 14, shade(C("brass_dark"), -0.15))
    cv.set(cx - 5, 35, C("brass_glint"))
    cv.outline(C("shadow_warm"))
    cv.rim_light(C("flame_edge"), from_left=True, strength=0.4)
    return cv


def _impression(quality: int):
    """One rose pressed into set wax. quality 0..3 = perfect / good / poor / smeared."""
    s = L.WAX_POOL_W + 4
    dark = shade(C("wax_dark"), -0.10)
    base = C("wax_cool")
    light = mix(C("wax_cool"), C("paper_dark"), 0.55)
    cx = cy = s // 2
    r = 7

    def draw(target, d, m, li, ox=0, oy=0):
        _rose(target, cx + ox, cy - 1 + oy, r, d, m, li)

    cv = Canvas(s, s)
    if quality == 0:                       # perfect - deep, centred, ringed
        cv.disc_ring(cx, cy, r + 4, dark, 2)
        cv.disc_ring(cx, cy - 1, r + 4, light, 1)
        _emboss(cv, draw, dark, light, base)
    elif quality == 1:                     # good - a touch off centre
        cv.disc_ring(cx + 1, cy + 1, r + 4, dark, 2)
        _emboss(cv, lambda t, d, m, li: draw(t, d, m, li, ox=1, oy=1),
                dark, light, base)
    elif quality == 2:                     # poor - the wax had already set
        tmp = Canvas(s, s)
        tmp.disc_ring(cx, cy, r + 4, dark, 1)
        _emboss(tmp, draw, dark, light, base)
        rnd = Rand(487)
        for j in range(s):                 # only the lower half took
            for i in range(s):
                c = tmp.get(i, j)
                if c[3] and (j > cy - 3 or rnd.chance(0.35)):
                    cv.set(i, j, c)
    else:                                  # smeared - pressed far too hot
        tmp = Canvas(s, s)
        _emboss(tmp, draw, dark, light, base)
        for j in range(s):
            for i in range(s):
                c = tmp.get(i, j)
                if c[3]:
                    drag = (j % 3) - 1
                    cv.set(i + drag, j, mix(c, C("wax_warm"), 0.45))
                    cv.set(i + drag + 1, j, mix(c, C("wax_warm"), 0.20))
    return cv


def make_seal_impressions():
    """Perfect / good / poor / smeared roses pressed into set wax.

    The grade has to be readable at a glance, because it is the verdict on the
    whole ritual: a crisp rose means the player judged the heat right.
    """
    return sheet([_impression(q) for q in range(4)], cols=4)


# --------------------------------------------------------------------------
# candle
# --------------------------------------------------------------------------

def make_candlestick():
    w, h = 44, 74
    cv = Canvas(w, h)
    cx = w // 2
    # brass chamberstick: dished base, short stem, drip pan, ring handle
    cv.fellipse(cx, h - 5, 18, 6, C("brass_dark"))
    cv.fellipse(cx, h - 7, 16, 5, C("brass"))
    cv.fellipse(cx, h - 8, 12, 3, C("brass_hi"))
    cv.frect(cx - 4, h - 26, 8, 20, C("brass_dark"))
    cv.ramp_rect(cx - 3, h - 26, 6, 20, [C("brass_hi"), C("brass"),
                                         C("brass_dark")], 0.0, 1.0,
                 vertical=False)
    cv.fellipse(cx, h - 27, 12, 4, C("brass_dark"))
    cv.fellipse(cx, h - 28, 10, 3, C("brass"))
    # ring handle on the right
    cv.disc_ring(cx + 16, h - 12, 7, C("brass_dark"), 2)
    cv.disc_ring(cx + 16, h - 13, 6, C("brass"), 1)
    # the candle itself, with wax runs down one side
    cand_h = h - 34
    cv.round_rect(cx - 6, 4, 12, cand_h, 2, C("paper_shadow"))
    cv.ramp_rect(cx - 5, 4, 10, cand_h,
                 [C("paper_hi"), C("paper_lit"), C("paper_mid"),
                  C("paper_dark")], 0.0, 0.9, vertical=False)
    rnd = Rand(503)
    for _ in range(4):
        dx = cx - 5 + rnd.i(0, 9)
        dy = 6 + rnd.i(0, 6)
        dl = rnd.i(6, 18)
        for k in range(dl):
            cv.set(dx, dy + k, C("paper_hi"))
            cv.set(dx + 1, dy + k, C("paper_lit"))
        cv.fdisc(dx, dy + dl, 1, C("paper_hi"))
    cv.fellipse(cx, 4, 6, 3, C("paper_lit"))     # melted crater at the top
    cv.fellipse(cx, 4, 4, 2, C("paper_dark"))
    cv.outline(C("shadow_warm"))
    cv.rim_light(C("flame_edge"), from_left=True, strength=0.5)
    return cv


def make_flame_frames(n=6):
    """Teardrop flame with a blue base, wobbling. Frame 0 is the calm pose."""
    w, h = 15, 24
    frames = []
    for f in range(n):
        cv = Canvas(w, h)
        phase = f / float(n) * math.tau
        lean = math.sin(phase) * 1.6
        stretch = 1.0 + 0.12 * math.sin(phase * 2 + 1.0)
        cx = w / 2.0
        top = 2 + (1.0 - stretch) * 3
        for j in range(int(top), h - 4):
            t = (j - top) / float(h - 4 - top)
            # teardrop profile: narrow at the tip, widest low down
            half = (1.0 - (1.0 - t) ** 2.1) * 5.2 * stretch
            off = lean * (1.0 - t) ** 1.5
            for i in range(int(cx + off - half), int(cx + off + half) + 1):
                d = abs(i - (cx + off)) / max(0.6, half)
                if t > 0.72:
                    col = C("flame_low") if d > 0.55 else C("flame_edge")
                elif d > 0.78:
                    col = C("flame_edge")
                elif d > 0.42:
                    col = C("flame_mid")
                else:
                    col = C("flame_core")
                cv.set(i, j, col)
        # blue-white base and the wick
        cv.fellipse(cx, h - 5, 3, 2, mix(C("flame_core"), C("night_hi"), 0.45))
        cv.vline(int(cx), h - 4, 4, C("ink"))
        frames.append(cv)
    return sheet(frames, cols=n)


def make_flame_glow():
    """Additive halo sprite parented to the flame."""
    s = 96
    cv = Canvas(s, s)
    cx = cy = s // 2
    for j in range(s):
        for i in range(s):
            d = math.hypot(i - cx, j - cy) / (s / 2.0)
            if d >= 1.0:
                continue
            t = (1.0 - d) ** 2.6
            col = C("flame_mid") if t > 0.55 else C("flame_edge")
            cv.set(i, j, (col[0], col[1], col[2], int(min(150, t * 190))))
    return cv


# --------------------------------------------------------------------------
# dressing
# --------------------------------------------------------------------------

def make_photo_frame():
    w, h = 74, 104
    cv = Canvas(w, h)
    cv.round_rect(0, 0, w, h - 8, 2, C("brass_dark"))
    cv.ramp_rect(1, 1, w - 2, h - 10,
                 [C("brass_hi"), C("brass"), C("brass_dark")], 0.0, 1.0)
    for i in range(2, w - 2, 4):                       # beaded gilt moulding
        cv.set(i, 2, C("brass_glint"))
        cv.set(i, h - 11, C("brass_dark"))
    px, py, pw, ph = 7, 7, w - 14, h - 30
    cv.ramp_rect(px, py, pw, ph,
                 [C("paper_dark"), C("paper_shadow"), C("ink_faint")], 0.1, 0.8)
    # A seated carte-de-visite portrait. Kept high-key so the sitter reads as a
    # person rather than a dark smudge - she matters to the story.
    fcx = px + pw // 2
    head_y = py + 24                      # hair mass centre
    shoulder_y = head_y + 22              # just below the collar, so the bust joins on

    # bust: a narrow torso with sloped shoulders, cropped by the frame edge the
    # way a real carte-de-visite is
    cv.fellipse(fcx, shoulder_y + 12, 19, 18, C("ink_soft"))
    cv.fellipse(fcx, shoulder_y + 2, 16, 9, C("ink_soft"))
    cv.fellipse(fcx, shoulder_y + 12, 16, 16, shade(C("ink_soft"), 0.05))
    cv.fellipse(fcx, shoulder_y + 2, 13, 7, shade(C("ink_soft"), 0.05))
    cv.fellipse(fcx - 11, shoulder_y + 6, 5, 8, shade(C("ink_soft"), -0.05))
    cv.fellipse(fcx + 11, shoulder_y + 6, 5, 8, shade(C("ink_soft"), -0.05))
    cv.frect(fcx - 3, head_y + 8, 6, 10, C("paper_dark"))             # neck
    cv.hline(fcx - 8, head_y + 16, 16, C("paper_mid"))                # lace collar
    cv.hline(fcx - 7, head_y + 17, 14, C("paper_lit"))
    cv.hline(fcx - 5, head_y + 18, 10, C("paper_mid"))

    cv.fellipse(fcx, head_y, 10, 12, C("ink"))                        # hair mass
    cv.fellipse(fcx, head_y + 2, 7, 9, C("paper_mid"))                # face
    cv.fellipse(fcx, head_y - 4, 8, 5, C("ink"))                      # centre part
    cv.fellipse(fcx - 8, head_y + 2, 3, 5, C("ink"))                  # side curls
    cv.fellipse(fcx + 8, head_y + 2, 3, 5, C("ink"))
    cv.set(fcx - 3, head_y + 2, C("ink"))                             # eyes
    cv.set(fcx + 3, head_y + 2, C("ink"))
    cv.set(fcx, head_y + 4, C("ink_faint"))                           # nose
    cv.hline(fcx - 2, head_y + 6, 4, C("ink_soft"))                   # mouth
    cv.set(fcx - 5, head_y, C("paper_lit"))                           # lit cheek
    cv.rect(px - 1, py - 1, pw + 2, ph + 2, C("brass_dark"))
    # engraved nameplate
    cv.round_rect(w // 2 - 26, h - 11, 52, 9, 2, C("brass_dark"))
    cv.ramp_rect(w // 2 - 25, h - 10, 50, 7, [C("brass"), C("brass_dark")],
                 0.0, 1.0)
    # easel back
    cv.line(w - 6, h - 14, w + 4, h - 2, C("wood_dark"))
    cv.outline(C("shadow_warm"))
    cv.rim_light(C("flame_edge"), from_left=True, strength=0.45)
    return cv


def make_inkwell():
    w, h = 30, 30
    cv = Canvas(w, h)
    cx = w // 2
    cv.fellipse(cx, h - 4, 13, 4, C("shadow_warm"))
    cv.round_rect(cx - 11, 8, 22, h - 10, 3, C("night"))
    cv.ramp_rect(cx - 10, 9, 20, h - 13,
                 [C("night_hi"), C("night"), C("void")], 0.0, 1.0,
                 vertical=False)
    cv.fellipse(cx, 9, 10, 4, C("night_hi"))
    cv.fellipse(cx, 9, 8, 3, C("ink"))
    cv.fellipse(cx, 8, 5, 2, shade(C("ink"), 0.08))
    cv.set(cx - 5, 7, C("moon"))
    cv.outline(C("shadow_warm"))
    cv.rim_light(C("flame_edge"), from_left=True, strength=0.4)
    return cv


def make_quill():
    """A goose quill lying on the desk.

    Drawn as a solid VANE around the shaft rather than as a fan of separate
    barb strokes. The stroke version read as a scalpel at this size - the eye
    needs a continuous feather silhouette to recognise a quill, and the barbs
    are then just texture on top of it.
    """
    w, h = 56, 44
    cv = Canvas(w, h)
    rnd = Rand(547)

    # the shaft, running down-right; the tip end is the nib
    x0, y0 = 5.0, 5.0
    x1, y1 = w - 7.0, h - 7.0
    dx, dy = x1 - x0, y1 - y0
    ln = math.hypot(dx, dy)
    ux, uy = dx / ln, dy / ln
    nx, ny = -uy, ux                       # unit normal

    # --- vane: a solid lens over the upper two thirds of the shaft ---
    steps = int(ln * 2)
    for s in range(steps):
        t = s / float(steps - 1)
        if t > 0.72:                       # bare quill below the vane
            break
        px = x0 + dx * t
        py = y0 + dy * t
        # widest a third of the way down, tapering to a point at both ends
        half = 8.6 * math.sin(min(1.0, t / 0.72) * math.pi) ** 0.62
        for k in range(-int(half), int(half) + 1):
            e = abs(k) / max(0.8, half)
            if k < 0:
                col = C("paper_hi") if e < 0.45 else C("paper_lit")
            else:
                col = C("paper_mid") if e < 0.55 else C("paper_shadow")
            cv.set(px + nx * k, py + ny * k, col)

    # --- barbs: short diagonal texture combed off the shaft ---
    for s in range(0, steps, 2):
        t = s / float(steps - 1)
        if t > 0.70:
            break
        px = x0 + dx * t
        py = y0 + dy * t
        half = 8.6 * math.sin(min(1.0, t / 0.72) * math.pi) ** 0.62
        for side in (-1, 1):
            b = half * rnd.range(0.55, 0.95)
            ex = px + nx * b * side + ux * 2.2
            ey = py + ny * b * side + uy * 2.2
            col = C("paper_lit") if side < 0 else C("paper_shadow")
            cv.line(px + nx * side, py + ny * side, ex, ey, col)

    # --- shaft over the top, so the vane reads as attached to it ---
    for s in range(steps):
        t = s / float(steps - 1)
        px = x0 + dx * t
        py = y0 + dy * t
        cv.set(px, py, C("paper_shadow"))
        cv.set(px + nx, py + ny, C("paper_hi"))

    # --- the nib: split, inked, and clearly darker than the feather ---
    for k in range(7):
        t = 0.86 + k * 0.022
        px = x0 + dx * t
        py = y0 + dy * t
        cv.set(px, py, C("ink_soft"))
        cv.set(px + nx, py + ny, C("ink_faint"))
    cv.fdisc(x1, y1, 1, C("ink"))
    cv.set(x1 - ux, y1 - uy, C("ink"))

    cv.outline(C("shadow_warm"))
    cv.rim_light(C("flame_edge"), from_left=True, strength=0.30)
    return cv


def make_journal():
    w, h = 66, 26
    cv = Canvas(w, h)
    cv.round_rect(0, 4, w, h - 4, 3, C("leather_dark"))
    cv.ramp_rect(2, 5, w - 4, h - 7,
                 [C("leather"), C("leather_dark"),
                  shade(C("leather_dark"), -0.12)], 0.0, 1.0)
    cv.frect(3, 2, w - 8, 5, C("paper_mid"))               # page block
    cv.hline(3, 2, w - 8, C("paper_hi"))
    for j in range(3, 7):
        cv.hline(3, j, w - 8, C("paper_dark") if j % 2 else C("paper_mid"))
    cv.round_rect(0, 4, w, h - 4, 3, C("shadow_warm"))
    cv.ramp_rect(2, 6, w - 4, h - 8,
                 [C("leather"), C("leather_dark")], 0.0, 1.0)
    cv.hline(4, 6, w - 8, mix(C("leather"), C("paper_hi"), 0.2))
    cv.frect(w - 18, 6, 3, h - 8, C("curtain_dark"))       # ribbon marker
    cv.outline(C("shadow_warm"))
    cv.rim_light(C("flame_edge"), from_left=True, strength=0.35)
    return cv


def make_source_letter():
    """The letter being transcribed, as it lies on the desk.

    Blank stock only - SourceLetter.gd draws the actual words on top at runtime
    in the 5x7 face with per-glyph jitter, so the text is genuinely legible in
    place. That is what lets the transcript live on the desk instead of in a
    floating UI panel.
    """
    w, h = L.SOURCE_LETTER_W, L.SOURCE_LETTER_H
    cv = _paper_body(w, h, 521, lit=0.10)
    # a horizontal crease where the letter was folded for the post
    crease = h // 3
    cv.hline(0, crease, w, C("paper_shadow"))
    cv.hline(0, crease + 1, w, C("paper_hi"))
    # dog-eared lower-right corner
    for k in range(9):
        for i in range(9 - k):
            cv.set(w - 1 - i, h - 1 - k, (0, 0, 0, 0))
    for k in range(9):
        cv.set(w - 1 - (8 - k), h - 1 - k, C("paper_shadow"))
    cv.outline(C("shadow_warm"))
    return cv


def make_reading_sheet():
    """Enlarged stock for the hold-to-read close-up; text drawn at runtime."""
    return _paper_body(L.SOURCE_LETTER_W * 2, L.SOURCE_LETTER_H * 2, 541,
                       lit=0.16)


def make_menu_letter():
    """The title screen, as a letter lying on the desk.

    A menu drawn as a UI panel sits on top of the fiction; a menu written on a
    sheet of paper IS the fiction - the player marks up terms of engagement
    before sitting down to work. It is also the highest-contrast surface in the
    game, which is exactly what a menu over a busy candlelit bookshelf needs.

    The sheet carries a wax seal with the same rose the player will press a few
    minutes later, so the motif is established before the mechanic teaches it.
    """
    w, h = L.MENU_LETTER_W, L.MENU_LETTER_H
    cv = _paper_body(w, h, 601, lit=0.20)
    rnd = Rand(607)

    # age: foxing spots and a faintly grubby lower edge
    for _ in range(18):
        x = rnd.i(4, w - 6)
        y = rnd.i(4, h - 6)
        cv.fdisc(x, y, rnd.i(1, 2), shade(cv.get(x, y), -0.055))
    for i in range(w):
        cv.set(i, h - 2, shade(cv.get(i, h - 2), -0.08))

    # folded in three for the post, so it has two horizontal creases
    for cy in (int(h * 0.335), int(h * 0.72)):
        for i in range(w):
            cv.set(i, cy, C("paper_shadow"))
            cv.set(i, cy + 1, C("paper_hi"))

    # printed double rule beneath the heading, and a single one near the foot
    for (ry, gap) in ((L.MENU_RULE_TOP, 2), (L.MENU_RULE_BOTTOM, 0)):
        cv.hline(20, ry, w - 40, C("ink_faint"))
        if gap:
            cv.hline(20, ry + gap, w - 40, C("ink_faint"))

    # dog-eared bottom-right corner
    for k in range(11):
        for i in range(11 - k):
            cv.set(w - 1 - i, h - 1 - k, (0, 0, 0, 0))
    for k in range(11):
        cv.set(w - 1 - (10 - k), h - 1 - k, C("paper_shadow"))

    # the seal, already pressed, bottom-left
    blob = _wax_blob(L.WAX_POOL_STAGES - 1, WAX_TEMP_RAMPS[3], seed=613)
    cv.blit(blob, L.MENU_SEAL_X - blob.w // 2, L.MENU_SEAL_Y - blob.h // 2)
    imp = _impression(0)
    cv.blit(imp, L.MENU_SEAL_X - imp.w // 2, L.MENU_SEAL_Y - imp.h // 2)

    cv.outline(C("shadow_warm"))
    return cv


def make_bin():
    """Wicker wastepaper basket. Where every ruined page ends up.

    Drawn with a visible dark mouth and a couple of crumpled balls already in
    it, so it reads as a bin at a glance rather than as a basket of something.
    """
    w, h = L.BIN_W, L.BIN_H
    cv = Canvas(w, h)
    rim_h = 9
    taper = 10                       # narrower at the base

    # body: woven bands, narrowing toward the bottom
    for j in range(rim_h, h):
        t = (j - rim_h) / float(h - rim_h - 1)
        inset = int(taper * t)
        band = ((j - rim_h) // 4) % 2
        base = C("leather") if band == 0 else C("leather_dark")
        for i in range(inset, w - inset):
            e = (i - inset) / float(max(1, w - inset * 2))
            # lit on the candle side, falling away to the right
            if e < 0.16:
                col = shade(base, 0.10)
            elif e < 0.62:
                col = base
            else:
                col = shade(base, -0.12)
            # vertical weave stakes
            if (i + band * 2) % 7 == 0:
                col = shade(col, -0.14)
            cv.set(i, j, col)

    # Rim first, then the mouth punched into it by overdrawing. `set()` ignores
    # alpha-0 writes, so a hole cannot be knocked out after the fact - the
    # interior has to be painted on top instead.
    cv.fellipse(w // 2, rim_h, w // 2, rim_h - 1, C("leather_dark"))
    cv.fellipse(w // 2, rim_h - 1, w // 2 - 1, rim_h - 2, C("leather"))
    for i in range(2, w - 2, 3):                    # rim weave
        cv.set(i, rim_h - 1 - int((1.0 - abs(i - w / 2.0) / (w / 2.0)) * 3),
               C("leather_dark"))

    # the mouth: a dark well the player is throwing into
    cv.fellipse(w // 2, rim_h, w // 2 - 4, rim_h - 4, C("shadow_warm"))
    cv.fellipse(w // 2, rim_h + 1, w // 2 - 6, rim_h - 5, C("void"))

    # two balls already in there, so it reads as a wastebasket immediately
    rnd = Rand(601)
    for (bx, by, br) in ((w // 2 - 8, rim_h + 1, 5), (w // 2 + 7, rim_h, 4)):
        cv.fdisc(bx, by, br, C("paper_shadow"))
        cv.fdisc(bx, by - 1, br - 1, C("paper_dark"))
        for _ in range(5):
            cv.set(bx + rnd.i(-br, br), by + rnd.i(-br, br - 1),
                   C("paper_mid"))

    cv.speckle(0, rim_h, w, h - rim_h, 607, amount=0.05, density=0.16)
    cv.outline(C("shadow_warm"))
    cv.rim_light(C("flame_edge"), from_left=True, strength=0.35)
    return cv


def make_paper_ball():
    """Flat sheet crumpling into a ball, PAPER_BALL_FRAMES steps.

    Frame 0 is a folded-ish sheet, the last frame is a tight ball. Played
    forward when the player crushes a ruined page.
    """
    w, h = L.PAPER_BALL_W, L.PAPER_BALL_H
    frames = []
    for f in range(L.PAPER_BALL_FRAMES):
        t = f / float(L.PAPER_BALL_FRAMES - 1)
        cv = Canvas(w, h)
        rnd = Rand(613 + f * 31)
        cx, cy = w // 2, h // 2
        rx = (w * 0.5 - 1) * (1.0 - t * 0.28)
        ry = (h * 0.5 - 1) * (0.55 + t * 0.45)

        # lumpy silhouette: a lobed blob, lumpier the more crushed it is
        lobes = [rnd.range(0.80, 1.16) for _ in range(7 + f)]
        for j in range(h):
            for i in range(w):
                dx = (i - cx) / max(0.5, rx)
                dy = (j - cy) / max(0.5, ry)
                d = math.hypot(dx, dy)
                if d > 1.3:
                    continue
                a = (math.atan2(dy, dx) + math.pi) / math.tau * len(lobes)
                k = int(a) % len(lobes)
                k2 = (k + 1) % len(lobes)
                fr = a - int(a)
                edge = lobes[k] * (1 - fr) + lobes[k2] * fr
                if d > edge:
                    continue
                # lit up-left, shadowed down-right
                v = 1.0 - d / edge - (dx * 0.18 + dy * 0.26)
                if v > 0.72:
                    col = C("paper_hi")
                elif v > 0.42:
                    col = C("paper_lit")
                elif v > 0.16:
                    col = C("paper_mid")
                else:
                    col = C("paper_dark")
                cv.set(i, j, col)

        # creases - more of them, and sharper, as it crushes
        for _ in range(3 + f * 4):
            x0 = cx + rnd.i(-int(rx), int(rx))
            y0 = cy + rnd.i(-int(ry), int(ry))
            ln = rnd.i(3, 8)
            dxs = rnd.range(-1.0, 1.0)
            dys = rnd.range(-1.0, 1.0)
            for s in range(ln):
                px = x0 + int(dxs * s)
                py = y0 + int(dys * s)
                if cv.get(px, py)[3] > 0:
                    cv.set(px, py, C("paper_shadow") if s % 2 else C("paper_hi"))

        cv.outline(C("shadow_warm"))
        frames.append(cv)
    return sheet(frames, cols=L.PAPER_BALL_FRAMES)


def make_wax_box():
    """A small box of sealing-wax sticks, so a spent stick has somewhere to come
    from. Purely diegetic - the supply is not limited."""
    w, h = 34, 22
    cv = Canvas(w, h)
    cv.round_rect(0, 4, w, h - 4, 2, C("leather_dark"))
    cv.ramp_rect(1, 5, w - 2, h - 7,
                 [C("leather"), C("leather_dark"),
                  shade(C("leather_dark"), -0.12)], 0.0, 1.0)
    cv.hline(2, 5, w - 4, mix(C("leather"), C("paper_hi"), 0.25))
    # sticks poking out of the open end
    for k in range(4):
        sx = 4 + k * 7
        cv.round_rect(sx, 0, 5, 9, 1, C("wax_dark"))
        cv.ramp_rect(sx + 1, 1, 3, 7, [C("wax_cool"), C("wax_cold")], 0.0, 1.0,
                     vertical=False)
    cv.outline(C("shadow_warm"))
    cv.rim_light(C("flame_edge"), from_left=True, strength=0.35)
    return cv


def _hand(mirror, reach):
    """One hand on the keys, seen from behind and above.

    Fingers point AWAY from the viewer and are heavily foreshortened - drawn as
    short stubs off the knuckle line rather than as long radiating spokes, which
    is the difference between a hand and a spider at this size.
    """
    w, h = 46, 52
    cv = Canvas(w, h)
    skin_d = (92, 58, 40, 255)
    skin = (128, 86, 60, 255)
    skin_l = (162, 114, 82, 255)

    knuckle_y = 20

    # four foreshortened fingers reaching up onto the keys
    lengths = (13, 15, 14, 11)
    for k in range(4):
        fx = 7 + k * 8
        ln = lengths[k] + (4 if (reach and k == 1) else 0)
        top = knuckle_y - ln
        cv.round_rect(fx, top, 6, ln + 6, 2, skin_d)
        cv.round_rect(fx + 1, top + 1, 4, ln + 4, 1, skin)
        cv.vline(fx + 1, top + 2, ln + 2, skin_l)
        cv.hline(fx + 1, top + 1, 4, skin_l)
        if reach and k == 1:
            cv.round_rect(fx + 1, top + 1, 4, 4, 1, skin_l)

    # back of the hand: a broad wedge widening toward the wrist
    cv.round_rect(4, knuckle_y - 2, 34, 20, 5, skin_d)
    cv.round_rect(5, knuckle_y - 1, 32, 18, 4, skin)
    cv.round_rect(8, knuckle_y, 20, 8, 3, skin_l)
    for k in range(4):                            # knuckles
        cv.set(9 + k * 8, knuckle_y, skin_l)
        cv.set(10 + k * 8, knuckle_y - 1, skin_l)
    for k in range(3):                            # tendons
        cv.vline(12 + k * 8, knuckle_y + 3, 9, skin_d)

    # thumb angling out to the left
    cv.round_rect(0, knuckle_y + 6, 8, 7, 3, skin_d)
    cv.round_rect(1, knuckle_y + 7, 6, 5, 2, skin)

    # shirt cuff at the wrist
    cv.round_rect(6, knuckle_y + 17, 30, 11, 4, C("paper_shadow"))
    cv.round_rect(7, knuckle_y + 18, 28, 9, 3, C("paper_mid"))
    cv.hline(10, knuckle_y + 18, 22, C("paper_lit"))
    cv.fdisc(20, knuckle_y + 23, 2, C("brass_dark"))      # cuff link
    cv.set(19, knuckle_y + 22, C("brass_hi"))

    cv.outline(C("shadow_warm"))
    cv.shade_region(0, 0, w, h, -0.14)            # they sit in front of the light
    if mirror:
        cv = cv.flip_h()
    return cv


def make_hands():
    """rest / left striking / right striking, as one atlas."""
    frames = []
    for reach_l, reach_r in ((False, False), (True, False), (False, True)):
        cv = Canvas(L.HANDS_W, L.HANDS_H)
        cv.blit(_hand(False, reach_l), 10, L.HANDS_H - 54)
        cv.blit(_hand(True, reach_r), L.HANDS_W - 56, L.HANDS_H - 54)
        frames.append(cv)
    return sheet(frames, cols=3)


def make_dust():
    cv = Canvas(3, 3)
    cv.set(1, 1, C("flame_mid"))
    cv.set(0, 1, mix(C("flame_edge"), (0, 0, 0, 0), 0.4))
    cv.set(2, 1, mix(C("flame_edge"), (0, 0, 0, 0), 0.4))
    cv.set(1, 0, mix(C("flame_edge"), (0, 0, 0, 0), 0.4))
    cv.set(1, 2, mix(C("flame_edge"), (0, 0, 0, 0), 0.4))
    return cv


def make_cursors():
    """default / open hand / closed hand / point, 16x16 each."""
    out = []

    a = Canvas(16, 16)                       # arrow
    for j in range(11):
        for i in range(max(1, 11 - j)):
            if i <= j:
                a.set(2 + i, 1 + j, C("paper_lit"))
    a.outline(C("void"))
    out.append(a)

    for closed in (False, True):             # hands
        c = Canvas(16, 16)
        c.round_rect(4, 7, 9, 8, 3, C("paper_mid"))
        span = 3 if closed else 6
        for k in range(4):
            fx = 4 + k * 2
            c.frect(fx, 7 - span + (k == 3), 2, span + 2, C("paper_mid"))
        c.frect(2, 8, 3, 5, C("paper_mid"))  # thumb
        c.outline(C("void"))
        c.rim_light(C("paper_hi"), from_left=True, strength=0.5)
        out.append(c)

    p = Canvas(16, 16)                       # pointing finger
    p.round_rect(4, 7, 9, 8, 3, C("paper_mid"))
    p.frect(6, 1, 2, 8, C("paper_mid"))
    p.frect(2, 8, 3, 5, C("paper_mid"))
    p.outline(C("void"))
    out.append(p)

    return sheet(out, cols=4)


# --------------------------------------------------------------------------

def generate(save):
    save("paper_sheet", make_sheet())
    save("paper_sheet_torn", make_sheet_torn())
    save("paper_stack", make_paper_stack())
    save("letter_fold", sheet([make_folded_letter(0)], cols=1))
    save("letter_fold1", make_folded_letter(1))
    save("letter_fold2", make_folded_letter(2))
    save("envelope_closed", make_envelope_closed())
    save("envelope_open", make_envelope_open())
    save("wax_stick", sheet([make_wax_stick(s) for s in WAX_STATES], cols=4))
    save("wax_pool", make_wax_pool_atlas())
    save("seal_stamp", make_seal_stamp())
    save("seal_die", make_seal_die())
    save("seal_impressions", make_seal_impressions())
    save("candlestick", make_candlestick())
    save("flame", make_flame_frames())
    save("flame_glow", make_flame_glow())
    save("photo_frame", make_photo_frame())
    save("inkwell", make_inkwell())
    save("quill", make_quill())
    save("journal", make_journal())
    save("source_letter", make_source_letter())
    save("reading_sheet", make_reading_sheet())
    save("menu_letter", make_menu_letter())
    save("bin", make_bin())
    save("paper_ball", make_paper_ball())
    save("wax_box", make_wax_box())
    save("hands", make_hands())
    save("dust", make_dust())
    save("cursors", make_cursors())
