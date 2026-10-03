#!/usr/bin/env bash
# ==============================================================================
# Arch3ro 3DS - Script de lancement PC Desktop (LÖVE 11.x)
# Usage:
#   ./run.sh              -> Lancement standard
#   ./run.sh --sim3ds     -> Simulation des contraintes GPU PICA200 de la 3DS
#   ./run.sh --gpustats   -> Affichage de l'overlay temps réel FPS / GPU
#   ./run.sh --bench      -> Lancement du banc de test automatisé
#   ./run.sh --test       -> Mode autotest
# ==============================================================================

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

# Détection de l'exécutable LÖVE
LOVE_BIN=""

if [ -x "$HOME/AppImages/löve.appimage" ]; then
    LOVE_BIN="$HOME/AppImages/löve.appimage"
elif [ -x "$HOME/AppImages/love.appimage" ]; then
    LOVE_BIN="$HOME/AppImages/love.appimage"
elif command -v love >/dev/null 2>&1; then
    LOVE_BIN="love"
fi

if [ -z "$LOVE_BIN" ]; then
    echo "❌ Erreur: Impossible de trouver l'exécutable LÖVE 2D."
    echo "   Veuillez installer love (ex: sudo apt install love) ou placer löve.appimage dans ~/AppImages/"
    exit 1
fi

exec "$LOVE_BIN" . "$@"
