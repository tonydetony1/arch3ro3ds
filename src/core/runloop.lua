-- src/core/runloop.lua
-- 3DS main loop (replaces LÖVE Potion's love.run, same event logic).
--
-- Difference: the touch screen is only redrawn one frame in BOTTOM_EVERY (3), unless it was
-- touched, a button was pressed or a state requires it (Screen.bottomDirty). A screen that is
-- not redrawn simply keeps its previous image (citro3d only transfers the targets drawn on),
-- which frees the CPU for the top screen where the action happens.

local Screen = require("src.core.screen")
local Depth = require("src.render.depth")
local Perf = require("src.core.perf")

-- LÖVE Potion turns stereo on at boot (gfxSet3D(true)): the top screen is then rendered twice per
-- frame (left eye + right eye) even with the 3D slider at zero. Stereo is only kept while the
-- slider is up and depth is not disabled in the Settings.
local stereoOn = nil
local function updateStereo()
    if not love.graphics.set3D then return end
    local want = Depth.slider() > 0.01 and (Depth.userScale or 1) > 0
    if want ~= stereoOn then
        love.graphics.set3D(want)
        stereoOn = want
    end
end

-- Events that do not change anything on the touch screen: the Circle Pad sends one per frame
-- while the hero moves, which used to force a full touch-screen redraw on every frame
local NO_BOTTOM_REDRAW = { gamepadaxis = true, joystickaxis = true }

-- End of frame: the loop must give the CPU away, or another thread on the game core never runs
-- (without any sleep the game froze in Azahar). A 1 ms sleep costs a full millisecond, so it is
-- only taken when the frame left that much room before the vertical sync; otherwise
-- love.timer.sleep(0) (svcSleepThread(0)) just yields to the other threads.
local IDLE_SLEEP = 0.001
local ROOMY_FRAME = 0.012 -- seconds of work under which the 1 ms sleep still fits in the frame

-- Periodic touch-screen refresh: due every BOTTOM_EVERY frames, it waits for a frame light enough
-- to take it (the previous frame's CPU work plus the average touch-screen draw must fit before the
-- vertical sync), and never waits beyond BOTTOM_MAX frames. Touches and buttons still redraw at once.
local FRAME_BUDGET = 0.0155 -- seconds of CPU work that fit in a 60 Hz frame with present() margin
local BOTTOM_COST_SMOOTHING = 0.2

local RunLoop = {
    BOTTOM_EVERY = 3,
    BOTTOM_MAX = 6,
    lastBusy = nil, -- seconds of CPU work of the last frame, without the wait for the vertical sync
    bottomCost = 0, -- running average of a touch-screen draw (seconds)
    syncTime = nil, -- when the last frame came out of its wait for the vertical sync
    frame = 0, -- number of the frame being computed
    bottomThisFrame = false, -- this frame will redraw the touch screen (decided before the update)
}

local sinceBottom = 0
local function wantBottom(frame)
    if Screen.bottomDirty or Screen.bottomAlways or frame < 4 then return true end
    sinceBottom = sinceBottom + 1
    if sinceBottom < RunLoop.BOTTOM_EVERY then return false end
    if sinceBottom >= RunLoop.BOTTOM_MAX then return true end
    return (RunLoop.lastBusy or 0) + RunLoop.bottomCost <= FRAME_BUDGET
end

function RunLoop.run()
    if love.load then
        love.load(love.parsedGameArguments, love.rawGameArguments)
    end

    for _, j in ipairs(love.joystick.getJoysticks()) do
        love.handlers.joystickadded(j)
    end

    if love.timer then love.timer.step() end

    local delta = 0
    local frame = 0
    local now = love.timer.getTime
    local prevStart = nil -- start of the previous frame (Perf: frame period)

    return function()
        if love.window and g_windowShown then
            return
        end
        local frameStart = now()
        if Perf.enabled and RunLoop.frameEnd then Perf.add("L:outside", frameStart - RunLoop.frameEnd) end

        if love.event and love.event.pump then
            love.event.pump()
            for name, a, b, c, d, e, f in love.event.poll() do
                if name == "quit" then
                    if not love.quit or not love.quit() then
                        if love.audio then love.audio.stop() end
                        return a or 0
                    end
                end
                love.handlers[name](a, b, c, d, e, f)
                -- Any interaction refreshes the touch screen on the next frame
                if not NO_BOTTOM_REDRAW[name] then Screen.bottomDirty = true end
            end
        end

        -- Decided before the update, so the update can prepare the touch screen (src/ui/hud.lua)
        local drawBottom = wantBottom(frame + 1)
        RunLoop.frame, RunLoop.bottomThisFrame = frame + 1, drawBottom

        local tUpdate = now()
        if love.timer then delta = love.timer.step() end
        if love.update then love.update(delta) end
        if Perf.enabled then Perf.add("L:update", now() - tUpdate) end

        if love.graphics and love.graphics.isActive() then
            updateStereo()
            frame = frame + 1
            local syncWait = 0
            for i, screen in ipairs(love.graphics.getScreens()) do
                if screen ~= "bottom" or drawBottom then
                    local tScreen = now()
                    love.graphics.origin()
                    love.graphics.setActiveScreen(screen)
                    love.graphics.clear(love.graphics.getBackgroundColor())
                    -- The wait for the previous frame (vertical sync) happens in the first bind
                    local tDraw = now()
                    if i == 1 then
                        syncWait = tDraw - tScreen
                        RunLoop.syncTime = tDraw -- the frame starts drawing right after the vertical sync
                    end
                    if Perf.enabled then Perf.add("L:bind-" .. screen, tDraw - tScreen) end
                    if love.draw then love.draw(screen) end
                    if screen == "bottom" then
                        local cost = now() - tDraw
                        RunLoop.bottomCost = RunLoop.bottomCost + (cost - RunLoop.bottomCost) * BOTTOM_COST_SMOOTHING
                    end
                end
            end
            if drawBottom then
                Screen.bottomDirty = false
                sinceBottom = 0
            end
            local tp = now()
            -- CPU work of the frame up to present(), without the wait for the vertical sync
            RunLoop.lastBusy = tp - frameStart - syncWait
            love.graphics.present()
            Perf.add("present", now() - tp)
            Perf.endFrame(RunLoop.lastBusy, drawBottom, prevStart and (frameStart - prevStart), syncWait)
            prevStart = frameStart
        end

        if love.timer then
            local busy = RunLoop.lastBusy
            local tSleep = now()
            love.timer.sleep((busy and busy < ROOMY_FRAME) and IDLE_SLEEP or 0)
            if Perf.enabled then
                RunLoop.frameEnd = now()
                Perf.add("L:sleep", RunLoop.frameEnd - tSleep)
            end
        end
    end
end

return RunLoop
