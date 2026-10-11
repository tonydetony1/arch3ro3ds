# Act II step 1 — acts, Act II launch and the CONTINUE choice — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the run into two acts: Act I (floors 1-50) ends with a choice to continue into Act II, and Act II (Void City, floors 51-60 for now) can be launched from the hub with a head start and ends with its own victory.

**Architecture:** Acts are pure functions in `src/core/world_manager.lua` (`ACT_WORLDS`, `actFloors`, `actOfRoom`, `actOfWorld`, `offersNextAct`); Act II grows by itself when worlds 7-10 are added to `CHAPTERS`. `GameState` reads a new `params.act`, starts the run on the act's first floor, and chains queued drafts. The Act I victory opens a small bottom-screen choice (`src/ui/act_choice.lua`) instead of ending the run at once.

**Tech Stack:** Lua 5.1 (LuaJIT on 3DS), LOVE 11 API through LOVE Potion, unit tests with `lua5.1 tests/run.lua`, PC self-test with `love . --test`.

**Spec:** `docs/superpowers/specs/2026-10-11-act-2-worlds-design.md` (delivery step 1).

---

## Before you start

- **Prerequisite:** PR #9 (`fix/extra-life-revive`) is merged into `main`. This plan uses `Save.setFloorRecord`, `tests/love_stubs.lua` and the `finishRun` from that branch.
- Work in a new worktree from the up-to-date `origin/main`:

```bash
git fetch origin
git worktree add -b feat/act-2-engine .claude/worktrees/act-2-engine origin/main
cd .claude/worktrees/act-2-engine
lua5.1 tests/run.lua
```

Expected: `N tests réussis, 0 échecs`.

- Rules from `AGENTS.md`: English code, comments and commits; Conventional Commits; zero allocations in `update`/`draw` loops; never write the name of the commercial game this project is inspired by.
- `love . --test` rewrites the real PC save (`~/.local/share/love/arch3ro`). Run it only in a harness with its own identity (Task 8).

### Deviations from the spec, decided while planning

- The sanctuary theme move (7/8 → 11/12) is done in step 2 (world 7). It needs an atlas re-bake (ground tiles are named `ground_<theme>_<v>`), and step 1 adds no art, so step 1 does not need it.
- CONTINUE is offered in the game itself, right after the golden victory pause, instead of on the end-of-run screen. The end-of-run screen only knows a saved snapshot of the run, and resuming from a snapshot still loses table-based state (orbital blades, skill elements). Staying in `GameState` keeps the build intact.
- Act II gets the start wheel on its first floor (51), like floor 1, and the head-start drafts open right after it.

## File structure

| File | Responsibility |
|---|---|
| `src/core/world_manager.lua` (modify) | Acts: which floors and worlds each act covers, act of a floor or world, victory floors, floor totals; world of a floor with the Abyss cycle; absolute world depth |
| `src/data/save.lua` (modify) | `Save.isActUnlocked`, `Save.setChapter` clamped to the real world count |
| `src/data/balance.lua` (modify) | `Balance.ACT2_HEAD_START_DRAFTS` |
| `src/ui/act_choice.lua` (create) | Geometry, drawing and touch test of the CONTINUE / END THE RUN choice |
| `src/states/game.lua` (modify) | `params.act`, run start floor, queued drafts, act choice, boss damage by depth, clears per act |
| `src/states/gameover.lua` (modify) | Victory title per act, AGAIN/RETRY relaunches the same act |
| `src/states/menu.lua` (modify) | Launch the act of the selected world, Act II worlds unlocked by the Act I clear |
| `tests/test_acts.lua` (create) | Act functions and `Save.isActUnlocked` |
| `tests/test_act_two.lua` (create) | Act II start, head start, CONTINUE and END THE RUN, Act II victory |
| `tests/test_world_progress.lua`, `tests/test_stage_label.lua` (modify) | Follow the new world and floor rules |
| `tests/run.lua` (modify) | Register the new test files |

---

### Task 1: Act model in WorldManager

**Files:**
- Modify: `src/core/world_manager.lua` (block "WORLDS OF A RUN", currently `ROOMS_PER_WORLD` to `worldProgress`)
- Create: `tests/test_acts.lua`
- Modify: `tests/test_stage_label.lua`, `tests/test_world_progress.lua`, `tests/run.lua`

- [ ] **Step 1: Write the failing tests**

Create `tests/test_acts.lua`:

```lua
-- tests/test_acts.lua
-- Acts of the Ascension: Act I = worlds 1-5 (floors 1-50), Act II = worlds 6-10 (floors 51-100).
-- Act II ends with the last world that exists, so it grows as new worlds ship.
local WorldManager = require("src.core.world_manager")

local LAST_FLOOR = #WorldManager.CHAPTERS * WorldManager.ROOMS_PER_WORLD

local T = {}

T["Act I covers floors 1 to 50"] = function()
    local first, last = WorldManager.actFloors(1)
    assert(first == 1 and last == 50, tostring(first) .. "-" .. tostring(last))
end

T["Act II starts on floor 51 and ends with the last world"] = function()
    local first, last = WorldManager.actFloors(2)
    assert(first == 51 and last == LAST_FLOOR, tostring(first) .. "-" .. tostring(last))
end

T["there is no Act III"] = function()
    assert(WorldManager.actFloors(3) == nil)
end

T["act of a floor"] = function()
    assert(WorldManager.actOfRoom(1) == 1)
    assert(WorldManager.actOfRoom(50) == 1)
    assert(WorldManager.actOfRoom(51) == 2)
    assert(WorldManager.actOfRoom(LAST_FLOOR) == 2)
    assert(WorldManager.actOfRoom(LAST_FLOOR + 1) == nil, "Abyss floors past the last act")
end

T["act of a world"] = function()
    assert(WorldManager.actOfWorld(1) == 1)
    assert(WorldManager.actOfWorld(5) == 1)
    assert(WorldManager.actOfWorld(6) == 2)
end

T["the end of Act I offers the next act, the end of Act II does not"] = function()
    assert(WorldManager.offersNextAct("ascension", 50) == true)
    assert(WorldManager.offersNextAct("ascension", LAST_FLOOR) == false)
    assert(WorldManager.offersNextAct("ascension", 49) == false)
    assert(WorldManager.offersNextAct("infinite", 50) == false)
end

T["the world depth keeps counting past the last world"] = function()
    assert(WorldManager.worldDepth(1) == 1)
    assert(WorldManager.worldDepth(60) == 6)
    assert(WorldManager.worldDepth(61) == 7)
    assert(WorldManager.worldDepth(125) == 13)
end

T["the Abyss cycles the worlds past the last floor"] = function()
    local n = #WorldManager.CHAPTERS
    assert(WorldManager.worldOfRoom(LAST_FLOOR) == n)
    assert(WorldManager.worldOfRoom(LAST_FLOOR + 1) == 1)
    assert(WorldManager.worldOfRoom(LAST_FLOOR + 10) == 1)
    assert(WorldManager.worldOfRoom(LAST_FLOOR + 11) == 2)
end

return T
```

Replace the body of `tests/test_stage_label.lua` from `T["Ascension counts up to 50 floors"]` to the end with:

```lua
T["Act I counts up to 50 floors"] = function()
    assert(WorldManager.floorTotal("ascension", 1) == 50)
    assert(WorldManager.floorTotal("ascension", 50) == 50)
end

T["Act II counts up to its last floor"] = function()
    local _, last = WorldManager.actFloors(2)
    assert(WorldManager.floorTotal("ascension", 51) == last)
    assert(WorldManager.floorTotal("ascension", 57) == last)
end

T["past the last act there is no total"] = function()
    local _, last = WorldManager.actFloors(2)
    assert(WorldManager.floorTotal("ascension", last + 1) == nil)
end

T["the endless Abyss never shows a total"] = function()
    assert(WorldManager.floorTotal("infinite", 3) == nil)
    assert(WorldManager.floorTotal("infinite", 80) == nil)
end

T["event modes show no total"] = function()
    assert(WorldManager.floorTotal("boss_rush", 3) == nil)
    assert(WorldManager.floorTotal("survival", 3) == nil)
end

T["the stage text adds the total only when there is one"] = function()
    local _, last = WorldManager.actFloors(2)
    assert(WorldManager.stageText("ascension", 7) == "STAGE 7 / 50")
    assert(WorldManager.stageText("ascension", 57) == "STAGE 57 / " .. last)
    assert(WorldManager.stageText("infinite", 7) == "STAGE 7")
end

T["clearing the last floor of an act ends it"] = function()
    local _, last = WorldManager.actFloors(2)
    assert(WorldManager.isFinalFloor("ascension", 50) == true)
    assert(WorldManager.isFinalFloor("ascension", last) == true)
    assert(WorldManager.isFinalFloor("ascension", 49) == false)
    assert(WorldManager.isFinalFloor("ascension", 1) == false)
    assert(WorldManager.isFinalFloor("ascension", 51) == false)
end

T["the Abyss and the event modes never end on a floor"] = function()
    assert(WorldManager.isFinalFloor("infinite", 50) == false)
    assert(WorldManager.isFinalFloor("boss_rush", 50) == false)
    assert(WorldManager.isFinalFloor("survival", 50) == false)
end

return T
```

Also update the header comment of `tests/test_stage_label.lua` to:

```lua
-- tests/test_stage_label.lua
-- The floor counter shows the length of the current act (50 for Act I, the last floor of Act II
-- after that). The Abyss and the event modes have no total. Clearing the last floor of an act
-- ends it with a victory.
```

Replace `tests/test_world_progress.lua` with:

```lua
-- tests/test_world_progress.lua
-- Worlds of a run (10 floors each) and their progress in the hub, derived from the best floor
-- ever reached. Past the last world, the Abyss cycles the worlds again.
local WorldManager = require("src.core.world_manager")

local LAST_FLOOR = #WorldManager.CHAPTERS * WorldManager.ROOMS_PER_WORLD

local T = {}

T["world of a floor: 10 floors per world"] = function()
    assert(WorldManager.worldOfRoom(1) == 1)
    assert(WorldManager.worldOfRoom(10) == 1)
    assert(WorldManager.worldOfRoom(11) == 2)
    assert(WorldManager.worldOfRoom(50) == 5)
    assert(WorldManager.worldOfRoom(51) == 6)
    assert(WorldManager.worldOfRoom(LAST_FLOOR + 1) == 1, "the Abyss cycles back to world 1")
end

T["world floors: every world has a first and a last floor"] = function()
    local first, last = WorldManager.worldFloors(3)
    assert(first == 21 and last == 30, first .. "-" .. tostring(last))
    first, last = WorldManager.worldFloors(6)
    assert(first == 51 and last == 60, first .. "-" .. tostring(last))
end

T["progress at floor 21: worlds 1-2 cleared, world 3 started, the rest locked"] = function()
    local w1 = WorldManager.worldProgress(1, 21)
    assert(w1.unlocked and w1.cleared and w1.reached == 10 and w1.total == 10)
    local w2 = WorldManager.worldProgress(2, 21)
    assert(w2.unlocked and w2.cleared and w2.reached == 10)
    local w3 = WorldManager.worldProgress(3, 21)
    assert(w3.unlocked and not w3.cleared and w3.reached == 1, tostring(w3.reached))
    for world = 4, 6 do
        local w = WorldManager.worldProgress(world, 21)
        assert(not w.unlocked and not w.cleared and w.reached == 0, "world " .. world)
    end
end

T["progress of a new save: only the first world is open"] = function()
    local w1 = WorldManager.worldProgress(1, 1)
    assert(w1.unlocked and not w1.cleared and w1.reached == 1)
    assert(not WorldManager.worldProgress(2, 1).unlocked)
end

T["an open act unlocks its first world before any of its floor is reached"] = function()
    local w6 = WorldManager.worldProgress(6, 50, 51)
    assert(w6.unlocked and w6.reached == 0 and not w6.cleared)
    assert(not WorldManager.worldProgress(6, 50).unlocked, "Act II stays locked without the clear")
end

T["progress in Void City: floors reached out of 10"] = function()
    local w6 = WorldManager.worldProgress(6, 55)
    assert(w6.unlocked and not w6.cleared and w6.reached == 5 and w6.total == 10)
end

return T
```

Add `"tests.test_acts",` at the end of the `files` list in `tests/run.lua`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `lua5.1 tests/run.lua 2>&1 | grep -E "ÉCHEC|réussis"`
Expected: failures in `test_acts` (`attempt to call field 'actFloors' (a nil value)`), `test_stage_label` (Act II totals) and `test_world_progress` (Void City has a last floor, openFloor).

- [ ] **Step 3: Implement the act model**

In `src/core/world_manager.lua`, replace the whole block from the comment `-- WORLDS OF A RUN: 10 floors per world, the last world (Abyss only) is endless` down to the end of `function WorldManager.worldProgress` with:

```lua
-- ============================================================================
-- WORLDS OF A RUN: 10 floors per world. Past the last world, the Abyss cycles them again.
-- ============================================================================
WorldManager.ROOMS_PER_WORLD = 10

-- Absolute world depth of a floor (1 for floors 1-10, 7 for 61-70...), even past the last
-- world: bosses and elite blasts scale on it, so the Abyss keeps getting tougher
function WorldManager.worldDepth(roomNumber)
    return math.floor((math.max(1, roomNumber or 1) - 1) / WorldManager.ROOMS_PER_WORLD) + 1
end

-- World whose scenery and monsters a floor uses (the Abyss cycles the worlds)
function WorldManager.worldOfRoom(roomNumber)
    return (WorldManager.worldDepth(roomNumber) - 1) % #WorldManager.CHAPTERS + 1
end

-- First and last floor of a world
function WorldManager.worldFloors(world)
    local first = (world - 1) * WorldManager.ROOMS_PER_WORLD + 1
    return first, first + WorldManager.ROOMS_PER_WORLD - 1
end

-- Hub progress of a world from the best floor ever reached. `openFloor` (optional) is the first
-- floor of an act the player may start from: its world shows as unlocked before it is reached.
-- { first, last, total, reached, unlocked, cleared }
function WorldManager.worldProgress(world, bestFloor, openFloor)
    local first, last = WorldManager.worldFloors(world)
    local best = math.max(1, bestFloor or 1)
    local total = last - first + 1
    local reached = math.min(total, math.max(0, best - first + 1))
    return {
        first = first, last = last, total = total, reached = reached,
        unlocked = best >= first or (openFloor ~= nil and first <= openFloor),
        cleared = best > last,
    }
end

-- ============================================================================
-- ACTS OF THE ASCENSION: Act I = worlds 1-5, Act II = worlds 6-10. Clearing the last floor of an
-- act is a victory. An act ends with the last world that exists, so Act II grows as worlds ship.
-- ============================================================================
WorldManager.ACT_WORLDS = { { 1, 5 }, { 6, 10 } }
WorldManager.ACT_NAMES = { "ACT I", "ACT II" }

-- Length of Act I, shown on the hub record card
WorldManager.ASCENSION_FLOORS = 50

-- First and last floor of an act, or nil when none of its worlds exists yet
function WorldManager.actFloors(act)
    local span = WorldManager.ACT_WORLDS[act]
    if not span then return nil end
    local lastWorld = math.min(span[2], #WorldManager.CHAPTERS)
    if lastWorld < span[1] then return nil end
    local first = WorldManager.worldFloors(span[1])
    local _, last = WorldManager.worldFloors(lastWorld)
    return first, last
end

-- Act of a floor, or nil past the last act (the Abyss)
function WorldManager.actOfRoom(roomNumber)
    for act = 1, #WorldManager.ACT_WORLDS do
        local first, last = WorldManager.actFloors(act)
        if first and roomNumber >= first and roomNumber <= last then return act end
    end
    return nil
end

-- Act a world belongs to
function WorldManager.actOfWorld(world)
    for act, span in ipairs(WorldManager.ACT_WORLDS) do
        if world >= span[1] and world <= span[2] then return act end
    end
    return nil
end

-- True when clearing this floor ends an Ascension act (floor 50, then the last floor of Act II).
-- Exact floors only: an admin test run started past them keeps going.
function WorldManager.isFinalFloor(mode, roomNumber)
    if mode ~= "ascension" then return false end
    local act = WorldManager.actOfRoom(roomNumber)
    if not act then return false end
    local _, last = WorldManager.actFloors(act)
    return roomNumber == last
end

-- True when the act ending on this floor is followed by another one (CONTINUE is offered)
function WorldManager.offersNextAct(mode, roomNumber)
    if not WorldManager.isFinalFloor(mode, roomNumber) then return false end
    return WorldManager.actFloors(WorldManager.actOfRoom(roomNumber) + 1) ~= nil
end

-- Length of the current act in Ascension ("STAGE 7 / 50"), nil elsewhere
function WorldManager.floorTotal(mode, roomNumber)
    if mode ~= "ascension" then return nil end
    local act = WorldManager.actOfRoom(roomNumber or 1)
    if not act then return nil end
    local _, last = WorldManager.actFloors(act)
    return last
end

function WorldManager.stageText(mode, roomNumber)
    local total = WorldManager.floorTotal(mode, roomNumber)
    return "STAGE " .. roomNumber .. (total and (" / " .. total) or "")
end
```

Delete the old `ASCENSION_FLOORS`, `isFinalFloor`, `floorTotal` and `stageText` definitions above that block, which this code replaces.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `lua5.1 tests/run.lua 2>&1 | grep -E "ÉCHEC|réussis"`
Expected: `… tests réussis, 0 échecs`. If `test_world_encounter` fails, check whether it assumed floors past 60 stay in world 6 and update the assertion to `WorldManager.worldOfRoom`, which now cycles.

- [ ] **Step 5: Commit**

```bash
git add src/core/world_manager.lua tests/test_acts.lua tests/test_stage_label.lua tests/test_world_progress.lua tests/run.lua
git commit -m "feat(acts): split the Ascension into Act I and Act II

Act I covers worlds 1-5 (floors 1-50) and Act II worlds 6-10, ending
with the last world that exists (Void City, floor 60, for now). Each act
ends with a victory on its last floor and the floor counter shows the
length of the current act. Past the last world the Abyss cycles the
worlds; worldDepth keeps the absolute depth for difficulty.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Boss and elite damage scale with the world depth

Today bosses read `d.chapterIndex` (`src/core/boss_brain.lua:30`) and elite blasts take `self.chapterIndex` (`src/states/game.lua`, `EliteAffixes.onDeath`). Once the Abyss cycles worlds, the chapter index drops back to 1 on floor 61, so both must use the depth.

**Files:**
- Modify: `src/states/game.lua` (`GameState:spawnMonstersNow`, the `EliteAffixes.onDeath` call)
- Create: `tests/test_act_two.lua`
- Modify: `tests/run.lua`

- [ ] **Step 1: Write the failing test**

Create `tests/test_act_two.lua`:

```lua
-- tests/test_act_two.lua
-- Act II: launched from the hub on its first floor with a head start, reached from Act I by
-- CONTINUE, ended by its own victory. Bosses keep scaling with the absolute world depth.

local GameState = require("src.states.game")
local Save = require("src.data.save")
local Balance = require("src.data.balance")
local WorldManager = require("src.core.world_manager")
local withLoveStubs = require("tests.love_stubs")

-- A game state whose switches to other states are recorded
local function newGame()
    local g = setmetatable({}, { __index = GameState })
    g.switched = nil
    g.sm = { switch = function(_, name, data) g.switched = { name = name, data = data } end }
    return g
end

-- Runs the game frame by frame until `done(g)` (a hit stop left by another test can hold frames)
local function runUntil(g, done)
    for _ = 1, 900 do
        if done(g) then return end
        g:update(1 / 60)
    end
    error("condition never reached")
end

local T = {}

T["bosses scale with the world depth, not the cycled world"] = function()
    withLoveStubs(function()
        local g = newGame()
        g:enter({ mode = "infinite" })
        g.roomNumber = 70
        g.pendingSpawns = { { x = 100, y = 100, hp = 500, type = "golem", isBoss = true } }
        g:spawnMonstersNow()
        local boss
        for i = 1, g.dummyPool.activeCount do
            local d = g.dummyPool.items[g.dummyPool.activeList[i]]
            if d.isBoss then boss = d end
        end
        assert(boss, "no boss spawned")
        assert(boss.chapterIndex == 7, "boss damage depth " .. tostring(boss.chapterIndex))
    end)
end

return T
```

Add `"tests.test_act_two",` at the end of the `files` list in `tests/run.lua`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `lua5.1 tests/run.lua 2>&1 | grep -A1 "ÉCHEC"`
Expected: `boss damage depth 1` (floor 70 is world 1 of the Abyss cycle with 6 worlds).

- [ ] **Step 3: Use the depth**

In `src/states/game.lua`, `GameState:spawnMonstersNow`, replace:

```lua
            d.chapterIndex = self.chapterIndex -- dégâts des boss selon le chapitre
```

with:

```lua
            -- Boss damage scales with the absolute world depth (the Abyss cycles the worlds)
            d.chapterIndex = WorldManager.worldDepth(self.roomNumber)
```

and replace:

```lua
    local blast = EliteAffixes.onDeath(target, self.chapterIndex)
```

with:

```lua
    local blast = EliteAffixes.onDeath(target, WorldManager.worldDepth(self.roomNumber))
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `lua5.1 tests/run.lua 2>&1 | grep -E "ÉCHEC|réussis"`
Expected: `… tests réussis, 0 échecs`.

- [ ] **Step 5: Commit**

```bash
git add src/states/game.lua tests/test_act_two.lua tests/run.lua
git commit -m "fix(difficulty): bosses and elite blasts scale with the world depth

Boss damage and the volatile elite blast read the world index, which
stopped at 6 and now cycles back to 1 in the Abyss. They use the
absolute world depth instead, so they keep scaling past floor 60.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Act unlock and world selection in the save

**Files:**
- Modify: `src/data/save.lua` (`Save.setChapter`, new `Save.isActUnlocked`)
- Modify: `tests/test_acts.lua`

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_acts.lua`, before `return T`:

```lua
local Save = require("src.data.save")

-- Runs `fn(records)` on fresh records, then restores them
local function withRecords(fn)
    local records = Save.get().records
    local saved = {}
    for k, v in pairs(records) do saved[k] = v end
    for k in pairs(saved) do records[k] = nil end
    records.ascensionMax, records.infiniteMax = 1, 0
    local ok, err = pcall(fn, records)
    for k in pairs(records) do records[k] = nil end
    for k, v in pairs(saved) do records[k] = v end
    assert(ok, err)
end

T["Act I is always open"] = function()
    withRecords(function() assert(Save.isActUnlocked(1)) end)
end

T["Act II opens with the first Act I clear"] = function()
    withRecords(function(records)
        assert(not Save.isActUnlocked(2))
        records.ascensionClears = 1
        assert(Save.isActUnlocked(2))
    end)
end

T["Act II is open on saves that went past floor 50 before the victory existed"] = function()
    withRecords(function(records)
        records.ascensionMax = 57
        assert(Save.isActUnlocked(2))
    end)
end

T["the world carousel reaches the last world"] = function()
    local saved = Save.get().selectedChapter
    local real = Save.save
    Save.save = function() end
    local ok, err = pcall(function()
        assert(Save.setChapter(99) == #WorldManager.CHAPTERS)
        assert(Save.setChapter(0) == 1)
    end)
    Save.save = real
    Save.get().selectedChapter = saved
    assert(ok, err)
end
```

These tests run without `love_stubs`: `Save.get()` works with the plain `love.filesystem` stub that the earlier test files install (`tests.test_acts` is last in `tests/run.lua`).

- [ ] **Step 2: Run the tests to verify they fail**

Run: `lua5.1 tests/run.lua 2>&1 | grep -A1 "ÉCHEC"`
Expected: `attempt to call field 'isActUnlocked' (a nil value)`; the carousel test fails only if the world count is not 6 (today it passes by chance, keep it as a guard).

- [ ] **Step 3: Implement**

In `src/data/save.lua`, replace `Save.setChapter` with:

```lua
function Save.setChapter(chapIndex)
    local WorldManager = require("src.core.world_manager")
    local d = Save.get()
    d.selectedChapter = math.max(1, math.min(#WorldManager.CHAPTERS, chapIndex))
    Save.save()
    return d.selectedChapter
end

-- Act I is always open. Act II opens with the first Act I clear, or on saves that went past
-- floor 50 before the floor-50 victory existed.
function Save.isActUnlocked(act)
    if act <= 1 then return true end
    local records = Save.get().records or {}
    if act == 2 then
        return (records.ascensionClears or 0) >= 1 or (records.ascensionMax or 1) > 50
    end
    return false
end
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `lua5.1 tests/run.lua 2>&1 | grep -E "ÉCHEC|réussis"`
Expected: `… tests réussis, 0 échecs`.

- [ ] **Step 5: Commit**

```bash
git add src/data/save.lua tests/test_acts.lua
git commit -m "feat(acts): Act II unlocks with the first Act I clear

Save.isActUnlocked opens Act II after an Act I clear, or on saves that
went past floor 50 before the victory existed. The world carousel is
clamped to the real world count instead of 6.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Act II start floor and the queued head-start drafts

**Files:**
- Modify: `src/data/balance.lua` (after `Balance.ENERGY`)
- Modify: `src/states/game.lua` (`GameState:enter`, `roomSpec`, `setupRoom`, `pickDraft`, `specialRoomDone`, new `openQueuedDraft`)
- Modify: `tests/test_act_two.lua`

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_act_two.lua`, before `return T`:

```lua
-- Runs `fn` with the Glory talent off (it adds a free draft at the start of every run)
local function withoutGlory(fn)
    local talents = Save.getTalents()
    local glory = talents.glory
    talents.glory = 0
    local ok, err = pcall(fn)
    talents.glory = glory
    assert(ok, err)
end

T["an Act II run starts on its first floor with the start wheel"] = function()
    withLoveStubs(function() withoutGlory(function()
        local g = newGame()
        g:enter({ mode = "ascension", act = 2 })
        assert(g.roomNumber == 51, "started on floor " .. g.roomNumber)
        assert(g.phase == "wheel", "no start wheel on floor 51: " .. tostring(g.phase))
    end) end)
end

T["the Act II head start chains its drafts after the wheel"] = function()
    withLoveStubs(function() withoutGlory(function()
        local g = newGame()
        g:enter({ mode = "ascension", act = 2 })
        g:specialRoomDone()
        for i = 1, Balance.ACT2_HEAD_START_DRAFTS do
            assert(g.isDrafting, "draft " .. i .. " did not open")
            g:pickDraft(1)
        end
        assert(not g.isDrafting, "one draft too many")
        assert(#g.acquiredSkills == Balance.ACT2_HEAD_START_DRAFTS)
    end) end)
end

T["a normal Ascension run still starts on floor 1"] = function()
    withLoveStubs(function() withoutGlory(function()
        local g = newGame()
        g:enter({ mode = "ascension" })
        assert(g.roomNumber == 1)
        g:specialRoomDone()
        assert(not g.isDrafting, "no head start in Act I")
    end) end)
end

T["the act is ignored outside the Ascension"] = function()
    withLoveStubs(function() withoutGlory(function()
        local g = newGame()
        g:enter({ mode = "infinite", act = 2 })
        assert(g.roomNumber == 1)
    end) end)
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `lua5.1 tests/run.lua 2>&1 | grep -A1 "ÉCHEC"`
Expected: `started on floor 1` and `attempt to perform arithmetic on field 'ACT2_HEAD_START_DRAFTS' (a nil value)`.

- [ ] **Step 3: Implement**

In `src/data/balance.lua`, after the `Balance.ENERGY = { ... }` table, add:

```lua
-- A fresh Act II run starts on floor 51, where rooms hold about 30 times the HP of floor 1:
-- the hero gets this many drafts right after the start wheel. Tune on Azahar and on console.
Balance.ACT2_HEAD_START_DRAFTS = 8
```

In `src/states/game.lua`, `GameState:enter`, next to `self.hasSpunStartWheel = false`, add:

```lua
    -- First floor of this run (51 for Act II): the start wheel is played there
    self.runStartRoom = 1
    -- Drafts waiting to open one after the other (Glory talent, Act II head start)
    self.queuedDrafts = 0
```

Then, right after the admin `params.startRoom` block and before `self:setupRoom(self.roomNumber)`, add:

```lua
    -- Act II launched from the hub: the run starts on the act's first floor with a head start
    if params.act and self.gameMode == "ascension" and not params.resume and not params.startRoom then
        local first = WorldManager.actFloors(params.act)
        if first and first > 1 then
            self.runStartRoom = first
            self.roomNumber = first
            self.queuedDrafts = Balance.ACT2_HEAD_START_DRAFTS
        end
    end
```

Replace the Glory talent block after `self:setupRoom(self.roomNumber)`:

```lua
    -- Talent Gloire : offre immédiatement un Draft de départ gratuit !
    -- Si la salle 1 débute par la Roue de la Fortune, différer le Draft juste après la roue
    if talents and (talents.glory or 0) >= 1 then
        if self.phase == "wheel" then
            self.pendingGloryDraft = true
        else
            self:openDraft()
        end
    end
```

with:

```lua
    -- Glory talent: one free draft at the start. Queued drafts open after the start wheel.
    if talents and (talents.glory or 0) >= 1 then
        self.queuedDrafts = self.queuedDrafts + 1
    end
    if self.phase ~= "wheel" then self:openQueuedDraft() end
```

In `GameState:roomSpec`, replace `(roomNum == 1 and not self.hasSpunStartWheel)` with `(roomNum == self.runStartRoom and not self.hasSpunStartWheel)`. In `GameState:setupRoom`, replace `elseif roomNum == 1 and not self.hasSpunStartWheel then` with `elseif roomNum == self.runStartRoom and not self.hasSpunStartWheel then`.

Add after `GameState:openDraft`:

```lua
-- Opens the next queued draft, if any: the head start chains several, one per pick
function GameState:openQueuedDraft()
    if self.queuedDrafts > 0 and not self.isDrafting then
        self.queuedDrafts = self.queuedDrafts - 1
        self:openDraft()
    end
end
```

In `GameState:pickDraft`, after `self:triggerShake(0.1, 2.5)` (its last line), add:

```lua
    self:openQueuedDraft()
```

In `GameState:specialRoomDone`, replace:

```lua
        -- Talent Gloire en attente : le tirage s'ouvre maintenant que la roue est résolue
        if self.pendingGloryDraft then
            self.pendingGloryDraft = false
            self:openDraft()
        end
```

with:

```lua
        -- Drafts queued at the start (Glory, Act II head start) open once the wheel is done
        self:openQueuedDraft()
```

Check that nothing else reads `pendingGloryDraft`: `grep -rn pendingGloryDraft src` must print nothing.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `lua5.1 tests/run.lua 2>&1 | grep -E "ÉCHEC|réussis"`
Expected: `… tests réussis, 0 échecs`.

- [ ] **Step 5: Commit**

```bash
git add src/data/balance.lua src/states/game.lua tests/test_act_two.lua
git commit -m "feat(acts): an Act II run starts on floor 51 with a head start

GameState reads params.act: an Act II Ascension run starts on its first
floor, plays the start wheel there and then chains
Balance.ACT2_HEAD_START_DRAFTS drafts. Starting drafts go through one
queue, which the Glory talent now uses too.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: The CONTINUE choice at the end of Act I

**Files:**
- Create: `src/ui/act_choice.lua`
- Modify: `src/states/game.lua` (update victory block, new `continueToNextAct` and `chooseAct`, `drawBottom`, `touchpressed`, `gamepadpressed`, `keypressed`, `winRun`, `finishRun`)
- Modify: `tests/test_act_two.lua`

- [ ] **Step 1: Write the failing tests**

Add to `tests/test_act_two.lua`, before `return T`:

```lua
-- Runs `fn(records)` and restores the records afterwards
local function withRecords(fn)
    local records = Save.get().records
    local saved = {}
    for k, v in pairs(records) do saved[k] = v end
    local ok, err = pcall(fn, records)
    for k in pairs(records) do records[k] = nil end
    for k, v in pairs(saved) do records[k] = v end
    assert(ok, err)
end

-- An Ascension run that just cleared `room`
local function clearedFloor(room)
    local g = newGame()
    g:enter({ mode = "ascension" })
    g.roomNumber = room
    g:winRun()
    return g
end

T["clearing floor 50 offers to continue into Act II"] = function()
    withLoveStubs(function() withRecords(function()
        local g = clearedFloor(50)
        runUntil(g, function(s) return s.phase == "act_choice" or s.switched end)
        assert(g.phase == "act_choice", "the run ended without the choice")
    end) end)
end

T["CONTINUE goes on to floor 51 with the same build and gold"] = function()
    withLoveStubs(function() withRecords(function(records)
        local clears = records.ascensionClears or 0
        local g = clearedFloor(50)
        runUntil(g, function(s) return s.phase == "act_choice" end)
        g.goldEarnedRun = 500
        local skills = #g.acquiredSkills
        g:chooseAct("continue")
        runUntil(g, function(s) return s.roomNumber == 51 end)
        assert(not g.switched, "the run ended")
        assert(g.goldEarnedRun == 500, "gold lost: " .. g.goldEarnedRun)
        assert(#g.acquiredSkills == skills)
        assert(records.ascensionClears == clears + 1, "the Act I clear was not counted")
    end) end)
end

T["END THE RUN opens the Act I victory screen"] = function()
    withLoveStubs(function() withRecords(function()
        local g = clearedFloor(50)
        runUntil(g, function(s) return s.phase == "act_choice" end)
        g:chooseAct("finish")
        assert(g.switched and g.switched.name == "gameover" and g.switched.data.victory)
        assert(g.switched.data.act == 1)
    end) end)
end

T["clearing the last floor of Act II ends the run with its own victory"] = function()
    withLoveStubs(function() withRecords(function(records)
        local _, last = WorldManager.actFloors(2)
        local clears = records.act2Clears or 0
        local g = clearedFloor(last)
        runUntil(g, function(s) return s.switched or s.phase == "act_choice" end)
        assert(g.switched and g.switched.data.victory, "no victory screen")
        assert(g.switched.data.act == 2)
        assert(records.act2Clears == clears + 1, "the Act II clear was not counted")
    end) end)
end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `lua5.1 tests/run.lua 2>&1 | grep -A1 "ÉCHEC"`
Expected: `the run ended without the choice`, `attempt to call method 'chooseAct' (a nil value)` and `the Act II clear was not counted`.

- [ ] **Step 3: Create the choice panel**

Create `src/ui/act_choice.lua`:

```lua
-- src/ui/act_choice.lua
-- End of Act I: the bottom screen offers to go on to Act II with the same hero and build, or to
-- end the run on the victory screen. Pure drawing and hit test; GameState owns the choice.
local Skin = require("src.ui.skin")
local PixelFont = require("src.ui.pixel_font")
local Palette = require("src.render.palette")
local Config = require("src.data.config")

local ActChoice = {}

-- Buttons in cursor order (D-pad up/down)
ActChoice.BUTTONS = {
    { id = "continue", x = 20, y = 96, w = 280, h = 52, theme = "green", label = "CONTINUE TO ACT II" },
    { id = "finish",   x = 20, y = 160, w = 280, h = 44, theme = "blue",  label = "END THE RUN" },
}

-- Id of the button under (tx, ty), or nil
function ActChoice.hit(tx, ty)
    for _, b in ipairs(ActChoice.BUTTONS) do
        if tx >= b.x and tx <= b.x + b.w and ty >= b.y and ty <= b.y + b.h then return b.id end
    end
    return nil
end

-- Draws the panel; the button at `cursor` is shown pressed
function ActChoice.draw(cursor)
    local C = Palette.C
    love.graphics.setColor(0.04, 0.04, 0.06, 0.75)
    love.graphics.rectangle("fill", 0, 0, Config.BOTTOM_WIDTH, Config.BOTTOM_HEIGHT)
    Skin.panel(12, 12, Config.BOTTOM_WIDTH - 24, 72, "dark")
    PixelFont.printf("ACT I CLEAR!", 12, 22, Config.BOTTOM_WIDTH - 24, "center", C.yellow, "main", 2)
    PixelFont.printf("KEEP YOUR BUILD AND FACE THE VOID", 12, 56, Config.BOTTOM_WIDTH - 24, "center", C.white, "main")
    for i, b in ipairs(ActChoice.BUTTONS) do
        local oy = Skin.button(b.x, b.y, b.w, b.h, b.theme, cursor == i) or 0
        PixelFont.printf(b.label, b.x, b.y + oy + math.floor(b.h / 2) - 6, b.w, "center", C.white, "main")
    end
end

return ActChoice
```

`Skin.button` returns the label offset in `src/states/menu.lua` (`local oy = Skin.button(...)`); the `or 0` keeps the label right if it returns nothing.

- [ ] **Step 4: Wire the choice into GameState**

In `src/states/game.lua`, add near the other `src.ui` requires at the top:

```lua
local ActChoice = require("src.ui.act_choice")
```

Replace the victory block in `GameState:update`:

```lua
    -- Victory: a short golden pause, then the end-of-run screen
    if self.isVictory then
        self.victoryTimer = self.victoryTimer + dt
        if self.victoryTimer >= VICTORY_DELAY then self:finishRun(true) end
        return
    end
```

with:

```lua
    -- Victory: a short golden pause, then the choice to go on to the next act (end of Act I) or
    -- the end-of-run screen
    if self.isVictory then
        self.victoryTimer = self.victoryTimer + dt
        if self.phase == "victory" and self.victoryTimer >= VICTORY_DELAY then
            if WorldManager.offersNextAct(self.gameMode, self.roomNumber) then
                self.phase = "act_choice"
                self.actChoiceCursor = 1
            else
                self:finishRun(true)
            end
        end
        return
    end
```

Add after `GameState:winRun`:

```lua
-- Act I cleared and the player goes on: the clear counts (floor record, clears), the gold stays
-- in the run, and the fade leads to the first floor of Act II with the same hero and build
function GameState:continueToNextAct()
    local records = Save.get().records
    Save.setFloorRecord(self.gameMode, self.roomNumber)
    records.ascensionClears = (records.ascensionClears or 0) + 1
    Save.save()
    self.isVictory = false
    self.victoryTimer = 0
    Audio.playMusic("battle", 0.6)
    self.phase = "transition"
    self.fadeDirection = 1
end

-- Act choice made (touch, buttons or keys): "continue" or "finish"
function GameState:chooseAct(id)
    if self.phase ~= "act_choice" then return end
    Audio.play("ui_confirm", 0, 0.9)
    if id == "continue" then
        self:continueToNextAct()
    elseif id == "finish" then
        self:finishRun(true)
    end
end
```

In `GameState:winRun`, replace:

```lua
    Banner.show("chapter", "VICTORY!", "ASCENSION COMPLETE")
```

with:

```lua
    local act = WorldManager.actOfRoom(self.roomNumber) or 1
    Banner.show("chapter", "VICTORY!", WorldManager.ACT_NAMES[act] .. " COMPLETE")
```

In `GameState:finishRun`, replace:

```lua
    if victory then
        sData.records.ascensionClears = (sData.records.ascensionClears or 0) + 1
```

with:

```lua
    -- Each act counts its own clears (Act I: ascensionClears, shipped before the acts)
    local act = WorldManager.actOfRoom(self.roomNumber) or 1
    local clearsKey = (act == 2) and "act2Clears" or "ascensionClears"
    if victory then
        sData.records[clearsKey] = (sData.records[clearsKey] or 0) + 1
```

and in the `self.sm:switch("gameover", { ... })` table of the same function, replace `clears = sData.records.ascensionClears or 0,` with:

```lua
        clears = sData.records[clearsKey] or 0,
        act = act,
```

In `GameState:drawBottom`, after the draft modal block (`if self.isDrafting then ... end`), add:

```lua
    if self.phase == "act_choice" then
        ActChoice.draw(self.actChoiceCursor)
    end
```

In `GameState:touchpressed`, right after the pause button test, add:

```lua
    if self.phase == "act_choice" then
        local id = ActChoice.hit(tx, ty)
        if id then self:chooseAct(id) end
        return
    end
```

In `GameState:gamepadpressed`, right after the `start` (pause) test, add:

```lua
    if self.phase == "act_choice" then
        local n = #ActChoice.BUTTONS
        if button == "dpup" then
            self.actChoiceCursor = (self.actChoiceCursor - 2) % n + 1
        elseif button == "dpdown" then
            self.actChoiceCursor = self.actChoiceCursor % n + 1
        elseif button == "a" then
            self:chooseAct(ActChoice.BUTTONS[self.actChoiceCursor].id)
        end
        return
    end
```

In `GameState:keypressed`, as the very first lines of the function (before the pause test, since `return` would pause), add:

```lua
    if self.phase == "act_choice" then
        local n = #ActChoice.BUTTONS
        if key == "up" then
            self.actChoiceCursor = (self.actChoiceCursor - 2) % n + 1
        elseif key == "down" then
            self.actChoiceCursor = self.actChoiceCursor % n + 1
        elseif key == "return" or key == "space" or key == "a" then
            self:chooseAct(ActChoice.BUTTONS[self.actChoiceCursor].id)
        elseif key == "1" then
            self:chooseAct("continue")
        elseif key == "2" then
            self:chooseAct("finish")
        end
        return
    end
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `lua5.1 tests/run.lua 2>&1 | grep -E "ÉCHEC|réussis"`
Expected: `… tests réussis, 0 échecs`.

- [ ] **Step 6: Commit**

```bash
git add src/ui/act_choice.lua src/states/game.lua tests/test_act_two.lua
git commit -m "feat(acts): continue from the Act I victory into Act II

After the golden pause on floor 50 the bottom screen offers CONTINUE TO
ACT II or END THE RUN. Continuing counts the Act I clear and leads to
floor 51 with the same hero, build and gold. The last floor of Act II
ends the run with an ACT II COMPLETE victory, counted in act2Clears.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: The victory screen and RETRY follow the act

**Files:**
- Modify: `src/states/gameover.lua` (victory title, `GameOverState:retryRun`)
- Modify: `tests/test_act_two.lua`

- [ ] **Step 1: Write the failing test**

Add to `tests/test_act_two.lua`, before `return T`:

```lua
T["RETRY after an Act II run starts Act II again"] = function()
    local GameOverState = require("src.states.gameover")
    local launched
    local screen = setmetatable({
        sm = { switch = function(_, name, params) launched = { name = name, params = params } end },
        data = { mode = "ascension", act = 2, room = 55 },
    }, { __index = GameOverState })
    screen:retryRun()
    assert(launched.name == "game" and launched.params.act == 2, "RETRY lost the act")
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `lua5.1 tests/run.lua 2>&1 | grep -A1 "ÉCHEC"`
Expected: `RETRY lost the act`.

- [ ] **Step 3: Implement**

In `src/states/gameover.lua`, replace `GameOverState:retryRun`:

```lua
function GameOverState:retryRun()
    local mode = self.data.mode or "ascension"
    self.sm:switch("game", { mode = mode })
end
```

with:

```lua
-- AGAIN / RETRY: the same mode, and the same act (an Act II run starts again on floor 51)
function GameOverState:retryRun()
    local mode = self.data.mode or "ascension"
    self.sm:switch("game", { mode = mode, act = self.data.act })
end
```

and in the victory title, replace:

```lua
    PixelFont.printf("ASCENSION COMPLETE - " .. (self.data.room or 50) .. " FLOORS", mx - 150, 40, 300, "center",
        C.white, "main", 1, nil, 1)
```

with:

```lua
    local actName = WorldManager.ACT_NAMES[self.data.act or 1] or "ASCENSION"
    PixelFont.printf(actName .. " COMPLETE - " .. (self.data.room or 50) .. " FLOORS", mx - 150, 40, 300, "center",
        C.white, "main", 1, nil, 1)
```

`src/states/gameover.lua` already requires `WorldManager` (it calls `WorldManager.floorTotal`); check with `grep -n "local WorldManager" src/states/gameover.lua`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `lua5.1 tests/run.lua 2>&1 | grep -E "ÉCHEC|réussis"`
Expected: `… tests réussis, 0 échecs`.

- [ ] **Step 5: Commit**

```bash
git add src/states/gameover.lua tests/test_act_two.lua
git commit -m "feat(acts): the end-of-run screen names the act and RETRY replays it

The victory title reads ACT I or ACT II COMPLETE, and AGAIN / RETRY
relaunch the act the run ended in.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Launch Act II from the hub

The menu is drawing code with no unit test harness; the act decision goes into a small pure function that is tested, and the drawing change is checked by eye in Task 8.

**Files:**
- Modify: `src/states/menu.lua` (`MenuState:drawPlayTab`, `MenuState:launchGame`, new `MenuState.launchAct`)
- Modify: `tests/test_acts.lua`

- [ ] **Step 1: Write the failing test**

Add to `tests/test_acts.lua`, before `return T`:

```lua
T["the hub launches Act II only for an unlocked Act II world in Ascension"] = function()
    -- The menu module loads drawing modules: require it with LOVE stubbed
    require("tests.love_stubs")(function()
        local MenuState = require("src.states.menu")
        assert(MenuState.launchAct("ascension", 6, true) == 2)
        assert(MenuState.launchAct("ascension", 6, false) == 1, "locked Act II falls back to Act I")
        assert(MenuState.launchAct("ascension", 3, true) == 1)
        assert(MenuState.launchAct("infinite", 6, true) == nil, "the Abyss has no act")
    end)
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `lua5.1 tests/run.lua 2>&1 | grep -A1 "ÉCHEC"`
Expected: `attempt to call field 'launchAct' (a nil value)`.

- [ ] **Step 3: Implement**

In `src/states/menu.lua`, add before `function MenuState:launchGame()`:

```lua
-- Act a hub launch plays: the act of the selected world in Ascension when it is unlocked, Act I
-- otherwise; nil for the other modes (they always start on floor 1)
function MenuState.launchAct(mode, world, actUnlocked)
    if mode ~= "ascension" then return nil end
    local act = WorldManager.actOfWorld(world) or 1
    if act > 1 and not actUnlocked then return 1 end
    return act
end
```

In `MenuState:launchGame`, replace:

```lua
    self.sm:switch("game", {
        mode = self.selectedMode,
        chapter = self.saveData.selectedChapter or 1,
        boosted = boosted,
    })
```

with:

```lua
    local world = self.saveData.selectedChapter or 1
    local act = MenuState.launchAct(self.selectedMode, world, Save.isActUnlocked(WorldManager.actOfWorld(world) or 1))
    self.sm:switch("game", {
        mode = self.selectedMode,
        act = act,
        boosted = boosted,
    })
```

In `MenuState:drawPlayTab`, replace:

```lua
    local prog = WorldManager.worldProgress(chap.id, best)
```

with:

```lua
    -- An unlocked act opens its first world before any of its floors is reached
    local act = WorldManager.actOfWorld(chap.id) or 1
    local openFloor = Save.isActUnlocked(act) and (WorldManager.actFloors(act)) or nil
    local prog = WorldManager.worldProgress(chap.id, best, openFloor)
```

and replace the locked text:

```lua
        PixelFont.printf(string.format("LOCKED: FLOOR %d+", prog.first), wc.x, wc.y + 48, wc.w, "center", C.fog, "main")
```

with:

```lua
        local lockText = (act > 1 and not Save.isActUnlocked(act)) and "LOCKED: CLEAR ACT I"
            or string.format("LOCKED: FLOOR %d+", prog.first)
        PixelFont.printf(lockText, wc.x, wc.y + 48, wc.w, "center", C.fog, "main")
```

`drawPlayTab` runs every frame: `string.format` there already allocated before this change; do not add other per-frame tables.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `lua5.1 tests/run.lua 2>&1 | grep -E "ÉCHEC|réussis"`
Expected: `… tests réussis, 0 échecs`.

- [ ] **Step 5: Commit**

```bash
git add src/states/menu.lua tests/test_acts.lua
git commit -m "feat(menu): launch Act II from the world carousel

Selecting an Act II world (Void City) once Act I is cleared launches an
Ascension run on floor 51 with the head start. The world card shows it
unlocked, or LOCKED: CLEAR ACT I before the clear. The ignored chapter
launch parameter is gone.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Self-test, device check and PR

**Files:** none changed unless a check fails.

- [ ] **Step 1: Full unit suite**

Run: `lua5.1 tests/run.lua 2>&1 | tail -1`
Expected: `… tests réussis, 0 échecs`.

- [ ] **Step 2: PC self-test in a scratch-identity harness**

```bash
H=$(mktemp -d)
for f in assets src tests main.lua; do ln -s "$PWD/$f" "$H/$f"; done
sed 's/t.identity = "arch3ro"/t.identity = "arch3ro_selftest_scratch"/' conf.lua > "$H/conf.lua"
(cd "$H" && SDL_VIDEODRIVER=offscreen timeout 300 love . --test > selftest.log 2>&1; echo "exit=$?"; grep -ciE "FAIL|ERROR|traceback" selftest.log; tail -3 selftest.log)
```

Expected: `exit=0`, `0`, and the last lines ending with `OK`.

- [ ] **Step 3: Azahar check (300 % CPU, see `tools/emu/`)**

With a save that has `records.ascensionClears >= 1` (or the admin panel's floor launcher to reach floor 50):
1. Clear floor 50: golden pause, then the CONTINUE / END THE RUN panel on the bottom screen; D-pad up/down moves the cursor, A confirms, touch works.
2. CONTINUE: fade to floor 51 (Void City banner), same skills and gold in the HUD, "STAGE 51 / 60".
3. Hub: select Void City in the carousel → BATTLE starts on floor 51 with the start wheel, then 8 drafts in a row.
4. Clear floor 60: "ACT II COMPLETE" victory screen; AGAIN restarts on floor 51.
5. Before the first Act I clear (fresh save): Void City shows "LOCKED: CLEAR ACT I" and BATTLE starts on floor 1.

- [ ] **Step 4: Push and open the PR**

```bash
git push -u origin feat/act-2-engine
gh pr create --base main --title "feat(acts): Act II launch, CONTINUE after Act I, act victories" --body-file - <<'EOF'
## Summary

First step of Act II (spec: docs/superpowers/specs/2026-10-11-act-2-worlds-design.md). Act II holds Void City only (floors 51-60) until worlds 7-10 ship; it grows by itself when they are added to `WorldManager.CHAPTERS`.

- **Acts** (`src/core/world_manager.lua`): Act I = floors 1-50, Act II = floors 51 to the last world. Each act ends with a victory on its last floor, and the floor counter shows the act's length. Past the last world, the Abyss cycles the worlds.
- **Difficulty**: boss damage and elite blasts scale with the absolute world depth, so they keep growing past floor 60.
- **CONTINUE**: after the floor-50 victory, the bottom screen offers CONTINUE TO ACT II (same hero, build and gold) or END THE RUN.
- **Hub launch**: once Act I is cleared, selecting Void City starts an Ascension run on floor 51, with the start wheel and `Balance.ACT2_HEAD_START_DRAFTS` (8) drafts in a row.
- **End of run**: ACT I / ACT II COMPLETE, clears counted per act (`ascensionClears`, `act2Clears`), and AGAIN / RETRY replay the same act.

## Test plan

- [x] `lua5.1 tests/run.lua` (new: tests/test_acts.lua, tests/test_act_two.lua)
- [x] PC self-test in a scratch-identity harness
- [x] Azahar at 300 % CPU: CONTINUE panel, floor 51 with the same build, hub launch with 8 drafts, ACT II COMPLETE on floor 60, LOCKED: CLEAR ACT I on a fresh save
- [ ] Console: head start balance on floor 51 (8 drafts)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
```

Tick the Azahar box only after doing the Step 3 checklist; leave it unticked otherwise.
