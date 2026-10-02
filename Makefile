# ==============================================================================
# Arch3ro 3DS - Makefile
# Commandes pratiques pour exécuter, tester et compiler le jeu
# ==============================================================================

.PHONY: all run sim stats bench test build build-fast citra clean help

# Cible par défaut : lancer le jeu
all: run

## Lance le jeu sur PC (LÖVE 2D)
run:
	@./run.sh

## Lance le jeu en simulant les limites GPU PICA200 de la 3DS
sim:
	@./run.sh --sim3ds

## Lance le jeu avec l'overlay temps réel FPS / sommets GPU
stats:
	@./run.sh --sim3ds --gpustats

## Exécute le banc de test automatisé de performance
bench:
	@./run.sh --bench

## Exécute la suite d'autotests
test:
	@./run.sh --test

## Compile les packages Nintendo 3DS (.3dsx et .cia)
build:
	@python3 tools/build_all.py

## Compilation rapide pour itération (.3dsx uniquement, sans CIA ni bake)
build-fast:
	@python3 tools/build_all.py --fast

## Démarre le jeu sous l'émulateur Citra / Azahar
citra:
	@./tools/run_citra.sh

## Nettoie les fichiers temporaires et les journaux de test
clean:
	@rm -rf logs/* tools/romfs_dir/game.love tools/__pycache__ *.tmp
	@echo "✨ Répertoire nettoyé."

## Affiche l'aide
help:
	@echo "Usage : make [cible]"
	@echo ""
	@echo "Cibles disponibles :"
	@echo "  run         Lancer le jeu sur PC (LÖVE 2D)"
	@echo "  sim         Lancer avec simulation GPU 3DS"
	@echo "  stats       Lancer avec télémétrie FPS et sommets GPU"
	@echo "  bench       Exécuter le banc de test de performance"
	@echo "  test        Exécuter la suite d'autotests"
	@echo "  build       Compiler Arch3ro.3dsx et Arch3ro.cia"
	@echo "  build-fast  Compilation rapide itérative (.3dsx)"
	@echo "  citra       Lancer le jeu dans l'émulateur Citra / Azahar"
	@echo "  clean       Nettoyer les fichiers de cache et journaux temporaires"
