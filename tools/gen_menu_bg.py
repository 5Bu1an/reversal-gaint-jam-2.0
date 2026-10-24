#!/usr/bin/env python3
"""Generates the title-screen background as pixel art: a future Japanese town
at dusk under a giant golden tree, with sakura, pagodas, neon towers, a torii
and a still canal reflecting it all.

Writes four 640x360 layers to assets/ui/menu/ so the title screen can drift
them for parallax: sky.png, far.png (mountain + golden tree), city.png and
near.png (sakura, torii, canal). Deterministic; rerun to regenerate.

    python3 tools/gen_menu_bg.py [--preview out.png]
"""
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

W, H = 640, 360
HORIZON = 238
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "ui", "menu")
rng = random.Random(794)

BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0


def hexc(h, a=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(len(a)))


def dither_gradient(stops, height, width=W):
    """Vertical gradient through colour stops, ordered-dithered between bands."""
    img = np.zeros((height, width, 4), np.uint8)
    for y in range(height):
        t = y / max(height - 1, 1)
        for i in range(len(stops) - 1):
            if stops[i][0] <= t <= stops[i + 1][0]:
                k = (t - stops[i][0]) / (stops[i + 1][0] - stops[i][0])
                a, b = stops[i][1], stops[i + 1][1]
                break
        steps = 6
        band = k * steps
        lo, frac = int(band), band - int(band)
        c0 = lerp(a, b, lo / steps)
        c1 = lerp(a, b, min(lo + 1, steps) / steps)
        row = BAYER[y % 4][np.arange(width) % 4] < frac
        img[y, :, :] = np.where(row[:, None], c1, c0)
    return Image.fromarray(img, "RGBA")


def blob(d, cx, cy, r, color):
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color)


# ---------- sky ----------

def sky():
    img = dither_gradient([
        (0.0, hexc("#0b0820")), (0.35, hexc("#2a1240")), (0.62, hexc("#6b1f4f")),
        (0.8, hexc("#c4553f")), (1.0, hexc("#f2a65a"))], HORIZON + 4)
    full = Image.new("RGBA", (W, H), hexc("#f2a65a"))
    full.paste(img, (0, 0))
    d = ImageDraw.Draw(full)
    for i in range(140):
        x, y = rng.randrange(W), rng.randrange(int(HORIZON * 0.55))
        c = hexc("#ffffff", rng.choice([90, 140, 220]))
        d.point((x, y), fill=c)
        if rng.random() < 0.08:
            d.point([(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)], fill=hexc("#ffffff", 80))
    # Pale moon with a soft halo.
    mx, my = 120, 54
    for r, a in ((22, 14), (16, 26), (12, 40)):
        blob(d, mx, my, r, hexc("#ffe9d0", a))
    blob(d, mx, my, 9, hexc("#fff4e6"))
    blob(d, mx + 3, my - 2, 7, hexc("#ffdcc0"))
    # Long dusk cloud bands.
    for i in range(9):
        y = rng.randrange(70, HORIZON - 40)
        x = rng.randrange(-100, W)
        length = rng.randrange(120, 300)
        shade = lerp(hexc("#3a1a4a"), hexc("#ff9a6a"), y / HORIZON)
        for k in range(3):
            d.rectangle([x + k * 6, y + k, x + length - k * 10, y + k], fill=shade[:3] + (200 - k * 50,))
    return full


# ---------- far: mountain and golden tree ----------

def radial_glow(img, cx, cy, rx, ry, color, max_alpha):
    """Soft elliptical glow composited onto img."""
    ys, xs = np.mgrid[0:H, 0:W]
    dist = np.sqrt(((xs - cx) / rx) ** 2 + ((ys - cy) / ry) ** 2)
    alpha = np.clip(1.0 - dist, 0.0, 1.0) ** 2 * max_alpha
    layer = np.zeros((H, W, 4), np.uint8)
    layer[..., 0], layer[..., 1], layer[..., 2] = color[0], color[1], color[2]
    layer[..., 3] = alpha.astype(np.uint8)
    img.alpha_composite(Image.fromarray(layer, "RGBA"))


def golden_tree(d, img, cx, base_y):
    """An immense luminous tree on the horizon, Erdtree-like: a slender
    braided trunk rising into a vast, finely clustered golden canopy that
    glows and sheds motes of light."""
    deep, amber, gold, pale = hexc("#a8561f"), hexc("#e0902c"), hexc("#ffc94d"), hexc("#fff1b0")
    canopy_cy = base_y - 168
    radial_glow(img, cx, canopy_cy + 10, 260, 190, hexc("#ffb43c"), 150)
    radial_glow(img, cx, canopy_cy + 10, 150, 100, hexc("#ffd36a"), 120)
    radial_glow(img, cx, base_y - 60, 80, 130, hexc("#ffd36a"), 90)
    # Trunk: strands spiralling tightly around each other, flaring at the roots.
    for s in range(6):
        pts = []
        for i in range(48):
            t = i / 47
            y = base_y - t * 165
            radius = 10 * (1 - t) ** 1.5 + 3
            x = cx + math.sin(t * 9 + s * math.tau / 6) * radius
            pts.append((x, y))
        d.line(pts, fill=deep, width=3)
    for s in range(6):
        pts = [(cx + math.sin(i / 47 * 9 + s * math.tau / 6) * (10 * (1 - i / 47) ** 1.5 + 3), base_y - i / 47 * 165) for i in range(48)]
        d.line(pts[::2], fill=gold, width=1)
    for s in range(11):
        dx = (s - 5) * 14
        d.line([(cx, base_y - 8), (cx + dx * 0.6, base_y - 3), (cx + dx * 1.5, base_y + 1)], fill=amber, width=1)
    # Canopy: hundreds of small leaf clusters in a broad dome, shaded from a
    # deep amber underside to pale highlights on top.
    # Solid crown first so no sky shows through, then leaf clusters on top.
    crown = []
    for i in range(41):
        u = i / 40 * 2 - 1
        crown.append((cx + u * 150, canopy_cy + 36 + abs(u) ** 2 * 18 - (1 - abs(u) ** 2) * 4))
    for i in range(41):
        u = 1 - i / 40 * 2
        crown.append((cx + u * 140, canopy_cy - 30 - (1 - abs(u) ** 1.6) * 44 + rng.uniform(-4, 4)))
    d.polygon(crown, fill=deep)
    clusters = []
    for i in range(1600):
        u = rng.uniform(-1, 1)
        v = rng.uniform(0, 1) ** 0.8
        top = canopy_cy - 30 - (1 - abs(u) ** 1.6) * 44
        bottom = canopy_cy + 36 + abs(u) ** 2 * 18
        px = cx + u * 145
        py = bottom - v * (bottom - top)
        clusters.append((px, py, rng.uniform(2.5, 6.5), v))
    clusters.sort(key=lambda c: c[3])
    for px, py, r, v in clusters:
        blob(d, px, py + 2, r, deep)
    for px, py, r, v in clusters:
        blob(d, px, py, r * 0.85, amber if v < 0.45 else gold)
    for px, py, r, v in clusters:
        if v > 0.55 and rng.random() < 0.5:
            blob(d, px - 1, py - 1, max(1, r * 0.4), pale)
    # Hanging fronds of light under the canopy.
    for i in range(26):
        x = cx + rng.uniform(-130, 130)
        y = canopy_cy + 40 + abs(x - cx) ** 2 / 1100
        d.line([(x, y), (x + rng.uniform(-2, 2), y + rng.uniform(10, 30))], fill=gold[:3] + (150,), width=1)
    for i in range(160):
        x = cx + rng.gauss(0, 110)
        y = canopy_cy + rng.uniform(-60, 190)
        d.point((x, y), fill=pale[:3] + (rng.choice([120, 200, 255]),))


def far():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Distant ridge line.
    ridge = [(0, HORIZON)]
    for x in range(0, W + 20, 20):
        ridge.append((x, HORIZON - 22 - 10 * math.sin(x * 0.02) - rng.randrange(0, 8)))
    ridge.append((W, HORIZON))
    d.polygon(ridge, fill=hexc("#7a3550"))
    # A snow-capped volcanic peak, left of centre.
    px, py = 210, HORIZON - 120
    d.polygon([(px - 170, HORIZON), (px - 22, py + 8), (px, py), (px + 24, py + 8), (px + 180, HORIZON)], fill=hexc("#5a2a4a"))
    d.polygon([(px - 40, py + 26), (px - 22, py + 8), (px, py), (px + 24, py + 8), (px + 44, py + 28),
               (px + 26, py + 22), (px + 12, py + 34), (px - 4, py + 22), (px - 20, py + 32)], fill=hexc("#f5d6c8"))
    golden_tree(d, img, 448, HORIZON - 4)
    # Haze over the base.
    haze = dither_gradient([(0.0, hexc("#f2a65a", 0)), (1.0, hexc("#f2a65a", 150))], 40)
    img.alpha_composite(haze, (0, HORIZON - 40))
    return img


# ---------- city: pagodas and neon towers ----------

def pagoda(d, x, base, tiers, width, color, trim):
    y = base
    for t in range(tiers):
        w = width * (1 - t * 0.14)
        h = 16 - t
        d.rectangle([x - w * 0.32, y - h, x + w * 0.32, y], fill=color)
        for i in range(2, int(w * 0.6), 6):
            d.point((x - w * 0.3 + i, y - h + 5), fill=hexc("#ffb36b"))
        y -= h
        # Curved eaves with upturned tips.
        d.polygon([(x - w * 0.62, y + 2), (x - w * 0.5, y - 1), (x + w * 0.5, y - 1), (x + w * 0.62, y + 2),
                   (x + w * 0.4, y - 5), (x - w * 0.4, y - 5)], fill=trim)
        y -= 5
    d.line([(x, y), (x, y - 14)], fill=trim, width=1)
    d.point((x, y - 15), fill=hexc("#ff4d6d"))


def tower(d, x, base, w, h, color, neon):
    d.rectangle([x, base - h, x + w, base], fill=color)
    for wy in range(base - h + 4, base - 2, 5):
        for wx in range(x + 2, x + w - 2, 3):
            if rng.random() < 0.45:
                d.point((wx, wy), fill=rng.choice([hexc("#ffd28a"), hexc("#8fe9ff"), hexc("#ff7aa8")]))
    if rng.random() < 0.7:
        sy = base - h + rng.randrange(6, max(8, h // 2))
        sx = x + (w if rng.random() < 0.5 else -4)
        d.rectangle([sx, sy, sx + 3, sy + rng.randrange(10, 22)], fill=neon)
    d.line([(x + w // 2, base - h), (x + w // 2, base - h - rng.randrange(4, 14))], fill=color)


def city():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    base = HORIZON + 4
    dark, mid = hexc("#2a1636"), hexc("#3b1d45")
    for i in range(46):
        x = rng.randrange(-10, W)
        w = rng.randrange(8, 22)
        h = rng.randrange(24, 90)
        tower(d, x, base, w, h, dark if i % 2 else mid, rng.choice([hexc("#ff3d8b"), hexc("#30e8ff"), hexc("#ffcf5a")]))
    for x, tiers in ((70, 5), (300, 4), (560, 6)):
        pagoda(d, x, base, tiers, 46, hexc("#1d0f26"), hexc("#14091b"))
    # Holographic billboards.
    for x, y, c in ((150, 170, "#30e8ff"), (380, 160, "#ff3d8b"), (610, 175, "#30e8ff")):
        d.rectangle([x, y, x + 26, y + 12], fill=hexc(c, 70))
        d.rectangle([x, y, x + 26, y + 12], outline=hexc(c, 220))
        for k in range(3):
            d.line([(x + 4, y + 3 + k * 3), (x + 4 + rng.randrange(8, 18), y + 3 + k * 3)], fill=hexc(c, 230))
    d.rectangle([0, base, W, base + 2], fill=hexc("#14091b"))
    return img


# ---------- near: sakura, torii, canal ----------

def branch(d, x, y, ang, length, width, depth, tips):
    x2 = x + math.cos(ang) * length
    y2 = y + math.sin(ang) * length
    d.line([(x, y), (x2, y2)], fill=hexc("#1a0c14"), width=max(1, int(width)))
    if depth == 0:
        tips.append((x2, y2))
        return
    for k in (-1, 1):
        branch(d, x2, y2, ang + k * rng.uniform(0.25, 0.65), length * rng.uniform(0.62, 0.8), width * 0.68, depth - 1, tips)


def sakura(img, x, base, size, flip=1):
    d = ImageDraw.Draw(img)
    tips = []
    branch(d, x, base, -math.pi / 2 + flip * 0.12, size, size * 0.18, 5, tips)
    petals = [hexc("#ff9ec4"), hexc("#ffc2d9"), hexc("#ff7aae"), hexc("#ffe0ec")]
    for tx, ty in tips:
        for k in range(5):
            r = rng.randrange(4, 9)
            blob(d, tx + rng.randrange(-8, 8), ty + rng.randrange(-6, 6), r, petals[2])
    for tx, ty in tips:
        for k in range(4):
            r = rng.randrange(3, 7)
            blob(d, tx + rng.randrange(-8, 8), ty + rng.randrange(-8, 4), r, petals[0])
    for tx, ty in tips[::2]:
        blob(d, tx + rng.randrange(-5, 5), ty - rng.randrange(2, 7), rng.randrange(2, 4), petals[3])


def torii(d, x, base, h, w):
    red, dark = hexc("#d8243f"), hexc("#7a0f22")
    for px in (x - w // 2, x + w // 2 - 6):
        d.rectangle([px, base - h, px + 6, base], fill=red)
        d.rectangle([px + 4, base - h, px + 6, base], fill=dark)
    d.polygon([(x - w // 2 - 16, base - h - 4), (x + w // 2 + 16, base - h - 4), (x + w // 2 + 10, base - h + 4),
               (x - w // 2 - 10, base - h + 4)], fill=red)
    d.rectangle([x - w // 2 - 16, base - h - 7, x + w // 2 + 16, base - h - 4], fill=hexc("#1a0c14"))
    d.rectangle([x - w // 2 - 2, base - h + 16, x + w // 2 + 2, base - h + 21], fill=red)


def stone_lantern(d, x, base):
    stone = hexc("#2b1e2c")
    d.rectangle([x - 2, base - 22, x + 2, base], fill=stone)
    d.rectangle([x - 6, base - 30, x + 6, base - 22], fill=stone)
    d.rectangle([x - 3, base - 28, x + 3, base - 24], fill=hexc("#ffcf5a"))
    d.polygon([(x - 9, base - 30), (x + 9, base - 30), (x, base - 37)], fill=stone)
    for r, a in ((12, 25), (7, 45)):
        blob(d, x, base - 26, r, hexc("#ffcf5a", a))


def near(sky_img, far_img, city_img):
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    # Canal: reflection of everything above, darkened and rippled.
    above = sky_img.copy()
    above.alpha_composite(far_img)
    above.alpha_composite(city_img)
    water_top = HORIZON + 6
    refl = above.crop((0, water_top - (H - water_top), W, water_top)).transpose(Image.FLIP_TOP_BOTTOM)
    arr = np.array(refl).astype(np.float32)
    for y in range(arr.shape[0]):
        shift = int(round(math.sin(y * 0.9) * (1 + y * 0.03)))
        arr[y] = np.roll(arr[y], shift, axis=0)
        arr[y, :, :3] *= 0.55 - y * 0.002
    arr[:, :, 3] = 255
    img.paste(Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA"), (0, water_top))
    d = ImageDraw.Draw(img)
    for i in range(60):
        y = rng.randrange(water_top + 2, H)
        x = rng.randrange(W)
        d.line([(x, y), (x + rng.randrange(6, 24), y)], fill=hexc("#ffd8a8", rng.choice([40, 70, 110])))
    # Stone embankment.
    d.rectangle([0, water_top - 4, W, water_top + 1], fill=hexc("#1a0c14"))
    for x in range(0, W, 14):
        d.line([(x, water_top - 4), (x, water_top + 1)], fill=hexc("#2b1e2c"))
    # Foreground: torii on the right, sakura framing both sides, lanterns.
    torii(d, 548, water_top - 3, 78, 70)
    stone_lantern(d, 470, water_top - 3)
    stone_lantern(d, 140, water_top - 3)
    sakura(img, 26, water_top - 2, 58, 1)
    sakura(img, 618, water_top - 2, 52, -1)
    # Drifting petals on the water.
    for i in range(70):
        d.point((rng.randrange(W), rng.randrange(water_top + 1, H)), fill=hexc("#ff9ec4", rng.choice([120, 200])))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    s, f, c = sky(), far(), city()
    n = near(s, f, c)
    for name, layer in (("sky", s), ("far", f), ("city", c), ("near", n)):
        layer.save(os.path.join(OUT, name + ".png"))
    print("wrote", OUT)
    if "--preview" in sys.argv:
        comp = s.copy()
        for layer in (f, c, n):
            comp.alpha_composite(layer)
        comp.resize((W * 2, H * 2), Image.NEAREST).save(sys.argv[sys.argv.index("--preview") + 1])


if __name__ == "__main__":
    main()
