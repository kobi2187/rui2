#!/usr/bin/env python3
"""Make the background tiles that ship with rui (packages/rui_drawing/tiles/).

Each tile repeats without a seam: planks and bricks sit on a grid that wraps,
noise is blurred with wrap-around, waves are whole periods across the tile.
Run it again to regenerate them (the output is the same every run):

    python3 tools/make_tiles.py

These are starting points. Any PNG works as a theme background
(`background: {image: my_tile.png}`).
"""
import math
import os
import numpy as np
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "packages", "rui_drawing", "tiles")
rng = np.random.default_rng(7)


def wrap_blur(a, r):
    """Box blur with wrap-around, r pixels each way, twice (close to a Gaussian)."""
    for _ in range(2):
        acc = np.zeros_like(a)
        for d in range(-r, r + 1):
            acc += np.roll(a, d, axis=0)
        a = acc / (2 * r + 1)
        acc = np.zeros_like(a)
        for d in range(-r, r + 1):
            acc += np.roll(a, d, axis=1)
        a = acc / (2 * r + 1)
    return a


def streak_noise(h, w, rx, ry):
    """Noise stretched along x (wood fibres): blurred rx across, ry down, wrapping."""
    a = rng.random((h, w))
    for _ in range(3):
        acc = np.zeros_like(a)
        for d in range(-rx, rx + 1):
            acc += np.roll(a, d, axis=1)
        a = acc / (2 * rx + 1)
        acc = np.zeros_like(a)
        for d in range(-ry, ry + 1):
            acc += np.roll(a, d, axis=0)
        a = acc / (2 * ry + 1)
    return (a - a.min()) / (a.max() - a.min() + 1e-9)


def noise(h, w, r):
    n = wrap_blur(rng.random((h, w)), r)
    return (n - n.min()) / (n.max() - n.min() + 1e-9)


def save(name, rgb, alpha=None):
    rgb = np.clip(rgb, 0, 255).astype(np.uint8)
    if alpha is None:
        Image.fromarray(rgb, "RGB").save(os.path.join(OUT, name + ".png"), optimize=True)
    else:
        a = np.clip(alpha, 0, 255).astype(np.uint8)
        Image.fromarray(np.dstack([rgb, a]), "RGBA").save(os.path.join(OUT, name + ".png"), optimize=True)


def wood(name, light, dark, size=256, plank=64):
    """Planks running across, joints staggered, grain along them."""
    h = w = size
    y, x = np.mgrid[0:h, 0:w].astype(float)
    light = np.array(light, float); dark = np.array(dark, float)
    t = np.zeros((h, w))
    rows = h // plank
    warp = (streak_noise(h, w, 40, 6) - 0.5) * 26        # the grain wanders
    fibre = streak_noise(h, w, 24, 0)                     # fine streaks along it
    for p in range(rows):
        band = (y >= p * plank) & (y < (p + 1) * plank)
        yy = y - p * plank
        phase = rng.random() * 6.28
        # Growth rings cut lengthwise: bands whose spacing drifts, bent by warp.
        ring = (yy + warp + np.sin(x / w * 2 * math.pi + phase) * 4) * (0.35 + 0.08 * p)
        g = np.sin(ring + phase) * 0.5 + 0.5
        g = g ** 4                                        # thin late-wood lines
        t[band] = (0.35 * g + 0.25 * fibre + 0.1 * rng.random())[band]
    t += noise(h, w, 2) * 0.25 - 0.12
    t += (noise(h, w, 12) - 0.5) * 0.25                # broad shading
    rgb = light + (dark - light) * np.clip(t, 0, 1)[..., None]
    # Gaps between planks, and joints staggered by half a tile on alternate rows.
    gap = dark * 0.7
    for p in range(rows):
        rgb[p * plank:p * plank + 2] = gap
        jx = (w // 3 if p % 2 == 0 else w * 5 // 6) % w
        rgb[p * plank:(p + 1) * plank, jx:jx + 2] = gap
    save(name, rgb)


def brick(name, base, mortar, size=(128, 64), bw=60, bh=28, gap=4):
    """Running bond: alternate courses offset by half a brick."""
    w, h = size
    rgb = np.zeros((h, w, 3)) + np.array(mortar, float)
    base = np.array(base, float)
    for row in range(h // (bh + gap)):
        off = 0 if row % 2 == 0 else (bw + gap) // 2
        for col in range(-1, w // (bw + gap) + 1):
            tint = 1 + (rng.random() - 0.5) * 0.22
            x0 = col * (bw + gap) + off
            y0 = row * (bh + gap)
            for yy in range(y0, y0 + bh):
                for xx in range(x0, x0 + bw):
                    rgb[yy % h, xx % w] = base * tint
    speck = noise(h, w, 1) - 0.5
    rgb *= (1 + speck * 0.25)[..., None]
    save(name, rgb)


def paper(name, colour, fibre, size=256, strength=1.0):
    """Paper or parchment: soft blotches and fine fibres."""
    c = np.array(colour, float)
    blot = (noise(size, size, 18) - 0.5) * 0.10 * strength
    fine = (noise(size, size, 1) - 0.5) * 0.06 * strength
    rgb = c * (1 + blot + fine)[..., None]
    # Fibres: short dark strokes.
    f = np.array(fibre, float)
    for _ in range(int(160 * strength)):
        x, y = rng.integers(0, size, 2)
        ang = rng.random() * math.pi
        for i in range(rng.integers(3, 9)):
            xx = int(x + math.cos(ang) * i) % size
            yy = int(y + math.sin(ang) * i) % size
            rgb[yy, xx] = rgb[yy, xx] * 0.75 + f * 0.25
    save(name, rgb)


def overlay(name, size, draw):
    """A see-through tile: ink where `draw` says, transparent elsewhere."""
    w, h = size
    a = np.zeros((h, w))
    draw(a)
    save(name, np.zeros((h, w, 3)) + 255, a * 255)


def halftone(a):
    h, w = a.shape
    y, x = np.mgrid[0:h, 0:w]
    for cx, cy in [(3, 3), (9, 9)]:
        dx = np.minimum(abs(x - cx), w - abs(x - cx))
        dy = np.minimum(abs(y - cy), h - abs(y - cy))
        a[np.hypot(dx, dy) <= 2.2] = 1


def graph(a):
    a[:, ::10] = 0.5
    a[::10, :] = 0.5
    a[:, 0] = 1
    a[0, :] = 1


def scanlines(a):
    a[0, :] = 1


def bubbles(a):
    h, w = a.shape
    y, x = np.mgrid[0:h, 0:w]
    for cx, cy, r in [(12, 18, 6), (40, 70, 10), (70, 30, 4), (84, 80, 7),
                      (28, 46, 3), (60, 54, 2), (90, 8, 3), (8, 88, 4)]:
        dx = np.minimum(abs(x - cx), w - abs(x - cx))
        dy = np.minimum(abs(y - cy), h - abs(y - cy))
        d = np.hypot(dx, dy)
        a[abs(d - r) < 0.7] = 1


def grid(a):
    a[:, 0] = 1
    a[0, :] = 1


def pinstripes(name, light, dark, size=(8, 4)):
    """Fine horizontal stripes, two rows light and two a shade darker (Aqua's
    window background)."""
    w, h = size
    rgb = np.zeros((h, w, 3)) + np.array(light, float)
    rgb[h // 2:] = np.array(dark, float)
    save(name, rgb)


def brushed(name, base, size=256):
    """Brushed metal: long horizontal streaks over a light gradient-free grey."""
    streak = streak_noise(size, size, 60, 0)
    fine = noise(size, size, 1)
    k = (streak - 0.5) * 0.10 + (fine - 0.5) * 0.04
    save(name, np.array(base, float) * (1 + k)[..., None])


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    wood("wood", light=(236, 214, 178), dark=(150, 98, 52))           # light oak
    wood("wood-dark", light=(110, 66, 38), dark=(48, 26, 14))          # walnut
    brick("brick", base=(158, 66, 48), mortar=(196, 186, 170))
    paper("parchment", colour=(240, 226, 205), fibre=(150, 120, 90), strength=1.4)
    paper("paper", colour=(244, 236, 216), fibre=(170, 160, 140), strength=0.7)
    overlay("halftone", (12, 12), halftone)
    overlay("graph", (50, 50), graph)
    overlay("scanlines", (4, 4), scanlines)
    overlay("bubbles", (96, 96), bubbles)
    overlay("grid", (32, 32), grid)
    pinstripes("pinstripes", light=(246, 246, 246), dark=(236, 236, 236))   # added last:
    brushed("brushed-metal", base=(196, 196, 198))                          # the rest stay as they were
    for f in sorted(os.listdir(OUT)):
        print(f, os.path.getsize(os.path.join(OUT, f)), "bytes")
