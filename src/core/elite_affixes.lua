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
