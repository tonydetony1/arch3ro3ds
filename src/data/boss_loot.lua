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

-- Banner shown when the chest is opened: header, item name, rarity name, rarity colour.
-- `entry` = { id, isNew, copies, reason } (see GameState:dropBossChest)
function BossLoot.bannerText(entry)
    local item = Items.get(entry.id)
    local rData = Items.getRarityData(item and item.rarity)
    local header
    if entry.reason == "new_weapon" then
        header = "NEW WEAPON"
    elseif entry.isNew then
        header = "NEW ITEM"
    else
        header = string.format("COPY %d/3", entry.copies or 1)
    end
    return header, (item and item.name or tostring(entry.id)):upper(), rData.name, rData.color
end

-- Game over list: up to `maxLines` { text, color } and the number of items left out
function BossLoot.summary(runLoot, maxLines)
    local lines = {}
    for i = 1, math.min(#runLoot, maxLines) do
        local item = Items.get(runLoot[i].id)
        lines[i] = {
            text = (item and item.name or tostring(runLoot[i].id)):upper(),
            color = Items.getRarityData(item and item.rarity).color,
        }
    end
    return lines, math.max(0, #runLoot - maxLines)
end

return BossLoot
