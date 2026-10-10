-- tests/test_item_passives.lua
-- Item passives (src/data/item_passives.lua): every passive an item lists does something, a
-- passive only works from its rarity tier, and the combat hooks apply what the texts promise.

love = love or {}
love.timer = love.timer or { getTime = function() return 0 end }
love.image = love.image or { newImageData = function() return {} end }
love.filesystem = love.filesystem or { write = function() return true end, read = function() return nil end }
love.graphics = love.graphics or {}
if not getmetatable(love.graphics) then
    setmetatable(love.graphics, { __index = function() return function() return {} end end })
end

local Items = require("src.data.items")
local ItemPassives = require("src.data.item_passives")
local CombatRules = require("src.data.combat_rules")
local Player = require("src.entities.player")
local Pet = require("src.entities.pet")

local VFX = require("src.render.vfx_manager")
local buildAtlas = VFX.buildTextureAtlas
VFX.buildTextureAtlas = function() end
VFX.init()
VFX.buildTextureAtlas = buildAtlas

local function hero()
    local p = Player.new(100, 100)
    p.hp, p.maxHp = 100, 100
    return p
end

local function near(a, b) return math.abs(a - b) < 1e-9 end

local T = {}

T["every rare, epic and legendary passive has an effect"] = function()
    local missing = {}
    for id, item in pairs(Items.CATALOGUE) do
        for tier, passive in pairs(item.passives or {}) do
            if tier ~= "uncommon" then
                local hero = ItemPassives.HERO[id] and ItemPassives.HERO[id][tier]
                local pet = ItemPassives.PET[id] and ItemPassives.PET[id][tier]
                if not hero and not pet and not ItemPassives.HONOURED_ELSEWHERE[passive.name] then
                    missing[#missing + 1] = id .. "." .. tier .. " (" .. passive.name .. ")"
                end
            end
        end
    end
    assert(#missing == 0, "passives without effect: " .. table.concat(missing, ", "))
end

T["a passive only works from its rarity tier"] = function()
    local p = hero()
    local base = p.critChance
    ItemPassives.applyHero(p, "starter_bow", 2) -- uncommon: Eagle Eye (rare) is still locked
    assert(near(p.critChance, base))
    ItemPassives.applyHero(p, "starter_bow", 3)
    assert(near(p.critChance, base + 0.10), "Eagle Eye must add +10% crit")
    assert((p.diagArrows or 0) == 0, "Fractal Arrows (epic) must stay locked at rare")
end

T["a legendary item has all its passives"] = function()
    local p = hero()
    local mult = p.critMultiplier
    ItemPassives.applyHero(p, "starter_bow", 5)
    assert(p.diagArrows == 1 and near(p.critMultiplier, mult + 0.5) and p.wallPasses == 1)
end

T["Eternal Monarch adds 1% per 100 gold, capped at +30%"] = function()
    local p = hero()
    local base = p.damageMult
    ItemPassives.applyHero(p, "golden_chestplate", 5, { gold = 1250 })
    assert(near(p.damageMult, base + 0.12))
    local q = hero()
    ItemPassives.applyHero(q, "golden_chestplate", 5, { gold = 90000 })
    assert(near(q.damageMult, base + 0.30))
end

T["Ferocity and Aerial Hunt pick the monster's kind"] = function()
    local p = hero()
    p.groundDamage, p.flyingDamage = 0.20, 0.20
    assert(near(ItemPassives.damageFactor(p, { type = "slime" }), 1.20))
    assert(near(ItemPassives.damageFactor(p, { type = "bat" }), 1.20))
    p.flyingDamage = 0
    assert(near(ItemPassives.damageFactor(p, { type = "bat" }), 1.0))
end

T["Primal Rage gives +1% damage per 5% missing HP"] = function()
    local p = hero()
    p.primalRage = true
    p.hp = 50
    assert(near(ItemPassives.damageFactor(p, { type = "slime" }), 1.10))
end

T["knockback only comes from a multiplier above 1, capped, weaker on bosses"] = function()
    assert(CombatRules.knockbackDistance(1, false) == 0)
    assert(near(CombatRules.knockbackDistance(3.2, false), 19.2))
    assert(CombatRules.knockbackDistance(32, false) == CombatRules.KNOCKBACK_MAX)
    assert(near(CombatRules.knockbackDistance(32, true), CombatRules.KNOCKBACK_MAX * CombatRules.KNOCKBACK_BOSS))
end

T["Magic Resistance and Carapace cut shot and contact damage"] = function()
    local p = hero()
    p.shotDamageCut, p.contactDamageCut = 0.12, 0.10
    assert(p:takeDamage(50, false, "shot") == 44)
    assert(p:takeDamage(50, false, "contact") == 45)
    assert(p:takeDamage(50, false) == 50, "hazards are not cut")
end

T["Incorporeal blocks damage for 1 second after a hit"] = function()
    local p = hero()
    p.hurtImmunityTime = 1.0
    assert(p:takeDamage(10) == 10)
    local dealt, blocked = p:takeDamage(10)
    assert(dealt == 0 and blocked)
    p:updatePassiveTimers(1.1)
    assert(p:takeDamage(10) == 10)
end

T["Ouroboros heals and Lightning Agility triggers on a dodge"] = function()
    local real = math.random
    math.random = function() return 0.01 end
    local p = hero()
    p.hp = 50
    p.dodgeChance, p.dodgeHeal, p.dodgeLightning = 0.5, 5, true
    local _, blocked, reason = p:takeDamage(30, true)
    math.random = real
    assert(blocked and reason == "dodge")
    assert(p.hp == 55 and p.lightningPending)
end

T["Phantom Drift adds dodge only under 20% HP"] = function()
    local p = hero()
    p.lowHpDodge = 0.30
    assert(near(p:effectiveDodge(), 0))
    p.hp = 15
    assert(near(p:effectiveDodge(), 0.30))
end

T["Vindictive Frost freezes a monster that hits the hero, not a boss"] = function()
    local p = hero()
    p.contactFreeze = 1.5
    local m = { status = { freeze = 0, freezeImmune = 0 } }
    p:takeDamage(10, false, "contact", m)
    assert(m.status.freeze == 1.5)
    local boss = { isBoss = true, status = { freeze = 0, freezeImmune = 0 } }
    p:takeDamage(10, false, "contact", boss)
    assert(boss.status.freeze == 0)
end

T["Entry Rush and Pack Leader speed up shots while active"] = function()
    local p = hero()
    p.entryRush, p.entryRushTimer = 0.20, 5
    p.critAttackHaste = 0.15
    p:onCritShot()
    assert(near(p:passiveHaste(), 1.35))
    p:updatePassiveTimers(5.1)
    assert(near(p:passiveHaste(), 1.0))
end

T["Lethal Gale stacks up to +25% move speed"] = function()
    local p = hero()
    p.critSpeedBoost = 0.05
    for _ = 1, 8 do p:onCritShot() end
    assert(p.critSpeedStacks == 5)
    p:updatePassiveTimers(3.1)
    assert(p.critSpeedStacks == 0)
end

T["pet passives unlock with the pet's rarity"] = function()
    local bat = Pet.new("bat_companion", 1, 1)
    ItemPassives.applyPet(bat, "bat_companion", 3)
    assert(near(bat.haste, 1.15) and bat.wallPasses == 0)
    ItemPassives.applyPet(bat, "bat_companion", 4)
    assert(bat.wallPasses > 0)
    local dragon = Pet.new("dragon_pet", 2, 1)
    ItemPassives.applyPet(dragon, "dragon_pet", 4)
    assert(dragon.burns and dragon.twin)
end

return T
