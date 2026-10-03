# Réglages + panneau admin — plan d'implémentation

> Exécution inline (superpowers:executing-plans). Conception : `docs/superpowers/specs/2026-10-03-reglages-admin-design.md`.

**Goal:** onglet SETTINGS tactile + panneau admin caché (équilibrage, triches, outils) persistant.

- [ ] **Task 1 — `src/data/admin.lua` (TDD).** Écrire `tests/test_admin.lua` (bornes/pas, bascules,
  `isModified`, validation `load`, aller-retour `export`), l'ajouter à `tests/run.lua`, voir échouer,
  implémenter `Admin.TUNING`, `Admin.CHEATS`, `get/set/step/toggle/isModified/resetTuning/load/export`,
  voir passer. Commit.
- [ ] **Task 2 — Branchements équilibrage (TDD).** Tests : `Director.compose` avec
  `Admin.set("eliteMult", 0)` → aucune élite, `budgetMult` 2 → budget doublé ; `generateEncounter`
  avec `hpMult` 2 → PV totaux doublés. Implémenter dans `encounter_director.lua` (élites ×
  arrondi, `difficulty` par défaut = `budgetMult`) et `world_manager.lua` (PV ×). Remettre
  `Admin.resetTuning()` en fin de test. Commit.
- [ ] **Task 3 — Effets en jeu.** `Save.load` → `Admin.load`; `Dummy:takeDamage` (× HERO DAMAGE,
  ONE-HIT) ; `GameState:update` (GOD MODE, INFINITE ULTIMATE) ; or ramassé (× GOLD GAIN) ;
  `GameState:enter` `params.startRoom` ; `Config.SHOW_GPU_STATS` dans `main.lua` ; badge ADMIN.
  Autotest. Commit.
- [ ] **Task 4 — `src/ui/settings_panel.lua`.** Pages settings/tuning/cheats/tools, lignes
  slider/toggle/stepper/action, toucher + manette, déblocage 7 touchers, requêtes
  `close/launch/refresh`. Migrer les réglages joueur existants depuis `menu.lua`. Commit.
- [ ] **Task 5 — Menu.** 7ᵉ onglet SETTINGS (`icon_gear`, onglets 41 px), indication « Y: SETTINGS »
  en haut, délégation dessin/toucher/manette au panneau, suppression de l'ancien code de page.
  Atlas recompilé. Captures de chaque page. Commit.
- [ ] **Task 6 — Autotest + vérifs.** Autotest : déblocage, page admin dessinée, TEST BOSS lance la
  salle 10. `make unit`, `love . --test`, build 3DS + capture Azahar du panneau. Commit.
