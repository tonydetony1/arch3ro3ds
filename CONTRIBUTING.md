# 🛠️ Contribution & Modding Guide — Arch3ro 3DS

Welcome to **Arch3ro 3DS**! 🎉  
This step-by-step guide is designed to empower **everyone** — from Lua beginners to veteran homebrew developers — to add new content, create mods, build custom stages, or fix bugs.

The game's architecture is **fully modular and data-driven**. You can create a new hero, craft a custom weapon, design new room layouts, or introduce an entirely new world simply by modifying Lua configuration tables without having to re-architect engine internals!

---

## 📑 Table of Contents
1. [Development Environment Setup](#1-development-environment-setup)
2. [Nintendo 3DS Golden Rules (Performance & Stability)](#2-nintendo-3ds-golden-rules)
3. [How to Add a New Hero](#3-how-to-add-a-new-hero)
4. [How to Add a New Chapter / World](#4-how-to-add-a-new-chapter--world)
5. [How to Create New Rooms & Obstacles (Maps)](#5-how-to-create-new-rooms--obstacles-maps)
6. [How to Add a New Weapon](#6-how-to-add-a-new-weapon)
7. [How to Create a New Skill](#7-how-to-create-a-new-skill)
8. [How to Add a Monster to the Bestiary](#8-how-to-add-a-monster-to-the-bestiary)
9. [Debugging & Fixing Bugs](#9-debugging--fixing-bugs)
10. [Submitting Your Work (Pull Requests)](#10-submitting-your-work-pull-requests)

---

## 1. Development Environment Setup

To iterate and test your changes rapidly on your computer, you don't even need a physical 3DS: the game runs natively on desktop PC using **LÖVE 2D**!

### Prerequisites
- **Git**: For version control and cloning the repository.
- **LÖVE 11.4+**:
  - **Linux (Debian/Ubuntu)**: `sudo apt install love`
  - **macOS**: `brew install love`
  - **Windows**: Download installer or zip from [love2d.org](https://love2d.org/)
- **Python 3**: *(Optional, required only for building `.cia` and `.3dsx` packages)*.

### Clone and Launch
```bash
git clone https://github.com/tonydetony1/arch3ro3ds.git
cd arch3ro3ds

# Run the game immediately on PC
make run
# or directly:
./run.sh
```

---

## 2. Nintendo 3DS Golden Rules

The Nintendo 3DS hardware (ARM11 CPU @ 268 MHz on Old 3DS, PICA200 GPU @ 268 MHz) imposes a few golden rules to stay smooth and never crash. Remember that the console runs **interpreted Lua 5.1**: code that is instant on PC (LuaJIT) can be 20-40x slower on an Old 3DS, so always measure on the console or in Azahar (see "Measuring on the console" below).

1. **Zero Garbage Collector Allocations in Combat Loops (`Zero-GC`)**:
   - ❌ **NEVER DO THIS** in functions called every frame (`update` or `draw`):
     ```lua
     local pos = { x = 10, y = 20 } -- Bad: allocates a new table in memory every single frame!
     ```
   - ✅ **Best Practice**: Reuse pre-declared local variables or pre-allocated object pools (`self.projectilePool:obtain()`, `VFX.addSparks(...)`).
2. **Respect the PICA200 Hardware Vertex Budget**:
   - The 3DS hardware command buffer caps geometry at **24,576 vertices per frame** (total across both screens, with the top screen rendered twice when stereoscopic 3D is active).
   - Always verify your creations using the 3DS simulator and hardware vertex estimation:
     ```bash
     make sim
     ```
     Press `F3` on PC (or `SELECT` on 3DS) to view real-time draw call counts, estimated vertex loads, and RAM consumption.
3. **Always Run Self-Tests Before Committing**:
   ```bash
   make test
   # or
   ./run.sh --test
   ```

---

## 3. How to Add a New Hero

Heroes are configured in [`src/data/heroes.lua`](src/data/heroes.lua).

### Step 1: Add the Hero Entry to `Heroes.ROSTER`
Open [`src/data/heroes.lua`](src/data/heroes.lua) and define your character:

```lua
-- Example: Lyra, the Tempest Archer
lyra = {
    id = "lyra",
    name = "Lyra",
    title = "Thunder Dancer",
    desc = "Master of lightning who channels bouncing electric arcs.",
    costType = "gems",        -- "free", "gold", or "gems"
    cost = 150,
    color = {0.95, 0.85, 0.20},        -- Primary RGB color (electric yellow)
    accentColor = {0.30, 0.80, 1.00},  -- Accent RGB color (cyan)
    baseAtkBonus = 18,                 -- Flat ATK bonus
    baseHpBonus = 120,                 -- Flat Max HP bonus
    passiveId = "storm_arrows",        -- Unique passive ID
    passiveName = "Voltaic Arc",
    passiveDesc = "All arrows trigger a bouncing chain lightning strike.",
    cowlColor = {0.80, 0.70, 0.15},    -- Cowl sprite tint
    capeColor = {0.20, 0.40, 0.70},    -- Cape sprite tint
    ultimate = {
        id = "thunderstorm",
        name = "Lightning Storm",
        desc = "Strikes all enemies on screen with high-voltage lightning bolts.",
    },
},
```

### Step 2: Implement the Passive in `Heroes.applyHeroPassives`
In the same file:

```lua
elseif h.passiveId == "storm_arrows" then
    player.elements = player.elements or {}
    player.elements.lightning = true
```

### Step 3: Implement the Signature Ultimate in `GameState:triggerUltimate`
Open [`src/states/game.lua`](src/states/game.lua) and handle the new hero's ultimate ability:

```lua
elseif heroId == "lyra" then
    VFX.addFCT(self.player.x, self.player.y - 25, "THUNDERSTORM!", true)
    VFX.shakeHeavy()
    VFX.addSparks(self.player.x, self.player.y, 25, {0.95, 0.85, 0.2, 1.0})
    if self.dummyPool and self.dummyPool.activeCount > 0 then
        for i = 1, self.dummyPool.activeCount do
            local dIdx = self.dummyPool.activeList[i]
            local m = self.dummyPool.items[dIdx]
            if m and m.alive then
                m:takeDamage(90, 0, 0, { lightning = true })
                VFX.triggerHitFlash(m, 4)
                VFX.addFCT(m.x, m.y - 12, 90, true)
            end
        end
    end
```

### Step 4: Add the Hero ID to `Heroes.ORDER`
```lua
ORDER = { "atreus", "urasil", "phoren", "helix", "rolla", "lyra" },
```
Your new hero will instantly appear in the bottom-screen **HEROES** roster with preview stats and unlocks!

---

## 4. How to Add a New Chapter / World

Worlds are configured in [`src/core/world_manager.lua`](src/core/world_manager.lua).

### Step 1: Add the Chapter to `WorldManager.CHAPTERS`
Define a new indexed entry (e.g., chapter `[7]`):

```lua
[7] = {
    id = "crypt",
    name = "Forgotten Crypt",
    roomCount = 50,             -- Total rooms (e.g., 50 stages)
    baseHp = 550,               -- Starting enemy HP
    hpScaling = 95,             -- Additional HP per stage
    goldMultiplier = 4.8,       -- Gold drop multiplier
    monsterPool = { "skeleton", "ghost_wraith", "mage", "summoner", "turret" },
    boss = "skeleton_king",     -- Major boss at stage 50
    palette = {
        floorBase  = {0.12, 0.14, 0.18},  -- Floor base color
        floorTile1 = {0.15, 0.18, 0.22},
        floorTile2 = {0.10, 0.12, 0.15},
        mortar     = {0.06, 0.08, 0.10},  -- Tile grout lines
        wallNorth  = {0.22, 0.25, 0.32},  -- North back wall
        wallSide   = {0.16, 0.19, 0.25},  -- Lateral walls
        torchGlow  = {0.30, 0.80, 1.00},  -- Spectral blue torch glow
        gateGlow   = {0.40, 0.90, 1.00},  -- Gate portal aura
    },
},
```

### Step 2: Add the Chapter to the Main Menu Carousel
In [`src/states/menu.lua`](src/states/menu.lua), append your chapter to the chapter carousel:

```lua
{ id = 7, name = "Forgotten Crypt", floors = 50, theme = "blue", desc = "Undead Legions & Arcane Necromancers", bg = {0.10, 0.12, 0.16} },
```

---

## 5. How to Create New Rooms & Obstacles (Maps)

Rooms are hand-drawn ASCII grids (13 x 9 cells) in [`src/data/rooms.lua`](src/data/rooms.lua).
The room size is derived from the grid (`Rooms.roomSize`), so anything touching the grid edge touches the wall.

```lua
{ id = "my_room", minRoom = 11, grid = {   -- minRoom: 1, 11 or 21 (unlocks per chapter)
    "o....m.m....o",   -- top centre cell = exit gate, must be '.'
    ".............",
    "..#.......#..",   -- # rock   ~ water   ^ spikes   h biome hazard
    ".~~~..b..~~~.",   -- b barrel o pot     m monster spawn marker
    ".............",
    "..^^.....^^..",
    ".............",   -- no 'm' in the last 3 rows (too close to the entry)
    ".............",
    ".............",   -- bottom centre cell = entry, must be '.'
} },
```

Add it to `Rooms.COMBAT`, `Rooms.ARENA` (centre must stay clear: bosses, wheel, devil) or `Rooms.SANCTUARY`.
Run `make test`: `Rooms.validateAll()` checks the gate is reachable, no cell is sealed off by rocks,
at most 10 rock blocks, and no layout repeats inside a chapter. Each grid is also played mirrored.

---

## 6. How to Add a New Weapon

Weapons are cataloged in [`src/data/weapons.lua`](src/data/weapons.lua):

```lua
-- Example: Thunder Hammer
thunder_hammer = {
    id = "thunder_hammer",
    name = "Telluric War Hammer",
    type = "hammer",
    fire_rate = 0.65,              -- Attack interval in seconds (while standing still)
    projectile_speed = 190,        -- Wave projectile speed
    damage = 42,                   -- Base raw damage
    range = 280,                   -- Range in pixels
    radius = 6.0,                  -- Impact collision radius
    knockback_mult = 3.5,          -- Knockback force applied to foes
    color = {0.85, 0.70, 0.30, 1}, -- Projectile glow color
    sprite = "hammer",
},
```

To make the weapon craftable in the inventory forge across all 5 rarity tiers (*Common ➔ Legendary*), add its entry in [`src/data/items.lua`](src/data/items.lua).

---

## 7. How to Create a New Skill

The skill system in [`src/data/skills.lua`](src/data/skills.lua) uses lightweight event **Hooks**:
- `onApply(player)`: Triggered when drafted upon level-up.
- `onShoot(player, projectile)`: Triggered whenever the hero fires.
- `onHit(player, monster, damage)`: Triggered when a projectile damages an enemy.
- `onMonsterDeath(player, monster)`: Triggered when an enemy is eliminated.

### Example: "Vampiric Strike" Skill
```lua
Skills.register({
    id = "vampire_strike",
    name = "Vampiric Touch",
    desc = "Defeating an enemy instantly restores 15 HP.",
    rarity = "rare",         -- "common", "uncommon", "rare", "epic", "legendary"
    category = "heal",
    icon = "heal",
    hooks = {
        onMonsterDeath = function(player, monster)
            player:heal(15)
        end,
    }
})
```

---

## 8. How to Add a Monster to the Bestiary

The monster and boss catalog resides in [`src/data/bestiary.lua`](src/data/bestiary.lua):

```lua
{
    type = "dark_knight",
    name = "Dark Knight",
    family = "Undead",
    attack = "Heavy Slash",
    weakness = "Lightning",
    desc = "Heavily armored warrior that reflects direct frontal shots."
},
```
Its AI movement pattern (melee charge, laser sniper, jumping burrower, parabolic lobber) is configured cleanly in [`src/core/ai_controller.lua`](src/core/ai_controller.lua).

---

## 9. Debugging & Fixing Bugs

### Reading Crash & Error Logs
If an unhandled error occurs, the error handler prints the full stack trace on both 3DS screens and writes it to `error_log.txt` in the save folder:
- PC: `~/.local/share/love/arch3ro/` (Linux), `%APPDATA%\LOVE\arch3ro\` (Windows)
- 3DS: `sdmc:/3ds/save/arch3ro/`

### Developer CLI Commands
```bash
make stats          # Run with GPU & memory performance overlay enabled
make bench          # Execute simulated 3DS stress-test bench
make test           # Run 100% automated test suite
```

Extra bench flags (`love . --bench --sim3ds ...`):

| Flag | What it measures |
| :--- | :--- |
| `--room=N`, `--duration=S` | Autopilot in room `N` for `S` seconds |
| `--profile` | GPU calls and vertices per source line (JIT off for accurate lines) |
| `--lprof` | Sampling Lua profiler, per function and per line |
| `--alloc` | Lua memory allocated per frame, per function (JIT off, like the console) |
| `--roomload` | Time to build each of the 50 rooms, and what is prepared in the background |
| `--menu` | Stay on the main menu instead of starting a run |

### Measuring on the console (or Azahar)
On the 3DS there are no command-line arguments: create empty files in `sdmc:/3ds/save/arch3ro/` instead, then launch a build made with `python3 tools/build_all.py --fast --with-bench` (the release build never embeds `src/dev/`). Results are written to `bench_log.txt` in the same folder.

| File | Effect |
| :--- | :--- |
| `perf_on` | Frame timings per section every 3 s in `perf_log.txt` (also with `SELECT`) |
| `bench_roomload` | Room build times (same as `--roomload`) |
| `bench_play` | 30 s autopilot run; the file may contain a room number, or `menu` |
| `bench_lprof` / `bench_alloc` | Add the Lua profiler / allocation profiler to the run above |

`tools/emu/emu.sh` drives Azahar headless (`display`, `start`, `shot`, `play`, `stop`). Azahar at 100 % CPU clock behaves like an Old 3DS; remember to delete the flag files afterwards.

### Useful PC Keybindings:
- `F3`: Toggle GPU & vertex budget debug overlay.
- `Escape`: Pause or return to previous screen.
- `Left Click + Drag`: Simulates the 3DS stylus touch screen.

---

## 10. Submitting Your Work (Pull Requests)

1. **Fork** the repository on GitHub: [https://github.com/tonydetony1/arch3ro3ds](https://github.com/tonydetony1/arch3ro3ds).
2. **Create a topic branch** for your feature or bugfix:
   ```bash
   git checkout -b feature/new-hero-lyra
   # or for a bugfix:
   git checkout -b fix/titan-boss-collision
   ```
3. **Always ensure tests pass**:
   ```bash
   make test
   ```
4. **Commit your changes** with descriptive commit messages:
   ```bash
   git commit -m "feat(heroes): add new hero Lyra with bouncing voltaic arrows"
   ```
5. **Push your branch** and open a **Pull Request** on GitHub!

---

<div align="center">
  Have an idea, question, or need feedback? Feel free to open a <b>GitHub Issue</b> or join the discussion with the 3DS homebrew community! 🏹
</div>
