-- tests/test_talent_caps.lua
-- Agility stops at the level where its dodge bonus is still useful (hero dodge is capped,
-- see PlayerStats.dodge_cap): the card must never promise more dodge than the hero gets.
local Talents = require("src.data.talents")

local T = {}

local function agility()
    return Talents.get("agility")
end

T["agility: capped at 15 levels"] = function()
    assert(not Talents.isMaxed("agility", { agility = 14 }))
    assert(Talents.isMaxed("agility", { agility = 15 }))
    assert(not Talents.canUpgrade("agility", { agility = 15 }))
end

T["agility: a save above the cap gets the capped dodge"] = function()
    local player = { dodgeChance = 0 }
    Talents.apply(player, { agility = 47 })
    assert(math.abs(player.dodgeChance - 0.30) < 1e-9, tostring(player.dodgeChance))
end

T["agility: the card shows the capped total"] = function()
    assert(Talents.totalText(agility(), 47) == "+30% DODGE", Talents.totalText(agility(), 47))
end

T["strength, vitality and recovery stay unlimited"] = function()
    for _, id in ipairs({ "strength", "vitality", "recovery" }) do
        assert(Talents.canUpgrade(id, { [id] = 500 }), id)
    end
end

return T
