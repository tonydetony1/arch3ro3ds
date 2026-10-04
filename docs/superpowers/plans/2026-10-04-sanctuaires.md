# Sanctuaires de l'Ange et du Démon — plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Salles d'un écran, au décor ciel (Ange, salles 5, 15…) et enfer (Démon, salles 9, 19…), dont l'offre s'ouvre quand le héros s'approche ; le boss mène directement à la roue.

**Architecture:** Deux thèmes de décor supplémentaires (7 = ciel, 8 = enfer) dans `WorldManager.THEMES` réutilisent toute la chaîne de rendu existante (sol en tuiles précalculées, murs, ciel). Un petit module `src/render/sanctuary.lua` ajoute autel, chemin, braseros et animations. `SpecialRoomManager` gagne un état « en attente d'approche » ; `game.lua` route les entrées et l'écran du bas selon `isOfferOpen()`.

**Tech Stack:** Lua 5.1, LÖVE 11 (PC) / LÖVE Potion 3 (3DS), sprites procéduraux (`PixGen`, `SpriteAtlas`), tests `lua5.1 tests/run.lua`, autotest `./run.sh --test`.

Spec : `docs/superpowers/specs/2026-10-04-sanctuaires-ange-demon-design.md`

## Fichiers

| Fichier | Rôle |
|---|---|
| `src/core/world_manager.lua` | `getRoomType` (salle 9 → `"devil"`), aucune vague en sanctuaire, thèmes 7 et 8, `SANCTUARY_THEME` |
| `src/data/rooms.lua` | `SANCTUARY_W/H` (400 × 240), grille `shrine` vide |
| `src/core/special_room_manager.lua` | `inSanctuary`, `waitingApproach`, `npcPosition`, `isOfferOpen`, `checkApproach` |
| `src/render/sprites/sanctuary.lua` (nouveau) | Colonne de marbre, banc de nuages, flèche d'obsidienne, autels, brasero, nuage, détails au sol |
| `src/render/art.lua`, `tools/bake/main.lua` | Enregistrement du nouveau fichier de sprites |
| `src/render/ground_tiles.lua` | 8 thèmes de tuiles au lieu de 6 |
| `src/render/sanctuary.lua` (nouveau) | Autel, chemin, braseros, nuages, rayons, lueur |
| `src/states/game.lua` | Déroulé des sanctuaires, pause pendant l'offre, routage des entrées, boss → roue |
| `src/dev/selftest.lua` | Autotest des deux sanctuaires et de la roue de boss |
| `tests/test_sanctuary_rooms.lua` (nouveau), `tests/run.lua` | Tests unitaires |

---

### Task 1 : types de salles, thèmes 7 et 8, grille de sanctuaire

**Files:**
- Create: `tests/test_sanctuary_rooms.lua`
- Modify: `tests/run.lua` (liste `files`)
- Modify: `src/core/world_manager.lua` (`getRoomType`, `generateEncounter`, `THEMES`)
- Modify: `src/data/rooms.lua` (en-tête, `Rooms.SANCTUARY`)

- [ ] **Step 1 : écrire le test**

`tests/test_sanctuary_rooms.lua` :

```lua
local WorldManager = require("src.core.world_manager")
local Rooms = require("src.data.rooms")

local T = {}

T["salles 5, 15… : Ange ; 9, 19… : Démon ; 10, 20… : boss"] = function()
    assert(WorldManager.getRoomType(4) == "combat")
    assert(WorldManager.getRoomType(5) == "angel")
    assert(WorldManager.getRoomType(9) == "devil")
    assert(WorldManager.getRoomType(10) == "boss")
    assert(WorldManager.getRoomType(15) == "angel")
    assert(WorldManager.getRoomType(19) == "devil")
    assert(WorldManager.getRoomType(49) == "devil")
end

T["aucune vague dans un sanctuaire"] = function()
    for _, room in ipairs({ 5, 9, 25, 39 }) do
        local enc = WorldManager.generateEncounter(1, room, 400, 240)
        assert(#enc.waves == 0, "salle " .. room .. " : vagues inattendues")
    end
end

T["thèmes des sanctuaires : ciel pour l'Ange, lave pour le Démon"] = function()
    local angel = WorldManager.getTheme(WorldManager.SANCTUARY_THEME.angel)
    local devil = WorldManager.getTheme(WorldManager.SANCTUARY_THEME.devil)
    assert(angel.variant == "sky" and angel.hazard == nil)
    assert(devil.variant == "lava" and devil.hazard == nil)
    assert(angel ~= WorldManager.getTheme(5) and devil ~= WorldManager.getTheme(4))
end

T["sanctuaire : un écran, grille sans obstacle"] = function()
    assert(Rooms.SANCTUARY_W == 400 and Rooms.SANCTUARY_H == 240)
    local layout = Rooms.pick("sanctuary", 9)
    for _, row in ipairs(layout.grid) do
        assert(not row:find("[^%.]"), layout.id .. " : " .. row)
    end
end

return T
```

Dans `tests/run.lua`, ajouter `"tests.test_sanctuary_rooms",` à la fin de la liste `files`.

- [ ] **Step 2 : vérifier l'échec**

Run: `lua5.1 tests/run.lua`
Expected: 4 échecs dans `tests.test_sanctuary_rooms` (salle 9 vue comme `combat`, `SANCTUARY_THEME` absent, `SANCTUARY_W` absent).

- [ ] **Step 3 : implémenter**

`src/core/world_manager.lua`, remplacer `getRoomType` :

```lua
-- Détermine le type de salle : "angel" (sanctuaire du ciel, salles 5, 15…), "devil" (antre
-- du Démon juste avant le boss, salles 9, 19…), "boss" (palier) ou "combat" (vague)
function WorldManager.getRoomType(roomNumber)
    local slot = roomNumber % 10
    if slot == 0 then
        return "boss"
    elseif slot == 5 then
        return "angel"
    elseif slot == 9 then
        return "devil"
    else
        return "combat"
    end
end
```

Dans `generateEncounter`, remplacer `if roomType == "angel" then` par
`if roomType == "angel" or roomType == "devil" then`, et dans le commentaire au-dessus
« Salles d'ange : aucune vague » par « Sanctuaires (Ange, Démon) : aucune vague ».

À la fin de la table `WorldManager.THEMES` (après `[6] = {…},`), ajouter :

```lua
    [7] = { -- Sanctuaire de l'Ange (salles 5, 15…) : marbre, nuages, lumière dorée
        variant = "sky",
        ground = "dfe8f5", groundLight = "f4f8ff", groundDark = "c3d0e3", edge = "8b9bb4",
        skyTop = "f2c14e", skyBottom = "fff4d6",
        wallTree = "marble_column", wallTreeSmall = "cloud_bank",
        decals = { "feather", "sparkle", "cloud_wisp" },
        patchLight = "patch_light", patchDark = "patch_light", patchExtra = "patch_light",
        hazard = nil,
    },
    [8] = { -- Antre du Démon (salles 9, 19…) : basalte, braises, ciel rouge
        variant = "lava",
        ground = "2b1d1d", groundLight = "3d2828", groundDark = "1f1414", edge = "120b0b",
        skyTop = "1a0505", skyBottom = "8a1d0e",
        wallTree = "obsidian_spire", wallTreeSmall = "obsidian_spire",
        decals = { "lava_crack", "skull", "ember_rock", "lava_crack" },
        patchLight = "patch_dark", patchDark = "patch_dirt", patchExtra = "patch_dark",
        hazard = nil,
    },
```

Juste après la table, ajouter :

```lua
-- Thèmes des sanctuaires (src/render/sanctuary.lua ajoute autel, braseros et animations)
WorldManager.SANCTUARY_THEME = { angel = 7, devil = 8 }
```

`src/data/rooms.lua` : dans l'en-tête, remplacer la ligne
`--   sanctuary : salle de l'ange, sans obstacle au centre` par
`--   sanctuary : sanctuaires de l'Ange et du Démon, un écran sans obstacle`, et remplacer
toute la table `Rooms.SANCTUARY` (grilles `sanctuary_plain` et `sanctuary_garden`) par :

```lua
-- Sanctuaires de l'Ange (salles 5, 15…) et du Démon (9, 19…) : salle d'un écran, sans
-- obstacle ; autel et décor viennent de src/render/sanctuary.lua
Rooms.SANCTUARY_W = 400
Rooms.SANCTUARY_H = 240
Rooms.SANCTUARY = {
    { id = "shrine", minRoom = 1, grid = {
        ".............",
        ".............",
        ".............",
        ".............",
        ".............",
        ".............",
        ".............",
        ".............",
        ".............",
    } },
}
```

Mettre à jour le commentaire de `ROOMS_PER_BLOCK` :
`local ROOMS_PER_BLOCK = 10 -- un chapitre = 10 salles : 7 combats, ange (5e), démon (9e), boss (10e)`.

- [ ] **Step 4 : vérifier le succès**

Run: `lua5.1 tests/run.lua`
Expected: `85 tests réussis, 0 échecs` (81 + 4).

- [ ] **Step 5 : commit**

```bash
git add tests/test_sanctuary_rooms.lua tests/run.lua src/core/world_manager.lua src/data/rooms.lua
git commit -m "feat: demon lair before each boss, sanctuary themes and one-screen shrine grid"
```

---

### Task 2 : autotest des sanctuaires (RED)

**Files:**
- Modify: `src/dev/selftest.lua` (blocs `testFrames == 52` et `testFrames == 58`)

- [ ] **Step 1 : réécrire le bloc 52 (Ange)**

Remplacer tout le bloc `elseif testFrames == 52 then … print(…Angel Sanctuary VALIDATED…)` par :

```lua
        elseif testFrames == 52 then
            -- 3b. SANCTUAIRE DE L'ANGE (salles 5, 15…) : un écran, porte ouverte, offre
            -- ouverte seulement quand le héros s'approche de l'Ange, jeu figé pendant le choix
            local g = gameStateMachine.current
            g:setupRoom(5)
            local srm = g.specialRoomManager
            assert(g.roomType == "angel", "Room 5 must be an angel room")
            assert(g.mapW == 400 and g.mapH == 240, "Sanctuary must be a single screen (400x240)")
            assert(g.phase == "clear" and g.isGateOpen == true, "Sanctuary gate must be open on entry")
            assert(#g.pendingSpawns == 0 and g.dummyPool.activeCount == 0, "Angel room must NOT have any enemies")
            assert(srm.isActive and srm.activeType == "angel", "Angel must be present")
            assert(#srm.angelChoices == 2, "Angel must offer exactly 2 choices (Heal vs Blessing)")
            assert(not srm:isOfferOpen(), "Offer must stay closed until the hero comes close")
            g:update(0.016)
            assert(not srm:isOfferOpen(), "Offer must stay closed while the hero is at the entrance")
            g:drawTop()
            g:drawBottom()

            -- Le héros rejoint l'Ange : l'offre s'ouvre et le jeu se fige
            local nx, ny = srm:npcPosition(g.mapW, g.mapH)
            g.player.x, g.player.y = nx, ny + 20
            g:update(0.016)
            assert(srm:isOfferOpen(), "Offer must open when the hero reaches the Angel")
            local frozenY = g.player.y
            g.player.vy = 200
            g:update(0.016)
            assert(g.player.y == frozenY, "Game must be paused while the offer is open")
            g.player.vy = 0
            g:drawTop()
            g:drawBottom()

            -- Choix 1 (Soin Vital +40% PV) au toucher
            local preHp = g.player.hp
            g:touchpressed(1, 40, 100)
            assert(srm.pressedBtn == "angel_1", "Touch should press angel_1 button")
            g:touchreleased(1, 40, 100)
            assert(srm.isResolved == true and srm.isActive == false, "Angel offer must be resolved")
            assert(g.isGateOpen == true and g.phase == "clear", "Gate must stay open after the choice")
            print(string.format("[TEST] Angel Sanctuary VALIDATED: Room 5 one-screen sky shrine, offer on approach, game paused, healing applied (PV: %d -> %d).", preHp, g.player.hp))
```

- [ ] **Step 2 : réécrire le début du bloc 58 (boss → roue, puis Démon)**

Dans le bloc `elseif testFrames == 58 then`, remplacer tout ce qui précède
`-- Vérification des compétences interdites du Diable` par :

```lua
        elseif testFrames == 58 then
            -- 3c. BOSS (salle 10) : sa mort ouvre directement la roue de boss, sans Démon
            local g = gameStateMachine.current
            g:setupRoom(10)
            assert(g.roomType == "boss", "Room 10 must be a boss room")
            assert(g.specialRoomManager.isActive == false, "No special room during boss combat")
            g.dummyPool:clear()
            g.spawnWarningTimer = 0
            g:update(0.016)
            assert(g.phase == "boss_wheel", "Boss death must open the boss wheel")
            assert(g.specialRoomManager.activeType == "wheel", "Boss reward must be the wheel, not the Demon")

            -- 3d. ANTRE DU DÉMON (salles 9, 19…) : juste avant le boss, pacte à l'approche
            g:setupRoom(9)
            local srm = g.specialRoomManager
            assert(g.roomType == "devil", "Room 9 must be the Demon's lair")
            assert(g.mapW == 400 and g.mapH == 240 and g.isGateOpen, "Demon lair: single screen, gate open")
            assert(#g.pendingSpawns == 0, "Demon lair must NOT have any enemies")
            assert(srm.activeType == "devil" and srm.devilPact ~= nil, "Demon must propose a forbidden pact")
            local pact = srm.devilPact
            assert(pact.costHp > 0 and pact.skillId ~= nil, "Devil pact must require max HP sacrifice for forbidden skill")
            assert(not srm:isOfferOpen(), "Pact must wait for the hero to come close")
            local nx, ny = srm:npcPosition(g.mapW, g.mapH)
            g.player.x, g.player.y = nx, ny + 20
            g:update(0.016)
            assert(srm:isOfferOpen(), "Pact must open when the hero reaches the Demon")
            g:drawTop()
            g:drawBottom()

            -- Acceptation du pacte (bouton SCELLER LE PACTE)
            local preMaxHp = g.player.maxHp
            g:touchpressed(1, 60, 200)
            assert(srm.pressedBtn == "devil_accept", "Touch should press devil_accept button")
            g:touchreleased(1, 60, 200)
            assert(g.player.maxHp == preMaxHp - pact.costHp, "Player Max HP must be permanently reduced by 20%")
            assert(srm.isResolved == true, "Devil encounter should be resolved")
            assert(g.isGateOpen == true and g.phase == "clear", "Gate must stay open after the pact")

```

Dans le `print` final du bloc 58, remplacer `Post-boss demon summon` par `Pre-boss demon lair (room 9)`.

- [ ] **Step 3 : vérifier l'échec**

Run: `DISPLAY=:5 SDL_AUDIODRIVER=dummy timeout 300 ./run.sh --test; head -3 error_log.txt`
Expected: code 1, `error_log.txt` commence par
`src/dev/selftest.lua:…: Sanctuary must be a single screen (400x240)`.

- [ ] **Step 4 : commit**

```bash
git add src/dev/selftest.lua
git commit -m "test: self-test angel and demon sanctuaries and boss wheel"
```

---

### Task 3 : état « en attente d'approche » dans SpecialRoomManager

**Files:**
- Modify: `src/core/special_room_manager.lua`

- [ ] **Step 1 : signature de `setup` et nouvel état**

Remplacer `function SpecialRoomManager:setup(roomType, player, roomNumber, variant)` et ses
lignes jusqu'à `self.hoverCard = nil` incluses par :

```lua
-- opts.approach : sanctuaire (Ange, Démon), le personnage attend au centre de la salle
-- que le héros s'approche pour ouvrir son offre (voir checkApproach)
function SpecialRoomManager:setup(roomType, player, roomNumber, variant, opts)
    self.activeType = roomType or "angel"
    self.variant = variant
    self.isActive = true
    self.isResolved = false
    self.animTime = 0
    self.pressedBtn = nil
    self.hoverCard = nil
    self.inSanctuary = (opts and opts.approach) or false
    self.waitingApproach = self.inSanctuary
```

- [ ] **Step 2 : position du personnage, offre ouverte, approche**

Juste avant `function SpecialRoomManager:update(dt)`, ajouter :

```lua
SpecialRoomManager.APPROACH_RADIUS = 40

-- Position du personnage : centre du sanctuaire, ou face à l'entrée sud d'une grande salle
function SpecialRoomManager:npcPosition(mapW, mapH)
    mapW, mapH = mapW or 640, mapH or 480
    if self.inSanctuary then
        return mapW / 2, mapH / 2 - 4
    end
    return mapW / 2, mapH - 148
end

-- Offre affichée : l'écran tactile et les boutons lui reviennent
function SpecialRoomManager:isOfferOpen()
    return self.isActive and not self.waitingApproach
end

-- Ouvre l'offre quand le héros arrive près du personnage ; renvoie true à l'ouverture
function SpecialRoomManager:checkApproach(px, py, mapW, mapH)
    if not (self.isActive and self.waitingApproach) then return false end
    local nx, ny = self:npcPosition(mapW, mapH)
    local dx, dy = px - nx, py - ny
    local r = SpecialRoomManager.APPROACH_RADIUS
    if dx * dx + dy * dy > r * r then return false end
    self.waitingApproach = false
    Audio.play("ui_confirm", 0, 0.8)
    return true
end
```

- [ ] **Step 3 : `drawTop` utilise `npcPosition` ; pas de piédestal sur l'autel**

Dans `drawTop`, remplacer :

```lua
    local cx = (mapW or 640) / 2
    local cy = (mapH or 480) - 148      -- placé face au joueur qui entre par le sud
```

par :

```lua
    local cx, cy = self:npcPosition(mapW, mapH)
```

et `if setup.pedestal then` par `if setup.pedestal and not self.inSanctuary then`
(dans un sanctuaire, l'autel de `src/render/sanctuary.lua` remplace le piédestal).

- [ ] **Step 4 : vérifier qu'aucun test unitaire ne casse**

Run: `lua5.1 tests/run.lua`
Expected: `85 tests réussis, 0 échecs`.

- [ ] **Step 5 : commit**

```bash
git add src/core/special_room_manager.lua
git commit -m "feat: special room offer waits for the hero to approach in sanctuaries"
```

---

### Task 4 : sprites des sanctuaires et tuiles de sol 7 et 8

**Files:**
- Create: `src/render/sprites/sanctuary.lua`
- Modify: `src/render/art.lua` (`SPRITE_MODULES`), `tools/bake/main.lua` (`SPRITE_MODULES`)
- Modify: `src/render/ground_tiles.lua` (`THEMES = 8`)
- Regenerate: `assets/atlas.png`, `src/render/atlas_data.lua`

- [ ] **Step 1 : créer `src/render/sprites/sanctuary.lua`**

```lua
-- src/render/sprites/sanctuary.lua
-- Décor des sanctuaires : colonne de marbre et banc de nuages (Ange), flèche d'obsidienne
-- (Démon), autels, brasero animé, nuage dérivant et détails au sol (plume, éclat, volute de
-- nuage, crâne, pierre à braise). Formes générées par PixGen (déterministe).

local PixGen = require("src.render.sprites.pixgen")

local Sanctuary = {}

local INK = "181425"
local VOL = { depth = 5, strength = 1.0 }

-- Colonne de marbre : fût cannelé, chapiteau et base dorés
local function marbleColumn(w, h)
    local g = PixGen.new(w, h, 7)
    g:rect(2, 5, w - 4, h - 10, "M")
    for x = 3, w - 4, 3 do g:rect(x, 6, 1, h - 12, "m", "M") end
    g:edge("M", "s", 1, 0)
    g:rect(1, 0, w - 2, 4, "G")
    g:rect(0, 3, w, 2, "G")
    g:rect(1, 0, w - 2, 1, "Y", "G")
    g:rect(0, h - 5, w, 2, "G")
    g:rect(1, h - 3, w - 2, 3, "g")
    return g:toGrid()
end

-- Banc de nuages posé au sol (bords du sanctuaire de l'Ange)
local function cloudBank(w, h, seed)
    local g = PixGen.new(w, h, seed)
    g:ellipse(w * 0.5, h * 0.62, w * 0.48, h * 0.38, "C")
    g:circle(w * 0.3, h * 0.48, h * 0.34, "C")
    g:circle(w * 0.62, h * 0.4, h * 0.4, "C")
    g:edge("C", "c", 0, 1)
    g:ellipse(w * 0.55, h * 0.3, w * 0.18, h * 0.14, "W", "C")
    return g:toGrid()
end

-- Flèche d'obsidienne à runes rouges (bords de l'antre du Démon)
local function obsidianSpire(w, h, seed)
    local g = PixGen.new(w, h, seed)
    local cx = w / 2
    for i = 0, h - 1 do
        local t = i / (h - 1)
        local half = (w * 0.46) * (t ^ 0.6)
        g:rect(math.floor(cx - half), i, math.max(1, math.floor(half * 2)), 1, "O")
    end
    g:edge("O", "o", 1, 0)
    g:rect(math.floor(cx) - 1, 4, 1, h - 8, "L", "O")
    for k = 0, 2 do
        local y = math.floor(h * (0.35 + k * 0.18))
        g:rect(math.floor(cx) - 1, y, 3, 1, "R", "Oo")
        g:rect(math.floor(cx), y - 1, 1, 1, "R", "Oo")
    end
    g:ellipse(cx, h - 1, w * 0.48, 2, "d")
    return g:toGrid()
end

-- Autel rond vu de trois quarts : socle, bord, plateau et anneau intérieur
local function altar(w, h, rim, inner, mark)
    local g = PixGen.new(w, h, 3)
    local cx, cy = w / 2, h / 2
    g:ellipse(cx, cy + 2, w * 0.49, h * 0.46, "S")
    g:ellipse(cx, cy, w * 0.49, h * 0.42, rim)
    g:ellipse(cx, cy, w * 0.43, h * 0.34, inner)
    g:ellipse(cx, cy, w * 0.30, h * 0.22, mark, inner)
    g:ellipse(cx, cy, w * 0.27, h * 0.18, inner, mark)
    return g:toGrid()
end

-- Brasero mural : flamme oscillante (3 images) au-dessus d'une coupe de fer
local function brazier(frame)
    local g = PixGen.new(14, 26, 11 + frame)
    local sway = ({ 0, 1, -1 })[frame]
    g:ellipse(7 + sway * 0.5, 8, 4.5, 5, "F")
    g:ellipse(7 + sway, 5, 3, 4.5, "F")
    g:ellipse(7 + sway, 8, 3, 3.5, "Y", "F")
    g:ellipse(7 + sway * 0.5, 9, 1.5, 2, "W", "Y")
    g:rect(7 + sway * 2, 1, 1, 1, "F")
    g:rect(1, 12, 12, 3, "i")
    g:ellipse(7, 15, 6, 3, "I")
    g:rect(6, 16, 2, 8, "I")
    g:rect(4, 24, 6, 2, "I")
    g:edge("I", "k", 1, 0)
    return g:toGrid()
end

-- Petit nuage qui dérive au-dessus du sanctuaire de l'Ange
local function cloudPuff(w, h, seed)
    local g = PixGen.new(w, h, seed)
    g:ellipse(w * 0.5, h * 0.6, w * 0.48, h * 0.38, "C")
    g:circle(w * 0.36, h * 0.45, h * 0.36, "C")
    g:circle(w * 0.62, h * 0.4, h * 0.42, "C")
    g:edge("C", "c", 0, 1)
    return g:toGrid()
end

local FEATHER = {
    "......w",
    "....wW.",
    "..wwW..",
    ".wWw...",
    "g......",
}
local SPARKLE = {
    "..y..",
    "..Y..",
    "yYWYy",
    "..Y..",
    "..y..",
}
local CLOUD_WISP = {
    "...cccc.....",
    ".ccCCCCcc...",
    "cCCCCCCCCccc",
    ".cccccccc...",
}
local SKULL = {
    ".BBBBB.",
    "BBBBBBB",
    "BkBBBkB",
    "BBBkBBB",
    ".BBBBB.",
    ".B.B.B.",
}
local EMBER_ROCK = {
    "..RRR..",
    ".RFFRR.",
    "RRFYFRR",
    ".RRFRR.",
    "..RRR..",
}

function Sanctuary.define(atlas)
    local function d(name, frames, pal, outline, anchor, shade)
        atlas:define(name, {
            frames = frames, palette = pal, outline = outline,
            anchor = anchor or "center", shade = shade,
        })
    end
    local MARBLE = { M = "e8ecf4", m = "c3cad8", s = "9aa3b8", G = "e0a83a", g = "b07a26", Y = "fee761" }
    d("marble_column", { marbleColumn(14, 44) }, MARBLE, "5a6988", "bottom", VOL)
    d("cloud_bank", { cloudBank(30, 18, 5), cloudBank(26, 16, 9) },
        { C = "f4f8ff", c = "b9c6dc", W = "ffffff" }, "9fb2cc", "bottom")
    d("obsidian_spire", { obsidianSpire(16, 44, 4), obsidianSpire(12, 34, 8) },
        { O = "2a2030", o = "16101c", L = "5a4a6a", R = "e43b44", d = "0c0808" }, INK, "bottom", VOL)
    d("altar_angel", { altar(56, 28, "G", "M", "Y") },
        { S = "9aa3b8", G = "e0a83a", M = "e8ecf4", Y = "fee761" }, "5a6988", "center")
    d("altar_devil", { altar(56, 28, "R", "O", "F") },
        { S = "0c0808", R = "a82814", O = "2a2030", F = "f77622" }, INK, "center")
    d("brazier", { brazier(1), brazier(2), brazier(3) },
        { I = "3a3a4a", i = "5a5a6e", k = "1c1c26", F = "e43b44", Y = "f77622", W = "fee761" }, INK, "bottom")
    d("cloud_puff", { cloudPuff(24, 11, 3), cloudPuff(18, 9, 12) }, { C = "ffffff", c = "dfe8f5" }, nil, "center")
    d("feather", { FEATHER }, { w = "f4f8ff", W = "c3cad8", g = "9aa3b8" }, nil, "center")
    d("sparkle", { SPARKLE }, { y = "e0a83a", Y = "fee761", W = "ffffff" }, nil, "center")
    d("cloud_wisp", { CLOUD_WISP }, { c = "c3cad8", C = "f4f8ff" }, nil, "center")
    d("skull", { SKULL }, { B = "d9c8a8", k = "1c1010" }, "3e2731", "center")
    d("ember_rock", { EMBER_ROCK }, { R = "3a2424", F = "f77622", Y = "fee761" }, nil, "center")
end

return Sanctuary
```

- [ ] **Step 2 : enregistrer le fichier de sprites**

Dans `src/render/art.lua` **et** `tools/bake/main.lua`, ajouter
`"src.render.sprites.sanctuary",` juste après `"src.render.sprites.props",` dans
`SPRITE_MODULES`.

Dans `src/render/ground_tiles.lua`, remplacer `THEMES = 6,` par
`THEMES = 8, -- 6 chapitres + sanctuaires de l'Ange (7) et du Démon (8)`.

- [ ] **Step 3 : précompiler l'atlas**

Run: `~/AppImages/löve.appimage tools/bake 2>&1 | tail -4`
Expected: `Tuiles de sol : 8 thèmes x 6 variantes (jusqu'à y=704)` et aucune erreur
`SpriteAtlas trop petit`.

Si l'assertion `SpriteAtlas trop petit (1024x512)` apparaît : remplacer
`SpriteAtlas.new(1024, 512)` par `SpriteAtlas.new(1024, 576)` dans `tools/bake/main.lua` et
`src/render/art.lua`, puis relancer (les tuiles descendent alors jusqu'à y=768 < 1024).

- [ ] **Step 4 : vérifier l'atlas**

Run:
```bash
python3 -c "from PIL import Image; print(Image.open('assets/atlas.png').size)"
grep -c '"altar_angel"\|"brazier"\|"ground_8_6"' src/render/atlas_data.lua
lua5.1 tests/run.lua | tail -1
```
Expected: `(1024, 1024)`, `3`, `85 tests réussis, 0 échecs`.

- [ ] **Step 5 : commit**

```bash
git add src/render/sprites/sanctuary.lua src/render/art.lua tools/bake/main.lua src/render/ground_tiles.lua assets/atlas.png src/render/atlas_data.lua
git commit -m "feat: sanctuary sprites and sky/hell ground tiles"
```

---

### Task 5 : module de rendu des sanctuaires

**Files:**
- Create: `src/render/sanctuary.lua`

- [ ] **Step 1 : créer le module**

```lua
-- src/render/sanctuary.lua
-- Décor propre aux sanctuaires : chemin de dalles et autel au sol, braseros muraux de l'antre
-- du Démon, nuages qui dérivent et rayons de lumière du sanctuaire de l'Ange, lueur de lave.
-- Le sol, les murs et le ciel viennent des thèmes 7 et 8 (WorldManager.THEMES).
-- Une vingtaine de sprites et quelques aplats par image : coût négligeable.

local Art = require("src.render.art")

local Sanctuary = {}
Sanctuary.__index = Sanctuary

local SLAB = 16

-- kind : "angel" ou "devil" ; salle de mapW x mapH (un écran)
function Sanctuary.new(kind, mapW, mapH)
    local self = setmetatable({}, Sanctuary)
    self.kind = kind
    self.variant = (kind == "angel") and "sky" or "lava"
    self.w, self.h = mapW, mapH
    self.cx, self.cy = math.floor(mapW / 2), math.floor(mapH / 2)
    -- Chemin de dalles de l'entrée (sud) à la porte (nord), interrompu par l'autel
    self.path = {}
    for y = 40, mapH - 24, SLAB do
        if math.abs(y + SLAB / 2 - self.cy) > 20 then
            self.path[#self.path + 1] = y
        end
    end
    -- Braseros dans les bandes de mur latérales : jamais sous les pas du héros
    self.braziers = {
        { x = 11, y = math.floor(mapH * 0.38) }, { x = mapW - 11, y = math.floor(mapH * 0.38) },
        { x = 11, y = math.floor(mapH * 0.78) }, { x = mapW - 11, y = math.floor(mapH * 0.78) },
    }
    self.clouds = {
        { x = 30, y = 70, speed = 6, frame = 1 },
        { x = 250, y = 150, speed = 4, frame = 2 },
        { x = 140, y = 200, speed = 5, frame = 1 },
    }
    return self
end

function Sanctuary:update(dt)
    if self.kind ~= "angel" then return end
    for _, c in ipairs(self.clouds) do
        c.x = c.x + c.speed * dt
        if c.x > self.w + 20 then c.x = -20 end
    end
end

-- Sol : chemin de dalles et autel, sous le personnage et le héros
function Sanctuary:drawFloor()
    love.graphics.setColor(1, 1, 1, 1)
    for i, y in ipairs(self.path) do
        Art.draw("slab", 1 + (i % 4), self.cx - SLAB, y, false, false, self.variant)
        Art.draw("slab", 1 + ((i + 2) % 4), self.cx, y, false, false, self.variant)
    end
    Art.draw(self.kind == "angel" and "altar_angel" or "altar_devil", 1, self.cx, self.cy + 14)
end

-- Murs : braseros allumés de l'antre du Démon
function Sanctuary:drawWalls(t)
    if self.kind ~= "devil" then return end
    love.graphics.setColor(1, 1, 1, 1)
    for i, b in ipairs(self.braziers) do
        Art.draw("brazier", Art.animFrame("brazier", t, 8, i * 0.7), b.x, b.y)
    end
end

-- Ambiance au premier plan : rayons et nuages (Ange), lueur de lave qui respire (Démon)
function Sanctuary:drawAmbient(t)
    if self.kind == "angel" then
        for i = 0, 2 do
            local a = 0.06 + 0.04 * math.sin(t * 1.3 + i * 2.1)
            love.graphics.setColor(1, 0.95, 0.75, a)
            local x = self.cx - 70 + i * 60
            love.graphics.polygon("fill", x, 30, x + 26, 30, x + 66, self.h - 20, x + 34, self.h - 20)
        end
        love.graphics.setColor(1, 1, 1, 0.85)
        for _, c in ipairs(self.clouds) do
            Art.draw("cloud_puff", c.frame, c.x, c.y)
        end
    else
        local a = 0.05 + 0.04 * (math.sin(t * 2.0) + 1) * 0.5
        love.graphics.setColor(0.9, 0.25, 0.08, a)
        love.graphics.rectangle("fill", 16, 30, self.w - 32, self.h - 44)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return Sanctuary
```

- [ ] **Step 2 : contrôle de syntaxe et bytecode**

Run: `luac5.1 -p src/render/sanctuary.lua && python3 tools/lua_bytecode.py --selftest | tail -1`
Expected: aucune erreur, `aller-retour … identique sur 78 fichiers`.

- [ ] **Step 3 : commit**

```bash
git add src/render/sanctuary.lua
git commit -m "feat: sanctuary renderer (altar, path, braziers, clouds, light rays)"
```

---

### Task 6 : déroulé des sanctuaires dans GameState (GREEN)

**Files:**
- Modify: `src/states/game.lua`

- [ ] **Step 1 : require**

Après `local SpecialRoomManager = require("src.core.special_room_manager")`, ajouter :

```lua
local Sanctuary = require("src.render.sanctuary")
```

- [ ] **Step 2 : `roomSpec` — taille et thème des sanctuaires**

Dans `GameState:roomSpec`, remplacer :

```lua
    elseif roomType == "angel" then
        kind = "sanctuary"
    end
    local chapterIndex = math.min(6, math.floor((roomNum - 1) / 10) + 1)
    local theme = WorldManager.getTheme(chapterIndex)
    -- Dimensions taillées sur la grille de la salle (629x463 à 694x508)
    local mapW, mapH = Rooms.roomSize(roomNum)
    return {
        room = roomNum, roomType = roomType, kind = kind, chapterIndex = chapterIndex,
```

par :

```lua
    elseif roomType == "angel" or roomType == "devil" then
        kind = "sanctuary"
    end
    local chapterIndex = math.min(6, math.floor((roomNum - 1) / 10) + 1)
    -- Décor du chapitre, ou ciel de l'Ange / enfer du Démon (thèmes 7 et 8)
    local themeIndex = (kind == "sanctuary") and WorldManager.SANCTUARY_THEME[roomType] or chapterIndex
    local theme = WorldManager.getTheme(themeIndex)
    -- Dimensions taillées sur la grille de la salle (629x463 à 694x508) ; sanctuaire : un écran
    local mapW, mapH = Rooms.roomSize(roomNum)
    if kind == "sanctuary" then mapW, mapH = Rooms.SANCTUARY_W, Rooms.SANCTUARY_H end
    return {
        room = roomNum, roomType = roomType, kind = kind, chapterIndex = chapterIndex, themeIndex = themeIndex,
```

et dans la clé, remplacer `tostring(theme.variant)` par `tostring(themeIndex), tostring(theme.variant)`.

- [ ] **Step 3 : `setupRoom` — musique, thème, sanctuaire**

Remplacer les deux premières lignes du corps :

```lua
    Audio.playMusic((WorldManager.getRoomType(roomNum) == "boss" or self.gameMode == "boss_rush") and "boss" or "battle", 0.5)
    local spec = self:roomSpec(roomNum)
```

par :

```lua
    local spec = self:roomSpec(roomNum)
    Audio.playMusic(spec.roomType == "boss" and "boss" or (spec.kind == "sanctuary" and "hub" or "battle"), 0.5)
```

Supprimer la ligne `self.devilEncountered = false`.

Remplacer `self.arena:setTheme(self.chapterIndex)` par `self.arena:setTheme(spec.themeIndex)`.

Juste avant `if self.gameMode == "survival" then` (branche des phases), ajouter
`self.sanctuary = nil`, puis remplacer la branche :

```lua
    elseif self.roomType == "angel" then
        -- SALLE DE L'ANGE (Sanctuaire sacré de bénédictions sans monstres)
        self.phase = "angel"
        self.spawnWarningTimer = 0
        self.pendingSpawns = {}
        self.specialRoomManager:setup("angel", self.player, self.roomNumber)
```

par :

```lua
    elseif spec.kind == "sanctuary" then
        -- SANCTUAIRE (Ange : ciel, salles 5, 15… ; Démon : enfer, salles 9, 19…) : un écran,
        -- porte ouverte dès l'entrée, offre ouverte quand le héros s'approche du personnage
        self.phase = "clear"
        self.isGateOpen = true
        self.spawnWarningTimer = 0
        self.pendingSpawns = {}
        self.specialRoomManager:setup(self.roomType, self.player, self.roomNumber, nil, { approach = true })
        self.sanctuary = Sanctuary.new(self.roomType, self.mapW, self.mapH)
```

- [ ] **Step 4 : fin du fondu d'entrée**

Remplacer `self.phase = (self.roomType == "angel") and "angel" or "combat"` par
`self.phase = self.sanctuary and "clear" or "combat"`.

- [ ] **Step 5 : `update` — résolution, approche, pause**

Remplacer le bloc :

```lua
        if self.specialRoomManager.isResolved and not self.isGateOpen then
            if self.phase == "devil" and self.roomType == "boss" and not self.bossWheelDone then
                -- ROUE DE BOSS : tour de roue exclusif après le grand boss
                self.bossWheelDone = true
                self.phase = "boss_wheel"
                self.specialRoomManager:setup("wheel", self.player, self.roomNumber, "boss")
                self:triggerShake(0.20, 3.0)
            elseif self.phase ~= "wheel" and self.phase ~= "combat" then
                self.isGateOpen = true
                self.phase = "clear"
            end
        end
    end
```

par :

```lua
        if self.specialRoomManager.isResolved and not self.isGateOpen
            and self.phase ~= "wheel" and self.phase ~= "combat" then
            self.isGateOpen = true
            self.phase = "clear"
        end
    end

    -- Sanctuaire : l'offre s'ouvre quand le héros s'approche ; le jeu est figé pendant le choix
    local srm = self.specialRoomManager
    if srm and srm.waitingApproach then
        srm:checkApproach(self.player.x, self.player.y, self.mapW, self.mapH)
    end
    if srm and srm.inSanctuary and srm:isOfferOpen() then
        self.hud:update(dt, self.player, self.ultimateCharge)
        return
    end
```

Après `self.arena:update(dt, self.isGateOpen)`, ajouter :

```lua
    if self.sanctuary then self.sanctuary:update(dt) end
```

- [ ] **Step 6 : boss → roue de boss directement**

Remplacer :

```lua
        if self.roomType == "boss" and not self.devilEncountered then
            -- APPARITION DU DÉMON APRÈS LE GRAND BOSS !
            self.devilEncountered = true
            self.phase = "devil"
            self.specialRoomManager:setup("devil", self.player, self.roomNumber)
            self:triggerShake(0.25, 4.0)
```

par :

```lua
        if self.roomType == "boss" and not self.bossWheelDone then
            -- ROUE DE BOSS : tour de roue exclusif après le grand boss (le Démon attend
            -- désormais dans son antre, juste avant le boss : salles 9, 19…)
            self.bossWheelDone = true
            self.phase = "boss_wheel"
            self.specialRoomManager:setup("wheel", self.player, self.roomNumber, "boss")
            self:triggerShake(0.25, 4.0)
```

- [ ] **Step 7 : dessin**

Dans `drawTop`, après `self.obstacleManager:draw()` + `Perf.sec("h:obstacles")`, ajouter :

```lua
    if self.sanctuary then self.sanctuary:drawFloor() end
```

Après `self.arena:drawWalls(self.isGateOpen, self.mapW)`, ajouter :

```lua
    if self.sanctuary then self.sanctuary:drawWalls(love.timer.getTime()) end
```

Après le bloc `-- 6. Projectiles et particules` (après son `Depth.pop()`), ajouter :

```lua
    if self.sanctuary then self.sanctuary:drawAmbient(love.timer.getTime()) end
```

Dans `drawBottom`, remplacer
`if self.specialRoomManager and self.specialRoomManager.isActive then` par
`if self.specialRoomManager and self.specialRoomManager:isOfferOpen() then`.

- [ ] **Step 8 : entrées réservées à l'offre ouverte**

Dans `touchpressed`, `touchreleased`, `gamepadpressed` et `keypressed`, remplacer chaque
`self.specialRoomManager and self.specialRoomManager.isActive` par
`self.specialRoomManager and self.specialRoomManager:isOfferOpen()` (5 occurrences ; la
condition de `drawTop` reste sur `isActive` : le personnage est visible avant l'offre).

- [ ] **Step 9 : fin d'offre factorisée**

Avant `function GameState:touchreleased(id, tx, ty)`, ajouter :

```lua
-- Fin d'une offre (Ange, Démon, roue, marchand) : la roue de départ lance le combat, les
-- autres ouvrent la porte ; le personnage d'un sanctuaire disparaît dans un éclat
function GameState:specialRoomDone()
    if self.phase == "wheel" then
        self.phase = "combat"
        self.spawnWarningTimer = 0.55
        -- Talent Gloire en attente : le tirage s'ouvre maintenant que la roue est résolue
        if self.pendingGloryDraft then
            self.pendingGloryDraft = false
            self:openDraft()
        end
    else
        self.isGateOpen = true
        self.phase = "clear"
    end
    if self.sanctuary then
        local nx, ny = self.specialRoomManager:npcPosition(self.mapW, self.mapH)
        VFX.addSparks(nx, ny, 16, (self.roomType == "angel") and { 1, 0.9, 0.4, 1 } or { 1, 0.3, 0.1, 1 })
    end
    self:triggerShake(0.18, 2.5)
end
```

Dans `touchreleased`, remplacer la fonction anonyme passée à
`self.specialRoomManager:touchreleased(id, tx, ty, self.player, self.fctPool, function() … end)`
par `function() self:specialRoomDone() end`. Dans `keypressed`, remplacer le corps de
`local onDone = function() … end` par `local onDone = function() self:specialRoomDone() end`.

- [ ] **Step 10 : vérifier**

Run:
```bash
lua5.1 tests/run.lua | tail -1
rm -f error_log.txt; DISPLAY=:5 SDL_AUDIODRIVER=dummy timeout 300 ./run.sh --test > /tmp/st.txt 2>&1; echo "code=$?"
grep -E "Angel Sanctuary|Devil Encounter|SUCCESS: 100%" /tmp/st.txt
python3 tools/lua_bytecode.py --selftest | tail -1
```
Expected: `85 tests réussis, 0 échecs`, `code=0`, les 3 lignes `[TEST]`, aller-retour identique.

- [ ] **Step 11 : commit**

```bash
git add src/states/game.lua
git commit -m "feat: one-screen angel and demon sanctuaries, offer on approach, boss wheel after boss"
```

---

### Task 7 : vérification visuelle et performance

- [ ] **Step 1 : captures PC des deux sanctuaires**

Run:
```bash
SAVE=~/.local/share/love/arch3ro
for r in 5 9; do rm -f $SAVE/bench_*.png; DISPLAY=:5 SDL_AUDIODRIVER=dummy timeout 60 ./run.sh --bench --room=$r >/dev/null 2>&1; cp $SAVE/bench_1.png /tmp/sanctuary_$r.png; done
```
Expected: `/tmp/sanctuary_5.png` (ciel : sol clair, colonnes, autel doré, nuages, rayons) et
`/tmp/sanctuary_9.png` (enfer : sol basalte, flèches d'obsidienne, braseros, autel rouge). Les
regarder ; corriger couleurs ou positions si un élément est illisible.

- [ ] **Step 2 : build 3DS et Azahar**

Run: `python3 tools/build_all.py | grep -E "SUCCÈS|ERREUR"` puis lancer le CIA dans Azahar,
démarrer une course à la salle 5 puis 9 via le panneau admin (salle de départ), vérifier :
écran unique, porte ouverte, offre à l'approche, FPS et `rejets 0` dans `perf_log.txt`.

- [ ] **Step 3 : intégration**

```bash
git fetch origin && git rebase origin/main
lua5.1 tests/run.lua | tail -1
```
Puis fusion dans `main` (fast-forward) et push, après accord de l'utilisateur pour la release.
