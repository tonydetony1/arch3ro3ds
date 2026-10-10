-- tests/test_new_run.lua
-- GameState is a singleton: "retry" calls enter() on the same table, so a new run must not
-- inherit anything from the previous one.

local VFX = require("src.render.vfx_manager")
local Audio = require("src.audio.audio")
local GameState = require("src.states.game")

-- Runs `fn` with LOVE stubbed well enough for GameState:enter (any method is a no-op, sizes are
-- numbers), then puts the previous stubs back. Modules keep `local g = love.graphics` from
-- whichever test loaded them first, so the existing tables are patched in place, not replaced.
local function withLoveStubs(fn)
    local stub
    stub = setmetatable({}, { __index = function(_, k)
        if k == "getWidth" or k == "getHeight" or k == "getDimensions" then
            return function() return 64, 64 end
        end
        return function() return stub end
    end })
    local anyMethod = { __index = function() return function() return stub end end }

    love.graphics, love.audio = love.graphics or {}, love.audio or {}
    love.image, love.filesystem = love.image or {}, love.filesystem or {}
    love.timer = love.timer or {}
    local savedMt = { graphics = getmetatable(love.graphics), audio = getmetatable(love.audio) }
    local savedFn = {
        newImageData = love.image.newImageData, write = love.filesystem.write,
        read = love.filesystem.read, getInfo = love.filesystem.getInfo, getTime = love.timer.getTime,
    }
    local savedAtlas, savedAudio = VFX.buildTextureAtlas, Audio.enabled
    -- Earlier test files also set raw fields (e.g. newImage returning {}): hide them too
    local savedRaw = {}
    for _, t in ipairs({ love.graphics, love.audio }) do
        savedRaw[t] = {}
        for k, v in pairs(t) do savedRaw[t][k] = v end
        for k in pairs(savedRaw[t]) do t[k] = nil end
    end
    setmetatable(love.graphics, anyMethod)
    setmetatable(love.audio, anyMethod)
    love.image.newImageData = function() return stub end
    love.filesystem.write = function() return true end
    love.filesystem.read = function() return nil end
    love.filesystem.getInfo = function() return nil end
    love.timer.getTime = function() return 0 end
    VFX.buildTextureAtlas = function() end
    Audio.enabled = false

    local ok, err = xpcall(fn, debug.traceback)

    setmetatable(love.graphics, savedMt.graphics)
    setmetatable(love.audio, savedMt.audio)
    for t, fields in pairs(savedRaw) do
        for k, v in pairs(fields) do t[k] = v end
    end
    love.image.newImageData = savedFn.newImageData
    love.filesystem.write, love.filesystem.read = savedFn.write, savedFn.read
    love.filesystem.getInfo, love.timer.getTime = savedFn.getInfo, savedFn.getTime
    VFX.buildTextureAtlas, Audio.enabled = savedAtlas, savedAudio
    assert(ok, err)
end

local function singleton()
    return setmetatable({ sm = { switch = function() end } }, { __index = GameState })
end

local T = {}

T["a new run does not inherit the previous run's synergies"] = function()
    withLoveStubs(function()
        local g = singleton()
        -- Skills drafted in the run that just ended (fire + poison = Toxic Flame)
        g.acquiredSkills = { { id = "fire_element" }, { id = "poison_element" } }
        g:enter({ mode = "ascension" })
        assert(not g.player.hasSynergyToxicFlame, "Toxic Flame leaked into the new run")
        assert(not (g.player.activeSynergies or {}).toxic_flame, "the leaked synergy is marked active")
    end)
end

return T
