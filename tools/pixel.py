"""Minimal pixel-art drawing toolkit.

PIL's own drawing primitives anti-alias and think in floats, which is exactly
wrong for this project. Everything here writes whole pixels only, so the output
survives nearest-neighbour upscaling in Godot without a single soft edge.
"""

from PIL import Image
from palette import PAL, shade, mix, dither_pick, BAYER4, BAYER8, Rand

CLEAR = (0, 0, 0, 0)


class Canvas:
    def __init__(self, w, h, fill=CLEAR):
        self.w = w
        self.h = h
        self.img = Image.new("RGBA", (w, h), fill)
        self.px = self.img.load()

    # -- primitives --------------------------------------------------------

    def set(self, x, y, col):
        x = int(x)
        y = int(y)
        if not (0 <= x < self.w and 0 <= y < self.h):
            return
        if col[3] <= 0:
            return
        if col[3] == 255:
            self.px[x, y] = col
            return
        # source-over blend
        d = self.px[x, y]
        a = col[3] / 255.0
        da = d[3] / 255.0
        na = a + da * (1 - a)
        if na <= 0:
            return
        self.px[x, y] = (
            int((col[0] * a + d[0] * da * (1 - a)) / na),
            int((col[1] * a + d[1] * da * (1 - a)) / na),
            int((col[2] * a + d[2] * da * (1 - a)) / na),
            int(na * 255),
        )

    def get(self, x, y):
        x = int(x)
        y = int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[x, y]
        return CLEAR

    def frect(self, x, y, w, h, col):
        for j in range(int(y), int(y + h)):
            for i in range(int(x), int(x + w)):
                self.set(i, j, col)

    def rect(self, x, y, w, h, col):
        x, y, w, h = int(x), int(y), int(w), int(h)
        for i in range(x, x + w):
            self.set(i, y, col)
            self.set(i, y + h - 1, col)
        for j in range(y, y + h):
            self.set(x, j, col)
            self.set(x + w - 1, j, col)

    def hline(self, x, y, w, col):
        for i in range(int(x), int(x + w)):
            self.set(i, y, col)

    def vline(self, x, y, h, col):
        for j in range(int(y), int(y + h)):
            self.set(x, j, col)

    def line(self, x0, y0, x1, y1, col):
        """Bresenham - integer only, no anti-aliasing."""
        x0, y0, x1, y1 = int(x0), int(y0), int(x1), int(y1)
        dx = abs(x1 - x0)
        dy = -abs(y1 - y0)
        sx = 1 if x0 < x1 else -1
        sy = 1 if y0 < y1 else -1
        err = dx + dy
        while True:
            self.set(x0, y0, col)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy

    # -- rounded / curved shapes ------------------------------------------

    def fdisc(self, cx, cy, r, col):
        r2 = r * r
        for j in range(int(cy - r) - 1, int(cy + r) + 2):
            for i in range(int(cx - r) - 1, int(cx + r) + 2):
                dx = i - cx
                dy = j - cy
                if dx * dx + dy * dy <= r2:
                    self.set(i, j, col)

    def disc_ring(self, cx, cy, r, col, thickness=1):
        inner = (r - thickness) ** 2
        outer = r * r
        for j in range(int(cy - r) - 1, int(cy + r) + 2):
            for i in range(int(cx - r) - 1, int(cx + r) + 2):
                dx = i - cx
                dy = j - cy
                d = dx * dx + dy * dy
                if inner < d <= outer:
                    self.set(i, j, col)

    def fellipse(self, cx, cy, rx, ry, col):
        for j in range(int(cy - ry) - 1, int(cy + ry) + 2):
            for i in range(int(cx - rx) - 1, int(cx + rx) + 2):
                dx = (i - cx) / max(0.001, rx)
                dy = (j - cy) / max(0.001, ry)
                if dx * dx + dy * dy <= 1.0:
                    self.set(i, j, col)

    def round_rect(self, x, y, w, h, r, col):
        """Filled rectangle with the corner pixels knocked off - the standard
        pixel-art way to imply a radius without anti-aliasing."""
        x, y, w, h = int(x), int(y), int(w), int(h)
        r = max(0, min(r, min(w, h) // 2))
        for j in range(h):
            for i in range(w):
                # nearest corner centre, if we are inside a corner box
                cx = None
                cy = None
                if i < r:
                    cx = r
                elif i > w - 1 - r:
                    cx = w - 1 - r
                if j < r:
                    cy = r
                elif j > h - 1 - r:
                    cy = h - 1 - r
                if cx is not None and cy is not None:
                    dx = i - cx
                    dy = j - cy
                    if dx * dx + dy * dy > r * r + r * 0.35:
                        continue
                self.set(x + i, y + j, col)

    # -- shading -----------------------------------------------------------

    def dither_rect(self, x, y, w, h, col_a, col_b, t0, t1, vertical=True,
                    matrix=BAYER4):
        """Fill a rect with a dithered ramp from t0 to t1 between two colours."""
        x, y, w, h = int(x), int(y), int(w), int(h)
        for j in range(h):
            for i in range(w):
                f = (j / max(1, h - 1)) if vertical else (i / max(1, w - 1))
                t = t0 + (t1 - t0) * f
                self.set(x + i, y + j, dither_pick(x + i, y + j, t, col_a, col_b, matrix))

    def ramp_rect(self, x, y, w, h, colors, t0, t1, vertical=True,
                  dither_width=0.34, matrix=BAYER4):
        """Banded shading ramp - the correct way to shade a large pixel-art area.

        A straight two-colour dither across a big region reads as noise. This
        walks an ordered list of palette colours instead, keeping most of each
        band solid and dithering only across the narrow seam between bands.
        """
        x, y, w, h = int(x), int(y), int(w), int(h)
        n = len(colors)
        for j in range(h):
            for i in range(w):
                f = (j / max(1, h - 1)) if vertical else (i / max(1, w - 1))
                t = t0 + (t1 - t0) * f
                self.set(x + i, y + j,
                         self._ramp_pick(x + i, y + j, t, colors, n,
                                         dither_width, matrix))

    @staticmethod
    def _ramp_pick(px, py, t, colors, n, dither_width, matrix):
        t = max(0.0, min(0.9999, t))
        p = t * (n - 1)
        band = int(p)
        frac = p - band
        if band >= n - 1:
            return colors[-1]
        if frac <= 1.0 - dither_width:
            return colors[band]
        local = (frac - (1.0 - dither_width)) / dither_width
        return dither_pick(px, py, local, colors[band], colors[band + 1], matrix)

    def ramp_glow(self, cx, cy, radius, colors, strength=1.0, falloff=2.0,
                  matrix=BAYER4):
        """Radial light pool built from banded colours instead of a dot cloud."""
        n = len(colors)
        for j in range(max(0, int(cy - radius)), min(self.h, int(cy + radius) + 1)):
            for i in range(max(0, int(cx - radius)), min(self.w, int(cx + radius) + 1)):
                base = self.get(i, j)
                if base[3] == 0:
                    continue
                dx = (i - cx) / radius
                dy = (j - cy) / radius
                d = (dx * dx + dy * dy) ** 0.5
                if d >= 1.0:
                    continue
                t = ((1.0 - d) ** falloff) * strength
                if t <= 0.0:
                    continue
                tint = self._ramp_pick(i, j, min(0.9999, t), colors, n,
                                       0.42, matrix)
                self.set(i, j, mix(base, tint, min(0.55, t * 0.75)))

    def radial_glow(self, cx, cy, radius, col, strength=1.0, matrix=BAYER8,
                    max_mix=0.75):
        """Soft dithered light falloff - used for candle and lamp pools."""
        for j in range(int(cy - radius), int(cy + radius) + 1):
            for i in range(int(cx - radius), int(cx + radius) + 1):
                if not (0 <= i < self.w and 0 <= j < self.h):
                    continue
                dx = (i - cx) / radius
                dy = (j - cy) / radius
                d = (dx * dx + dy * dy) ** 0.5
                if d >= 1.0:
                    continue
                t = (1.0 - d) ** 2 * strength
                n = len(matrix)
                if t > (matrix[j % n][i % n] + 0.5) / (n * n):
                    base = self.get(i, j)
                    if base[3] > 0:
                        self.set(i, j, mix(base, col, min(max_mix, t)))

    def shade_region(self, x, y, w, h, amount, mask_alpha=True):
        """Lighten/darken whatever is already drawn in a rect."""
        for j in range(int(y), int(y + h)):
            for i in range(int(x), int(x + w)):
                c = self.get(i, j)
                if c[3] > 0 or not mask_alpha:
                    self.set(i, j, shade(c, amount))

    # -- texture -----------------------------------------------------------

    def wood_grain(self, x, y, w, h, seed, density=0.30, contrast=0.07):
        """Horizontal grain streaks with occasional knots.

        Streaks are long, thin and tapered at both ends; without the taper they
        read as scratches rather than grain.
        """
        rnd = Rand(seed)
        x, y, w, h = int(x), int(y), int(w), int(h)
        n_streaks = int(h * density) + 2
        for _ in range(n_streaks):
            sy = y + rnd.i(0, max(0, h - 1))
            sx = x + rnd.i(0, max(1, w - 4))
            length = rnd.i(max(2, w // 6), max(3, w))
            amt = rnd.range(-contrast, contrast * 0.7)
            drift = rnd.range(-0.02, 0.02)
            for i in range(length):
                px = sx + i
                if px >= x + w:
                    break
                py = sy + int(i * drift)
                edge = min(i, length - 1 - i) / max(1.0, length * 0.2)
                a = amt * min(1.0, edge)
                c = self.get(px, py)
                if c[3] > 0:
                    self.set(px, py, shade(c, a))
        for _ in range(max(1, w * h // 2600)):
            kx = x + rnd.i(2, max(3, w - 3))
            ky = y + rnd.i(1, max(2, h - 2))
            kr = rnd.i(1, 2)
            for j in range(-kr - 1, kr + 2):
                for i in range(-kr - 1, kr + 2):
                    d = (i * i + j * j) ** 0.5
                    if d <= kr + 0.5:
                        c = self.get(kx + i, ky + j)
                        if c[3] > 0:
                            self.set(kx + i, ky + j, shade(c, -0.09 if d < kr else -0.04))

    def speckle(self, x, y, w, h, seed, amount=0.05, density=0.10):
        """Subtle per-pixel value noise - breaks up flat fills."""
        rnd = Rand(seed)
        for j in range(int(y), int(y + h)):
            for i in range(int(x), int(x + w)):
                if rnd.f() < density:
                    c = self.get(i, j)
                    if c[3] > 0:
                        self.set(i, j, shade(c, rnd.range(-amount, amount)))

    # -- edges -------------------------------------------------------------

    def outline(self, col, diagonal=False):
        """Trace an outline around every opaque cluster."""
        adds = []
        offs = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        if diagonal:
            offs += [(-1, -1), (1, -1), (-1, 1), (1, 1)]
        for j in range(self.h):
            for i in range(self.w):
                if self.get(i, j)[3] != 0:
                    continue
                for (dx, dy) in offs:
                    if self.get(i + dx, j + dy)[3] > 128:
                        adds.append((i, j))
                        break
        for (i, j) in adds:
            self.set(i, j, col)

    def rim_light(self, col, from_left=True, strength=0.55):
        """Add a lit edge on the side facing the candle."""
        adds = []
        dx = -1 if from_left else 1
        for j in range(self.h):
            for i in range(self.w):
                if self.get(i, j)[3] < 200:
                    continue
                if self.get(i + dx, j)[3] < 128:
                    adds.append((i, j))
        for (i, j) in adds:
            self.set(i, j, mix(self.get(i, j), col, strength))

    def drop_shadow(self, dx=1, dy=1, col=(0, 0, 0, 90)):
        """Return a NEW canvas with a hard offset shadow behind this one."""
        out = Canvas(self.w, self.h)
        for j in range(self.h):
            for i in range(self.w):
                if self.get(i, j)[3] > 128:
                    out.set(i + dx, j + dy, col)
        out.blit(self, 0, 0)
        return out

    # -- composition -------------------------------------------------------

    def blit(self, other, x, y, alpha=255):
        for j in range(other.h):
            for i in range(other.w):
                c = other.get(i, j)
                if c[3] > 0:
                    if alpha < 255:
                        c = (c[0], c[1], c[2], c[3] * alpha // 255)
                    self.set(x + i, y + j, c)

    def sub(self, x, y, w, h):
        out = Canvas(w, h)
        for j in range(h):
            for i in range(w):
                out.set(i, j, self.get(x + i, y + j))
        return out

    def flip_h(self):
        out = Canvas(self.w, self.h)
        for j in range(self.h):
            for i in range(self.w):
                out.set(self.w - 1 - i, j, self.get(i, j))
        return out

    def tinted(self, col, t):
        out = Canvas(self.w, self.h)
        for j in range(self.h):
            for i in range(self.w):
                c = self.get(i, j)
                if c[3] > 0:
                    out.set(i, j, mix(c, col, t))
        return out

    def copy(self):
        out = Canvas(self.w, self.h)
        out.blit(self, 0, 0)
        return out

    def save(self, path):
        self.img.save(path)
        return path


def sheet(frames, cols=None, pad=0):
    """Pack equally-sized canvases into a horizontal (or grid) atlas."""
    if not frames:
        raise ValueError("no frames")
    fw, fh = frames[0].w, frames[0].h
    cols = cols or len(frames)
    rows = (len(frames) + cols - 1) // cols
    out = Canvas(cols * (fw + pad) - pad, rows * (fh + pad) - pad)
    for idx, f in enumerate(frames):
        cx = (idx % cols) * (fw + pad)
        cy = (idx // cols) * (fh + pad)
        out.blit(f, cx, cy)
    return out
