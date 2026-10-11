-- tests/test_acts.lua
-- Acts of the Ascension: Act I = worlds 1-5 (floors 1-50), Act II = worlds 6-10 (floors 51-100).
-- Act II ends with the last world that exists, so it grows as new worlds ship.
local WorldManager = require("src.core.world_manager")

local LAST_FLOOR = #WorldManager.CHAPTERS * WorldManager.ROOMS_PER_WORLD

local T = {}

T["Act I covers floors 1 to 50"] = function()
    local first, last = WorldManager.actFloors(1)
    assert(first == 1 and last == 50, tostring(first) .. "-" .. tostring(last))
end

T["Act II starts on floor 51 and ends with the last world"] = function()
    local first, last = WorldManager.actFloors(2)
    assert(first == 51 and last == LAST_FLOOR, tostring(first) .. "-" .. tostring(last))
end

T["there is no Act III"] = function()
    assert(WorldManager.actFloors(3) == nil)
end

T["act of a floor"] = function()
    assert(WorldManager.actOfRoom(1) == 1)
    assert(WorldManager.actOfRoom(50) == 1)
    assert(WorldManager.actOfRoom(51) == 2)
    assert(WorldManager.actOfRoom(LAST_FLOOR) == 2)
    assert(WorldManager.actOfRoom(LAST_FLOOR + 1) == nil, "Abyss floors past the last act")
end

T["act of a world"] = function()
    assert(WorldManager.actOfWorld(1) == 1)
    assert(WorldManager.actOfWorld(5) == 1)
    assert(WorldManager.actOfWorld(6) == 2)
end

T["the end of Act I offers the next act, the end of Act II does not"] = function()
    assert(WorldManager.offersNextAct("ascension", 50) == true)
    assert(WorldManager.offersNextAct("ascension", LAST_FLOOR) == false)
    assert(WorldManager.offersNextAct("ascension", 49) == false)
    assert(WorldManager.offersNextAct("infinite", 50) == false)
end

T["the world depth keeps counting past the last world"] = function()
    assert(WorldManager.worldDepth(1) == 1)
    assert(WorldManager.worldDepth(60) == 6)
    assert(WorldManager.worldDepth(61) == 7)
    assert(WorldManager.worldDepth(125) == 13)
end

T["the Abyss cycles the worlds past the last floor"] = function()
    local n = #WorldManager.CHAPTERS
    assert(WorldManager.worldOfRoom(LAST_FLOOR) == n)
    assert(WorldManager.worldOfRoom(LAST_FLOOR + 1) == 1)
    assert(WorldManager.worldOfRoom(LAST_FLOOR + 10) == 1)
    assert(WorldManager.worldOfRoom(LAST_FLOOR + 11) == 2)
end

T["a missing or zero floor counts as floor 1"] = function()
    assert(WorldManager.actOfRoom(nil) == 1)
    assert(WorldManager.actOfRoom(0) == 1)
    assert(WorldManager.isFinalFloor("ascension", nil) == false)
    assert(WorldManager.offersNextAct("ascension", nil) == false)
    assert(WorldManager.floorTotal("ascension", 0) == 50)
end

-- Runs fn with WorldManager.CHAPTERS cut down to its first `count` entries, then restores it
local function withWorlds(count, fn)
    local original = WorldManager.CHAPTERS
    local truncated = {}
    for i = 1, count do truncated[i] = original[i] end
    WorldManager.CHAPTERS = truncated
    local ok, err = pcall(fn)
    WorldManager.CHAPTERS = original
    assert(ok, err)
end

T["without Act II worlds, Act II does not exist and Act I offers no next act"] = function()
    withWorlds(5, function()
        assert(WorldManager.actFloors(2) == nil)
        assert(WorldManager.offersNextAct("ascension", 50) == false)
    end)
end

T["an act ends with the last world that exists"] = function()
    withWorlds(3, function()
        local first, last = WorldManager.actFloors(1)
        assert(first == 1 and last == 30, tostring(first) .. "-" .. tostring(last))
    end)
end

return T
