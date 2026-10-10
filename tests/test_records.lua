-- tests/test_records.lua
-- Floor records: Ascension and the Abyss keep the deepest floor reached, whether the run ends
-- in death or is abandoned. Event modes (Boss Rush, Survival) keep their own records and must
-- not touch the floor records (the Abyss record unlocks chest rarities).

local GameState = require("src.states.game")
local PauseState = require("src.states.pause")
local Save = require("src.data.save")
local withLoveStubs = require("tests.love_stubs")

local noop = function() end

-- Runs `fn(records)` on fresh floor records, then restores the previous ones
local function withRecords(fn)
    withLoveStubs(function()
        local records = Save.get().records
        local ascension, infinite = records.ascensionMax, records.infiniteMax
        records.ascensionMax, records.infiniteMax = 1, 0
        local ok, err = pcall(fn, records)
        records.ascensionMax, records.infiniteMax = ascension, infinite
        assert(ok, err)
    end)
end

-- Ends a run of `mode` at `room` through the real game over sequence (frame by frame: a hit
-- stop left by another test can hold the first frames)
local function dieAt(mode, room)
    local over = false
    local g = setmetatable({ sm = { switch = function() over = true end } }, { __index = GameState })
    g:enter({ mode = mode })
    g.roomNumber = room
    g.isGameOver, g.gameOverTimer = true, 0
    for _ = 1, 600 do
        if over then return end
        g:update(1 / 60)
    end
    error("the game over screen never opened")
end

-- Abandons a run of `mode` at `room` from the pause screen
local function abandonAt(mode, room)
    local p = PauseState.new({ pop = noop, switch = noop })
    p:enter({ mode = mode, room = room, goldEarned = 0 })
    p.confirmQuit = true
    local b = p.modal.confirm
    p:touchpressed(1, b.x + 1, b.y + 1)
end

local T = {}

T["a Boss Rush death leaves the Abyss record alone"] = function()
    withRecords(function(records)
        dieAt("boss_rush", 12)
        assert(records.infiniteMax == 0, "Boss Rush wrote the Abyss record: " .. records.infiniteMax)
    end)
end

T["an Ascension death keeps the floor reached"] = function()
    withRecords(function(records)
        dieAt("ascension", 23)
        assert(records.ascensionMax == 23)
    end)
end

T["abandoning an Ascension run keeps the floor reached"] = function()
    withRecords(function(records)
        abandonAt("ascension", 23)
        assert(records.ascensionMax == 23, "the abandoned run's floor was lost")
    end)
end

T["abandoning an Abyss run keeps the floor reached"] = function()
    withRecords(function(records)
        abandonAt("infinite", 31)
        assert(records.infiniteMax == 31, "the abandoned run's floor was lost")
    end)
end

T["abandoning a Boss Rush leaves the floor records alone"] = function()
    withRecords(function(records)
        abandonAt("boss_rush", 9)
        assert(records.ascensionMax == 1 and records.infiniteMax == 0)
    end)
end

return T
