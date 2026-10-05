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

return T
