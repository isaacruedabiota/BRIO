"""Generates the BRIO app icon (gradient arc) with Pillow.
   python generate_icon.py
"""
import math
import os
from PIL import Image, ImageDraw

SIZE = 1024
BG = (15, 15, 20, 255)          # #0F0F14
C0 = (27, 111, 208)             # #1B6FD0 (deep blue)
C1 = (127, 196, 255)            # #7FC4FF (light blue)
# Output path relative to this script (brio-backend/) → the Flutter app's icons.
OUT = os.path.join(os.path.dirname(__file__), "..", "brio", "assets", "icon")


def lerp(a, b, t):
    return int(a + (b - a) * t)


def draw_arc(img, r_frac, w_frac):
    """Draws the BRIO arc (270°, gap at bottom-right) with a gradient."""
    draw = ImageDraw.Draw(img)
    c = SIZE // 2
    r = int(SIZE * r_frac)
    width = int(SIZE * w_frac)
    bbox = [c - r, c - r, c + r, c + r]
    start, sweep, steps = 135, 270, 160
    for i in range(steps):
        t = i / (steps - 1)
        a0 = start + sweep * i / steps
        a1 = start + sweep * (i + 1) / steps + 0.6
        col = (lerp(C0[0], C1[0], t), lerp(C0[1], C1[1], t), lerp(C0[2], C1[2], t), 255)
        draw.arc(bbox, a0, a1, fill=col, width=width)
    # (no circles at the ends: the arc finishes clean, without "dots")


# 1) Full icon (rounded dark background + arc) — iOS and legacy Android.
icon = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
ImageDraw.Draw(icon).rounded_rectangle(
    [0, 0, SIZE - 1, SIZE - 1], radius=int(SIZE * 0.23), fill=BG)
draw_arc(icon, r_frac=0.30, w_frac=0.155)
os.makedirs(OUT, exist_ok=True)
icon.save(os.path.join(OUT, "brio_icon.png"))

# 2) Adaptive foreground (transparent, smaller arc within the safe zone).
fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw_arc(fg, r_frac=0.20, w_frac=0.10)
fg.save(os.path.join(OUT, "brio_foreground.png"))

print("Iconos generados en", OUT)
