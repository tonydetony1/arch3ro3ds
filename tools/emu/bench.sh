#!/bin/bash
# tools/emu/bench.sh : frame-time benchmark of the 3DSX in Azahar, on a copy of the game that uses its own
# save identity ("arch3ro_bench"), so the real emulator save (sdmc:/3ds/save/arch3ro) is never touched.
#
#   bench.sh ROOM [FLAG...]   build a bench copy, auto-play ROOM for 30 s (src/dev/bench.lua), print the logs
#     FLAG = name of an empty file created in the bench save directory before the run:
#       bench_input  : Circle Pad held (input event every frame -> touch screen redrawn every frame)
#       bench_lprof  : Lua sampling profile          bench_alloc : allocations per function
#   Environment:
#     SEED=file      save copied into the bench save directory before each run; SEED=user copies your
#                    own emulator save (read only, run in progress dropped) for the same hero and gear;
#                    without it the bench save is kept as is
#     NOBUILD=1      reuse the last bench build
#     TREE=dir       bench copy location (default /tmp/arch3ro_bench_tree)
#     NOPERF=1       no perf_log.txt (its write every 3 s stalls a few frames): only the overall FPS
# Needs the virtual display (tools/emu/emu.sh display) and Azahar's CPU clock at the speed to measure
# (100 % = Old 3DS).
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TREE="${TREE:-/tmp/arch3ro_bench_tree}"
B=~/.var/app/org.azahar_emu.Azahar/data/azahar-emu
SV=$B/sdmc/3ds/save/arch3ro_bench
mkdir -p "$TREE" "$SV"

rsync -a --delete --exclude .git --exclude docs --exclude '*.cia' --exclude '*.3dsx' --exclude 'user_game.love' "$ROOT/" "$TREE/"
sed -i 's|t.identity = "arch3ro"|t.identity = "arch3ro_bench"|' "$TREE/conf.lua"
grep -q 't.identity = "arch3ro_bench"' "$TREE/conf.lua" || { echo "could not set the bench save identity"; exit 1; }
# The patched boot.lua mounts sdmc:/3ds/Arch3ro.3dsx when Azahar gives no launch path, so the bench
# build must sit there during the run: the user's copy is set aside and put back on exit
GAME=$B/sdmc/3ds/Arch3ro.3dsx
BENCH_3DSX=$TREE/bench_game.3dsx
USER_3DSX=$TREE/user_game.3dsx
LP_LOVE=$B/sdmc/lovepotion/game.love # also rewritten by build_all.py (fallback archive)
USER_LOVE=$TREE/user_game.love
if [ -f "$GAME" ] && [ ! -f "$USER_3DSX" ]; then cp -p "$GAME" "$USER_3DSX"; fi
if [ -f "$LP_LOVE" ] && [ ! -f "$USER_LOVE" ]; then cp -p "$LP_LOVE" "$USER_LOVE"; fi
restore_user_game() {
  [ -f "$USER_3DSX" ] && mv -f "$USER_3DSX" "$GAME"
  [ -f "$USER_LOVE" ] && mv -f "$USER_LOVE" "$LP_LOVE"
}
trap restore_user_game EXIT
if [ -z "$NOBUILD" ] || [ ! -f "$BENCH_3DSX" ]; then
  (cd "$TREE" && python3 tools/build_all.py --fast --with-bench > "$TREE/bench_build.log" 2>&1) \
    || { tail -20 "$TREE/bench_build.log"; exit 1; }
  cp -p "$TREE/Arch3ro.3dsx" "$BENCH_3DSX"
fi
cp -p "$BENCH_3DSX" "$GAME"

if [ "$SEED" = "user" ]; then
  # Copy of the user's emulator save (read only) without its run in progress: same hero and gear
  python3 - "$B/sdmc/3ds/save/arch3ro/arch3ro_save.lua" "$SV/arch3ro_save.lua" <<'PY'
import sys
out, skip = [], False
for line in open(sys.argv[1]).read().split("\n"):
    if line == "  run = {": skip = True; continue
    if skip:
        if line == "  },": skip = False
        continue
    out.append(line)
open(sys.argv[2], "w").write("\n".join(out))
PY
  cp "$SV/arch3ro_save.lua" "$SV/arch3ro_save_secours.lua"
elif [ -n "$SEED" ]; then
  cp "$SEED" "$SV/arch3ro_save.lua"; cp "$SEED" "$SV/arch3ro_save_secours.lua"
fi
rm -f "$SV"/bench_* "$SV/perf_log.txt" "$SV/error_log.txt" "$SV/boot_profile.txt"
echo "${1:-1}" > "$SV/bench_play"
shift
for f in "$@"; do touch "$SV/$f"; done
if [ -z "$NOPERF" ]; then touch "$SV/perf_on"; else rm -f "$SV/perf_on"; fi

flatpak kill org.azahar_emu.Azahar 2>/dev/null; sleep 1
(DISPLAY=:5 XAUTHORITY= flatpak run --socket=x11 --nosocket=wayland --env=QT_QPA_PLATFORM=xcb \
  org.azahar_emu.Azahar "$GAME" > "$TREE/azahar.log" 2>&1 &)
for _ in $(seq 1 100); do
  sleep 1
  grep -q "FIN" "$SV/bench_log.txt" 2>/dev/null && break
  [ -f "$SV/error_log.txt" ] && break
done
sleep 1
flatpak kill org.azahar_emu.Azahar 2>/dev/null; pkill -9 zenity 2>/dev/null
rm -f "$SV/bench_play" "$SV/bench_input" "$SV/bench_lprof" "$SV/bench_alloc"

[ -f "$SV/error_log.txt" ] && { echo "=== ERROR ==="; head -8 "$SV/error_log.txt"; }
echo "=== $(grep FIN "$SV/bench_log.txt" 2>/dev/null || echo 'no FIN line') ==="
grep -E "^\[game\]" "$SV/perf_log.txt" 2>/dev/null | sed -E 's/  (sommets|images).*//' | tail -8
grep "sections" "$SV/perf_log.txt" 2>/dev/null | tail -1 | tr -s ' ' | fold -w 200
exit 0
