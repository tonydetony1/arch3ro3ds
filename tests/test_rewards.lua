-- tests/test_rewards.lua
-- Rewards and stats must do what the game says: wheel segments, loot drops, dodge,
-- heart pickups, hero attack bonus and weapon power by rarity.

-- Minimal LÖVE environment: every graphics call is a no-op
love = love or {}
love.timer = love.timer or { getTime = function() return 0 end }
love.image = love.image or { newImageData = function() return {} end }
love.graphics = love.graphics or {}
if not getmetatable(love.graphics) then
    setmetatable(love.graphics, { __index = function() return function() return {} end end })
end

local SpecialRoomManager = require("src.core.special_room_manager")
local Balance = require("src.data.balance")
local Player = require("src.entities.player")
local Heroes = require("src.data.heroes")
local Weapons = require("src.data.weapons")
local Items = require("src.data.items")

local T = {}

local function fakeSave()
    local s = { gold = 0, gems = 0 }
    function s.addGold(n) s.gold = s.gold + n end
    function s.addGems(n) s.gems = s.gems + n end
    return s
end

local function woundedPlayer()
    local p = Player.new(100, 100)
    p.maxHp, p.hp = 200, 50
    p.damageMult, p.attackSpeedMult = 1.0, 1.0
    return p
end

T["wheel: every segment of both wheels has an effect"] = function()
    for name, segments in pairs(SpecialRoomManager.WHEELS) do
        for _, seg in ipairs(segments) do
            local p, save = woundedPlayer(), fakeSave()
            SpecialRoomManager.applyWheelReward(p, seg, save)
            local changed = save.gold > 0 or save.gems > 0 or p.hp > 50
                or p.damageMult ~= 1.0 or p.attackSpeedMult ~= 1.0
            assert(changed, name .. " wheel: '" .. seg.label .. "' does nothing")
        end
    end
end

T["wheel: boost segments give exactly the percentage on their label"] = function()
    for name, segments in pairs(SpecialRoomManager.WHEELS) do
        for _, seg in ipairs(segments) do
            if seg.type == "boost" then
                local pct = tonumber(seg.label:match("%+(%d+)%%"))
                local p = woundedPlayer()
                SpecialRoomManager.applyWheelReward(p, seg, fakeSave())
                local gained = p[seg.stat] - 1.0
                assert(math.abs(gained - pct / 100) < 1e-6,
                    string.format("%s wheel: '%s' gives +%.0f%%", name, seg.label, gained * 100))
            end
        end
    end
end

T["loot: no scroll drop (scrolls have no use yet)"] = function()
    for i = 0, 99 do
        assert(Balance.lootType(i / 100, true) ~= "scroll")
        assert(Balance.lootType(i / 100, false) ~= "scroll")
    end
end

T["loot: 40% experience, hearts only when the hero is hurt"] = function()
    local xp, hearts = 0, 0
    for i = 0, 99 do
        if Balance.lootType(i / 100, true) == "xp" then xp = xp + 1 end
        if Balance.lootType(i / 100, false) == "heart" then hearts = hearts + 1 end
    end
    assert(xp == 40, tostring(xp))
    assert(hearts == 0, tostring(hearts))
end

T["dodge: capped so the hero can never become untouchable"] = function()
    local p = Player.new(100, 100)
    p.dodgeChance = 1.4
    assert(p:effectiveDodge() == 0.6, tostring(p:effectiveDodge()))
    p.dodgeChance = 0.25
    assert(p:effectiveDodge() == 0.25)
end

T["heart: heals at least 10% of max HP"] = function()
    local p = Player.new(100, 100)
    p.maxHp, p.healMult = 100, 1
    assert(p:heartHeal(30) == 30, tostring(p:heartHeal(30)))
    p.maxHp = 600
    assert(p:heartHeal(30) == 60, tostring(p:heartHeal(30)))
    p.healMult = 1.5
    assert(p:heartHeal(30) == 90, tostring(p:heartHeal(30)))
end

T["hero attack bonus: raises arrow damage, not only the ultimate"] = function()
    for _, hero in ipairs(Heroes.getAll()) do
        local p = Player.new(100, 100)
        p.damageMult = 1.0
        Heroes.applyHeroPassives(p, hero.id)
        local expected = 1.0 + (hero.baseAtkBonus or 0) / 100
        assert(math.abs(p.damageMult - expected) < 1e-6,
            string.format("%s: damageMult %.2f, expected %.2f", hero.id, p.damageMult, expected))
    end
end

-- Damage per second of a weapon at the same Forge level (the boomerang hits twice)
local function weaponDps(w)
    return w.damage / w.fire_rate * (1 + (w.return_damage_mult or 0))
end

T["weapons: a rarer weapon always has more damage per second"] = function()
    local minDps, maxDps = {}, {}
    for id, item in pairs(Items.CATALOGUE) do
        if item.slot == "weapon" then
            local tier = Items.getRarityData(item.rarity).tier
            local dps = weaponDps(Weapons.get(id))
            minDps[tier] = math.min(minDps[tier] or math.huge, dps)
            maxDps[tier] = math.max(maxDps[tier] or 0, dps)
        end
    end
    for tier = 2, 5 do
        if minDps[tier] and maxDps[tier - 1] then
            assert(minDps[tier] > maxDps[tier - 1], string.format("tier %d min %.1f <= tier %d max %.1f",
                tier, minDps[tier], tier - 1, maxDps[tier - 1]))
        end
    end
end

T["equipment: Bear Ring raises damage against bosses"] = function()
    local p = { bossDamageMult = 1.0, goldMultiplier = 1.0 }
    Items.applyCombatBonuses(p, Items.getStats("bear_ring", 1))
    assert(math.abs(p.bossDamageMult - 1.12) < 1e-9, tostring(p.bossDamageMult))
end

T["equipment: Golden Chestplate raises gold collected"] = function()
    local p = { bossDamageMult = 1.0, goldMultiplier = 1.0 }
    Items.applyCombatBonuses(p, Items.getStats("golden_chestplate", 1))
    assert(math.abs(p.goldMultiplier - 1.18) < 1e-9, tostring(p.goldMultiplier))
end

T["equipment: items without those bonuses change nothing"] = function()
    local p = { bossDamageMult = 1.0, goldMultiplier = 1.0 }
    Items.applyCombatBonuses(p, Items.getStats("wolf_ring", 1))
    assert(p.bossDamageMult == 1.0 and p.goldMultiplier == 1.0)
end

-- Percentage written in a passive description, e.g. "+10% Critical Hit Chance." -> 10
local function passivePct(id, tier)
    return tonumber(Items.get(id).passives[tier].desc:match("(%d+)%%"))
end

T["rare passives: crit and dodge bonuses match their description"] = function()
    for _, case in ipairs({
        { id = "starter_bow", stat = "crit" },
        { id = "wolf_ring", stat = "crit" },
        { id = "serpent_ring", stat = "dodge" },
        { id = "vest_dexterity", stat = "dodge" },
    }) do
        local item = Items.get(case.id)
        local base = (case.stat == "crit") and (item.bonusCrit or 0) or (item.bonusDodge or 0)
        local got = Items.getStats(case.id, 1, "rare")[case.stat]
        local expected = base + passivePct(case.id, "rare")
        assert(got == expected, string.format("%s: %s %d, expected %d", case.id, case.stat, got, expected))
    end
end

T["boomerang: return flight passive matches the weapon"] = function()
    local pct = passivePct("tornado_boomerang", "rare")
    assert(pct == math.floor(Weapons.get("tornado_boomerang").return_damage_mult * 100 + 0.5), tostring(pct))
end

return T
