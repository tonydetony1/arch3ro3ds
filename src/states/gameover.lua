-- src/states/gameover.lua
-- Écran de Game Over cinématique et stylé pour Nintendo 3DS (LÖVEPotion) & PC (LÖVE2D)
-- Top Screen (400x240) : Sépulture du Héros Déchu, Fantôme Chibi, Braises incandescentes & God Rays
-- Bottom Screen (320x240) : Rapport de Run Gummy, Statistiques (Étage, Kills, Or), et Boutons Tactiles 3D

local Config = require("src.data.config")
local Audio = require("src.audio.audio")
local Save = require("src.data.save")
local Items = require("src.data.items")
local UI = require("src.ui.ui_components")
local WorldManager = require("src.core.world_manager")

local Skin = require("src.ui.skin")
local Palette = require("src.render.palette")
local PixelFont = require("src.ui.pixel_font")
local Art = require("src.render.art")
local Icons = require("src.render.sprites.icons")
local GameOverState = {}
GameOverState.__index = GameOverState

function GameOverState.new(stateMachine)
    local self = setmetatable({}, GameOverState)
    self.sm = stateMachine
    self.data = {
        room = 1,
        goldEarned = 0,
        kills = 0,
        skills = {},
        mode = "ascension",
        isNewRecord = false,
        bestRoom = 1,
    }
    self.timer = 0
    self.pressedBtn = nil

    -- 28 Braises / Cendres rougeoyantes pré-allouées pour le Top Screen (Zéro allocation GC)
    self.embers = {}
    for i = 1, 28 do
        table.insert(self.embers, {
            x = math.random(4, Config.TOP_WIDTH - 4),
            y = math.random(-20, Config.TOP_HEIGHT),
            speedY = math.random(18, 38),
            driftSpeed = math.random(2, 5),
            driftAmp = math.random(4, 10),
            phase = (i / 28) * math.pi * 2,
            size = math.random(2, 4),
            rot = math.random() * math.pi * 2,
            rotSpeed = (math.random() > 0.5 and 1 or -1) * (math.random(10, 25) / 10),
            baseAlpha = math.random(35, 75) / 100,
            isFiery = (i % 2 == 0),
        })
    end

    -- Géométrie des boutons de l'écran tactile (320x240)
    self.buttons = {
        retry = { x = 14,  y = 190, w = 140, h = 42 },
        hub   = { x = 166, y = 190, w = 140, h = 42 },
    }

    return self
end

function GameOverState:enter(data)
    self.data = data or self.data
    self.timer = 0
    self.pressedBtn = nil

    -- Répartition aléatoire immédiate des braises
    for _, p in ipairs(self.embers) do
        p.x = math.random(4, Config.TOP_WIDTH - 4)
        p.y = math.random(0, Config.TOP_HEIGHT)
    end
end

function GameOverState:update(dt)
    self.timer = self.timer + dt

    -- Mise à jour des braises descendantes (sans allocation mémoire)
    for _, p in ipairs(self.embers) do
        p.y = p.y + p.speedY * dt
        p.rot = (p.rot + p.rotSpeed * dt) % (math.pi * 2)
        if p.y > Config.TOP_HEIGHT + 10 then
            p.y = math.random(-15, -4)
            p.x = math.random(4, Config.TOP_WIDTH - 4)
        end
    end
end

-- ============================================================================
-- TOP SCREEN (400x240) : MONUMENT DU HÉROS DÉCHU & AMBIANCE DRAMATIQUE
-- ============================================================================
function GameOverState:drawTop()
    local w = Config.TOP_WIDTH
    local h = Config.TOP_HEIGHT
    local t = love.timer.getTime()

    -- 1. Fond sombre nébuleux avec teinte sanglante
    love.graphics.setColor(0.08, 0.04, 0.06, 1.0)
    love.graphics.rectangle("fill", 0, 0, w, h)

    -- Vignette rouge sombre pulsante sur les contours
    local vignettePulse = 0.22 + 0.08 * math.sin(t * 2.6)
    love.graphics.setColor(0.65, 0.08, 0.12, vignettePulse)
    love.graphics.rectangle("line", 1, 1, w - 2, h - 2)
    love.graphics.rectangle("line", 3, 3, w - 6, h - 6)

    -- Halo mystique descendant sur la sépulture
    love.graphics.setColor(0.35, 0.15, 0.25, 0.25)
    love.graphics.circle("fill", w / 2, 130, 85)

    -- Rayons célestes spectraux descendants
    UI.drawGodRays(w / 2, 80, 190, 12, t * 0.4, {0.65, 0.25, 0.35, 0.14})

    -- 2. Pluie de braises et de cendres incandescentes
    for _, p in ipairs(self.embers) do
        local waveX = p.x + math.sin(t * p.driftSpeed + p.phase) * p.driftAmp
        local pulseAlpha = p.baseAlpha * (0.65 + 0.35 * math.sin(t * 3.5 + p.phase))

        if p.isFiery then
            love.graphics.setColor(1.0, 0.35, 0.10, pulseAlpha) -- Braise orange
        else
            love.graphics.setColor(0.95, 0.15, 0.20, pulseAlpha) -- Étincelle rouge sang
        end

        love.graphics.push()
        love.graphics.translate(waveX, p.y)
        love.graphics.rotate(p.rot)
        local s = p.size
        love.graphics.rectangle("fill", -s / 2, -s / 2, s, s)
        love.graphics.pop()
    end

    -- 3. Monument Central : Le Piédestal et l'Arme Plantée
    local mx = w / 2
    local my = 170

    -- Butte de terre et pierres moussues
    love.graphics.setColor(0.14, 0.12, 0.16, 1.0)
    love.graphics.ellipse("fill", mx, my + 8, 64, 18)
    love.graphics.setColor(0.24, 0.18, 0.22, 1.0)
    love.graphics.ellipse("line", mx, my + 8, 64, 18)

    -- Pierres funéraires
    love.graphics.setColor(0.22, 0.20, 0.26, 1.0)
    love.graphics.rectangle("fill", mx - 42, my + 2, 16, 10, 3, 3)
    love.graphics.rectangle("fill", mx + 26, my + 4, 18, 9, 3, 3)

    -- Épée brisée plantée en terre (Symbole de la chute)
    love.graphics.setColor(0.70, 0.75, 0.85, 1.0)
    love.graphics.rectangle("fill", mx - 2, my - 34, 4, 38, 1, 1)
    -- Garde de l'épée
    love.graphics.setColor(0.95, 0.75, 0.20, 1.0)
    love.graphics.rectangle("fill", mx - 12, my - 24, 24, 4, 2, 2)
    -- Pommeau
    love.graphics.circle("fill", mx, my - 36, 3.5)

    -- Cape émeraude nouée flottant mélancoliquement au vent
    local capeWave = math.sin(t * 3.4) * 3.5
    love.graphics.setColor(0.12, 0.45, 0.25, 0.90)
    love.graphics.polygon("fill", mx + 2, my - 22, mx + 18 + capeWave, my - 14, mx + 22 + capeWave, my - 2, mx + 2, my - 10)

    -- 4. Le Petit Fantôme / Ange Chibi du Héros (Volumétrique et Doux)
    local ghostY = my - 58 + math.sin(t * 2.8) * 3.5
    local ghostX = mx

    -- Halo doré céleste au-dessus de sa tête
    love.graphics.setColor(1.0, 0.88, 0.25, 0.75 + 0.25 * math.sin(t * 4.0))
    love.graphics.setLineWidth(1.8)
    love.graphics.ellipse("line", ghostX, ghostY - 18, 8, 3)
    love.graphics.setLineWidth(1)

    -- Petites ailes spectrales qui battent
    local wingFlap = math.sin(t * 6.5) * 4
    love.graphics.setColor(1, 1, 1, 0.75)
    love.graphics.ellipse("fill", ghostX - 11, ghostY - 4 + wingFlap * 0.3, 7, 3 + math.abs(wingFlap) * 0.4)
    love.graphics.ellipse("fill", ghostX + 11, ghostY - 4 - wingFlap * 0.3, 7, 3 + math.abs(wingFlap) * 0.4)

    -- Corps spectral vaporeux
    love.graphics.setColor(0.85, 0.92, 1.0, 0.85)
    love.graphics.circle("fill", ghostX, ghostY - 8, 9)
    love.graphics.polygon("fill", ghostX - 9, ghostY - 8, ghostX + 9, ghostY - 8, ghostX + 6, ghostY + 8, ghostX - 6, ghostY + 8)

    -- Yeux fermés paisibles (petits arcs)
    love.graphics.setColor(0.15, 0.20, 0.30, 1.0)
    love.graphics.arc("line", "open", ghostX - 3.5, ghostY - 9, 2.2, 0, math.pi)
    love.graphics.arc("line", "open", ghostX + 3.5, ghostY - 9, 2.2, 0, math.pi)

    -- 5. Title banner: where the hero fell (world of the room reached)
    local C = Palette.C
    local world = WorldManager.getChapter(WorldManager.worldOfRoom(self.data.room or 1))
    local subText = string.format("%s - ROOM %d", (world and world.name or "?"):upper(), self.data.room or 1)
    Skin.panel(mx - 150, 10, 300, 48, "dark")
    Skin.rect(C.wine, mx - 147, 11, 294, 2)
    PixelFont.printf("YOU HAVE FALLEN", mx - 150, 15, 300, "center", C.white, "main", 2)
    PixelFont.printf(subText, mx - 150, 40, 300, "center", C.pink, "main", 1, nil, 1)

    -- 6. New record badge
    if self.data.isNewRecord then
        Skin.pill(mx - 70, 64, 140, 18, "gold")
        PixelFont.printf("NEW RECORD!", mx - 70, 67, 140, "center", C.white, "main")
    end
end

-- ============================================================================
-- BOTTOM SCREEN (320x240): battle report and the two exits
-- ============================================================================
local REPORT_STATS = {
    { key = "room", label = "ROOM", icon = "icon_door", color = "white" },
    { key = "kills", label = "KILLS", icon = "icon_skull", color = "pink" },
    { key = "goldEarned", label = "GOLD", icon = "icon_coin", color = "yellow" },
}

-- Console button glyph and label centred in a button rectangle
local function buttonLabel(r, glyph, label, pressed)
    local C = Palette.C
    local w = 22 + PixelFont.getWidth(label, "main")
    local x = math.floor(r.x + (r.w - w) / 2)
    local y = math.floor(r.y + (r.h - 3 - 14) / 2) + (pressed and 2 or 0)
    Skin.disc(C.ink, x + 8, y + 7, 9)
    Skin.disc(C.slate, x + 8, y + 7, 8)
    PixelFont.printf(glyph, x + 1, y + 1, 15, "center", C.white, "main")
    PixelFont.print(label, x + 22, y + 1, C.white, "main")
end

function GameOverState:drawBottom()
    local C = Palette.C
    local botW, botH = Config.BOTTOM_WIDTH, Config.BOTTOM_HEIGHT
    Skin.background(botW, botH)
    Skin.panel(4, 4, botW - 8, 26, "dark")
    for i = 1, #REPORT_STATS do Skin.panel(4 + (i - 1) * 105, 34, 101, 54, "raised") end
    Skin.panel(4, 92, botW - 8, 92, "inset")
    local b1, b2 = self.buttons.retry, self.buttons.hub
    Skin.button(b1.x, b1.y, b1.w, b1.h, "green", self.pressedBtn == "retry")
    Skin.button(b2.x, b2.y, b2.w, b2.h, "blue", self.pressedBtn == "hub")

    love.graphics.setColor(1, 1, 1, 1)
    PixelFont.print("BATTLE REPORT", 12, 11, C.yellow, "main")
    local total = WorldManager.floorTotal(self.data.mode, self.data.room or 1)
    if total then PixelFont.printf("BEST " .. (self.data.bestRoom or 1) .. "/" .. total, 4, 11, botW - 16, "right", C.fog, "main") end
    for i, st in ipairs(REPORT_STATS) do
        local x = 4 + (i - 1) * 105
        Art.draw(st.icon, 1, x + 14, 46)
        PixelFont.print(st.label, x + 24, 40, C.fog, "main")
        local value = self.data[st.key] or 0
        PixelFont.printf((st.key == "goldEarned" and "+" or "") .. value, x, 58, 101, "center", C[st.color], "main", 2)
    end

    -- Skills of the run, grouped, two columns
    local skills = self.data.skills or {}
    if #skills == 0 then
        PixelFont.printf("NO SKILLS THIS RUN", 4, 132, botW - 8, "center", C.steel, "main")
    else
        local order, count = {}, {}
        for _, sk in ipairs(skills) do
            if not count[sk.id] then order[#order + 1] = sk end
            count[sk.id] = (count[sk.id] or 0) + 1
        end
        for i, sk in ipairs(order) do
            if i > 6 then
                PixelFont.printf("+" .. (#order - 6), 4, 170, botW - 16, "right", C.silver, "main")
                break
            end
            local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
            local sx, sy = 12 + col * 154, 98 + row * 26
            Art.draw(Icons.skillIcon(sk.icon), 1, sx + 8, sy + 10)
            PixelFont.printf(sk.name, sx + 20, sy + 4, 112, "left", C.white, "main", 1, nil, 1)
            if count[sk.id] > 1 then PixelFont.print("x" .. count[sk.id], sx + 134, sy + 4, C.yellow, "main") end
        end
    end
    buttonLabel(b1, "A", "RETRY", self.pressedBtn == "retry")
    buttonLabel(b2, "B", "MENU", self.pressedBtn == "hub")
end

-- ============================================================================
-- GESTION DES ENTRÉES TACTILES & MANETTE
-- ============================================================================
function GameOverState:touchpressed(id, tx, ty)
    for btnName, box in pairs(self.buttons) do
        if tx >= box.x and tx <= box.x + box.w and ty >= box.y and ty <= box.y + box.h then
            self.pressedBtn = btnName
            return true
        end
    end
    return false
end

function GameOverState:touchreleased(id, tx, ty)
    if self.pressedBtn then
        local box = self.buttons[self.pressedBtn]
        if box and tx >= box.x and tx <= box.x + box.w and ty >= box.y and ty <= box.y + box.h then
            if self.pressedBtn == "retry" then
                self:retryRun()
            elseif self.pressedBtn == "hub" then
                self:returnToHub()
            end
        end
        self.pressedBtn = nil
    end
end

-- Boutons physiques 3DS : A relance la partie, B retourne au hub
function GameOverState:gamepadpressed(joystick, button)
    self:keypressed(button)
end

function GameOverState:keypressed(key)
    if key == "a" or key == "space" or key == "return" then
        self:retryRun()
    elseif key == "b" or key == "escape" or key == "backspace" then
        self:returnToHub()
    end
end

function GameOverState:retryRun()
    local mode = self.data.mode or "ascension"
    self.sm:switch("game", { mode = mode })
end

function GameOverState:returnToHub()
    self.sm:switch("menu")
end

return GameOverState
