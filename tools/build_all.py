#!/usr/bin/env python3
"""
tools/build_all.py
Générateur automatisé et unifié des packages Nintendo 3DS :
  - Arch3ro.3dsx (Homebrew Launcher / Citra)
  - Arch3ro.cia  (Menu HOME Nintendo 3DS / Citra)

Effectue :
  1. Empaquetage de l'archive game.love (optimisée sans masters HD)
  2. Vérification / génération du SMDH officiel (48x48 + 24x24 CTR RGB565)
  3. Patch binaire universel du runtime (NOP mcuHwcInit + résolution multi-sources)
  4. Création du binaire 3DSX avec SMDH et .love fusionné
  5. Assemblage du package CIA autonome avec RomFS via makerom
  6. Déploiement dans la SDMC virtuelle de Citra/Azahar
"""

import os
import re
import sys
import struct
import zipfile
import subprocess
import shutil

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOOLS_DIR = os.path.join(ROOT_DIR, "tools")
SDMC_3DS_DIR = os.path.expanduser("~/.var/app/org.azahar_emu.Azahar/data/azahar-emu/sdmc/3ds")
SDMC_LP_DIR = os.path.expanduser("~/.var/app/org.azahar_emu.Azahar/data/azahar-emu/sdmc/lovepotion")

os.chdir(ROOT_DIR)

# Runtimes LÖVE Potion (non versionnés, ~100 Mo) : patchés à des offsets fixes plus bas,
# il faut exactement les fichiers dont les empreintes figurent dans le README
TEMPLATES_DIR = os.path.join(TOOLS_DIR, ".templates")
_missing = [n for n in ("lovepotion.3dsx", "lovepotion.elf", "lovepotion_cia.elf")
            if not os.path.exists(os.path.join(TEMPLATES_DIR, n))]
if _missing:
    sys.exit("ERREUR : runtimes LÖVE Potion absents de tools/.templates/ : " + ", ".join(_missing)
             + "\n  Voir la section « Compiling .CIA & .3DSX » du README (fichiers et empreintes SHA-256).")

# --fast : itération rapide (pas de précompilation d'atlas, pas de CIA, pas d'installation)
FAST = "--fast" in sys.argv
# --with-bench : embarque src/dev/bench.lua (mesures sur console via le fichier bench_roomload)
WITH_BENCH = "--with-bench" in sys.argv
# --source : embarque les .lua en source au lieu du bytecode précompilé (débogage)
KEEP_SOURCE = "--source" in sys.argv

print("=" * 60)
print(" ARCH3RO - COMPILATION UNIFIÉE 3DSX & CIA (NINTENDO 3DS)")
print("=" * 60)

# -------------------------------------------------------------
# 0. Précompilation de l'atlas de sprites (Boot Instantané < 0.1s)
# -------------------------------------------------------------
print("\n[0/5] Précompilation de l'atlas de sprites (boot instantané)...")
bake_tool = os.path.join(TOOLS_DIR, "bake")
love_bin = next((p for p in (os.path.expanduser("~/AppImages/löve.appimage"),
                             os.path.expanduser("~/AppImages/love.appimage"),
                             shutil.which("love")) if p and os.path.exists(p)), None)
if FAST:
    print(" -> --fast : atlas existant conservé.")
elif love_bin:
    subprocess.run([love_bin, bake_tool], check=True)
else:
    print(" -> Attention: AppImage löve introuvable, utilisation de l'atlas existant.")

# Texture native 3DS : LÖVE Potion charge assets/atlas.t3x à la place de assets/atlas.png
subprocess.run([sys.executable, os.path.join(TOOLS_DIR, "png2t3x.py"),
                os.path.join(ROOT_DIR, "assets", "atlas.png"),
                os.path.join(ROOT_DIR, "assets", "atlas.t3x")], check=True)

# -------------------------------------------------------------
# 1. Vérification / Création de l'archive .love optimisée
# -------------------------------------------------------------
love_archive_path = os.path.join(TOOLS_DIR, "romfs_dir", "game.love")
os.makedirs(os.path.dirname(love_archive_path), exist_ok=True)

print("\n[1/5] Création de l'archive de jeu optimisée (game.love)...")
# Bytecode Lua 5.1 au format de la console : la 3DS n'a plus à compiler ~70 000 lignes de
# source à chaque démarrage (tools/lua_bytecode.py). conf.lua reste en source (lu par boot.lua).
sys.path.insert(0, TOOLS_DIR)
import lua_bytecode
use_bytecode = not KEEP_SOURCE and shutil.which(lua_bytecode.LUAC) is not None
if not KEEP_SOURCE and not use_bytecode:
    print(f" -> Attention : {lua_bytecode.LUAC} introuvable, scripts embarqués en source (démarrage plus lent).")


def add_script(zf, path, arcname):
    zf.writestr(arcname, script_bytes(path))


# Données générées (pas de numéros de ligne utiles dans une trace) : bytecode sans débogage
STRIPPED_SCRIPTS = {os.path.join("src", "render", "atlas_data.lua")}


def script_bytes(path):
    if use_bytecode:
        return lua_bytecode.compile_for_3ds(path, cwd=ROOT_DIR, strip=os.path.normpath(path) in STRIPPED_SCRIPTS)
    with open(path, "rb") as f:
        return f.read()


# Paquet de modules (lu une seule fois par main.lua) : "A3MB", puis pour chaque module
# nom (longueur sur 2 octets) et contenu (longueur sur 4 octets), gros-boutiste
bundle = bytearray(b"A3MB")


def bundle_module(path):
    name = os.path.splitext(os.path.relpath(path, ROOT_DIR))[0].replace(os.sep, ".").encode()
    data = script_bytes(path)
    bundle.extend(struct.pack(">H", len(name)) + name + struct.pack(">I", len(data)) + data)
    return data


file_count = 0
with zipfile.ZipFile(love_archive_path, "w", zipfile.ZIP_DEFLATED) as zf:
    add_script(zf, "main.lua", "main.lua")
    zf.write("conf.lua", "conf.lua")
    file_count += 2
    for folder in ["src", "assets"]:
        if os.path.exists(folder):
            for root, _, files in os.walk(folder):
                for f in sorted(files):
                    if f.endswith(("_hd.png", ".DS_Store", ".tmp")):
                        continue
                    # Images du menu HOME (icône, bannière, logo) : inutiles dans le jeu
                    if root == "assets" and f.endswith(".png") and f != "atlas.png":
                        continue
                    # Outils de développement : jamais embarqués
                    if root.startswith(os.path.join("src", "dev")):
                        if not (WITH_BENCH and f == "bench.lua"):
                            continue
                    fp = os.path.join(root, f)
                    arcname = os.path.relpath(fp, ROOT_DIR)
                    if f.endswith(".lua"):
                        zf.writestr(arcname, bundle_module(fp))
                    else:
                        zf.write(fp, arcname)
                    file_count += 1
    # Stocké sans compression : main.lua le lit d'un bloc au démarrage
    zf.writestr(zipfile.ZipInfo("modules.bin"), bytes(bundle), compress_type=zipfile.ZIP_STORED)
    print(f" -> modules.bin : {len(bundle) // 1024} Ko de modules regroupés.")

love_size = os.path.getsize(love_archive_path)
print(f" -> {file_count} fichiers inclus ({'bytecode Lua 5.1 32 bits' if use_bytecode else 'scripts en source'}).")
print(f" -> Archive game.love : {love_size / (1024*1024):.2f} Mo ({love_size:,} octets)")

# -------------------------------------------------------------
# 2. Vérification du fichier SMDH (Métadonnées & Icônes 3DS)
# -------------------------------------------------------------
smdh_path = os.path.join(ROOT_DIR, "Arch3ro.smdh")
export_script = os.path.join(TOOLS_DIR, "export_3ds_assets.py")
need_smdh = (not os.path.exists(smdh_path) or 
             os.path.getsize(smdh_path) != 14016 or
             (os.path.exists(export_script) and os.path.getmtime(export_script) > os.path.getmtime(smdh_path)))
if need_smdh:
    print("\n[2/5] Génération d'Arch3ro.smdh...")
    subprocess.run([sys.executable, export_script], check=True)
else:
    print(f"\n[2/5] Arch3ro.smdh conforme ({os.path.getsize(smdh_path)} octets).")

with open(smdh_path, "rb") as f:
    smdh_bytes = f.read()

# -------------------------------------------------------------
# 2.5. Génération de la bannière HOME Menu (Photo & Jingle sonore)
# -------------------------------------------------------------
banner_path = os.path.join(ROOT_DIR, "Arch3ro.bnr")
banner_png = os.path.join(ROOT_DIR, "assets", "banner.png")
banner_audio = os.path.join(ROOT_DIR, "assets", "audio", "sfx", "gate_open.wav")
bannertool_bin = os.path.join(TOOLS_DIR, "bannertool")

if os.path.exists(bannertool_bin) and os.path.exists(banner_png):
    print("\n[2.5/5] Génération de la bannière HOME Menu 3DS (Arch3ro.bnr)...")
    cmd_b = [bannertool_bin, "makebanner", "-i", banner_png]
    if os.path.exists(banner_audio):
        cmd_b.extend(["-a", banner_audio])
    cmd_b.extend(["-o", banner_path])
    res_b = subprocess.run(cmd_b, capture_output=True, text=True)
    if res_b.returncode == 0:
        print(f" -> Arch3ro.bnr généré avec succès ({os.path.getsize(banner_path)} octets).")
    else:
        print(f" -> Avertissement bannertool : {res_b.stderr.strip()}")

# -------------------------------------------------------------
# 3. Code Lua universel de recherche de jeu pour boot.lua
# -------------------------------------------------------------
OLD_BOOT_BLOCK = """    local arg0 = love.arg.getLow(love.rawGameArguments)
    love.filesystem.init(arg0)

    local exepath = love.filesystem.getExecutablePath()
    if #exepath == 0 then
        -- This shouldn't happen, but just in case we'll fall back to arg0.
        exepath = arg0
    end

    no_game_code = false
    invalid_game_path = nil

    -- Is this one of those fancy "fused" games?
    local can_has_game = pcall(love.filesystem.setSource, exepath)"""

NEW_BOOT_RAW = """    local a = love.arg and love.arg.getLow(love.rawGameArguments)
    local exepath = "sdmc:/3ds/Arch3ro.3dsx"
    for _,p in ipairs({"romfs:/game.love",a,"sdmc:/3ds/Arch3ro.3dsx"}) do
        if p and #p>0 then local f=io.open(p) if f then f:close() exepath=p break end end
    end
    love.filesystem.init(exepath)
    no_game_code = false
    invalid_game_path = nil
    local can_has_game = pcall(love.filesystem.setSource, exepath)"""

# Ajustement exact à la taille du bloc d'origine (447 octets)
pad_len = len(OLD_BOOT_BLOCK.encode("latin-1")) - len(NEW_BOOT_RAW.encode("latin-1"))
assert pad_len >= 0, f"NEW_BOOT_RAW trop long de {-pad_len} octets"
NEW_BOOT_BLOCK = NEW_BOOT_RAW + (" " * pad_len)
assert len(NEW_BOOT_BLOCK.encode("latin-1")) == len(OLD_BOOT_BLOCK.encode("latin-1"))

def patch_boot_lua(content: bytearray) -> bytearray:
    # 1. Patch de la détection et initialisation du système de fichiers
    target_bytes = OLD_BOOT_BLOCK.encode("latin-1")
    repl_bytes = NEW_BOOT_BLOCK.encode("latin-1")
    pos = content.find(target_bytes)
    if pos != -1:
        content[pos:pos + len(target_bytes)] = repl_bytes
        print(f" -> boot.lua: initialisation filesystem universelle appliquée à l'offset {pos}.")
    else:
        print(" -> boot.lua: bloc filesystem déjà patché ou format personnalisé.")

    # 2. Patch du mode de secours de l'erreur handler (800x600 -> 400x240)
    err_target = b"pcall(love.window.setMode, 800, 600)"
    err_repl   = b"pcall(love.window.setMode, 400, 240)"
    err_pos = content.find(err_target)
    if err_pos != -1:
        content[err_pos:err_pos + len(err_target)] = err_repl
        print(f" -> boot.lua: écran d'erreur 3DS (400x240) patché à l'offset {err_pos}.")
    else:
        print(" -> boot.lua: écran d'erreur déjà patché en 400x240.")

    return content

# -------------------------------------------------------------
# 4. Construction d'Arch3ro.3dsx
# -------------------------------------------------------------
print("\n[3/5] Construction d'Arch3ro.3dsx...")
base_3dsx_path = os.path.join(TOOLS_DIR, ".templates", "lovepotion.3dsx")
with open(base_3dsx_path, "rb") as f:
    raw_3dsx = bytearray(f.read())

# Patch 1: NOP mcuHwcInit à l'offset 74152 (0x121a8)
instr = struct.unpack_from("<I", raw_3dsx, 74152)[0]
if instr == 0xebffff56:
    struct.pack_into("<I", raw_3dsx, 74152, 0xe1a00000)
    print(" -> NOP mcuHwcInit appliqué sur le 3DSX (offset 74152).")
elif instr == 0xe1a00000:
    print(" -> NOP mcuHwcInit déjà présent sur le 3DSX.")

# Patch 2: NOP __PHYSFS_platformCalcBaseDir à l'offset 0xb9448 (758856)
instr_phys = struct.unpack_from("<I", raw_3dsx, 0xb9448)[0]
if instr_phys == 0x1a00001e:
    struct.pack_into("<I", raw_3dsx, 0xb9448, 0xe1a00000)
    print(" -> NOP __PHYSFS_platformCalcBaseDir appliqué sur le 3DSX (offset 0xb9448).")
elif instr_phys == 0xe1a00000:
    print(" -> NOP __PHYSFS_platformCalcBaseDir déjà présent sur le 3DSX.")

# Patch 3: Patch boot.lua (initialisation sdmc/romfs + setMode 400x240)
raw_3dsx = patch_boot_lua(raw_3dsx)

# Remplacement du SMDH officiel CTR dans le binaire 3DSX
smdh_off, smdh_sz, fs_off = struct.unpack_from("<III", raw_3dsx, 32)
if smdh_sz == len(smdh_bytes):
    raw_3dsx[smdh_off:smdh_off + smdh_sz] = smdh_bytes
    print(f" -> SMDH Arch3ro inséré à l'offset {smdh_off}.")

# Fusion avec l'archive .love
with open(love_archive_path, "rb") as f:
    zip_bytes = f.read()

out_3dsx = os.path.join(ROOT_DIR, "Arch3ro.3dsx")
with open(out_3dsx, "wb") as f:
    f.write(raw_3dsx + zip_bytes)

size_3dsx = os.path.getsize(out_3dsx)
print(f" -> SUCCÈS : Arch3ro.3dsx généré ({size_3dsx / (1024*1024):.2f} Mo)")

if FAST:
    os.makedirs(SDMC_3DS_DIR, exist_ok=True)
    shutil.copyfile(out_3dsx, os.path.join(SDMC_3DS_DIR, "Arch3ro.3dsx"))
    print("\n --fast : Arch3ro.3dsx copié dans la SD de l'émulateur.")
    sys.exit(0)

# -------------------------------------------------------------
# 5. Construction d'Arch3ro.cia
# -------------------------------------------------------------
print("\n[4/5] Construction d'Arch3ro.cia...")
base_elf_path = os.path.join(TOOLS_DIR, ".templates", "lovepotion.elf")
with open(base_elf_path, "rb") as f:
    raw_elf = bytearray(f.read())

# Résolution des segments ELF
out = subprocess.run(["readelf", "-lW", base_elf_path], capture_output=True, text=True).stdout
segs = []
for line in out.splitlines():
    p = line.split()
    if len(p) >= 6 and p[0] == "LOAD":
        segs.append((int(p[1], 16), int(p[2], 16), int(p[4], 16)))

def v2f(v):
    for off, va, sz in segs:
        if va <= v < va + sz:
            return off + (v - va)
    raise KeyError(hex(v))

# Patch 1: NOP mcuHwcInit dans l'ELF (VA 0x00112164)
o_mcu = v2f(0x00112164)
cur_elf_instr = struct.unpack_from("<I", raw_elf, o_mcu)[0]
if cur_elf_instr == 0xebffff56:
    struct.pack_into("<I", raw_elf, o_mcu, 0xe1a00000)
    print(f" -> NOP mcuHwcInit appliqué sur l'ELF (offset {hex(o_mcu)}).")
elif cur_elf_instr == 0xe1a00000:
    print(" -> NOP mcuHwcInit déjà présent sur l'ELF.")

# Patch 2: NOP __PHYSFS_platformCalcBaseDir dans l'ELF (VA 0x1b9404)
o_calc = v2f(0x1b9404)
cur_calc_instr = struct.unpack_from("<I", raw_elf, o_calc)[0]
if cur_calc_instr == 0x1a00001e:
    struct.pack_into("<I", raw_elf, o_calc, 0xe1a00000)
    print(f" -> NOP __PHYSFS_platformCalcBaseDir appliqué sur l'ELF (offset {hex(o_calc)}).")
elif cur_calc_instr == 0xe1a00000:
    print(" -> NOP __PHYSFS_platformCalcBaseDir déjà présent sur l'ELF.")

# Patch 3: Patch boot.lua dans l'ELF
raw_elf = patch_boot_lua(raw_elf)

cia_elf_path = os.path.join(TOOLS_DIR, ".templates", "lovepotion_cia.elf")
with open(cia_elf_path, "wb") as f:
    f.write(raw_elf)

# Exécution de makerom
out_cia = os.path.join(ROOT_DIR, "Arch3ro.cia")
cmd_makerom = [
    os.path.join(TOOLS_DIR, "makerom"),
    "-f", "cia",
    "-o", out_cia,
    "-rsf", os.path.join(TOOLS_DIR, "app.rsf"),
    "-elf", cia_elf_path,
    "-icon", smdh_path,
    "-target", "t",
    "-exefslogo"
]
if os.path.exists(banner_path):
    cmd_makerom.extend(["-banner", banner_path])

res_make = subprocess.run(cmd_makerom, capture_output=True, text=True)
if res_make.returncode != 0:
    print("ERREUR makerom :", res_make.stderr)
    sys.exit(1)

size_cia = os.path.getsize(out_cia)
print(f" -> SUCCÈS : Arch3ro.cia généré ({size_cia / (1024*1024):.2f} Mo)")

# -------------------------------------------------------------
# 6. Déploiement et Synchronisation SDMC (Émulateur & Tests)
# -------------------------------------------------------------
print("\n[5/5] Synchronisation de l'environnement Citra/Azahar...")
os.makedirs(SDMC_3DS_DIR, exist_ok=True)
os.makedirs(os.path.join(SDMC_3DS_DIR, "Arch3ro"), exist_ok=True)
os.makedirs(os.path.join(SDMC_LP_DIR, "game"), exist_ok=True)

# Copie des binaires 3DSX aux emplacements standards
shutil.copyfile(out_3dsx, os.path.join(SDMC_3DS_DIR, "Arch3ro.3dsx"))
shutil.copyfile(smdh_path, os.path.join(SDMC_3DS_DIR, "Arch3ro.smdh"))
shutil.copyfile(out_3dsx, os.path.join(SDMC_3DS_DIR, "Arch3ro", "Arch3ro.3dsx"))
shutil.copyfile(smdh_path, os.path.join(SDMC_3DS_DIR, "Arch3ro", "Arch3ro.smdh"))
if os.path.exists(banner_path):
    shutil.copyfile(banner_path, os.path.join(SDMC_3DS_DIR, "Arch3ro.bnr"))
    shutil.copyfile(banner_path, os.path.join(SDMC_3DS_DIR, "Arch3ro", "Arch3ro.bnr"))

# Copie de l'archive game.love sur SDMC comme filet de sécurité
shutil.copyfile(love_archive_path, os.path.join(SDMC_LP_DIR, "game.love"))

# Synchronisation des sources dans sdmc/lovepotion/game
game_sdmc = os.path.join(SDMC_LP_DIR, "game")
for item in ["main.lua", "conf.lua"]:
    shutil.copyfile(os.path.join(ROOT_DIR, item), os.path.join(game_sdmc, item))
for folder in ["src", "assets"]:
    src_f = os.path.join(ROOT_DIR, folder)
    dst_f = os.path.join(game_sdmc, folder)
    if os.path.exists(dst_f):
        shutil.rmtree(dst_f)
    shutil.copytree(src_f, dst_f, ignore=shutil.ignore_patterns("*_hd.png", ".DS_Store"))

# Installation du CIA dans Azahar si présent
try:
    inst_res = subprocess.run(["flatpak", "run", "org.azahar_emu.Azahar", "-i", out_cia], capture_output=True, text=True, timeout=15)
    if "Installed CIA successfully" in inst_res.stdout or inst_res.returncode == 0:
        print(" -> Arch3ro.cia installé avec succès dans l'émulateur Azahar.")
except Exception as e:
    print(f" -> Note: installation automatique CIA: {e}")

print("\n" + "=" * 60)
print(" COMPILATION ET INSTALLATION TERMINÉES SANS ERREUR !")
print(" - Fichier 3DSX : Arch3ro.3dsx (HBL / Citra)")
print(" - Fichier CIA  : Arch3ro.cia  (Menu HOME 3DS / Citra)")
print("=" * 60)
