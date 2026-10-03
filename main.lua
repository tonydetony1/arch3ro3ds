-- main.lua
-- Point d'entrée d'Arch3ro pour Nintendo 3DS (LÖVEPotion) & PC Desktop (LÖVE2D)

-- Paquet 3DS : tous les modules sont regroupés dans « modules.bin » (tools/build_all.py).
-- Une seule lecture au démarrage au lieu d'une recherche de fichier par module dans
-- l'archive (~50 ms chacune sur Old 3DS, soit ~3 s pour la soixantaine de modules).
-- Absent sur PC : require charge alors les fichiers .lua normalement.
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
        -- Après le démarrage : on rend la mémoire du paquet (~1,3 Mo) ; les rares require
        -- tardifs repassent par les fichiers individuels, toujours présents dans l'archive
        releaseModuleBundle = function()
            index, blob = nil, nil
            for i, loader in ipairs(package.loaders) do
                if loader == bundleLoader then table.remove(package.loaders, i) break end
            end
        end
    end
end

-- Chronométrage du démarrage (écrit dans boot_profile.txt du dossier de sauvegarde)
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

-- Boucle 3DS : écran tactile redessiné une image sur deux (voir src/core/runloop.lua)
if Gpu.is3DS and love.graphics.getScreens then
    love.run = require("src.core.runloop").run
end

bootMark("modules chargés")

local gameStateMachine
local isTestMode = false
local testFrames = 0
local showGpuStats = false
local GPU_STATS_REFRESH = 0.25
local gpuStatsNextRefresh = 0
local gpuStatsText = ""
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
    if releaseModuleBundle then releaseModuleBundle() end

    -- Sur console, pas d'arguments : le fichier "bench_roomload" du dossier de sauvegarde
    -- déclenche la mesure des temps de construction de salle (résultat dans bench_log.txt)
    local roomloadFlag = love.filesystem.getInfo and love.filesystem.getInfo("bench_roomload") ~= nil
    local playFlag = love.filesystem.getInfo and love.filesystem.getInfo("bench_play") ~= nil
    if benchMode or roomloadFlag or playFlag then
        -- src/dev n'est embarqué dans le paquet 3DS qu'avec `build_all.py --with-bench`
        local ok, mod = pcall(require, "src.dev.bench")
        Bench = ok and mod or nil
    end
    if Bench then
        Bench.parse(arg)
        if roomloadFlag then Bench.active, Bench.roomload = true, true end
        if playFlag then
            -- Contenu du fichier (facultatif) : numéro de la salle à jouer
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
        -- Texte reconstruit 4 fois par seconde : une chaîne neuve à chaque image allouait
        -- une mise en page de police par image (pression GC visible sur la console)
        local now = love.timer.getTime()
        if now >= gpuStatsNextRefresh then
            gpuStatsNextRefresh = now + GPU_STATS_REFRESH
            gpuStatsText = string.format("%d FPS  %d sommets  %d appels  %d rejets",
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
    -- SELECT : affiche / masque les performances (FPS, sommets, appels GPU) sur la console
    if button == "back" then
        showGpuStats = not showGpuStats
        return
    end
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

    -- Autotest et banc d'essai (lancés sans écran, ex. intégration continue) : on quitte
    -- avec un code d'erreur au lieu d'attendre devant l'écran d'erreur
    if isTestMode or benchMode then
        os.exit(1)
    end

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


