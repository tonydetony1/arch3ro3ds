-- tests/test_world_progress.lua
-- Worlds of a run (10 floors each, the last one endless) and their progress in the hub,
-- derived from the best floor ever reached.
local WorldManager = require("src.core.world_manager")

local T = {}

T["world of a floor: 10 floors per world, the last world is endless"] = function()
    assert(WorldManager.worldOfRoom(1) == 1)
    assert(WorldManager.worldOfRoom(10) == 1)
    assert(WorldManager.worldOfRoom(11) == 2)
    assert(WorldManager.worldOfRoom(50) == 5)
    assert(WorldManager.worldOfRoom(51) == 6)
    assert(WorldManager.worldOfRoom(140) == 6)
end

T["world floors: first and last floor, no last floor for the endless world"] = function()
    local first, last = WorldManager.worldFloors(3)
    assert(first == 21 and last == 30, first .. "-" .. tostring(last))
    first, last = WorldManager.worldFloors(6)
    assert(first == 51 and last == nil, first .. "-" .. tostring(last))
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

T["progress of the endless world: floors reached, never cleared"] = function()
    local w6 = WorldManager.worldProgress(6, 63)
    assert(w6.unlocked and not w6.cleared and w6.reached == 13 and w6.total == nil)
end

return T
