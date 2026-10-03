#!/usr/bin/env python3
"""
tools/make_title_assets.py
Génère les textures de l'écran titre (src/states/splash.lua) à partir de l'illustration
officielle (assets/banner_hd.png) :

  assets/title_top.png    512x256 : décor de l'écran haut (426x256, titre effacé, vignette)
  assets/title_fx.png     256x256 : titre détouré, son halo, sprites de lueur / étincelle
  assets/title_bottom.png 512x256 : fond flouté de l'écran bas (320x240) et anneau runique
  assets/banner_home.png  256x128 : bannière du menu HOME (même visuel, lueurs figées)
  src/render/title_layout.lua     : rectangles des sprites, lumières et positions dans le décor

Le titre « ARCH3RO » est détaché du décor pour flotter devant l'écran en relief 3D :
il est découpé par sa teinte dorée, puis le ciel est reconstruit dessous (diffusion
et étoiles) pour qu'aucun fantôme n'apparaisse quand les deux yeux le décalent.

Le décor fait 426x256 (et non 400x240) : la marge absorbe le décalage stéréo et la lente
dérive de caméra sans montrer de bord, tout en restant affiché pixel pour pixel.
Les dimensions sont des puissances de deux : la conversion .t3x n'ajoute aucun padding.

Usage : python3 tools/make_title_assets.py
"""

import math
import os
import random

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "assets")
SRC = os.path.join(ASSETS, "banner_hd.png")
RUNIC_FONT = "/usr/share/fonts/noto/NotoSansRunic-Regular.ttf"

SCALE = 3                      # illustration 1278x768 -> décor 426x256
CROP = (49, 0, 49 + 426 * SCALE, 256 * SCALE)
BG_W, BG_H = 426, 256
TITLE_BOX = (352, 24, 1022, 214)   # zone du titre dans banner_hd.png (pixels source)

FX_W, FX_H = 256, 256
LETTERS_MAX = (224, 112)
HALO_Y = 112
HALO_PAD = 8

# Lumières posées sur l'illustration (pixels du décor 426x256), animées par splash.lua
MOON = (277, 15)
TORCHES = [(108, 155), (348, 145), (417, 95)]
ARROWS = [  # pointe des flèches enchantées : feu, or, vide
    (327, 90, (1.0, 0.45, 0.10)),
    (330, 115, (1.0, 0.85, 0.35)),
    (333, 146, (0.75, 0.30, 1.0)),
]
RUNES = [(27, 110), (27, 150), (50, 47), (110, 117), (347, 100), (410, 30), (360, 187)]
STARS = [(130, 86), (166, 76), (252, 82), (345, 62), (94, 74), (300, 10)]

random.seed(3)


def clamp(v, lo=0, hi=255):
    return lo if v < lo else hi if v > hi else v


# ---------------------------------------------------------------------------
# 1. Masque du titre (pleine résolution, puis réduit : bords lissés)
# ---------------------------------------------------------------------------
def title_mask(src):
    """Alpha du titre : lettres dorées, contour brun et une partie du halo orangé."""
    w, h = src.size
    mask = Image.new("L", (w, h), 0)
    px, mp = src.load(), mask.load()
    x0, y0, x1, y1 = TITLE_BOX
    for y in range(y0, y1):
        for x in range(x0, x1):
            r, g, b = px[x, y]
            warm = r - b
            # Or et brun : rouge nettement au-dessus du bleu ; le ciel nocturne est bleu
            a = (warm - 18) * 255 // 70
            # Contour sombre des lettres (brun foncé) : chaud mais peu lumineux
            if warm > 25 and r < 120:
                a = max(a, 255)
            mp[x, y] = clamp(a)
    # Bouche les trous du contour puis adoucit le bord
    mask = mask.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.MinFilter(3))
    mask = mask.filter(ImageFilter.GaussianBlur(1.6))
    # Fondu sur les bords de la zone : rien de découpé net dans le ciel
    fade = Image.new("L", (w, h), 0)
    fd = ImageDraw.Draw(fade)
    for i in range(10):
        v = int(255 * (i + 1) / 10)
        fd.rectangle((x0 + i, y0 + i, x1 - 1 - i, y1 - 1 - i), fill=v)
    return ImageChops.multiply(mask, fade)


# ---------------------------------------------------------------------------
# 2. Reconstruction du ciel sous le titre (diffusion grossière -> fine + étoiles)
# ---------------------------------------------------------------------------
def inpaint(img, hole):
    """Remplit les pixels où hole > 0 par diffusion depuis les bords (multi-échelle)."""
    w, h = img.size
    if w < 8 or h < 8:
        return img
    # Niveau grossier d'abord : le remplissage converge en quelques passes
    small = img.resize((w // 2, h // 2), Image.Resampling.BOX)
    small_hole = hole.resize((w // 2, h // 2), Image.Resampling.BOX).point(lambda v: 255 if v > 20 else 0)
    small = inpaint(small, small_hole)
    guess = small.resize((w, h), Image.Resampling.BILINEAR)
    out = Image.composite(guess, img, hole)

    px, hp = out.load(), hole.load()
    holes = [(x, y) for y in range(h) for x in range(w) if hp[x, y]]
    for _ in range(24):
        for x, y in holes:
            acc = [0, 0, 0]
            n = 0
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < w and 0 <= ny < h:
                    c = px[nx, ny]
                    acc[0] += c[0]
                    acc[1] += c[1]
                    acc[2] += c[2]
                    n += 1
            px[x, y] = (acc[0] // n, acc[1] // n, acc[2] // n)
    return out


def sprinkle_stars(img, hole, density):
    px, hp = img.load(), hole.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if hp[x, y] > 128 and random.random() < density:
                r, g, b = px[x, y]
                k = random.uniform(0.35, 1.0)
                px[x, y] = (clamp(int(r + (235 - r) * k)), clamp(int(g + (240 - g) * k)), clamp(int(b + (255 - b) * k)))
    return img


def vignette(img, strength, bottom_fade):
    """Assombrit les bords et le bas (lisibilité du message « APPUIE SUR A »)."""
    w, h = img.size
    shade = Image.new("L", (w, h), 0)
    sp = shade.load()
    for y in range(h):
        for x in range(w):
            dx = (x - w / 2) / (w / 2)
            dy = (y - h * 0.45) / (h / 2)
            d = math.sqrt(dx * dx * 0.8 + dy * dy)
            v = max(0.0, d - 0.55) / 0.75
            v = min(1.0, v) ** 1.6 * strength
            fy = (y - h * 0.80) / (h * 0.20)
            if fy > 0:
                v = max(v, min(1.0, fy) ** 1.4 * bottom_fade)
            sp[x, y] = int(v * 255)
    dark = Image.new("RGB", (w, h), (6, 8, 18))
    return Image.composite(dark, img, shade)


# ---------------------------------------------------------------------------
# 3. Sprites de lueur (blancs : teintés à l'exécution par setColor)
# ---------------------------------------------------------------------------
def glow_sprite(size, sigma):
    im = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    px = im.load()
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            d2 = (x - c) ** 2 + (y - c) ** 2
            a = math.exp(-d2 / (2 * sigma * sigma))
            # Bord ramené à zéro : aucun carré visible en fusion additive
            edge = max(0.0, 1.0 - math.sqrt(d2) / (c + 0.5))
            px[x, y] = (255, 255, 255, int(255 * a * min(1.0, edge * 3)))
    return im


def spark_sprite(size):
    """Étoile à quatre branches (scintillement des lettres et du ciel)."""
    im = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    px = im.load()
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            dx, dy = abs(x - c) / c, abs(y - c) / c
            ray = max(math.exp(-(dy * 14) ** 2) * (1 - dx) ** 2, math.exp(-(dx * 14) ** 2) * (1 - dy) ** 2)
            core = math.exp(-(dx * dx + dy * dy) * 30)
            px[x, y] = (255, 255, 255, int(255 * min(1.0, ray + core)))
    return im


# ---------------------------------------------------------------------------
# 4. Anneau runique (écran bas)
# ---------------------------------------------------------------------------
RUNE_GLYPHS = "ᚠᚢᚦᚨᚱᚲᚷᚹᚺᚾᛁᛃᛇᛈᛉᛊᛏᛒᛖᛗᛚᛜᛞᛟ"


def rune_ring(size):
    big = size * 4
    im = Image.new("L", (big, big), 0)
    d = ImageDraw.Draw(im)
    c = big / 2
    s = big / size

    def ring(r, width):
        d.ellipse((c - r, c - r, c + r, c + r), outline=255, width=int(width))

    ring(86 * s, 2.2 * s)
    ring(71 * s, 1.2 * s)
    ring(50 * s, 1.0 * s)
    # Graduations entre les deux cercles intérieurs
    for i in range(48):
        a = i / 48 * math.tau
        r0, r1 = (50 * s, 56 * s) if i % 4 else (50 * s, 62 * s)
        d.line((c + math.cos(a) * r0, c + math.sin(a) * r0, c + math.cos(a) * r1, c + math.sin(a) * r1),
               fill=255, width=int(1.0 * s))
    # Losanges cardinaux sur le cercle extérieur
    for i in range(8):
        a = i / 8 * math.tau
        x, y = c + math.cos(a) * 86 * s, c + math.sin(a) * 86 * s
        k = 4.5 * s
        d.polygon([(x - k, y), (x, y - k), (x + k, y), (x, y + k)], fill=255)

    # Runes posées tangentiellement entre les deux cercles extérieurs
    if os.path.exists(RUNIC_FONT):
        font = ImageFont.truetype(RUNIC_FONT, int(13 * s))
        for i, ch in enumerate(RUNE_GLYPHS):
            a = i / len(RUNE_GLYPHS) * math.tau
            glyph = Image.new("L", (int(16 * s), int(16 * s)), 0)
            ImageDraw.Draw(glyph).text((glyph.width / 2, glyph.height / 2), ch, fill=255, font=font, anchor="mm",
                                               stroke_width=int(0.7 * s), stroke_fill=255)
            glyph = glyph.rotate(-math.degrees(a) - 90, resample=Image.Resampling.BICUBIC)
            gx = int(c + math.cos(a) * 78.5 * s - glyph.width / 2)
            gy = int(c + math.sin(a) * 78.5 * s - glyph.height / 2)
            im.paste(255, (gx, gy), glyph)

    im = im.resize((size, size), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    out.putalpha(im)
    return out


# ---------------------------------------------------------------------------
# 5. Bannière du menu HOME : le décor de l'écran titre, ses lueurs figées
# ---------------------------------------------------------------------------
def add_glow(img, x, y, sigma, color, strength):
    """Lueur gaussienne ajoutée (fusion additive, comme setBlendMode("add") en jeu)."""
    size = int(sigma * 6) | 1
    c = size // 2
    mask = Image.new("L", (size, size), 0)
    mp = mask.load()
    for j in range(size):
        for i in range(size):
            d2 = (i - c) ** 2 + (j - c) ** 2
            mp[i, j] = int(255 * strength * math.exp(-d2 / (2 * sigma * sigma)))
    layer = Image.new("RGB", img.size, (0, 0, 0))
    tint = Image.new("RGB", (size, size), tuple(int(v * 255) for v in color))
    layer.paste(tint, (int(x) - c, int(y) - c), mask)
    return ImageChops.add(img, layer)


def home_banner(clean_bg, letters, halo, title_pos, gleams):
    img = vignette(clean_bg.copy(), 0.6, 0.0)
    img = add_glow(img, *MOON, 11, (0.55, 0.70, 1.0), 0.30)
    for x, y in RUNES:
        img = add_glow(img, x, y, 9, (0.35, 1.0, 0.60), 0.28)
    for x, y in TORCHES:
        img = add_glow(img, x, y, 16, (1.0, 0.55, 0.18), 0.40)
    for x, y, col in ARROWS:
        img = add_glow(img, x, y, 9, col, 0.50)
    for _ in range(9):  # lucioles
        img = add_glow(img, random.randint(20, 400), random.randint(90, 200), 3, (0.45, 1.0, 0.65), 0.8)
    tx, ty = title_pos
    halo_rgb = Image.new("RGB", halo.size, halo.getpixel((0, 0))[:3])
    layer = Image.new("RGB", img.size, (0, 0, 0))
    layer.paste(halo_rgb, (tx - HALO_PAD, ty - HALO_PAD), halo.split()[3].point(lambda v: int(v * 0.5)))
    img = ImageChops.add(img, layer).convert("RGBA")
    img.alpha_composite(letters, (tx, ty))
    gx, gy = gleams[0]
    img = add_glow(img.convert("RGB"), tx + gx, ty + gy, 4, (1.0, 0.95, 0.8), 0.9)
    spark = spark_sprite(21)
    img = img.convert("RGBA")
    img.alpha_composite(spark, (tx + gx - 10, ty + gy - 10))
    # Format 2:1 de bannertool : on garde le titre, le bas (jambes du héros) est rogné
    img = img.convert("RGB").crop((0, 2, BG_W, 2 + BG_W // 2))
    img = img.resize((256, 128), Image.Resampling.LANCZOS)
    return img.filter(ImageFilter.UnsharpMask(radius=0.8, percent=90, threshold=2))


# ---------------------------------------------------------------------------
# 6. Assemblage
# ---------------------------------------------------------------------------
def brightest_points(letters, count, min_dist):
    """Points les plus lumineux des lettres : ancrages des scintillements."""
    w, h = letters.size
    px = letters.load()
    cands = []
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 230:
                cands.append((r + g + b, x, y))
    cands.sort(reverse=True)
    picked = []
    for _, x, y in cands:
        if all((x - px_) ** 2 + (y - py_) ** 2 >= min_dist * min_dist for px_, py_ in picked):
            picked.append((x, y))
            if len(picked) == count:
                break
    return picked


def main():
    src_full = Image.open(SRC).convert("RGB")
    mask_full = title_mask(src_full)

    # --- Titre détouré (prémultiplié pour la réduction : pas de liseré sombre)
    letters_full = src_full.copy()
    letters_full.putalpha(mask_full)
    letters_full = letters_full.crop(CROP)
    mask_crop = mask_full.crop(CROP)
    bbox_full = mask_crop.point(lambda v: 255 if v > 6 else 0).getbbox()
    pad = 3 * SCALE
    bx0 = max(0, bbox_full[0] - pad) // SCALE * SCALE
    by0 = max(0, bbox_full[1] - pad) // SCALE * SCALE
    bx1 = -(-(bbox_full[2] + pad) // SCALE) * SCALE
    by1 = -(-(bbox_full[3] + pad) // SCALE) * SCALE
    lw, lh = (bx1 - bx0) // SCALE, (by1 - by0) // SCALE
    if lw > LETTERS_MAX[0] or lh > LETTERS_MAX[1]:
        raise SystemExit(f"titre trop grand : {lw}x{lh} > {LETTERS_MAX}")
    letters = (letters_full.crop((bx0, by0, bx1, by1)).convert("RGBa")
               .resize((lw, lh), Image.Resampling.LANCZOS).convert("RGBA"))
    title_pos = (bx0 // SCALE, by0 // SCALE)

    # Halo : alpha du titre étalé, couleur or chaud (fusion additive à l'exécution)
    # (marge HALO_PAD autour des lettres : le flou n'est jamais coupé net)
    halo_a = Image.new("L", (lw + 2 * HALO_PAD, lh + 2 * HALO_PAD), 0)
    halo_a.paste(letters.split()[3], (HALO_PAD, HALO_PAD))
    halo_a = halo_a.filter(ImageFilter.MaxFilter(3)).filter(ImageFilter.GaussianBlur(3))
    halo = Image.new("RGBA", halo_a.size, (255, 196, 92, 0))
    halo.putalpha(halo_a)

    # --- Décor : ciel reconstruit sous le titre
    bg = src_full.crop(CROP).resize((BG_W, BG_H), Image.Resampling.LANCZOS)
    hole = (mask_crop.resize((BG_W, BG_H), Image.Resampling.BOX)
            .point(lambda v: 255 if v > 4 else 0)
            .filter(ImageFilter.MaxFilter(9)))
    # Le titre déborde sur le haut de l'arc : on ne remplit que la zone du titre
    tb = (TITLE_BOX[0] - CROP[0]) // SCALE, TITLE_BOX[1] // SCALE, (TITLE_BOX[2] - CROP[0]) // SCALE, TITLE_BOX[3] // SCALE
    region = (max(0, tb[0] - 6), max(0, tb[1] - 6), min(BG_W, tb[2] + 6), min(BG_H, tb[3] + 6))
    sub = inpaint(bg.crop(region), hole.crop(region))
    sub = sprinkle_stars(sub, hole.crop(region), 0.012)
    bg.paste(sub, region[:2], hole.crop(region).filter(ImageFilter.GaussianBlur(1.2)))
    clean_bg = bg.copy()
    bg = vignette(bg, 0.85, 0.75)

    top = Image.new("RGBA", (512, 256), (0, 0, 0, 255))
    top.paste(bg, (0, 0))
    top.save(os.path.join(ASSETS, "title_top.png"))

    # --- Feuille d'effets
    fx = Image.new("RGBA", (FX_W, FX_H), (0, 0, 0, 0))
    fx.paste(letters, (0, 0))
    fx.paste(halo, (0, HALO_Y))
    sprites = {
        "glow": ((224, 0), glow_sprite(32, 7.0)),
        "spark": ((224, 32), spark_sprite(32)),
        "dot": ((224, 64), glow_sprite(16, 2.6)),
        "mote": ((240, 64), glow_sprite(8, 1.3)),
    }
    for (x, y), im in sprites.values():
        fx.paste(im, (x, y))
    fx.save(os.path.join(ASSETS, "title_fx.png"))

    # --- Écran bas : décor sans titre, recadré en 4:3, flouté et assombri + anneau runique
    cw = BG_H * 320 // 240
    blur = clean_bg.crop(((BG_W - cw) // 2, 0, (BG_W - cw) // 2 + cw, BG_H)).resize((320, 240), Image.Resampling.LANCZOS)
    blur = blur.filter(ImageFilter.GaussianBlur(7))
    blur = Image.blend(blur, Image.new("RGB", blur.size, (8, 22, 34)), 0.5)
    blur = vignette(blur, 1.0, 0.55)
    bottom = Image.new("RGBA", (512, 256), (0, 0, 0, 0))
    bottom.paste(blur, (0, 0))
    ring = rune_ring(176)
    bottom.paste(ring, (328, 0))
    bottom.save(os.path.join(ASSETS, "title_bottom.png"))

    # --- Points de scintillement, bannière HOME et mise en page Lua
    gleams = brightest_points(letters, 7, 18)
    home_banner(clean_bg, letters, halo, title_pos, gleams).save(os.path.join(ASSETS, "banner_home.png"))
    with open(os.path.join(ROOT, "src", "render", "title_layout.lua"), "w", encoding="utf-8") as f:
        f.write("-- src/render/title_layout.lua\n")
        f.write("-- Généré par tools/make_title_assets.py : ne pas modifier à la main.\n")
        f.write("-- Rectangles (x, y, w, h) dans les textures de l'écran titre.\n\n")
        f.write("return {\n")
        f.write(f"    bg = {{ 0, 0, {BG_W}, {BG_H} }},\n")
        f.write(f"    letters = {{ 0, 0, {lw}, {lh} }},\n")
        f.write(f"    halo = {{ 0, {HALO_Y}, {halo.width}, {halo.height} }},\n")
        for name, ((x, y), im) in sprites.items():
            f.write(f"    {name} = {{ {x}, {y}, {im.width}, {im.height} }},\n")
        f.write(f"    ring = {{ 328, 0, {ring.width}, {ring.height} }},\n")
        f.write(f"    bottomBg = {{ 0, 0, 320, 240 }},\n")
        f.write(f"    -- Position du titre dans le décor (pixels du décor {BG_W}x{BG_H})\n")
        f.write(f"    titleX = {title_pos[0]}, titleY = {title_pos[1]},\n")
        f.write("    -- Points les plus brillants des lettres (repère du titre)\n")
        f.write("    gleams = { " + ", ".join(f"{{ {x}, {y} }}" for x, y in gleams) + " },\n")
        f.write("    -- Lumières du décor (pixels du décor) ; flèches : x, y, couleur\n")
        f.write(f"    moon = {{ {MOON[0]}, {MOON[1]} }},\n")
        for name, pts in (("torches", TORCHES), ("runes", RUNES), ("stars", STARS)):
            f.write(f"    {name} = {{ " + ", ".join(f"{{ {x}, {y} }}" for x, y in pts) + " },\n")
        f.write("    arrows = {\n")
        for x, y, (r, g, b) in ARROWS:
            f.write(f"        {{ {x}, {y}, {{ {r:.2f}, {g:.2f}, {b:.2f} }} }},\n")
        f.write("    },\n")
        f.write("}\n")

    print(f"title_top.png : décor {BG_W}x{BG_H}, titre retiré ({lw}x{lh} à {title_pos})")
    print("title_fx.png : titre, halo, glow, spark, dot, mote")
    print("title_bottom.png : fond 320x240 + anneau runique 176x176")
    print("banner_home.png : bannière HOME 256x128")
    print("src/render/title_layout.lua écrit")


if __name__ == "__main__":
    main()
