# Chantier 6 — Diversité des mondes : salles et décors propres à chaque monde

Date : 2026-10-04 · Statut : validé (l'utilisateur a approuvé les deux sections du design)

## Constat

Les 6 mondes (Forêt, Désert, Cavernes de cristal, Volcan, Îles célestes, Vide) tirent leurs
salles de combat dans les **mêmes 18 grilles** (`src/data/rooms.lua`). Seuls changent la palette
du décor et la nature des zones `h` (sable, glace, lave, vent, vide). Les obstacles ont la même
forme partout (souche, bloc), seulement recolorée. Le joueur a l'impression de revoir les mêmes
salles d'un monde à l'autre.

## Décisions

| Sujet | Choix |
|---|---|
| Quantité | 4 salles propres à chaque monde (24 au total), dont une salle « totale » |
| Création | Grilles dessinées à la main, au format actuel (13 × 9), marquées par monde |
| Tirage | Par chapitre : 4 salles du monde + 4 du pool commun parmi les 8 combats |
| Obstacles | Forme propre au monde ; collisions inchangées |
| Décors au sol | Éléments sans collision propres au monde, pré-rendus sur le fond de la salle |

## Salles par monde

| Monde | Salle totale | Autres salles |
|---|---|---|
| 1 Forêt | Marais : eau presque partout, îlots reliés par des sentiers | Clairière aux souches, Ruisseau sinueux, Bosquet en couloirs |
| 2 Désert | Mer de sable : sables mouvants partout sauf des chemins de pierre | Oasis, Canyon, Dunes en diagonale |
| 3 Cristal | Patinoire : sol entièrement en glace, quelques piliers | Lac gelé, Forêt de cristaux, Couloirs glacés |
| 4 Volcan | Rivières de lave : lave partout, ponts de pierre étroits | Caldeira, Coulées, Forge (barils + lave) |
| 5 Ciel | Tempête : bourrasques partout, directions alternées | Archipel, Couloir des vents, Temple flottant |
| 6 Vide | Fracture : failles en damier, cases sûres | Spirale, Œil, Labyrinthe brisé |

Règles d'équité :
- Salles totales qui blessent (lave, Vide) : chemins sûrs d'au moins 2 cases de large entre
  l'entrée, la porte et chaque zone de combat ; repères `m` uniquement sur sol sûr.
- La patinoire (glace) et la tempête (vent) ne blessent pas : surface entière autorisée.
- Toutes les grilles passent `Rooms.validate` : porte atteignable, aucune poche fermée,
  au plus `Rooms.MAX_ROCK_RECTS` (10) rectangles de rochers.

## Tirage

`Rooms.pick(kind, roomNumber, world)` reçoit le monde de la salle (`chapterIndex` de
`GameState:roomSpec`, plafonné à 6 comme aujourd'hui). Pour un chapitre :
- les 8 emplacements de combat reçoivent les 4 salles du monde et 4 salles du pool commun
  éligible (`minRoom`), dans un ordre mélangé à graine fixe (même chapitre → même ordre) ;
- la salle totale apparaît exactement une fois par chapitre ;
- aucune grille n'est répétée dans un chapitre ; une salle sur deux reste jouée en miroir.

Les arènes (boss, roue, survie) et les sanctuaires ne changent pas.

## Correctif lié : poussée du vent

`ObstacleManager:update` déplace le héros pris dans une bourrasque en écrivant directement sa
position, sans collision : il peut être collé dans un rocher. La salle Tempête multiplie ce
risque. La poussée passe désormais par `Physics.moveAndSlide`.

## Obstacles et décors par monde

| Monde | Petit obstacle (1 case) | Gros blocs | Décors au sol |
|---|---|---|---|
| Forêt | souche moussue (actuelle) | pierre moussue | fleurs, champignons, touffes d'herbe |
| Désert | cactus | grès en briques | os, herbes sèches, cailloux |
| Cristal | pic de glace | blocs de glace | éclats de cristal, givre |
| Volcan | roche d'obsidienne à veines rouges | basalte | cendres, fissures, branches calcinées |
| Ciel | pierre flottante | marbre | plumes, petits nuages, fleurs blanches |
| Vide | monolithe à œil violet | cristal sombre | débris, runes, herbe violette |

- Les rectangles de collision ne changent pas : seule l'image dessinée change.
- Décors au sol et 2 ou 3 variantes de dalles par monde : pré-rendus une fois sur le canevas
  de la salle (`Arena:buildCanvas`), aucun coût par image.
- Sprites procéduraux (comme `src/render/sprites/props.lua`), dans un nouveau fichier
  `src/render/sprites/biomes.lua`, ajoutés à l'atlas. Budget : la place libre de l'atlas
  (1024 × 320) est partagée avec le chantier 5 (sanctuaires) ; la précompilation échoue si
  l'atlas déborde.

## Architecture

| Fichier | Changement |
|---|---|
| `src/data/rooms.lua` | 24 grilles marquées `world = 1..6` (`total = true` pour la salle totale) ; `Rooms.pick` avec le monde |
| `src/states/game.lua` | `roomSpec` transmet le monde au tirage |
| `src/core/obstacle_manager.lua` | Poussée du vent via `moveAndSlide` ; sprite d'obstacle choisi selon le monde |
| `src/render/sprites/biomes.lua` (nouveau) | Obstacles, dalles et décors au sol par monde |
| `src/render/arena.lua` | Semis des décors au sol et des variantes de dalles du monde |

## Tests

- Unitaires (`tests/`, Lua 5.1) : pour chaque chapitre 1 à 6, les 8 combats contiennent les
  4 salles du monde dont une seule totale, aucune grille répétée, tirage identique d'une
  exécution à l'autre ; le vent ne fait pas entrer le héros dans un rocher.
- Autotest PC : `Rooms.validateAll` couvre les 24 nouvelles grilles.
- Azahar : capture de la salle totale de chaque monde, FPS et rejets de sommets (journal de
  perf).
