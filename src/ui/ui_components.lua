-- src/ui/ui_components.lua
-- Design System pixel art partagé par tous les écrans (menus, forge, salles spéciales).
-- Mêmes fonctions qu'avant : le style change, pas l'API.
--   * typographie  -> src/ui/pixel_font.lua (police maison, accents, contour)
--   * panneaux/boutons/jauges -> src/ui/skin.lua (kit "gummy" pixel)
--   * icônes et objets -> atlas pixel art (src/render/art.lua)

local Config = require("src.data.config")
local ItemsData = require("src.data.items")
local Palette = require("src.render.palette")
local PixelFont = require("src.ui.pixel_font")
local Skin = require("src.ui.skin")
local Art = require("src.render.art")
local ItemSprites = require("src.render.sprites.items")

local UI = {}

local C = Palette.C
local floor = math.floor

-- ============================================================================
-- 1. POLICES (conservées pour compatibilité : le rendu passe par PixelFont)
-- ============================================================================
UI.fonts = nil

function UI.initFonts()
    if not UI.fonts and love.graphics then
        UI.fonts = {
            tiny   = love.graphics.newFont(8),
            small  = love.graphics.newFont(9),
            normal = love.graphics.newFont(12),
            title  = love.graphics.newFont(14),
        }
    end
end

function UI.getFont(name)
    UI.initFonts()
    if UI.fonts then
        return UI.fonts[name] or UI.fonts.normal
    end
    return love.graphics and love.graphics.getFont()
end

-- Police pixel courante : "tiny" pour les libellés compacts, "main" sinon
UI.fontName = "main"

function UI.setFont(name)
    UI.fontName = (name == "tiny") and "tiny" or "main"
end

function UI.textHeight(name)
    return PixelFont.lineHeight(name or UI.fontName)
end

function UI.textWidth(text, name)
    return PixelFont.getWidth(text, name or UI.fontName)
end

-- ============================================================================
-- 2. TYPOGRAPHIE (contour intégré + ombre portée optionnelle)
-- ============================================================================
function UI.drawText(text, x, y, textColor, shadowColor, ox, oy)
    PixelFont.print(tostring(text or ""), x, y, textColor or C.white, UI.fontName, 1, shadowColor and "shadow" or nil)
end

function UI.drawTextAligned(text, x, y, limit, align, textColor, shadowColor, ox, oy)
    PixelFont.printf(tostring(text or ""), x, y, limit or 200, align or "center",
        textColor or C.white, UI.fontName, 1, shadowColor and "shadow" or nil)
end

function UI.printOutlined(text, x, y, textColor, outlineColor, outlineWidth)
    PixelFont.print(tostring(text or ""), x, y, textColor or C.white, UI.fontName, 1)
end

function UI.printfOutlined(text, x, y, limit, align, textColor, outlineColor, outlineWidth)
    PixelFont.printf(tostring(text or ""), x, y, limit or 200, align or "center", textColor or C.white, UI.fontName, 1)
end

-- Titre : police agrandie 2x avec ombre
function UI.drawTitle(text, x, y, limit, align, color)
    PixelFont.printf(tostring(text or ""), x, y, limit or Config.TOP_WIDTH, align or "center", color or C.yellow, "main", 2, "shadow")
end

-- ============================================================================
-- 3. ICÔNES D'INTERFACE
-- ============================================================================
local ICON_SPRITES = {
    gold = "icon_coin", coin = "icon_coin", gem = "icon_gem", gems = "icon_gem",
    heart = "icon_heart", hp = "icon_heart", energy = "icon_bolt", bolt = "icon_bolt",
    swords = "icon_sword", sword = "icon_sword", attack = "icon_sword",
    skull = "icon_skull", kills = "icon_skull", pause = "icon_pause",
    star = "icon_star", sparkles = "icon_star", rune = "icon_star",
    gear = "icon_gear", settings = "icon_gear",
    door = "icon_door", room = "icon_door", lock = "icon_lock", check = "icon_check",
    shield = "icon_skill_shield", hero = "icon_skill_boots", boots = "icon_skill_boots",
    chest = "icon_door", fuse = "icon_star", upgrade = "icon_star", equip = "icon_check",
    crit = "icon_skill_crit", speed = "icon_skill_speed", heal = "icon_skill_heal",
    multishot = "icon_skill_multishot", ricochet = "icon_skill_ricochet", damage = "icon_skill_damage",
    meteor = "icon_skill_meteor", swords_fly = "icon_skill_swords",
    arrow_left = "icon_arrow_l", arrow_right = "icon_arrow_r", prev = "icon_arrow_l", next = "icon_arrow_r",
}

-- iconType : identifiant logique ; size : hauteur souhaitée (l'échelle est entière)
function UI.drawIcon(iconType, cx, cy, size, color)
    if not iconType then return end
    local name = ICON_SPRITES[iconType]
    if not name or not Art.has(name) then
        name = "icon_star"
    end
    local frame = Art.frame(name, 1)
    local scale = 1
    if size and frame then
        scale = math.max(1, floor((size + 2) / frame.h + 0.5))
    end
    -- Les icônes pixel portent déjà leurs couleurs : seule l'opacité est reprise
    love.graphics.setColor(1, 1, 1, (color and color[4]) or 1)
    Art.drawEx(name, 1, floor(cx), floor(cy), 0, scale, scale)
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- 4. BOUTONS, CARTES ET PASTILLES
-- ============================================================================
local THEME_ALIASES = {
    emerald = "green", green = "green", sapphire = "blue", blue = "blue",
    gold = "gold", amber = "gold", violet = "purple", purple = "purple",
    ruby = "red", red = "red", gray = "gray", grey = "gray", dark = "dark",
}

local function themeOf(name)
    return THEME_ALIASES[name or "green"] or "green"
end

function UI.drawGummyButton(x, y, w, h, text, themeName, isPressed, iconType)
    local theme = themeOf(themeName)
    local oy = Skin.button(x, y, w, h, theme, isPressed)
    local label = text or ""
    local compact = (w <= 76 and h >= 30)

    if iconType and compact then
        UI.drawIcon(iconType, x + w / 2, y + oy + 11, 11)
        PixelFont.printf(label, x, y + oy + 18, w, "center", C.white, "tiny")
    elseif iconType then
        local tw = PixelFont.getWidth(label, "main")
        local total = tw + 20
        local tx = floor(x + (w - total) / 2)
        UI.drawIcon(iconType, tx + 7, y + oy + floor(h / 2) - 1, 11)
        PixelFont.print(label, tx + 20, y + oy + floor((h - 13) / 2), C.white, "main")
    elseif label ~= "" then
        PixelFont.printf(label, x, y + oy + floor((h - 13) / 2), w, "center", C.white, "main")
    end
end

function UI.drawBentoCard(x, y, w, h, options)
    options = options or {}
    local style = options.inset and "inset" or "dark"
    Skin.panel(x, y, w, h, style)
    if options.accentColor then
        local a = options.accentColor
        love.graphics.setColor(a[1], a[2], a[3], a[4] or 1)
        love.graphics.rectangle("fill", x + 4, y + 1, w - 8, 2)
        love.graphics.setColor(1, 1, 1, 1)
    elseif options.borderColor then
        local b = options.borderColor
        love.graphics.setColor(b[1], b[2], b[3], (b[4] or 1) * 0.9)
        love.graphics.rectangle("line", x + 1, y + 1, w - 2, h - 2)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function UI.drawPillButton(x, y, w, h, text, themeName, isPressed, iconType)
    local theme = themeOf(themeName)
    local oy = Skin.button(x, y, w, h, theme, isPressed)
    local label = text or ""

    if iconType and (label == "" ) then
        UI.drawIcon(iconType, x + w / 2, y + oy + floor(h / 2) - 1, math.min(w, h) - 6)
    elseif iconType and w <= 76 and h >= 24 then
        UI.drawIcon(iconType, x + w / 2, y + oy + 8, 9)
        PixelFont.printf(label, x, y + oy + 14, w, "center", C.white, "tiny")
    elseif iconType then
        local tw = PixelFont.getWidth(label, "main")
        local tx = floor(x + (w - (tw + 19)) / 2)
        UI.drawIcon(iconType, tx + 6, y + oy + floor(h / 2) - 1, 10)
        PixelFont.print(label, tx + 19, y + oy + floor((h - 13) / 2), C.white, "main")
    else
        PixelFont.printf(label, x, y + oy + floor((h - 13) / 2), w, "center", C.white, "main")
    end
end

function UI.drawPillBadge(x, y, w, h, text, bgColor, borderColor, textColor, iconType)
    Skin.roundRect(C.ink, x, y, w, h, 3)
    if bgColor then
        Skin.roundRect(bgColor, x + 1, y + 1, w - 2, h - 2, 2, bgColor[4])
    else
        Skin.roundRect(C.night, x + 1, y + 1, w - 2, h - 2, 2)
    end
    if borderColor then
        love.graphics.setColor(borderColor[1], borderColor[2], borderColor[3], borderColor[4] or 0.9)
        love.graphics.rectangle("line", x + 1, y + 1, w - 2, h - 2)
        love.graphics.setColor(1, 1, 1, 1)
    end

    local ty = y + floor((h - 8) / 2) -- tiny caps: 6 px + 1 px outline above and below
    if iconType then
        UI.drawIcon(iconType, x + 8, y + floor(h / 2), 9)
        PixelFont.printf(text or "", x + 12, ty, w - 16, "center", textColor or C.white, "tiny")
    else
        PixelFont.printf(text or "", x, ty, w, "center", textColor or C.white, "tiny")
    end
end

-- Jauge horizontale (XP, PV, progression) — thème identique aux boutons
function UI.drawBar(x, y, w, h, ratio, themeName, segments)
    Skin.bar(x, y, w, h, ratio, themeOf(themeName), segments)
end

-- ============================================================================
-- 5. ICÔNES D'OBJETS & CARTES D'INVENTAIRE
-- ============================================================================
function UI.drawItemIcon(iconType, cx, cy, size, rarityColor)
    local map = ItemSprites.ICON_MAP[iconType or "bow"] or ItemSprites.ICON_MAP.bow
    local frame = Art.frame(map.sprite, 1)
    local scale = 1
    if size and frame then
        scale = math.max(1, floor((size * 2) / frame.h + 0.5))
    end
    love.graphics.setColor(1, 1, 1, 1)
    Art.drawEx(map.sprite, 1, floor(cx), floor(cy), 0, scale, scale, false, map.variant)
end

function UI.drawItemCard(x, y, w, h, item, level, isEquipped, isSelected, rarityOverride)
    local curRarity = rarityOverride or (item and item.rarity) or "common"
    local rData = ItemsData.getRarityData(curRarity)
    local t = love.timer.getTime()
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)

    -- Fond teinté par la rareté
    Skin.roundRect(C.ink, x, y, w, h, 3)
    Skin.roundRect(rData.bg, x + 1, y + 1, w - 2, h - 2, 2)
    love.graphics.setColor(1, 1, 1, 0.07)
    love.graphics.rectangle("fill", x + 3, y + 2, w - 6, floor(h * 0.35))

    -- Cadre : pulsant si sélectionné ou légendaire
    local border = rData.border
    if isSelected then
        local pulse = (math.sin(t * 8) + 1) * 0.5
        love.graphics.setColor(1.0, 0.85 + pulse * 0.15, 0.2, 1.0)
    elseif curRarity == "legendary" then
        local pulse = (math.sin(t * 6) + 1) * 0.5
        love.graphics.setColor(1.0, 0.78 + pulse * 0.2, 0.15, 1.0)
    else
        love.graphics.setColor(border[1], border[2], border[3], 1.0)
    end
    love.graphics.rectangle("line", x + 1, y + 1, w - 2, h - 2)
    love.graphics.setColor(1, 1, 1, 1)

    -- Icône de l'objet
    UI.drawItemIcon(item and item.icon or "bow", x + w / 2, y + floor(h * 0.46), math.min(w, h) * 0.30, rData.color)

    -- Badge de niveau
    if level and level > 0 then
        local lvlStr = "LV." .. level
        local bw = math.max(18, PixelFont.getWidth(lvlStr, "tiny") + 6)
        Skin.roundRect(C.ink, x + 3, y + 3, bw, 9, 2)
        PixelFont.printf(lvlStr, x + 3, y + 5, bw, "center", C.yellow, "tiny")
    end

    -- Bandeau "ÉQUIPÉ"
    if isEquipped then
        local bh = 10
        local by = y + h - bh - 3
        Skin.roundRect(C.pine, x + 3, by, w - 6, bh, 2)
        Skin.rect(C.leaf, x + 4, by + 1, w - 8, 1)
        PixelFont.printf("EQUIPPED", x + 3, by + 3, w - 6, "center", C.white, "tiny")
    end
end

-- ============================================================================
-- 6. RAYONS DE LUMIÈRE (GACHA, SALLES SPÉCIALES)
-- ============================================================================
function UI.drawGodRays(cx, cy, radius, numRays, angle, rayColor)
    numRays = numRays or 14
    radius = radius or 160
    angle = angle or 0
    local color = rayColor or { 1.0, 0.85, 0.3, 0.25 }

    local step = (math.pi * 2) / numRays
    local halfStep = step * 0.45

    for i = 1, numRays do
        local a1 = angle + (i - 1) * step
        local a2 = a1 + halfStep
        love.graphics.setColor(color[1], color[2], color[3], color[4] or 0.25)
        love.graphics.polygon("fill", cx, cy,
            cx + math.cos(a1) * radius, cy + math.sin(a1) * radius,
            cx + math.cos(a2) * radius, cy + math.sin(a2) * radius)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- 6. DÉFILEMENT TACTILE AVEC INERTIE (KINETIC SCROLLER)
-- ============================================================================
local KineticScroller = {}
KineticScroller.__index = KineticScroller

function UI.newScroller(viewH, contentH)
    local self = setmetatable({}, KineticScroller)
    self.offsetY = 0
    self.velocity = 0
    self.viewH = viewH or 120
    self.contentH = contentH or 200
    self.minY = math.min(0, self.viewH - self.contentH)
    self.maxY = 0

    self.isDragging = false
    self.dragStartY = 0
    self.dragStartOffset = 0
    self.lastMoveY = 0
    self.lastMoveTime = 0
    return self
end

function KineticScroller:setContentHeight(contentH)
    self.contentH = math.max(self.viewH, contentH)
    self.minY = math.min(0, self.viewH - self.contentH)
end

function KineticScroller:update(dt)
    if not self.isDragging then
        -- 1. Application de la vitesse d'inertie
        if math.abs(self.velocity) > 0.5 then
            self.offsetY = self.offsetY + self.velocity * dt
            self.velocity = self.velocity * math.max(0, 1.0 - dt * 7.5)
        else
            self.velocity = 0
        end

        -- 2. Rebond élastique doux (Rubber-banding) si dépassement des bornes
        if self.offsetY > self.maxY then
            local diff = self.maxY - self.offsetY
            self.offsetY = self.offsetY + diff * math.min(1.0, dt * 14)
            self.velocity = self.velocity * 0.4
        elseif self.offsetY < self.minY then
            local diff = self.minY - self.offsetY
            self.offsetY = self.offsetY + diff * math.min(1.0, dt * 14)
            self.velocity = self.velocity * 0.4
        end
    end
end

function KineticScroller:touchDown(x, y)
    self.isDragging = true
    self.dragStartY = y
    self.dragStartOffset = self.offsetY
    self.lastMoveY = y
    self.lastMoveTime = love.timer.getTime()
    self.velocity = 0
end

function KineticScroller:touchMove(x, y)
    if self.isDragging then
        local deltaY = y - self.dragStartY
        local now = love.timer.getTime()
        local timeDelta = math.max(0.001, now - self.lastMoveTime)

        -- Calcul de la vitesse instantanée pour l'inertie
        self.velocity = (y - self.lastMoveY) / timeDelta
        self.lastMoveY = y
        self.lastMoveTime = now

        -- Résistance élastique si on tire hors des limites
        local targetOffset = self.dragStartOffset + deltaY
        if targetOffset > self.maxY then
            targetOffset = self.maxY + (targetOffset - self.maxY) * 0.35
        elseif targetOffset < self.minY then
            targetOffset = self.minY + (targetOffset - self.minY) * 0.35
        end

        self.offsetY = targetOffset
    end
end

function KineticScroller:touchUp(x, y)
    self.isDragging = false
    -- Limite de vitesse maximale pour éviter des défilements trop brusques
    self.velocity = math.max(-600, math.min(600, self.velocity))
end

function KineticScroller:getOffset()
    return math.floor(self.offsetY)
end

UI.KineticScroller = KineticScroller

return UI
