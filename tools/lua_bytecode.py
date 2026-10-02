#!/usr/bin/env python3
"""
tools/lua_bytecode.py
Précompilation Lua 5.1 pour la 3DS : compile un fichier avec luac5.1 (PC, 64 bits) puis
réécrit le bytecode au format de la console (ARM 32 bits : size_t sur 4 octets au lieu de 8).

Sur Old 3DS, compiler le source Lua au démarrage coûte plusieurs secondes ; charger du
bytecode évite l'analyse syntaxique. Les deux formats ne diffèrent que par la taille de
size_t (longueur des chaînes) : int, Instruction et lua_Number font 4, 4 et 8 octets des
deux côtés, et les deux machines sont petit-boutistes.

Usage : lua_bytecode.py SOURCE.lua SORTIE   (le chemin du source apparaît dans les traces)
        lua_bytecode.py --selftest          (aller-retour 64 -> 32 -> 64 sur src/)
"""

import os
import struct
import subprocess
import sys
import tempfile

LUAC = "luac5.1"
SIGNATURE = b"\x1bLua"
VERSION = 0x51


class Reader:
    def __init__(self, data, size_t):
        self.data, self.pos, self.size_t = data, 0, size_t

    def take(self, n):
        chunk = self.data[self.pos:self.pos + n]
        if len(chunk) != n:
            raise ValueError("bytecode tronqué")
        self.pos += n
        return chunk

    def byte(self):
        return self.take(1)[0]

    def int(self):
        return struct.unpack("<i", self.take(4))[0]

    def size(self):
        return struct.unpack("<Q" if self.size_t == 8 else "<I", self.take(self.size_t))[0]

    def string(self):
        n = self.size()
        return self.take(n) if n else None


class Writer:
    def __init__(self, size_t):
        self.out, self.size_t = bytearray(), size_t

    def raw(self, b):
        self.out += b

    def byte(self, v):
        self.out.append(v)

    def int(self, v):
        self.out += struct.pack("<i", v)

    def size(self, v):
        if self.size_t == 4 and v > 0xFFFFFFFF:
            raise ValueError("chaîne trop longue pour size_t 32 bits")
        self.out += struct.pack("<Q" if self.size_t == 8 else "<I", v)

    def string(self, s):
        if s is None:
            self.size(0)
        else:
            self.size(len(s))
            self.raw(s)


def convert_function(r, w):
    w.string(r.string())                      # source
    w.int(r.int()); w.int(r.int())            # linedefined, lastlinedefined
    for _ in range(4):                        # nups, numparams, is_vararg, maxstacksize
        w.byte(r.byte())
    n = r.int(); w.int(n); w.raw(r.take(4 * n))   # code
    n = r.int(); w.int(n)                     # constantes
    for _ in range(n):
        t = r.byte(); w.byte(t)
        if t == 0:                            # nil
            pass
        elif t == 1:                          # booléen
            w.byte(r.byte())
        elif t == 3:                          # nombre (double)
            w.raw(r.take(8))
        elif t == 4:                          # chaîne
            w.string(r.string())
        else:
            raise ValueError(f"type de constante inconnu {t}")
    n = r.int(); w.int(n)                     # prototypes imbriqués
    for _ in range(n):
        convert_function(r, w)
    n = r.int(); w.int(n); w.raw(r.take(4 * n))   # lineinfo
    n = r.int(); w.int(n)                     # variables locales
    for _ in range(n):
        w.string(r.string()); w.int(r.int()); w.int(r.int())
    n = r.int(); w.int(n)                     # noms des upvalues
    for _ in range(n):
        w.string(r.string())


def convert(data, to_size_t):
    header = data[:12]
    if header[:4] != SIGNATURE or header[4] != VERSION or header[5] != 0:
        raise ValueError("ce n'est pas du bytecode Lua 5.1")
    endian, s_int, s_size, s_instr, s_num, integral = header[6:12]
    if (endian, s_int, s_instr, s_num, integral) != (1, 4, 4, 8, 0):
        raise ValueError(f"format inattendu {tuple(header[6:12])}")
    r = Reader(data, s_size)
    r.pos = 12
    w = Writer(to_size_t)
    w.raw(header[:8])
    w.byte(to_size_t)
    w.raw(header[9:12])
    convert_function(r, w)
    if r.pos != len(data):
        raise ValueError("octets en trop après la fonction principale")
    return bytes(w.out)


def compile_for_3ds(source_path, cwd=None, strip=False):
    """Bytecode 3DS (size_t 32 bits) du fichier ; le chemin tel quel sert de nom de source.
    strip : sans informations de débogage (données générées : moitié moins lourd)."""
    with tempfile.NamedTemporaryFile(suffix=".luac", delete=False) as tmp:
        tmp_path = tmp.name
    try:
        cmd = [LUAC] + (["-s"] if strip else []) + ["-o", tmp_path, source_path]
        subprocess.run(cmd, check=True, cwd=cwd)
        with open(tmp_path, "rb") as f:
            native = f.read()
    finally:
        os.unlink(tmp_path)
    return convert(native, 4)


def selftest(root):
    count = 0
    for folder, _, files in os.walk(os.path.join(root, "src")):
        for name in files:
            if not name.endswith(".lua"):
                continue
            rel = os.path.relpath(os.path.join(folder, name), root)
            with tempfile.NamedTemporaryFile(suffix=".luac", delete=False) as tmp:
                tmp_path = tmp.name
            subprocess.run([LUAC, "-o", tmp_path, rel], check=True, cwd=root)
            with open(tmp_path, "rb") as f:
                native = f.read()
            os.unlink(tmp_path)
            small = convert(native, 4)
            if convert(small, 8) != native:
                raise SystemExit(f"aller-retour différent : {rel}")
            count += 1
    print(f"aller-retour 64 -> 32 -> 64 identique sur {count} fichiers")


if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "--selftest":
        selftest(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    elif len(sys.argv) == 3:
        with open(sys.argv[2], "wb") as f:
            f.write(compile_for_3ds(sys.argv[1]))
    else:
        sys.exit(__doc__)
