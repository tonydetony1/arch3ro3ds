# Act II — four new worlds after Void City (floors 51-100)

Date: 2026-10-11 · Status: design approved by the user, spec awaiting review

## Goal

Give the game a second act that continues the journey after the Ascension victory on floor 50
(shipped in v1.1.2): Void City plus four new worlds, each with its own hazard, a monster with a
new behaviour and a brand-new boss, ending with a final boss and a victory on floor 100.

## Decisions

| Topic | Choice |
|---|---|
| Structure | Act I = floors 1-50 (worlds 1-5, victory on 50, already shipped). Beating it unlocks Act II = floors 51-100 (worlds 6-10), victory on 100 |
| Launch | Act II starts from the hub world carousel (selecting world 6+ once Act I is cleared) and from the Act I victory screen (CONTINUE) |
| Run length | One act ≈ today's 50-floor run; no 100-floor single run is required |
| Void City | Becomes the first world of Act II (floors 51-60); no longer endless |
| Abyss | Stays endless and cycles through all 10 worlds past floor 100 |
| Bestiary | Per new world: 1 brand-new boss + 1 monster with a new behaviour family; the rest of each pool reuses existing archetypes and world-specific elite affix mixes |

## Structure

### Act I ending (extends the v1.1.2 victory)

`GameState:winRun` / `finishRun(true)` and the victory end screen exist. Changes:

- The first Act I clear sets `records.actsCleared[1] = true` and shows "ACT II UNLOCKED" on the
  victory screen.
- The victory screen gains a third choice, CONTINUE, next to AGAIN / MENU: the run goes on to
  floor 51 with the same hero, skills and gold (no bank, no `finishRun`), so a strong build can
  play straight through. AGAIN and MENU keep today's behaviour.

### Act II launch from the hub

- `Save.setChapter` clamps to `#WorldManager.CHAPTERS` instead of 6; the carousel wraps over all
  10 worlds (`src/states/menu.lua` next/prev and d-pad).
- `GameState:enter` reads `params.chapter` (ignored today): a world of Act II (6-10) starts the
  run at floor 51 with `params.act = 2`. Worlds 1-5 keep starting at floor 1. A world past the
  best floor reached stays locked (worldProgress already computes `unlocked`).
- Head start for a fresh Act II run (the HP curve at floor 51 is about 30x floor 1): the hero
  starts with the experience of a typical floor-50 hero, which opens a chain of 8 drafts before
  the start wheel. The number of drafts is a tuning constant (`Balance.ACT2_HEAD_START_DRAFTS`)
  checked on Azahar at 300 % CPU and on console.
- A run launched at floor 51 ends with a victory on floor 100 (`WorldManager.ACT_FLOORS = {50, 100}`
  replaces `ASCENSION_FLOORS`); the "/ 50" counter becomes "/ 100" in Act II.
- Records: `records.ascensionMax` keeps the deepest floor; `records.act2Clears` counts Act II
  clears like `ascensionClears` does for Act I.

### Abyss

`worldOfRoom` stops capping at the last world: floors 1-100 map to worlds 1-10, then the Abyss
cycles worlds 1-10 again (101-110 = world 1, ...). The difficulty curve stays continuous on the
absolute floor number. Boss damage scaling (`Bosses.DAMAGE_PER_CHAPTER`) uses the absolute world
depth `ceil(floor / 10)`, not the cycled index, so bosses keep scaling past world 6 (today their
damage freezes at x2.25 on floor 51+).

## The four worlds

Floors per world: slot 5 angel, slot 9 devil, slot 10 boss (unchanged). Each world has 4 room
grids (one "total" room) in `Rooms.WORLDS[w]`, like worlds 1-6.

### World 7 — Mycelium Hollow (floors 61-70)

Under Void City, the Rift's roots feed a glowing fungal forest.

- Palette: ground `1f2a2e`, light `2b3a3d`, dark `151d20`, edge `0b1012`, sky `05080a` → `123033`,
  torch `35f2d0`, gate `d24bff`.
- Hazard `dark` (new): the room is dark beyond a light radius around the hero (~100 px). Glowing
  mushroom decals make extra light pockets. Monsters and every projectile are always drawn above
  the darkness, so nothing that can hurt the hero is hidden; only floor hazards (spore puddles)
  are hidden outside the light. Render: one pre-baked radial sprite centred on the hero plus 4
  edge rectangles (5 draws), no per-frame allocation.
- Obstacles and decor: giant mushroom stump (1-cell obstacle), shelf fungus blocks, spores and
  glowing caps as ground decor.
- Pool: `sporeling` (new), `plant`, `splitter`, `burrower`, `wisp`, `summoner`, `bat`.
- New monster `sporeling` (trail family): slow walker; on death it leaves a spore puddle for 3 s
  that poisons the hero (no damage to monsters). Reuses the slime walker AI.
- Boss `myconid_matriarch` (new):
  - phase 1: spore mortar (`rain` attack leaving a puddle on impact), spore ring (`radial`);
  - phase 2: summons sporelings (`summon`), light pulse burst (`ring_gap`);
  - phase 3: the light radius shrinks by 30 % during the fight, spiral spore stream (`spiral`).
- Signature total room "Lightless Grotto": dark everywhere except a few mushroom groves.

### World 8 — Gearworks Citadel (floors 71-80)

The ancients' machine that drills the Rift open: brass halls and live pylons.

- Palette: ground `5a4a3a`, light `72604a`, dark `43372b`, edge `2a221a`, sky `2b1d12` → `c9772e`,
  torch `ffb347`, gate `6fd6ff`.
- Hazard `pylon` (new): pairs of pylon obstacles linked by an electric arc on a 3 s cycle (1 s on,
  0.6 s flicker warning, then off). Crossing a live arc deals damage that scales with depth.
  Collision is a segment-to-circle distance test; arcs are drawn as lines. Fairness: every room
  keeps a path from the entry to the gate and to each combat area that never crosses an arc.
- Obstacles and decor: cog stump, riveted brass blocks, rails, bolts and oil stains.
- Pool: `bulwark` (new), `turret`, `golem`, `bomber`, `skeleton`, `mage`, `gargoyle`.
- New monster `bulwark` (shielder family): a front shield blocks arrows inside ±60° of its facing;
  it turns slowly towards the hero, so flanking, ricochet and piercing beat it. Reuses the
  skeleton walker AI; the check sits where arrows hit monsters.
- Boss `brass_colossus` (new):
  - phase 1: piston charges (`charge`), rivet fan (`fan`);
  - phase 2: turns on the arena pylons, rotating arc beam (new `beam` attack);
  - phase 3: overheat, faster charges and steam ring (`ring_gap`).
- Signature total room "Assembly Line": a grid of pylon pairs with timed safe lanes.

### World 9 — Starfall Observatory (floors 81-90)

The drill pierced the sky: an observatory where stars are pulled down, floating over a starfield.

- Palette: ground `2c3157`, light `3d4475`, dark `1f2340`, edge `121530`, sky `04051a` → `3b2a7a`,
  torch `fff1a8`, gate `9fb4ff`. Floating island (`skyMargin`), like worlds 1 and 5.
- Hazard `gravity` (new): 1-2 singularities per room pull the hero (at most 40 % of the hero's
  speed) and bend every projectile, enemy and hero alike; the core deals damage. Counterplay: dash
  out, or curve your own arrows around rocks. Per-frame cost: one vector per well for the hero and
  each live projectile (pool of 200), no allocation.
- Obstacles and decor: brass telescope stump, star-chart slabs, stardust and meteor fragments.
- Pool: `blink_seer` (new), `wisp`, `raven`, `gargoyle`, `frost_wraith`, `mage`, `turret`.
- New monster `blink_seer` (teleporter family): fires a 3-shot fan, then teleports; the arrival
  point shimmers 0.5 s before it appears. Reuses the mage AI.
- Boss `eclipse_seraph` (new):
  - phase 1: star rain (`rain`), radial bursts (`radial`);
  - phase 2: spawns a gravity well (new `well` attack) that bends its own bursts into spirals;
  - phase 3: eclipse, the wells push instead of pull, double `spiral`, blinks (`teleport`).
- Signature total room "Event Horizon": one big well in the centre, a ring of platforms around it.

### World 10 — Ashen Throne (floors 91-100), final world

The Rift Sovereign's burnt throne at the top of the world, where every past world echoes.

- Palette: ground `6b6560`, light `857e77`, dark `514c47`, edge `2e2a27`, sky `1a1414` → `e8b04a`,
  torch `ffd34d`, gate `ff4d6d`.
- Hazard `echo` (remix): each room's `h` zones take one past hazard (sand, ice, lava, wind, void,
  dark), chosen from the room's seed. This needs the hazard kind per room instead of per world.
- World rule: one extra elite per combat room.
- Obstacles and decor: ash statues, broken thrones, embers and gold leaf.
- Pool: `echo_wraith` (new), `frost_wraith`, `gargoyle`, `summoner`, `splitter`, `wolf`, `mage`.
- New monster `echo_wraith` (mirror family): mirrors the hero's position across the room centre
  with a 0.3 s lag and fires back whenever the hero fires.
- Final boss `rift_sovereign` (new): each phase borrows signature attacks of earlier bosses
  (king volley and witch ring, titan charge and void orbs, drake spiral), and in phase 3 the
  arena closes in (the playable rectangle shrinks to 70 %). Beating it ends Act II with a victory.
- Signature total room "Hall of Echoes": four quadrants, one past hazard each.

## Engine changes

| Area | Change |
|---|---|
| World and theme indices | Worlds keep theme index = world index (1-10); the angel and devil sanctuary themes move from indices 7 and 8 to 11 and 12 (`SANCTUARY_THEME = { angel = 11, devil = 12 }`), so worlds 7-10 never render with the sanctuary look. `GroundTiles` (constant 8 themes → 12, 72 of the 96 tile slots), sky sprites (baked for 1-6 only → 1-10), `Ambience` looks, `menu_top` world looks and `tests/test_sanctuary_rooms.lua` follow |
| World count | No hard-coded 6: `Save.setChapter`, `worldOfRoom`, `Encounters.unlocked` (`room > 60` Abyss cutoff), HUD "WORLD n/10", admin TEST BOSS, achievements boss list (`src/data/achievements.lua`), selftest and tests |
| Hazards | `HAZARD_KIND` gains `dark`, `pylon`, `gravity`; `echo` sets a per-room kind; each new kind gets its `HAZARD_COLORS` entry and HUD minimap colour (a missing colour makes a hazard invisible but active) |
| Puddles | A small pool of persistent ground puddles (max 8, pre-allocated) that hurt the hero, used by the sporeling and the Matriarch. Bosses cannot create ground hazards today |
| Boss attacks | Three new executors in `BossBrain.EXECUTORS`: `rain` with a puddle on impact, `beam` (rotating arc with a telegraph), `well` (spawns a gravity well). Everything else reuses `radial`, `fan`, `rain`, `ring_gap`, `spiral`, `summon`, `teleport`, `charge` |
| Monsters | 4 new archetypes with `Encounters.ROLE`/`COST` (a type without them is silently excluded), `ARCHETYPE_HP`, dummy stats and AI branches in `src/core/ai_controller.lua`, sprites in a table-based module (the 60-upvalue limit is reached in `src/render/sprites/monsters.lua`) |
| Bestiary | The page holds 24 cells and 22 are used: page it by act (2 pages) |
| Menu art | 4 new hub islands: `tools/make_menu_sprites.py` and `tools/menu_art/island_art.py` (generated file, do not edit `menu_art.lua` by hand) |

## Atlas budget

The atlas is a fixed 1024 × 1024 texture. Free space measured on origin/main (v1.1.1): about 94k px
in the sprite shelf (rows 541-639) and the ground-tile rows 832-1023 (room for 8 more themes).

Per new world: ground tiles (in the free ground region), sky sprite, boss about 10k, new monster
about 3k, one obstacle 1.8k, decals about 1k, hub island 6.8k: about 23k, so the 4 worlds take about
92k and fit, provided they reuse an existing prop variant set for walls and trees (a new set costs
about 13.4k). Unique walls and trees for every world need more space, freed by trimming some of the
baked font colour copies (about 14.9k each). The bake asserts on overflow, so the budget is checked
at every bake.

## Delivery order

Each step is a playable release.

1. Engine preparation: theme mapping, world count, Act II launch from the hub, CONTINUE on the Act
   I victory screen, head start, `ACT_FLOORS`, Abyss rotation, boss damage scaling. Act II at this
   step = Void City only (floors 51-60).
2. World 7 Mycelium Hollow: `dark` hazard, puddles, sporeling, Myconid Matriarch, bestiary paging.
3. World 8 Gearworks Citadel: `pylon` hazard, bulwark, `beam` attack, Brass Colossus.
4. World 9 Starfall Observatory: `gravity` hazard, blink seer, `well` attack, Eclipse Seraph.
5. World 10 Ashen Throne: `echo` hazard, echo wraith, Rift Sovereign, victory on floor 100.

## Tests

- Unit (`tests/`, Lua 5.1):
  - theme mapping: worlds 7-10 get themes 7-10, sanctuaries get 11 and 12;
  - `worldOfRoom` and the Abyss cycle (floors 1-100 → worlds 1-10, 101 → world 1);
  - boss damage keeps scaling past world 6;
  - `Save.setChapter` and the carousel reach world 10;
  - an Act II run starts on floor 51 with the head start and ends with a victory on floor 100;
  - each new hazard: effect, warning timing, safe path (pylons), no allocation in its update;
  - puddle pool limits;
  - new boss brains: 3 phases and known attacks (extend `tests/test_boss_brain.lua` `BOSS_TYPES`);
  - `Rooms.validate` on the 16 new grids.
- PC self-test (`love . --test` in a scratch-identity harness): chapter loops and boss fights over
  10 worlds.
- Azahar at 300 % CPU, and console: one capture of each world's total room, FPS and vertex
  rejections in the perf log (darkness overlay, pylon arcs and gravity on projectiles are the
  costs to watch).

## Out of scope (separate specs)

Retention features ranked with this design, each its own spec: boss chests and first-kill trophies
(dormant `src/data/boss_loot.lua`), world medals (3 per world), draft reroll/banish/skip, visible
skill evolutions, kill chain and perfect dash, run journal and next-goal line, hero mastery and
account level, forked paths, Heat ladder, relics and devil pacts, seeded daily challenge.

## Open questions

- Head start size for a fresh Act II run (8 drafts is the starting value, to tune on device).
- Whether the admin panel stays reachable by players (7 taps today).
