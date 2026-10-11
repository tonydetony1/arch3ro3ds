-- tests/test_act_two.lua
-- Act II: launched from the hub on its first floor with a head start, reached from Act I by
-- CONTINUE, ended by its own victory. Bosses keep scaling with the absolute world depth.

local GameState = require("src.states.game")
local Save = require("src.data.save")
local Balance = require("src.data.balance")
local WorldManager = require("src.core.world_manager")
local withLoveStubs = require("tests.love_stubs")

-- A game state whose switches to other states are recorded
local function newGame()
    local g = setmetatable({}, { __index = GameState })
    g.switched = nil
    g.sm = { switch = function(_, name, data) g.switched = { name = name, data = data } end }
    return g
end

-- Runs the game frame by frame until `done(g)` (a hit stop left by another test can hold frames)
local function runUntil(g, done)
    for _ = 1, 900 do
        if done(g) then return end
        g:update(1 / 60)
    end
    error("condition never reached")
end

local T = {}

T["bosses scale with the world depth, not the cycled world"] = function()
    withLoveStubs(function()
        local g = newGame()
        g:enter({ mode = "infinite" })
        g.roomNumber = 70
        g.pendingSpawns = { { x = 100, y = 100, hp = 500, type = "golem", isBoss = true } }
        g:spawnMonstersNow()
        local boss
        for i = 1, g.dummyPool.activeCount do
            local d = g.dummyPool.items[g.dummyPool.activeList[i]]
            if d.isBoss then boss = d end
        end
        assert(boss, "no boss spawned")
        assert(boss.chapterIndex == 7, "boss damage depth " .. tostring(boss.chapterIndex))
    end)
end

T["the shooter cap follows the world depth in the Abyss"] = function()
    local Encounters = require("src.data.encounters")
    assert(Encounters.shooterCap(WorldManager.worldDepth(65)) == 3)
    local Director = require("src.core.encounter_director")
    local enc = Director.compose(WorldManager.worldOfRoom(65), 65)
    assert(enc.shooterCap == 3, "shooter cap on floor 65: " .. tostring(enc.shooterCap))
end

return T
