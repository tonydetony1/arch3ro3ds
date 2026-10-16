-- tests/test_stage_label.lua
-- The floor counter shows the length of the current act (50 for Act I, the last floor of Act II
-- after that). The Abyss and the event modes have no total. Clearing the last floor of an act
-- ends it with a victory.

local WorldManager = require("src.core.world_manager")

local T = {}

T["Act I counts up to 50 floors"] = function()
    assert(WorldManager.floorTotal("ascension", 1) == 50)
    assert(WorldManager.floorTotal("ascension", 50) == 50)
end

T["Act II counts up to its last floor"] = function()
    local _, last = WorldManager.actFloors(2)
    assert(WorldManager.floorTotal("ascension", 51) == last)
    assert(WorldManager.floorTotal("ascension", 57) == last)
end

T["past the last act there is no total"] = function()
    local _, last = WorldManager.actFloors(2)
    assert(WorldManager.floorTotal("ascension", last + 1) == nil)
end

T["the endless Abyss never shows a total"] = function()
    assert(WorldManager.floorTotal("infinite", 3) == nil)
    assert(WorldManager.floorTotal("infinite", 80) == nil)
end

T["event modes show no total"] = function()
    assert(WorldManager.floorTotal("boss_rush", 3) == nil)
    assert(WorldManager.floorTotal("survival", 3) == nil)
end

T["the stage text adds the total only when there is one"] = function()
    local _, last = WorldManager.actFloors(2)
    assert(WorldManager.stageText("ascension", 7) == "STAGE 7 / 50")
    assert(WorldManager.stageText("ascension", 57) == "STAGE 57 / " .. last)
    assert(WorldManager.stageText("infinite", 7) == "STAGE 7")
end

T["clearing the last floor of an act ends it"] = function()
    local _, last = WorldManager.actFloors(2)
    assert(WorldManager.isFinalFloor("ascension", 50) == true)
    assert(WorldManager.isFinalFloor("ascension", last) == true)
    assert(WorldManager.isFinalFloor("ascension", 49) == false)
    assert(WorldManager.isFinalFloor("ascension", 1) == false)
    assert(WorldManager.isFinalFloor("ascension", 51) == false)
end

T["the Abyss and the event modes never end on a floor"] = function()
    assert(WorldManager.isFinalFloor("infinite", 50) == false)
    assert(WorldManager.isFinalFloor("boss_rush", 50) == false)
    assert(WorldManager.isFinalFloor("survival", 50) == false)
end

return T
