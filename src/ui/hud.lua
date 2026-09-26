-- src/ui/hud.lua
-- Interface de combat de l'écran tactile (320x240), style jeu mobile pixel art :
-- barre de niveau, fiche héros, progression de salle, compétences acquises, ultime, choix de compétence.

local Config = require("src.data.config")
local Palette = require("src.render.palette")
local PixelFont = require("src.ui.pixel_font")
local Skin = require("src.ui.skin")
local Art = require("src.render.art")
local Icons = require("src.render.sprites.icons")
local HeroSprites = require("src.render.sprites.heroes")
local Heroes = require("src.data.heroes")
local Skills = require("src.data.skills")

local C = Palette.C
local floor = math.floor

local HUD = {}
HUD.__index = HUD

local RARITY_THEME = {
    common = "gray", uncommon = "green", rare = "blue", epic = "purple", legendary = "gold", forbidden = "red",
}
local MAX_SKILL_SLOTS = 12

function HUD.new()
    local self = setmetatable({}, HUD)
    self.displayXp = 0
    self.displayHp = 100
    self.coinAnim = 0
    self.ultPulse = 0

    self.cards = {
        { x = 8,   y = 46, w = 96, h = 156, hovered = false },
        { x = 112, y = 46, w = 96, h = 156, hovered = false },
        { x = 216, y = 46, w = 96, h = 156, hovered = false },
    }
    self.ultCircle = { cx = 160, cy = 200, radius = 25 }
    -- Bouton circulaire de Dash / roulade d'esquive
    self.dashCircle = { cx = 46, cy = 200, radius = 21 }
    return self
end

function HUD:update(dt, player, ultCharge)
    if player then
        local targetXp = player.xp / player.nextLevelXp
        self.displayXp = self.displayXp + (targetXp - self.displayXp) * math.min(1.0, dt * 10)
        self.displayHp = self.displayHp + (player.hp - self.displayHp) * math.min(1.0, dt * 12)
    end
    self.coinAnim = self.coinAnim + dt * 3
    if ultCharge >= 1.0 then
        self.ultPulse = self.ultPulse + dt * 8
    else
        self.ultPulse = 0
    end
end

function HUD:drawBackground()
    Skin.background(Config.BOTTOM_WIDTH, Config.BOTTOM_HEIGHT)
end

-- ============================================================================
-- EN-TÊTE : badge de niveau, barre d'XP, or
-- ============================================================================
function HUD:drawTopBar(player, gold)
    Skin.rect(C.ink, 0, 0, Config.BOTTOM_WIDTH, 33, 0.5)

    -- Badge de niveau
    Skin.disc(C.ink, 17, 16, 13)
    Skin.disc(C.navy, 17, 16, 12)
    Skin.disc(C.blue, 17, 15, 11)
    Skin.disc(C.cyan, 13, 10, 3, 0.5)
    local lvl = tostring(player.level or 1)
    PixelFont.printf(lvl, 4, 9, 27, "center", C.white, "main")

    -- Barre d'expérience
    PixelFont.print("NIVEAU", 36, 2, C.silver, "tiny")
    Skin.bar(34, 10, 198, 13, self.displayXp, "gold")
    local xpText = string.format("%d/%d", floor(player.xp or 0), player.nextLevelXp or 1)
    PixelFont.printf(xpText, 34, 14, 198, "center", C.white, "tiny")

    -- Or récolté
    love.graphics.setColor(1, 1, 1, 1)
    Art.draw("icon_coin", 1, 245, 16)
    PixelFont.print(tostring(floor(gold or 0)), 254, 11, C.yellow, "main")
end

function HUD:drawPauseButton(pb, pressed)
    local oy = Skin.button(pb.x, pb.y, pb.w, pb.h, "blue", pressed)
    love.graphics.setColor(1, 1, 1, 1)
    Art.draw("icon_pause", 1, pb.x + floor(pb.w / 2), pb.y + oy + floor((pb.h - 3) / 2))
end

-- ============================================================================
-- ZONE CENTRALE : fiche héros, salle, compétences acquises
-- ============================================================================
local function drawHeroPortrait(player, x, y)
    Skin.panel(x, y, 38, 42, "inset")
    Skin.rect(C.slate, x + 3, y + 3, 32, 14, 0.5)
    local heroId = player.heroId or "atreus"
    local variant = (heroId ~= "atreus") and heroId or nil
    local cx, bottom = x + 19, y + 40
    love.graphics.setColor(1, 1, 1, 1)
    Art.drawEx("hero_body", 1, cx, bottom, 0, 2, 2, false, variant)
    local acc = HeroSprites.ACCESSORY_BY_HERO[heroId]
    if acc then
        local offs = { feather = { 3, -14 }, mask = { -2, -8 }, crest = { 0, -15 }, horns = { 0, -13 }, tiara = { 0, -15 } }
        local o = offs[acc]
        Art.drawEx("hero_acc_" .. acc, 1, cx + o[1] * 2, bottom + o[2] * 2, 0, 2, 2)
    end
end

local function statLine(icon, text, x, y)
    love.graphics.setColor(1, 1, 1, 1)
    Art.draw(icon, 1, x + 5, y + 6)
    PixelFont.print(text, x + 12, y, C.white, "main")
end

function HUD:drawStatusArea(player, kills, waveNumber, chapterName, acquiredSkills)
    -- Fiche héros
    Skin.panel(4, 37, 152, 94, "dark")
    drawHeroPortrait(player, 9, 42)
    local hero = Heroes.get(player.heroId)
    PixelFont.print(hero.name:upper(), 52, 40, C.yellow, "main")

    local ratio = math.max(0, math.min(1, self.displayHp / math.max(1, player.maxHp)))
    Skin.bar(51, 55, 100, 12, ratio, ratio < 0.3 and "red" or "green", 5)
    PixelFont.printf(string.format("%d/%d", math.max(0, floor(player.hp)), player.maxHp), 51, 58, 100, "center", C.white, "tiny")

    local w = player.currentWeapon
    local dmg = floor(w.damage * (player.damageMult or 1.0))
    local arrows = (player.frontArrows or 1) + (player.diagArrows or 0) * 2 + (player.rearArrows or 0) + (player.sideArrows or 0) * 2
    statLine("icon_sword", tostring(dmg), 51, 71)
    statLine("icon_star", floor((player.critChance or 0) * 100) .. "%", 104, 71)
    statLine("icon_skill_multishot", "×" .. arrows, 51, 86)
    statLine("icon_skill_boots", floor((player.dodgeChance or 0) * 100) .. "%", 104, 86)
    PixelFont.printf(w.name:upper(), 9, 104, 142, "left", C.fog, "tiny")
    Skin.rect(C.slate, 9, 113, 142, 1)
    PixelFont.print("ÉLIMINATIONS", 9, 118, C.silver, "tiny")
    PixelFont.printf(tostring(kills or 0), 9, 116, 142, "right", C.white, "main")

    -- Progression de la salle
    local room = waveNumber or 1
    Skin.panel(160, 37, 156, 94, "dark")
    PixelFont.printf(chapterName or "Forêt Verdoyante", 164, 41, 148, "center", C.white, "main", 1, nil, 1)
    Skin.rect(C.slate, 166, 54, 144, 1)
    love.graphics.setColor(1, 1, 1, 1)
    Art.drawEx("icon_door", 1, 178, 72, 0, 2, 2)
    PixelFont.print("SALLE", 194, 60, C.silver, "tiny")
    PixelFont.print(tostring(room), 194, 64, C.white, "main", 2, "shadow")
    PixelFont.print("/ 50", 194 + PixelFont.getWidth(tostring(room), "main", 2) + 4, 74, C.fog, "main")

    local inChapter = ((room - 1) % 10) + 1
    Skin.bar(166, 92, 132, 10, inChapter / 10, "blue", 10)
    love.graphics.setColor(1, 1, 1, 1)
    Art.draw("icon_skull", 1, 306, 97)
    local toBoss = 10 - (room % 10)
    local bossText = (room % 10 == 0) and "COMBAT DE BOSS !" or string.format("BOSS DANS %d SALLES", toBoss)
    PixelFont.printf(bossText, 160, 110, 156, "center", (room % 10 == 0) and C.red or C.silver, "tiny")
    if room % 10 == 5 then
        PixelFont.printf("SANCTUAIRE DE L'ANGE", 160, 120, 156, "center", C.yellow, "tiny")
    end

    -- Compétences acquises
    Skin.panel(4, 134, 312, 38, "dark")
    PixelFont.print("COMPÉTENCES", 10, 137, C.silver, "tiny")
    local skills = acquiredSkills or {}
    PixelFont.printf(tostring(#skills), 10, 137, 300, "right", C.fog, "tiny")
    for i = 1, MAX_SKILL_SLOTS do
        local sx = 10 + (i - 1) * 25
        Skin.panel(sx, 146, 22, 22, "inset")
        local sk = skills[i]
        if sk then
            if i == MAX_SKILL_SLOTS and #skills > MAX_SKILL_SLOTS then
                PixelFont.printf("+" .. (#skills - MAX_SKILL_SLOTS + 1), sx, 151, 22, "center", C.white, "tiny")
            else
                local th = Skin.theme(RARITY_THEME[sk.rarity] or "gray")
                Skin.rect(th.main, sx + 2, 165, 18, 1)
                love.graphics.setColor(1, 1, 1, 1)
                Art.draw(Icons.skillIcon(sk.icon), 1, sx + 11, 156)
            end
        end
    end
end

-- ============================================================================
-- BAS DE L'ÉCRAN : esquive et ultime (anneaux de charge segmentés)
-- ============================================================================
local function ringGauge(cx, cy, r, ratio, lit, dim, segments)
    segments = segments or 28
    local n = floor(math.min(1, math.max(0, ratio)) * segments + 0.5)
    for i = 0, segments - 1 do
        local a = -math.pi / 2 + (i + 0.5) / segments * math.pi * 2
        local px = floor(cx + math.cos(a) * r + 0.5)
        local py = floor(cy + math.sin(a) * r + 0.5)
        Skin.rect(i < n and lit or dim, px - 1, py - 1, 3, 3)
    end
end

function HUD:drawCircularUltimate(ultCharge, player)
    local t = love.timer.getTime()
    Skin.rect(C.ink, 0, 174, Config.BOTTOM_WIDTH, 66, 0.35)

    -- 1. Esquive (Dash)
    if player then
        local dc = self.dashCircle
        local cd = player.dashCooldownTimer or 0
        local ready = cd <= 0
        local ratio = ready and 1 or (1 - cd / (player.dashCooldown or 1.5))
        Skin.disc(C.ink, dc.cx, dc.cy, dc.radius)
        ringGauge(dc.cx, dc.cy, dc.radius - 3, ratio, ready and C.cyan or C.blue, C.slate, 24)
        Skin.iconDisc(dc.cx, dc.cy, dc.radius - 6, ready and "blue" or "dark")
        love.graphics.setColor(1, 1, 1, 1)
        Art.drawEx("icon_bolt", 1, dc.cx, dc.cy, 0, 2, 2)
        if ready then
            PixelFont.printf("ESQUIVE", dc.cx - 40, dc.cy + dc.radius + 3, 80, "center", C.cyan, "tiny")
        else
            PixelFont.printf(string.format("%.1f s", cd), dc.cx - 40, dc.cy + dc.radius + 3, 80, "center", C.fog, "tiny")
        end
    end

    -- 2. Attaque ultime
    local uc = self.ultCircle
    local ready = ultCharge >= 1.0
    if ready then
        local pulse = floor((math.sin(self.ultPulse) + 1) * 2)
        Skin.disc(C.amber, uc.cx, uc.cy, uc.radius + 3 + pulse, 0.25)
    end
    Skin.disc(C.ink, uc.cx, uc.cy, uc.radius)
    ringGauge(uc.cx, uc.cy, uc.radius - 3, ultCharge, ready and C.yellow or C.cyan, C.slate, 32)
    Skin.iconDisc(uc.cx, uc.cy, uc.radius - 6, ready and "gold" or "dark")
    love.graphics.setColor(1, 1, 1, 1)
    local bob = ready and floor(math.sin(t * 6) * 1.5 + 0.5) or 0
    Art.drawEx("icon_star", 1, uc.cx, uc.cy + bob, 0, 2, 2)
    PixelFont.printf("ULTIME", uc.cx - 50, uc.cy + uc.radius + 3, 100, "center", ready and C.yellow or C.white, "tiny")

    -- 3. Charge en chiffres
    PixelFont.printf(ready and "PRÊT !" or (floor(math.min(1, ultCharge) * 100) .. "%"), 216, 190, 100, "center",
        ready and C.yellow or C.white, "main", 2, "shadow")
end

-- ============================================================================
-- ALERTE PV CRITIQUES
-- ============================================================================
function HUD:drawLowHpOverlay(player)
    if not player or player.hp <= 0 then return end
    if (player.hp / player.maxHp) >= 0.20 then return end
    local pulse = (math.sin(love.timer.getTime() * 9) + 1) * 0.5
    local a = 0.35 + pulse * 0.4
    local w, h = Config.BOTTOM_WIDTH, Config.BOTTOM_HEIGHT
    Skin.rect(C.red, 0, 0, w, 3, a)
    Skin.rect(C.red, 0, h - 3, w, 3, a)
    Skin.rect(C.red, 0, 0, 3, h, a)
    Skin.rect(C.red, w - 3, 0, 3, h, a)
end

-- ============================================================================
-- CHOIX DE COMPÉTENCE (montée de niveau)
-- ============================================================================
local function drawRays(cx, cy, t)
    local C2 = Palette.C.amber
    for i = 0, 11 do
        local a = t * 0.4 + i * math.pi / 6
        love.graphics.setColor(C2[1], C2[2], C2[3], 0.06)
        love.graphics.polygon("fill", cx, cy,
            cx + math.cos(a - 0.12) * 260, cy + math.sin(a - 0.12) * 260,
            cx + math.cos(a + 0.12) * 260, cy + math.sin(a + 0.12) * 260)
    end
end

function HUD:drawDraftModal(draftOptions, acquiredSkills)
    local W = Config.BOTTOM_WIDTH
    local t = love.timer.getTime()
    Skin.rect(C.ink, 0, 0, W, Config.BOTTOM_HEIGHT, 0.93)
    drawRays(W / 2, 18, t)

    Skin.ribbon(W / 2, 5, 244, 28, "gold")
    PixelFont.printf("NIVEAU SUPÉRIEUR !", 0, 6, W, "center", C.white, "main", 2, "shadow")
    PixelFont.printf("CHOISIS UNE COMPÉTENCE", 0, 37, W, "center", C.silver, "tiny")

    for i = 1, math.min(3, #draftOptions) do
        local skill = draftOptions[i]
        local card = self.cards[i]
        local x, y, w, h = card.x, card.y, card.w, card.h
        local themeName = RARITY_THEME[skill.rarity] or "gray"
        local th = Skin.theme(themeName)
        local rarity = Palette.rarity(skill.rarity)

        Skin.panel(x, y, w, h, "dark")
        Skin.roundRect(th.dark, x + 1, y + 1, w - 2, 15, 2)
        Skin.rect(th.main, x + 3, y + 1, w - 6, 13)
        Skin.rect(th.light, x + 3, y + 1, w - 6, 1)
        PixelFont.printf(rarity.name, x, y + 5, w, "center", C.white, "tiny")

        local bob = floor(math.sin(t * 3 + i) * 1.5 + 0.5)
        Skin.iconDisc(x + floor(w / 2), y + 38 + bob, 18, themeName)
        love.graphics.setColor(1, 1, 1, 1)
        Art.drawEx(Icons.skillIcon(skill.icon), 1, x + floor(w / 2), y + 38 + bob, 0, 2, 2)

        PixelFont.printf(skill.name, x + 3, y + 60, w - 6, "center", C.yellow, "main", 1, nil, 2, 11)
        Skin.rect(C.slate, x + 10, y + 84, w - 20, 1)
        PixelFont.printf(skill.desc, x + 4, y + 88, w - 8, "center", C.silver, "main", 1, nil, 4, 11)
        -- Compétence déjà possédée : la carte annonce le niveau atteint après la prise
        local owned = Skills.stackCount(acquiredSkills, skill.id)
        if owned > 0 then
            Skin.pill(x + 3, y + 18, 34, 12, "gold", "NV." .. (owned + 1), "tiny")
        end

        Skin.pill(x + floor(w / 2) - 10, y + h - 16, 20, 12, themeName, tostring(i), "tiny")
    end

    PixelFont.printf("TOUCHE UNE CARTE", 0, 212, W, "center", C.fog, "tiny")
end

-- ============================================================================
-- ZONES TACTILES
-- ============================================================================
function HUD:checkCardTouch(tx, ty)
    for i = 1, #self.cards do
        local c = self.cards[i]
        if tx >= c.x and tx <= c.x + c.w and ty >= c.y and ty <= c.y + c.h then
            return i
        end
    end
    return nil
end

function HUD:checkDashTouch(tx, ty)
    local dc = self.dashCircle
    local dx = tx - dc.cx
    local dy = ty - dc.cy
    return (dx * dx + dy * dy <= (dc.radius + 6) * (dc.radius + 6))
end

function HUD:checkUltimateTouch(tx, ty)
    local uc = self.ultCircle
    local dx = tx - uc.cx
    local dy = ty - uc.cy
    return (dx * dx + dy * dy <= (uc.radius + 6) * (uc.radius + 6))
end

return HUD
