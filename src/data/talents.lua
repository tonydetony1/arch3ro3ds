-- src/data/talents.lua
-- Talents permanents du Sceau sacré. Une seule table décrit l'effet affiché dans l'onglet
-- TALENTS (src/states/menu.lua) et l'effet appliqué en combat (src/states/game.lua) :
-- le libellé ne peut plus promettre autre chose que ce que le talent donne.

local Talents = {}

-- Effet par niveau
Talents.DAMAGE_PER_LEVEL = 0.05 -- force : multiplicateur de dégâts
Talents.HP_PER_LEVEL = 30       -- vitalité : PV max
Talents.DODGE_PER_LEVEL = 0.02  -- agilité : chance d'esquive
Talents.HEAL_PER_LEVEL = 0.10   -- récupération : soins reçus (cœurs, montée de niveau)

-- Talents améliorables sans limite (grille 2 x 2 de l'onglet TALENTS, dans cet ordre).
-- `step` / `unit` : effet d'un niveau tel qu'affiché (même valeur que ci-dessus).
local function pct(x) return math.floor(x * 100 + 0.5) end
Talents.LIST = {
    { id = "strength", name = "STRENGTH", step = pct(Talents.DAMAGE_PER_LEVEL), unit = "% DMG",
      icon = "swords",   color = { 1.0, 0.45, 0.45, 1.0 } },
    { id = "vitality", name = "VITALITY", step = Talents.HP_PER_LEVEL, unit = " HP",
      icon = "heart",    color = { 0.45, 1.0, 0.65, 1.0 } },
    { id = "agility",  name = "AGILITY",  step = pct(Talents.DODGE_PER_LEVEL), unit = "% DODGE",
      icon = "sparkles", color = { 0.40, 0.85, 1.0, 1.0 } },
    { id = "recovery", name = "RECOVERY", step = pct(Talents.HEAL_PER_LEVEL), unit = "% HEAL",
      icon = "hero",     color = { 1.0, 0.85, 0.30, 1.0 } },
}

-- Gloire : achat unique, une compétence offerte au début de chaque partie
Talents.GLORY = { id = "glory", name = "GLORY", maxLevel = 1, desc = "A FREE SKILL AT THE START OF EVERY RUN" }

local BY_ID = { glory = Talents.GLORY }
for _, t in ipairs(Talents.LIST) do
    BY_ID[t.id] = t
    t.effect = string.format("+%d%s", t.step, t.unit)
end

-- Effet cumulé des niveaux achetés, ex. "+15% DMG" (talents de la grille)
function Talents.totalText(t, level)
    return string.format("+%d%s", math.floor(t.step * (level or 0) + 0.5), t.unit)
end

function Talents.get(id)
    return id and BY_ID[id] or nil
end

-- Somme des niveaux achetés (sert au coût du talent suivant)
function Talents.totalLevel(levels)
    local total = 0
    for id in pairs(BY_ID) do total = total + ((levels and levels[id]) or 0) end
    return total
end

function Talents.isMaxed(id, levels)
    local t = BY_ID[id]
    return t ~= nil and t.maxLevel ~= nil and ((levels and levels[id]) or 0) >= t.maxLevel
end

function Talents.canUpgrade(id, levels)
    return BY_ID[id] ~= nil and not Talents.isMaxed(id, levels)
end

-- Multiplicateur de dégâts et PV bonus (aussi affichés dans la fiche de puissance du hub)
function Talents.damageBonus(levels)
    return ((levels and levels.strength) or 0) * Talents.DAMAGE_PER_LEVEL
end

function Talents.hpBonus(levels)
    return ((levels and levels.vitality) or 0) * Talents.HP_PER_LEVEL
end

-- Applique les talents au héros en début de partie
function Talents.apply(player, levels)
    if not levels then return end
    player.damageMult = (player.damageMult or 1) + Talents.damageBonus(levels)
    local bonusHp = Talents.hpBonus(levels)
    if bonusHp > 0 then
        player.maxHp = player.maxHp + bonusHp
        player.hp = player.maxHp
    end
    player.dodgeChance = (player.dodgeChance or 0) + (levels.agility or 0) * Talents.DODGE_PER_LEVEL
    player.healMult = (player.healMult or 1) + (levels.recovery or 0) * Talents.HEAL_PER_LEVEL
end

return Talents
