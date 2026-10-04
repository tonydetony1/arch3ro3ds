-- main.lua
-- Entry point for Arch3ro on Nintendo 3DS (LÖVE-Potion) & Desktop PC (LÖVE2D)

-- 3DS package: all modules are bundled in "modules.bin" (tools/build_all.py).
-- A single read at boot instead of per-module file lookups in the archive
-- (~50 ms each on Old 3DS, taking ~3 s for ~60 modules).
-- Absent on PC: require loads .lua files normally.
local releaseModuleBundle
local bundleReadTime = nil
do
    local t0 = love.timer.getTime()
    local okRead, blob = pcall(love.filesystem.read, "modules.bin")
    bundleReadTime = love.timer.getTime() - t0
    if okRead and type(blob) == "string" and blob:sub(1, 4) == "A3MB" then
        local index, pos, byte = {}, 5, string.byte
        while pos <= #blob do
            local nameLen = byte(blob, pos) * 256 + byte(blob, pos + 1)
            local name = blob:sub(pos + 2, pos + 1 + nameLen)
            pos = pos + 2 + nameLen
            local b1, b2, b3, b4 = byte(blob, pos, pos + 3)
            local len = ((b1 * 256 + b2) * 256 + b3) * 256 + b4
            index[name] = { pos + 4, len }
            pos = pos + 4 + len
        end
        local function bundleLoader(name)
            local entry = index and index[name]
            if not entry then return nil end
            local chunk, err = loadstring(blob:sub(entry[1], entry[1] + entry[2] - 1),
                "@" .. name:gsub("%.", "/") .. ".lua")
            if not chunk then error(err, 2) end
            return chunk
        end
        table.insert(package.loaders, 2, bundleLoader)
        -- After boot: free the bundle memory (~1.3 MB); rare late requires
        -- fall back to individual files still present in the archive
        releaseModuleBundle = function()
            index, blob = nil, nil
            for i, loader in ipairs(package.loaders) do
                if loader == bundleLoader then table.remove(package.loaders, i) break end
            end
        end
    end
end

-- Boot timing (written to boot_profile.txt in the save directory)
local Boot = require("src.core.boot_profile")
local bootMark = Boot.mark
if bundleReadTime then
    Boot.marks[#Boot.marks + 1] = string.format("%-28s %7.3f s  (avant le chrono)", "lecture de modules.bin", bundleReadTime)
end

local Config = require("src.data.config")
local Screen = require("src.core.screen")
local StateMachine = require("src.core.statemachine")
local Save = require("src.data.save")
bootMark("src.data.save")
local Audio = require("src.audio.audio")
bootMark("src.audio.audio")
local SplashState = require("src.states.splash")
local MenuState = require("src.states.menu")
bootMark("src.states.menu")
local GameState = require("src.states.game")
bootMark("src.states.game")
local PauseState = require("src.states.pause")
local GameOverState = require("src.states.gameover")
local Gpu = require("src.core.gpu")
local Perf = require("src.core.perf")
local PixelFont = require("src.ui.pixel_font")
local Palette = require("src.render.palette")

-- 3DS loop: touch screen redrawn every other frame (see src/core/runloop.lua)
if Gpu.is3DS and love.graphics.getScreens then
    love.run = require("src.core.runloop").run
end

bootMark("modules loaded")

local gameStateMachine
local isTestMode = false
local testFrames = 0
local GPU_STATS_REFRESH = 0.25
local gpuStatsNextRefresh = 0
local gpuStatsText = ""
local benchMode = false
local Bench = nil

function love.load(arg)
    -- Random seed
    math.randomseed(os.time())

    -- Load or initialize save data
    Save.load()
    Save.updateEnergyRegen()
    bootMark("save loaded")

    -- Detect CLI flags
    if arg then
        for _, a in ipairs(arg) do
            if a == "--test" then isTestMode = true end
            -- PC test bench with 3DS GPU constraints (vertex budget, ordered batches)
            if a == "--sim3ds" then Gpu.simulate3DS(); Config.SHOW_GPU_STATS = true end
            if a == "--gpustats" then Config.SHOW_GPU_STATS = true end
            if a == "--profile" then Gpu.profile = {} end
            if a == "--bench" then benchMode = true end
        end
    end

    Perf.init(arg)

    -- PICA200 vertex buffer safeguard (prevents black screen in combat, see src/core/gpu.lua)
    Gpu.install()

    -- Crisp rendering (nearest) optimized for 3DS screen and PICA200 GPU performance
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Build pixel art atlas (sprites, scenery, icons, font): runs once
    require("src.render.art").init()
    bootMark("graphics atlas")

    -- Settings page configuration (3D depth, particles, floating damage numbers)
    Save.applySettings()

    -- Audio soundtrack: effects and music (silent if files are missing)
    Audio.init()
    local sData = Save.get()
    if sData.audio then
        Audio.setMusicVolume(sData.audio.music or 0.55)
        Audio.setSfxVolume(sData.audio.sfx or 0.85)
    end
    Audio.playMusic("hub")
    bootMark("audio")

    -- State Machine initialization
    gameStateMachine = StateMachine.new()
    gameStateMachine:add("splash", SplashState.new(gameStateMachine))
    gameStateMachine:add("menu", MenuState.new(gameStateMachine))
    gameStateMachine:add("game", GameState.new(gameStateMachine))
    gameStateMachine:add("pause", PauseState.new(gameStateMachine))
    gameStateMachine:add("gameover", GameOverState.new(gameStateMachine))

    -- Official splash title screen with logo (selftest advances it, src/dev/selftest.lua)
    gameStateMachine:switch("splash")
    bootMark("menu ready")
    Boot.save()
    if releaseModuleBundle then releaseModuleBundle() end

    -- On console, no CLI arguments: "bench_roomload" file in save directory
    -- triggers room generation timing benchmark (output in bench_log.txt)
    local roomloadFlag = love.filesystem.getInfo and love.filesystem.getInfo("bench_roomload") ~= nil
    local playFlag = love.filesystem.getInfo and love.filesystem.getInfo("bench_play") ~= nil
    if benchMode or roomloadFlag or playFlag then
        -- src/dev is only bundled in the 3DS package with `build_all.py --with-bench`
        local ok, mod = pcall(require, "src.dev.bench")
        Bench = ok and mod or nil
    end
    if Bench then
        Bench.parse(arg)
        if roomloadFlag then Bench.active, Bench.roomload = true, true end
        if playFlag then
            -- Optional file content: room number to play
            Bench.active, Bench.duration = true, 30
            local spec = love.filesystem.read("bench_play") or ""
            Bench.room = tonumber(spec:match("%d+")) or Bench.room
            Bench.menu = spec:find("menu", 1, true) ~= nil
        end
        if love.filesystem.getInfo("bench_lprof") then Bench.lprof = {} end
        if love.filesystem.getInfo("bench_alloc") then Bench.alloc = {} end
        Bench.start(gameStateMachine)
    end

    if isTestMode then
        print("[TEST] Arch3ro Meta-Game booted successfully!")
        print("[TEST] Hub Menu + Forge + Game + Pause + GameOver States registered.")
    end
end

function love.update(dt)
    local safeDt = math.min(dt, 0.1)
    if Perf.enabled then Perf.begin() end
    Audio.update(safeDt)
    gameStateMachine:update(safeDt)
    if Perf.enabled then
        Perf.stop("update")
        local name = "?"
        for k, v in pairs(gameStateMachine.states) do
            if v == gameStateMachine.current then name = k end
        end
        Perf.frame(dt, name)
    end
    if Bench then Bench.update(safeDt) end

    if isTestMode then
        testFrames = testFrames + 1
        require("src.dev.selftest").update(gameStateMachine, testFrames)
    end
end

function love.draw(screen)
    -- One frame = all screens: budget resets to zero before the first screen
    if screen == nil or screen == "top" or screen == "left" then
        Gpu.beginFrame()
    end
    Screen.render(
        function(eye)
            if Perf.enabled then Perf.begin() end
            gameStateMachine:drawTop(eye)
            if Perf.enabled then Perf.stop("top") end
        end,
        function()
            if Perf.enabled then Perf.begin() end
            gameStateMachine:drawBottom()
            if Perf.enabled then Perf.stop("bottom") end
        end,
        screen
    )
    if Config.SHOW_GPU_STATS and (screen == nil or screen == "bottom") then
        local st = Gpu.stats
        -- Text rebuilt 4 times per second: a fresh string every frame would allocate
        -- font layout memory on every frame (visible GC pressure on console)
        local now = love.timer.getTime()
        if now >= gpuStatsNextRefresh then
            gpuStatsNextRefresh = now + GPU_STATS_REFRESH
            gpuStatsText = string.format("%d FPS  %d vertices  %d calls  %d skipped",
                love.timer.getFPS(), st.vertices, st.calls, st.skipped)
        end
        love.graphics.origin()
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, 250, 12)
        love.graphics.setColor(st.skipped > 0 and 1 or 0.6, 1, 0.6, 1)
        PixelFont.print(gpuStatsText, 2, 2, Palette.C.white, "tiny")
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function love.keypressed(key)
    if key == "f3" then Config.SHOW_GPU_STATS = not Config.SHOW_GPU_STATS return end
    if key == "escape" then
        local menu = gameStateMachine.states["menu"]
        if gameStateMachine.current == menu then
            -- Escape closes open UI first (item card, sub-page, tab)
            if not menu:goBack() then love.event.quit() end
            return
        end
    end

    gameStateMachine:keypressed(key)
end

-- Touch handling on Nintendo 3DS (LÖVE-Potion)
function love.touchpressed(id, x, y, dx, dy, pressure)
    local localX, localY = Screen.normalizeTouch(x, y)
    if localX and localY then
        gameStateMachine:touchpressed(id, localX, localY)
    end
end

function love.touchmoved(id, x, y, dx, dy, pressure)
    local localX, localY = Screen.normalizeTouch(x, y)
    if localX and localY then
        gameStateMachine:touchmoved(id, localX, localY, dx, dy)
    end
end

function love.touchreleased(id, x, y, dx, dy, pressure)
    local localX, localY = Screen.normalizeTouch(x, y)
    if localX and localY then
        gameStateMachine:touchreleased(id, localX, localY)
    end
end

-- Mouse touch emulation on Desktop PC. On a touchscreen, LÖVE also sends
-- a mouse event (istouch): ignored since finger input is handled by love.touchpressed.
function love.mousepressed(x, y, button, istouch)
    if istouch then return end
    if button == 1 then
        local localX, localY = Screen.normalizeTouch(x, y)
        if localX and localY then
            gameStateMachine:touchpressed(1, localX, localY)
        end
    end
end

function love.mousemoved(x, y, dx, dy, istouch)
    if istouch then return end
    if love.mouse and love.mouse.isDown(1) then
        local localX, localY = Screen.normalizeTouch(x, y)
        if localX and localY then
            gameStateMachine:touchmoved(1, localX, localY, dx, dy)
        end
    end
end

function love.mousereleased(x, y, button, istouch)
    if istouch then return end
    if button == 1 then
        local localX, localY = Screen.normalizeTouch(x, y)
        if localX and localY then
            gameStateMachine:touchreleased(1, localX, localY)
        end
    end
end

-- Analog inputs from 3DS Circle Pad
function love.gamepadaxis(joystick, axis, value)
    gameStateMachine:gamepadaxis(joystick, axis, value)
end

-- Physical buttons on 3DS console (A, B, X, Y, D-Pad, Shoulder triggers)
function love.gamepadpressed(joystick, button)
    -- SELECT: toggles performance stats (FPS, vertices, GPU calls) on console
    if button == "back" then
        Config.SHOW_GPU_STATS = not Config.SHOW_GPU_STATS
        return
    end
    gameStateMachine:gamepadpressed(joystick, button)
end

-- Robust error handler: renders error to screen instead of crashing the window.
-- Like in LÖVE 11, returns the error screen loop (one frame per call).
function love.errorhandler(msg)
    local trace = debug.traceback()
    local errText = tostring(msg) .. "\n\n" .. trace
    print("FATAL ERROR:\n" .. errText)

    pcall(function()
        local f = io.open("error_log.txt", "w")
        if f then f:write(errText); f:close() end
    end)
    pcall(function()
        love.filesystem.write("error_log.txt", errText)
    end)

    -- Self-test and benchmark (run headless, e.g. continuous integration): exit
    -- with error code instead of hanging on error screen
    if isTestMode or benchMode then
        os.exit(1)
    end

    -- Bounded text: vertex guard (src/core/gpu.lua) would reject overly long text
    local title = "ARCH3RO ERROR (START: quit):\n" .. tostring(msg):sub(1, 600)
    trace = trace:sub(1, 1200)

    local function draw()
        if not (love.graphics and love.graphics.isActive()) then return end
        -- Outside love.draw: reset vertex budget here, otherwise text disappears
        -- after several frames; an error during batch recording would leave it active
        Gpu.endRecord()
        Gpu.beginFrame()
        love.graphics.setScissor()
        -- LÖVE-Potion screens: "left" and "right" (top, per eye) then "bottom"; "top"
        -- does not exist and would crash this handler (game would exit to black screen)
        local screens = love.graphics.getScreens and love.graphics.getScreens()
        if screens then
            for _, screen in ipairs(screens) do
                love.graphics.origin()
                love.graphics.setActiveScreen(screen)
                if screen == "bottom" then
                    love.graphics.clear(0.12, 0.02, 0.02)
                    love.graphics.setColor(1, 0.8, 0.8)
                    love.graphics.printf(trace, 10, 10, 300)
                else
                    love.graphics.clear(0.25, 0.05, 0.05)
                    love.graphics.setColor(1, 1, 1)
                    love.graphics.printf(title, 10, 10, 380)
                end
            end
        else
            love.graphics.origin()
            love.graphics.clear(0.25, 0.05, 0.05)
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf("ARCH3RO ERREUR :\n" .. errText, 10, 10, 380)
        end
        love.graphics.present()
    end

    return function()
        if love.event then
            love.event.pump()
            for name, a, b in love.event.poll() do
                if name == "quit" or (name == "gamepadpressed" and b == "start") then return 1 end
            end
        end
        draw()
        if love.timer then
            love.timer.sleep(0.05)
        end
    end
end


