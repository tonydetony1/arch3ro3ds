#!/usr/bin/env python3
"""HOME Menu 3D banner model: a double-faced voxel "ARCH3RO" logo turning over the HOME Menu theme.

Writes assets/banner/banner.gltf (self-contained, data URIs).
Convert it to CGFX with pycgfx
(https://github.com/skyfloogle/pycgfx, needs `gltflib` and `pillow`):

    python3 <pycgfx>/main.py assets/banner/banner.gltf assets/banner/banner.cgfx

tools/build_all.py then builds Arch3ro.bnr from banner.cgfx with `bannertool makebanner -ci`.

Real hardware rules (a bad banner can freeze the HOME Menu): rigid node rotations only (no
skinning, no morph targets), CGFX under 512 KB, textures at most 256 px. Camera framing comes
from pycgfx's banner-camera.gltf: eye at (0, 1, 44.786) looking down -Z, vertical field of view
30 degrees, so the centre of the screen is the line y = 1. There is no backdrop: the HOME Menu
theme shows behind the logo.

Every position is baked into the vertices and the nodes have no rest transform: the logo is
centred on the vertical axis x = z = 0 at the screen's centre height and only ever rotates
around that axis at a constant speed, so it turns on itself smoothly whatever order the HOME
Menu applies transforms in.
Both faces carry readable text (the back one is mirrored), glued to a dark core.

pycgfx turns rotation keys into Euler angles with asin(), which flips to another representation
past 90 degrees and makes a linear key-to-key interpolation spin the wrong way. The full turn is
therefore split between two nested nodes ("LogoTurn" and its child "Logo"), each turning half
of the angle and so never reaching 90 degrees.
"""
import base64
import json
import math
import os
import re
import struct


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GLYPHS_LUA = os.path.join(ROOT, "src", "ui", "font_glyphs.lua")
OUT_GLTF = os.path.join(ROOT, "assets", "banner", "banner.gltf")

VOXEL = 0.56            # logo voxel size (world units)
LOGO_DEPTH = 2          # logo thickness in voxels
SCREEN_CENTER_Y = 1.0   # height of the camera axis: the logo's centre sits on it
SUB_VOXEL = 0.38        # "3DS" subtitle voxel size
TURN_PERIOD = 8.0       # seconds per full turn (back face, front face, back face)
TURN_KEYS = 48          # rotation keys per turn (linear in between)
TURN_LIMIT = 179.9      # turn range is +-this (each node stays below 90 degrees)

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


def add_voxels(mesh, cells, size, origin, colors, skip=()):
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
                corners.append((ox + c[0] * size, oy - c[1] * size, oz + c[2] * size))
            mesh.quad(corners, normal, color)


def text_block(mesh, glyphs, text, size, top, palette):
    """Double-faced voxel text: letters reading normally from the front, the mirrored letters
    reading normally from the back, and a dark core one voxel larger than both all around (it
    draws the outline). Centred on x = 0 and z = 0, `top` is the world height of its first row.
    Returns the text height in voxels."""
    pixels, w, h = text_mask(glyphs, text)
    mirrored = {(w - 1 - x, y) for (x, y) in pixels}
    kinds = {}
    for (x, y) in pixels | mirrored:
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                kinds[(x + dx, y + dy, LOGO_DEPTH)] = "core"
    for (x, y) in mirrored:
        for z in range(LOGO_DEPTH):
            kinds[(x, y, z)] = "letter"
    for (x, y) in pixels:
        for z in range(LOGO_DEPTH + 1, 2 * LOGO_DEPTH + 1):
            kinds[(x, y, z)] = "letter"
    light, main, side, under = palette

    def color(cell, face):
        if kinds[cell] == "core":
            return INK if face in ("front", "back") else INK_SIDE
        if face in ("front", "back"):
            return light if cell[1] <= 2 else main
        if face == "top":
            return light
        return under if face == "bottom" else side

    depth = (2 * LOGO_DEPTH + 1) * size
    add_voxels(mesh, set(kinds), size, (-w * size / 2, top, -depth / 2), color)
    return h


def logo_mesh(glyphs):
    mesh = Mesh()
    top = 0.0
    h = text_block(mesh, glyphs, "ARCH3RO", VOXEL, top, (LIGHT, MAIN, SIDE, UNDER))
    text_block(mesh, glyphs, "3DS", SUB_VOXEL, top - (h + 3) * VOXEL, (SUB_LIGHT, SUB_MAIN, SUB_SIDE, SUB_SIDE))
    center_mesh(mesh, (0.0, SCREEN_CENTER_Y, 0.0))
    return mesh


def center_mesh(mesh, target):
    """Moves the mesh so the centre of its bounding box lands on `target`."""
    shift = []
    for axis in range(3):
        values = [p[axis] for p in mesh.pos]
        shift.append(target[axis] - (min(values) + max(values)) / 2)
    mesh.pos = [(p[0] + shift[0], p[1] + shift[1], p[2] + shift[2]) for p in mesh.pos]


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


def turn_angle(t):
    """Logo rotation around its vertical axis at time t, in degrees: from -TURN_LIMIT (back face)
    through 0 (front face) to +TURN_LIMIT at a constant speed, so linear keys are exact."""
    u = min(max(t, 0.0), TURN_PERIOD) / TURN_PERIOD
    return -TURN_LIMIT + 2 * TURN_LIMIT * u


def turn_animation(g, outer, inner):
    """Rigid rotations of the two logo nodes, each carrying half of the turn angle."""
    times = [TURN_PERIOD * i / TURN_KEYS for i in range(TURN_KEYS + 1)]
    assert all(abs(turn_angle(t)) < 180 for t in times), "a node would pass 90 degrees"
    rots = []
    for t in times:
        a = math.radians(turn_angle(t) / 2)
        rots.append((0.0, math.sin(a / 2), 0.0, math.cos(a / 2)))
    t_acc = g.accessor(times, "SCALAR", 5126, "f", minmax=True)
    r_acc = g.accessor(rots, "VEC4", 5126, "f")
    g.doc["animations"].append({"name": "LogoTurn", "samplers": [
        {"input": t_acc, "output": r_acc, "interpolation": "LINEAR"}], "channels": [
        {"sampler": 0, "target": {"node": outer, "path": "rotation"}},
        {"sampler": 0, "target": {"node": inner, "path": "rotation"}}]})


def build(out_gltf):
    glyphs = load_glyphs()
    g = Gltf()
    g.doc["materials"].append({"name": "Logo", "pbrMetallicRoughness": {
        "baseColorFactor": [1, 1, 1, 1], "roughnessFactor": 0.6, "metallicFactor": 0.0}})
    mesh = logo_mesh(glyphs)
    inner = len(g.doc["nodes"])
    g.doc["nodes"].append({"name": "Logo", "mesh": g.add_mesh(mesh, 0)})
    outer = g.add_node({"name": "LogoTurn", "children": [inner]})
    turn_animation(g, outer, inner)
    os.makedirs(os.path.dirname(out_gltf), exist_ok=True)
    g.save(out_gltf)
    print("banner model: %d vertices, %d triangles -> %s" % (len(mesh.pos), len(mesh.idx) // 3, out_gltf))


def main():
    build(OUT_GLTF)


if __name__ == "__main__":
    main()
