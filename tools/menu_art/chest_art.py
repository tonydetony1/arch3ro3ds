"""Pixel-art treasure chest (same grid format as the game sprites: one char per pixel).

Chars: L/l/d wood light/mid/dark, H/B/b band highlight/main/shade, R rivet,
Y/y lock light/dark, h keyhole, s shadow under the lid rim, g/G gem glow (obsidian).
"""
from PIL import Image

W, H = 30, 26
LID_INSET = [5, 3, 2, 1, 1, 0, 0, 0, 0]  # dome, rows 0-8
BAND_X = (4, 25)                         # left edge of each vertical band (3 px wide)


def grid(gems=False):
    top = 6 if gems else 0          # room for the crystals above the lid
    g = [["." for _ in range(W)] for _ in range(H + top)]
    def put(x, y, c):
        if 0 <= x < W and 0 <= y < H:
            g[y + top][x] = c
    def get(x, y):
        return g[y + top][x]
    for y in range(H):
        inset = LID_INSET[y] if y < len(LID_INSET) else 0
        for x in range(inset, W - inset):
            if y <= 1:
                c = "T"                    # lit top face of the lid
            elif x <= inset + 1:
                c = "L"
            elif x >= W - inset - 3:
                c = "d"
            else:
                c = "l"
            if y in (4, 7, 16, 21) and c != "T":
                c = "d" if c != "L" else "l"
            put(x, y, c)
    for x in range(W):
        put(x, 9, "H"); put(x, 10, "B"); put(x, 11, "s"); put(x, 24, "B"); put(x, 25, "b")
    for bx in BAND_X:
        for y in range(H):
            if get(bx, y) == ".":
                continue
            put(bx, y, "H"); put(bx + 1, y, "B"); put(bx + 2, y, "b")
        for y in (3, 6, 14, 19):
            put(bx + 1, y, "R")
    # reinforced bottom corners
    for x0 in (0, W - 4):
        for y in range(20, 24):
            for x in range(x0, x0 + 4):
                put(x, y, "H" if (y == 20 or x == x0) else "B")
    # lock plate with a classic keyhole
    for y in range(8, 17):
        for x in range(11, 19):
            corner = (x in (11, 18)) and (y in (8, 16))
            if corner:
                continue
            edge = x in (11, 18) or y in (8, 16)
            put(x, y, "y" if edge else "Y")
    put(12, 9, "H")
    for x, y in ((14, 10), (15, 10), (13, 11), (14, 11), (15, 11), (16, 11), (14, 12), (15, 12), (14, 13), (15, 13), (14, 14), (15, 14)):
        put(x, y, "h")
    if gems:
        for x, y in ((14, 10), (15, 10), (13, 11), (14, 11), (15, 11), (16, 11), (14, 12), (15, 12), (14, 13), (15, 13), (14, 14), (15, 14)):
            put(x, y, "G")
        put(14, 11, "g"); put(14, 10, "g")
        # faceted crystal shards growing out of the lid (light, mid and dark faces)
        small = ["..g..", ".gGG.", "ggGGb", "gGGGb", "gGGbb", ".GGb."]
        big = ["...g...", "..gGG..", "..gGG..", ".ggGGb.", ".gGGGb.", "ggGGGbb", "gGGGbbb", ".GGGbb.", "..Gbb.."]
        for shape, x0, y0 in ((small, 5, -3), (small, 20, -3), (big, 11, -6)):
            for dy, row in enumerate(shape):
                for dx, c in enumerate(row):
                    if c != ".":
                        g[y0 + dy + top][x0 + dx] = c
    return ["".join(r) for r in g]


PAL_GOLD = {
    "T": "e4a672", "L": "b86f50", "l": "8f563b", "d": "5d3a2b", "H": "fee761", "B": "feae34", "b": "f77622",
    "R": "ffffff", "Y": "fee761", "y": "feae34", "h": "181425", "s": "3e2731",
}
PAL_OBSIDIAN = {
    "T": "b55088", "L": "68386c", "l": "45284c", "d": "2a1d33", "H": "f6757a", "B": "b55088", "b": "68386c",
    "R": "ffffff", "Y": "c0cbdc", "y": "8b9bb4", "h": "181425", "s": "181425", "G": "73ffa6", "g": "ffffff",
}
PAL_OBSIDIAN.update({"T": "68386c", "g": "ffffff", "G": "f6757a", "b": "b55088", "Y": "c0cbdc", "y": "5a6988"})


def image(rows, pal, scale=1, outline="181425"):
    h, w = len(rows), len(rows[0])
    im = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    px = im.load()
    def rgb(hx):
        return tuple(int(hx[i:i + 2], 16) for i in (0, 2, 4)) + (255,)
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c in pal:
                px[x + 1, y + 1] = rgb(pal[c])
    filled = {(x, y) for y in range(h + 2) for x in range(w + 2) if px[x, y][3]}
    for (x, y) in list(filled):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            p = (x + dx, y + dy)
            if 0 <= p[0] < w + 2 and 0 <= p[1] < h + 2 and p not in filled:
                px[p] = rgb(outline)
    if scale != 1:
        im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
    return im


def gold(scale=1):
    return image(grid(False), PAL_GOLD, scale)


def obsidian(scale=1):
    return image(grid(True), PAL_OBSIDIAN, scale)
