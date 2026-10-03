-- src/states/splash.lua
-- Écran Titre & Splash Screen officiel pour Nintendo 3DS
-- Vitrine Top Screen (400x240) : Logo officiel doré ARCH3RO 3DS, Rayons divins & Particules
-- Interface Bottom Screen (320x240) : Bouton d'accueil tactile Gummy & Invocation du héros

local Config = require("src.data.config")
local Palette = require("src.render.palette")
local UI = require("src.ui.ui_components")
local Audio = require("src.audio.audio")
local Art = require("src.render.art")
local Skin = require("src.ui.skin")
local Heroes = require("src.data.heroes")
local Save = require("src.data.save")

local SplashState = {}
SplashState.__index = SplashState

function SplashState.new(stateMachine)
    local self = setmetatable({}, SplashState)
    self.sm = stateMachine
    self.timer = 0
    self.godRaysAngle = 0
    self.logoImg = nil
    self.bannerImg = nil

    -- Tentative de chargement du logo officiel 3DS (format t3x sur console, png sur PC)
    local okLogo, imgLogo = pcall(love.graphics.newImage, "assets/logo_3ds.png")
    if okLogo and imgLogo then
        imgLogo:setFilter("linear", "linear")
        self.logoImg = imgLogo
    end

    local okBanner, imgBanner = pcall(love.graphics.newImage, "assets/banner.png")
    if okBanner and imgBanner then
        imgBanner:setFilter("linear", "linear")
        self.bannerImg = imgBanner
    end

    -- Particules d'étoiles dorées pré-allouées (zéro allocation GC)
    self.particles = {}
    for i = 1, 30 do
        table.insert(self.particles, {
            x = math.random(6, Config.TOP_WIDTH - 6),
            y = math.random(0, Config.TOP_HEIGHT),
            speed = math.random(15, 35),
            size = math.random(1, 3),
            phase = math.random() * math.pi * 2,
            isGold = (i % 2 == 0)
        })
    end

    return self
end

function SplashState:enter()
    self.timer = 0
    Audio.playMusic("hub")
end

function SplashState:update(dt)
    self.timer = self.timer + dt
    self.godRaysAngle = self.godRaysAngle + dt * 0.35

    -- Mise à jour des particules
    for _, p in ipairs(self.particles) do
        p.y = p.y - p.speed * dt
        if p.y < -10 then
            p.y = Config.TOP_HEIGHT + 5
            p.x = math.random(6, Config.TOP_WIDTH - 6)
        end
    end
end

function SplashState:drawTop()
    local w = Config.TOP_WIDTH
    local h = Config.TOP_HEIGHT
    local t = self.timer

    -- Fond céleste étoilé dégradé
    love.graphics.clear(0.04, 0.06, 0.10, 1.0)
    love.graphics.setColor(0.08, 0.12, 0.20, 0.6)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- Particules flottantes
    for _, p in ipairs(self.particles) do
        local wave = math.sin(t * 2.5 + p.phase) * 6
        local alpha = 0.4 + 0.4 * math.sin(t * 3.0 + p.phase)
        if p.isGold then
            love.graphics.setColor(1.0, 0.85, 0.30, alpha)
        else
            love.graphics.setColor(0.40, 0.80, 1.0, alpha)
        end
        love.graphics.circle("fill", p.x + wave, p.y, p.size)
    end

    -- Rayons de lumière dorés divins en arrière-plan
    UI.drawGodRays(w / 2, 95, 180, 14, self.godRaysAngle, { 1.0, 0.80, 0.20, 0.18 })

    -- Affichage du Logo Officiel ARCH3RO 3DS
    local bob = math.floor(math.sin(t * 2.2) * 3)
    if self.logoImg then
        local iw = self.logoImg:getWidth()
        local ih = self.logoImg:getHeight()
        -- Échelle adaptée pour l'écran 400x240 (largeur ~300)
        local scale = math.min(300 / iw, 150 / ih)
        local lx = (w - iw * scale) / 2
        local ly = 20 + bob
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.logoImg, math.floor(lx), math.floor(ly), 0, scale, scale)
    else
        -- Fallback typographique avec ombre portée dorée
        UI.setFont("title")
        UI.drawTextAligned("ARCH3RO", 0, 45 + bob, w, "center", { 1.0, 0.85, 0.20, 1.0 })
        UI.setFont("main")
        UI.drawTextAligned("3 D S   E D I T I O N", 0, 85 + bob, w, "center", { 0.40, 0.90, 0.60, 1.0 })
    end

    -- Ruban sous le logo avec sous-titre
    Skin.ribbon(w / 2, 182, 260, 20, "gold")
    UI.drawTextAligned("AN ACTION ROGUELITE FOR NINTENDO 3DS", w / 2 - 130, 186, 260, "center", Palette.C.white)

    -- Mention New 3DS XL & Framerate
    UI.setFont("tiny")
    UI.drawTextAligned("NEW 3DS XL 804 MHz | 60 FPS | STEREOSCOPIC 3D", 0, 218, w, "center", { 0.65, 0.75, 0.90, 0.85 })
    UI.setFont("main")
end

function SplashState:drawBottom()
    local w = Config.BOTTOM_WIDTH
    local h = Config.BOTTOM_HEIGHT
    local t = self.timer

    love.graphics.clear(0.06, 0.08, 0.12, 1.0)

    -- Bento Card Centrale (296x140)
    UI.drawBentoCard(12, 14, 296, 140, {
        r = 10,
        bg = { 0.09, 0.12, 0.18, 0.95 },
        borderColor = { 0.25, 0.35, 0.50, 0.90 },
        accentColor = { 1.0, 0.80, 0.25, 0.90 },
        isElevated = true
    })

    -- Aperçu du héros
    local sData = Save.get()
    local curHeroId = sData.selectedHero or "atreus"
    local hData = Heroes.get(curHeroId)
    local heroX = 60
    local heroY = 110

    Palette.set(Palette.C.ink, 0.4)
    love.graphics.ellipse("fill", heroX, heroY + 8, 20, 6)
    love.graphics.setColor(1, 1, 1, 1)
    Art.drawEx("hero_legs", 1, heroX, heroY, 0, 2.5, 2.5)
    Art.drawEx("hero_body", 1, heroX, heroY - 7, 0, 2.5, 2.5, false, (curHeroId ~= "atreus") and curHeroId or nil)
    Art.drawEx("bow", 1, heroX + 20, heroY - 26, 0.3, 1.8, 1.8)

    -- Informations du joueur
    UI.drawText(string.format("HÉROS : %s", hData.name:upper()), 110, 32, { 1.0, 0.85, 0.25, 1.0 })
    UI.setFont("tiny")
    UI.drawText(string.format("Titre : %s", hData.title), 110, 52, { 0.80, 0.88, 1.0, 0.95 })
    UI.drawText(string.format("Niveau Compte : %d", sData.accountLevel or 1), 110, 70, Palette.C.yellow)
    UI.drawText(string.format("Or : %d  |  Gemmes : %d", sData.gold or 0, sData.gems or 0), 110, 88, Palette.C.white)
    UI.drawText(string.format("Progression : Chapitre %d", sData.selectedChapter or 1), 110, 106, Palette.C.leaf)
    UI.setFont("main")

    -- Bouton Gummy d'entrée de jeu (Pulsing Highlight)
    local pulse = 0.5 + 0.5 * math.sin(t * 4.0)
    local btnY = 168
    local btnH = 46
    local isHover = (pulse > 0.5)

    UI.drawPillButton(20, btnY, 280, btnH, "TOUCHER POUR JOUER  /  (A)", "emerald", false, "swords")

    -- Footer d'auteur
    UI.setFont("tiny")
    UI.drawTextAligned("Développé par TonyDeTony • v1.0.2", 0, 222, w, "center", { 0.55, 0.65, 0.80, 0.75 })
    UI.setFont("main")
end

function SplashState:startGame()
    Audio.playSfx("ui_confirm")
    self.sm:switch("menu")
end

function SplashState:touchpressed(id, x, y)
    self:startGame()
end

function SplashState:keypressed(key)
    if key == "a" or key == "return" or key == "space" or key == "start" then
        self:startGame()
    end
end

return SplashState
