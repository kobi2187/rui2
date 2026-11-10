#!/usr/bin/env python3
"""score.py <a.png> <b.png> -- how alike two renders are, as one TSV line:

    diff%   share of pixels whose largest channel difference exceeds 8%
    blur%   the same after a 3px box blur of both (forgives antialiasing and
            one-pixel shifts; still sees missing, moved or recoloured things)
    ssim    mean structural similarity of the greyscale images, 8x8 windows
            (1.0 identical; ~0.95+ reads as "the same screen" to a person)

numpy + Pillow only; ImageMagick 6 has no SSIM.
"""
import sys
import numpy as np
from PIL import Image


def load(p):
    return np.asarray(Image.open(p).convert("RGB"), dtype=np.float64) / 255.0


def box(img, r):
    # Separable box blur by cumulative sums, edges clamped.
    k = 2 * r + 1
    for axis in (0, 1):
        pad = [(0, 0)] * img.ndim
        pad[axis] = (r + 1, r)
        c = np.cumsum(np.pad(img, pad, mode="edge"), axis=axis)
        hi = np.take(c, range(k, c.shape[axis]), axis=axis)
        lo = np.take(c, range(0, c.shape[axis] - k), axis=axis)
        img = (hi - lo) / k
    return img


def ssim(a, b, r=4):
    ga, gb = a @ [0.299, 0.587, 0.114], b @ [0.299, 0.587, 0.114]
    c1, c2 = 0.01 ** 2, 0.03 ** 2
    ma, mb = box(ga, r), box(gb, r)
    va = box(ga * ga, r) - ma * ma
    vb = box(gb * gb, r) - mb * mb
    cov = box(ga * gb, r) - ma * mb
    s = ((2 * ma * mb + c1) * (2 * cov + c2)) / ((ma ** 2 + mb ** 2 + c1) * (va + vb + c2))
    return float(s.mean())


def main():
    a, b = load(sys.argv[1]), load(sys.argv[2])
    if a.shape != b.shape:
        print(f"size\t{a.shape[1]}x{a.shape[0]} vs {b.shape[1]}x{b.shape[0]}")
        sys.exit(1)
    diff = (np.abs(a - b).max(axis=2) > 0.08).mean() * 100
    blur = (np.abs(box(a, 3) - box(b, 3)).max(axis=2) > 0.08).mean() * 100
    print(f"{diff:.2f}\t{blur:.2f}\t{ssim(a, b):.4f}")


if __name__ == "__main__":
    main()
