#!/usr/bin/env bash
set -e

SDMC_3DS="$HOME/.var/app/org.azahar_emu.Azahar/data/azahar-emu/sdmc/3ds"
TARGET="$SDMC_3DS/Arch3ro.3dsx"
PORT=24714

echo "Starting Azahar with GDB port $PORT..."
flatpak run org.azahar_emu.Azahar -g $PORT "$TARGET" &
EMU_PID=$!

trap "kill -9 $EMU_PID 2>/dev/null || true" EXIT

sleep 2

cat << 'EOF' > /tmp/gdb_script.txt
set architecture arm
file tools/.templates/lovepotion.elf
target remote localhost:24714

b *0x0015d3c8
commands
  print "[1] HIT Wrap_Window::SetMode (boot.lua)!"
  c
end

b *0x00146730
commands
  print "[2] HIT Wrap_Graphics::SetDefaultFilter (main.lua: love.load)!"
  c
end

b *0x00149fc0
commands
  print "[2.5] HIT Wrap_Graphics::NewImage!"
  c
end

b *0x001497c0
commands
  print "[3] HIT Wrap_Graphics::NewCanvas (art.lua: love.load)!"
  c
end

b *0x00174e90
commands
  print "[ERROR] HIT ImageData::Decode THROW EXCEPTION!"
  c
end

b *0x2ebce8
commands
  set $L = $r0
  set $top = *(unsigned int*)($L + 8)
  set $tval = $top - 16
  set $tstr = *(unsigned int*)$tval
  set $str_chars = $tstr + 16
  printf "[ERROR] LUA ERROR: %s\n", (char*)$str_chars
  c
end

c
EOF

gdb -batch -x /tmp/gdb_script.txt || true
