-- tests/test_energy_boost.lua
-- Launching a run with energy spends it for a gold bonus (Balance.ENERGY.goldMult): the gold
-- collected in that run, resume included, must actually be multiplied.

local Balance = require("src.data.balance")
local GameState = require("src.states.game")
local Save = require("src.data.save")
local withLoveStubs = require("tests.love_stubs")

local function newRun(params)
    local g = setmetatable({ sm = { switch = function() end } }, { __index = GameState })
    g:enter(params)
    return g
end

local T = {}

T["a boosted run earns the energy gold bonus"] = function()
    withLoveStubs(function()
        local g = newRun({ mode = "ascension", boosted = true })
        g:addRunGold(100)
        assert(g.goldEarnedRun == 100 * Balance.ENERGY.goldMult,
            "boosted run earned " .. g.goldEarnedRun .. " for 100 gold")
    end)
end

T["a run without energy earns plain gold"] = function()
    withLoveStubs(function()
        local g = newRun({ mode = "ascension", boosted = false })
        g:addRunGold(100)
        assert(g.goldEarnedRun == 100)
    end)
end

T["a resumed boosted run keeps its gold bonus"] = function()
    withLoveStubs(function()
        local saved = Save.get().run
        local g = newRun({ mode = "ascension", boosted = true })
        Save.saveRun(g)
        local resumed = newRun({ mode = "ascension", resume = Save.getRun() })
        Save.get().run = saved
        resumed:addRunGold(100)
        assert(resumed.goldEarnedRun == 100 * Balance.ENERGY.goldMult, "the bonus was lost on resume")
    end)
end

return T
