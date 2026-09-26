#!/usr/bin/env bash
# tools/run_citra.sh
# Script pour compiler (3DSX + CIA) et lancer Arch3ro dans Citra / Azahar

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

SDMC_3DS="$HOME/.var/app/org.azahar_emu.Azahar/data/azahar-emu/sdmc/3ds"
mkdir -p "$SDMC_3DS"
touch "$SDMC_3DS/dspfirm.cdc"

echo "=========================================="
echo " 1. Compilation unifiée (3DSX & CIA)      "
echo "=========================================="
python3 tools/build_all.py

echo ""
echo "=========================================="
echo " 2. Lancement dans Citra / Azahar         "
echo "=========================================="

if [ "$1" == "--cia" ]; then
    APP_PATH=$(find "$HOME/.var/app/org.azahar_emu.Azahar/data/azahar-emu/sdmc/Nintendo 3DS/" -name "*.app" | head -n 1)
    echo "Lancement du titre CIA installé : $APP_PATH"
    flatpak run org.azahar_emu.Azahar "$APP_PATH"
else
    echo "Lancement du Homebrew 3DSX : $SDMC_3DS/Arch3ro.3dsx"
    flatpak run org.azahar_emu.Azahar "$SDMC_3DS/Arch3ro.3dsx"
fi
