# Chantier 5 — Sanctuaires de l'Ange et du Démon

Date : 2026-10-04 · Statut : validé (l'utilisateur a approuvé les deux sections du design)

## Constat

L'Ange (salles 5, 15, 25…) s'installe dans une salle de combat ordinaire, au décor du chapitre.
Le Démon surgit dans la salle du boss vaincu, en surimpression. Ni l'un ni l'autre n'a de lieu
propre. L'offre s'ouvre dès l'entrée, sans que le joueur ait à s'avancer.

## Décisions

| Sujet | Choix |
|---|---|
| Placement | Ange : salles 5, 15, 25, 35, 45. Démon : salles 9, 19, 29, 39, 49 (juste avant chaque boss) |
| Après un boss | Plus de Démon : roue de boss directement, puis la porte |
| Modes | Ascension et Abysse suivent ces numéros ; Boss Rush et Arène inchangés |
| Taille | Un écran : 400 × 240, caméra fixe |
| Interaction | Le héros s'approche du personnage (rayon 40 px) : l'offre s'ouvre, le jeu se met en pause |
| Sortie | Porte nord ouverte dès l'entrée ; aller à la porte sans s'approcher = ignorer l'offre |
| Récompenses | Inchangées : Ange = soin 40 % ou bénédiction ; Démon = pacte (accepter / refuser) |
| Décors | Nouveaux éléments pixel art générés en code, ajoutés à l'atlas |
| Musique | Musique calme du menu (`hub`) dans les deux sanctuaires |

Les salles 9, 19… comptent dans « STAGE X/50 » comme les autres : elles remplacent la salle de
combat qui précédait le boss.

## Déroulé dans une salle

1. Fondu d'entrée. Le héros apparaît en bas, au centre. Pas de monstre, pas d'obstacle.
2. Le personnage (`npc_angel` ou `npc_devil`) flotte au centre de la salle, sur son autel.
3. Le héros arrive à moins de 40 px du personnage : l'offre s'ouvre sur l'écran tactile (cartes
   actuelles de `SpecialRoomManager`), le jeu se fige comme pendant un tirage de compétence.
4. Choix fait (ou pacte refusé) : le personnage disparaît dans un nuage de particules, l'autel
   s'éteint. Le héros sort par la porte nord.
5. Le héros peut aussi aller directement à la porte : l'offre est perdue.

L'offre ne s'ouvre qu'une fois par salle.

## Décors

**Ciel (Ange)**
- Sol : mer de nuages. Chemin de dalles de marbre blanc bordées d'or, de l'entrée à l'autel puis
  à la porte.
- Centre : estrade ronde en marbre doré, halo de lumière qui pulse.
- Bords : 4 colonnes de marbre à chapiteau doré, porte nord en arche lumineuse.
- Animé : petits nuages qui dérivent, rayons de lumière obliques qui oscillent, étoiles et plumes
  dorées qui tombent.

**Enfer (Démon)**
- Sol : basalte noir fissuré, fissures de lave à lueur orange.
- Centre : cercle runique rouge en obsidienne.
- Bords : piliers d'obsidienne à runes rouges, coulées de lave, 4 braseros.
- Animé : flammes des braseros (3 ou 4 images), lueur des fissures qui respire, braises qui
  montent.

## Architecture

| Fichier | Rôle |
|---|---|
| `src/render/sprites/sanctuary.lua` (nouveau) | Sprites procéduraux : tuiles nuage et basalte, dalles, colonnes, piliers, autels, braseros (images de flamme), halo, rayon |
| `src/render/sanctuary.lua` (nouveau) | Rendu d'un sanctuaire : décor fixe pré-rendu une fois sur un canevas, éléments animés dessinés à chaque image |
| `src/core/world_manager.lua` | `getRoomType` renvoie `"devil"` pour les salles 9, 19… ; aucune vague pour `angel` et `devil` |
| `src/data/rooms.lua` | Taille des sanctuaires (400 × 240) |
| `src/states/game.lua` | `roomSpec` / `setupRoom` : sanctuaire pour `angel` et `devil` ; porte ouverte d'entrée ; boss → roue directe |
| `src/core/special_room_manager.lua` | Personnage au centre de la salle ; état « en attente d'approche » avant d'ouvrir l'offre |

`src/render/arena.lua` (545 lignes) n'est pas agrandi : il délègue au nouveau module quand la salle
est un sanctuaire. Le Démon d'après-boss (déclenchement dans `game.lua`, phase `devil` en salle de
boss) est supprimé ; la roue de boss se déclenche à la fin du combat.

## Performance

Le décor fixe tient dans un canevas de 400 × 240. Par image : halo, rayons, nuages ou flammes,
moins de 1 000 sommets au total (limite LÖVE Potion : 24 576). Les particules réutilisent celles,
pré-allouées, de `SpecialRoomManager` : aucune allocation par image.

## Tests

- Unitaires (`tests/`, Lua 5.1) : `getRoomType` (4 → combat, 5 → angel, 9 → devil, 10 → boss) ;
  aucune vague générée pour une salle Ange ou Démon.
- Autotest PC (`src/dev/selftest.lua`) : salle 9 sans monstre, porte ouverte ; l'offre reste fermée
  loin du Démon et s'ouvre à moins de 40 px ; refus du pacte → personnage parti ; boss vaincu → roue
  de boss sans Démon.
- Azahar : captures des deux sanctuaires, FPS et rejets de sommets (journal de perf).
