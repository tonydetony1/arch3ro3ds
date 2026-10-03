-- src/data/admin.lua
-- Valeurs du panneau admin (équilibrage et triches), persistées dans Save.data.admin.
-- Module pur : lu par le directeur de rencontres, le monde, les entités et la partie.
-- Débloqué en jeu par 7 touchers sur le titre SETTINGS (src/ui/settings_panel.lua).

local Admin = {}

Admin.TUNING = {
    { id = "hpMult",        label = "MONSTER HP",    min = 0.5, max = 2.0, step = 0.1,  default = 1 },
    { id = "budgetMult",    label = "THREAT BUDGET", min = 0.5, max = 2.0, step = 0.1,  default = 1 },
    { id = "eliteMult",     label = "ELITE RATE",    min = 0,   max = 3,   step = 0.5,  default = 1 },
    { id = "bossDmgMult",   label = "BOSS DAMAGE",   min = 0.5, max = 2.0, step = 0.1,  default = 1 },
    { id = "playerDmgMult", label = "HERO DAMAGE",   min = 0.5, max = 3.0, step = 0.25, default = 1 },
    { id = "goldMult",      label = "GOLD GAIN",     min = 1,   max = 5,   step = 0.5,  default = 1 },
}

Admin.CHEATS = {
    { id = "god",    label = "GOD MODE" },
    { id = "oneHit", label = "ONE-HIT KILLS" },
    { id = "infUlt", label = "INFINITE ULTIMATE" },
}

local defs = {}
for _, d in ipairs(Admin.TUNING) do defs[d.id] = d end
for _, d in ipairs(Admin.CHEATS) do defs[d.id] = { id = d.id, label = d.label, default = false, cheat = true } end

local values = {}

local function snap(def, v)
    v = math.max(def.min, math.min(def.max, v))
    v = def.min + math.floor((v - def.min) / def.step + 0.5) * def.step
    return tonumber(string.format("%.4f", v))
end

local function defOf(id)
    local def = defs[id]
    if not def then error("valeur admin inconnue : " .. tostring(id), 3) end
    return def
end

function Admin.get(id)
    return values[id]
end

function Admin.set(id, v)
    local def = defOf(id)
    if def.cheat then
        values[id] = (v == true)
    else
        values[id] = snap(def, v)
    end
end

function Admin.step(id, delta)
    local def = defOf(id)
    Admin.set(id, values[id] + delta * def.step)
end

function Admin.toggle(id)
    local def = defOf(id)
    if not def.cheat then error("pas une bascule : " .. id, 2) end
    values[id] = not values[id]
end

function Admin.isModified()
    for id, def in pairs(defs) do
        if values[id] ~= def.default then return true end
    end
    return false
end

function Admin.resetTuning()
    for id, def in pairs(defs) do values[id] = def.default end
end

-- Chargement depuis la sauvegarde : toute valeur absente, d'un mauvais type ou d'un
-- identifiant inconnu est ignorée (valeur par défaut)
function Admin.load(saved)
    Admin.resetTuning()
    if type(saved) ~= "table" then return end
    for id, def in pairs(defs) do
        local v = saved[id]
        if def.cheat then
            if type(v) == "boolean" then values[id] = v end
        elseif type(v) == "number" and v == v then
            values[id] = snap(def, v)
        end
    end
end

function Admin.export()
    local out = {}
    for id in pairs(defs) do out[id] = values[id] end
    return out
end

Admin.resetTuning()

return Admin
