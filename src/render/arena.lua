-- src/render/arena.lua
-- Île flottante "Prairie" en pixel art 2.5D :
--   * ciel en couches (dégradé, îles lointaines, nuages) avec parallaxe et profondeur stéréo
--   * sol cuit dans un Canvas (1 draw call) : herbe, dalles, falaise, ombres portées
--   * murs (haies, arbres, porte) dans un SpriteBatch dessiné au-dessus du sol (1 draw call)
--   * atmosphère écran : vignettage et lumière chaude venant du haut-gauche

local Config = require("src.data.config")
local Art = require("src.render.art")
local Palette = require("src.render.palette")
local Depth = require("src.render.depth")
local WorldManager = require("src.core.world_manager")

local is3DS = (love._console == "3DS" or love._os == "3DS" or (love.graphics and love.graphics.setActiveScreen ~= nil))

local Arena = {}
Arena.__index = Arena

-- Marges du Canvas autour de la carte (arbres qui débordent, falaise sous l'île)
local PAD_X = 40
local PAD_TOP = 40
local PAD_BOTTOM = 64

local GATE_HALF_W = 40
local GROUND_TOP = 26
local WALL_BATCH_SIZE = 600

local DEFAULT_THEME = nil -- résolu au premier usage (évite un cycle de chargement)

local C = Palette.C

local function makeRng(seed)
    local s = seed % 4294967296
    return function()
        s = (s * 1664525 + 1013904223) % 4294967296
        return s / 4294967296
    end
end

function Arena.new()
    local self = setmetatable({}, Arena)
    self.gateAnim = 0
    self.canvas = nil
    self.canvasW = 0
    self.canvasH = 0
    self.skyStrip = nil
    self.vignette = nil
    self.wallBatch = nil
    self.theme = WorldManager.getTheme(1)
    self.themeId = 1

    local cloudNames = { "cloud_c", "cloud_a", "cloud_b", "cloud_a", "cloud_c", "cloud_b" }
    self.clouds = {}
    for i = 1, #cloudNames do
        self.clouds[i] = {
            name = cloudNames[i],
            x = math.random(-60, Config.TOP_WIDTH + 60),
            y = 14 + (i - 1) * 34 + math.random(-6, 6),
            speed = 5 + i * 1.6,
            parallax = 0.08 + i * 0.03,
        }
    end
    self.farIslands = {
        { name = "far_island_a", x = 70, y = 70, parallax = 0.03, bob = 0.0 },
        { name = "far_island_b", x = 300, y = 40, parallax = 0.02, bob = 1.7 },
        { name = "far_island_b", x = 380, y = 150, parallax = 0.04, bob = 3.1 },
    }
    return self
end

-- Change le décor (chapitre) : sol, ciel, murs et dangers
function Arena:setTheme(chapterIndex)
    local idx = chapterIndex or 1
    if self.themeId == idx and self.theme then return end
    self.themeId = idx
    self.theme = WorldManager.getTheme(idx)
    if self.skyStrip and self.skyStrip.release then pcall(function() self.skyStrip:release() end) end
    self.skyStrip = nil
    self.canvasW = 0 -- force la reconstruction du sol
end

function Arena:update(dt, isGateOpen)
    if isGateOpen then
        self.gateAnim = self.gateAnim + dt * 4
    else
        self.gateAnim = 0
    end
    for _, c in ipairs(self.clouds) do
        c.x = c.x + c.speed * dt
        if c.x > Config.TOP_WIDTH + 90 then
            c.x = -90
            c.y = 12 + math.random(0, 170)
        end
    end
end

-- ============================================================================
-- 1. CIEL EN COUCHES
-- ============================================================================
local function newCanvas(w, h)
    -- 3DS PICA200 max framebuffer : 512x512 ; refuser les Canvas trop grands
    if is3DS and (w > 512 or h > 512) then return nil end
    local ok, cv = pcall(love.graphics.newCanvas, w, h)
    if not ok or not cv then return nil end
    cv:setFilter("nearest", "nearest")
    return cv
end

local function buildSkyStrip(theme)
    local top = Palette.hex(theme and theme.skyTop or "4f9be8")
    local bottom = Palette.hex(theme and theme.skyBottom or "cdeeff")
    local steps = 60
    local prev = love.graphics.getCanvas()
    local strip = newCanvas(1, steps)
    love.graphics.setCanvas(strip)
    for i = 0, steps - 1 do
        local f = i / (steps - 1)
        love.graphics.setColor(
            top[1] + (bottom[1] - top[1]) * f,
            top[2] + (bottom[2] - top[2]) * f,
            top[3] + (bottom[3] - top[3]) * f, 1)
        love.graphics.rectangle("fill", 0, i, 1, 1)
    end
    love.graphics.setCanvas(prev)
    return strip
end

function Arena:drawSky(camX, camY)
    local w, h = Config.TOP_WIDTH, Config.TOP_HEIGHT
    local t = love.timer.getTime()
    if not self.skyStrip and love.graphics.newCanvas then self.skyStrip = buildSkyStrip(self.theme) end

    Depth.push(Depth.SKY)
    if self.skyStrip then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.skyStrip, -16, 0, 0, w + 32, h / 60)
    else
        Palette.set(Palette.hex(self.theme and self.theme.skyTop or "4f9be8"))
        love.graphics.rectangle("fill", -16, 0, w + 32, h)
    end
    Depth.pop()

    Depth.push(Depth.FAR)
    love.graphics.setColor(1, 1, 1, 0.85)
    for _, isl in ipairs(self.farIslands) do
        local px = ((isl.x - (camX or 0) * isl.parallax) % (w + 80)) - 40
        local py = isl.y - (camY or 0) * isl.parallax + math.floor(math.sin(t * 0.6 + isl.bob) * 2 + 0.5)
        Art.draw(isl.name, 1, px, py, false, false, self.theme and self.theme.variant)
    end
    Depth.pop()

    Depth.push(Depth.CLOUDS)
    love.graphics.setColor(1, 1, 1, 0.92)
    for _, c in ipairs(self.clouds) do
        local px = c.x - (camX or 0) * c.parallax
        local wrapped = ((px + 90) % (w + 180)) - 90
        local py = c.y - (camY or 0) * c.parallax * 0.5
        Art.draw(c.name, 1, wrapped, py)
    end
    Depth.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- ============================================================================
-- 2. SOL CUIT DANS UN SPRITEBATCH (1 SEUL DRAW CALL GPU POUR TOUT LE DÉCOR)
-- ============================================================================
local function addRect(batch, x, y, w, h, color, alpha)
    local f = Art.frame("fx_pixel", 1)
    if not f then return end
    batch:setColor(color[1], color[2], color[3], alpha or 1)
    batch:add(f.quad, math.floor(x), math.floor(y), 0, w, h, 0, 0)
end

local function addSprite(batch, name, frame, x, y, sx, sy, r, g, b, a)
    local f = Art.frame(name, frame or 1)
    if not f then return end
    batch:setColor(r or 1, g or 1, b or 1, a or 1)
    batch:add(f.quad, math.floor(x + 0.5), math.floor(y + 0.5), 0, sx or 1, sy or 1, f.ox, f.oy)
end

local function addSpriteV(batch, name, frame, x, y, variant)
    local f = Art.frame(name, frame or 1, false, variant)
    if not f then return end
    batch:setColor(1, 1, 1, 1)
    batch:add(f.quad, math.floor(x + 0.5), math.floor(y + 0.5), 0, 1, 1, f.ox, f.oy)
end

local function fillCliff(b, w, h, rng, theme)
    local top = h - 16
    for x = 12, w - 28, 16 do
        addSpriteV(b, "cliff", 1 + math.floor(rng() * 4), x, top, theme.variant)
        addSpriteV(b, "cliff", 1 + math.floor(rng() * 4), x, top + 20, theme.variant)
    end
    addSpriteV(b, "cliff", 1 + math.floor(rng() * 4), w - 28, top, theme.variant)
    addSpriteV(b, "cliff", 1 + math.floor(rng() * 4), w - 28, top + 20, theme.variant)
    for i = 0, 5 do
        addRect(b, 12, top + 22 + i * 5, w - 24, 5, C.night, 0.12 + i * 0.07)
    end
    for _ = 1, math.floor(w / 30) do
        addSprite(b, "root", 1, 16 + rng() * (w - 40), top + 44 + math.floor(rng() * 6))
    end
    addRect(b, 16, top - 1, w - 32, 2, Palette.hex(theme.edge))
    addRect(b, 16, top - 2, w - 32, 1, Palette.hex(theme.groundDark))
end

local function fillGround(b, w, h, theme, rng)
    addRect(b, 16, GROUND_TOP, w - 32, h - GROUND_TOP - 14, Palette.hex(theme.ground))
    local area = w * h
    for _ = 1, math.floor(area / 7000) do
        local name = (rng() < 0.55) and theme.patchLight or theme.patchDark
        addSpriteV(b, name, 1, 30 + rng() * (w - 60), 40 + rng() * (h - 70), theme.variant)
    end
    for _ = 1, math.floor(area / 60000) do
        addSpriteV(b, theme.patchExtra, 1, 40 + rng() * (w - 80), 60 + rng() * (h - 120), theme.variant)
    end
    local bands = 8
    local hazeH = math.floor((h - GROUND_TOP) * 0.45 / bands)
    for i = 0, bands - 1 do
        addRect(b, 16, GROUND_TOP + i * hazeH, w - 32, hazeH, C.cyan, 0.075 * (1 - i / bands))
    end
    local nearH = math.floor((h - GROUND_TOP) * 0.3 / bands)
    for i = 0, bands - 1 do
        addRect(b, 16, h - 16 - (i + 1) * nearH, w - 32, nearH, C.abyss, 0.09 * (1 - i / bands))
    end
    for i = 0, 4 do
        addRect(b, 16, GROUND_TOP + i * 18, (w - 32) * (1 - i / 5), 18, C.yellow, 0.035)
        addRect(b, 16 + (w - 32) * (i / 5), h - 16 - (i + 1) * 18, (w - 32) * (1 - i / 5), 18, C.navy, 0.035)
    end
end

local function fillPlazas(b, w, h, theme)
    local function plaza(cx, cy, cols, rows, seed)
        local rng = makeRng(seed)
        for r = 0, rows - 1 do
            local inset = (r == 0 or r == rows - 1) and 1 or 0
            for c = inset, cols - 1 - inset do
                addSpriteV(b, "slab", 1 + math.floor(rng() * 4), cx + (c - cols / 2) * 16, cy + r * 16, theme.variant)
            end
        end
    end
    plaza(math.floor(w / 2), GROUND_TOP + 2, 6, 2, 91)
    plaza(math.floor(w / 2), h - 64, 4, 3, 57)
end

local function fillDecals(b, w, h, rng, theme)
    local cx = w / 2
    local decals = theme.decals
    for _ = 1, math.floor(w * h / 2400) do
        local x = 26 + rng() * (w - 52)
        local y = 42 + rng() * (h - 70)
        local nearGate = math.abs(x - cx) < 52 and y < GROUND_TOP + 40
        local nearEntry = math.abs(x - cx) < 40 and y > h - 70
        if not nearGate and not nearEntry then
            addSprite(b, decals[1 + math.floor(rng() * #decals)], 1, x, y)
        end
    end
end

local function fillWallShadows(b, w, h)
    for i = 0, 3 do
        addRect(b, 16, GROUND_TOP + i * 3, w - 32, 3, C.abyss, 0.34 - i * 0.08)
        addRect(b, 16 + i * 3, GROUND_TOP, 3, h - GROUND_TOP - 16, C.abyss, 0.30 - i * 0.07)
    end
    addRect(b, w - 26, GROUND_TOP, 10, h - GROUND_TOP - 16, C.abyss, 0.12)
end

function Arena:buildGround(mapW, mapH, palette, obstacleManager)
    local w = mapW or Config.TOP_WIDTH
    local h = mapH or Config.TOP_HEIGHT
    if not Art.ready then Art.init() end

    self.obstacleManager = obstacleManager or self.obstacleManager
    self._groundW = w
    self._groundH = h
    self._groundTheme = self.theme or WorldManager.getTheme(1)

    if not self.groundBatch then
        self.groundBatch = love.graphics.newSpriteBatch(Art.image, 1400, "static")
    end
    self.canvas = self.groundBatch
    self.canvasW = w
    self.canvasH = h
    local b = self.groundBatch
    b:clear()

    local theme = self._groundTheme
    local rng = makeRng(w * 7 + h * 13)

    fillCliff(b, w, h, rng, theme)
    fillGround(b, w, h, theme, rng)
    fillPlazas(b, w, h, theme)
    fillDecals(b, w, h, rng, theme)
    fillWallShadows(b, w, h)

    b:setColor(1, 1, 1, 1)

    if self.obstacleManager and self.obstacleManager.bakeStatic then
        self.obstacleManager:bakeStatic()
    end
    if self.obstacleManager and self.obstacleManager.buildProps then
        self.obstacleManager:buildProps()
    end
    self:buildWalls(w, h, makeRng(w * 3 + h * 5), theme)
end

-- Rétrocompatibilité : buildCanvas pointe vers buildGround
function Arena:buildCanvas(mapW, mapH, palette, obstacleManager)
    self:buildGround(mapW, mapH, palette, obstacleManager)
end

-- ============================================================================
-- 3. MURS EN RELIEF (SpriteBatch)
-- ============================================================================
function Arena:buildWalls(w, h, rng, theme)
    theme = theme or self.theme or WorldManager.getTheme(1)
    if not self.wallBatch then
        self.wallBatch = love.graphics.newSpriteBatch(Art.image, WALL_BATCH_SIZE, "static")
    end
    local b = self.wallBatch
    b:clear()
    local cx = w / 2

    -- Arbres du fond (au-dessus de l'île, derrière la haie)
    for x = -8, w + 8, 26 do
        if math.abs(x - cx) > GATE_HALF_W + 10 then
            local name = (rng() < 0.5) and theme.wallTree or theme.wallTreeSmall
            addSpriteV(b, name, 1, x + rng() * 8 - 4, 10 + rng() * 4, theme.variant)
        end
    end
    -- Face avant de la haie (texture de feuillage)
    for x = -16, w + 16, 16 do
        if math.abs(x + 8 - cx) > GATE_HALF_W - 4 then
            addSpriteV(b, "hedge_front", 1 + math.floor(rng() * 2), x, 10, theme.variant)
        end
    end
    -- Crête de la haie
    for x = -6, w + 6, 12 do
        if math.abs(x - cx) > GATE_HALF_W - 2 then
            addSpriteV(b, (rng() < 0.6) and "bush_a" or "bush_b", 1, x + rng() * 4 - 2, 8 + rng() * 4, theme.variant)
        end
    end
    -- Murs latéraux (buissons + arbres extérieurs)
    for y = 22, h - 24, 11 do
        addSpriteV(b, (rng() < 0.6) and "bush_a" or "bush_b", 1, 7 + rng() * 3, y + rng() * 3, theme.variant)
        addSpriteV(b, (rng() < 0.6) and "bush_a" or "bush_b", 1, w - 8 - rng() * 3, y + rng() * 3, theme.variant)
    end
    for y = 40, h - 30, 42 do
        addSpriteV(b, theme.wallTreeSmall, 1, -10 + rng() * 4, y + rng() * 10, theme.variant)
        addSpriteV(b, theme.wallTreeSmall, 1, w + 10 - rng() * 4, y + 22 + rng() * 10, theme.variant)
    end
    addSpriteV(b, theme.wallTree, 1, 10, h - 12, theme.variant)
    addSpriteV(b, theme.wallTree, 1, w - 10, h - 12, theme.variant)
    -- Porte de pierre
    addSprite(b, "gate_arch", 1, math.floor(w / 2), 32)
    b:setColor(1, 1, 1, 1)
end

-- ============================================================================
-- 4. RENDU PAR FRAME (1 DRAW CALL SOL + 1 DRAW CALL MURS)
-- ============================================================================
function Arena:draw(isGateOpen, palette, spawnWarnings, mapW, mapH)
    local w = mapW or Config.TOP_WIDTH
    local h = mapH or Config.TOP_HEIGHT
    local t = love.timer.getTime()

    if not self.groundBatch or self._groundW ~= w or self._groundH ~= h or self._groundTheme ~= self.theme then
        self:buildGround(w, h, palette, self.obstacleManager)
    end

    love.graphics.setColor(1, 1, 1, 1)
    if self.groundBatch then
        love.graphics.draw(self.groundBatch)
    end

    if spawnWarnings and #spawnWarnings > 0 then
        local pulse = (math.sin(t * 12) + 1) * 0.5
        for _, sw in ipairs(spawnWarnings) do
            love.graphics.setColor(0.9, 0.2, 0.2, 0.35 + pulse * 0.25)
            Art.drawEx("fx_shadow", 1, sw.x, sw.y + 6, 0, (13 + pulse * 2) / 5, (6 + pulse) / 3, false)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- 5. ATMOSPHÈRE (espace écran) : vignettage léger optimisé
-- ============================================================================
local function drawVignetteDirect(w, h)
    local ink = C.ink
    love.graphics.setColor(ink[1], ink[2], ink[3], 0.16)
    love.graphics.rectangle("fill", 0, 0, w, 8)
    love.graphics.rectangle("fill", 0, h - 8, w, 8)
    love.graphics.rectangle("fill", 0, 0, 8, h)
    love.graphics.rectangle("fill", w - 8, 0, 8, h)
    love.graphics.setColor(1, 1, 1, 1)
end

local function buildVignette(w, h)
    local cv = newCanvas(w, h)
    if not cv then return nil end
    local prev = love.graphics.getCanvas()
    love.graphics.push()
    love.graphics.origin()
    love.graphics.setCanvas(cv)
    love.graphics.clear(0, 0, 0, 0)
    drawVignetteDirect(w, h)
    love.graphics.setCanvas(prev)
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
    return cv
end

-- Murs + porte (couche Depth.WALLS, 1 seul draw call SpriteBatch)
function Arena:drawWalls(isGateOpen, mapW)
    local w = mapW or Config.TOP_WIDTH
    local t = love.timer.getTime()
    love.graphics.setColor(1, 1, 1, 1)
    if self.wallBatch then love.graphics.draw(self.wallBatch) end

    local gx, gy = math.floor(w / 2), 32
    if not isGateOpen then
        Art.draw("gate_bars", (math.floor(t * 3) % 2) + 1, gx, gy)
    else
        Art.draw("portal", (math.floor(t * 8) % 3) + 1, gx, gy)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Arena:drawAtmosphere()
    if not self.vignette and not self._vignetteAttempted then
        self._vignetteAttempted = true
        self.vignette = buildVignette(Config.TOP_WIDTH, Config.TOP_HEIGHT)
    end
    if self.vignette then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.vignette, 0, 0)
    else
        -- 3DS: dessin direct de la vignette (légèrement simplifié)
        drawVignetteDirect(Config.TOP_WIDTH, Config.TOP_HEIGHT)
    end
end

return Arena
