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
Encounters.MAX_SAME_TYPE = 3        -- variété : jamais plus de 3 fois le même monstre par vague
Encounters.BUDGET_BASE = 6
Encounters.BUDGET_PER_ROOM = 0.5
Encounters.BUDGET_CAP = 34          -- au-delà (Abysse), le surplus devient des PV
Encounters.ELITE_COST_MULT = 2
Encounters.ELITE_RESERVE = 3        -- budget réservé par élite (coût maximal d'un type)
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

-- HP multiplier for the part of a threat budget above BUDGET_CAP (deep Abyss rooms):
-- the room cannot hold more monsters, so the surplus turns into extra HP
function Encounters.hpOverflow(rawBudget)
    if rawBudget <= Encounters.BUDGET_CAP then return 1 end
    return 1 + (rawBudget - Encounters.BUDGET_CAP) / Encounters.BUDGET_CAP
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
