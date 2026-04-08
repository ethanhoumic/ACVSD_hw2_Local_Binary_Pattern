#!/usr/bin/env python3
"""
LBP Testbench Data Generator
Generates patternX.dat (input image) and goldenX.dat (LBP result)
for 128x128 8-bit images, rotation-invariant LBP with 4 rotations.

Usage:
    python gen_testdata.py [num_tests]
    e.g. python gen_testdata.py 5   -> generates pattern0~4.dat and golden0~4.dat
"""

import numpy as np
import sys
import os

# ── Image size ────────────────────────────────────────────────────────────────
IMG_H = 128
IMG_W = 128

# ── Neighbor layout (from spec p.10) ─────────────────────────────────────────
# Positions relative to center (row_offset, col_offset), g0..g7
#
#  g0  g1  g2
#  g7  gc  g3
#  g6  g5  g4
#
NEIGHBORS = [
    (-1, -1),  # g0  -> bit 0  (weight 1)
    (-1,  0),  # g1  -> bit 1  (weight 2)
    (-1,  1),  # g2  -> bit 2  (weight 4)
    ( 0,  1),  # g3  -> bit 3  (weight 8)
    ( 1,  1),  # g4  -> bit 4  (weight 16)
    ( 1,  0),  # g5  -> bit 5  (weight 32)
    ( 1, -1),  # g6  -> bit 6  (weight 64)
    ( 0, -1),  # g7  -> bit 7  (weight 128)
]


def compute_lbp_value(neighbors_vals, center):
    """Compute raw 8-bit LBP given ordered neighbor values and center value."""
    result = 0
    for bit, gp in enumerate(neighbors_vals):
        if gp >= center:
            result |= (1 << bit)
    return result


def rotate_neighbors_90cw(neighbors_vals):
    """
    Rotate the neighbor ring 90° clockwise.

    Original ring (g0..g7) in clockwise order starting top-left:
      g0 g1 g2
      g7    g3
      g6 g5 g4

    Rotating the *image* 90° CW is equivalent to shifting the neighbor
    indices by 2 positions (each 90° = 2 neighbors in an 8-neighbor ring).
    From spec example: 0° LBP=77, 90° LBP=53 -> confirmed shift of 2.
    """
    n = len(neighbors_vals)
    shift = 2  # 90° CW corresponds to shifting ring by 2 positions
    return [neighbors_vals[(i + shift) % n] for i in range(n)]


def compute_rotation_invariant_lbp(img_padded, r, c):
    """
    Compute rotation-invariant LBP for pixel at (r, c) in the padded image.
    The padded image has 1-pixel zero border, so original (r,c) -> padded (r+1, c+1).
    Returns minimum LBP across 0°/90°/180°/270°.
    """
    pr, pc = r + 1, c + 1  # offset into padded image
    center = int(img_padded[pr, pc])

    # Collect neighbor values in g0..g7 order
    neighbors_vals = [int(img_padded[pr + dr, pc + dc]) for dr, dc in NEIGHBORS]

    min_lbp = 256  # larger than any 8-bit value
    for _ in range(4):  # 0°, 90°, 180°, 270°
        lbp = compute_lbp_value(neighbors_vals, center)
        if lbp < min_lbp:
            min_lbp = lbp
        neighbors_vals = rotate_neighbors_90cw(neighbors_vals)

    return min_lbp


def generate_test(index, out_dir="."):
    """Generate one test pattern and its golden output."""
    # Random 128x128 image, uint8
    img = np.random.randint(0, 256, (IMG_H, IMG_W), dtype=np.uint8)

    # Zero-pad by 1 pixel on each side
    img_padded = np.pad(img, pad_width=1, mode='constant', constant_values=0)

    # Compute LBP for every pixel
    lbp = np.zeros((IMG_H, IMG_W), dtype=np.uint8)
    for r in range(IMG_H):
        for c in range(IMG_W):
            lbp[r, c] = compute_rotation_invariant_lbp(img_padded, r, c)

    # ── Write patternX.dat ────────────────────────────────────────────────────
    pattern_path = os.path.join(out_dir, f"pattern{index+2}.dat")
    with open(pattern_path, "w") as f:
        for r in range(IMG_H):
            for c in range(IMG_W):
                f.write(f"{img[r, c]:02x}\n")

    # ── Write goldenX.dat ─────────────────────────────────────────────────────
    golden_path = os.path.join(out_dir, f"golden{index+2}.dat")
    with open(golden_path, "w") as f:
        for r in range(IMG_H):
            for c in range(IMG_W):
                f.write(f"{lbp[r, c]:02x}\n")

    print(f"  [Test {index}] {pattern_path}  {golden_path}")


def main():
    num_tests = 1
    if len(sys.argv) > 1:
        try:
            num_tests = int(sys.argv[1])
            if num_tests < 1:
                raise ValueError
        except ValueError:
            print("Usage: python gen_testdata.py [num_tests]")
            sys.exit(1)

    out_dir = "."
    print(f"Generating {num_tests} test(s) in '{os.path.abspath(out_dir)}'")
    for i in range(num_tests):
        generate_test(i, out_dir)
    print("Done.")


if __name__ == "__main__":
    main()