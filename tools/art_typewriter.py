"""The machine itself - body, carriage, platen, keycaps, typebars.

Everything that MOVES during the mechanic is its own sprite with its own pivot,
because the polish lives in the movement: the carriage slides, the platen turns,
each keycap dips, one typebar swings up and two of them cross when it jams.

Draw order in the scene, back to front:
    paper -> carriage + platen -> typebars -> body -> keycaps
so the body's front deck hides the bottom of the platen and the base of every
typebar, exactly as it does on the real machine.
"""

import json
import math
import os

import layout as L
from palette import C, shade, mix
from pixel import Canvas, sheet

ART = os.path.join(os.path.dirname(__file__), "..", "assets", "art")
FONTS = os.path.join(os.path.dirname(__file__), "..", "assets", "fonts")

_tiny = None


def tiny_font():
    global _tiny
    if _tiny is None:
        from PIL import Image
        meta = json.load(open(os.path.join(FONTS, "tiny_3x5.json")))
        img = Image.open(os.path.join(FONTS, "tiny_3x5.png")).convert("RGBA")
        _tiny = (meta, img.load())
    return _tiny


def draw_tiny(cv, x, y, text, col):
    """Stamp 3x5 text - used for keycap legends and the nameplate."""
    meta, px = tiny_font()
    for i, ch in enumerate(text):
        m = meta["chars"].get(ch)
        if m is None:
            continue
        for j in range(5):
            for k in range(3):
                if px[m["x"] + k, m["y"] + j][3] > 0:
                    cv.set(x + i * 4 + k, y + j, col)


# --------------------------------------------------------------------------
# body
# --------------------------------------------------------------------------

def make_body():
    """The open U-frame: two arms carrying the spools, a basket well, a deck."""
    W, H = L.TW_BODY_W, L.TW_BODY_H
    cv = Canvas(W, H)

    iron = C("iron")
    iron_mid = C("iron_mid")
    iron_hi = C("iron_hi")
    iron_dark = C("iron_dark")

    nx0, nx1 = L.TW_NOTCH_X0, L.TW_NOTCH_X1
    notch_h = L.TW_NOTCH_H

    # ---- side arms ----------------------------------------------------
    for side in (0, 1):
        ax = 2 if side == 0 else W - 32
        cv.round_rect(ax, 0, 30, notch_h + 26, 5, iron)
        # arms are lit from the candle side (left)
        cv.dither_rect(ax + 1, 1, 28, notch_h + 24, iron_mid, iron, 0.05, 0.85,
                       vertical=False if side == 0 else True)
        cv.round_rect(ax + 3, 3, 24, notch_h + 20, 4, iron_mid)

    # ---- main mass under the notch -------------------------------------
    body_top = notch_h
    cv.round_rect(0, body_top, W, H - body_top, 7, iron)
    cv.dither_rect(2, body_top + 2, W - 4, H - body_top - 4,
                   iron_mid, iron, 0.15, 0.9)

    # basket well: a recessed dark arch the typebars rise out of
    well_x, well_w = (W - L.BASKET_W) // 2, L.BASKET_W
    well_y = body_top + 2
    well_h = 34
    cv.round_rect(well_x, well_y, well_w, well_h, 6, iron_dark)
    cv.dither_rect(well_x + 2, well_y + 2, well_w - 4, well_h - 4,
                   C("void"), iron_dark, 0.0, 0.7)
    # slot the bars emerge from
    cv.frect(well_x + 8, well_y + 1, well_w - 16, 3, C("void"))
    cv.hline(well_x + 8, well_y + 4, well_w - 16, shade(iron_dark, 0.06))

    # ---- keyboard deck --------------------------------------------------
    deck_y = L.KEYBOARD_TOP_Y - L.TW_BODY_Y - 6
    cv.round_rect(6, deck_y, W - 12, H - deck_y - 12, 6, shade(iron, 0.04))
    cv.dither_rect(8, deck_y + 2, W - 16, H - deck_y - 16,
                   iron_mid, iron, 0.35, 0.05)

    # ---- base plinth + brass foot strip ---------------------------------
    cv.round_rect(0, H - 14, W, 14, 4, iron_dark)
    cv.dither_rect(2, H - 12, W - 4, 10, iron, iron_dark, 0.2, 0.95)
    cv.hline(4, H - 14, W - 8, C("brass_dark"))
    cv.hline(4, H - 13, W - 8, C("brass"))

    # ---- nameplate: gold script across the front ------------------------
    plate_w = 9 * 4 + 2
    plate_x = (W - plate_w) // 2
    plate_y = deck_y - 13
    cv.round_rect(plate_x - 5, plate_y - 4, plate_w + 10, 15, 4, iron_dark)
    cv.round_rect(plate_x - 4, plate_y - 3, plate_w + 8, 13, 3, C("brass_dark"))
    cv.dither_rect(plate_x - 3, plate_y - 2, plate_w + 6, 11,
                   C("brass"), C("brass_dark"), 0.55, 0.05)
    cv.hline(plate_x - 2, plate_y - 2, plate_w + 4, C("brass_hi"))
    draw_tiny(cv, plate_x + 1, plate_y + 2, "REMINGTON", shade(C("brass_dark"), -0.12))
    draw_tiny(cv, plate_x + 1, plate_y + 1, "REMINGTON", C("iron_dark"))

    # lower plate on the plinth
    draw_tiny(cv, (W - 13 * 4) // 2, H - 11, "REMINGTON NO.1", C("brass_dark"))
    draw_tiny(cv, (W - 13 * 4) // 2, H - 12, "REMINGTON NO.1", C("brass"))

    # ---- gold pinstriping, the period decorative touch -------------------
    stripe = C("brass_dark")
    cv.hline(10, body_top + 6, nx0 - 14, stripe)
    cv.hline(nx1 + 4, body_top + 6, W - nx1 - 14, stripe)
    for side in (0, 1):
        ax = 6 if side == 0 else W - 26
        cv.hline(ax, 8, 20, stripe)
        cv.hline(ax, notch_h + 14, 20, stripe)

    # ---- ribbon spools on top of each arm --------------------------------
    r = L.TW_SPOOL_R
    for side in (0, 1):
        cx = 17 if side == 0 else W - 17
        cy = 13
        cv.fdisc(cx, cy, r, iron_dark)
        cv.fdisc(cx, cy, r - 1, C("brass_dark"))
        cv.disc_ring(cx, cy, r - 2, C("brass"), 2)
        cv.fdisc(cx, cy, r - 5, C("ink"))          # the inked ribbon itself
        cv.fdisc(cx, cy, 2, C("brass_hi"))
        cv.set(cx - r + 3, cy - 3, C("brass_glint"))

    # ---- ribbon running between the spools, dipping across the platen ----
    # Routed BELOW the strike line on purpose: the ribbon does pass in front of
    # the paper on a real machine, but drawn any higher it lies straight across
    # the line the player just typed and makes it unreadable.
    ribbon_top = L.PLATEN_Y - L.TW_BODY_Y + 3
    for x in range(20, W - 20):
        t = (x - 20) / float(W - 40)
        y = ribbon_top + int(12 * math.sin(math.pi * t))
        if nx0 - 4 < x < nx1 + 4 and y > notch_h - 6:
            continue
        cv.set(x, y, C("ink"))
        cv.set(x, y + 1, shade(C("ink"), -0.04))

    cv.speckle(0, 0, W, H, 11, amount=0.045, density=0.16)
    cv.outline(C("void"))
    cv.rim_light(C("flame_edge"), from_left=True, strength=0.30)
    return cv


# --------------------------------------------------------------------------
# carriage + platen
# --------------------------------------------------------------------------

def make_carriage():
    W, H = L.CARRIAGE_W, L.CARRIAGE_H
    cv = Canvas(W, H)
    iron = C("iron")
    iron_mid = C("iron_mid")

    # paper table: the sloped shelf the sheet rests against
    cv.round_rect(10, 2, W - 20, 16, 3, iron_mid)
    cv.dither_rect(12, 3, W - 24, 13, C("iron_hi"), iron_mid, 0.5, 0.0)

    # main rail the whole assembly hangs from
    cv.round_rect(0, 16, W, 12, 3, iron)
    cv.dither_rect(1, 17, W - 2, 10, iron_mid, iron, 0.55, 0.05)
    cv.hline(4, 17, W - 8, C("iron_edge"))

    # paper-bail arm with its two little rubber rollers
    cv.round_rect(24, 20, W - 48, 3, 1, C("iron_edge"))
    for bx in (W // 3, 2 * W // 3):
        cv.fdisc(bx, 21, 3, C("iron_dark"))
        cv.fdisc(bx, 21, 2, shade(C("iron_dark"), 0.08))

    # end plates
    for side in (0, 1):
        ax = 0 if side == 0 else W - 16
        cv.round_rect(ax, 8, 16, H - 14, 3, iron)
        cv.dither_rect(ax + 1, 9, 14, H - 16, iron_mid, iron, 0.5, 0.05)
        cv.hline(ax + 2, 10, 12, C("brass_dark"))

    cv.speckle(0, 0, W, H, 23, amount=0.04, density=0.14)
    cv.outline(C("void"))
    cv.rim_light(C("flame_edge"), from_left=True, strength=0.28)
    return cv


def make_platen():
    """Rubber cylinder. The horizontal banding is what sells it as round."""
    W, H = L.PLATEN_W, L.PLATEN_H
    cv = Canvas(W, H)
    rubber_dark = C("iron_dark")
    rubber = (58, 46, 42, 255)
    rubber_hi = (96, 80, 72, 255)

    cv.round_rect(0, 0, W, H, 6, rubber_dark)
    # a vertical ramp reading as the curve of the cylinder, lit from above-left
    for j in range(1, H - 1):
        t = j / float(H - 1)
        # brightest a third of the way down, falling off to both edges
        f = 1.0 - abs(t - 0.32) / 0.68
        col = mix(rubber_dark, rubber_hi, max(0.0, f) ** 1.4)
        for i in range(1, W - 1):
            if cv.get(i, j)[3] > 0:
                cv.set(i, j, col)
    cv.hline(6, 1, W - 12, mix(rubber_hi, C("flame_edge"), 0.25))
    cv.hline(6, H - 2, W - 12, C("void"))
    cv.speckle(0, 0, W, H, 31, amount=0.05, density=0.2)
    cv.outline(C("void"))
    return cv


def make_knob_frames(n=8):
    """Platen end knob, n rotation steps. Turning it is how paper is fed."""
    r = L.KNOB_R
    size = r * 2 + 4
    frames = []
    for f in range(n):
        cv = Canvas(size, size)
        cx = cy = size // 2
        cv.fdisc(cx, cy, r, C("iron_dark"))
        cv.fdisc(cx, cy, r - 1, C("iron_mid"))
        cv.disc_ring(cx, cy, r - 1, C("iron"), 1)
        # knurled grip ridges - these are what make the rotation readable
        for k in range(10):
            a = (k / 10.0 + f / float(n) / 10.0) * math.tau
            x0 = cx + math.cos(a) * (r - 5)
            y0 = cy + math.sin(a) * (r - 5)
            x1 = cx + math.cos(a) * (r - 1)
            y1 = cy + math.sin(a) * (r - 1)
            cv.line(x0, y0, x1, y1, C("iron_dark"))
            cv.set(x0, y0, C("iron_hi"))
        cv.fdisc(cx, cy, r - 6, C("brass_dark"))
        cv.fdisc(cx, cy, r - 7, C("brass"))
        cv.set(cx - 2, cy - 2, C("brass_glint"))
        cv.outline(C("void"))
        cv.rim_light(C("flame_edge"), from_left=True, strength=0.35)
        frames.append(cv)
    return frames


def make_release_lever():
    """The paper release. Two frames: engaged (down) and released (up).

    Throwing it lifts the feed rollers off the platen so the sheet can be drawn
    straight out - the escape hatch from winding a page all the way through.
    """
    W, H = L.RELEASE_LEVER_W, L.RELEASE_LEVER_H
    frames = []
    for released in (False, True):
        cv = Canvas(W, H)
        # pivot boss on the left, arm swinging up when released
        cv.fdisc(5, H - 5, 4, C("iron"))
        cv.fdisc(5, H - 5, 2, C("iron_mid"))
        tipx, tipy = (W - 4, H - 7) if not released else (W - 6, 3)
        for off in (-1, 0, 1):
            cv.line(5 + off, H - 5, tipx + off, tipy,
                    C("iron") if off else C("iron_hi"))
        # knurled grip
        cv.round_rect(tipx - 3, tipy - 3, 7, 7, 2,
                      C("brass_dark") if not released else C("brass"))
        cv.set(tipx - 1, tipy - 1, C("brass_glint"))
        cv.outline(C("void"))
        cv.rim_light(C("flame_edge"), from_left=True, strength=0.45)
        frames.append(cv)
    return sheet(frames, cols=2)


def make_return_lever():
    """The bar the player drags right-to-left to return the carriage."""
    W, H = L.RETURN_LEVER_W, L.RETURN_LEVER_H
    cv = Canvas(W, H)
    # pivot boss on the right, arm sweeping left, wooden grip on the end
    cv.fdisc(W - 6, H // 2, 5, C("iron"))
    cv.fdisc(W - 6, H // 2, 3, C("iron_mid"))
    cv.round_rect(8, H // 2 - 2, W - 12, 4, 1, C("iron"))
    cv.hline(9, H // 2 - 2, W - 14, C("iron_hi"))
    cv.round_rect(0, 1, 12, H - 2, 4, C("leather_dark"))
    cv.dither_rect(1, 2, 10, H - 4, C("leather"), C("leather_dark"), 0.7, 0.05)
    cv.outline(C("void"))
    cv.rim_light(C("flame_edge"), from_left=True, strength=0.4)
    return cv


# --------------------------------------------------------------------------
# keycaps
# --------------------------------------------------------------------------

def _keycap(legend, pressed, wide=False):
    if wide:
        return _spacebar_cap(pressed)
    w = L.KEY_W
    h = L.KEY_H
    cv = Canvas(w, h + 3)
    dy = 2 if pressed else 0

    # the post the cap sits on - shortening it is what reads as "pressed"
    post_top = 5 + dy
    cv.frect(w // 2 - 2, post_top, 4, h - post_top + 1, C("iron_dark"))
    cv.vline(w // 2 - 2, post_top, h - post_top + 1, C("iron"))

    # cap
    face = C("paper_lit") if not pressed else C("paper_dark")
    ring = C("iron_dark")
    r = L.KEY_W // 2
    cx, cy = w // 2, r + dy
    cv.fdisc(cx, cy, r, ring)
    cv.fdisc(cx, cy, r - 1, C("brass_dark"))
    cv.fdisc(cx, cy, r - 2, face)
    cv.disc_ring(cx, cy, r - 2, C("paper_hi"), 1)
    cv.set(cx - 3, cy - 4, C("paper_hi"))
    if legend:
        draw_tiny(cv, cx - 1, cy - 2, legend[0], C("ink"))
    if pressed:
        # sink the whole cap into shadow when down
        cv.shade_region(0, 0, w, h + 3, -0.10)
    cv.outline(C("void"))
    return cv


def make_keycaps():
    """Atlas: one column per key, row 0 = up, row 1 = down."""
    legends = []
    for row in L.KEY_ROWS:
        legends.extend(list(row))
    cells = []
    for st in (False, True):
        for ch in legends:
            cells.append(_keycap(ch, st))
    atlas = sheet(cells, cols=len(legends))
    return atlas, legends


def _spacebar_cap(pressed):
    """Wide ivory bar. Kept short so its post never shows below the plinth."""
    w, h = L.SPACEBAR_W, L.SPACEBAR_H
    cv = Canvas(w, h)
    dy = 2 if pressed else 0
    cv.frect(w // 2 - 8, 4 + dy, 16, h - 4 - dy, C("iron_dark"))
    cv.round_rect(0, dy, w, 8, 3, C("iron_dark"))
    cv.round_rect(1, 1 + dy, w - 2, 6, 2,
                  C("paper_lit") if not pressed else C("paper_dark"))
    cv.hline(4, 1 + dy, w - 8, C("paper_hi"))
    if pressed:
        cv.shade_region(0, 0, w, h, -0.10)
    cv.outline(C("void"))
    return cv


def make_spacebar():
    return sheet([_spacebar_cap(False), _spacebar_cap(True)], cols=2)


# --------------------------------------------------------------------------
# typebars
# --------------------------------------------------------------------------

def _bar_canvas(angle_deg, length, pad=6):
    """One typebar drawn at a given angle, pivoting about the bottom centre.

    Returned canvas is square and centred on the pivot so the game can place
    every frame at the same point and let the art do the swinging.
    """
    size = (length + pad) * 2
    cv = Canvas(size, size)
    px = py = size // 2
    a = math.radians(angle_deg)
    tipx = px + math.sin(a) * length
    tipy = py - math.cos(a) * length

    # the bar: two-tone so it reads as a rod with a lit edge
    cv.line(px, py, tipx, tipy, C("brass_dark"))
    nx = math.cos(a)
    ny = math.sin(a)
    cv.line(px + nx, py + ny, tipx + nx, tipy + ny, C("brass"))
    cv.line(px - nx * 0.9, py - ny * 0.9, tipx - nx * 0.9, tipy - ny * 0.9,
            C("brass_hi"))

    # the type slug on the end - the bit that carries the letter
    cv.fdisc(tipx, tipy, 2, C("iron_dark"))
    cv.set(tipx, tipy, C("iron_hi"))
    # pivot boss
    cv.fdisc(px, py, 2, C("iron"))
    return cv


def make_typebar_swing():
    """Rest -> struck, as a horizontal strip of equally sized frames."""
    frames = []
    n = L.TYPEBAR_FRAMES
    for f in range(n):
        t = f / float(n - 1)
        # ease-out: the bar leaves the basket fast and arrives softly
        e = 1.0 - (1.0 - t) ** 2
        angle = -62.0 * (1.0 - e)     # rest lies back, struck stands upright
        frames.append(_bar_canvas(angle, L.TYPEBAR_LEN))
    return sheet(frames, cols=n)


def _jam_bar(cv, px, py, angle_deg, length, bright):
    """One jammed bar, drawn thicker and hotter than a resting one."""
    a = math.radians(angle_deg)
    tipx = px + math.sin(a) * length
    tipy = py - math.cos(a) * length
    nx = math.cos(a)
    ny = math.sin(a)
    edge = C("brass_dark") if not bright else C("brass")
    body = C("brass") if not bright else C("brass_hi")
    lit = C("brass_hi") if not bright else C("brass_glint")
    for off, col in ((-1.0, edge), (0.0, body), (1.0, edge)):
        cv.line(px + nx * off, py + ny * off,
                tipx + nx * off, tipy + ny * off, col)
    cv.line(px - nx * 1.8, py - ny * 1.8, tipx - nx * 1.8, tipy - ny * 1.8, lit)
    # the type slug, wedged
    cv.fdisc(tipx, tipy, 3, C("iron_dark"))
    cv.fdisc(tipx, tipy - 1, 2, C("iron_hi"))
    cv.fdisc(px, py, 2, C("iron"))
    return (tipx, tipy)


def make_typebar_jam():
    """Two bars frozen CROSSED against the platen - the jam the player clears.

    They pivot from two different points in the basket and lean into each other,
    because that is what a clash actually is. Radiating both from one point
    makes a V that never touches, and a jam the player cannot see is a jam they
    cannot learn to fix.
    """
    # Longer than a normal bar so the locked tips rise ABOVE the frame's notch
    # and cross in front of the paper. A jam that happens down inside the basket
    # is invisible; a jam standing against the platen is unmistakable.
    length = L.TYPEBAR_LEN + 12
    size = (length + 8) * 2
    cv = Canvas(size, size)
    cx = cy = size // 2
    spread = 20                        # how far apart the two pivots sit
    lean = 23.0                        # degrees each bar leans inward

    tip_a = _jam_bar(cv, cx - spread, cy, lean, length, False)
    tip_b = _jam_bar(cv, cx + spread, cy, -lean, length, True)

    # ink ground out of the ribbon where the slugs are locked together
    cross_h = spread / math.tan(math.radians(lean))
    mid = (cx, cy - cross_h)
    for (dx, dy, r) in ((0, 0, 3), (2, 2, 2), (-3, 1, 2), (1, -3, 1)):
        cv.fdisc(mid[0] + dx, mid[1] + dy, r, C("ink"))
    cv.fdisc(mid[0] - 1, mid[1] - 1, 1, C("ink_soft"))

    cv.rim_light(C("flame_edge"), from_left=True, strength=0.5)
    return cv


def make_basket():
    """The resting fan of bars sitting in the well, drawn once as a backdrop."""
    W, H = L.BASKET_W, L.BASKET_H
    cv = Canvas(W, H)
    cx = W // 2
    n = 21
    for k in range(n):
        t = (k / float(n - 1)) * 2.0 - 1.0        # -1 .. 1
        angle = math.radians(t * 62.0)
        # bars nearer the edges lie further back, so darken them
        depth = 1.0 - abs(t) * 0.45
        x0 = cx + t * (W * 0.44)
        y0 = H - 2
        length = H * 0.82 * (0.72 + 0.28 * (1.0 - abs(t)))
        x1 = x0 + math.sin(angle) * 6
        y1 = y0 - length
        col = mix(C("brass_dark"), C("brass"), depth)
        cv.line(x0, y0, x1, y1, mix(col, C("void"), 0.35))
        cv.line(x0 + 1, y0, x1 + 1, y1, col)
        cv.fdisc(x1, y1, 1, mix(C("iron_dark"), C("iron_hi"), depth * 0.5))
    cv.shade_region(0, 0, W, H // 3, -0.10)
    return cv


# --------------------------------------------------------------------------

def generate(save):
    save("tw_body", make_body())
    save("tw_carriage", make_carriage())
    save("tw_platen", make_platen())
    save("tw_knob", sheet(make_knob_frames(), cols=8))
    save("tw_return_lever", make_return_lever())
    save("tw_release_lever", make_release_lever())
    caps, legends = make_keycaps()
    save("tw_keycaps", caps)
    save("tw_spacebar", make_spacebar())
    save("tw_typebar_swing", make_typebar_swing())
    save("tw_typebar_jam", make_typebar_jam())
    save("tw_basket", make_basket())
    return {"key_legends": "".join(legends)}
