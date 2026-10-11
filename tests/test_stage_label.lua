-- tests/test_stage_label.lua
-- The "/ 50" floor counter only makes sense in the 50-floor Ascension run: the Abyss is endless.
-- Clearing floor 50 in Ascension now ends the run with a victory.

local WorldManager = require("src.core.world_manager")

local T = {}

T["Ascension counts up to 50 floors"] = function()
    assert(WorldManager.floorTotal("ascension", 1) == 50)
    assert(WorldManager.floorTotal("ascension", 50) == 50)
end

T["past floor 50 there is no total"] = function()
    assert(WorldManager.floorTotal("ascension", 51) == nil)
    assert(WorldManager.floorTotal("ascension", 57) == nil)
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
    assert(WorldManager.stageText("ascension", 7) == "STAGE 7 / 50")
    assert(WorldManager.stageText("ascension", 57) == "STAGE 57")
    assert(WorldManager.stageText("infinite", 7) == "STAGE 7")
end

T["clearing floor 50 ends the Ascension run"] = function()
    assert(WorldManager.isFinalFloor("ascension", 50) == true)
    assert(WorldManager.isFinalFloor("ascension", 49) == false)
    assert(WorldManager.isFinalFloor("ascension", 1) == false)
    -- an admin test run started past floor 50 is not stopped at its first door
    assert(WorldManager.isFinalFloor("ascension", 51) == false)
end

T["the Abyss and the event modes never end on a floor"] = function()
    assert(WorldManager.isFinalFloor("infinite", 50) == false)
    assert(WorldManager.isFinalFloor("boss_rush", 50) == false)
    assert(WorldManager.isFinalFloor("survival", 50) == false)
end

return T
