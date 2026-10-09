# World diversity — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Each of the 6 worlds gets 4 hand-drawn rooms of its own (one "total" room per world), a world-specific single-cell obstacle and extra ground details; wind gusts push the hero through collisions.

**Architecture:** World rooms live in `Rooms.WORLDS[world]` (same 13 × 9 ASCII format, validated by `Rooms.validate`). `Rooms.pick(kind, room, world)` places 4 world rooms (the total one in the middle of the chapter) and 3 common rooms in the 7 combat slots of a chapter. `ObstacleManager:generate` receives the world. New sprites (`src/render/sprites/biomes.lua`) give each world its own obstacle shape; ground details are baked into the existing ground tiles through each theme's `decals` list.

**Tech Stack:** Lua 5.1, LÖVE 11 / LÖVE Potion 3, `PixGen` sprites, `lua5.1 tests/run.lua`, `./run.sh --test`.

Spec: `docs/superpowers/specs/2026-10-04-diversite-mondes-design.md`. Adjustments since the spec: a chapter now has 7 combat rooms (the demon lair took room 9), so 4 world rooms + 3 common rooms; big rock blocks already use a per-world palette (`BLOCK_THEMES`) and keep it.

Conventions: code, comments and commit messages in English (AGENTS.md).

## Files

| File | Change |
|---|---|
| `src/data/rooms.lua` | `Rooms.WORLDS` (24 grids), `Rooms.pick(kind, room, world)`, `validateAll` covers world rooms |
| `src/core/obstacle_manager.lua` | `generate(…, layout, world)`, per-world obstacle sprite, wind through `Physics.moveAndSlide` |
| `src/states/game.lua` | Passes the world to `generate` |
| `src/render/sprites/biomes.lua` (new) | 5 obstacle sprites, 8 ground details |
| `src/render/art.lua`, `tools/bake/main.lua` | Register the sprite module |
| `src/core/world_manager.lua` | Theme `decals` lists |
| `src/dev/selftest.lua` | Wind test, world rooms in spawn and repetition checks |
| `tests/test_world_rooms.lua` (new), `tests/run.lua` | Unit tests |

---

### Task 1: world rooms and pick (unit tests first)

**Files:** Create `tests/test_world_rooms.lua`; modify `tests/run.lua`, `src/data/rooms.lua`.

- [ ] **Step 1: failing test** — `tests/test_world_rooms.lua`:

```lua
local Rooms = require("src.data.rooms")
local WorldManager = require("src.core.world_manager")

local T = {}

local SAFE = { ["."] = true, o = true, m = true }

local function chapterRooms(chapter)
    local first = (chapter - 1) * 10 + 1
    local list = {}
    for room = first, first + 9 do
        if WorldManager.getRoomType(room) == "combat" then list[#list + 1] = room end
    end
    return list
end

local function isWorldLayout(world, layout)
    for _, l in ipairs(Rooms.WORLDS[world]) do
        if l == layout then return true end
    end
    return false
end

T["each world has 4 rooms, exactly one of them total"] = function()
    for world = 1, 6 do
        local rooms, totals = Rooms.WORLDS[world], 0
        assert(#rooms == 4, "world " .. world .. ": " .. #rooms .. " rooms")
        for _, l in ipairs(rooms) do
            if l.total then totals = totals + 1 end
        end
        assert(totals == 1, "world " .. world .. ": " .. totals .. " total rooms")
    end
end

T["every world room is valid, mirrored too"] = function()
    for world = 1, 6 do
        for _, l in ipairs(Rooms.WORLDS[world]) do
            for _, grid in ipairs({ l.grid, Rooms.mirror(l.grid) }) do
                local ok, err = Rooms.validate({ id = l.id, grid = grid }, "combat")
                assert(ok, err)
            end
        end
    end
end

-- Total rooms that hurt (lava, void rifts): a hazard-free path from the entry to the gate,
-- and monsters always appear on safe ground
T["damaging total rooms keep a safe path and safe spawns"] = function()
    for _, world in ipairs({ 4, 6 }) do
        for _, l in ipairs(Rooms.WORLDS[world]) do
            if l.total then
                local g = l.grid
                local seen, stack = {}, { { 7, Rooms.ROWS } }
                while #stack > 0 do
                    local c, r = unpack(table.remove(stack))
                    local key = r * 100 + c
                    if not seen[key] and c >= 1 and c <= Rooms.COLS and r >= 1 and r <= Rooms.ROWS
                        and SAFE[g[r]:sub(c, c)] then
                        seen[key] = true
                        stack[#stack + 1] = { c + 1, r }
                        stack[#stack + 1] = { c - 1, r }
                        stack[#stack + 1] = { c, r + 1 }
                        stack[#stack + 1] = { c, r - 1 }
                    end
                end
                assert(seen[100 + 7], l.id .. ": no hazard-free path to the gate")
                for r = 1, Rooms.ROWS do
                    for c = 1, Rooms.COLS do
                        if g[r]:sub(c, c) == "m" then
                            assert(seen[r * 100 + c], l.id .. ": spawn " .. c .. "," .. r .. " not on safe ground")
                        end
                    end
                end
            end
        end
    end
end

T["a chapter plays its 4 world rooms (total once) and 3 common rooms, no repeat"] = function()
    for chapter = 1, 6 do
        local seen, own, totals = {}, 0, 0
        local rooms = chapterRooms(chapter)
        assert(#rooms == 7, "chapter " .. chapter .. ": " .. #rooms .. " combat rooms")
        for _, room in ipairs(rooms) do
            local layout = Rooms.pick("combat", room, chapter)
            assert(not seen[layout.id], "chapter " .. chapter .. ": " .. layout.id .. " repeated")
            seen[layout.id] = true
            if isWorldLayout(chapter, layout) then own = own + 1 end
            if layout.total then totals = totals + 1 end
        end
        assert(own == 4 and totals == 1, "chapter " .. chapter .. ": " .. own .. " world rooms, " .. totals .. " total")
    end
end

T["pick is deterministic and unchanged without a world"] = function()
    for room = 1, 60 do
        local a, ma = Rooms.pick("combat", room, 3)
        local b, mb = Rooms.pick("combat", room, 3)
        assert(a == b and ma == mb, "room " .. room)
        local c = Rooms.pick("combat", room)
        local found = false
        for _, l in ipairs(Rooms.COMBAT) do
            if l == c then found = true end
        end
        assert(found, "room " .. room .. ": world room picked without a world")
    end
end

return T
```

Add `"tests.test_world_rooms",` at the end of `files` in `tests/run.lua`.

- [ ] **Step 2: run** `lua5.1 tests/run.lua` — Expected: the 5 new tests fail (`Rooms.WORLDS` is nil).

- [ ] **Step 3: implement** — in `src/data/rooms.lua`, after the `Rooms.SANCTUARY` table, add:

```lua
-- Rooms of each world (chapter 1 forest, 2 desert, 3 crystal, 4 volcano, 5 sky, 6 void):
-- 4 per world, one "total" room covered by the world's hazard. 'h' is the world hazard
-- (plain ground in the forest). Damaging total rooms keep a hazard-free path and safe spawns.
Rooms.WORLDS = {
    [1] = {
        { id = "marsh", total = true, grid = {
            "o....m.m....o",
            ".~~~~...~~~~.",
            ".~~~~.m.~~~~.",
            "..m.......m..",
            "~~~~..#..~~~~",
            "~~~~.....~~~~",
            "..~~~...~~~..",
            "..~~~...~~~..",
            ".....o.o.....",
        } },
        { id = "stump_clearing", grid = {
            ".....m.m.....",
            "..#.......#..",
            "....#...#....",
            ".m....o....m.",
            "..#.......#..",
            "....#...#....",
            "......b......",
            "..#.......#..",
            ".............",
        } },
        { id = "winding_stream", grid = {
            "....m...m....",
            "~~~~~~.~~~~~~",
            "......m......",
            ".#.........#.",
            "~~~.~~~~~~~~~",
            ".....m.......",
            "~~~~~~~~~.~~~",
            ".............",
            ".............",
        } },
        { id = "grove", grid = {
            ".....m.m.....",
            ".###.....###.",
            ".............",
            "..m.#####.m..",
            ".............",
            ".###.....###.",
            "......o......",
            "....##.##....",
            ".............",
        } },
    },
    [2] = {
        { id = "sand_sea", total = true, grid = {
            "hhhhhm.mhhhhh",
            "hhhhhh.hhhhhh",
            "hm.........mh",
            "hh.hhh.hhh.hh",
            "hh.hh#.#hh.hh",
            "hh.hhh.hhh.hh",
            "hh.........hh",
            "hhhhhh.hhhhhh",
            "hhhhhh.hhhhhh",
        } },
        { id = "oasis", grid = {
            ".....m.m.....",
            "..hh.....hh..",
            ".m.#.~~~.#.m.",
            "...~~~~~~~...",
            "..#~~~~~~~#..",
            "...~~~~~~~...",
            "..h.#...#.h..",
            "..hh.....hh..",
            ".............",
        } },
        { id = "canyon", grid = {
            ".....m.m.....",
            "..###...###..",
            "..#.......#..",
            "..#.m...m.#..",
            "......h......",
            "..#..hhh..#..",
            "..#.......#..",
            "..###...###..",
            ".............",
        } },
        { id = "dunes", grid = {
            "hh...m.m.....",
            ".hh.......#..",
            "..hh..m......",
            "...hh....hh..",
            ".#..hh..hh...",
            ".m...hhhh..m.",
            "......hh.....",
            "...#.....hh..",
            "..........hh.",
        } },
    },
    [3] = {
        { id = "ice_rink", total = true, grid = {
            "hhhhhm.mhhhhh",
            "hhhhhhhhhhhhh",
            "hhm#hhhhh#mhh",
            "hhhhhhhhhhhhh",
            "hhhhh#h#hhhhh",
            "hhmhhhhhhhmhh",
            "hh#hhhhhhh#hh",
            "hhhhhhhhhhhhh",
            "hhhhhh.hhhhhh",
        } },
        { id = "frozen_lake", grid = {
            ".....m.m.....",
            ".hhhhhhhhhhh.",
            ".hh~~~~~~~hh.",
            ".hh~~~~~~~hh.",
            ".m..~~~~~..m.",
            ".hh~~~~~~~hh.",
            ".hhhhhhhhhhh.",
            "..#.......#..",
            ".............",
        } },
        { id = "crystal_forest", grid = {
            ".....m.m.....",
            "..#.......#..",
            ".m....h....m.",
            "....#...#....",
            "..#..hhh..#..",
            ".m..#...#..m.",
            "......h......",
            "..#.......#..",
            ".............",
        } },
        { id = "ice_lanes", grid = {
            ".....m.m.....",
            "hhhhhhhhhhhhh",
            "....#...#....",
            "hhhhhhhhhhhhh",
            ".m....b....m.",
            "hhhhhhhhhhhhh",
            "...#.....#...",
            "hhhhhhhhhhhhh",
            ".............",
        } },
    },
    [4] = {
        { id = "lava_rivers", total = true, grid = {
            "...m.....m...",
            "hhhhh...hhhhh",
            "h..hh...hh..h",
            "..m.......m..",
            "hhhhh...hhhhh",
            "hhhhh...hhhhh",
            "..b.......b..",
            "hhhh.....hhhh",
            "hhhh.....hhhh",
        } },
        { id = "caldera", grid = {
            ".....m.m.....",
            "..hhhhhhhhh..",
            ".mh.......hm.",
            "..h..#.#..h..",
            "..h...m...h..",
            "..hhhh.hhhh..",
            ".............",
            "..#.......#..",
            ".............",
        } },
        { id = "lava_flows", grid = {
            ".....m.m.....",
            "hh...........",
            ".hhh....#..m.",
            "...hhh.......",
            ".m...hhh..#..",
            "...#...hhh...",
            ".........hhh.",
            "...........hh",
            ".............",
        } },
        { id = "forge", grid = {
            ".....m.m.....",
            "..b.......b..",
            ".hh..#.#..hh.",
            ".hh.......hh.",
            "...m..b..m...",
            ".hh.......hh.",
            ".hh..#.#..hh.",
            "..b.......b..",
            ".............",
        } },
    },
    [5] = {
        { id = "storm", total = true, grid = {
            "hhhhhm.mhhhhh",
            "hhhhhhhhhhhhh",
            "hhm#hhhhh#mhh",
            "hhhhhh.hhhhhh",
            ".....h.h.....",
            "hhmhhhhhhhmhh",
            "hhhhhhhhhhhhh",
            "hh#hhhhhhh#hh",
            "hhhhhh.hhhhhh",
        } },
        { id = "archipelago", grid = {
            ".....m.m.....",
            ".~~~.....~~~.",
            ".~~~.~~~.~~~.",
            ".m...hhh...m.",
            "~~~.~~.~~.~~~",
            "...m.....m...",
            ".~~~.~~~.~~~.",
            ".~~~.....~~~.",
            ".............",
        } },
        { id = "wind_corridor", grid = {
            ".....m.m.....",
            "hh..#...#..hh",
            "hh.........hh",
            "hhm..#.#..mhh",
            "hh.........hh",
            "hh.m.....m.hh",
            "hh..#...#..hh",
            "hh.........hh",
            ".............",
        } },
        { id = "floating_temple", grid = {
            ".....m.m.....",
            ".#.........#.",
            "...#.....#...",
            ".m...h.h...m.",
            "..#..~~~..#..",
            "...m.....m...",
            "...#.....#...",
            ".#.........#.",
            ".............",
        } },
    },
    [6] = {
        { id = "fracture", total = true, grid = {
            "..m.......m..",
            "hh..h...h..hh",
            "hh..h...h..hh",
            ".............",
            ".m.........m.",
            "hh..h...h..hh",
            "hh..h...h..hh",
            ".............",
            ".............",
        } },
        { id = "spiral", grid = {
            ".....m.m.....",
            ".hhhhh..hhhh.",
            ".h.........h.",
            ".h.hhh.hh..h.",
            ".h.hm...h..h.",
            ".h.hhhhhh..h.",
            ".h.........h.",
            ".hhhh...hhhh.",
            ".............",
        } },
        { id = "eye", grid = {
            ".....m.m.....",
            ".............",
            "...hhhhhhh...",
            ".m.h.....h.m.",
            "...h..#..h...",
            "...hhh.hhh...",
            ".............",
            "..#.......#..",
            ".............",
        } },
        { id = "monoliths", grid = {
            ".....m.m.....",
            ".##.......##.",
            ".............",
            "...##.h.##...",
            ".m...hhh...m.",
            "...##.h.##...",
            ".............",
            ".##.......##.",
            ".............",
        } },
    },
}
```

Replace the comment block above `function Rooms.pick` and the function itself with:

```lua
-- Deterministic pick by room number: a resumed run finds the same room again.
-- Combat: the 7 combat slots of a chapter (rooms 1-4 and 6-8) get, when the world is
-- known, its 4 own rooms (the total one at slot 5, right after the angel) and 3 common
-- rooms; the common pool of the 10-room block is shuffled once, so no grid repeats within a
-- chapter. Every other room is played mirrored left-right.
local WORLD_SLOTS = { [2] = 1, [4] = 2, [5] = "total", [7] = 3 }
local COMMON_SLOTS = { [1] = 1, [3] = 2, [6] = 3 }

local function worldRooms(world)
    local total, others = nil, {}
    for _, l in ipairs(Rooms.WORLDS[world] or {}) do
        if l.total then total = l else others[#others + 1] = l end
    end
    return total, others
end

function Rooms.pick(kind, roomNumber, world)
    roomNumber = math.max(1, roomNumber or 1)
    local block = math.floor((roomNumber - 1) / ROOMS_PER_BLOCK)
    local slot = (roomNumber - 1) % ROOMS_PER_BLOCK + 1
    local firstRoom = block * ROOMS_PER_BLOCK + 1

    local eligible = {}
    for _, layout in ipairs(Rooms.pool(kind)) do
        if (layout.minRoom or 1) <= firstRoom then eligible[#eligible + 1] = layout end
    end
    if #eligible == 0 then eligible = { Rooms.pool(kind)[1] } end
    local n = #eligible

    if kind == "combat" then
        local combatIndex = slot > ANGEL_SLOT and slot - 1 or slot
        local mirrored = (combatIndex + block) % 2 == 0
        local total, others = worldRooms(world)
        local own = total and WORLD_SLOTS[combatIndex]
        if own == "total" then return total, mirrored end
        if own then return shuffled(others, block + 1)[own], mirrored end
        local index = (total and COMMON_SLOTS[combatIndex]) or combatIndex
        return shuffled(eligible, block + 1)[(index - 1) % n + 1], mirrored
    end
    -- Arenas and sanctuaries: simple rotation (boss rush chains neighbouring rooms)
    return eligible[(roomNumber - 1 + block) % n + 1], block % 2 == 1
end
```

In `Rooms.validateAll`, after the `for kind, pool in pairs(POOLS) do … end` loop, add:

```lua
    for _, pool in pairs(Rooms.WORLDS) do
        for _, layout in ipairs(pool) do
            for _, grid in ipairs({ layout.grid, Rooms.mirror(layout.grid) }) do
                local ok, err = Rooms.validate({ id = layout.id, grid = grid }, "combat")
                if not ok then errors[#errors + 1] = err end
            end
        end
    end
```

- [ ] **Step 4: run** `lua5.1 tests/run.lua` — Expected: `153 tests réussis, 0 échecs`. A grid rejected by `Rooms.validate` is fixed in the grid itself (the message names the room and the cell).

- [ ] **Step 5: commit** `feat(rooms): four hand-drawn rooms per world, one total room each`

---

### Task 2: obstacle manager receives the world; wind through collisions

**Files:** `src/core/obstacle_manager.lua`, `src/states/game.lua`, `src/dev/selftest.lua`.

- [ ] **Step 1: failing self-test** — in `src/dev/selftest.lua`, right after the wall-sliding check (`print("[TEST] Wall Sliding …")`), add:

```lua
            -- B2. Wind gusts push the hero through collisions, never into a rock
            local ObstacleManager = require("src.core.obstacle_manager")
            local windOm = ObstacleManager.new()
            windOm:setTheme("sky", "wind")
            windOm:generate(400, 300, 41, "arena")
            windOm.rocks = { { x = 200, y = 200, w = 40, h = 40 } }
            windOm.hazards = { { x = 120, y = 150, w = 200, h = 120, kind = "wind", windX = 1, windY = 0 } }
            local p = g.player
            local px, py = p.x, p.y
            p.x, p.y = 190, 220
            for _ = 1, 5 do windOm:update(0.2, p, g.fctPool, g.dummyPool) end
            assert(not windOm:isBlocked(p.x, p.y, p.radius), "Wind must not push the hero into a rock")
            p.x, p.y = px, py
            print("[TEST] Wind gusts VALIDATED: the hero is pushed through collisions.")
```

Run `rm -f error_log.txt; DISPLAY=:5 SDL_AUDIODRIVER=dummy timeout 300 ./run.sh --test; head -1 error_log.txt`
Expected: `… Wind must not push the hero into a rock`.

- [ ] **Step 2: implement** — `src/core/obstacle_manager.lua`:

Add `local Physics = require("src.core.physics")` with the other requires, and near the other constants `local WIND_PUSH = 120 -- px/s`.

Replace the wind branch:

```lua
            elseif hz.kind == "wind" then
                -- Bourrasque : pousse le héros vers le nord-est, sans dégâts
                local push = 120 * dt
                player.x = player.x + push * (hz.windX or 1)
                player.y = player.y + push * (hz.windY or -0.35)
```

with:

```lua
            elseif hz.kind == "wind" then
                -- Gust: pushes the hero, through collisions (it used to shove him into rocks)
                Physics.moveAndSlide(player, WIND_PUSH * (hz.windX or 1), WIND_PUSH * (hz.windY or -0.35), dt,
                    player.radius, self, false, (player.maxX or 600) + 22, (player.maxY or 440) + 22)
```

Change the signature `function ObstacleManager:generate(mapW, mapH, roomNumber, kind, layout)` to
`function ObstacleManager:generate(mapW, mapH, roomNumber, kind, layout, world)` and the call
`layout, mirrored = Rooms.pick(kind or "combat", self.roomNumber)` to
`layout, mirrored = Rooms.pick(kind or "combat", self.roomNumber, world)`.
In `ObstacleManager.prefetch`, change `om:generate(spec.mapW, spec.mapH, spec.room, spec.kind)` to
`om:generate(spec.mapW, spec.mapH, spec.room, spec.kind, nil, spec.chapterIndex)`.

`src/states/game.lua` `setupRoom`: change
`self.obstacleManager:generate(self.mapW, self.mapH, roomNum, spec.kind)` to
`self.obstacleManager:generate(self.mapW, self.mapH, roomNum, spec.kind, nil, spec.chapterIndex)`.

In the self-test block "Aucune grille répétée dans un chapitre" (`Rooms.pick("combat", room)`), pass the
world: `Rooms.pick("combat", room, block + 1)`; in the spawn check loop over
`for _, kind in ipairs({ "combat", "arena" })`, add after it:

```lua
            for world, pool in ipairs(Rooms.WORLDS) do
                for _, layout in ipairs(pool) do
                    om:generate(620, 540, 12, "combat", layout, world)
                    local placed = om:placeSpawns(WorldManager.generateWave(3, 12, 620, 540))
                    for _, sp in ipairs(placed) do
                        assert(not om:isBlocked(sp.x, sp.y, 12), "Spawn blocked in layout '" .. layout.id .. "'")
                    end
                end
            end
```

- [ ] **Step 3: verify** — unit tests 153/153, self-test `code=0` with the `Wind gusts VALIDATED` line.

- [ ] **Step 4: commit** `fix(obstacles): wind pushes through collisions; rooms know their world`

---

### Task 3: per-world obstacle shapes and ground details

**Files:** Create `src/render/sprites/biomes.lua`; modify `src/render/art.lua`, `tools/bake/main.lua`, `src/core/obstacle_manager.lua`, `src/core/world_manager.lua`; regenerate the atlas.

- [ ] **Step 1: sprites** — `src/render/sprites/biomes.lua` with `obstacle_cactus`, `obstacle_ice`,
`obstacle_obsidian`, `obstacle_floatstone`, `obstacle_monolith` (40 × 40, centred like `stump_l`) and the
ground details `dry_grass`, `crystal_shard`, `frost`, `ash_pile`, `charred_twig`, `void_debris`,
`rune_mark`, `void_grass` (full code in the file; PixGen shapes + small ASCII grids).

- [ ] **Step 2: register** `"src.render.sprites.biomes",` after `"src.render.sprites.sanctuary",` in
`SPRITE_MODULES` of `src/render/art.lua` and `tools/bake/main.lua`.

- [ ] **Step 3: obstacle sprite per world** — in `obstacle_manager.lua`, near `STUMP_LIFT`:

```lua
-- Single-cell obstacle drawn per world (same collision box as the forest stump)
local STUMP_SPRITES = {
    sand = "obstacle_cactus", crystal = "obstacle_ice", lava = "obstacle_obsidian",
    sky = "obstacle_floatstone", void = "obstacle_monolith",
}
```

and in `buildProps` replace `prop.sprite = "stump_l"` with
`prop.sprite = STUMP_SPRITES[self.themeVariant or ""] or "stump_l"`.

- [ ] **Step 4: ground details** — `WorldManager.THEMES` `decals`:
1: add `"mushroom"`; 2: `{ "bones", "pebbles", "tuft_c", "dry_grass", "bones", "dry_grass" }`;
3: `{ "pebbles", "ice_patch", "crystal_shard", "frost" }`;
4: `{ "pebbles", "lava_crack", "bones", "ash_pile", "charred_twig" }`;
5: `{ "pebbles", "ice_patch", "feather", "cloud_wisp", "flowers_w" }`;
6: `{ "pebbles", "bones", "void_debris", "rune_mark", "void_grass" }`.

- [ ] **Step 5: bake and check** — `love tools/bake` (no `SpriteAtlas trop petit`; if it appears,
raise `SpriteAtlas.new(1024, 512)` to `(1024, 576)` in both `tools/bake/main.lua` and
`src/render/art.lua`). Extract the new sprites to an image and look at them.

- [ ] **Step 6: verify and commit** — unit + self-test + `python3 tools/lua_bytecode.py --selftest`;
commit `feat(art): world-specific obstacles and ground details`.

---

### Task 4: on-console check and integration

- [ ] Full build (`python3 tools/build_all.py`), 3DSX in Azahar: inject a run at room 26
(crystal, slot 6 = total room) and room 46 (sky storm), check the room, FPS and `rejets 0` in
`perf_log.txt`; restore the emulator save.
- [ ] Rebase on `origin/main`, re-bake the atlas if it conflicts, run all tests, push to `main`.
