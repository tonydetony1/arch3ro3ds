-- tests/test_boss_loot.lua
-- Equipment dropped by bosses: one item per boss, rarity capped by progression, a new weapon
-- guaranteed while the player owns a single weapon.
local Items = require("src.data.items")

local T = {}

local function always(value)
    return function() return value end
end

T["rollDrop: an injected rng makes the roll reproducible"] = function()
    -- rng 0: lowest rarity with items (common), first common id in sorted order
    assert(Items.rollDrop("boss", nil, "legendary", always(0)) == "bat_companion")
    -- rng 0.999: highest rarity with items (epic), last epic id in sorted order
    assert(Items.rollDrop("boss", nil, "legendary", always(0.999)) == "stalker_staff")
end

local BossLoot = require("src.data.boss_loot")
local Balance = require("src.data.balance")

-- Starting save: the Ranger set, best floor 1 (rarity cap: uncommon)
local function newSave(extra)
    local inventory = { "starter_bow", "vest_dexterity", "wolf_ring", "bat_companion" }
    for _, id in ipairs(extra or {}) do inventory[#inventory + 1] = id end
    return { inventory = inventory, records = { ascensionMax = 1, infiniteMax = 0 } }
end

-- Deterministic generator (same seed, same sequence)
local function lcg(seed)
    local s = seed
    return function()
        s = (s * 1664525 + 1013904223) % 4294967296
        return s / 4294967296
    end
end

T["ownedWeapons: counts distinct weapons in the inventory"] = function()
    assert(BossLoot.ownedWeapons(newSave()) == 1)
    assert(BossLoot.ownedWeapons(newSave({ "rapid_daggers" })) == 2)
end

T["roll: a single weapon owned guarantees an unowned weapon"] = function()
    local id, reason = BossLoot.roll(newSave(), always(0))
    assert(id == "rapid_daggers" and reason == "new_weapon", tostring(id) .. " " .. tostring(reason))
    id, reason = BossLoot.roll(newSave(), always(0.999))
    assert(id == "tornado_boomerang" and reason == "new_weapon", tostring(id))
end

T["roll: no weapon owned at all guarantees a weapon too"] = function()
    local save = { inventory = { "vest_dexterity" }, records = { ascensionMax = 1, infiniteMax = 0 } }
    local id, reason = BossLoot.roll(save, always(0))
    assert(Items.get(id).slot == "weapon" and reason == "new_weapon", tostring(id))
end

T["roll: two weapons owned means a normal boss roll"] = function()
    local _, reason = BossLoot.roll(newSave({ "rapid_daggers" }), always(0))
    assert(reason == "drop", tostring(reason))
end

T["roll: never above the rarity unlocked by progression"] = function()
    local save = newSave({ "rapid_daggers" })
    local cap = Balance.rarityRank(Balance.maxRarity(save))
    local rng = lcg(7)
    for _ = 1, 300 do
        local id = BossLoot.roll(save, rng)
        assert(Balance.rarityRank(Items.get(id).rarity) <= cap, id)
    end
end

T["roll: same seed, same item"] = function()
    local save = newSave({ "rapid_daggers" })
    assert(BossLoot.roll(save, lcg(42)) == BossLoot.roll(save, lcg(42)))
end

return T
