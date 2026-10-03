#!/usr/bin/env python3
"""
tools/png2t3x.py
Convertit un PNG RGBA en texture native 3DS .t3x (format lu par LÖVE Potion 3.x).

Sur 3DS, LÖVE Potion remplace automatiquement ".png" par ".t3x" : sans ce fichier,
love.graphics.newImage("assets/atlas.png") échoue et le jeu retombait sur la génération
procédurale de l'atlas (~13 s de démarrage). Le .t3x est copié tel quel en mémoire GPU.

Format (platform/ctr/.../t3xhandler.hpp de LÖVE Potion) :
  en-tête 17 octets (packed) : u16 numSubTextures=1, u8 [log2(w)-3 | (log2(h)-3)<<3 | type<<6],
  u8 format (0 = GPU_RGBA8), u8 mipmaps=0, u16 width, height, left, top, right, bottom
  puis un flux libctru "decompress" : u8 type (0x00 = non compressé), u24 taille, données.
Données : tuiles 8x8 en ordre de Morton (ligne 0 du PNG en premier),
pixel RGBA8 stocké en octets A, B, G, R.

Usage : png2t3x.py entrée.png sortie.t3x
"""

import struct
import sys

from PIL import Image


def morton_table():
    table = [0] * 64
    for y in range(8):
        for x in range(8):
            m = 0
            for bit in range(3):
                m |= ((x >> bit) & 1) << (2 * bit)
                m |= ((y >> bit) & 1) << (2 * bit + 1)
            table[y * 8 + x] = m
    return table


def next_pow2(n):
    p = 8
    while p < n:
        p *= 2
    return p


def convert(src, dst):
    img = Image.open(src).convert("RGBA")
    w, h = img.size
    tw, th = next_pow2(w), next_pow2(h)
    if tw > 1024 or th > 1024:
        raise SystemExit(f"{src}: {w}x{h} dépasse 1024x1024")

    canvas = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    canvas.paste(img, (0, 0))
    # Pas de retournement vertical : LÖVE Potion inverse déjà v à l'échantillonnage
    # (vérifié dans l'émulateur : ligne 0 du PNG = ligne 0 des tuiles)
    px = canvas.load()

    table = morton_table()
    out = bytearray(tw * th * 4)
    tiles_per_row = tw // 8
    for y in range(th):
        ty, sy = divmod(y, 8)
        for x in range(tw):
            tx, sx = divmod(x, 8)
            idx = ((tiles_per_row * ty + tx) * 64 + table[sy * 8 + sx]) * 4
            r, g, b, a = px[x, y]
            out[idx] = a
            out[idx + 1] = b
            out[idx + 2] = g
            out[idx + 3] = r

    log_w = tw.bit_length() - 1 - 3
    log_h = th.bit_length() - 1 - 3
    header = struct.pack("<HBBBHHHHHH", 1, (log_w & 7) | ((log_h & 7) << 3), 0, 0,
                         w, h, 0, th, w, th - h)
    size = len(out)
    if size >= 1 << 24:
        stream = struct.pack("<BBBBI", 0x00, 0, 0, 0, size)
    else:
        stream = struct.pack("<I", size << 8)
    with open(dst, "wb") as f:
        f.write(header + stream + out)
    print(f" -> {dst} : {w}x{h} (texture {tw}x{th}, {len(header) + len(stream) + size} octets)")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    convert(sys.argv[1], sys.argv[2])
