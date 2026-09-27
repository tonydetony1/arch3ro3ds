-- main.lua
-- Point d'entrée d'Arch3ro pour Nintendo 3DS (LÖVEPotion) & PC Desktop (LÖVE2D)

-- Chronométrage du démarrage (écrit dans boot_profile.txt du dossier de sauvegarde)
local Boot = require("src.core.boot_profile")
local bootMark = Boot.mark

local Config = require("src.data.config")
local Screen = require("src.core.screen")
local StateMachine = require("src.core.statemachine")
local Save = require("src.data.save")
bootMark("src.data.save")
local Audio = require("src.audio.audio")
bootMark("src.audio.audio")
local MenuState = require("src.states.menu")
bootMark("src.states.menu")
local GameState = require("src.states.game")
bootMark("src.states.game")
local PauseState = require("src.states.pause")
local GameOverState = require("src.states.gameover")
local Gpu = require("src.core.gpu")
local Perf = require("src.core.perf")

-- Boucle 3DS : écran tactile redessiné une image sur deux (voir src/core/runloop.lua)
if Gpu.is3DS and love.graphics.getScreens then
    love.run = require("src.core.runloop").run
end

bootMark("modules chargés")

local gameStateMachine
local isTestMode = false
local testFrames = 0
local showGpuStats = false
local benchMode = false
local Bench = nil

function love.load(arg)
    -- Graine aléatoire
    math.randomseed(os.time())

    -- Chargement ou initialisation des données de sauvegarde
    Save.load()
    Save.updateEnergyRegen()
    bootMark("sauvegarde lue")

    -- Détection des drapeaux CLI
    if arg then
        for _, a in ipairs(arg) do
            if a == "--test" then isTestMode = true end
            -- Banc d'essai PC avec les contraintes GPU de la 3DS (budget de sommets, lots ordonnés)
            if a == "--sim3ds" then Gpu.simulate3DS(); showGpuStats = true end
            if a == "--gpustats" then showGpuStats = true end
            if a == "--profile" then Gpu.profile = {} end
            if a == "--bench" then benchMode = true end
        end
    end

    Perf.init(arg)

    -- Garde-fou du tampon de sommets PICA200 (écran noir en combat, voir src/core/gpu.lua)
    Gpu.install()

    -- Rendu net (nearest) optimisé pour l'écran 3DS et les performances GPU PICA200
    love.graphics.setDefaultFilter("nearest", "nearest")

    -- Construction de l'atlas pixel art (sprites, décor, icônes, police) : une seule fois
    require("src.render.art").init()
    bootMark("atlas graphique")

    -- Réglages de la page Paramètres (relief 3D, particules, dégâts affichés)
    Save.applySettings()

    -- Bande-son : effets et musiques (silencieux si les fichiers manquent)
    Audio.init()
    local sData = Save.get()
    if sData.audio then
        Audio.setMusicVolume(sData.audio.music or 0.55)
        Audio.setSfxVolume(sData.audio.sfx or 0.85)
    end
    Audio.playMusic("hub")
    bootMark("audio")

    -- Initialisation de la Machine d'États
    gameStateMachine = StateMachine.new()
    gameStateMachine:add("menu", MenuState.new(gameStateMachine))
    gameStateMachine:add("game", GameState.new(gameStateMachine))
    gameStateMachine:add("pause", PauseState.new(gameStateMachine))
    gameStateMachine:add("gameover", GameOverState.new(gameStateMachine))

    -- Par défaut : Lancement sur le Hub / Menu Principal
    gameStateMachine:switch("menu")
    bootMark("menu prêt")
    Boot.save()

    if benchMode then
        Bench = require("src.dev.bench")
        Bench.parse(arg)
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
    -- Une image = tous les écrans : le budget repart à zéro avant le premier écran
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
    if showGpuStats and (screen == nil or screen == "bottom") then
        local st = Gpu.stats
        love.graphics.origin()
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle("fill", 0, 0, 250, 12)
        love.graphics.setColor(st.skipped > 0 and 1 or 0.6, 1, 0.6, 1)
        love.graphics.print(string.format("GPU %d/%d sommets  %d appels  %d rejets  pic %d  %d FPS",
            st.vertices, Gpu.VERTEX_CAPACITY, st.calls, st.skipped, st.peak, love.timer.getFPS()), 2, 0)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function love.keypressed(key)
    if key == "f3" then showGpuStats = not showGpuStats return end
    if key == "escape" then
        if gameStateMachine.current == gameStateMachine.states["menu"] then
            love.event.quit()
            return
        end
    end

    gameStateMachine:keypressed(key)
end

-- Gestion du tactile sur Nintendo 3DS (LÖVEPotion)
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

-- Émulation du tactile avec la souris sur PC Desktop
function love.mousepressed(x, y, button)
    if button == 1 then
        local localX, localY = Screen.normalizeTouch(x, y)
        if localX and localY then
            gameStateMachine:touchpressed(1, localX, localY)
        end
    end
end

function love.mousemoved(x, y, dx, dy)
    if love.mouse and love.mouse.isDown(1) then
        local localX, localY = Screen.normalizeTouch(x, y)
        if localX and localY then
            gameStateMachine:touchmoved(1, localX, localY, dx, dy)
        end
    end
end

function love.mousereleased(x, y, button)
    if button == 1 then
        local localX, localY = Screen.normalizeTouch(x, y)
        if localX and localY then
            gameStateMachine:touchreleased(1, localX, localY)
        end
    end
end

-- Entrées analogiques du Circle Pad 3DS
function love.gamepadaxis(joystick, axis, value)
    gameStateMachine:gamepadaxis(joystick, axis, value)
end

-- Boutons physiques de la console 3DS (A, B, X, Y, D-Pad, Gâchettes)
function love.gamepadpressed(joystick, button)
    gameStateMachine:gamepadpressed(joystick, button)
end

-- Gestionnaire d'erreur robuste : affiche l'erreur à l'écran au lieu de fermer la fenêtre
function love.errorhandler(msg)
    local errText = tostring(msg) .. "\n\n" .. debug.traceback()
    print("FATAL ERROR:\n" .. errText)

    pcall(function()
        local f = io.open("error_log.txt", "w")
        if f then f:write(errText); f:close() end
    end)
    pcall(function()
        love.filesystem.write("error_log.txt", errText)
    end)

    while true do
        if love.event then
            love.event.pump()
            for name, a in love.event.poll() do
                if name == "quit" then return end
            end
        end

        if love.graphics and love.graphics.isActive() then
            love.graphics.origin()
            love.graphics.setScissor()
            local setScreen = love.graphics.setActiveScreen or love.graphics.setScreen
            if setScreen then
                setScreen("top")
                love.graphics.clear(0.25, 0.05, 0.05)
                love.graphics.setColor(1, 1, 1)
                love.graphics.printf("ARCH3RO ERREUR :\n" .. tostring(msg), 10, 10, 380)

                setScreen("bottom")
                love.graphics.clear(0.12, 0.02, 0.02)
                love.graphics.setColor(1, 0.8, 0.8)
                love.graphics.printf(debug.traceback(), 10, 10, 300)
            else
                love.graphics.clear(0.25, 0.05, 0.05)
                love.graphics.setColor(1, 1, 1)
                love.graphics.printf("ARCH3RO ERREUR :\n" .. errText, 10, 10, 380)
            end
            love.graphics.present()
        end

        if love.timer then
            love.timer.sleep(0.05)
        end
    end
end


