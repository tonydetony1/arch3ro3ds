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

    -- 5. Titre Imposant et Décoratif "VOUS AVEZ PÉRI"
    local bannerY = 16
    love.graphics.setColor(0.08, 0.10, 0.14, 0.85)
    love.graphics.rectangle("fill", mx - 130, bannerY, 260, 42, 8, 8)
    love.graphics.setColor(0.75, 0.18, 0.22, 1.0)
    love.graphics.setLineWidth(1.8)
    love.graphics.rectangle("line", mx - 130, bannerY, 260, 42, 8, 8)
    love.graphics.setLineWidth(1)

    -- Ailes dorées ornementales sur le bandeau
    love.graphics.setColor(1.0, 0.80, 0.20, 0.9)
    love.graphics.polygon("fill", mx - 136, bannerY + 21, mx - 124, bannerY + 8, mx - 124, bannerY + 34)
    love.graphics.polygon("fill", mx + 136, bannerY + 21, mx + 124, bannerY + 8, mx + 124, bannerY + 34)

    -- Main title with bloody drop shadow
    love.graphics.setFont(UI.getFont("title"))
    UI.drawTextAligned("YOU HAVE FALLEN", mx - 130, bannerY + 6, 260, "center", {1.0, 0.90, 0.88, 1.0}, {0.45, 0.05, 0.08, 1.0}, 2, 2)

    -- Melancholy subtitle
    love.graphics.setFont(UI.getFont("small"))
    local subText = (self.data.mode == "infinite")
        and string.format("Swallowed into the Abyss - Floor %d", self.data.room or 1)
        or string.format("Fallen in Emerald Plains - Room %d", self.data.room or 1)
    UI.drawTextAligned(subText, mx - 130, bannerY + 26, 260, "center", {0.80, 0.65, 0.70, 1.0}, {0.05, 0.02, 0.03, 1.0}, 1, 1)

    -- 6. New Record Badge
    if self.data.isNewRecord then
        local recPulse = 1.0 + math.sin(t * 5.0) * 0.06
        love.graphics.push()
        love.graphics.translate(mx, 76)
        love.graphics.scale(recPulse, recPulse)
        love.graphics.setColor(0.95, 0.72, 0.12, 1.0)
        love.graphics.rectangle("fill", -95, -9, 190, 18, 4, 4)
        love.graphics.setColor(1.0, 0.95, 0.40, 1.0)
        love.graphics.rectangle("line", -95, -9, 190, 18, 4, 4)
        love.graphics.setFont(UI.getFont("tiny"))
        UI.drawTextAligned("NEW PROGRESS RECORD!", -95, -7, 190, "center", {0.12, 0.08, 0.02, 1.0}, {1.0, 0.9, 0.4, 0.6}, 0, 0)
        love.graphics.pop()
    end

    love.graphics.setFont(UI.getFont("normal"))
end

-- ============================================================================
-- BOTTOM SCREEN (320x240) : RAPPORT DE BATAILLE TACTILE & BOUTONS GUMMY
-- ============================================================================
function GameOverState:drawBottom()
    local botW = Config.BOTTOM_WIDTH
    local botH = Config.BOTTOM_HEIGHT
    local t = love.timer.getTime()

    -- 1. Fond sombre bleu nuit avec cadre subtil
    love.graphics.setColor(0.06, 0.07, 0.10, 1.0)
    love.graphics.rectangle("fill", 0, 0, botW, botH)

    -- 2. Grande Carte "Rapport de Fin de Run" Gummy
    local cx, cy, cw, ch = 10, 8, 300, 174
    love.graphics.setColor(0.11, 0.13, 0.18, 1.0)
    love.graphics.rectangle("fill", cx, cy, cw, ch, 10, 10)
    -- Biseau brillant supérieur
    love.graphics.setColor(1, 1, 1, 0.08)
    love.graphics.rectangle("fill", cx + 2, cy + 2, cw - 4, 32, 8, 8)
    -- Bordure dorée / carmin
    love.graphics.setColor(0.65, 0.20, 0.25, 0.9)
    love.graphics.setLineWidth(1.8)
    love.graphics.rectangle("line", cx, cy, cw, ch, 10, 10)
    love.graphics.setLineWidth(1)

    -- Card Header
    love.graphics.setColor(0.18, 0.20, 0.28, 0.9)
    love.graphics.rectangle("fill", cx + 6, cy + 6, cw - 12, 24, 6, 6)
    love.graphics.setFont(UI.getFont("small"))
    UI.drawTextAligned("BATTLE REPORT", cx + 6, cy + 10, cw - 12, "center", {1.0, 0.88, 0.35, 1.0}, {0.05, 0.05, 0.08, 1.0}, 1, 1)

    -- 3. The 3 Stat Capsules (Room, Kills, Gold)
    local colW = 86
    local colGap = 8
    local startX = cx + 13
    local rowY = cy + 36

    -- A. Room Capsule
    love.graphics.setColor(0.15, 0.18, 0.24, 0.95)
    love.graphics.rectangle("fill", startX, rowY, colW, 46, 6, 6)
    love.graphics.setColor(0.28, 0.45, 0.70, 0.9)
    love.graphics.rectangle("line", startX, rowY, colW, 46, 6, 6)

    love.graphics.setFont(UI.getFont("tiny"))
    UI.drawTextAligned("ROOM", startX, rowY + 5, colW, "center", {0.65, 0.75, 0.90, 1.0})
    love.graphics.setFont(UI.getFont("title"))
    local roomStr = string.format("%d", self.data.room or 1)
    UI.drawTextAligned(roomStr, startX, rowY + 16, colW, "center", {1.0, 1.0, 1.0, 1.0}, {0.05, 0.1, 0.2, 1.0}, 1, 1)
    love.graphics.setFont(UI.getFont("tiny"))
    local total = WorldManager.floorTotal(self.data.mode, self.data.room or 1)
    if total then
        UI.drawTextAligned("/ " .. total, startX, rowY + 34, colW, "center", {0.5, 0.6, 0.75, 0.9})
    end

    -- B. Enemies Defeated Capsule
    local startX2 = startX + colW + colGap
    love.graphics.setColor(0.15, 0.18, 0.24, 0.95)
    love.graphics.rectangle("fill", startX2, rowY, colW, 46, 6, 6)
    love.graphics.setColor(0.70, 0.25, 0.30, 0.9)
    love.graphics.rectangle("line", startX2, rowY, colW, 46, 6, 6)

    love.graphics.setFont(UI.getFont("tiny"))
    UI.drawTextAligned("ENEMIES", startX2, rowY + 5, colW, "center", {0.90, 0.65, 0.70, 1.0})
    love.graphics.setFont(UI.getFont("title"))
    local killStr = string.format("%d", self.data.kills or 0)
    UI.drawTextAligned(killStr, startX2, rowY + 16, colW, "center", {1.0, 0.45, 0.45, 1.0}, {0.2, 0.05, 0.05, 1.0}, 1, 1)
    love.graphics.setFont(UI.getFont("tiny"))
    UI.drawTextAligned("defeated", startX2, rowY + 34, colW, "center", {0.75, 0.55, 0.60, 0.9})

    -- C. Gold Loot Capsule
    local startX3 = startX2 + colW + colGap
    love.graphics.setColor(0.15, 0.18, 0.24, 0.95)
    love.graphics.rectangle("fill", startX3, rowY, colW, 46, 6, 6)
    love.graphics.setColor(0.85, 0.65, 0.15, 0.9)
    love.graphics.rectangle("line", startX3, rowY, colW, 46, 6, 6)

    love.graphics.setFont(UI.getFont("tiny"))
    UI.drawTextAligned("GOLD LOOT", startX3, rowY + 5, colW, "center", {1.0, 0.88, 0.45, 1.0})

    -- Animated coin
    local coinPulse = 1.0 + math.sin(t * 4.0) * 0.08
    love.graphics.push()
    love.graphics.translate(startX3 + colW / 2, rowY + 22)
    love.graphics.scale(coinPulse, coinPulse)
    love.graphics.setColor(1.0, 0.82, 0.15, 1.0)
    love.graphics.circle("fill", 0, 0, 5)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("fill", -1.5, -1.5, 1.8)
    love.graphics.pop()

    love.graphics.setFont(UI.getFont("small"))
    local goldStr = string.format("+%d G", self.data.goldEarned or 0)
    UI.drawTextAligned(goldStr, startX3, rowY + 31, colW, "center", {1.0, 0.92, 0.35, 1.0}, {0.15, 0.10, 0.02, 1.0}, 1, 1)

    -- 4. Skills summary box
    local skillBoxY = cy + 88
    love.graphics.setColor(0.08, 0.10, 0.14, 0.9)
    love.graphics.rectangle("fill", cx + 8, skillBoxY, cw - 16, 76, 6, 6)
    love.graphics.setColor(0.18, 0.22, 0.30, 0.8)
    love.graphics.rectangle("line", cx + 8, skillBoxY, cw - 16, 76, 6, 6)

    love.graphics.setFont(UI.getFont("tiny"))
    UI.drawText("SKILLS ACQUIRED THIS RUN:", cx + 14, skillBoxY + 5, {0.75, 0.80, 0.90, 1.0})

    local skills = self.data.skills or {}
    if #skills == 0 then
        love.graphics.setFont(UI.getFont("small"))
        UI.drawTextAligned("No skills unlocked during this run.", cx + 8, skillBoxY + 32, cw - 16, "center", {0.45, 0.50, 0.60, 1.0})
    else
        local pillW = 86
        local pillH = 18
        local pGapX = 6
        local pGapY = 5
        local pCols = 3
        local pStartX = cx + 14
        local pStartY = skillBoxY + 22

        for i, sk in ipairs(skills) do
            if i <= 6 then
                local col = (i - 1) % pCols
                local row = math.floor((i - 1) / pCols)
                local px = pStartX + col * (pillW + pGapX)
                local py = pStartY + row * (pillH + pGapY)

                love.graphics.setColor(0.14, 0.20, 0.28, 0.95)
                love.graphics.rectangle("fill", px, py, pillW, pillH, 4, 4)
                love.graphics.setColor(0.30, 0.65, 0.95, 0.9)
                love.graphics.rectangle("line", px, py, pillW, pillH, 4, 4)

                -- Color bullet
                love.graphics.setColor(0.35, 0.85, 0.45, 1.0)
                love.graphics.circle("fill", px + 7, py + pillH / 2, 3)

                love.graphics.setFont(UI.getFont("tiny"))
                local sName = sk.name or "Skill"
                if #sName > 12 then sName = string.sub(sName, 1, 10) .. ".." end
                UI.drawText(sName, px + 14, py + 3, {0.92, 0.95, 1.0, 1.0})
            end
        end
    end

    -- 5. Action Gummy Buttons
    local b1 = self.buttons.retry
    local b2 = self.buttons.hub

    UI.drawGummyButton(b1.x, b1.y, b1.w, b1.h, "RETRY  (A)", "green", self.pressedBtn == "retry", "swords")
    UI.drawGummyButton(b2.x, b2.y, b2.w, b2.h, "MAIN MENU  (B)", "blue", self.pressedBtn == "hub", "shield")

    love.graphics.setFont(UI.getFont("normal"))
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
