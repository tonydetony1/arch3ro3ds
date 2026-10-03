# Chantier 2 — Boss : attaques propres et trois phases

Date : 2026-10-03 · Statut : validé (l'utilisateur a approuvé la proposition)

## Constat

Les 6 boss réutilisent l'IA des monstres normaux (golem, mage) ; leur seule évolution est une
« rage » à 50 % (vitesse + cadence). Les dégâts de leurs tirs sont fixes (16-22) du chapitre 1 au
chapitre 6 alors que les PV du héros augmentent.

## Architecture

| Fichier | Rôle |
|---|---|
| `src/data/bosses.lua` | Fiches des boss : 3 phases, déplacement, cycle d'attaques ; catalogue d'attaques |
| `src/core/boss_brain.lua` | Machine d'états pure : phases, télégraphe → exécution → récupération |
| `src/core/ai_controller.lua` | Branche les boss sur le cerveau, fournit le contexte (tirs, bombes, invocations, effets) |

Le cerveau ne dépend ni de LÖVE ni des modules de rendu : tout effet passe par un **contexte**
(`ctx`) fourni par l'IA : `fire`, `lob`, `summon`, `move`, `contact`, `shotCount`,
`clearShots`, `minionCount`, `fx(event, …)`, `rng`. Les tests unitaires passent un contexte
factice. Un seul contexte réutilisé par image : aucune allocation par image.

## Phases

Seuils à 66 % et 33 % des PV. Au franchissement : 1 s d'étourdissement **invulnérable**
(`dummy.bossInvuln`), tirs ennemis effacés (répit), onde de choc qui repousse le héros,
rugissement, bannière « PHASE 2/3 ». En phase 3 le boss passe en rouge (`isEnraged`).
L'ancienne rage à 50 % ne s'applique plus aux boss pilotés par le cerveau.

## Attaques (catalogue)

| Type | Paramètres | Télégraphe |
|---|---|---|
| `radial` | nombre, vitesse, salves, décalage alterné | cercle pulsant autour du boss |
| `fan` | nombre, écart, vitesse, salves (visée verrouillée en fin de télégraphe) | ligne de visée |
| `ring_gap` | nombre, taille du trou (placé au hasard) | cercle pulsant |
| `spiral` | bras, durée, intervalle, vitesse de rotation | cercle pulsant |
| `rain` | nombre de bombes, rayon autour du héros, durée de vol, rayon d'impact | cercles d'impact (bombes) |
| `charge` | vitesse, durée, répétitions ; dégâts au contact une fois par ruée | ligne de ruée |
| `summon` | type, nombre, part des PV du boss, maximum de serviteurs vivants | étincelles |
| `teleport` | près du héros (bande de distance) ou centre | étincelles au départ et à l'arrivée |

Dégâts = base × (1 + 0.25 × (chapitre − 1)) × réglage admin BOSS DAMAGE.
Au plus **60 tirs ennemis** simultanés : au-delà, les tirs d'une attaque sont ignorés.

Déplacements : `chase` (poursuite, facteur de vitesse), `keep` (garde une distance min-max,
glisse latéralement), `hover` (tourne autour du centre), `anchor` (rejoint le centre et y reste).

## Les 6 boss

| Boss | Phase 1 | Phase 2 | Phase 3 |
|---|---|---|---|
| Golem (ch.1) | poursuite ; étoile 8 | étoile 10 alternée ×2, pluie de 3 rochers | étoile 12 alternée ×3, charge, pluie de 5 |
| Roi Squelette (ch.2) | distance ; volée de 3 | volée de 5, 2 squelettes, pluie de 4 flèches | volée de 5 ×2, anneau à trou, pluie de 6, invocation |
| Sorcière (ch.3) | téléportation, éventail de 5 orbes | spirale 3 bras, éventail | téléportation au centre, anneau à trou, chauves-souris, spirale 4 bras |
| Titan de Lave (ch.4) | poursuite lente ; étoile 10, pluie de 4 | charge, étoile 12 ×2, pluie de 6 | double charge, étoile 14, pluie de 8 |
| Drake des Tempêtes (ch.5) | distance ; éventail de 3 éclairs, ruée | ruée, éventail de 5 ×2, anneau à trou | spirale 4 bras, ruée, éventail de 7 |
| Œil du Vide (ch.6) | ancré au centre ; spirale 4 bras, éventail de 5 | anneau à trou ×2, 2 feux follets, spirale 5 bras | spirale 6 bras, éventail de 9 serré, anneau à trou |

Mode Boss Rush : les types sans fiche (slime géant) gardent l'IA d'origine.

## Affichage

Repères à 66 % et 33 % sur la barre de vie du boss (écran du haut). Télégraphes dessinés par
`AIController.drawTelegraph` à partir de `BossBrain.telegraph(dummy)`.

## Tests

- Unitaires (`tests/test_boss_brain.lua`, contexte factice) : fiches valides (3 phases, attaques
  connues) ; seuils de phase, invulnérabilité 1 s, tirs effacés ; nombre de tirs par type ;
  trou de l'anneau ; spirale étalée dans le temps ; plafond de 60 ; dégâts selon chapitre et
  admin ; 90 s de combat simulé par boss sans erreur, tous les types d'attaque utilisés.
- Autotest : chaque boss (salles 10 à 60) combattu jusqu'à la mort via de vrais dégâts, les 3
  phases atteintes.
- Mesure : FPS dans Azahar pour chaque boss (outil admin TEST BOSS / banc).
