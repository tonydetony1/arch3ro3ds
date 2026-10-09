-- tests/test_stage_label.lua
-- The "/ 50" floor counter only makes sense in the 50-floor Ascension run: the Abyss is endless
-- and nothing stops the run at floor 50, so it used to show "STAGE 57 / 50".

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

return T
