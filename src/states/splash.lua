-- src/states/splash.lua
-- Écran titre Nintendo 3DS
-- Haut (400x240) : illustration officielle plein écran. Le titre ARCH3RO, détaché du décor par
--   tools/make_title_assets.py, flotte devant l'écran en relief 3D. Caméra qui respire (parallaxe
--   par couche), torches qui vacillent, runes et flèches enchantées qui pulsent, braises, lucioles.
-- Bas (320x240) : autel runique (cercles qui tournent), héros choisi, ressources, bouton JOUER.

local Config = require("src.data.config")
local Palette = require("src.render.palette")
local UI = require("src.ui.ui_components")
local Skin = require("src.ui.skin")
local PixelFont = require("src.ui.pixel_font")
local Audio = require("src.audio.audio")
local Art = require("src.render.art")
local Depth = require("src.render.depth")
local Screen = require("src.core.screen")
local Heroes = require("src.data.heroes")
local HeroSprites = require("src.render.sprites.heroes")
local Save = require("src.data.save")
local Layout = require("src.render.title_layout")

local SplashState = {}
SplashState.__index = SplashState

local C = Palette.C
local sin, floor, min, random = math.sin, math.floor, math.min, math.random
local TAU = math.pi * 2

local TOP_W, TOP_H = Config.TOP_WIDTH, Config.TOP_HEIGHT
local BOT_W = Config.BOTTOM_WIDTH
-- Décor 426x256 centré : la marge absorbe le décalage stéréo et la dérive de caméra
local BG_X = (TOP_W - Layout.bg[3]) / 2
local BG_Y = (TOP_H - Layout.bg[4]) / 2

-- Chronologie de l'intro (secondes)
local FADE_IN = 1.0
local TITLE_IN, TITLE_DUR = 0.35, 0.9
local PROMPT_IN = 1.8
local GLEAM_EVERY, GLEAM_DUR = 2.6, 0.7

-- Dérive de caméra (px) : plus une couche est proche, plus elle se déplace
local CAM_BG, CAM_TITLE, CAM_NEAR = 3, 5, 7

-- Lumières posées sur l'illustration (pixels du décor, tools/make_title_assets.py)
local MOON, TORCHES, ARROWS = Layout.moon, Layout.torches, Layout.arrows
local RUNES, STARS = Layout.runes, Layout.stars

local FIREFLY_COLORS = { { 0.45, 1.0, 0.65 }, { 0.40, 0.95, 1.0 }, { 0.75, 1.0, 0.45 } }
local EMBER_COLOR = { 1.0, 0.55, 0.18 }
local FIREFLIES, EMBERS = 14, 18

-- Écran bas : autel runique et bouton
local ALTAR_X, ALTAR_Y, FLOOR_Y = 160, 84, 122
local BTN_X, BTN_Y, BTN_W, BTN_H = 24, 180, 272, 38
local BLINK_EVERY = 3.2

-- Couleurs réutilisées (aucune table créée pendant le dessin)
local PROMPT_COLOR = { 1.0, 0.90, 0.62, 1 }
local CAPTION_COLOR = { 0.80, 0.88, 1.0, 0.95 }
local FOOTER_COLOR = { 0.55, 0.65, 0.80, 0.75 }

-- ---------------------------------------------------------------------------
-- Ressources graphiques
-- ---------------------------------------------------------------------------
local function loadImage(path)
    local ok, img = pcall(love.graphics.newImage, path)
    if not ok or not img then return nil end
    img:setFilter("linear", "linear")
    return img
end

local function quadOf(rect, img)
    return love.graphics.newQuad(rect[1], rect[2], rect[3], rect[4], img:getWidth(), img:getHeight())
end

-- Fusion additive si le moteur la propose (lueurs) ; sinon fusion alpha, rendu plus doux
local addSupported = nil
local function setAdd(on)
    if addSupported == nil then
        addSupported = pcall(love.graphics.setBlendMode, "add")
        if not addSupported then return end
    end
    if addSupported then love.graphics.setBlendMode(on and "add" or "alpha") end
end

local function easeOutBack(k)
    local c = 1.6
    local u = k - 1
    return 1 + (c + 1) * u * u * u + c * u * u
end

-- ---------------------------------------------------------------------------
-- Particules (pré-allouées : zéro allocation par image)
-- ---------------------------------------------------------------------------
local function newFirefly()
    return {
        x0 = random(10, TOP_W - 10), y0 = random(30, TOP_H - 6),
        ax = random(8, 22), ay = random(5, 14), x = 0, y = 0,
        fx = 0.2 + random() * 0.35, fy = 0.25 + random() * 0.4, ph = random() * TAU,
        blink = 0.8 + random() * 1.4, rise = 3 + random() * 5,
        depth = random(-5, 5), size = 0.30 + random() * 0.30,
        col = FIREFLY_COLORS[random(#FIREFLY_COLORS)],
    }
end

-- Braise des torches ou étincelle des flèches (coordonnées du décor)
local function spawnEmber(e)
    if random() < 0.65 then
        local src = TORCHES[random(#TORCHES)]
        e.x, e.y = src[1] + random(-3, 3), src[2] - random(0, 4)
        e.vx, e.vy = random(-6, 6), -(18 + random() * 22)
        e.col, e.size = EMBER_COLOR, 0.45 + random() * 0.45
    else
        local src = ARROWS[random(#ARROWS)]
        e.x, e.y = src[1] + random(-4, 2), src[2] + random(-2, 2)
        e.vx, e.vy = 6 + random() * 14, -(4 + random() * 10)
        e.col, e.size = src[3], 0.35 + random() * 0.35
    end
    e.life, e.ttl, e.ph = 0, 1.0 + random() * 1.4, random() * TAU
end

function SplashState.new(stateMachine)
    local self = setmetatable({}, SplashState)
    self.sm = stateMachine
    self.timer = 0
    self.q = {}
    self.fireflies, self.embers = {}, {}
    for i = 1, FIREFLIES do self.fireflies[i] = newFirefly() end
    for i = 1, EMBERS do
        local e = {}
        spawnEmber(e)
        e.life = random() * e.ttl -- déjà en vol au premier affichage
        self.embers[i] = e
    end
    return self
end

function SplashState:loadAssets()
    if self.topImg then return end
    self.topImg = loadImage("assets/title_top.png")
    self.fxImg = loadImage("assets/title_fx.png")
    self.botImg = loadImage("assets/title_bottom.png")
    local q = {}
    if self.topImg then q.bg = quadOf(Layout.bg, self.topImg) end
    if self.fxImg then
        for _, name in ipairs({ "letters", "halo", "glow", "spark", "dot", "mote" }) do
            q[name] = quadOf(Layout[name], self.fxImg)
        end
    end
    if self.botImg then
        q.bottomBg = quadOf(Layout.bottomBg, self.botImg)
        q.ring = quadOf(Layout.ring, self.botImg)
    end
    self.q = q
end

function SplashState:enter()
    self.timer = 0
    self:loadAssets()
    local sData = Save.get()
    local st = sData.settings or {}
    local hData = Heroes.get(sData.selectedHero or "atreus")
    -- Textes figés le temps de l'écran titre (pas de string.format à chaque image)
    self.texts = {
        level = string.format("LV. %d", sData.accountLevel or 1),
        gold = tostring(sData.gold or 0),
        gems = tostring(sData.gems or 0),
        name = hData.name:upper(),
        caption = string.format("%s  -  CHAPTER %d", hData.title, sData.selectedChapter or 1),
    }
    -- Mode économie : moitié moins de particules
    self.particleCount = st.lowPower and 0.5 or 1
    -- Autel animé : l'écran tactile est redessiné à chaque image tant que le titre est affiché
    Screen.bottomAlways = true
    Audio.playMusic("hub")
end

-- L'écran titre ne revient pas pendant la session : ses ~1,2 Mo de textures sont rendus
function SplashState:exit()
    Screen.bottomAlways = false
    Depth.begin(0) -- pas d'œil résiduel pour les états qui ne gèrent pas le relief
    for _, key in ipairs({ "topImg", "fxImg", "botImg" }) do
        local img = self[key]
        if img and img.release then pcall(img.release, img) end
        self[key] = nil
    end
    self.q = {}
end

function SplashState:update(dt)
    self.timer = self.timer + dt
    local t = self.timer
    for i = 1, #self.fireflies do
        local f = self.fireflies[i]
        local y = f.y0 - t * f.rise + 20
        f.x = f.x0 + sin(t * f.fx + f.ph) * f.ax
        f.y = y - floor(y / (TOP_H + 40)) * (TOP_H + 40) - 20 + sin(t * f.fy + f.ph) * f.ay
    end
    for i = 1, #self.embers do
        local e = self.embers[i]
        e.life = e.life + dt
        if e.life >= e.ttl then spawnEmber(e) end
        e.x = e.x + (e.vx + sin(t * 3 + e.ph) * 8) * dt
        e.y = e.y + e.vy * dt
    end
end

-- ---------------------------------------------------------------------------
-- Écran du haut
-- ---------------------------------------------------------------------------
-- Sprite de la feuille d'effets centré en (x, y), teinté
function SplashState:sprite(name, x, y, scale, r, g, b, a, rot)
    local rect = Layout[name]
    love.graphics.setColor(r, g, b, a)
    love.graphics.draw(self.fxImg, self.q[name], x, y, rot or 0, scale, scale, rect[3] / 2, rect[4] / 2)
end

function SplashState:drawSceneLights(bx, by, t)
    setAdd(true)
    self:sprite("glow", bx + MOON[1], by + MOON[2], 1.6 + 0.1 * sin(t * 0.8), 0.55, 0.70, 1.0, 0.30)
    for i = 1, #RUNES do
        local r = RUNES[i]
        self:sprite("glow", bx + r[1], by + r[2], 1.3, 0.35, 1.0, 0.60, 0.16 + 0.14 * sin(t * 1.3 + i * 1.7))
    end
    -- Torches : sinus incommensurables, la flamme ne se répète jamais à l'identique
    for i = 1, #TORCHES do
        local p = TORCHES[i]
        local flick = 0.5 + 0.25 * sin(t * 9.1 + i * 2) + 0.15 * sin(t * 23.7 + i) + 0.1 * sin(t * 4.3 + i * 3)
        self:sprite("glow", bx + p[1], by + p[2], 2.2 + flick * 0.4, 1.0, 0.55, 0.18, 0.20 + flick * 0.22)
    end
    for i = 1, #ARROWS do
        local a, c = ARROWS[i], ARROWS[i][3]
        local pulse = 0.5 + 0.5 * sin(t * 3.2 + i * 2.1)
        self:sprite("glow", bx + a[1], by + a[2], 1.1 + pulse * 0.35, c[1], c[2], c[3], 0.28 + pulse * 0.25)
    end
    for i = 1, #STARS do
        local s, tw = STARS[i], sin(t * 1.7 + i * 2.3)
        if tw > 0.2 then
            self:sprite("spark", bx + s[1], by + s[2], 0.22 + tw * 0.2, 0.85, 0.92, 1.0, tw)
        end
    end
    local n = floor(#self.embers * self.particleCount)
    for i = 1, n do
        local e = self.embers[i]
        local k = e.life / e.ttl
        local a = (k < 0.15) and (k / 0.15) or (1 - k) / 0.85
        local c = e.col
        self:sprite("dot", bx + e.x, by + e.y, e.size * (1 - k * 0.5), c[1], c[2], c[3], a)
    end
    setAdd(false)
end

-- Lucioles réparties en profondeur : certaines derrière l'écran, d'autres jaillissent devant
function SplashState:drawFireflies(t, cx, cy)
    setAdd(true)
    local n = floor(#self.fireflies * self.particleCount)
    for i = 1, n do
        local f = self.fireflies[i]
        local blink = sin(t * f.blink + f.ph)
        if blink > -0.3 then
            local a = (blink + 0.3) / 1.3
            a = a * a
            local par = 0.5 + (f.depth + 5) / 10
            local x = f.x + cx * CAM_NEAR * par + Depth.offset(f.depth)
            local y = f.y + cy * CAM_NEAR * par * 0.6
            local c = f.col
            self:sprite("glow", x, y, f.size, c[1], c[2], c[3], a * 0.6)
            self:sprite("mote", x, y, 0.9, 0.8 + c[1] * 0.2, 1, 0.8 + c[3] * 0.2, a)
        end
    end
    setAdd(false)
end

function SplashState:drawTitle(t, cx, cy)
    local k = (t - TITLE_IN) / TITLE_DUR
    if k <= 0 then return end
    k = min(1, k)
    local scale = 1.18 - 0.18 * easeOutBack(k)
    local L, H = Layout.letters, Layout.halo
    local x = BG_X + Layout.titleX + L[3] / 2 + cx * CAM_TITLE + Depth.offset(Depth.TEXT)
    local y = BG_Y + Layout.titleY + L[4] / 2 + cy * CAM_TITLE * 0.6 + sin(t * 1.1) * 1.5
    -- Éclair doré à la fin de l'apparition, puis halo qui respire
    local since = t - (TITLE_IN + TITLE_DUR * 0.7)
    local flash = (since > 0 and since < 0.8) and (1 - since / 0.8) ^ 2 or 0
    setAdd(true)
    love.graphics.setColor(1, 0.85, 0.55, (0.32 + 0.14 * sin(t * 1.8) + flash * 0.9) * k)
    love.graphics.draw(self.fxImg, self.q.halo, x, y, 0, scale, scale, H[3] / 2, H[4] / 2)
    setAdd(false)
    love.graphics.setColor(1, 1, 1, min(1, k * 1.6))
    love.graphics.draw(self.fxImg, self.q.letters, x, y, 0, scale, scale, L[3] / 2, L[4] / 2)
    if flash > 0 then
        setAdd(true)
        love.graphics.setColor(1, 1, 1, flash * 0.6)
        love.graphics.draw(self.fxImg, self.q.letters, x, y, 0, scale, scale, L[3] / 2, L[4] / 2)
        setAdd(false)
    end
    self:drawGleam(t, x - L[3] / 2 * scale, y - L[4] / 2 * scale, scale)
end

-- Éclat qui court d'une lettre à l'autre (ordre mélangé : 3 est premier avec 7 points)
function SplashState:drawGleam(t, x0, y0, scale)
    local since = t - TITLE_IN - TITLE_DUR
    if since < 0 then return end
    local cycle = since / GLEAM_EVERY
    local idx = floor(cycle)
    local ph = (cycle - idx) * GLEAM_EVERY / GLEAM_DUR
    if ph >= 1 then return end
    local g = Layout.gleams[(idx * 3) % #Layout.gleams + 1]
    local s = sin(ph * math.pi)
    local x, y = x0 + g[1] * scale, y0 + g[2] * scale
    setAdd(true)
    self:sprite("glow", x, y, 0.7 * s, 1, 0.85, 0.5, s * 0.5)
    self:sprite("spark", x, y, 0.3 + s * 0.6, 1, 0.96, 0.82, s, ph * 1.2)
    setAdd(false)
end

function SplashState:drawPrompt(t)
    if t < PROMPT_IN then return end
    PROMPT_COLOR[4] = min(1, (t - PROMPT_IN) / 0.5) * (0.6 + 0.4 * sin(t * 3.4))
    local label = "PRESS"
    local tw = PixelFont.getWidth(label, "main")
    local x = floor((TOP_W - (tw + 18)) / 2) + Depth.offset(Depth.TEXT - 1)
    local y = 221
    PixelFont.print(label, x, y, PROMPT_COLOR, "main")
    -- Bouton A de la console
    local bx, by = x + tw + 11, y + 6
    Skin.disc(C.ink, bx, by, 7, PROMPT_COLOR[4])
    Skin.disc(C.amber, bx, by, 6, PROMPT_COLOR[4])
    PixelFont.print("A", bx - 3, by - 6, PROMPT_COLOR, "main")
    -- Losanges de part et d'autre
    love.graphics.setColor(PROMPT_COLOR[1], PROMPT_COLOR[2], PROMPT_COLOR[3], PROMPT_COLOR[4] * 0.8)
    local lx, rx = x - 12, bx + 14
    love.graphics.polygon("fill", lx, by, lx + 3, by - 3, lx + 6, by, lx + 3, by + 3)
    love.graphics.polygon("fill", rx, by, rx + 3, by - 3, rx + 6, by, rx + 3, by + 3)
end

function SplashState:drawTop(eye)
    Depth.begin(eye)
    love.graphics.clear(0, 0, 0, 1)
    local t = self.timer
    if self.topImg and self.fxImg then
        local cx, cy = sin(t * 0.21), sin(t * 0.17 + 1.3)
        local bx = BG_X + cx * CAM_BG + Depth.offset(Depth.FAR)
        local by = BG_Y + cy * CAM_BG * 0.6
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.topImg, self.q.bg, bx, by)
        self:drawSceneLights(bx, by, t)
        self:drawFireflies(t, cx, cy)
        self:drawTitle(t, cx, cy)
    else
        -- Textures absentes : titre typographique de secours
        UI.setFont("main")
        PixelFont.printf("ARCH3RO", 0, 80, TOP_W, "center", C.amber, "main", 3)
    end
    self:drawPrompt(t)
    if t < FADE_IN then
        love.graphics.setColor(0, 0, 0, 1 - t / FADE_IN)
        love.graphics.rectangle("fill", 0, 0, TOP_W, TOP_H)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ---------------------------------------------------------------------------
-- Écran du bas : autel runique
-- ---------------------------------------------------------------------------
function SplashState:drawRing(x, y, rot, scale, squash, r, g, b, a)
    local R = Layout.ring
    love.graphics.setColor(r, g, b, a)
    if squash == 1 then
        love.graphics.draw(self.botImg, self.q.ring, x, y, rot, scale, scale, R[3] / 2, R[4] / 2)
        return
    end
    -- Cercle couché au sol : rotation dans son plan, puis écrasement vertical
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(1, squash)
    love.graphics.draw(self.botImg, self.q.ring, 0, 0, rot, scale, scale, R[3] / 2, R[4] / 2)
    love.graphics.pop()
end

function SplashState:drawHero(heroId, x, feetY)
    local variant = (heroId ~= "atreus") and heroId or nil
    Palette.set(C.ink, 0.45)
    love.graphics.ellipse("fill", x, feetY - 8, 20, 6)
    love.graphics.setColor(1, 1, 1, 1)
    Art.drawEx("hero_legs", 1, x, feetY - 12, 0, 3, 3)
    -- Clignement des yeux bref toutes les ~3 s
    local blink = (self.timer % BLINK_EVERY) < 0.14 and 2 or 1
    Art.drawEx("hero_body", blink, x, feetY - 21, 0, 3, 3, false, variant)
    local acc = HeroSprites.ACCESSORY_BY_HERO[heroId]
    if acc then
        local o = HeroSprites.ACCESSORY_OFFSETS[acc]
        Art.drawEx("hero_acc_" .. acc, 1, x + o[1] * 3, feetY - 21 + o[2] * 3, 0, 3, 3)
    end
    Art.drawEx("bow", 1, x + 26, feetY - 46, 0.35, 2, 2)
end

function SplashState:drawAltar(t, heroId)
    local pulse = 0.5 + 0.5 * sin(t * 1.6)
    if self.botImg then
        setAdd(true)
        self:drawRing(ALTAR_X, ALTAR_Y, t * 0.10, 0.66, 1, 0.35, 1.0, 0.65, 0.22 + 0.08 * pulse)
        self:drawRing(ALTAR_X, ALTAR_Y, -t * 0.18, 0.40, 1, 0.45, 0.85, 1.0, 0.16)
        self:drawRing(ALTAR_X, FLOOR_Y, t * 0.25, 0.62, 0.32, 0.45, 1.0, 0.70, 0.50 + 0.15 * pulse)
        setAdd(false)
    end
    if self.fxImg then
        setAdd(true)
        self:sprite("glow", ALTAR_X, FLOOR_Y - 18, 2.6, 0.35, 1.0, 0.65, 0.20 + 0.10 * pulse)
        setAdd(false)
    end
    self:drawHero(heroId, ALTAR_X, FLOOR_Y + floor(sin(t * 2.2) * 2))
    -- Particules montant du cercle
    if self.fxImg then
        setAdd(true)
        for i = 1, 8 do
            local k = (t * 0.35 + i / 8) % 1
            local x = ALTAR_X + sin(i * 2.4 + t * 0.7) * (34 - k * 14)
            self:sprite("dot", x, FLOOR_Y - k * 70, 0.5 * (1 - k), 0.5, 1.0, 0.7, (1 - k) * 0.9)
        end
        setAdd(false)
    end
end

function SplashState:drawResources(texts)
    UI.drawPillBadge(8, 6, 58, 18, texts.level, nil, nil, C.yellow, "star")
    UI.drawPillBadge(BOT_W - 148, 6, 76, 18, texts.gold, nil, nil, C.yellow, "gold")
    UI.drawPillBadge(BOT_W - 68, 6, 60, 18, texts.gems, nil, nil, C.cyan, "gem")
end

function SplashState:drawBottom()
    local t = self.timer
    love.graphics.clear(0.02, 0.03, 0.06, 1)
    if self.botImg then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.botImg, self.q.bottomBg, 0, 0)
    end

    local texts = self.texts
    self:drawAltar(t, Save.get().selectedHero or "atreus")
    self:drawResources(texts)
    PixelFont.printf(texts.name, 0, 140, BOT_W, "center", C.yellow, "main", 1, "shadow")
    PixelFont.printf(texts.caption, 0, 157, BOT_W, "center", CAPTION_COLOR, "tiny")

    -- Bouton JOUER : halo qui pulse derrière
    if self.fxImg then
        setAdd(true)
        local glow = Layout.glow
        love.graphics.setColor(0.4, 1.0, 0.55, 0.16 + 0.12 * sin(t * 3.0))
        love.graphics.draw(self.fxImg, self.q.glow, BTN_X + BTN_W / 2, BTN_Y + BTN_H / 2, 0,
            BTN_W / glow[3] * 1.2, BTN_H / glow[4] * 2.2, glow[3] / 2, glow[4] / 2)
        setAdd(false)
    end
    UI.drawPillButton(BTN_X, BTN_Y, BTN_W, BTN_H, "TOUCH TO PLAY", "emerald", self.pressed, "swords")

    PixelFont.printf("Developed by TonyDeTony  -  v1.0.8", 0, 226, BOT_W, "center", FOOTER_COLOR, "tiny")
    if t < FADE_IN then
        love.graphics.setColor(0, 0, 0, 1 - t / FADE_IN)
        love.graphics.rectangle("fill", 0, 0, BOT_W, Config.BOTTOM_HEIGHT)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ---------------------------------------------------------------------------
-- Entrées
-- ---------------------------------------------------------------------------
function SplashState:startGame()
    Audio.play("ui_confirm", 0, 0.9)
    self.pressed = false
    self.sm:switch("menu")
end

function SplashState:touchpressed(id, x, y)
    self.pressed = true
end

-- Tout l'écran tactile lance la partie ; le bouton s'enfonce sous le doigt avant
function SplashState:touchreleased(id, x, y)
    if self.pressed then self:startGame() end
end

-- Boutons de la console (LÖVE Potion ne produit pas de keypressed pour A / START)
function SplashState:gamepadpressed(joystick, button)
    if button == "a" or button == "start" then
        self:startGame()
    end
end

function SplashState:keypressed(key)
    if key == "a" or key == "return" or key == "space" or key == "start" then
        self:startGame()
    end
end

return SplashState
