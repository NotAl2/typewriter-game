"""The study: panelled wall, bookcase, window, curtain, desk, chair.

Painted as a few big layers rather than many props, because the room is a
backdrop - it needs to establish warmth and depth and then get out of the way of
the machine. Detail budget goes to silhouette and value, not to trinkets.

Everything large is shaded with banded ramps rather than a two-colour dither: a
Bayer pattern stretched across a whole desktop reads as noise, whereas three or
four solid palette bands with a dithered seam between them reads as wood.

Light: the candle sits low-left on the desk, so the wall brightens toward the
left-centre and every horizontal surface catches a warm pool near it. The window
on the right is the only cool light in the painting, which is what makes the
candle read as warm.
"""

import math

import layout as L
from palette import C, shade, mix, Rand, BAYER4, dither_pick
from pixel import Canvas


WOOD_RAMP = [C("wood_glow"), C("wood_hi"), C("wood_light"), C("wood_mid"),
             C("wood_dark"), C("wood_darkest")]
CANDLE_RAMP = [C("flame_low"), C("flame_edge"), C("flame_mid")]


def band_darken(cv, cx, cy, inner, strength, col=None, bands=4):
    """Banded radial falloff toward a colour - used for corner vignetting."""
    col = col or C("void")
    md = math.hypot(max(cx, cv.w - cx), max(cy, cv.h - cy))
    for j in range(cv.h):
        for i in range(cv.w):
            base = cv.get(i, j)
            if base[3] == 0:
                continue
            d = math.hypot(i - cx, j - cy) / md
            t = max(0.0, (d - inner) / max(0.01, 1.0 - inner)) ** 1.5 * strength
            if t <= 0.0:
                continue
            p = min(0.999, t) * bands
            step = int(p)
            frac = p - step
            amt = step / float(bands)
            if frac > 0.66:
                amt = dither_pick(i, j, (frac - 0.66) / 0.34,
                                  (int(amt * 255),) * 4,
                                  (int((step + 1) / float(bands) * 255),) * 4,
                                  BAYER4)[0] / 255.0
            if amt > 0.0:
                cv.set(i, j, mix(base, col, min(0.82, amt)))


# --------------------------------------------------------------------------
# wall
# --------------------------------------------------------------------------

def _panelling(cv, x, y, w, h, seed, tones, groove):
    """Vertical tongue-and-groove boards, each shaded in three flat steps."""
    rnd = Rand(seed)
    i = x
    while i < x + w:
        bw = 17 + rnd.i(-2, 2)
        pick = rnd.i(0, len(tones) - 3)
        lit, mid, dark = tones[pick], tones[pick + 1], tones[pick + 2]
        for k in range(i, min(i + bw, x + w)):
            e = (k - i) / float(max(1, bw))
            col = lit if e < 0.22 else (mid if e < 0.74 else dark)
            for j in range(y, y + h):
                cv.set(k, j, col)
        cv.vline(i, y, h, groove)
        cv.wood_grain(i + 1, y, max(1, bw - 2), h, seed * 31 + i, density=0.14,
                      contrast=0.045)
        i += bw


def make_room():
    W, H = L.VIEW_W, L.VIEW_H
    cv = Canvas(W, H, C("wood_darkest"))

    rail_y = 92

    _panelling(cv, 0, 0, W, rail_y, 3,
               [C("wood_dark"), C("wood_darkest"), C("void"), C("void")],
               C("void"))
    _panelling(cv, 0, rail_y + 6, W, L.DESK_TOP_Y - rail_y + 24, 9,
               [C("wood_light"), C("wood_mid"), C("wood_dark"),
                C("wood_darkest")],
               C("wood_darkest"))

    # chair-rail moulding
    cv.frect(0, rail_y, W, 6, C("wood_mid"))
    cv.hline(0, rail_y, W, C("wood_hi"))
    cv.hline(0, rail_y + 1, W, C("wood_light"))
    cv.hline(0, rail_y + 4, W, C("wood_dark"))
    cv.hline(0, rail_y + 5, W, C("void"))

    # ---- framed etching, upper left ------------------------------------
    fx, fy, fw, fh = 26, 12, 108, 66
    cv.round_rect(fx, fy, fw, fh, 2, C("brass_dark"))
    cv.ramp_rect(fx + 1, fy + 1, fw - 2, fh - 2,
                 [C("brass_hi"), C("brass"), C("brass_dark")], 0.0, 1.0)
    ex, ey, ew, eh = fx + 5, fy + 5, fw - 10, fh - 10
    cv.ramp_rect(ex, ey, ew, eh,
                 [C("paper_dark"), C("paper_shadow"), C("ink_faint")], 0.0, 0.75)
    rnd = Rand(41)
    for k in range(3):                                  # receding hills
        base = ey + eh - 7 - k * 6
        amp = 4 + k * 2
        tone = mix(C("ink_faint"), C("ink_soft"), k * 0.4)
        for i in range(ew):
            t = i / float(ew)
            yy = base - int(amp * math.sin(t * math.pi * (1.2 + k * 0.4) + k))
            for j in range(yy, ey + eh):
                cv.set(ex + i, j, tone)
    for i in range(ew):
        if rnd.chance(0.35):
            cv.set(ex + i, ey + eh - 2, C("ink"))
    cv.rect(fx + 4, fy + 4, fw - 8, fh - 8, C("void"))
    cv.rect(fx, fy, fw, fh, C("void"))

    # ---- floating shelf with books, upper centre-left --------------------
    sx, sy, sw = 168, 44, 132
    cv.frect(sx, sy, sw, 5, C("wood_light"))
    cv.hline(sx, sy, sw, C("wood_hi"))
    cv.hline(sx, sy + 4, sw, C("void"))
    for bx in (sx + 6, sx + 42):
        cv.line(bx, sy + 5, bx + 5, sy + 13, C("wood_darkest"))
        cv.line(bx + 1, sy + 5, bx + 6, sy + 13, C("wood_dark"))
    _books(cv, sx + 10, sx + sw - 26, sy, Rand(63), lo=20, hi=30, dark=0.0)
    cv.frect(sx + sw - 40, sy - 8, 34, 4, C("leather_dark"))
    cv.hline(sx + sw - 40, sy - 8, 34, C("leather"))
    cv.frect(sx + sw - 38, sy - 12, 32, 4, C("green_book"))
    cv.hline(sx + sw - 38, sy - 12, 32, shade(C("green_book"), 0.12))

    # ---- tall bookcase, centre-right -------------------------------------
    cx0, cx1 = 322, 468
    cv.frect(cx0, 0, cx1 - cx0, L.DESK_TOP_Y + 24, C("wood_darkest"))
    cv.vline(cx0, 0, L.DESK_TOP_Y + 24, C("wood_mid"))
    cv.vline(cx0 + 1, 0, L.DESK_TOP_Y + 24, C("wood_dark"))
    cv.vline(cx1 - 1, 0, L.DESK_TOP_Y + 24, C("void"))
    rnd = Rand(77)
    for shelf_y in (46, 92, 138, 184):
        cv.frect(cx0 + 2, shelf_y, cx1 - cx0 - 4, 4, C("wood_dark"))
        cv.hline(cx0 + 2, shelf_y, cx1 - cx0 - 4, C("wood_light"))
        _books(cv, cx0 + 4, cx1 - 8, shelf_y, rnd, lo=26, hi=40, dark=0.12)
    band_darken(cv, cx0 - 40, 90, 0.0, 0.0)     # no-op guard, keeps intent clear

    # ---- window, right ----------------------------------------------------
    wx, wy, ww, wh = 508, 18, 100, 126
    cv.round_rect(wx - 7, wy - 7, ww + 14, wh + 14, 2, C("wood_dark"))
    cv.ramp_rect(wx - 6, wy - 6, ww + 12, wh + 12,
                 [C("wood_light"), C("wood_mid"), C("wood_dark")], 0.0, 1.0)
    cv.ramp_rect(wx, wy, ww, wh,
                 [C("night_hi"), C("night"), shade(C("night"), -0.06)],
                 0.15, 1.0)
    rnd = Rand(101)
    cv.fdisc(wx + 70, wy + 28, 9, mix(C("night_hi"), C("moon"), 0.45))
    cv.fdisc(wx + 70, wy + 28, 7, mix(C("night_hi"), C("moon"), 0.75))
    for _ in range(22):
        cv.set(wx + rnd.i(2, ww - 3), wy + rnd.i(2, wh - 3),
               mix(C("night_hi"), C("moon"), rnd.range(0.3, 0.85)))
    for _ in range(40):                                  # rain on the glass
        rx = wx + rnd.i(1, ww - 2)
        ry = wy + rnd.i(1, wh - 9)
        for k in range(rnd.i(3, 8)):
            cv.set(rx + k // 3, ry + k,
                   mix(cv.get(rx + k // 3, ry + k), C("moon"), 0.22))
    for mx in (wx + ww // 3, wx + 2 * ww // 3):
        cv.vline(mx, wy, wh, C("wood_dark"))
        cv.vline(mx + 1, wy, wh, C("wood_mid"))
    for my in (wy + wh // 3, wy + 2 * wh // 3):
        cv.hline(wx, my, ww, C("wood_dark"))
        cv.hline(wx, my + 1, ww, C("wood_mid"))
    cv.rect(wx, wy, ww, wh, C("void"))

    # ---- crimson curtain hanging beside the window ------------------------
    # Irregular fold widths and a tie-back are what stop a vertical band of red
    # from reading as a length of pipe.
    cur_x, cur_w = 470, 36
    cur_bottom = L.DESK_TOP_Y + 8
    tie_y = 118
    folds = [shade(C("curtain_dark"), -0.12), C("curtain_dark"), C("curtain"),
             C("curtain_hi")]
    rnd = Rand(151)
    edges = [0]
    while edges[-1] < cur_w:
        edges.append(edges[-1] + rnd.i(4, 9))
    for f in range(len(edges) - 1):
        a, b = edges[f], min(edges[f + 1], cur_w)
        lit = rnd.i(0, len(folds) - 1)
        for i in range(a, b):
            e = (i - a) / float(max(1, b - a))
            idx = min(len(folds) - 1, max(0, lit - (0 if e < 0.5 else 1)))
            for j in range(0, cur_bottom):
                # the drape is gathered at the tie and flares below it
                flare = 1.0 if j < tie_y else 1.0 + (j - tie_y) / 260.0
                xx = cur_x + int((i - cur_w * 0.5) * flare + cur_w * 0.5)
                cv.set(xx, j, folds[idx])
        cv.vline(cur_x + a, 0, cur_bottom, folds[0])

    cv.speckle(cur_x - 6, 0, cur_w + 14, cur_bottom, 131, amount=0.05,
               density=0.09)

    # pelmet and rod
    cv.frect(cur_x - 6, 4, cur_w + 12, 11, C("curtain_dark"))
    cv.ramp_rect(cur_x - 5, 5, cur_w + 10, 9,
                 [C("curtain_hi"), C("curtain"), C("curtain_dark")], 0.0, 1.0)
    for i in range(cur_w + 12):
        if (i // 3) % 2 == 0:
            cv.set(cur_x - 6 + i, 15, C("curtain_dark"))
    cv.hline(cur_x - 8, 3, cur_w + 16, C("brass_dark"))
    cv.hline(cur_x - 8, 2, cur_w + 16, C("brass"))

    # tasselled tie-back cinching the drape
    cv.frect(cur_x - 3, tie_y, cur_w + 4, 6, shade(C("curtain_dark"), -0.16))
    cv.hline(cur_x - 3, tie_y, cur_w + 4, C("brass_dark"))
    cv.hline(cur_x - 3, tie_y + 1, cur_w + 4, C("brass"))
    cv.hline(cur_x - 3, tie_y + 5, cur_w + 4, C("void"))
    cv.fdisc(cur_x + cur_w // 2, tie_y + 9, 3, C("brass_dark"))
    cv.fdisc(cur_x + cur_w // 2, tie_y + 8, 2, C("brass"))

    # ---- light -----------------------------------------------------------
    cv.ramp_glow(210, 168, 330, CANDLE_RAMP, strength=0.55, falloff=2.4)
    band_darken(cv, W / 2.0, H * 0.5, 0.40, 0.62)
    return cv


def _books(cv, x0, x1, base_y, rnd, lo, hi, dark):
    spines = ["green_book", "leather_dark", "blue_book", "curtain_dark",
              "wood_dark", "green_book", "leather"]
    bx = x0
    while bx < x1:
        bw = rnd.i(4, 9)
        bh = rnd.i(lo, hi)
        if bx + bw > x1:
            break
        col = shade(C(rnd.pick(spines)), -dark)
        cv.ramp_rect(bx, base_y - bh, bw, bh,
                     [shade(col, 0.06), col, shade(col, -0.14)], 0.0, 1.0,
                     vertical=False, dither_width=0.2)
        cv.hline(bx, base_y - bh, bw, shade(col, 0.10))
        if bw > 5 and rnd.chance(0.7):
            cv.hline(bx + 1, base_y - bh + 5, bw - 2, C("brass_dark"))
            cv.hline(bx + 1, base_y - 7, bw - 2, C("brass_dark"))
        bx += bw


# --------------------------------------------------------------------------
# desk
# --------------------------------------------------------------------------

def make_desk():
    W = L.VIEW_W
    H = L.VIEW_H - L.DESK_TOP_Y
    cv = Canvas(W, H)

    apron_y = 132

    # top surface: far edge in shadow, near lip catching the most light
    cv.ramp_rect(0, 0, W, apron_y,
                 [C("wood_dark"), C("wood_mid"), C("wood_light"), C("wood_hi")],
                 0.0, 0.92)
    cv.wood_grain(0, 0, W, apron_y, 211, density=0.30, contrast=0.055)
    for k, sy in enumerate((16, 46, 82, 122)):           # board seams
        skew = (k - 1.5) * 0.006
        for i in range(W):
            yy = int(sy + (i - W / 2) * skew)
            cv.set(i, yy, shade(cv.get(i, yy), -0.13))
            cv.set(i, yy + 1, shade(cv.get(i, yy + 1), 0.07))

    cv.frect(0, apron_y, W, 6, C("wood_hi"))
    cv.ramp_rect(0, apron_y, W, 6, [C("wood_glow"), C("wood_hi"),
                                    C("wood_light")], 0.0, 1.0)
    cv.hline(0, apron_y + 5, W, C("wood_darkest"))

    # apron and drawer
    cv.ramp_rect(0, apron_y + 6, W, H - apron_y - 6,
                 [C("wood_mid"), C("wood_dark"), C("wood_darkest")], 0.0, 1.0)
    cv.wood_grain(0, apron_y + 6, W, H - apron_y - 6, 223, density=0.22)

    dw, dh = 210, H - apron_y - 16
    dx, dy = (W - dw) // 2, apron_y + 12
    cv.round_rect(dx, dy, dw, dh, 3, C("wood_darkest"))
    cv.round_rect(dx + 2, dy + 2, dw - 4, dh - 4, 2, C("wood_dark"))
    cv.ramp_rect(dx + 3, dy + 3, dw - 6, dh - 6,
                 [C("wood_light"), C("wood_mid"), C("wood_dark")], 0.0, 1.0)
    cv.wood_grain(dx + 3, dy + 3, dw - 6, dh - 6, 229, density=0.35)
    cv.hline(dx + 2, dy + 2, dw - 4, C("wood_light"))

    px, py = dx + dw // 2, dy + dh // 2
    cv.round_rect(px - 14, py - 3, 28, 7, 3, C("brass_dark"))
    cv.ramp_rect(px - 13, py - 2, 26, 5,
                 [C("brass_hi"), C("brass"), C("brass_dark")], 0.0, 1.0)
    cv.fdisc(px - 12, py, 3, C("brass"))
    cv.fdisc(px + 12, py, 3, C("brass"))
    cv.set(px - 8, py - 2, C("brass_glint"))

    # the candle's pool of light on the desktop
    cv.ramp_glow(L.FLAME_CX, L.FLAME_CY - L.DESK_TOP_Y + 62, 230, CANDLE_RAMP,
                 strength=0.85, falloff=2.0)
    band_darken(cv, W / 2.0, H * 0.35, 0.46, 0.44)
    return cv


def make_chair():
    """A slice of chair back intruding at the bottom-left, for framing depth."""
    W, H = 172, 84
    cv = Canvas(W, H)
    cv.round_rect(0, 10, W, 20, 6, C("wood_dark"))
    cv.ramp_rect(2, 12, W - 4, 16,
                 [C("wood_mid"), C("wood_dark"), C("wood_darkest")], 0.0, 1.0)
    cv.hline(4, 11, W - 8, C("wood_light"))
    for sx in (18, W - 34):
        cv.round_rect(sx, 26, 16, H - 26, 4, C("wood_dark"))
        cv.ramp_rect(sx + 2, 28, 12, H - 30,
                     [C("wood_mid"), C("wood_dark"), C("wood_darkest")],
                     0.0, 1.0, vertical=False)
        cv.vline(sx + 3, 28, H - 30, C("wood_light"))
    for i in range(3):
        bx = 52 + i * 22
        cv.round_rect(bx, 28, 8, H - 34, 3, C("wood_darkest"))
        cv.vline(bx + 2, 30, H - 38, C("wood_dark"))
    cv.outline(C("void"))
    cv.shade_region(0, 0, W, H, -0.26)      # it sits in front of the light
    return cv


def make_vignette():
    """Screen-space corner darkening as a premultiplied overlay sprite."""
    W, H = L.VIEW_W, L.VIEW_H
    cv = Canvas(W, H, (0, 0, 0, 0))
    cx, cy = W / 2.0, H * 0.56
    md = math.hypot(cx, cy)
    void = C("void")
    for j in range(H):
        for i in range(W):
            d = math.hypot(i - cx, j - cy) / md
            t = max(0.0, (d - 0.44) / 0.56) ** 1.7
            if t <= 0.0:
                continue
            lvl = min(4, int(t * 5))
            frac = t * 5 - lvl
            a = lvl / 5.0
            if frac > 0.62 and lvl < 4:
                if dither_pick(i, j, (frac - 0.62) / 0.38, 0, 1, BAYER4):
                    a = (lvl + 1) / 5.0
            if a > 0:
                cv.set(i, j, (void[0], void[1], void[2], int(a * 190)))
    return cv


def generate(save):
    save("bg_room", make_room())
    save("desk", make_desk())
    save("chair", make_chair())
    save("vignette", make_vignette())
