#!/bin/bash
# tools/emu/emu.sh : tests headless d'Arch3ro dans Azahar (flatpak)
#   emu.sh display       : crée l'écran virtuel :5 (mutter headless + Xwayland non-rootless)
#   emu.sh start         : lance Arch3ro.3dsx sur :5 et attend le menu (lit boot_profile.txt)
#   emu.sh shot NOM      : capture haut+bas (400x480) dans $OUT/NOM.png
#   emu.sh play [s] [n]  : build rapide, lance, démarre une partie, joue s secondes, affiche perf_log
#   emu.sh stop          : ferme l'émulateur
B=~/.var/app/org.azahar_emu.Azahar/data/azahar-emu
SV=$B/sdmc/3ds/save/arch3ro
OUT=${OUT:-/tmp/arch3ro_emu}
mkdir -p "$OUT"
case "$1" in
display)
  if [ -S /tmp/.X11-unix/X5 ] && pgrep -f "Xwayland :5" > /dev/null; then echo "écran :5 déjà actif"; exit 0; fi
  rm -f /tmp/.X11-unix/X5 /tmp/.X5-lock
  setsid nohup mutter --headless --virtual-monitor 1280x720 --wayland-display=arch3ro-wl > "$OUT/mutter.log" 2>&1 < /dev/null &
  sleep 5
  (WAYLAND_DISPLAY=arch3ro-wl setsid Xwayland :5 -geometry 1280x720 -noreset -ac > "$OUT/xwayland.log" 2>&1 &)
  sleep 3; ls /tmp/.X11-unix/X5 ;;
start)
  flatpak kill org.azahar_emu.Azahar 2>/dev/null; sleep 1
  rm -f "$SV/boot_profile.txt"
  export DISPLAY=:5; unset XAUTHORITY
  (flatpak run --socket=x11 --nosocket=wayland --env=QT_QPA_PLATFORM=xcb org.azahar_emu.Azahar "$B/sdmc/3ds/Arch3ro.3dsx" > "$OUT/azahar.txt" 2>&1 &)
  T0=$(date +%s)
  for i in $(seq 1 120); do
    sleep 1
    if [ -f "$SV/boot_profile.txt" ]; then echo "menu après $(( $(date +%s) - T0 )) s"; cat "$SV/boot_profile.txt"; exit 0; fi
  done
  echo "TIMEOUT"; head "$SV/error_log.txt" 2>/dev/null ;;
shot)
  DISPLAY=:5 ffmpeg -loglevel error -y -f x11grab -video_size 400x480 -i :5+440,183 -frames:v 1 "$OUT/$2.png" ;;
fps)
  DISPLAY=:5 ffmpeg -loglevel error -y -f x11grab -video_size 640x30 -i :5+420,665 -frames:v 1 "$OUT/$2.png" ;;
play)
  cd "$(dirname "$0")/../.."
  python3 tools/build_all.py --fast > "$OUT/build.log" 2>&1 || { tail "$OUT/build.log"; exit 1; }
  "$0" start | head -1; sleep 7
  X="$(dirname "$0")/xin.py"
  "$X" click 690 570; sleep 2; "$X" click 640 625; sleep 5; "$X" click 640 625
  sleep "${2:-13}"
  tail -"${3:-4}" "$SV/perf_log.txt" | cut -c1-300
  [ -f "$SV/error_log.txt" ] && head -3 "$SV/error_log.txt"
  exit 0 ;;
stop)
  flatpak kill org.azahar_emu.Azahar 2>/dev/null; pkill -9 zenity 2>/dev/null; exit 0 ;;
*) sed -n 2,7p "$0" ;;
esac
