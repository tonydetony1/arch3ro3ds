# Chantier 1 — Rencontres : vagues, rôles, élites, champions

Date : 2026-10-03 · Statut : validé (l'utilisateur a délégué la conception)

## Objectif

Rendre les salles de combat variées et exigeantes **sans augmenter le nombre de monstres
affichés en même temps** (contrainte Old 3DS : le nombre de monstres est le premier coût
processeur). Le défi vient des compositions, des renforts et des élites, pas de la masse.

Choix de l'utilisateur :
- adresse d'abord, stratégie ensuite (chantier 3) ;
- courbe progressive, mode Difficile à débloquer plus tard (chantier 4) ;
- graphismes existants + quelques petits sprites (icônes d'affixes) ;
- au plus 7 monstres actifs à la fois, renforts en vagues.

Hors périmètre : patterns des boss (chantier 2), objectifs/modificateurs de salle
(chantier 3), mode Difficile (chantier 4), Survie et Boss Rush (inchangés). Les salles de boss
gardent leur génération actuelle.

## Constat de départ

- Une salle = une vague unique de 4 à 10 monstres en couronne, types pris en rotation dans le
  groupe du chapitre ; seule la quantité et les PV augmentent.
- La branche « mini-boss toutes les 5 salles » de `WorldManager.generateWave` est morte : les
  salles 5, 15, 25… sont des sanctuaires traités avant.

## 1. Rôles et budget de menace (`src/data/encounters.lua`)

| Rôle | Types (coût de menace) | Effet de jeu |
|---|---|---|
| tank | slime 2, splitter 3, gargoyle 2.5, golem 3 | avance, encaisse, bloque |
| harasser | bat 1, wolf 1.5, raven 1 | charge, force à bouger |
| shooter | skeleton 2, mage 2, frost_wraith 2.5 | lignes de tir, punit l'immobilité |
| zone | plant 1.5, turret 2, bomber 1.5, wisp 1.5 | salves, bombes, zones dangereuses |
| special | burrower 2.5, summoner 2.5 | embuscade, renforts : cible prioritaire |

`mini_slime` (enfant du splitter) n'est jamais tiré directement.

Budget d'une salle : `budget = (6 + 0.5 × (salle − 1)) × difficulté` (difficulté = 1 ; le
chantier 4 l'augmentera). Salle 1 ≈ 6 (4 monstres simples), salle 49 ≈ 30.

## 2. Composition (`src/core/encounter_director.lua`, fonctions pures)

`Director.compose(chapterIndex, roomNumber, opts) → { waves = { {spawn…}, … }, signature, eliteCount }`
où `spawn = { type, hpWeight, affixes?, champion? }` (positions et PV calculés ensuite).

- **Nombre de vagues** : 1 si budget < 9, 2 si < 18, sinon 3. Budget réparti 100 % /
  55-45 % / 40-30-30 %. Au-delà d'un budget de 34 (Abysse), le surplus devient un
  multiplicateur de PV (`1 + surplus / 34`) au lieu de monstres en plus.
- **Au plus 7 monstres par vague**, 16 au total par salle.
- **Règles** :
  1. chaque vague commence par un monstre de pression (tank ou harasser) ;
  2. au plus 1 invocateur par vague ; au plus 2 tireurs par vague aux chapitres 1-2, 3 ensuite ;
  3. **signature** : chaque salle a un rôle dominant (poids ×3), différent de la salle
     précédente (calculé sur les rôles de tout le groupe du chapitre) ;
  4. au plus 3 exemplaires du même type par vague (variété) ;
  5. **première apparition** d'un type dans le chapitre : budget de la salle × 0.8, et ce type
     ne peut pas être élite dans cette salle ; il est ajouté même au-delà du budget de la vague,
     et l'ancre de la vague est choisie parmi les autres types.
- **Déterminisme** : générateur LCG local initialisé par (chapitre, salle) ; aucun
  `math.random`. Même salle → mêmes rencontres (reprise de partie, préparation en fond).

## 3. Élites et champions

Nombre d'élites par salle : 0 en salles 1-3 ; 1 une salle sur deux en 4-19 ; 1 par salle en
20-39 ; 2 en 40-59 ; 3 au-delà (Abysse). Placés de préférence dans la dernière vague. Une élite
coûte 2 × le coût de son type et reçoit un poids de PV × 2.2.

| Affixe | Effet | Anneau | Rôles autorisés |
|---|---|---|---|
| swift | vitesse × 1.35, cadence d'attaque × 1/0.75 | yellow | tank, harasser, shooter |
| shielded | bouclier = 35 % des PV max, absorbé avant les PV | blue | tous |
| volatile | à la mort : explosion télégraphiée 0.9 s, rayon 46 | orange | tous |
| regenerating | 4 % PV max/s après 2 s sans être touché | leaf | tank, zone, special |
| enraged | sous 50 % PV : vitesse × 1.4, cadence × 1/0.7 | red | tous |
| frost | ses tirs ralentissent le héros (× 0.6 pendant 1.5 s) | cyan | shooter, zone |

**Champion** (salles 7, 17, 27… : remplace le mini-boss mort) : dernière vague = un tank du
chapitre (s'il n'y en a pas, comme au chapitre 2 : le harceleur le plus coûteux) avec 2 affixes, poids de PV × 4, bannière « CHAMPION », barre de vie large. Pas un
boss (pas de démon, pas de roue).

Rendu (`src/render/monsters.lua`) : anneau pré-teinté `fx_ring_<couleur>` aplati sous
l'élite (dans le lot de sprites), barre de vie toujours visible en ambre, icône(s) d'affixe
7×7 (`icon_affix_<nom>`, nouveaux sprites) à gauche de la barre. Étiquette flottante du nom
de l'affixe à l'apparition.

## 4. Vagues en jeu (`src/core/wave_runner.lua`)

- Vague 1 : comme aujourd'hui (runes au sol 0.55 s puis apparition).
- Vague suivante dès que **≤ 2 monstres** restent en vie, ou après **14 s** ; seulement autant de
  monstres que la place sous le plafond de 7 (le reste attend le déclenchement suivant).
- Annonce : bannière « WAVE 2/3 », runes au sol pendant 1.0 s.
- Position des renforts : couronne de la salle, mais toute position à moins de 110 px du héros
  est renvoyée de l'autre côté du centre, puis `findFreeSpot`.
- La porte ne s'ouvre qu'une fois toutes les vagues vaincues. HUD : « WAVE x/y » sous l'étage.

## 5. PV

PV totaux de la salle = `1.3 × WorldManager.hpBudget(baseHp, clamp(nb monstres, 4, 10))` ×
multiplicateur d'Abysse, répartis selon les poids (archétype × élite × champion) via
`distributeHp`. Le total augmente d'environ 30 % par rapport à aujourd'hui, mais il est réparti
sur des vagues ; la pression vient des compositions. Constante `Balance.ENCOUNTER.hpMult`.

## 6. Intégration

- `WorldManager.generateEncounter(chapter, room, mapW, mapH)` → `{ waves }`, chap ; utilisé
  pour les salles de combat (Ascension et Abysse). Salles de boss : génération actuelle
  enveloppée dans une vague unique.
- `GameState` : file de vagues, renforts, application des élites à l'apparition, condition
  de porte, HUD.
- `Dummy` : champs d'élite remis à zéro au `spawn`, crochets dans `update` (régénération,
  rage) et `takeDamage` (bouclier) ; contexte « tireur courant » pour marquer les tirs givrants.
- `Projectile` : drapeau `chill` ; `Player` : `chillTimer` appliqué à la vitesse.
- Aucune allocation par image : tout est créé à l'apparition des monstres.

## 7. Tests

Autotest (`src/dev/selftest.lua`) :
- directeur, salles 1-150 : budget respecté, ≤ 7 par vague, ≤ 16 par salle, règles 1-4,
  types du groupe du chapitre, déterminisme, élites selon le barème, champion en salle x7 ;
- vagues simulées : déclenchement à ≤ 2 vivants et à 14 s, plafond 7, porte fermée tant
  qu'il reste des vagues ;
- affixes : bouclier, régénération, rage, explosion différée, ralentissement du héros.

Mesures : banc `--roomload` (pas de régression), salle 48 dans Azahar (FPS ≥ avant), capture
d'écran d'une élite et d'un champion.
