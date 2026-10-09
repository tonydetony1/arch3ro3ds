-- tests/test_vfx_shake.lua
-- Kill feedback: a pack dying together must not turn into a rolling earthquake or a chain of
-- freeze frames, and the shake offset must stay on whole pixels (a fractional translate
-- blurs the pixel art and exposes thin background bars at the screen edges).

love = love or {}
love.timer = love.timer or { getTime = function() return 0 end }
love.filesystem = love.filesystem or { write = function() return true end, read = function() return nil end }

local VFX = require("src.render.vfx_manager")

local function reset()
    VFX.shakeTimer, VFX.shakeDuration, VFX.shakeIntensity = 0, 0, 0
    VFX.shakeOffsetX, VFX.shakeOffsetY = 0, 0
    VFX.hitStopTimer = 0
end

local T = {}

T["shake offset is always a whole number of pixels"] = function()
    reset()
    math.randomseed(7)
    VFX.shakeHeavy()
    for _ = 1, 30 do
        VFX.update(1 / 60)
        local ox, oy = VFX.getShakeOffset()
        assert(ox == math.floor(ox), "fractional X offset " .. ox)
        assert(oy == math.floor(oy), "fractional Y offset " .. oy)
    end
end

T["regular kill gives a micro shake and no freeze frame"] = function()
    reset()
    VFX.onKill(false)
    assert(VFX.shakeIntensity > 0 and VFX.shakeIntensity <= 3.0, "kill shake " .. VFX.shakeIntensity)
    assert(VFX.hitStopTimer == 0, "regular kill must not freeze the game")
end

T["a pack of kills does not restart a running shake"] = function()
    reset()
    VFX.onKill(false)
    VFX.update(0.04)
    local left = VFX.shakeTimer
    VFX.onKill(false)
    VFX.onKill(false)
    assert(VFX.shakeTimer == left, "shake timer restarted: " .. VFX.shakeTimer .. " vs " .. left)
end

T["a regular kill never downgrades or extends a heavier shake"] = function()
    reset()
    VFX.shakeHeavy()
    local intensity, timer = VFX.shakeIntensity, VFX.shakeTimer
    VFX.onKill(false)
    assert(VFX.shakeIntensity == intensity and VFX.shakeTimer == timer)
end

T["boss kill keeps the heavy shake and the freeze frame"] = function()
    reset()
    VFX.onKill(true)
    assert(VFX.shakeIntensity >= 9.0, "boss shake " .. VFX.shakeIntensity)
    assert(VFX.hitStopTimer >= 0.1, "boss freeze " .. VFX.hitStopTimer)
end

return T
