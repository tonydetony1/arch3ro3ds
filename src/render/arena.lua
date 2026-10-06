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
local Gpu = require("src.core.gpu")
local GroundTiles = require("src.render.ground_tiles")


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
    self.skyBands = nil
    self.camera = nil -- caméra de la salle (culling du sol), fournie par GameState
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
    self.skyBands = nil
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
-- Dégradé du ciel en bandes pleines (4 sommets par bande, aucun Canvas)
local SKY_BANDS = 8
-- Overflow past the screen: heavy shake (11 px) + 3D layer offset (10 px) horizontally,
-- heavy shake vertically
local SKY_PAD_X = 24
local SKY_PAD_Y = 16
local function buildSkyBands(theme)
    local top = Palette.hex(theme and theme.skyTop or "4f9be8")
    local bottom = Palette.hex(theme and theme.skyBottom or "cdeeff")
    local bands = {}
    for i = 0, SKY_BANDS - 1 do
        local f = i / (SKY_BANDS - 1)
        bands[i + 1] = {
            top[1] + (bottom[1] - top[1]) * f,
            top[2] + (bottom[2] - top[2]) * f,
            top[3] + (bottom[3] - top[3]) * f,
        }
    end
    return bands
end

function Arena:drawSky(camX, camY)
    local w, h = Config.TOP_WIDTH, Config.TOP_HEIGHT
    local t = love.timer.getTime()
    if not self.skyBands or self._skyTheme ~= self.theme then
        self.skyBands = buildSkyBands(self.theme)
        self._skyTheme = self.theme
    end

    -- The sky overflows the screen so the shake and the 3D layer offset never uncover the
    -- background clear colour (a blue bar at the screen edge)
    Depth.push(Depth.SKY)
    local skyName = "ov_sky_" .. (self.themeId or 1)
    local f = Art.has(skyName) and Art.frame(skyName, 1)
    if f then
        -- Dégradé précuit dessiné en blanc : même lot que les îles et nuages (1 appel GPU)
        love.graphics.setColor(1, 1, 1, 1)
        Art.drawEx(skyName, 1, -SKY_PAD_X, -SKY_PAD_Y, 0, (w + 2 * SKY_PAD_X) / f.w, (h + 2 * SKY_PAD_Y) / f.h)
    else
        local bandH = math.ceil(h / SKY_BANDS)
        local last = #self.skyBands
        for i, c in ipairs(self.skyBands) do
            local y0 = (i - 1) * bandH
            local y1 = i * bandH
            if i == 1 then y0 = -SKY_PAD_Y end
            if i == last then y1 = h + SKY_PAD_Y end
            love.graphics.setColor(c[1], c[2], c[3], 1)
            love.graphics.rectangle("fill", -SKY_PAD_X, y0, w + 2 * SKY_PAD_X, y1 - y0)
        end
    end
    Depth.pop()

    -- Îles lointaines et nuages opaques (dessinés en blanc : fusionnés dans le même lot)
    Depth.push(Depth.FAR)
    love.graphics.setColor(1, 1, 1, 1)
    for _, isl in ipairs(self.farIslands) do
        local px = ((isl.x - (camX or 0) * isl.parallax) % (w + 80)) - 40
        local py = isl.y - (camY or 0) * isl.parallax + math.floor(math.sin(t * 0.6 + isl.bob) * 2 + 0.5)
        Art.draw(isl.name, 1, px, py, false, false, self.theme and self.theme.variant)
    end
    Depth.pop()

    Depth.push(Depth.CLOUDS)
    love.graphics.setColor(1, 1, 1, 1)
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
-- Aplats teintés : hors du lot de sprites (sur 3DS un sprite teinté = 1 appel GPU, et un
-- aplat découpé par tuile en coûtait des dizaines). Ils sont mémorisés en deux listes :
--   * rectSink = "under" : sous tous les sprites du sol (couleur de base de l'île)
--   * rectSink = "over"  : par-dessus (brume, lumière, ombres des murs, ombrage de falaise)
local rectLists = { under = {}, over = {} }
local rectSink = "over"

local function addRect(_, x, y, w, h, color, alpha)
    local list = rectLists[rectSink]
    list[#list + 1] = { math.floor(x), math.floor(y), math.floor(w + 0.5), math.floor(h + 0.5),
        color[1], color[2], color[3], alpha or 1 }
end

local function drawRectList(list, x0, y0, x1, y1)
    for i = 1, #list do
        local r = list[i]
        if r[1] < x1 and r[1] + r[3] > x0 and r[2] < y1 and r[2] + r[4] > y0 then
            love.graphics.setColor(r[5], r[6], r[7], r[8])
            love.graphics.rectangle("fill", r[1], r[2], r[3], r[4])
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Voile ou ombre pré-coloré (src/render/sprites/overlays.lua) étiré sur un rectangle :
-- dessiné en blanc, il reste dans le lot du décor (1 appel GPU pour tout le sol)
local function addOverlay(b, name, x, y, w, h)
    local f = Art.frame(name, 1)
    if not f or w <= 0 or h <= 0 then return end
    b:setColor(1, 1, 1, 1)
    b:add(f.quad, math.floor(x), math.floor(y), 0, w / f.w, h / f.h, 0, 0)
end

-- Couches du sol découpé : une seule couche suffit (dans une tuile, l'ordre d'insertion
-- falaise -> motifs -> dalles -> détails est conservé) et divise le nombre d'appels GPU par 4
local function layer(_, _) end

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
    addOverlay(b, "ov_cliff", 12, top + 22, w - 24, 30)
    for _ = 1, math.floor(w / 30) do
        addSprite(b, "root", 1, 16 + rng() * (w - 40), top + 44 + math.floor(rng() * 6))
    end
    addRect(b, 16, top - 1, w - 32, 2, Palette.hex(theme.edge))
    addRect(b, 16, top - 2, w - 32, 1, Palette.hex(theme.groundDark))
end

-- Quads recadrés des tuiles de bord (largeur/hauteur partielles), mis en cache
local partialQuads = {}
local function tileQuad(f, pw, ph)
    if pw == f.w and ph == f.h then return f.quad end
    local key = f.ax .. ":" .. f.ay .. ":" .. pw .. "x" .. ph
    local q = partialQuads[key]
    if not q then
        local aw, ah = Art.image:getDimensions()
        q = love.graphics.newQuad(f.ax, f.ay, pw, ph, aw, ah)
        partialQuads[key] = q
    end
    return q
end

-- Sol en tuiles précalculées (src/render/ground_tiles.lua) : couleur, taches et détails
-- déjà composés ; le choix de la variante dépend de la position (stable d'une image à l'autre)
local function fillGroundTiles(b, x0, y0, gw, gh, themeIndex)
    local size = GroundTiles.SIZE
    b:setColor(1, 1, 1, 1)
    for ty = y0, y0 + gh - 1, size do
        for tx = x0, x0 + gw - 1, size do
            local cx, cy = math.floor(tx / size), math.floor(ty / size)
            local v = (cx * 7 + cy * 13 + cx * cy) % GroundTiles.VARIANTS + 1
            local f = Art.frame(GroundTiles.name(themeIndex, v), 1)
            if f then
                local pw = math.min(size, x0 + gw - tx)
                local ph = math.min(size, y0 + gh - ty)
                b:add(tileQuad(f, pw, ph), tx, ty, 0, 1, 1, 0, 0)
            end
        end
    end
end

local function fillGround(b, w, h, theme, rng, themeIndex)
    rectSink = "under"
    addRect(b, 16, GROUND_TOP, w - 32, h - GROUND_TOP - 14, Palette.hex(theme.ground))
    rectSink = "over"
    layer(b, 3)
    local useTiles = themeIndex and Art.has(GroundTiles.name(themeIndex, 1))
    if useTiles then
        fillGroundTiles(b, 16, GROUND_TOP, w - 32, h - GROUND_TOP - 14, themeIndex)
    end
    local area = w * h
    for _ = 1, useTiles and 0 or math.floor(area / 7000) do
        local name = (rng() < 0.55) and theme.patchLight or theme.patchDark
        addSpriteV(b, name, 1, 30 + rng() * (w - 60), 40 + rng() * (h - 70), theme.variant)
    end
    for _ = 1, useTiles and 0 or math.floor(area / 60000) do
        addSpriteV(b, theme.patchExtra, 1, 40 + rng() * (w - 80), 60 + rng() * (h - 120), theme.variant)
    end
    layer(b, 4)
    local hazeH = math.floor((h - GROUND_TOP) * 0.45)
    local nearH = math.floor((h - GROUND_TOP) * 0.3)
    addOverlay(b, "ov_haze", 16, GROUND_TOP, w - 32, hazeH)
    addOverlay(b, "ov_dark", 16, h - 16 - nearH, w - 32, nearH)
    for i = 0, 2 do
        addOverlay(b, "ov_yellow", 16, GROUND_TOP + i * 30, (w - 32) * (1 - i / 3), 30)
        addOverlay(b, "ov_navy", 16 + (w - 32) * (i / 3), h - 16 - (i + 1) * 30, (w - 32) * (1 - i / 3), 30)
    end
    return useTiles
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
    addOverlay(b, "ov_wall_top", 16, GROUND_TOP, w - 32, 12)
    addOverlay(b, "ov_wall_left", 16, GROUND_TOP, 12, h - GROUND_TOP - 16)
    addOverlay(b, "ov_abyss12", w - 26, GROUND_TOP, 10, h - GROUND_TOP - 16)
end

-- Ombres portées des rochers et souches : intégrées au lot du sol (sprites pré-colorés)
local function fillRockShadows(b, om)
    if not om or not om.rockShadows then return end
    for _, sh in ipairs(om.rockShadows) do
        if sh[1] == "ellipse" then
            local f = Art.frame("fx_shadow_d1", 1)
            if f then
                b:setColor(1, 1, 1, 1)
                b:add(f.quad, math.floor(sh[2]), math.floor(sh[3]), 0, sh[4] * 2 / f.w, sh[5] * 2 / f.h, f.ox, f.oy)
            end
        else
            local minX = math.min(sh[2], sh[4], sh[6], sh[8])
            local maxX = math.max(sh[2], sh[4], sh[6], sh[8])
            local minY = math.min(sh[3], sh[5], sh[7], sh[9])
            local maxY = math.max(sh[3], sh[5], sh[7], sh[9])
            addOverlay(b, "ov_shadow", minX, minY, maxX - minX, maxY - minY)
        end
    end
    om.rockShadows = {}
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
        -- Sol découpé en tuiles de 128 px : seules les tuiles visibles partent au GPU
        -- Un seul lot pour tout le sol : mesuré sur Old 3DS, 0,8 ms contre 1,3 ms découpé
        -- (un appel GPU coûte ~80 µs, un sommet ~0,6 µs). Les murs, eux, restent découpés.
        self.groundBatch = Gpu.newBatch(Art.image, 900, "static")
    end
    self.canvas = self.groundBatch
    self.canvasW = w
    self.canvasH = h
    local b = self.groundBatch
    b:clear()
    rectLists = { under = {}, over = {} }
    self.rectsUnder = rectLists.under
    self.rectsOver = rectLists.over
    rectSink = "over"

    local theme = self._groundTheme
    local rng = makeRng(w * 7 + h * 13)

    layer(b, 1)
    fillCliff(b, w, h, rng, theme)
    local tiled = fillGround(b, w, h, theme, rng, self.themeId)
    layer(b, 5)
    fillPlazas(b, w, h, theme)
    layer(b, 6)
    if not tiled then fillDecals(b, w, h, rng, theme) end -- détails déjà dans les tuiles
    layer(b, 7)
    fillWallShadows(b, w, h)

    b:setColor(1, 1, 1, 1)

    if self.obstacleManager and self.obstacleManager.bakeStatic then
        self.obstacleManager:bakeStatic()
        fillRockShadows(b, self.obstacleManager)
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
        self.wallBatch = Gpu.newChunkedBatch(Art.image, 256, WALL_BATCH_SIZE)
    end
    local b = self.wallBatch
    b:reset(w, h, -64, -64)
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
-- Rectangle monde visible par la caméra (élargi de `margin` pixels)
function Arena:viewRect(margin)
    local cam = self.camera
    if not cam then
        return -64, -64, (self._groundW or 640) + 64, (self._groundH or 480) + 96
    end
    local x0 = cam.x - cam.halfW - margin
    local y0 = cam.y - cam.halfH - margin
    return x0, y0, x0 + cam.viewportW + margin * 2, y0 + cam.viewportH + margin * 2
end

-- Sol dessiné directement (tous ses sprites et aplats) dans le rectangle donné
local Perf = require("src.core.perf")
function Arena:drawGroundLive(x0, y0, x1, y1)
    Perf.sec("h:sol-prep")
    drawRectList(self.rectsUnder, x0, y0, x1, y1)
    Perf.sec("h:sol-sous")
    self.groundBatch:draw()
    Perf.sec("h:sol-tuiles")
    if self.obstacleManager and self.obstacleManager.drawStaticGround then
        self.obstacleManager:drawStaticGround(x0, y0, x1, y1)
    end
    Perf.sec("h:sol-statique")
    drawRectList(self.rectsOver, x0, y0, x1, y1)
    Perf.sec("h:sol-voiles")
end

function Arena:draw(isGateOpen, palette, spawnWarnings, mapW, mapH)
    local w = mapW or Config.TOP_WIDTH
    local h = mapH or Config.TOP_HEIGHT
    local t = love.timer.getTime()

    if not self.groundBatch or self._groundW ~= w or self._groundH ~= h or self._groundTheme ~= self.theme then
        self:buildGround(w, h, palette, self.obstacleManager)
    end

    love.graphics.setColor(1, 1, 1, 1)
    if self.groundBatch then
        self:drawGroundLive(self:viewRect(16))
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

-- Murs + porte (couche Depth.WALLS, 1 seul draw call SpriteBatch)
function Arena:drawWalls(isGateOpen, mapW)
    local w = mapW or Config.TOP_WIDTH
    local t = love.timer.getTime()
    love.graphics.setColor(1, 1, 1, 1)
    if self.wallBatch then
        local x0, y0, x1, y1 = self:viewRect(0)
        self.wallBatch:drawView(x0, y0, x1, y1, 56)
    end

    local gx, gy = math.floor(w / 2), 32
    if not isGateOpen then
        Art.draw("gate_bars", (math.floor(t * 3) % 2) + 1, gx, gy)
    else
        Art.draw("portal", (math.floor(t * 8) % 3) + 1, gx, gy)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Arena:drawAtmosphere()
    -- 4 aplats : moins cher qu'une texture plein écran et sans Canvas
    drawVignetteDirect(Config.TOP_WIDTH, Config.TOP_HEIGHT)
end

return Arena
