# Rencontres (vagues, rôles, élites, champions) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer la vague unique des salles de combat par des rencontres composées (rôles, budget de menace, 1 à 3 vagues de renforts plafonnées à 7 monstres actifs, élites à affixes, champions en salle x7), conformément à `docs/superpowers/specs/2026-10-03-rencontres-design.md`.

**Architecture:** Trois modules purs testables en `lua5.1` (données `src/data/encounters.lua`, composition `src/core/encounter_director.lua`, file de vagues `src/core/wave_runner.lua`) et un module d'affixes pur (`src/core/elite_affixes.lua`). `WorldManager.generateEncounter` produit les vagues avec PV et positions ; `GameState` les déroule ; `Dummy`, `Projectile`, `Player` reçoivent de petits crochets ; le rendu ajoute anneau, icônes et barre d'élite.

**Tech Stack:** Lua 5.1 (LÖVE Potion sur 3DS, LÖVE 11 sur PC), tests unitaires `lua5.1 tests/run.lua`, autotest `love . --test`, banc Azahar.

---

## Fichiers

| Fichier | Rôle |
|---|---|
| `tests/run.lua` (créé) | Mini-lanceur de tests Lua 5.1 pur |
| `tests/test_director.lua` (créé) | Règles de composition sur les salles 1-150 |
| `tests/test_world_encounter.lua` (créé) | PV, positions, salles spéciales |
| `tests/test_wave_runner.lua` (créé) | Déclenchement des renforts |
| `tests/test_elite_affixes.lua` (créé) | Effets des affixes |
| `src/data/encounters.lua` (créé) | Rôles, coûts, barèmes, définitions d'affixes |
| `src/core/encounter_director.lua` (créé) | Composition déterministe des vagues |
| `src/core/wave_runner.lua` (créé) | File de vagues en jeu |
| `src/core/elite_affixes.lua` (créé) | Logique des affixes (sans dessin ni son) |
| `src/core/world_manager.lua` | `generateEncounter`, suppression de la branche mini-boss morte |
| `src/data/balance.lua` | `Balance.ENCOUNTER.hpMult` |
| `src/entities/dummy.lua` | Champs d'élite, crochets update/takeDamage, contexte tireur |
| `src/entities/projectile.lua` | Drapeau `chill` |
| `src/entities/player.lua` | `chillTimer`, `Player:chill` |
| `src/states/game.lua` | Vagues, élites, porte, explosion volatile, ralentissement |
| `src/render/monsters.lua` | Anneau, barre et icônes d'élite |
| `src/render/sprites/icons.lua` | 6 icônes d'affixes |
| `src/ui/hud.lua` | « WAVE x/y » |
| `Makefile`, `.github/workflows/ci.yml` | Cible `unit`, étape CI |

---

### Task 1: Lanceur de tests unitaires

**Files:** Create `tests/run.lua` ; Modify `Makefile`, `.github/workflows/ci.yml`

- [ ] **Step 1: Créer `tests/run.lua`**

```lua
-- tests/run.lua
-- Tests unitaires en Lua 5.1 pur (même VM que la 3DS) : `lua5.1 tests/run.lua`
-- Chaque fichier tests/test_*.lua renvoie une table { ["nom du test"] = function() ... end }.
package.path = "./?.lua;" .. package.path

local files = {
    "tests.test_director",
    "tests.test_world_encounter",
    "tests.test_wave_runner",
    "tests.test_elite_affixes",
}

local passed, failed = 0, 0
for _, modName in ipairs(files) do
    local ok, suite = pcall(require, modName)
    if not ok then
        print("ÉCHEC CHARGEMENT " .. modName .. " : " .. tostring(suite))
        failed = failed + 1
    else
        local names = {}
        for name in pairs(suite) do names[#names + 1] = name end
        table.sort(names)
        for _, name in ipairs(names) do
            local okTest, err = pcall(suite[name])
            if okTest then
                passed = passed + 1
            else
                failed = failed + 1
                print("ÉCHEC " .. modName .. " › " .. name .. "\n    " .. tostring(err))
            end
        end
    end
end
print(string.format("%d tests réussis, %d échecs", passed, failed))
os.exit(failed == 0 and 0 or 1)
```

- [ ] **Step 2: Cible Makefile** — ajouter `unit` à `.PHONY`, puis :

```make
## Tests unitaires Lua 5.1 (sans fenêtre)
unit:
	@lua5.1 tests/run.lua
```

et la ligne d'aide `@echo "  unit        Tests unitaires Lua 5.1 (rapides, sans fenêtre)"`.

- [ ] **Step 3: Étape CI** — dans `.github/workflows/ci.yml`, après l'étape « Lua 5.1 compile check » :

```yaml
      - name: Unit tests (Lua 5.1)
        run: lua5.1 tests/run.lua
```

(Les fichiers de test sont créés aux tâches suivantes ; le lanceur échoue tant qu'ils manquent.)

---

### Task 2: Données et directeur de rencontres

**Files:** Create `src/data/encounters.lua`, `src/core/encounter_director.lua`, `tests/test_director.lua`

- [ ] **Step 1: Écrire `tests/test_director.lua` (échoue : modules absents)**

```lua
local Director = require("src.core.encounter_director")
local Encounters = require("src.data.encounters")
local WorldManager = require("src.core.world_manager")

local T = {}

local function chapterOf(room) return math.min(6, math.floor((room - 1) / 10) + 1) end
local function isCombat(room) return WorldManager.getRoomType(room) == "combat" end

local function eachCombatRoom(fn)
    for room = 1, 150 do
        if isCombat(room) then fn(room, chapterOf(room), Director.compose(chapterOf(room), room)) end
    end
end

local function threat(spawn)
    return Encounters.COST[spawn.type] * (spawn.affixes and Encounters.ELITE_COST_MULT or 1)
end

T["déterministe"] = function()
    for room = 1, 60 do
        if isCombat(room) then
            local a, b = Director.compose(chapterOf(room), room), Director.compose(chapterOf(room), room)
            assert(#a.waves == #b.waves, "salle " .. room)
            for w = 1, #a.waves do
                for i = 1, #a.waves[w] do
                    assert(a.waves[w][i].type == b.waves[w][i].type, "salle " .. room)
                end
            end
        end
    end
end

T["plafonds par vague et par salle"] = function()
    eachCombatRoom(function(room, _, enc)
        local total = 0
        for _, wave in ipairs(enc.waves) do
            assert(#wave >= 1 and #wave <= Encounters.MAX_PER_WAVE, "salle " .. room .. " : " .. #wave)
            total = total + #wave
        end
        assert(total <= Encounters.MAX_PER_ROOM, "salle " .. room .. " total " .. total)
        assert(#enc.waves >= 1 and #enc.waves <= 3, "salle " .. room)
    end)
end

T["budget respecté (un monstre de dépassement au plus)"] = function()
    eachCombatRoom(function(room, _, enc)
        local sum = 0
        for _, wave in ipairs(enc.waves) do
            for _, s in ipairs(wave) do
                if not s.champion then sum = sum + threat(s) end
            end
        end
        assert(sum <= enc.budget + 3.0, string.format("salle %d : %.1f > %.1f", room, sum, enc.budget))
    end)
end

T["chaque vague commence par un monstre de pression"] = function()
    eachCombatRoom(function(room, _, enc)
        for w, wave in ipairs(enc.waves) do
            local role = Encounters.ROLE[wave[1].type]
            assert(Encounters.PRESSURE[role], "salle " .. room .. " vague " .. w .. " : " .. wave[1].type)
        end
    end)
end

T["invocateurs et tireurs plafonnés"] = function()
    eachCombatRoom(function(room, chapter, enc)
        for _, wave in ipairs(enc.waves) do
            local summoners, shooters = 0, 0
            for _, s in ipairs(wave) do
                if s.type == "summoner" then summoners = summoners + 1 end
                if Encounters.ROLE[s.type] == "shooter" then shooters = shooters + 1 end
            end
            assert(summoners <= 1, "salle " .. room)
            assert(shooters <= Encounters.shooterCap(chapter), "salle " .. room)
        end
    end)
end

T["types issus du groupe du chapitre"] = function()
    eachCombatRoom(function(room, chapter, enc)
        local pool = {}
        for _, t in ipairs(WorldManager.getChapter(chapter).monsterPool) do pool[t] = true end
        for _, wave in ipairs(enc.waves) do
            for _, s in ipairs(wave) do assert(pool[s.type], "salle " .. room .. " : " .. s.type) end
        end
    end)
end

T["signature différente de la salle précédente"] = function()
    for room = 2, 150 do
        if isCombat(room) and isCombat(room - 1) and chapterOf(room) == chapterOf(room - 1) then
            local a = Director.compose(chapterOf(room - 1), room - 1).signature
            local b = Director.compose(chapterOf(room), room).signature
            assert(a ~= b, "salles " .. (room - 1) .. "/" .. room .. " : " .. tostring(a))
        end
    end
end

T["nouveau type présent dans la salle de son apparition"] = function()
    eachCombatRoom(function(room, _, enc)
        if enc.newType then
            local found = false
            for _, wave in ipairs(enc.waves) do
                for _, s in ipairs(wave) do
                    if s.type == enc.newType then
                        found = true
                        assert(not s.affixes, "salle " .. room .. " : nouveau type élite")
                    end
                end
            end
            assert(found, "salle " .. room .. " : " .. enc.newType .. " absent")
        end
    end)
end

T["nombre d'élites selon le barème"] = function()
    eachCombatRoom(function(room, _, enc)
        if not Encounters.isChampionRoom(room) then
            local elites = 0
            for _, wave in ipairs(enc.waves) do
                for _, s in ipairs(wave) do if s.affixes then elites = elites + 1 end end
            end
            assert(elites == Encounters.eliteCount(room), "salle " .. room .. " : " .. elites)
        end
    end)
end

T["affixes compatibles avec le rôle"] = function()
    eachCombatRoom(function(room, _, enc)
        for _, wave in ipairs(enc.waves) do
            for _, s in ipairs(wave) do
                for _, name in ipairs(s.affixes or {}) do
                    local def = Encounters.AFFIXES[name]
                    assert(def, name)
                    assert(not def.roles or def.roles[Encounters.ROLE[s.type]], "salle " .. room .. " : " .. name .. " sur " .. s.type)
                end
            end
        end
    end)
end

T["champion en dernière vague des salles x7"] = function()
    eachCombatRoom(function(room, _, enc)
        local champions = 0
        for w, wave in ipairs(enc.waves) do
            for _, s in ipairs(wave) do
                if s.champion then
                    champions = champions + 1
                    assert(w == #enc.waves, "salle " .. room)
                    assert(#s.affixes == 2 and s.affixes[1] ~= s.affixes[2], "salle " .. room)
                end
            end
        end
        assert(champions == (Encounters.isChampionRoom(room) and 1 or 0), "salle " .. room)
    end)
end

T["salle 1 : une seule vague légère"] = function()
    local enc = Director.compose(1, 1)
    assert(#enc.waves == 1 and #enc.waves[1] <= 5)
end

T["abysse : surplus converti en PV"] = function()
    local enc = Director.compose(6, 121)
    assert(enc.budget <= Encounters.BUDGET_CAP + 1e-9)
    assert(enc.hpMult > 1)
end

return T
```

- [ ] **Step 2: Lancer** `lua5.1 tests/run.lua` → attendu : `ÉCHEC CHARGEMENT tests.test_director … module 'src.core.encounter_director' not found`.

- [ ] **Step 3: Créer `src/data/encounters.lua`**

```lua
-- src/data/encounters.lua
-- Données des rencontres : rôle et coût de menace de chaque monstre, barèmes de budget,
-- d'élites et de vagues, définitions des affixes d'élite. Module pur (aucune dépendance LÖVE).

local Encounters = {}

Encounters.ROLE = {
    slime = "tank", splitter = "tank", gargoyle = "tank", golem = "tank",
    bat = "harasser", wolf = "harasser", raven = "harasser",
    skeleton = "shooter", mage = "shooter", frost_wraith = "shooter",
    plant = "zone", turret = "zone", bomber = "zone", wisp = "zone",
    burrower = "special", summoner = "special",
}

Encounters.COST = {
    slime = 2, splitter = 3, gargoyle = 2.5, golem = 3,
    bat = 1, wolf = 1.5, raven = 1,
    skeleton = 2, mage = 2, frost_wraith = 2.5,
    plant = 1.5, turret = 2, bomber = 1.5, wisp = 1.5,
    burrower = 2.5, summoner = 2.5,
}

-- Rôles qui obligent le joueur à bouger (chaque vague en contient au moins un)
Encounters.PRESSURE = { tank = true, harasser = true }

Encounters.MAX_PER_WAVE = 7
Encounters.MAX_PER_ROOM = 16
Encounters.BUDGET_BASE = 6
Encounters.BUDGET_PER_ROOM = 0.5
Encounters.BUDGET_CAP = 34          -- au-delà (Abysse), le surplus devient des PV
Encounters.ELITE_COST_MULT = 2
Encounters.ELITE_HP_MULT = 2.2
Encounters.CHAMPION_HP_MULT = 4
Encounters.CHAMPION_WAVE1_SHARE = 0.5
Encounters.CHAMPION_ESCORT_SHARE = 0.2
Encounters.NEW_TYPE_BUDGET_MULT = 0.8
Encounters.SIGNATURE_WEIGHT = 3
Encounters.WAVE_SPLIT = { { 1 }, { 0.55, 0.45 }, { 0.4, 0.3, 0.3 } }

-- Affixes d'élite. roles = nil : autorisé pour tous les rôles. ring : teinte de l'anneau
-- pré-teinté de l'atlas (fx_ring_<ring>). L'ordre de AFFIX_ORDER fixe les tirages.
Encounters.AFFIXES = {
    swift = { label = "SWIFT", ring = "yellow", roles = { tank = true, harasser = true, shooter = true } },
    shielded = { label = "SHIELDED", ring = "blue" },
    volatile = { label = "VOLATILE", ring = "orange" },
    regenerating = { label = "REGENERATING", ring = "leaf", roles = { tank = true, zone = true, special = true } },
    enraged = { label = "ENRAGED", ring = "red" },
    frost = { label = "FROST", ring = "cyan", roles = { shooter = true, zone = true } },
}
Encounters.AFFIX_ORDER = { "swift", "shielded", "volatile", "regenerating", "enraged", "frost" }

function Encounters.budget(room, difficulty)
    return (Encounters.BUDGET_BASE + Encounters.BUDGET_PER_ROOM * (room - 1)) * (difficulty or 1)
end

function Encounters.waveCount(budget)
    if budget < 9 then return 1 elseif budget < 18 then return 2 end
    return 3
end

function Encounters.eliteCount(room)
    if room <= 3 then return 0
    elseif room <= 19 then return (room % 2 == 0) and 1 or 0
    elseif room <= 39 then return 1
    elseif room <= 59 then return 2 end
    return 3
end

function Encounters.shooterCap(chapter)
    return (chapter <= 2) and 2 or 3
end

function Encounters.isChampionRoom(room)
    return room % 10 == 7
end

-- Types débloqués dans le chapitre à la salle donnée : 3 au début du chapitre, +1 par
-- salle ; tout le groupe dans l'Abysse (salle > 60). Renvoie aussi le type qui apparaît
-- pour la première fois dans cette salle (nil en début de chapitre ou si tout est débloqué).
function Encounters.unlocked(pool, room)
    local usable = {}
    for _, t in ipairs(pool) do
        if Encounters.ROLE[t] then usable[#usable + 1] = t end
    end
    if room > 60 then return usable, nil end
    local slot = (room - 1) % 10 + 1
    local count = math.min(#usable, 2 + slot)
    local out = {}
    for i = 1, count do out[i] = usable[i] end
    local newType = (slot >= 2 and 2 + slot <= #usable) and usable[2 + slot] or nil
    return out, newType
end

return Encounters
```

- [ ] **Step 4: Créer `src/core/encounter_director.lua`**

```lua
-- src/core/encounter_director.lua
-- Composition déterministe des rencontres d'une salle de combat : budget de menace réparti
-- en 1 à 3 vagues, rôles complémentaires, élites et champion. Module pur : même salle,
-- mêmes rencontres (reprise de partie, préparation de la salle suivante en fond).

local Encounters = require("src.data.encounters")
local WorldManager = require("src.core.world_manager")

local Director = {}

local ROLE, COST = Encounters.ROLE, Encounters.COST

local function lcg(seed)
    local s = seed % 4294967296
    return function()
        s = (s * 1664525 + 1013904223) % 4294967296
        return s / 4294967296
    end
end

local function rolesOf(pool)
    local seen, list = {}, {}
    for _, t in ipairs(pool) do
        local r = ROLE[t]
        if r and not seen[r] then
            seen[r] = true
            list[#list + 1] = r
        end
    end
    return list
end

-- Rôle dominant : deux numéros de salle consécutifs donnent deux rôles différents
function Director.signature(pool, room)
    local roles = rolesOf(pool)
    if #roles == 0 then return nil end
    return roles[(room % #roles) + 1]
end

local function weightedPick(rng, list, signature)
    local total = 0
    for _, t in ipairs(list) do
        total = total + ((ROLE[t] == signature) and Encounters.SIGNATURE_WEIGHT or 1)
    end
    local r = rng() * total
    for _, t in ipairs(list) do
        r = r - ((ROLE[t] == signature) and Encounters.SIGNATURE_WEIGHT or 1)
        if r <= 0 then return t end
    end
    return list[#list]
end

-- Une vague : ancre de pression, type imposé éventuel, puis remplissage dans le budget
local function composeWave(rng, pool, signature, budget, maxCount, shooterCap, mustInclude)
    local wave, used, shooters, summoners = {}, 0, 0, 0
    local function canAdd(t)
        if #wave >= maxCount then return false end
        if #wave > 0 and used + COST[t] > budget + 1e-9 then return false end
        if t == "summoner" and summoners >= 1 then return false end
        if ROLE[t] == "shooter" and shooters >= shooterCap then return false end
        return true
    end
    local function add(t)
        wave[#wave + 1] = { type = t }
        used = used + COST[t]
        if t == "summoner" then summoners = summoners + 1 end
        if ROLE[t] == "shooter" then shooters = shooters + 1 end
    end

    local pressure = {}
    for _, t in ipairs(pool) do
        if Encounters.PRESSURE[ROLE[t]] then pressure[#pressure + 1] = t end
    end
    if #pressure > 0 and maxCount > 0 then add(weightedPick(rng, pressure, signature)) end
    if mustInclude and canAdd(mustInclude) then add(mustInclude) end
    for _ = 1, Encounters.MAX_PER_WAVE do
        local candidates = {}
        for _, t in ipairs(pool) do
            if canAdd(t) then candidates[#candidates + 1] = t end
        end
        if #candidates == 0 then break end
        add(weightedPick(rng, candidates, signature))
    end
    return wave
end

local function allowedAffixes(t, exclude)
    local list = {}
    for _, name in ipairs(Encounters.AFFIX_ORDER) do
        local def = Encounters.AFFIXES[name]
        if name ~= exclude and (not def.roles or def.roles[ROLE[t]]) then list[#list + 1] = name end
    end
    return list
end

local function pickAffix(rng, t, exclude)
    local list = allowedAffixes(t, exclude)
    return list[math.floor(rng() * #list) + 1]
end

-- Élites : depuis la dernière vague vers la première, parmi les monstres éligibles
local function assignElites(rng, waves, count, newType)
    local assigned = 0
    for w = #waves, 1, -1 do
        local eligible = {}
        for i, s in ipairs(waves[w]) do
            if s.type ~= newType and not s.affixes then eligible[#eligible + 1] = i end
        end
        while assigned < count and #eligible > 0 do
            local k = math.floor(rng() * #eligible) + 1
            local s = waves[w][eligible[k]]
            table.remove(eligible, k)
            s.affixes = { pickAffix(rng, s.type) }
            assigned = assigned + 1
        end
        if assigned >= count then break end
    end
end

-- Champion : le tank le plus coûteux du groupe, sinon le harceleur le plus coûteux
local function championType(pool)
    local best, bestCost
    for _, wanted in ipairs({ "tank", "harasser" }) do
        for _, t in ipairs(pool) do
            if ROLE[t] == wanted and (not bestCost or COST[t] > bestCost) then best, bestCost = t, COST[t] end
        end
        if best then return best end
    end
    return pool[1]
end

-- compose(chapterIndex, roomNumber, opts) -> { waves, budget, hpMult, signature, newType }
-- opts.difficulty : multiplicateur de budget (mode Difficile, chantier 4)
function Director.compose(chapterIndex, roomNumber, opts)
    opts = opts or {}
    local chap = WorldManager.getChapter(chapterIndex)
    local pool, newType = Encounters.unlocked(chap.monsterPool or { "slime" }, roomNumber)
    local rng = lcg(chapterIndex * 7919 + roomNumber * 104729 + 17)
    local signature = Director.signature(pool, roomNumber)
    local shooterCap = Encounters.shooterCap(chapterIndex)

    local raw = Encounters.budget(roomNumber, opts.difficulty)
    if newType then raw = raw * Encounters.NEW_TYPE_BUDGET_MULT end
    local budget = math.min(raw, Encounters.BUDGET_CAP)
    local hpMult = (raw > Encounters.BUDGET_CAP) and (1 + (raw - Encounters.BUDGET_CAP) / Encounters.BUDGET_CAP) or 1

    local result = { budget = budget, hpMult = hpMult, signature = signature, newType = newType, waves = {} }
    local remaining = Encounters.MAX_PER_ROOM

    if Encounters.isChampionRoom(roomNumber) then
        local w1 = composeWave(rng, pool, signature, budget * Encounters.CHAMPION_WAVE1_SHARE,
            math.min(Encounters.MAX_PER_WAVE, remaining), shooterCap, newType)
        local cType = championType(pool)
        local first = pickAffix(rng, cType)
        local champion = { type = cType, champion = true, affixes = { first, pickAffix(rng, cType, first) } }
        local escort = composeWave(rng, pool, signature, budget * Encounters.CHAMPION_ESCORT_SHARE,
            Encounters.MAX_PER_WAVE - 1, shooterCap, nil)
        local w2 = { champion }
        for _, s in ipairs(escort) do w2[#w2 + 1] = s end
        result.waves = { w1, w2 }
        return result
    end

    local elites = Encounters.eliteCount(roomNumber)
    local fillBudget = math.max(Encounters.BUDGET_BASE, budget - Encounters.ELITE_COST_MULT * elites)
    local split = Encounters.WAVE_SPLIT[Encounters.waveCount(budget)]
    for w, share in ipairs(split) do
        local maxCount = math.min(Encounters.MAX_PER_WAVE, remaining - (#split - w))
        local wave = composeWave(rng, pool, signature, fillBudget * share, maxCount, shooterCap,
            (w == 1) and newType or nil)
        remaining = remaining - #wave
        result.waves[w] = wave
    end
    assignElites(rng, result.waves, elites, newType)
    return result
end

return Director
```

- [ ] **Step 5: Lancer** `lua5.1 tests/run.lua` → attendu : tous les tests de `tests.test_director` passent (les autres suites échouent au chargement tant qu'elles n'existent pas). Corriger les barèmes si un test échoue, sans affaiblir le test.

- [ ] **Step 6: Commit** `git add src/data/encounters.lua src/core/encounter_director.lua tests/ Makefile .github/workflows/ci.yml && git commit -m "feat: encounter director (roles, threat budget, waves, elites, champions)"`

---

### Task 3: `WorldManager.generateEncounter`

**Files:** Modify `src/core/world_manager.lua`, `src/data/balance.lua` ; Create `tests/test_world_encounter.lua`

- [ ] **Step 1: Écrire `tests/test_world_encounter.lua`**

```lua
local WorldManager = require("src.core.world_manager")
local Balance = require("src.data.balance")

local T = {}

T["salle d'ange : aucune vague"] = function()
    local enc = WorldManager.generateEncounter(1, 5, 640, 480)
    assert(#enc.waves == 0)
end

T["salle de boss : une vague avec le boss"] = function()
    local enc = WorldManager.generateEncounter(1, 10, 640, 480)
    assert(#enc.waves == 1)
    local boss = 0
    for _, s in ipairs(enc.waves[1]) do if s.isBoss then boss = boss + 1 end end
    assert(boss == 1)
end

T["PV : total = hpMult x budget de PV historique"] = function()
    local room, chapter = 24, 3
    local enc = WorldManager.generateEncounter(chapter, room, 640, 480)
    local count, total = 0, 0
    for _, wave in ipairs(enc.waves) do
        for _, s in ipairs(wave) do count = count + 1; total = total + s.hp end
    end
    local chap = WorldManager.getChapter(chapter)
    local baseHp = chap.baseHp + (room - 1) * chap.hpScaling
    local expected = Balance.ENCOUNTER.hpMult * WorldManager.hpBudget(baseHp, math.max(4, math.min(10, count)))
    assert(math.abs(total - expected) <= count, string.format("%d vs %.0f", total, expected))
end

T["élite plus robuste que le même type normal"] = function()
    for room = 20, 40 do
        if WorldManager.getRoomType(room) == "combat" and room % 10 ~= 7 then
            local enc = WorldManager.generateEncounter(3, room, 640, 480)
            local elite, normal = {}, {}
            for _, wave in ipairs(enc.waves) do
                for _, s in ipairs(wave) do
                    if s.affixes then elite[s.type] = s.hp else normal[s.type] = s.hp end
                end
            end
            for t, hp in pairs(elite) do
                if normal[t] then assert(hp > normal[t] * 2, t) return end
            end
        end
    end
end

T["positions dans la salle"] = function()
    local enc = WorldManager.generateEncounter(2, 13, 640, 480)
    for _, wave in ipairs(enc.waves) do
        for _, s in ipairs(wave) do
            assert(s.x > 0 and s.x < 640 and s.y > 0 and s.y < 480)
        end
    end
end

return T
```

- [ ] **Step 2: Lancer** `lua5.1 tests/run.lua` → attendu : échecs `attempt to call field 'generateEncounter' (a nil value)`.

- [ ] **Step 3: `src/data/balance.lua`** — avant `return Balance` :

```lua
-- Rencontres (src/core/encounter_director.lua) : PV totaux d'une salle de combat par rapport
-- à l'ancien budget à vague unique (réparti désormais sur 1 à 3 vagues)
Balance.ENCOUNTER = {
    hpMult = 1.3,
}
```

- [ ] **Step 4: `src/core/world_manager.lua`**

1. Supprimer la branche morte `if roomNumber % 5 == 0 then … end` (mini-boss) de `WorldManager.generateWave` (les salles x5 sont des sanctuaires traités plus haut).
2. Avant `return WorldManager`, ajouter :

```lua
-- ============================================================================
-- RENCONTRES (salles de combat de l'Ascension et de l'Abysse) : 1 à 3 vagues composées
-- par src/core/encounter_director.lua. PV totaux = Balance.ENCOUNTER.hpMult x l'ancien
-- budget de salle, répartis selon le poids de chaque monstre (archétype, élite, champion).
-- Salles d'ange : aucune vague ; salles de boss : génération historique, vague unique.
-- ============================================================================
function WorldManager.generateEncounter(chapterIndex, roomNumber, mapW, mapH)
    local roomType = WorldManager.getRoomType(roomNumber)
    if roomType == "angel" then
        return { waves = {} }, WorldManager.getChapter(chapterIndex)
    end
    if roomType == "boss" then
        local spawns, chap = WorldManager.generateWave(chapterIndex, roomNumber, mapW, mapH)
        return { waves = { spawns } }, chap
    end

    local Director = require("src.core.encounter_director")
    local Encounters = require("src.data.encounters")
    local Balance = require("src.data.balance")
    local chap = WorldManager.getChapter(chapterIndex)
    local enc = Director.compose(chapterIndex, roomNumber)

    local types, weights, refs = {}, {}, {}
    for _, wave in ipairs(enc.waves) do
        for _, s in ipairs(wave) do
            local w = WorldManager.ARCHETYPE_HP[s.type] or 1.0
            if s.affixes then w = w * Encounters.ELITE_HP_MULT end
            if s.champion then w = w * Encounters.CHAMPION_HP_MULT end
            types[#types + 1] = s.type
            weights[#weights + 1] = w
            refs[#refs + 1] = s
        end
    end
    local count = #refs
    local baseHp = chap.baseHp + (roomNumber - 1) * chap.hpScaling
    local budget = Balance.ENCOUNTER.hpMult * WorldManager.hpBudget(baseHp, math.max(4, math.min(10, count)))
        * enc.hpMult
    local totalWeight = 0
    for _, w in ipairs(weights) do totalWeight = totalWeight + w end

    local cx = mapW and (mapW / 2) or 200
    local cy = mapH and (mapH / 2) or 120
    local waves, k = {}, 0
    for wi, wave in ipairs(enc.waves) do
        local out = {}
        for i, s in ipairs(wave) do
            k = k + 1
            local x, y = ringPosition(i, #wave, cx, cy, mapW, mapH)
            if s.champion then x, y = cx, cy - 70 end
            out[i] = {
                x = x, y = y, type = s.type, affixes = s.affixes, champion = s.champion,
                hp = math.max(1, math.floor(budget * weights[k] / math.max(1e-9, totalWeight) + 0.5)),
            }
        end
        waves[wi] = out
    end
    return { waves = waves }, chap
end
```

- [ ] **Step 5: Lancer** `lua5.1 tests/run.lua` → `test_director` et `test_world_encounter` passent.

- [ ] **Step 6: Commit** `git add src/core/world_manager.lua src/data/balance.lua tests/test_world_encounter.lua && git commit -m "feat: WorldManager.generateEncounter with weighted room HP"`

---

### Task 4: File de vagues

**Files:** Create `src/core/wave_runner.lua`, `tests/test_wave_runner.lua`

- [ ] **Step 1: Écrire `tests/test_wave_runner.lua`**

```lua
local WaveRunner = require("src.core.wave_runner")

local T = {}

local function wave(n)
    local w = {}
    for i = 1, n do w[i] = { type = "slime", id = i } end
    return w
end

T["start renvoie la première vague"] = function()
    local r = WaveRunner.new({ wave(4), wave(3) })
    assert(#r:start() == 4)
    assert(r:currentWave() == 1 and r:total() == 2)
    assert(not r:isDone())
end

T["renforts quand il reste 2 monstres ou moins"] = function()
    local r = WaveRunner.new({ wave(4), wave(3) })
    r:start()
    assert(r:update(0.1, 3, false) == nil)
    local spawns, waveNo = r:update(0.1, 2, false)
    assert(#spawns == 3 and waveNo == 2)
    assert(r:isDone())
end

T["renforts après le délai même avec du monde"] = function()
    local r = WaveRunner.new({ wave(2), wave(2) })
    r:start()
    assert(r:update(WaveRunner.TIMEOUT - 0.5, 5, false) == nil)
    local spawns = r:update(1.0, 5, false)
    assert(spawns and #spawns == 2)
end

T["plafond de monstres actifs"] = function()
    local r = WaveRunner.new({ wave(2), wave(7) })
    r:start()
    local spawns, waveNo = r:update(WaveRunner.TIMEOUT + 1, 2, false)
    assert(#spawns == WaveRunner.MAX_ACTIVE - 2 and waveNo == 2)
    assert(not r:isDone())
    local rest, again = r:update(0.1, 2, false)
    assert(#rest == 2 and again == nil)
    assert(r:isDone())
end

T["pas de renfort pendant une apparition en cours"] = function()
    local r = WaveRunner.new({ wave(1), wave(1) })
    r:start()
    assert(r:update(30, 0, true) == nil)
end

T["sans vague : terminé d'emblée"] = function()
    local r = WaveRunner.new({})
    assert(#r:start() == 0 and r:isDone())
end

T["libellé de vague"] = function()
    local r = WaveRunner.new({ wave(1), wave(1), wave(1) })
    r:start()
    assert(r:label() == "WAVE 1/3")
    r:update(0, 0, false)
    assert(r:label() == "WAVE 2/3")
end

return T
```

- [ ] **Step 2: Lancer** → échec de chargement `src.core.wave_runner`.

- [ ] **Step 3: Créer `src/core/wave_runner.lua`**

```lua
-- src/core/wave_runner.lua
-- Déroulement des vagues d'une salle : la suivante arrive quand il ne reste que
-- REINFORCE_AT monstres (ou après TIMEOUT secondes), sans jamais dépasser MAX_ACTIVE
-- monstres en vie ; le surplus attend le déclenchement suivant. Module pur.

local WaveRunner = {
    REINFORCE_AT = 2,
    TIMEOUT = 14,
    MAX_ACTIVE = 7,
}
WaveRunner.__index = WaveRunner

function WaveRunner.new(waves)
    return setmetatable({ waves = waves or {}, index = 1, queue = nil, timer = 0, labelText = nil }, WaveRunner)
end

local function setLabel(self)
    self.labelText = string.format("WAVE %d/%d", self:currentWave(), self:total())
end

-- Première vague (déjà composée), à faire apparaître immédiatement par l'appelant
function WaveRunner:start()
    local first = self.waves[1] or {}
    self.index = 2
    self.timer = 0
    setLabel(self)
    return first
end

-- alive : monstres en vie ; busy : une apparition est déjà en cours (runes au sol).
-- Renvoie (liste de monstres, numéro de la nouvelle vague ou nil) ou nil.
function WaveRunner:update(dt, alive, busy)
    if busy or self:isDone() then return nil end
    self.timer = self.timer + dt
    if alive > WaveRunner.REINFORCE_AT and self.timer < WaveRunner.TIMEOUT then return nil end
    local room = WaveRunner.MAX_ACTIVE - alive
    if room <= 0 then return nil end

    local newWave = nil
    if not self.queue then
        self.queue = {}
        for i, s in ipairs(self.waves[self.index]) do self.queue[i] = s end
        newWave = self.index
        self.index = self.index + 1
        setLabel(self)
    end
    local out = {}
    while #out < room and #self.queue > 0 do
        out[#out + 1] = table.remove(self.queue, 1)
    end
    if #self.queue == 0 then self.queue = nil end
    self.timer = 0
    return out, newWave
end

function WaveRunner:isDone()
    return self.queue == nil and self.index > #self.waves
end

function WaveRunner:currentWave()
    return math.min(math.max(1, self.index - 1), math.max(1, #self.waves))
end

function WaveRunner:total()
    return #self.waves
end

function WaveRunner:label()
    return self.labelText
end

return WaveRunner
```

- [ ] **Step 4: Lancer** → `test_wave_runner` passe.

- [ ] **Step 5: Commit** `git add src/core/wave_runner.lua tests/test_wave_runner.lua && git commit -m "feat: wave runner with reinforcement trigger and active cap"`

---

### Task 5: Affixes d'élite (logique)

**Files:** Create `src/core/elite_affixes.lua`, `tests/test_elite_affixes.lua`

- [ ] **Step 1: Écrire `tests/test_elite_affixes.lua`**

```lua
local Elite = require("src.core.elite_affixes")

local T = {}

local function monster()
    return { x = 10, y = 20, hp = 100, maxHp = 100, speed = 40, attackRateMult = 1.0 }
end

T["swift : plus rapide et attaque plus souvent"] = function()
    local d = monster()
    Elite.apply(d, { "swift" })
    assert(d.elite and d.speed > 40 and d.attackRateMult < 1)
end

T["shielded : le bouclier absorbe avant les PV"] = function()
    local d = monster()
    Elite.apply(d, { "shielded" })
    assert(d.shieldHp == 35)
    assert(Elite.absorb(d, 20) == 0 and d.shieldHp == 15)
    assert(Elite.absorb(d, 20) == 5 and d.shieldHp == 0)
    assert(Elite.absorb(d, 20) == 20)
end

T["regenerating : soigne après 2 s sans coup"] = function()
    local d = monster()
    Elite.apply(d, { "regenerating" })
    d.hp = 50
    Elite.update(d, 1.0)
    assert(d.hp == 50)
    Elite.update(d, 1.5)
    assert(d.hp > 50)
    Elite.onHit(d)
    local hp = d.hp
    Elite.update(d, 0.5)
    assert(d.hp == hp)
end

T["enraged : une seule fois sous 50 %"] = function()
    local d = monster()
    Elite.apply(d, { "enraged" })
    assert(Elite.update(d, 0.1) == nil)
    d.hp = 49
    assert(Elite.update(d, 0.1) == "enraged")
    local speed = d.speed
    assert(Elite.update(d, 0.1) == nil and d.speed == speed)
end

T["volatile : explosion différée à la mort"] = function()
    local d = monster()
    Elite.apply(d, { "volatile" })
    local blast = Elite.onDeath(d, 3)
    assert(blast and blast.x == 10 and blast.y == 20 and blast.delay > 0 and blast.radius > 0 and blast.damage > 0)
    assert(Elite.onDeath(monster(), 3) == nil)
end

T["frost : seuls les tirs du porteur ralentissent"] = function()
    local d = monster()
    Elite.apply(d, { "frost" })
    assert(Elite.chillsShots(d) == true)
    assert(Elite.chillsShots(monster()) == false)
    assert(Elite.chillsShots(nil) == false)
end

T["champion : deux affixes, anneau et icônes précalculés"] = function()
    local d = monster()
    Elite.apply(d, { "shielded", "enraged" }, true)
    assert(d.champion and d.affixes.shielded and d.affixes.enraged)
    assert(d.ringSprite == "fx_ring_blue")
    assert(#d.affixIcons == 2 and d.affixIcons[2] == "icon_affix_enraged")
end

T["reset efface l'état d'élite"] = function()
    local d = monster()
    Elite.apply(d, { "shielded" })
    Elite.reset(d)
    assert(not d.elite and d.shieldHp == 0 and d.affixes == nil)
end

return T
```

- [ ] **Step 2: Lancer** → échec de chargement `src.core.elite_affixes`.

- [ ] **Step 3: Créer `src/core/elite_affixes.lua`**

```lua
-- src/core/elite_affixes.lua
-- Logique des affixes d'élite (src/data/encounters.lua) : statistiques à l'apparition,
-- bouclier, régénération, rage, explosion à la mort, tirs givrants. Module pur : les effets
-- visuels et sonores sont déclenchés par l'appelant à partir des valeurs renvoyées.

local Encounters = require("src.data.encounters")

local Elite = {
    SWIFT_SPEED = 1.35, SWIFT_RATE = 0.75,
    SHIELD_RATIO = 0.35,
    REGEN_DELAY = 2.0, REGEN_RATE = 0.04,
    ENRAGE_AT = 0.5, ENRAGE_SPEED = 1.4, ENRAGE_RATE = 0.7,
    BLAST_DELAY = 0.9, BLAST_RADIUS = 46, BLAST_BASE = 20, BLAST_PER_CHAPTER = 6,
    CHILL_TIME = 1.5, CHILL_SPEED = 0.6,
    shooter = nil, -- monstre dont l'IA s'exécute (marque ses tirs : affixe frost)
}

function Elite.reset(d)
    d.elite, d.champion = false, false
    d.affixes, d.affixList, d.affixIcons, d.ringSprite = nil, nil, nil, nil
    d.shieldHp, d.shieldMax, d.sinceHit, d.eliteEnraged = 0, 0, 0, false
end

function Elite.apply(d, affixes, champion)
    Elite.reset(d)
    d.elite = true
    d.champion = champion or false
    d.affixes, d.affixList, d.affixIcons = {}, affixes, {}
    for i, name in ipairs(affixes) do
        d.affixes[name] = true
        d.affixIcons[i] = "icon_affix_" .. name
    end
    d.ringSprite = "fx_ring_" .. Encounters.AFFIXES[affixes[1]].ring
    if d.affixes.swift then
        d.speed = d.speed * Elite.SWIFT_SPEED
        d.attackRateMult = (d.attackRateMult or 1) * Elite.SWIFT_RATE
    end
    if d.affixes.shielded then
        d.shieldMax = math.floor(d.maxHp * Elite.SHIELD_RATIO)
        d.shieldHp = d.shieldMax
    end
end

-- Dégâts restants après le bouclier
function Elite.absorb(d, dmg)
    if (d.shieldHp or 0) <= 0 then return dmg end
    local taken = math.min(d.shieldHp, dmg)
    d.shieldHp = d.shieldHp - taken
    return dmg - taken
end

function Elite.onHit(d)
    d.sinceHit = 0
end

-- Renvoie "enraged" à l'image où la rage se déclenche (pour l'effet visuel), sinon nil
function Elite.update(d, dt)
    if not d.elite then return nil end
    d.sinceHit = (d.sinceHit or 0) + dt
    local a = d.affixes
    if a.regenerating and d.sinceHit >= Elite.REGEN_DELAY and d.hp < d.maxHp then
        d.hp = math.min(d.maxHp, d.hp + d.maxHp * Elite.REGEN_RATE * dt)
    end
    if a.enraged and not d.eliteEnraged and d.hp <= d.maxHp * Elite.ENRAGE_AT then
        d.eliteEnraged = true
        d.isEnraged = true
        d.speed = d.speed * Elite.ENRAGE_SPEED
        d.attackRateMult = (d.attackRateMult or 1) * Elite.ENRAGE_RATE
        return "enraged"
    end
    return nil
end

-- Explosion à déclencher à la mort (affixe volatile) : { x, y, radius, delay, damage } ou nil
function Elite.onDeath(d, chapterIndex)
    if not (d.elite and d.affixes and d.affixes.volatile) then return nil end
    return {
        x = d.x, y = d.y, radius = Elite.BLAST_RADIUS, delay = Elite.BLAST_DELAY,
        damage = Elite.BLAST_BASE + Elite.BLAST_PER_CHAPTER * (chapterIndex or 1),
    }
end

function Elite.chillsShots(d)
    return d ~= nil and d.elite == true and d.affixes ~= nil and d.affixes.frost == true
end

return Elite
```

- [ ] **Step 4: Lancer** → les 4 suites passent : `N tests réussis, 0 échecs`.

- [ ] **Step 5: Commit** `git add src/core/elite_affixes.lua tests/test_elite_affixes.lua && git commit -m "feat: elite affix logic (swift, shielded, volatile, regenerating, enraged, frost)"`

---

### Task 6: Crochets entités (Dummy, Projectile, Player)

**Files:** Modify `src/entities/dummy.lua`, `src/entities/projectile.lua`, `src/entities/player.lua`

- [ ] **Step 1: `dummy.lua`** — `local EliteAffixes = require("src.core.elite_affixes")` en tête ;
  - dans `Dummy:spawn`, après `self.attackRateMult = 1.0` : `EliteAffixes.reset(self)` ;
  - dans `Dummy:takeDamage`, juste après le test `canTakeDamage` :

```lua
    -- Élite : le bouclier absorbe d'abord ; tout coup interrompt la régénération
    if self.elite then
        dmg = EliteAffixes.absorb(self, dmg)
        EliteAffixes.onHit(self)
    end
```

  - dans `Dummy:update`, après la ligne `darkMark` :

```lua
    if self.elite and EliteAffixes.update(self, dt) == "enraged" then
        VFX.addFCT(self.x, self.y - 24, "ENRAGED!", true)
        VFX.addSparks(self.x, self.y, 10, { 1.0, 0.25, 0.2, 1.0 })
        VFX.triggerHitFlash(self, 4)
    end
```

  - autour de `AIController.update(...)` :

```lua
    EliteAffixes.shooter = self -- marque les tirs créés par cette IA (affixe frost)
    AIController.update(self, dt, player, projectilePool, obstacleManager, dummyPool, fctPool, mapW, mapH)
    EliteAffixes.shooter = nil
```

- [ ] **Step 2: `projectile.lua`** — `local EliteAffixes = require("src.core.elite_affixes")` ; à la fin de `Projectile:spawn` et de `Projectile:spawnLobbed` (avant leur `end`) :

```lua
    self.chill = (isEnemy and EliteAffixes.chillsShots(EliteAffixes.shooter)) or false
```

- [ ] **Step 3: `player.lua`** — `self.chillTimer = 0` dans l'initialisation du joueur ; méthode :

```lua
-- Ralentissement (tirs d'une élite "frost")
function Player:chill(duration)
    if (self.chillTimer or 0) <= 0 then
        VFX.addFCT(self.x, self.y - 22, "CHILLED", false)
    end
    self.chillTimer = math.max(self.chillTimer or 0, duration)
end
```

  dans `Player:update`, `if (self.chillTimer or 0) > 0 then self.chillTimer = self.chillTimer - dt end` ; dans `handleInput`, la vitesse devient
  `local speed = self.speed * (self.terrainSpeedMult or 1.0) * (((self.chillTimer or 0) > 0) and EliteAffixes.CHILL_SPEED or 1)` (require d'`EliteAffixes` en tête).

- [ ] **Step 4: Vérifier** `lua5.1 tests/run.lua` (0 échec) et `love . --test` → `SUCCESS: 100%`.

- [ ] **Step 5: Commit** `git commit -am "feat: elite hooks in monsters, chilling enemy shots"`

---

### Task 7: Intégration dans `GameState`

**Files:** Modify `src/states/game.lua`

- [ ] **Step 1: Requires** — `local WaveRunner = require("src.core.wave_runner")`, `local EliteAffixes = require("src.core.elite_affixes")`, `local Encounters = require("src.data.encounters")`, constante `local REINFORCE_WARNING = 1.0` (runes au sol avant un renfort) et `local REINFORCE_MIN_DIST = 110`.

- [ ] **Step 2: `setupRoom`** — remplacer la branche `else spawns, chap = WorldManager.generateWave(...)` par :

```lua
    else
        local enc
        enc, chap = WorldManager.generateEncounter(self.chapterIndex, roomNum, self.mapW, self.mapH)
        self.waveRunner = WaveRunner.new(enc.waves)
        spawns = self.waveRunner:start()
    end
```

  et mettre `self.waveRunner = nil` dans les branches Boss Rush et Survie.

- [ ] **Step 3: Placement des renforts** — nouvelle méthode :

```lua
-- Renforts : loin du héros (renvoyés de l'autre côté du centre s'ils tombent à moins de
-- REINFORCE_MIN_DIST), puis sur une case libre
function GameState:placeReinforcements(spawns)
    local cx, cy = self.mapW / 2, self.mapH / 2
    local p = self.player
    for _, sp in ipairs(spawns) do
        local dx, dy = sp.x - p.x, sp.y - p.y
        if dx * dx + dy * dy < REINFORCE_MIN_DIST * REINFORCE_MIN_DIST then
            sp.x, sp.y = cx * 2 - sp.x, cy * 2 - sp.y
        end
        sp.x, sp.y = self.obstacleManager:findFreeSpot(sp.x, sp.y, 18)
    end
    return spawns
end
```

  (vérifier la signature réelle de `ObstacleManager:findFreeSpot` et adapter le 3ᵉ argument).

- [ ] **Step 4: `spawnMonstersNow`** — après `d.isBoss = sp.isBoss or false` :

```lua
            if sp.affixes then
                EliteAffixes.apply(d, sp.affixes, sp.champion)
                local label = Encounters.AFFIXES[sp.affixes[1]].label
                VFX.addFCT(d.x, d.y - 22, sp.champion and "CHAMPION" or label, true)
                if sp.champion then
                    Banner.show("boss", "CHAMPION", Bestiary.nameOf(sp.type):upper())
                    Audio.play("boss_roar", 0.1, 0.7)
                end
            end
```

  (vérifier la signature de `Banner.show("boss", …)` et l'adapter.)

- [ ] **Step 5: Renforts dans `update`** — juste après le bloc « Phase d'anticipation des monstres » :

```lua
    -- Renforts : vague suivante quand la salle se vide (src/core/wave_runner.lua)
    if self.waveRunner and self.phase == "combat" and not self.isGameOver then
        local spawns, waveNo = self.waveRunner:update(dt, self.dummyPool.activeCount, self.spawnWarningTimer > 0)
        if spawns then
            self.pendingSpawns = self:placeReinforcements(spawns)
            self.spawnWarningTimer = REINFORCE_WARNING
            if waveNo then
                Banner.show("room", self.waveRunner:label())
                VFX.shakeLight()
            end
        end
    end
```

- [ ] **Step 6: Porte** — dans la condition du bloc « 8. PHASE DE CLEAR », ajouter `and (not self.waveRunner or self.waveRunner:isDone())`.

- [ ] **Step 7: Explosion volatile** — dans `handleMonsterDeath`, avant `self.dummyPool:free(target)` :

```lua
    local blast = EliteAffixes.onDeath(target, self.chapterIndex)
    if blast then
        local p = self.projectilePool:obtain()
        if p then
            p:spawnLobbed(blast.x, blast.y, blast.x, blast.y, blast.delay, blast.damage, blast.radius,
                { 1.0, 0.45, 0.1, 1.0 }, true)
        end
    end
```

- [ ] **Step 8: Tirs givrants** — dans les deux chemins où un tir ennemi touche le héros (explosion de bombe lobée et tir direct non esquivé), après les dégâts : `if proj.chill then self.player:chill(EliteAffixes.CHILL_TIME) end`.

- [ ] **Step 9: Vérifier** `love . --test` (`SUCCESS: 100%`), `love . --bench --sim3ds --room=24 --duration=20` sans erreur, puis commit `git commit -am "feat: waves, elites and champions in combat rooms"`.

---

### Task 8: Rendu et HUD

**Files:** Modify `src/render/sprites/icons.lua`, `src/render/monsters.lua`, `src/ui/hud.lua` ; régénérer l'atlas

- [ ] **Step 1: Icônes** — ajouter à `ICONS` dans `icons.lua` :

```lua
    affix_swift = {
        grid = { "....YY.", "...YY..", "..YYYY.", ".YYYY..", "...YY..", "..YY...", ".YY...." },
        pal = { Y = "fee761" },
    },
    affix_shielded = {
        grid = { ".BBBBB.", "BWBBBBB", "BWBBBBB", "BBBBBBB", ".BBBBB.", "..BBB..", "...B..." },
        pal = { B = "0099db", W = "2ce8f5" },
    },
    affix_volatile = {
        grid = { "....F..", "...F...", "..OOO..", ".OOOOO.", ".OWOOO.", ".OOOOO.", "..OOO.." },
        pal = { O = "f77622", W = "fee761", F = "feae34" },
    },
    affix_regenerating = {
        grid = { "..GGG..", "..GWG..", "GGGWGGG", "GWWWWWG", "GGGWGGG", "..GWG..", "..GGG.." },
        pal = { G = "3e8948", W = "63c74d" },
    },
    affix_enraged = {
        grid = { "R.....R", ".R...R.", "..RRR..", ".RRRRR.", "RWRRRWR", "RRRRRRR", ".R.R.R." },
        pal = { R = "e43b44", W = "fee761" },
    },
    affix_frost = {
        grid = { "...C...", ".C.C.C.", "..CWC..", "CCWWWCC", "..CWC..", ".C.C.C.", "...C..." },
        pal = { C = "2ce8f5", W = "ffffff" },
    },
```

- [ ] **Step 2: `monsters.lua`** — avant l'appel `drawer(m, px, py, t)` :

```lua
    -- Élite : anneau pré-teinté aplati sous le monstre (même lot que les sprites)
    if m.elite and m.ringSprite and not m.isBurrowed then
        local pulse = 0.25 * math.sin(t * 6 + (m.id or 0))
        local s = m.champion and 4.6 or 3.4
        Art.drawEx(m.ringSprite, 1, floor(m.x), floor(m.y + (m.radius or 10) * 0.7), 0, s + pulse, (s + pulse) * 0.45)
    end
```

  la barre de vie s'affiche aussi pour les élites à PV pleins (`(m.hp < m.maxHp or m.elite)`), et `drawHealthBar` devient :

```lua
local function drawHealthBar(m, mType)
    local big = m.champion or (mType == "golem" or mType == "splitter" or mType == "skeleton_king"
        or mType == "witch" or mType == "lava_titan"
        or mType == "storm_drake" or mType == "void_watcher")
    local barW = big and 30 or 18
    local x = floor(m.x - barW / 2)
    local y = floor(m.y - (TOP_OFFSET[mType] or 10) - 7)
    local ratio = math.max(0, math.min(1, m.hp / m.maxHp))

    -- Pixels pré-colorés : la barre reste dans le lot des sprites (pas d'appel GPU en plus)
    Art.px("ink", x - 1, y - 1, barW + 2, 5)
    local fillW = floor(barW * ratio + 0.5)
    if fillW > 0 then
        Art.px((m.isBoss or m.champion) and "orange" or (m.elite and "amber" or "red"), x, y, fillW, 3)
    end
    if (m.shieldMax or 0) > 0 and m.shieldHp > 0 then
        Art.px("cyan", x, y - 2, floor(barW * m.shieldHp / m.shieldMax + 0.5), 1)
    end
    if m.affixIcons then
        for i, icon in ipairs(m.affixIcons) do
            Art.draw(icon, 1, x - 6 - (i - 1) * 9, y + 1)
        end
    end
end
```

- [ ] **Step 3: HUD** — dans `HUD:drawLive`, à côté de la ligne `KILLS` :

```lua
        local waves = game.waveRunner
        if waves and waves:total() > 1 then
            PixelFont.printf(waves:label(), x + 4, y + 84, 60, "left", C.amber, "tiny")
        end
```

- [ ] **Step 4: Atlas** — `~/AppImages/löve.appimage tools/bake` ; vérifier qu'il tient (`max sprite bottom` < 512) et qu'une seconde exécution donne le même `md5sum`.

- [ ] **Step 5: Vérifier visuellement** — `love . --bench --room=24 --duration=6`, lire `bench_2.png` (anneau, icône, barre ambre), puis une salle de champion (`--room=17`).

- [ ] **Step 6: Commit** `git add -A && git commit -m "feat: elite rings, affix icons, shield bar, wave indicator"`

---

### Task 9: Vérification finale et documentation

- [ ] **Step 1:** `lua5.1 tests/run.lua` (0 échec), `love . --test` (`SUCCESS: 100%`), `python3 tools/lua_bytecode.py --selftest`.
- [ ] **Step 2:** `love . --bench --sim3ds --roomload` : moyenne PC comparable (≈ 6 ms).
- [ ] **Step 3:** Azahar : `python3 tools/build_all.py --fast --with-bench`, `bench_play` contenant `48` puis `24` ; FPS ≥ mesure précédente (46,4 en salle 48), aucune erreur dans `error_log.txt`. Capture `emu.sh shot`.
- [ ] **Step 4:** README, section « Key Features » : vagues de renforts, 6 affixes d'élite, champions en salle 7 de chaque chapitre.
- [ ] **Step 5:** Commit `git commit -am "docs: encounters in README"`.
