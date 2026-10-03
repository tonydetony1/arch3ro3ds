# Réglages accessibles et panneau admin de production

Date : 2026-10-03 · Statut : validé (accès admin : option A, déblocage caché)

## Problèmes

- Le bouton SETTINGS est dessiné sur l'écran du haut (non tactile sur 3DS) ; sa zone de
  toucher réelle est un rectangle invisible de l'écran du bas ; le raccourci Y n'est indiqué
  nulle part. Les réglages ne se pilotent qu'au toucher.
- Aucun moyen de régler l'équilibrage ou de tester un boss sur console sans recompiler.

## 1. Accès aux réglages

- 7ᵉ onglet **SETTINGS** (icône roue dentée `icon_gear`, nouveau sprite) dans la barre du bas.
  Les 7 onglets font 41 px de large, pas de 44 px (de x = 6 à x = 311).
- L'onglet ouvre le panneau ; B ou l'onglet PLAY referment. Y bascule toujours.
- Écran du haut : le faux bouton devient l'indication « Y: SETTINGS ».
- Navigation manette dans le panneau : haut/bas = ligne, gauche/droite = valeur, A = action.

## 2. Module `src/ui/settings_panel.lua`

Panneau autonome appelé par `MenuState` (dessin, toucher, manette). Pages :
`settings` (réglages joueur existants : musique, effets, relief 3D, chiffres de dégâts, économie
de batterie, réinitialisation), puis, une fois débloqué, `tuning`, `cheats`, `tools`.
Chaque page est une liste de lignes `{ id, label, kind, ... }` avec `kind` parmi
`slider` (− / jauge / +), `toggle` (ON/OFF), `stepper` (− valeur + et bouton GO),
`action` (bouton). Au plus 6 lignes par page ; en-tête avec onglets de page pour l'admin.

Le panneau renvoie des **requêtes** à `MenuState` plutôt que d'agir lui-même sur les états :
`{ close = true }`, `{ launch = { startRoom = N } }`, `{ refresh = true }`.

## 3. Panneau admin

**Déblocage** : 7 touchers sur le titre « SETTINGS » en moins de 4 s →
`settings.adminUnlocked = true` (sauvegardé), étiquette « ADMIN UNLOCKED ». La page Outils
propose de le re-verrouiller.

**Valeurs** : module pur `src/data/admin.lua`, persistées dans `Save.data.admin`, validées au
chargement (nombre hors bornes ou type inattendu → valeur par défaut).

| Page | Ligne | Bornes (pas) | Effet |
|---|---|---|---|
| Tuning | MONSTER HP | 0.5-2.0 (0.1) | × PV totaux des salles (`generateEncounter`) |
| Tuning | THREAT BUDGET | 0.5-2.0 (0.1) | `difficulty` du directeur de rencontres |
| Tuning | ELITE RATE | 0-3 (0.5) | × nombre d'élites (arrondi) |
| Tuning | BOSS DAMAGE | 0.5-2.0 (0.1) | × dégâts des tirs de boss |
| Tuning | HERO DAMAGE | 0.5-3.0 (0.25) | × dégâts reçus par les monstres |
| Tuning | GOLD GAIN | 1-5 (0.5) | × or ramassé en course |
| Cheats | GOD MODE | on/off | PV du héros remis au max, pas de game over |
| Cheats | ONE-HIT KILLS | on/off | tout coup tue (sauf boucliers d'élite déjà absorbés) |
| Cheats | INFINITE ULTIMATE | on/off | jauge d'ultime toujours pleine |
| Tools | START ROOM | 1-150 | lance une Ascension à la salle N (roue de départ sautée) |
| Tools | TEST BOSS | 1-6 | lance la salle 10 × N |
| Tools | +10K GOLD / +1K GEMS | action | |
| Tools | UNLOCK HEROES | action | tous les héros débloqués |
| Tools | HITBOXES / PERF OVERLAY | on/off | `Config.DEBUG_MODE` / `Config.SHOW_GPU_STATS` |
| Tools | RESET TUNING | action | valeurs d'équilibrage par défaut, triches coupées |
| Tools | LOCK ADMIN | action | masque à nouveau le panneau |

**Badge** : tant qu'une valeur diffère de sa valeur par défaut, « ADMIN » s'affiche en haut à
gauche de l'écran du haut pendant la partie.

## 4. Intégration

- `GameState:enter(params)` accepte `params.startRoom` (roue de départ sautée).
- `main.lua` lit `Config.SHOW_GPU_STATS` au lieu d'une variable locale (F3 et SELECT le
  basculent toujours).
- `Save.load` → `Admin.load(Save.data.admin)` ; toute modification → `Save.data.admin =
  Admin.export()` puis `Save.save()`.

## 5. Tests

- Unitaires (`tests/test_admin.lua`) : bornes et pas, bascules, `isModified`, validation au
  chargement, aller-retour export/load, effets sur le directeur (élites, budget) et sur les PV
  de `generateEncounter`.
- Autotest : 7 touchers débloquent l'admin ; l'outil TEST BOSS lance la salle 10 ; le panneau se
  dessine sans erreur sur chaque page.
