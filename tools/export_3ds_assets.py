#!/usr/bin/env python3
"""
tools/export_3ds_assets.py
Exportation et formatage des images pour la Nintendo 3DS :
- Icône 3DS (48x48 et 24x24 au format SMDH CTR 8x8 tiled RGB565)
- Bannière d'accueil 3DS (256x128 standard bannertool & 400x240 écran haut)
- Logo Arch3ro (haute résolution et formats adaptés in-game)
- Génération du fichier binaire SMDH complet (Arch3ro.smdh)
- Injection dans Arch3ro.3dsx
"""

import os
import struct
from PIL import Image, ImageFilter

ARTIFACTS_DIR = "/home/tonydetony/.gemini/antigravity-ide/brain/f15e127d-8a6c-4942-ab9a-61ca936fb0f0"
PROJECT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS_DIR = os.path.join(PROJECT_DIR, "assets")

def find_source(candidates):
    for c in candidates:
        if os.path.exists(c):
            return c
    return candidates[-1]

ICON_SRC = find_source([
    os.path.join(ARTIFACTS_DIR, "arch3ro_icon_1789928556073.jpg"),
    os.path.join(ASSETS_DIR, "icon_hd.png"),
    os.path.join(ASSETS_DIR, "icon.png")
])
BANNER_SRC = find_source([
    os.path.join(ARTIFACTS_DIR, "arch3ro_banner_clean_1789928595778.jpg"),
    os.path.join(ASSETS_DIR, "banner_hd.png"),
    os.path.join(ASSETS_DIR, "banner.png")
])
LOGO_SRC = find_source([
    os.path.join(ARTIFACTS_DIR, "arch3ro_logo_1789928524143.jpg"),
    os.path.join(ASSETS_DIR, "logo_hd.png"),
    os.path.join(ASSETS_DIR, "logo.png")
])

os.makedirs(ASSETS_DIR, exist_ok=True)

# ---------------------------------------------------------------------------
# 1. Traitement et exportation des Icônes
# ---------------------------------------------------------------------------
print("=== 1. Exportation des Icônes 3DS ===")
im_icon = Image.open(ICON_SRC).convert("RGBA")

# Icône HD 512x512 (pour affichage / documentation / CIA tools)
icon_512 = im_icon.resize((512, 512), Image.Resampling.LANCZOS)
icon_512.save(os.path.join(ASSETS_DIR, "icon_hd.png"))

# Icône 3DS standard 48x48 (pour Homebrew Launcher, SMDH, FBI)
icon_48 = im_icon.resize((48, 48), Image.Resampling.LANCZOS)
icon_48_sharp = icon_48.filter(ImageFilter.UnsharpMask(radius=1.0, percent=140, threshold=2))
icon_48_sharp.save(os.path.join(ASSETS_DIR, "icon.png"))
icon_48_sharp.save(os.path.join(ASSETS_DIR, "icon_48.png"))

# Icône 3DS miniature 24x24 (pour SMDH standard)
icon_24 = im_icon.resize((24, 24), Image.Resampling.LANCZOS)
icon_24_sharp = icon_24.filter(ImageFilter.UnsharpMask(radius=0.8, percent=120, threshold=2))
icon_24_sharp.save(os.path.join(ASSETS_DIR, "icon_24.png"))
icon_24_sharp.save(os.path.join(ASSETS_DIR, "icon_small.png"))

print("-> assets/icon.png (48x48) généré.")
print("-> assets/icon_24.png (24x24) généré.")
print("-> assets/icon_hd.png (512x512) généré.")

# ---------------------------------------------------------------------------
# 2. Traitement et exportation des Bannières 3DS
# ---------------------------------------------------------------------------
print("\n=== 2. Exportation des Bannières 3DS ===")
im_banner = Image.open(BANNER_SRC).convert("RGB")
bw, bh = im_banner.size

# Bannière HD originale
im_banner.save(os.path.join(ASSETS_DIR, "banner_hd.png"))

# Bannière Écran Haut Natif 3DS : 400x240 (ratio 5:3 = 1.6667)
target_aspect_top = 400.0 / 240.0
curr_aspect = bw / bh
if curr_aspect > target_aspect_top:
    crop_w = int(bh * target_aspect_top)
    left = (bw - crop_w) // 2
    banner_top_crop = im_banner.crop((left, 0, left + crop_w, bh))
else:
    crop_h = int(bw / target_aspect_top)
    top = (bh - crop_h) // 2
    banner_top_crop = im_banner.crop((0, top, bw, top + crop_h))

banner_top = banner_top_crop.resize((400, 240), Image.Resampling.LANCZOS)
banner_top_sharp = banner_top.filter(ImageFilter.UnsharpMask(radius=0.9, percent=110, threshold=2))
banner_top_sharp.save(os.path.join(ASSETS_DIR, "banner_top.png"))
banner_top_sharp.save(os.path.join(ASSETS_DIR, "splash.png"))

# Bannière officielle Bannertool Texture 3DS : 256x128 (ratio 2:1)
target_aspect_bin = 256.0 / 128.0
if curr_aspect > target_aspect_bin:
    crop_w = int(bh * target_aspect_bin)
    left = (bw - crop_w) // 2
    banner_bin_crop = im_banner.crop((left, 0, left + crop_w, bh))
else:
    crop_h = int(bw / target_aspect_bin)
    top = (bh - crop_h) // 2
    banner_bin_crop = im_banner.crop((0, top, bw, top + crop_h))

banner_256 = banner_bin_crop.resize((256, 128), Image.Resampling.LANCZOS)
banner_256_sharp = banner_256.filter(ImageFilter.UnsharpMask(radius=0.9, percent=110, threshold=2))
banner_256_sharp.save(os.path.join(ASSETS_DIR, "banner.png"))

print("-> assets/banner_top.png (400x240 - Plein écran Haut 3DS) généré.")
print("-> assets/banner.png (256x128 - Texture Bannertool Accueil 3DS) généré.")
print("-> assets/splash.png (400x240 - Écran d'accueil) généré.")

# ---------------------------------------------------------------------------
# 3. Traitement et exportation du Logo
# ---------------------------------------------------------------------------
print("\n=== 3. Exportation du Logo Arch3ro ===")
im_logo = Image.open(LOGO_SRC).convert("RGBA")
lw, lh = im_logo.size
im_logo.save(os.path.join(ASSETS_DIR, "logo_hd.png"))

# Version redimensionnée pour écran 3DS (largeur max 320 ou 260)
logo_3ds = im_logo.resize((320, int(320 * lh / lw)), Image.Resampling.LANCZOS)
logo_3ds.save(os.path.join(ASSETS_DIR, "logo_3ds.png"))

# Création d'une version avec transparence progressive sur fond noir
# R, G, B, A
r, g, b, a = im_logo.split()
# Luminosité pour créer un masque d'opacité
# Les bords sombres deviennent transparents
gray = im_logo.convert("L")
# Seuillage doux pour enlever le fond noir tout en gardant l'effet de lueur magique
def alpha_curve(p):
    if p < 25:
        return 0
    elif p < 80:
        return int((p - 25) / (80 - 25) * 255)
    return 255

alpha_mask = gray.point(alpha_curve)
im_logo_trans = im_logo.copy()
im_logo_trans.putalpha(alpha_mask)
im_logo_trans.save(os.path.join(ASSETS_DIR, "logo.png"))
print("-> assets/logo.png (Logo détouré transparent) généré.")
print("-> assets/logo_3ds.png (Logo calibré 3DS) généré.")

# ---------------------------------------------------------------------------
# 4. Encodage CTR 8x8 Tiled RGB565 pour l'icône SMDH Nintendo 3DS
# ---------------------------------------------------------------------------
def encode_ctr_tiled_rgb565(img, size):
    """
    Encode une image PIL en tuiles CTR 8x8 au format RGB565 Little-Endian.
    L'ordre des pixels dans chaque tuile 8x8 suit la courbe de Morton CTR.
    """
    img_rgb = img.convert("RGB").resize((size, size), Image.Resampling.LANCZOS)
    out = bytearray()

    def morton_index(x, y):
        return (x & 1) | ((y & 1) << 1) | ((x & 2) << 1) | ((y & 2) << 2) | ((x & 4) << 2) | ((y & 4) << 3)

    num_tiles_x = size // 8
    num_tiles_y = size // 8

    for ty in range(num_tiles_y):
        for tx in range(num_tiles_x):
            # Pré-réserver 64 pixels RGB565 pour cette tuile
            tile_bytes = [0] * 64
            for y in range(8):
                for x in range(8):
                    px = img_rgb.getpixel((tx * 8 + x, ty * 8 + y))
                    r, g, b = px[0], px[1], px[2]
                    # Conversion 24-bit RGB vers 16-bit RGB565
                    val = ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)
                    m = morton_index(x, y)
                    tile_bytes[m] = val
            for val in tile_bytes:
                out.extend(struct.pack("<H", val))
    return bytes(out)

# ---------------------------------------------------------------------------
# 5. Création du fichier SMDH complet (14016 octets = 0x36C0)
# ---------------------------------------------------------------------------
print("\n=== 4. Construction du fichier SMDH Nintendo 3DS ===")
smdh = bytearray(14016)

# En-tête SMDH : Magic "SMDH", version 0, reserved 0
smdh[0:4] = b"SMDH"
struct.pack_into("<HH", smdh, 4, 0, 0)

# Titres pour les 16 langues supportées par la 3DS (0x200 = 512 octets par langue)
# Offset 0x08 à 0x2008
# Entry layout (3dbrew SMDH): short description 0x80 bytes, long description 0x100 bytes,
# publisher 0x80 bytes. The HOME Menu shows the long description and publisher on the top
# screen when the title is selected.
SMDH_LANGS = 16
SMDH_SHORT, SMDH_LONG, SMDH_PUBLISHER = (0x00, 0x80), (0x80, 0x100), (0x180, 0x80)
LANG_FRENCH = 2

def smdh_text(text, size):
    raw = text.encode("utf-16-le")
    if len(raw) > size - 2:
        raise ValueError(f"SMDH text too long ({len(raw)} > {size - 2} bytes): {text}")
    return raw

TITLES = {
    "default": ("Arch3ro", "Arch3ro: roguelike archery action", "TonyDeTony"),
    LANG_FRENCH: ("Arch3ro", "Arch3ro : roguelike d'action à l'arc", "TonyDeTony"),
}

for lang in range(SMDH_LANGS):
    base = 0x08 + lang * 0x200
    texts = TITLES.get(lang, TITLES["default"])
    for (offset, size), text in zip((SMDH_SHORT, SMDH_LONG, SMDH_PUBLISHER), texts):
        raw = smdh_text(text, size)
        smdh[base + offset : base + offset + len(raw)] = raw

# Paramètres SMDH (Ratings, flags, region lock, etc.)
struct.pack_into("<I", smdh, 0x2018, 0x7FFFFFFF) # Region-free (toutes régions)
# Flags: Visible (0x1) | Allow 3D (0x4) | Uses save data (0x80) | Record usage (0x100).
# Never set 0x1000: it marks a New 3DS exclusive title and Old 3DS refuses to start it.
SMDH_FLAGS = 0x0001 | 0x0004 | 0x0080 | 0x0100
struct.pack_into("<I", smdh, 0x2028, SMDH_FLAGS)

# Icônes à l'offset 0x2040 (8256)
# 1. Icône 24x24 (1152 octets)
raw_icon_24 = encode_ctr_tiled_rgb565(im_icon, 24)
smdh[0x2040 : 0x2040 + 1152] = raw_icon_24

# 2. Icône 48x48 (4608 octets)
raw_icon_48 = encode_ctr_tiled_rgb565(im_icon, 48)
smdh[0x2040 + 1152 : 0x2040 + 1152 + 4608] = raw_icon_48

smdh_out_path = os.path.join(PROJECT_DIR, "Arch3ro.smdh")
with open(smdh_out_path, "wb") as f:
    f.write(smdh)
print(f"-> Arch3ro.smdh généré ({len(smdh)} octets).")

# ---------------------------------------------------------------------------
# 6. Injection dans Arch3ro.3dsx existant
# ---------------------------------------------------------------------------
target_3dsx = os.path.join(PROJECT_DIR, "Arch3ro.3dsx")
if os.path.exists(target_3dsx):
    print("\n=== 5. Injection du SMDH personnalisé dans Arch3ro.3dsx ===")
    with open(target_3dsx, "r+b") as f:
        hdr = f.read(44)
        magic, header_sz, reloc_sz, fmt, flags, code_sz, rodata_sz, data_sz, bss_sz, smdh_offset, smdh_size = struct.unpack("<4sHHIIIIIIII", hdr[:40])
        if magic == b"3DSX" and smdh_size == 14016:
            f.seek(smdh_offset)
            f.write(smdh)
            print(f"-> SMDH patché avec succès dans Arch3ro.3dsx à l'offset {smdh_offset} !")
        else:
            print(f"Avertissement : structure 3dsx inattendue (smdh_offset={smdh_offset}, smdh_size={smdh_size})")

print("\nTous les assets 3DS et le logo ont été exportés et packagés avec succès !")
