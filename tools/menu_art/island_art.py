"""Floating island platform for the menu hero, one look per world (grid format like game sprites).

Chars: g/G/e top surface light/mid/front lip, b hanging blades, r/R/d rock light/mid/dark,
s strata, c crack, p/P/q dais top/rim/front, a/A rune ring glow, x/X/y world extras.
"""
import math, random
from PIL import Image

W, H = 120, 52
CX, TOP_RY, TOP_CY = 60, 9, 9


def _top_half_width(y):
    dy = (y - TOP_CY) / TOP_RY
    return 0 if abs(dy) > 1 else (W / 2 - 2) * math.sqrt(1 - dy * dy)


def grid(world, seed=4):
    rnd = random.Random(seed)
    g = [["." for _ in range(W)] for _ in range(H)]

    def put(x, y, c):
        if 0 <= x < W and 0 <= y < H:
            g[y][x] = c

    # underside: rounded belly that narrows into a rocky tip; each side has its own bumps
    def walk(n):
        v, out = 0, []
        for _ in range(n):
            v = max(-3, min(3, v + rnd.choice((-1, 0, 0, 1))))
            out.append(v)
        return out
    nl, nr = walk(H), walk(H)
    bottom = H - 6
    span = bottom - TOP_CY
    for y in range(TOP_CY, bottom):
        f = (y - TOP_CY) / span
        prof = 1 - f ** 2.4                          # stays wide, then tapers
        prof *= 1 - 0.10 * math.sin(f * math.pi * 3) # two soft lobes
        half = (W / 2 - 2) * prof
        lft = int(CX - half + nl[y] * (1 - f * 0.5))
        rgt = int(CX + half + nr[y] * (1 - f * 0.5))
        if rgt - lft < 2:
            lft, rgt = CX - 1, CX + 1
        for x in range(lft, rgt + 1):
            rel = (x - lft) / max(1, rgt - lft)
            c = "r" if rel < 0.2 else ("d" if rel > 0.7 else "R")
            put(x, y, c)
    # soil band right under the lip, then broken strata
    for y in range(TOP_CY + TOP_RY + 1, TOP_CY + TOP_RY + 4):
        for x in range(W):
            if g[y][x] in "rRd":
                put(x, y, "s")
    for _ in range(14):
        y = rnd.randint(TOP_CY + 16, bottom - 8)
        x = rnd.randint(20, 90)
        for i in range(rnd.randint(5, 14)):
            if g[y][x + i] in "rR":
                put(x + i, y, "d")
    # cracks
    for _ in range(7):
        x, y = rnd.randint(30, 90), rnd.randint(TOP_CY + 6, bottom - 10)
        for i in range(rnd.randint(3, 6)):
            if g[y][x] in "rRs":
                put(x, y, "c")
            x += rnd.choice((-1, 0, 1)); y += 1

    # top surface ellipse (seen from above) with a darker front lip
    for y in range(0, TOP_CY + TOP_RY + 1):
        hw = _top_half_width(y)
        for x in range(int(CX - hw), int(CX + hw) + 1):
            front = y >= TOP_CY + TOP_RY - 2
            back = y <= 2
            put(x, y, "e" if front else ("g" if back or (x - CX) < -hw * 0.4 else "G"))
    # surface texture: tufts and pebbles (kept off the dais in the middle)
    for _ in range(70):
        x, y = rnd.randint(6, W - 7), rnd.randint(1, TOP_CY + TOP_RY - 3)
        if g[y][x] in "gG" and abs(x - CX) > 24:
            put(x, y, "e" if rnd.random() < 0.5 else "g")
    # blades / sand / snow hanging over the lip
    for x in range(4, W - 4, 2):
        hw_y = TOP_CY + TOP_RY
        if g[hw_y][x] == "e" and rnd.random() < 0.55:
            for i in range(rnd.randint(1, 3)):
                put(x, hw_y + 1 + i, "b")

    # world-specific hanging details
    hangs = {"roots": "x", "crystals": "x", "lava": "x", "clouds": "x", "runes": "x", "sand": "x"}
    kind = world["hang"]
    for _ in range(9 if kind != "clouds" else 0):
        x = rnd.randint(28, 92)
        y0 = None
        for y in range(H - 1, 0, -1):
            if g[y][x] in "rRdsc":
                y0 = y; break
        if y0 is None:
            continue
        if kind == "roots":
            ln = rnd.randint(3, 9)
            for i in range(ln):
                put(x + (1 if i > ln // 2 and rnd.random() < 0.3 else 0), y0 + 1 + i, "x")
        elif kind == "crystals":
            ln = rnd.randint(4, 8)
            for i in range(ln):
                ww = max(0, (ln - i) // 3)
                for dx in range(-ww, ww + 1):
                    put(x + dx, y0 + 1 + i, "X" if dx < 0 else "x")
        elif kind == "lava":
            ln = rnd.randint(2, 7)
            for i in range(ln):
                put(x, y0 + 1 + i, "x" if i < ln - 1 else "X")
        elif kind == "sand":
            for i in range(rnd.randint(4, 10)):
                if rnd.random() < 0.7:
                    put(x + rnd.choice((-1, 0, 0, 1)), y0 + 1 + i, "x")
        elif kind == "runes":
            put(x, y0 + 3, "X"); put(x, y0 + 5, "x")
    if kind == "lava":   # glowing veins in the rock
        for _ in range(5):
            x, y = rnd.randint(34, 86), rnd.randint(TOP_CY + 8, bottom - 8)
            for i in range(rnd.randint(4, 8)):
                if g[y][x] in "rRsd":
                    put(x, y, "X")
                x += rnd.choice((-1, 1)); y += rnd.choice((0, 1))
    if kind == "runes":
        for x, y in ((48, 20), (60, 26), (72, 21), (60, 15)):
            for dx, dy in ((0, 0), (1, 0), (0, 1), (-1, 0), (0, -1)):
                if g[y + dy][x + dx] in "rRsd":
                    put(x + dx, y + dy, "x")
    if kind == "clouds":
        for cx, cy, r in ((40, 30, 7), (56, 34, 8), (74, 31, 7), (86, 27, 5), (30, 26, 5)):
            for y in range(cy - r, cy + r):
                for x in range(cx - 2 * r, cx + 2 * r):
                    if ((x - cx) / (2 * r)) ** 2 + ((y - cy) / r) ** 2 <= 1:
                        put(x, y, "X" if y > cy + r // 3 else "x")

    # stone dais for the hero, with a glowing rune ring on its top face
    dcx, dcy, drx, dry = CX, 5, 20, 4
    for y in range(dcy - dry - 1, dcy + dry + 5):
        for x in range(dcx - drx - 1, dcx + drx + 2):
            nx = (x - dcx) / drx
            top_y = dcy + dry * math.sqrt(max(0, 1 - nx * nx)) if abs(nx) <= 1 else None
            if top_y is None:
                continue
            ell = ((x - dcx) / drx) ** 2 + ((y - dcy) / dry) ** 2
            if ell <= 1:
                put(x, y, "p" if ell < 0.55 else "P")
            elif top_y < y <= top_y + 5:
                put(x, y, "P" if (x - dcx) % 8 == 0 else "q")
    for i in range(64):
        a = i / 64 * math.pi * 2
        x, y = round(dcx + math.cos(a) * 13), round(dcy + math.sin(a) * 2.6)
        put(x, y, "a" if math.sin(a) > -0.2 else "A")
    return ["".join(r) for r in g]


WORLDS = {
    "forest": dict(hang="roots", pal=dict(g="7ad14f", G="5dac4d", e="3e8948", b="3e8948", r="9c7a5a", R="7a5a44", d="4f3a30",
                                          s="5d4436", c="3e2731", p="c0cbdc", P="8b9bb4", q="5a6988", a="73ffa6", A="2ce8f5", x="733e39", X="5d3a2b")),
    "desert": dict(hang="sand", pal=dict(g="f2d9a6", G="e4c48c", e="c09a63", b="d6ac72", r="e0b07a", R="c88f55", d="96653c",
                                         s="b07a48", c="7a4f2f", p="ead4aa", P="c8a77a", q="96653c", a="feae34", A="f77622", x="e4c48c", X="c09a63")),
    "crystal": dict(hang="crystals", pal=dict(g="7a88c4", G="5a6aa8", e="3f4a7a", b="3f4a7a", r="5a6988", R="3f4a7a", d="232a4d",
                                              s="323a63", c="141a33", p="c0cbdc", P="8b9bb4", q="5a6988", a="2ce8f5", A="66d9ff", x="66d9ff", X="2ce8f5")),
    "inferno": dict(hang="lava", pal=dict(g="6b5a5a", G="5c4747", e="3a2e2e", b="241c1c", r="5c4747", R="4a3b3b", d="2a1f1f",
                                          s="3a2e2e", c="181425", p="8b9bb4", P="5a6988", q="3a4466", a="feae34", A="f77622", x="f77622", X="feae34")),
    "sky": dict(hang="clouds", pal=dict(g="ffffff", G="dfe8f5", e="c0cbdc", b="dfe8f5", r="c0cbdc", R="8b9bb4", d="5a6988",
                                        s="a8b4c8", c="5a6988", p="ffffff", P="dfe8f5", q="8b9bb4", a="fee761", A="feae34", x="ffffff", X="dfe8f5")),
    "void": dict(hang="runes", pal=dict(g="5c3f7a", G="3d2c57", e="2a1f3d", b="2a1f3d", r="3d2c57", R="2a1f3d", d="1a1229",
                                        s="241a36", c="0f0a18", p="68386c", P="45284c", q="2a1d33", a="f6757a", A="b55088", x="f6757a", X="b55088")),
}


def image(world, scale=2, outline="181425"):
    w = WORLDS[world]
    rows = grid(w)
    pal = w["pal"]
    h, wd = len(rows), len(rows[0])
    im = Image.new("RGBA", (wd + 2, h + 2), (0, 0, 0, 0))
    px = im.load()
    rgb = lambda hx: tuple(int(hx[i:i + 2], 16) for i in (0, 2, 4)) + (255,)
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c in pal:
                px[x + 1, y + 1] = rgb(pal[c])
    filled = {(x, y) for y in range(h + 2) for x in range(wd + 2) if px[x, y][3]}
    for (x, y) in list(filled):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            p = (x + dx, y + dy)
            if 0 <= p[0] < wd + 2 and 0 <= p[1] < h + 2 and p not in filled:
                px[p] = rgb(outline)
    return im.resize((im.width * scale, im.height * scale), Image.NEAREST)
