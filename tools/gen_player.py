#!/usr/bin/env python3
"""Generates the Cyber Ronin player sprite sheet.

A small pose rig drawn straight to pixels: legs, cloak, obi, sword arm, ivory
mask under a wide neon-rimmed kasa, and a trailing red scarf, then a 1 px dark
outline. Every animation is a list of poses, so tweaking a number here and
rerunning regenerates the whole sheet.

Writes assets/art/player/samurai.png (one row per animation, facing right)
and samurai.json (cell size, feet y, rows, frame counts, fps, loop). Poses
are authored in a 64x64 space and drawn natively at SCALE, so outlines stay
one crisp pixel.

    python3 tools/gen_player.py [--preview out.png]
"""
import json
import math
import os
import sys

from PIL import Image, ImageDraw

CELL = 64  # rig space; poses are authored in a 64x64 cell
GROUND = 60
SCALE = 1.4  # drawn natively at this size for more pixel detail
OUT = round(CELL * SCALE)
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "art", "player")

PAL = {
    "outline": (11, 11, 20),
    "cloak": (34, 30, 58), "cloak_hi": (58, 54, 96), "cloak_lo": (22, 19, 38),
    "lining": (192, 38, 58), "lining_hi": (255, 77, 94),
    "leg": (24, 22, 40), "foot": (40, 36, 62),
    "obi": (245, 197, 66), "obi_lo": (185, 138, 42),
    "mask": (232, 220, 192), "mask_lo": (185, 169, 138),
    "eye": (11, 11, 20), "stripe": (220, 40, 60),
    "hat": (43, 31, 26), "hat_hi": (84, 60, 46), "rim": (5, 217, 232),
    "blade": (216, 246, 255), "edge": (5, 217, 232), "hilt": (58, 42, 32), "tsuba": (245, 197, 66),
    "arm": (44, 40, 70),
    "sheath": (26, 20, 36), "sheath_hi": (60, 46, 70),
    "smear": (240, 255, 255), "smear_rim": (5, 217, 232),
}


# ---------- geometry ----------

class ScaledDraw:
    """ImageDraw that maps rig coordinates (64x64 space) onto the SCALE canvas."""

    def __init__(self, draw):
        self.d = draw

    @staticmethod
    def _pts(points):
        return [(x * SCALE, y * SCALE) for x, y in points]

    def polygon(self, points, fill):
        self.d.polygon(self._pts(points), fill=fill)

    def line(self, points, fill, width=1):
        self.d.line(self._pts(points), fill=fill, width=max(1, round(width * SCALE)))

    def point(self, points, fill):
        for x, y in self._pts(points):
            self.d.rectangle([x, y, x + SCALE - 1, y + SCALE - 1], fill=fill)

    def rectangle(self, box, fill):
        if len(box) == 4:  # [x0, y0, x1, y1] rather than two corner points
            box = [box[:2], box[2:]]
        (x0, y0), (x1, y1) = self._pts(box)
        self.d.rectangle([min(x0, x1), min(y0, y1), max(x0, x1) + SCALE - 1, max(y0, y1) + SCALE - 1], fill=fill)


def rot(v, deg):
    a = math.radians(deg)
    return (v[0] * math.cos(a) - v[1] * math.sin(a), v[0] * math.sin(a) + v[1] * math.cos(a))


def add(a, b):
    return (a[0] + b[0], a[1] + b[1])


def polar(deg, r):
    a = math.radians(deg)
    return (math.cos(a) * r, math.sin(a) * r)


def quad(p0, p1, w0, w1):
    """Tapered limb from p0 (width w0) to p1 (width w1)."""
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    length = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / length, dx / length
    return [(p0[0] + nx * w0 / 2, p0[1] + ny * w0 / 2), (p1[0] + nx * w1 / 2, p1[1] + ny * w1 / 2),
            (p1[0] - nx * w1 / 2, p1[1] - ny * w1 / 2), (p0[0] - nx * w0 / 2, p0[1] - ny * w0 / 2)]


# ---------- the rig ----------

DEFAULT = {
    "bob": 0, "lean": 0, "legs": ((-3, 0), (3, 0)), "flare": 0.2, "hem_lift": 0, "scarf": 0.0,
    "scarf_lift": 0.0, "sword": 115, "arm": 100, "hat_tilt": 0, "smear": None, "squash": 1.0,
    "sword_front": False, "crouch": 0, "drawn": False, "planted": False,
}


def draw_pose(pose, t):
    p = dict(DEFAULT)
    p.update(pose)
    img = Image.new("RGBA", (OUT, OUT), (0, 0, 0, 0))
    d = ScaledDraw(ImageDraw.Draw(img))
    sq = p["squash"]
    leg_len = 9 * sq - p["crouch"]
    hip = (32, GROUND - leg_len + p["bob"] * 0.5)
    lean = p["lean"]

    def body(v):  # body-space offset -> pixel, leaning around the hip
        return add(hip, rot((v[0], v[1] * sq), lean))

    neck = body((1, -10 + p["bob"] * 0.5))
    head = body((1.5, -16 + p["bob"]))
    shoulder = body((2, -8 + p["bob"] * 0.5))

    # Scarf trails behind the neck, waving.
    _scarf(d, neck, p, t)

    # Legs mostly hide under the coat; feet poke out.
    (bx, by), (fx, fy) = p["legs"]
    _leg(d, add(hip, (-1.5, 0)), (32 + bx, GROUND - by))
    _leg(d, add(hip, (1.5, 0)), (32 + fx, GROUND - fy))

    flare, lift = p["flare"], p["hem_lift"]
    swing = math.sin(t * math.tau + p["scarf"]) * 1.2
    # Ragged back hem that flares out and lifts with motion.
    hem = [body((6, 6 - lift * 0.3)), body((3, 7.5 - lift * 0.4)), body((0, 7 - lift * 0.5)),
           body((-3 + swing * 0.3, 8 - lift * 0.7)), body((-5 - flare * 4 + swing, 6.5 - lift)),
           body((-6 - flare * 7 + swing, 7 - lift * 1.3)), body((-7 - flare * 8 + swing, 3 - lift * 1.2))]
    if flare > 0.3:
        d.polygon([body((-3, -8)), hem[4], hem[5], hem[6], body((-6, -3))], fill=PAL["lining"])
        d.line([hem[5], hem[6]], fill=PAL["lining_hi"])
    if not p["sword_front"] and p["drawn"]:
        _sword_arm(d, shoulder, p)
    cloak = [body((-4, -10)), body((4, -10)), body((5.5, -2))] + hem + [body((-6, -3))]
    d.polygon(cloak, fill=PAL["cloak"])
    d.polygon([body((1, -10)), body((4, -10)), body((5.5, -2)), body((6, 6)), body((3, 7)), body((2, -2))], fill=PAL["cloak_hi"])
    d.line([body((-1, 0)), body((0, 6))], fill=PAL["cloak_lo"])
    # Obi sash and the sheathed katana at the hip.
    d.polygon([body((-4, -4)), body((5, -4)), body((5, -2)), body((-4, -2))], fill=PAL["obi"])
    d.point([body((0, -2))], fill=PAL["obi_lo"])
    _sheath(d, body((-2, -3)), lean, p["drawn"] or p["planted"])

    if p["planted"]:
        _planted_sword(d)
    elif p["sword_front"]:
        _sword_arm(d, shoulder, p)

    _head(d, head, p)

    if p["smear"]:
        _smear(img, shoulder, p["smear"])

    return _outline(img)


def _leg(d, top, foot):
    d.polygon(quad(top, foot, 3, 2.5), fill=PAL["leg"])
    d.rectangle([foot[0] - 1, foot[1] - 1, foot[0] + 2, foot[1]], fill=PAL["foot"])


def _sheath(d, at, lean, empty):
    """Scabbard angled back-down from the obi; hilt forward unless drawn."""
    tip = add(at, polar(145 + lean, 12))
    d.line([at, tip], fill=PAL["sheath"], width=2)
    d.line([add(at, (0, -1)), add(tip, (0, -1))], fill=PAL["sheath_hi"], width=1)
    d.point([tip], fill=PAL["tsuba"])
    if not empty:
        grip = add(at, polar(-20 + lean, 6))
        d.line([at, grip], fill=PAL["hilt"], width=2)
        d.line([add(at, polar(70 + lean, 2)), add(at, polar(-110 + lean, 2))], fill=PAL["tsuba"])


def _planted_sword(d):
    """Katana stuck upright in the ground in front of a fallen ronin."""
    base = (41, GROUND + 1)
    top = (41, GROUND - 19)
    d.line([base, top], fill=PAL["blade"], width=2)
    d.line([(42, GROUND), (42, GROUND - 18)], fill=PAL["edge"])
    d.line([(39, GROUND - 19), (44, GROUND - 19)], fill=PAL["tsuba"])
    d.line([top, (41, GROUND - 24)], fill=PAL["hilt"], width=2)


def _sword_arm(d, shoulder, p):
    hand = add(shoulder, polar(p["arm"], 5))
    d.polygon(quad(shoulder, hand, 3, 2.5), fill=PAL["arm"])
    tip = add(hand, polar(p["sword"], 21))
    hilt_end = add(hand, polar(p["sword"], -3))
    guard = add(hand, polar(p["sword"], 2))
    d.line([hilt_end, guard], fill=PAL["hilt"], width=2)
    g0, g1 = add(guard, polar(p["sword"] + 90, 2)), add(guard, polar(p["sword"] - 90, 2))
    d.line([g0, g1], fill=PAL["tsuba"], width=1)
    d.line([guard, tip], fill=PAL["blade"], width=2)
    edge_off = polar(p["sword"] + 90, 1)
    d.line([add(guard, edge_off), add(tip, edge_off)], fill=PAL["edge"], width=1)


def _head(d, c, p):
    tilt = p["hat_tilt"]

    def h(v):
        return add(c, rot(v, tilt))

    # Ivory mask, eyes forward, red stripe.
    d.polygon([h((-5, -3)), h((6, -3)), h((6, 3)), h((4, 6)), h((-3, 6)), h((-5, 3))], fill=PAL["mask"])
    d.polygon([h((-5, 2)), h((-2, 2)), h((-2, 6)), h((-3, 6)), h((-5, 3))], fill=PAL["mask_lo"])
    for ex in (0, 3.5):
        d.rectangle([h((ex, -0.5)), h((ex + 1.5, 2.5))], fill=PAL["eye"])
        d.point([h((ex + 1, 0))], fill=PAL["rim"])
    d.line([h((4, 3.5)), h((5.5, 5))], fill=PAL["stripe"])
    # Kasa: wide lacquered cone with a neon rim along the brim.
    hat = [h((-13, -2)), h((13, -2)), h((11, -3.5)), h((3, -10)), h((-1, -10)), h((-11, -3.5))]
    d.polygon(hat, fill=PAL["hat"])
    d.polygon([h((1, -10)), h((3, -10)), h((10, -3.5)), h((6, -3.5))], fill=PAL["hat_hi"])
    d.line([h((-13, -2)), h((13, -2))], fill=PAL["rim"])


def _scarf(d, neck, p, t):
    lift = p["scarf_lift"]
    for strand, (length, width, phase) in enumerate(((13, 2, 0.0), (9, 1, 1.3))):
        points = []
        for i in range(7):
            u = i / 6
            x = -u * length
            y = u * (2 - lift * 6) + math.sin(t * math.tau + p["scarf"] + phase - u * 3) * 1.6 * u
            points.append(add(neck, (x, y + strand)))
        d.line(points, fill=PAL["lining"] if strand == 0 else PAL["lining_hi"], width=width)


def _smear(img, shoulder, smear):
    kind, progress, fade = smear
    start, span, r_out, r_in = {
        "side": (-115, 185, 24, 14),
        "up": (35, -200, 24, 14),
        "down": (-35, 210, 24, 14),
    }[kind]
    layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ScaledDraw(ImageDraw.Draw(layer))
    steps = 14
    end = span * progress
    outer, inner = [], []
    for i in range(steps + 1):
        u = i / steps
        a = start + end * u
        taper = math.sin(u * math.pi) ** 0.6
        outer.append(add(shoulder, polar(a, r_out)))
        inner.append(add(shoulder, polar(a, r_out - (r_out - r_in) * taper)))
    alpha = int(235 * (0.4 + 0.6 * fade))
    body_color = tuple(int(a + (b - a) * (1 - fade)) for a, b in zip(PAL["smear"], PAL["smear_rim"]))
    d.polygon(outer + inner[::-1], fill=body_color + (alpha,))
    d.line(outer, fill=PAL["smear_rim"] + (alpha,), width=1)
    img.alpha_composite(layer)


def _outline(img):
    """1 px dark outline around everything opaque (smears excluded by alpha)."""
    w, h = img.size
    px = img.load()
    solid = [[px[x, y][3] > 200 for x in range(w)] for y in range(h)]
    out = img.copy()
    o = out.load()
    for y in range(h):
        for x in range(w):
            if px[x, y][3] > 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and solid[ny][nx]:
                    o[x, y] = PAL["outline"] + (255,)
                    break
    return out


# ---------- animations ----------

def idle(n=6):
    frames = []
    for i in range(n):
        t = i / n
        breath = math.sin(t * math.tau)
        frames.append({"bob": round(breath * 0.8), "flare": 0.15 + 0.08 * breath, "scarf": 0.0,
                       "sword": 118 + 3 * breath, "arm": 100})
    return frames


def run(n=8):
    frames = []
    for i in range(n):
        t = i / n
        a = t * math.tau
        front = (round(5 * math.cos(a)), max(0, round(3 * math.sin(a))))
        back = (round(-5 * math.cos(a)), max(0, round(-3 * math.sin(a))))
        frames.append({"bob": -round(abs(math.sin(a)) * 1.5), "lean": 12, "legs": (back, front),
                       "flare": 0.7 + 0.15 * math.sin(a * 2), "scarf": a, "scarf_lift": 0.3,
                       "sword": 155, "arm": 120, "hat_tilt": -4})
    return frames


def jump():
    return [{"legs": ((-2, 4), (3, 5)), "flare": 0.3, "hem_lift": -1, "scarf_lift": -0.2, "sword": 130, "arm": 110, "lean": 4},
            {"legs": ((-2, 5), (2, 6)), "flare": 0.35, "hem_lift": 0, "scarf_lift": 0.0, "sword": 128, "arm": 108, "lean": 2}]


def fall():
    return [{"legs": ((-3, 1), (2, 0)), "flare": 0.8, "hem_lift": 3, "scarf_lift": 0.8, "sword": 120, "arm": 95, "hat_tilt": 3},
            {"legs": ((-3, 0), (2, -1)), "flare": 0.9, "hem_lift": 4, "scarf_lift": 1.0, "sword": 118, "arm": 92, "hat_tilt": 4}]


def land():
    return [{"squash": 0.75, "crouch": 1, "flare": 0.5, "legs": ((-5, 0), (5, 0)), "sword": 125, "hat_tilt": 2},
            {"squash": 0.9, "flare": 0.3, "legs": ((-4, 0), (4, 0)), "sword": 120}]


def dash():
    return [{"lean": 28, "flare": 1.0, "hem_lift": 2, "legs": ((-7, 2), (4, 1)), "scarf_lift": 0.9, "scarf": i * 1.5,
             "sword": 175, "arm": 150, "hat_tilt": -10} for i in range(3)]


def slash(kind):
    if kind == "side":
        swords = [(-150, -120, None), (-40, 10, ("side", 0.55, 1.0)), (35, 40, ("side", 1.0, 0.9)), (55, 60, ("side", 1.0, 0.35))]
        lean = [-6, 10, 14, 8]
    elif kind == "up":
        swords = [(70, 60, None), (-30, -40, ("up", 0.5, 1.0)), (-95, -80, ("up", 1.0, 0.9)), (-115, -95, ("up", 1.0, 0.35))]
        lean = [4, -4, -8, -4]
    else:
        swords = [(-110, -100, None), (20, 30, ("down", 0.5, 1.0)), (85, 80, ("down", 1.0, 0.9)), (105, 95, ("down", 1.0, 0.35))]
        lean = [-4, 8, 12, 6]
    air = kind == "down"
    frames = []
    for i, (sword, arm, smear) in enumerate(swords):
        frames.append({"sword": sword, "arm": arm, "smear": smear, "sword_front": True, "drawn": True, "lean": lean[i],
                       "flare": 0.4 + 0.15 * i, "scarf": i * 0.8,
                       "legs": ((-2, 4), (3, 5)) if air else ((-5, 0), (5, 0))})
    return frames


def hurt():
    return [{"lean": -18, "hat_tilt": -14, "flare": 0.6, "legs": ((-4, 1), (2, 2)), "sword": 150, "arm": 140, "scarf_lift": 0.5},
            {"lean": -10, "hat_tilt": -8, "flare": 0.4, "legs": ((-4, 0), (3, 0)), "sword": 140, "arm": 125}]


def dead():
    return [{"crouch": 4, "lean": 22, "hat_tilt": 18, "flare": 0.5, "legs": ((-5, 0), (4, 0)), "bob": 3, "planted": True, "scarf_lift": -0.4}]


ANIMS = [
    ("idle", idle(), 8, True),
    ("run", run(), 14, True),
    ("jump", jump(), 10, True),
    ("fall", fall(), 8, True),
    ("land", land(), 16, False),
    ("dash", dash(), 18, True),
    ("slash_side", slash("side"), 26, False),
    ("slash_up", slash("up"), 26, False),
    ("slash_down", slash("down"), 26, False),
    ("hurt", hurt(), 10, False),
    ("dead", dead(), 1, False),
]


def build():
    cols = max(len(frames) for _, frames, _, _ in ANIMS)
    sheet = Image.new("RGBA", (cols * OUT, len(ANIMS) * OUT), (0, 0, 0, 0))
    meta = {"cell": OUT, "feet_y": round(GROUND * SCALE), "anims": {}}
    for row, (name, frames, fps, loop) in enumerate(ANIMS):
        for col, pose in enumerate(frames):
            sheet.alpha_composite(draw_pose(pose, col / len(frames)), (col * OUT, row * OUT))
        meta["anims"][name] = {"row": row, "frames": len(frames), "fps": fps, "loop": loop}
    return sheet, meta


if __name__ == "__main__":
    os.makedirs(OUT_DIR, exist_ok=True)
    sheet, meta = build()
    sheet.save(os.path.join(OUT_DIR, "samurai.png"))
    with open(os.path.join(OUT_DIR, "samurai.json"), "w") as f:
        json.dump(meta, f, indent=1)
    print(f"samurai.png {sheet.size}, {sum(m['frames'] for m in meta['anims'].values())} frames")
    if "--preview" in sys.argv:
        out = sys.argv[sys.argv.index("--preview") + 1]
        bg = Image.new("RGBA", sheet.size, (40, 44, 70, 255))
        bg.alpha_composite(sheet)
        bg.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(out)
