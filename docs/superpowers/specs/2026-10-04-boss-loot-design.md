# Boss loot and guaranteed second weapon

Date: 2026-10-04 · Status: approved by the user · Sub-project 1 of 4 (boss loot → recycling →
held-weapon visuals → item passives)

## Problem

A tester (v1.0.7, 30 min) never saw any weapon but the bow: the 7 other weapons exist but only come
from hub chests (450 gold each). `Items.DROP_TABLES.boss` has been defined for a long time but is
never used: beating a boss only gives gold.

## Rules

| Topic | Choice |
|---|---|
| Modes | Ascension and Abyss (a boss every 10 rooms) |
| Frequency | Every defeated boss drops exactly 1 item |
| Roll | `Items.rollDrop("boss", nil, Balance.maxRarity(save))`: rarity weighted by the boss table, capped by progression |
| Guarantee | While the player owns a single weapon, the item is a weapon they do not own, picked uniformly among weapons of an unlocked rarity |
| Boss Rush, Arena | No chest (event modes: gold rewards unchanged) |
| Save | `Save.addItem` as soon as the boss dies: an item is never lost, even if the hero dies before opening the chest. A duplicate becomes a copy (+75 gold, existing behaviour) |

The guarantee only applies when at least one unowned weapon of an unlocked rarity exists;
otherwise the normal roll applies. Records (hence unlocked rarities) are only updated at the end of
a run: during the very first run the cap stays `uncommon`, so the weapon guaranteed by the first
boss is the Wind Daggers or the Tornado Boomerang.

## Components

### `src/data/boss_loot.lua` (new, pure module)

`BossLoot.roll(saveData, rng)` → `itemId, reason`

- `reason = "new_weapon"` when the guarantee applies, otherwise `"drop"`.
- `rng`: function returning a number in [0, 1) (defaults to `math.random`), injected by tests for a
  reproducible roll.
- Only reads `saveData.inventory` and `saveData.records`; writes nothing.

`BossLoot.ownedWeapons(saveData)` → number of distinct weapons owned (used by the guarantee).

### `src/entities/loot.lua`

New `"chest"` type: same bounce physics, picked up on contact, pulled towards the hero when the
room is cleared (behaviour shared by all loot). Sprite: new hand-drawn `loot_chest` (pixel art
~16 x 12, wood and gold bands) in `src/render/sprites/props.lua`; the atlas is re-baked
(`love tools/bake`). Loot currently bounces inside the old 400 x 240 screen area: it is clamped to
the room instead, so the chest lands where the boss died.

### `src/states/game.lua`

- When a boss dies (Ascension / Abyss): `BossLoot.roll`, then `Save.addItem`; the entry
  `{ id, isNew, copies, reason }` is appended to `self.runLoot` and a chest drops on the spot.
- When the chest is picked up: banner with the header "NEW WEAPON" (guarantee), "NEW ITEM" or
  "COPY n/3", the item name as title in its rarity colour and the rarity as subtitle; reward sound.
- `runLoot` is passed to the game over screen.

### `src/states/gameover.lua`

"LOOT" block in the skills box: up to 2 item names (rarity colour) then "+N MORE". When the run
gave loot, the skills box keeps one row of skills. Nothing changes when the run gave no item.

## Tests

- `tests/test_boss_loot.lua`:
  - a single weapon owned → the item is an unowned weapon, `reason = "new_weapon"`;
  - two weapons owned → normal roll (`reason = "drop"`);
  - rarity cap respected (new save: never above `uncommon`);
  - same seed → same item;
  - no weapon owned at all → a weapon is guaranteed too;
  - banner text and game over summary.
- `tests/test_loot_bounds.lua`: loot dropped near the far corner of a 640 x 480 room stays there.
- LÖVE self-test (`love . --test`): must stay green.

## Out of scope

Duplicate recycling, held-weapon visuals and item passives: next sub-projects, each with its own
spec. Run resume does not restore `runLoot` (items are already saved; only the game over list of a
resumed run is shorter).
