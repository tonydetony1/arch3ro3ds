-- tests/test_new_run.lua
-- GameState is a singleton: "retry" calls enter() on the same table, so a new run must not
-- inherit anything from the previous one.

local GameState = require("src.states.game")

local withLoveStubs = require("tests.love_stubs")

local function singleton()
    return setmetatable({ sm = { switch = function() end } }, { __index = GameState })
end

local T = {}

T["a new run does not inherit the previous run's synergies"] = function()
    withLoveStubs(function()
        local g = singleton()
        -- Skills drafted in the run that just ended (fire + poison = Toxic Flame)
        g.acquiredSkills = { { id = "fire_element" }, { id = "poison_element" } }
        g:enter({ mode = "ascension" })
        assert(not g.player.hasSynergyToxicFlame, "Toxic Flame leaked into the new run")
        assert(not (g.player.activeSynergies or {}).toxic_flame, "the leaked synergy is marked active")
    end)
end

return T
