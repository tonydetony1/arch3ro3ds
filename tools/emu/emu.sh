#!/bin/bash
# tools/emu/emu.sh : tests headless d'Arch3ro dans Azahar (flatpak)
#   emu.sh display       : crée l'écran virtuel :5 (mutter headless + Xwayland non-rootless)
#   emu.sh start         : lance Arch3ro.3dsx sur :5 et attend le menu (lit boot_profile.txt)
#   emu.sh shot NOM      : capture haut+bas (400x480) dans $OUT/NOM.png
#   emu.sh stop          : ferme l'émulateur
B=~/.var/app/org.azahar_emu.Azahar/data/azahar-emu
SV=$B/sdmc/3ds/save/arch3ro
OUT=${OUT:-/tmp/arch3ro_emu}
mkdir -p "$OUT"
case "$1" in
display)
  if [ -S /tmp/.X11-unix/X5 ]; then echo "écran :5 déjà actif"; exit 0; fi
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
stop)
  flatpak kill org.azahar_emu.Azahar 2>/dev/null; pkill -9 zenity 2>/dev/null; exit 0 ;;
*) sed -n 2,7p "$0" ;;
esac
