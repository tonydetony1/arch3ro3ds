-- src/data/boss_loot.lua
-- Equipment dropped by bosses (Ascension and Abyss): one item per boss, rolled in the boss
-- loot table and capped by the rarities unlocked by progression. While the player owns a
-- single weapon, the boss guarantees a weapon they do not own. Pure module (no LÖVE).

local Items = require("src.data.items")
local Balance = require("src.data.balance")

local BossLoot = {}

local function owns(saveData, id)
    for _, owned in ipairs(saveData.inventory or {}) do
        if owned == id then return true end
    end
    return false
end

function BossLoot.ownedWeapons(saveData)
    local count = 0
    for _, id in ipairs(Items.getSortedIds()) do
        if Items.get(id).slot == "weapon" and owns(saveData, id) then count = count + 1 end
    end
    return count
end

-- Weapons the player does not own yet, of an unlocked rarity, in a stable order
local function newWeapons(saveData, maxRarity)
    local ceiling = Balance.rarityRank(maxRarity)
    local list = {}
    for _, id in ipairs(Items.getSortedIds()) do
        local item = Items.get(id)
        if item.slot == "weapon" and not owns(saveData, id) and Balance.rarityRank(item.rarity) <= ceiling then
            list[#list + 1] = id
        end
    end
    return list
end

-- Item dropped by a boss and why: "new_weapon" (guarantee) or "drop" (boss loot table).
-- `rng` (optional): function returning a number in [0, 1), math.random by default.
function BossLoot.roll(saveData, rng)
    rng = rng or math.random
    local maxRarity = Balance.maxRarity(saveData)
    if BossLoot.ownedWeapons(saveData) <= 1 then
        local candidates = newWeapons(saveData, maxRarity)
        if #candidates > 0 then
            return candidates[math.floor(rng() * #candidates) + 1], "new_weapon"
        end
    end
    return Items.rollDrop("boss", nil, maxRarity, rng), "drop"
end

return BossLoot
