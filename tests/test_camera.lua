-- tests/test_camera.lua
-- Past the arena border, the camera only shows open sky in worlds drawn as floating
-- islands. Elsewhere (desert, crystal, inferno, void) the plain sky gradient read as an
-- empty void around the room.
local WorldManager = require("src.core.world_manager")
local Camera = require("src.core.camera")

local T = {}

T["sky margin: grounded worlds never show the sky past their border"] = function()
    for _, world in ipairs({ 2, 3, 4, 6 }) do
        assert(WorldManager.skyMargin(world) == 0, "world " .. world)
    end
end

T["sky margin: floating worlds keep their open sky"] = function()
    for _, world in ipairs({ 1, 5 }) do
        assert(WorldManager.skyMargin(world) > 0, "world " .. world)
    end
end

T["camera: with no margin the view stays inside the room"] = function()
    local cam = Camera.new()
    cam:setBounds(640, 480, 0)
    cam:setPosition(-200, -200)
    assert(cam.x - cam.halfW >= 0 and cam.y - cam.halfH >= 0)
    cam:setPosition(2000, 2000)
    assert(cam.x + cam.halfW <= 640 and cam.y + cam.halfH <= 480)
end

return T
