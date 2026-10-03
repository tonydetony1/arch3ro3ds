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

-- Rôle dominant : deux numéros de salle consécutifs donnent deux rôles différents. Calculé
-- sur tout le groupe du chapitre (pas seulement les types déjà débloqués) pour que la
-- liste des rôles, donc l'alternance, ne change pas d'une salle à l'autre.
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
    local wave, used, shooters, summoners, sameType = {}, 0, 0, 0, {}
    local function canAdd(t)
        if #wave >= maxCount then return false end
        if (sameType[t] or 0) >= Encounters.MAX_SAME_TYPE then return false end
        if #wave > 0 and used + COST[t] > budget + 1e-9 then return false end
        if t == "summoner" and summoners >= 1 then return false end
        if ROLE[t] == "shooter" and shooters >= shooterCap then return false end
        return true
    end
    local function add(t)
        wave[#wave + 1] = { type = t }
        used = used + COST[t]
        sameType[t] = (sameType[t] or 0) + 1
        if t == "summoner" then summoners = summoners + 1 end
        if ROLE[t] == "shooter" then shooters = shooters + 1 end
    end

    -- Ancre : de préférence un autre type que le type imposé (sinon la vague pourrait ne
    -- contenir que le nouveau venu, qui ne doit pas être élite)
    local pressure = {}
    for _, t in ipairs(pool) do
        if Encounters.PRESSURE[ROLE[t]] and t ~= mustInclude then pressure[#pressure + 1] = t end
    end
    if #pressure == 0 then
        for _, t in ipairs(pool) do
            if Encounters.PRESSURE[ROLE[t]] then pressure[#pressure + 1] = t end
        end
    end
    if #pressure > 0 and maxCount > 0 then add(weightedPick(rng, pressure, signature)) end
    -- Type imposé (première apparition) : ajouté même au-delà du budget de la vague
    if mustInclude and #wave < maxCount and wave[1].type ~= mustInclude then add(mustInclude) end
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
    local signature = Director.signature(chap.monsterPool or pool, roomNumber)
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
    local fillBudget = math.max(Encounters.BUDGET_BASE, budget - Encounters.ELITE_RESERVE * elites)
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
