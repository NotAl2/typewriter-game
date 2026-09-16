"""Shared palette + pixel-art drawing helpers for The Correspondence Ritual.

Every generated asset pulls its colours from here so the whole game reads as one
painting.  Palette is derived from the 1870s candlelit-study reference art:
warm walnut, brass, candle gold, cream paper, ink brown-black.

Light direction convention for ALL assets: the candle sits low and to the LEFT
of the desk, so left-facing surfaces catch warm light and right-facing surfaces
fall into cool shadow.  Keep to it or the scene stops reading as one room.
"""

import colorsys

# --------------------------------------------------------------------------
# core palette
# --------------------------------------------------------------------------

def _h(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)


PAL = {
    # shadow / ground
    "void":         _h("#0d0805"),
    "shadow":       _h("#1a0f0a"),
    "shadow_warm":  _h("#241610"),

    # walnut panelling & furniture
    "wood_darkest": _h("#2a1a11"),
    "wood_dark":    _h("#3a2418"),
    "wood_mid":     _h("#5a3a22"),
    "wood_light":   _h("#7a5230"),
    "wood_hi":      _h("#9a6c42"),
    "wood_glow":    _h("#b98a55"),

    # candle light
    "flame_core":   _h("#fff6d8"),
    "flame_mid":    _h("#ffe9b0"),
    "flame_edge":   _h("#f5c877"),
    "flame_low":    _h("#e08a34"),
    "glow":         _h("#f5c877"),

    # paper
    "paper_shadow": _h("#c4b394"),
    "paper_dark":   _h("#d8c9a8"),
    "paper_mid":    _h("#e8dcc0"),
    "paper_lit":    _h("#f2e8d0"),
    "paper_hi":     _h("#fbf4e2"),

    # ink
    "ink":          _h("#2a1f18"),
    "ink_soft":     _h("#4a3a2c"),
    "ink_faint":    _h("#6b5844"),

    # metal
    "iron_dark":    _h("#151110"),
    "iron":         _h("#211a17"),
    "iron_mid":     _h("#332824"),
    "iron_hi":      _h("#4d3d36"),
    "iron_edge":    _h("#6b5750"),
    "brass_dark":   _h("#5c451e"),
    "brass":        _h("#8a6a2e"),
    "brass_hi":     _h("#b08840"),
    "brass_glint":  _h("#d8b064"),

    # fabric / room
    "curtain":      _h("#6e2422"),
    "curtain_dark": _h("#4a1618"),
    "curtain_hi":   _h("#8e3630"),
    "night":        _h("#1c2438"),
    "night_hi":     _h("#2e3c58"),
    "moon":         _h("#8fa2c4"),

    # wax  (molten -> cooled)
    "wax_hot":      _h("#ffb257"),
    "wax_molten":   _h("#ff8a3c"),
    "wax_warm":     _h("#e0532a"),
    "wax_cool":     _h("#b02a24"),
    "wax_cold":     _h("#8e1b22"),
    "wax_dark":     _h("#5e1016"),
    "wax_scorch":   _h("#241012"),

    # accents
    "leather":      _h("#7a4a28"),
    "leather_dark": _h("#4e2c17"),
    "green_book":   _h("#3c4a32"),
    "blue_book":    _h("#2c3a4e"),
    "rose":         _h("#a8323a"),
    "rose_dark":    _h("#6e1c26"),

    "clear":        (0, 0, 0, 0),
}


def C(name):
    """Look up a palette colour by name."""
    return PAL[name]


# --------------------------------------------------------------------------
# colour maths
# --------------------------------------------------------------------------

def shade(col, amount):
    """Lighten (amount > 0) or darken (amount < 0) a colour in HSV space.

    Saturation is nudged the opposite way so darks go richer and lights go
    creamier, which is what keeps procedural ramps from looking like grey mud.
    """
    r, g, b, a = col
    h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
    v = max(0.0, min(1.0, v + amount))
    s = max(0.0, min(1.0, s - amount * 0.28))
    r, g, b = colorsys.hsv_to_rgb(h, s, v)
    return (int(r * 255), int(g * 255), int(b * 255), a)


def mix(a, b, t):
    """Linear blend between two RGBA colours."""
    t = max(0.0, min(1.0, t))
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(4))


def with_alpha(col, alpha):
    return (col[0], col[1], col[2], int(max(0, min(255, alpha))))


def warm_light(col, strength):
    """Push a colour toward candle gold - used for anything the flame touches."""
    return mix(col, PAL["flame_edge"], strength)


# --------------------------------------------------------------------------
# ordered dithering
# --------------------------------------------------------------------------

BAYER4 = [
    [0, 8, 2, 10],
    [12, 4, 14, 6],
    [3, 11, 1, 9],
    [15, 7, 13, 5],
]

BAYER8 = [
    [0, 32, 8, 40, 2, 34, 10, 42],
    [48, 16, 56, 24, 50, 18, 58, 26],
    [12, 44, 4, 36, 14, 46, 6, 38],
    [60, 28, 52, 20, 62, 30, 54, 22],
    [3, 35, 11, 43, 1, 33, 9, 41],
    [51, 19, 59, 27, 49, 17, 57, 25],
    [15, 47, 7, 39, 13, 45, 5, 37],
    [63, 31, 55, 23, 61, 29, 53, 21],
]


def dither_pick(x, y, t, col_a, col_b, matrix=BAYER4):
    """Ordered-dither between two palette colours.

    t = 0 -> all col_a, t = 1 -> all col_b.  Using two flat palette colours plus
    a dither pattern (rather than a true gradient) is what keeps the output
    reading as pixel art instead of as a blurry render.
    """
    n = len(matrix)
    thresh = (matrix[y % n][x % n] + 0.5) / (n * n)
    return col_b if t > thresh else col_a


# --------------------------------------------------------------------------
# deterministic noise
# --------------------------------------------------------------------------

class Rand:
    """Tiny deterministic PRNG.

    Deliberately not `random` - every asset is generated from a fixed seed so
    regenerating the art after a tweak produces a byte-identical diff for
    everything you did not touch.
    """

    def __init__(self, seed):
        self.s = (seed * 2654435761 + 1013904223) & 0xFFFFFFFF

    def next(self):
        self.s = (self.s * 1664525 + 1013904223) & 0xFFFFFFFF
        return self.s

    def f(self):
        return self.next() / 4294967296.0

    def range(self, lo, hi):
        return lo + (hi - lo) * self.f()

    def i(self, lo, hi):
        """Inclusive integer range."""
        return lo + self.next() % (hi - lo + 1)

    def chance(self, p):
        return self.f() < p

    def pick(self, seq):
        return seq[self.next() % len(seq)]
