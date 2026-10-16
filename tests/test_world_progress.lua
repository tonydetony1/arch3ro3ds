-- tests/test_world_progress.lua
-- Worlds of a run (10 floors each) and their progress in the hub, derived from the best floor
-- ever reached. Past the last world, the Abyss cycles the worlds again.
local WorldManager = require("src.core.world_manager")

local LAST_FLOOR = #WorldManager.CHAPTERS * WorldManager.ROOMS_PER_WORLD

local T = {}

T["world of a floor: 10 floors per world"] = function()
    assert(WorldManager.worldOfRoom(1) == 1)
    assert(WorldManager.worldOfRoom(10) == 1)
    assert(WorldManager.worldOfRoom(11) == 2)
    assert(WorldManager.worldOfRoom(50) == 5)
    assert(WorldManager.worldOfRoom(51) == 6)
    assert(WorldManager.worldOfRoom(LAST_FLOOR + 1) == 1, "the Abyss cycles back to world 1")
end

T["world floors: every world has a first and a last floor"] = function()
    local first, last = WorldManager.worldFloors(3)
    assert(first == 21 and last == 30, first .. "-" .. tostring(last))
    first, last = WorldManager.worldFloors(6)
    assert(first == 51 and last == 60, first .. "-" .. tostring(last))
end

T["progress at floor 21: worlds 1-2 cleared, world 3 started, the rest locked"] = function()
    local w1 = WorldManager.worldProgress(1, 21)
    assert(w1.unlocked and w1.cleared and w1.reached == 10 and w1.total == 10)
    local w2 = WorldManager.worldProgress(2, 21)
    assert(w2.unlocked and w2.cleared and w2.reached == 10)
    local w3 = WorldManager.worldProgress(3, 21)
    assert(w3.unlocked and not w3.cleared and w3.reached == 1, tostring(w3.reached))
    for world = 4, 6 do
        local w = WorldManager.worldProgress(world, 21)
        assert(not w.unlocked and not w.cleared and w.reached == 0, "world " .. world)
    end
end

T["progress of a new save: only the first world is open"] = function()
    local w1 = WorldManager.worldProgress(1, 1)
    assert(w1.unlocked and not w1.cleared and w1.reached == 1)
    assert(not WorldManager.worldProgress(2, 1).unlocked)
end

T["an open act unlocks its first world before any of its floor is reached"] = function()
    local w6 = WorldManager.worldProgress(6, 50, 51)
    assert(w6.unlocked and w6.reached == 0 and not w6.cleared)
    assert(not WorldManager.worldProgress(6, 50).unlocked, "Act II stays locked without the clear")
end

T["progress in Void City: floors reached out of 10"] = function()
    local w6 = WorldManager.worldProgress(6, 55)
    assert(w6.unlocked and not w6.cleared and w6.reached == 5 and w6.total == 10)
end

return T
