#!/usr/bin/env python3
"""HOME Menu 3D banner model: voxel "ARCH3RO" logo swaying in front of the menu backdrop.

Writes assets/banner/banner.gltf (self-contained, data URIs). Convert it to CGFX with pycgfx
(https://github.com/skyfloogle/pycgfx, needs `gltflib` and `pillow`):

    python3 <pycgfx>/main.py assets/banner/banner.gltf assets/banner/banner.cgfx

tools/build_all.py then builds Arch3ro.bnr from banner.cgfx with `bannertool makebanner -ci`.

Real hardware rules (a bad banner can freeze the HOME Menu): one rigid node animation only
(rotation + translation of the logo node, no skinning, no morph targets), CGFX under 512 KB,
textures at most 256 px. Camera framing comes from pycgfx's banner-camera.gltf: eye at
(0, 1, 44.786) looking down -Z, vertical field of view 30 degrees.
"""
import base64
import json
import math
import os
import re
import struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GLYPHS_LUA = os.path.join(ROOT, "src", "ui", "font_glyphs.lua")
BACKDROP_PNG = os.path.join(ROOT, "assets", "banner", "backdrop.png")
OUT_GLTF = os.path.join(ROOT, "assets", "banner", "banner.gltf")

VOXEL = 0.62            # logo voxel size (world units)
LOGO_DEPTH = 2          # logo thickness in voxels
LOGO_Y = 4.6            # logo centre height
SUB_VOXEL = 0.42        # "3DS" subtitle voxel size
SWAY_DEG = 22           # logo sway amplitude around Y
BOB = 0.45              # vertical float amplitude
PERIOD = 4.0            # seconds per loop
BACKDROP_Z = -24.0
BACKDROP_W, BACKDROP_H, BACKDROP_Y = 76.0, 38.0, 1.0

# Colours (sRGB, the HOME Menu does not convert them)
LIGHT = (0xfe, 0xe7, 0x61)
MAIN = (0xfe, 0xae, 0x34)
SIDE = (0xf7, 0x76, 0x22)
UNDER = (0xbe, 0x4a, 0x2f)
INK = (0x18, 0x14, 0x25)
INK_SIDE = (0x26, 0x2b, 0x44)
SUB_LIGHT = (0x66, 0xd9, 0xff)
SUB_MAIN = (0x00, 0x99, 0xdb)
SUB_SIDE = (0x12, 0x4e, 0x89)


def load_glyphs():
    """Capital glyphs of the MAIN font from font_glyphs.lua: char -> (yoff, rows)."""
    src = open(GLYPHS_LUA, encoding="utf-8").read()
    main = src[src.index("G.MAIN"):src.index("G.TINY")]
    out = {}
    for m in re.finditer(r'\["(.)"\]\s*=\s*\{\s*(\d+),\s*((?:"[.#]+",?\s*)+)\}', main):
        out[m.group(1)] = (int(m.group(2)), re.findall(r'"([.#]+)"', m.group(3)))
    return out


def text_mask(glyphs, text):
    """2D pixel mask of a capital text line: set of (x, y), y = 0 at the top, and its size."""
    pixels, x = set(), 0
    for ch in text:
        _, rows = glyphs[ch]
        for y, row in enumerate(rows):
            for dx, c in enumerate(row):
                if c == "#":
                    pixels.add((x + dx, y))
        x += len(rows[0]) + 1
    w = x - 1
    h = max(y for _, y in pixels) + 1
    return pixels, w, h


class Mesh:
    def __init__(self):
        self.pos, self.nrm, self.col, self.idx = [], [], [], []

    def quad(self, corners, normal, color):
        base = len(self.pos)
        for c in corners:
            self.pos.append(c)
            self.nrm.append(normal)
            self.col.append(tuple(v / 255 for v in color) + (1.0,))
        self.idx += [base, base + 1, base + 2, base, base + 2, base + 3]


FACES = {
    # name: (normal, neighbour step in cell space, unit quad corners (qx, qy, qz))
    "front": ((0, 0, 1), (0, 0, 1), [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)]),
    "back": ((0, 0, -1), (0, 0, -1), [(1, 0, 0), (0, 0, 0), (0, 1, 0), (1, 1, 0)]),
    "left": ((-1, 0, 0), (-1, 0, 0), [(0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)]),
    "right": ((1, 0, 0), (1, 0, 0), [(1, 0, 1), (1, 0, 0), (1, 1, 0), (1, 1, 1)]),
    "top": ((0, 1, 0), (0, -1, 0), [(0, 1, 1), (1, 1, 1), (1, 1, 0), (0, 1, 0)]),
    "bottom": ((0, -1, 0), (0, 1, 0), [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)]),
}
# For each face: which cell axes span the face (u, v) and which one is the plane
FACE_AXES = {"front": (0, 1, 2), "back": (0, 1, 2), "left": (2, 1, 0), "right": (2, 1, 0),
             "top": (0, 2, 1), "bottom": (0, 2, 1)}


def greedy_rects(cells):
    """Split a set of (u, v) cells into maximal rectangles (u0, v0, u1, v1), inclusive."""
    left = set(cells)
    rects = []
    for (u, v) in sorted(cells, key=lambda c: (c[1], c[0])):
        if (u, v) not in left:
            continue
        u1 = u
        while (u1 + 1, v) in left:
            u1 += 1
        v1 = v
        while all((x, v1 + 1) in left for x in range(u, u1 + 1)):
            v1 += 1
        for y in range(v, v1 + 1):
            for x in range(u, u1 + 1):
                left.discard((x, y))
        rects.append((u, v, u1, v1))
    return rects


def add_voxels(mesh, cells, size, origin, colors, skip=("back",)):
    """Visible faces of a voxel set, merged into rectangles of one colour per plane.
    `colors(cell, face)` picks the colour; y grows downward in cell space."""
    ox, oy, oz = origin
    groups = {}
    for cell in cells:
        for name, (_, step, _) in FACES.items():
            if name in skip:
                continue
            if (cell[0] + step[0], cell[1] + step[1], cell[2] + step[2]) in cells:
                continue
            ua, va, pa = FACE_AXES[name]
            key = (name, cell[pa], colors(cell, name))
            groups.setdefault(key, set()).add((cell[ua], cell[va]))
    for (name, plane, color), uv in groups.items():
        normal, _, quad = FACES[name]
        ua, va, pa = FACE_AXES[name]
        for (u0, v0, u1, v1) in greedy_rects(uv):
            corners = []
            for q in quad:
                c = [0, 0, 0]
                c[pa] = plane + q[pa]
                c[ua] = u0 if q[ua] == 0 else u1 + 1
                if va == 1:   # y: q = 1 is the top edge of the cell
                    c[1] = v0 if q[1] == 1 else v1 + 1
                else:
                    c[va] = v0 if q[va] == 0 else v1 + 1
                if pa == 1:   # horizontal faces: plane row, q = 1 is the cell's top
                    c[1] = plane + (0 if q[1] == 1 else 1)
                corners.append((ox + c[0] * size, oy - c[1] * size, oz + (c[2] - LOGO_DEPTH) * size))
            mesh.quad(corners, normal, color)


def logo_mesh(glyphs):
    mesh = Mesh()
    pixels, w, h = text_mask(glyphs, "ARCH3RO")
    cx = -w * VOXEL / 2
    top = h * VOXEL / 2
    letters = {(x, y, z) for (x, y) in pixels for z in range(LOGO_DEPTH)}

    def letter_color(cell, face):
        x, y, z = cell
        if face == "front":
            return LIGHT if y <= 2 else MAIN
        if face == "top":
            return LIGHT
        if face == "bottom":
            return UNDER
        return SIDE

    add_voxels(mesh, letters, VOXEL, (cx, top, 0.0), letter_color)
    # ink backing one voxel larger all around and one voxel behind: reads as an outline
    halo = {(x + dx, y + dy) for (x, y) in pixels for dx in (-1, 0, 1) for dy in (-1, 0, 1)}
    backing = {(x, y, -1) for (x, y) in halo}
    add_voxels(mesh, backing, VOXEL, (cx, top, 0.0), lambda c, f: INK if f in ("front", "back") else INK_SIDE)

    sub, sw, sh = text_mask(glyphs, "3DS")
    sub_cells = {(x, y, z) for (x, y) in sub for z in range(LOGO_DEPTH)}
    sub_top = top - (h + 3) * VOXEL
    sub_x = -sw * SUB_VOXEL / 2

    def sub_color(cell, face):
        if face == "front":
            return SUB_LIGHT if cell[1] <= 2 else SUB_MAIN
        return SUB_LIGHT if face == "top" else SUB_SIDE

    add_voxels(mesh, sub_cells, SUB_VOXEL, (sub_x, sub_top, 0.0), sub_color)
    sub_halo = {(x + dx, y + dy) for (x, y) in sub for dx in (-1, 0, 1) for dy in (-1, 0, 1)}
    add_voxels(mesh, {(x, y, -1) for (x, y) in sub_halo}, SUB_VOXEL, (sub_x, sub_top, 0.0),
               lambda c, f: INK if f in ("front", "back") else INK_SIDE)
    return mesh


class Gltf:
    """Minimal glTF 2.0 writer with one embedded buffer."""

    def __init__(self):
        self.doc = {"asset": {"version": "2.0", "generator": "arch3ro make_banner_model"},
                    "scene": 0, "scenes": [{"nodes": []}], "nodes": [], "meshes": [], "materials": [],
                    "accessors": [], "bufferViews": [], "buffers": [], "animations": []}
        self.blob = bytearray()

    def view(self, data, target=None):
        while len(self.blob) % 4:
            self.blob.append(0)
        view = {"buffer": 0, "byteOffset": len(self.blob), "byteLength": len(data)}
        if target:
            view["target"] = target
        self.blob += data
        self.doc["bufferViews"].append(view)
        return len(self.doc["bufferViews"]) - 1

    def accessor(self, values, kind, comp, fmt, target=None, minmax=False):
        flat = [v for item in values for v in (item if isinstance(item, tuple) else (item,))]
        data = struct.pack("<%d%s" % (len(flat), fmt), *flat)
        acc = {"bufferView": self.view(data, target), "componentType": comp, "count": len(values), "type": kind}
        if minmax:
            n = len(values[0]) if isinstance(values[0], tuple) else 1
            cols = [[v[i] if n > 1 else v for v in values] for i in range(n)]
            acc["min"] = [min(c) for c in cols]
            acc["max"] = [max(c) for c in cols]
        self.doc["accessors"].append(acc)
        return len(self.doc["accessors"]) - 1

    def add_mesh(self, mesh, material):
        attrs = {
            "POSITION": self.accessor(mesh.pos, "VEC3", 5126, "f", 34962, minmax=True),
            "NORMAL": self.accessor(mesh.nrm, "VEC3", 5126, "f", 34962),
            "COLOR_0": self.accessor(mesh.col, "VEC4", 5126, "f", 34962),
        }
        prim = {"attributes": attrs, "indices": self.accessor(mesh.idx, "SCALAR", 5123, "H", 34963),
                "material": material}
        self.doc["meshes"].append({"name": "Logo", "primitives": [prim]})
        return len(self.doc["meshes"]) - 1

    def add_node(self, node):
        self.doc["nodes"].append(node)
        self.doc["scenes"][0]["nodes"].append(len(self.doc["nodes"]) - 1)
        return len(self.doc["nodes"]) - 1

    def save(self, path):
        self.doc["buffers"] = [{"byteLength": len(self.blob),
                                "uri": "data:application/octet-stream;base64," + base64.b64encode(bytes(self.blob)).decode()}]
        if not self.doc["animations"]:
            del self.doc["animations"]
        with open(path, "w") as f:
            json.dump(self.doc, f)


def backdrop(g):
    """Textured quad behind the logo showing the menu island scene."""
    png = open(BACKDROP_PNG, "rb").read()
    g.doc["images"] = [{"name": "backdrop", "uri": "data:image/png;base64," + base64.b64encode(png).decode()}]
    g.doc["samplers"] = [{"magFilter": 9728, "minFilter": 9728, "wrapS": 33071, "wrapT": 33071}]
    g.doc["textures"] = [{"sampler": 0, "source": 0}]
    g.doc["materials"].append({"name": "Backdrop", "pbrMetallicRoughness": {
        "baseColorTexture": {"index": 0}, "roughnessFactor": 1.0, "metallicFactor": 0.0}})
    hw, hh = BACKDROP_W / 2, BACKDROP_H / 2
    pos = [(-hw, -hh, 0.0), (hw, -hh, 0.0), (hw, hh, 0.0), (-hw, hh, 0.0)]
    uv = [(0.0, 1.0), (1.0, 1.0), (1.0, 0.0), (0.0, 0.0)]
    prim = {"attributes": {
        "POSITION": g.accessor(pos, "VEC3", 5126, "f", 34962, minmax=True),
        "NORMAL": g.accessor([(0.0, 0.0, 1.0)] * 4, "VEC3", 5126, "f", 34962),
        "TEXCOORD_0": g.accessor(uv, "VEC2", 5126, "f", 34962)},
        "indices": g.accessor([0, 1, 2, 0, 2, 3], "SCALAR", 5123, "H", 34963), "material": 0}
    g.doc["meshes"].append({"name": "Backdrop", "primitives": [prim]})
    g.add_node({"name": "Backdrop", "mesh": len(g.doc["meshes"]) - 1, "translation": [0.0, BACKDROP_Y, BACKDROP_Z]})


def sway_animation(g, node):
    """Rigid TRS animation of the logo node: gentle sway around Y and a slow float."""
    keys = 16
    times = [PERIOD * i / keys for i in range(keys + 1)]
    rots, trans = [], []
    for t in times:
        a = math.radians(SWAY_DEG) * math.sin(2 * math.pi * t / PERIOD)
        rots.append((0.0, math.sin(a / 2), 0.0, math.cos(a / 2)))
        trans.append((0.0, LOGO_Y + BOB * math.sin(4 * math.pi * t / PERIOD), 0.0))
    t_acc = g.accessor(times, "SCALAR", 5126, "f", minmax=True)
    r_acc = g.accessor(rots, "VEC4", 5126, "f")
    p_acc = g.accessor(trans, "VEC3", 5126, "f")
    g.doc["animations"].append({"name": "LogoSway", "samplers": [
        {"input": t_acc, "output": r_acc, "interpolation": "LINEAR"},
        {"input": t_acc, "output": p_acc, "interpolation": "LINEAR"}], "channels": [
        {"sampler": 0, "target": {"node": node, "path": "rotation"}},
        {"sampler": 1, "target": {"node": node, "path": "translation"}}]})


def main():
    glyphs = load_glyphs()
    g = Gltf()
    backdrop(g)
    g.doc["materials"].append({"name": "Logo", "pbrMetallicRoughness": {
        "baseColorFactor": [1, 1, 1, 1], "roughnessFactor": 0.6, "metallicFactor": 0.0}})
    mesh = logo_mesh(glyphs)
    node = g.add_node({"name": "Logo", "mesh": g.add_mesh(mesh, 1), "translation": [0.0, LOGO_Y, 0.0]})
    sway_animation(g, node)
    os.makedirs(os.path.dirname(OUT_GLTF), exist_ok=True)
    g.save(OUT_GLTF)
    print("banner model: %d vertices, %d triangles -> %s" % (len(mesh.pos), len(mesh.idx) // 3, OUT_GLTF))


if __name__ == "__main__":
    main()
