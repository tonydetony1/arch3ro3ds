-- src/states/inventory.lua
-- Interface d'Inventaire et d'Équipement ergonomique Archero pour le Bottom Screen (320x240)
-- 6 Slots d'équipement entourant le Héros, Grille d'Inventaire avec Kinetic Scrolling,
-- Raretés 5 paliers colorées et Pop-up Modale détaillée d'Équipement / Amélioration

local Config = require("src.data.config")
local Save = require("src.data.save")
local Items = require("src.data.items")
local UI = require("src.ui.ui_components")
local Art = require("src.render.art")
local HeroSprites = require("src.render.sprites.heroes")
local Audio = require("src.audio.audio")

local Inventory = {}
Inventory.__index = Inventory

function Inventory.new()
    local self = setmetatable({}, Inventory)
    self.saveData = nil

    -- Défilement tactile à inertie (Hauteur vue = 108px)
    self.scroller = UI.newScroller(108, 120)

    -- Pop-up Modale d'objet sélectionné
    self.modalItem = nil
    self.modalItemId = nil
    self.modalSourceSlot = nil

    -- Détection appui court (Tap) vs glissement (Drag)
    self.touchStartX = 0
    self.touchStartY = 0
    self.hasDragged = false

    -- État des boutons pressés
    self.pressedBtn = nil

    -- 6 Equipped slots surrounding the hero
    self.slots = {
        { id = "weapon", name = "Weapon",  type = "weapon", x = 32,  y = 7,  w = 46, h = 37 },
        { id = "ring1",  name = "Ring 1",  type = "ring",   x = 8,   y = 46, w = 46, h = 37 },
        { id = "pet1",   name = "Pet 1",   type = "pet",    x = 56,  y = 46, w = 46, h = 37 },
        { id = "armor",  name = "Armor",   type = "armor",  x = 242, y = 7,  w = 46, h = 37 },
        { id = "pet2",   name = "Pet 2",   type = "pet",    x = 218, y = 46, w = 46, h = 37 },
        { id = "ring2",  name = "Ring 2",  type = "ring",   x = 266, y = 46, w = 46, h = 37 },
    }

    return self
end

function Inventory:refresh()
    self.saveData = Save.get()
    -- Calcul de la hauteur totale du contenu pour le scroller
    local itemCount = #(self.saveData.inventory or {})
    local rows = math.ceil(math.max(1, itemCount) / 4)
    local contentH = rows * 56 + 12
    self.scroller:setContentHeight(contentH)
end

function Inventory:update(dt)
    self.scroller:update(dt)
end

-- Vérifie si un objet est équipé dans l'un des 6 slots
function Inventory:isEquipped(itemId)
    return Save.isEquipped(itemId)
end

-- ============================================================================
-- RENDU PRINCIPAL DU PANNEAU INVENTAIRE (BOTTOM SCREEN 320x240)
-- ============================================================================
function Inventory:draw()
    if not self.saveData then self:refresh() end
    local t = love.timer.getTime()

    -- 1. HAUT DE L'ÉCRAN : LES 6 SLOTS ÉQUIPÉS ENCADRANT LE HÉROS
    self:drawEquippedSection(t)

    -- 2. BAS DE L'ÉCRAN : GRILLE DE SAC À DOS AVEC KINETIC SCROLLING
    self:drawBackpackSection()

    -- 3. MODALE POP-UP DÉTAILLÉE D'OBJET (SI OUVERTE)
    if self.modalItem then
        self:drawItemModal(t)
    end
end

-- Section supérieure : 6 Slots & Portrait du Héros
function Inventory:drawEquippedSection(t)
    -- Fond subtil de la section équipée (Bento Card)
    UI.drawBentoCard(4, 4, 312, 82, {
        r = 8,
        bg = {0.08, 0.10, 0.15, 0.96},
        borderColor = {0.18, 0.23, 0.33, 0.85},
    })

    -- 1. Les 6 Slots d'Équipement (Padding aéré & pas de chevauchement)
    for _, s in ipairs(self.slots) do
        local itemId = self.saveData.equipped[s.id]
        local item = itemId and Items.get(itemId)
        local lvl = itemId and (self.saveData.itemLevels[itemId] or 1) or 0

        if item then
            local effRarity = Save.getItemRarity(itemId)
            UI.drawItemCard(s.x, s.y, s.w, s.h, item, lvl, false, false, effRarity)

            -- Libellé du slot aéré avec micro-pastille sombre protectrice au bas
            local fontTiny = UI.getFont("tiny")
            local prevFont = love.graphics.getFont()
            love.graphics.setFont(fontTiny)

            love.graphics.setColor(0.06, 0.08, 0.12, 0.75)
            love.graphics.rectangle("fill", s.x + 3, s.y + s.h - 11, s.w - 6, 9, 2, 2)
            UI.drawTextAligned(s.name, s.x, s.y + s.h - 11, s.w, "center", {0.85, 0.90, 0.98, 0.90}, {0.02, 0.03, 0.05, 0.9}, 1, 1)

            love.graphics.setFont(prevFont)
        else
            -- Emplacement vide Bento
            UI.drawBentoCard(s.x, s.y, s.w, s.h, {
                r = 6,
                bg = {0.09, 0.11, 0.16, 0.85},
                borderColor = {0.18, 0.22, 0.32, 0.70},
            })

            -- Icône silhouette discrète
            UI.drawItemIcon(s.type, s.x + s.w / 2, s.y + 14, 10, {0.35, 0.40, 0.50, 0.6})

            -- Libellé du slot vide sous l'icône silhouette
            local fontTiny = UI.getFont("tiny")
            local prevFont = love.graphics.getFont()
            love.graphics.setFont(fontTiny)
            UI.drawTextAligned(s.name, s.x, s.y + s.h - 11, s.w, "center", {0.60, 0.65, 0.75, 0.85}, {0.04, 0.05, 0.08, 0.8}, 1, 1)
            love.graphics.setFont(prevFont)
        end
    end

    -- 2. Carte Centrale : Vitrine du Héros & Statistiques Globales (Bento Card)
    local hx, hy, hw, hh = 108, 7, 104, 76
    UI.drawBentoCard(hx, hy, hw, hh, {
        r = 7,
        bg = {0.11, 0.14, 0.20, 0.98},
        borderColor = {0.22, 0.28, 0.40, 0.85},
        isElevated = true,
    })

    -- Portrait pixel du héros équipé (respiration)
    local bob = math.floor(math.sin(t * 3.0) * 1.5 + 0.5)
    local heroCx = hx + hw / 2
    local heroBottom = hy + 36 + bob

    love.graphics.setColor(0.04, 0.05, 0.08, 0.4)
    love.graphics.ellipse("fill", heroCx, hy + 37, 14, 5)

    local heroId = self.saveData.selectedHero or "atreus"
    local variant = (heroId ~= "atreus") and heroId or nil
    love.graphics.setColor(1, 1, 1, 1)
    Art.drawEx("hero_legs", 1, heroCx, heroBottom, 0, 1, 1)
    Art.drawEx("hero_body", 1, heroCx, heroBottom - 4, 0, 1, 1, false, variant)
    local acc = HeroSprites.ACCESSORY_BY_HERO[heroId]
    if acc then
        local offs = { feather = { 3, -14 }, mask = { -2, -8 }, crest = { 0, -15 }, horns = { 0, -13 }, tiara = { 0, -15 } }
        local o = offs[acc]
        Art.drawEx("hero_acc_" .. acc, 1, heroCx + o[1], heroBottom - 4 + o[2], 0, 1, 1)
    end

    -- Titre "HÉROS"
    local fontSmall = UI.getFont("small")
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(fontSmall)
    UI.drawTextAligned("ARCHER LV." .. (self.saveData.accountLevel or 1), hx, hy + 38, hw, "center", {1.0, 0.88, 0.25, 1.0}, {0.08, 0.10, 0.14, 1.0})

    -- Calcul des stats cumulées
    local totalAtk = 0
    local totalHp = 100
    for _, slot in ipairs(self.slots) do
        local id = self.saveData.equipped[slot.id]
        if id then
            local lvl = self.saveData.itemLevels[id] or 1
            local st = Items.getStats(id, lvl, Save.getItemRarity(id), Save.getItemStars(id))
            totalAtk = totalAtk + st.atk
            totalHp = totalHp + st.hp
        end
    end

    -- Badges ATQ et PV aérés
    love.graphics.setColor(0.85, 0.22, 0.22, 0.9)
    love.graphics.rectangle("fill", hx + 4, hy + 54, 46, 15, 3, 3)
    UI.drawTextAligned("ATK " .. totalAtk, hx + 4, hy + 55, 46, "center", {1, 1, 1, 1}, {0.1, 0.05, 0.05, 1.0})

    love.graphics.setColor(0.18, 0.75, 0.35, 0.9)
    love.graphics.rectangle("fill", hx + 54, hy + 54, 46, 15, 3, 3)
    UI.drawTextAligned("HP " .. totalHp, hx + 54, hy + 55, 46, "center", {1, 1, 1, 1}, {0.05, 0.1, 0.05, 1.0})
    love.graphics.setFont(prevFont)
end

-- Section inférieure : Sac à Dos & Grille avec Scissor
function Inventory:drawBackpackSection()
    local sx, sy, sw, sh = 4, 88, 312, 108

    -- Bannière Bento du Sac à dos
    UI.drawBentoCard(sx, sy, sw, sh, {
        r = 8,
        bg = {0.08, 0.10, 0.15, 0.96},
        borderColor = {0.18, 0.23, 0.33, 0.85},
    })

    local count = #(self.saveData.inventory or {})
    local fontSmall = UI.getFont("small")
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(fontSmall)
    UI.drawText(string.format("BACKPACK (%d ITEM%s)", count, count > 1 and "S" or ""), sx + 8, sy + 4, {0.80, 0.85, 0.95, 1.0}, {0.08, 0.10, 0.14, 1.0})
    love.graphics.setFont(prevFont)

    -- ZONE DE CISEAUX POUR LE KINETIC SCROLLER
    love.graphics.setScissor(sx + 2, sy + 18, sw - 4, sh - 20)

    local offsetY = self.scroller:getOffset()
    local startY = sy + 20 + offsetY

    local cols = 4
    local cardW = 70
    local cardH = 48
    local gapX = 6
    local gapY = 6
    local originX = sx + 7

    for i, itemId in ipairs(self.saveData.inventory) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local cx = originX + col * (cardW + gapX)
        local cy = startY + row * (cardH + gapY)

        -- Ne dessine que les cartes visibles
        if cy + cardH >= sy + 18 and cy <= sy + sh then
            local item = Items.get(itemId)
            local lvl = self.saveData.itemLevels[itemId] or 1
            local isEq = self:isEquipped(itemId)
            local isSel = (self.modalItemId == itemId)
            local effRarity = Save.getItemRarity(itemId)

            UI.drawItemCard(cx, cy, cardW, cardH, item, lvl, isEq, isSel, effRarity)
        end
    end

    love.graphics.setScissor()

    -- Indicateur de défilement (Scrollbar subtile)
    local totalContentH = self.scroller.contentH
    if totalContentH > (sh - 20) then
        local barH = math.max(12, math.floor(((sh - 20) / totalContentH) * (sh - 20)))
        local progress = (-self.scroller.offsetY) / math.max(1, totalContentH - (sh - 20))
        local barY = sy + 20 + progress * ((sh - 20) - barH)
        love.graphics.setColor(0.35, 0.40, 0.55, 0.6)
        love.graphics.rectangle("fill", sx + sw - 6, barY, 3, barH, 2, 2)
    end
end

-- ============================================================================
-- MODALE POP-UP DÉTAILLÉE D'OBJET (ÉQUIPER / AMÉLIORER)
-- ============================================================================
function Inventory:drawItemModal(t)
    local botW = Config.BOTTOM_WIDTH
    local botH = Config.BOTTOM_HEIGHT

    -- 1. Overlay sombre
    love.graphics.setColor(0.04, 0.05, 0.08, 0.82)
    love.graphics.rectangle("fill", 0, 0, botW, botH)

    -- 2. Carte Modale Bento Grid 2026
    local mx, my, mw, mh = 22, 10, 276, 186
    local item = self.modalItem
    local itemId = self.modalItemId
    local lvl = self.saveData.itemLevels[itemId] or 1
    local effRarity = Save.getItemRarity(itemId)
    local rData = Items.getRarityData(effRarity)
    local copies = Save.getItemCopies(itemId)
    local canFuse = (copies >= 3) and (rData.tier < 5)

    -- Cadre Bento principal avec bordure subtile aux teintes de la rareté
    UI.drawBentoCard(mx, my, mw, mh, {
        r = 10,
        bg = {0.08, 0.10, 0.15, 0.98},
        borderColor = {rData.border[1], rData.border[2], rData.border[3], 0.85},
        borderWidth = 1,
        accentColor = rData.color,
    })

    -- Bandeau supérieur d'accentuation de rareté (Subtle Sheen)
    love.graphics.setColor(rData.bg[1], rData.bg[2], rData.bg[3], 0.35)
    love.graphics.rectangle("fill", mx + 1, my + 1, mw - 2, 38, 9, 9)
    love.graphics.setColor(1, 1, 1, 0.08)
    love.graphics.rectangle("fill", mx + 8, my + 2, mw - 16, 1, 1, 1)

    -- Bouton de fermeture tactile stylisé
    love.graphics.setColor(0.18, 0.22, 0.30, 0.90)
    love.graphics.circle("fill", mx + mw - 16, my + 18, 9)
    love.graphics.setColor(0.85, 0.30, 0.30, 1.0)
    love.graphics.setLineWidth(1.6)
    love.graphics.line(mx + mw - 20, my + 14, mx + mw - 12, my + 22)
    love.graphics.line(mx + mw - 12, my + 14, mx + mw - 20, my + 22)
    love.graphics.setLineWidth(1)

    -- Icône et Nom de l'objet avec Drop Shadow
    UI.drawItemIcon(item.icon, mx + 22, my + 20, 15, rData.color)
    UI.drawText(item.name, mx + 44, my + 8, {1, 1, 1, 1}, {0.08, 0.10, 0.14, 1.0})

    -- Badge Pillule de rareté, niveau et copies possédées
    UI.drawPillBadge(mx + 44, my + 23, 76, 15, string.format("%s LV.%d", rData.name, lvl), {0.12, 0.15, 0.22, 0.9}, rData.color, rData.color)
    UI.drawText(string.format("Copies: %d/3", copies), mx + 126, my + 24, {0.60, 0.70, 0.85, 0.9}, {0.05, 0.08, 0.12, 1.0})

    -- Statistiques Actuelles et Prochain Niveau dans une sous-carte Bento
    local curStats = Items.getStats(itemId, lvl, effRarity, Save.getItemStars(itemId))
    local nextStats = Items.getStats(itemId, lvl + 1, effRarity, Save.getItemStars(itemId))
    local upgradeCost = Items.getUpgradeCost(lvl, effRarity)
    local canUpgrade = (self.saveData.gold >= upgradeCost)

    UI.drawBentoCard(mx + 8, my + 44, mw - 16, 32, {
        r = 6,
        bg = {0.05, 0.07, 0.11, 0.90},
        borderColor = {0.16, 0.22, 0.32, 0.60},
    })

    local statStr = ""
    if curStats.atk > 0 then
        statStr = statStr .. string.format("ATK: %d (+%d)  ", curStats.atk, nextStats.atk - curStats.atk)
    end
    if curStats.hp > 0 then
        statStr = statStr .. string.format("HP: %d (+%d)  ", curStats.hp, nextStats.hp - curStats.hp)
    end
    if curStats.crit > 0 then
        statStr = statStr .. string.format("Crit: +%d%%  ", curStats.crit)
    end
    if curStats.dodge > 0 then
        statStr = statStr .. string.format("Dodge: +%d%%  ", curStats.dodge)
    end

    local fontSmall = UI.getFont("small")
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(fontSmall)
    UI.drawTextAligned(statStr, mx + 8, my + 48, mw - 16, "center", {0.35, 0.95, 0.55, 1.0}, {0.04, 0.08, 0.04, 1.0})
    UI.drawTextAligned(item.desc, mx + 10, my + 62, mw - 20, "center", {0.80, 0.85, 0.95, 1.0}, {0.04, 0.05, 0.07, 1.0})
    love.graphics.setFont(prevFont)

    -- 3. Passives list
    local py = my + 80
    local tiers = {
        { id = "uncommon", name = "Great",     minTier = 2 },
        { id = "rare",     name = "Rare",      minTier = 3 },
        { id = "epic",     name = "Epic",      minTier = 4 },
        { id = "legendary",name = "Legendary", minTier = 5 },
    }

    UI.drawBentoCard(mx + 8, py, mw - 16, 56, {
        r = 6,
        bg = {0.05, 0.07, 0.11, 0.90},
        borderColor = {0.16, 0.22, 0.32, 0.60},
    })

    local currentTier = rData.tier
    love.graphics.setFont(fontSmall)
    for i, tInfo in ipairs(tiers) do
        local pInfo = item.passives and item.passives[tInfo.id]
        if pInfo then
            local isUnlocked = (currentTier >= tInfo.minTier)
            local lineY = py + (i - 1) * 13 + 3
            local pColor = isUnlocked and Items.getRarityData(tInfo.id).color or {0.45, 0.48, 0.55, 0.8}
            local iconLock = isUnlocked and "check" or "lock"

            UI.drawIcon(iconLock, mx + 16, lineY + 6, 8, pColor)
            UI.drawText(string.format("[%s] %s : %s", tInfo.name, pInfo.name, pInfo.desc), mx + 24, lineY, pColor, {0.02, 0.03, 0.05, 0.8}, 1, 1)
        end
    end
    love.graphics.setFont(prevFont)

    -- 4. Action buttons: EQUIP, UPGRADE, FUSE
    local btnY = my + 142
    local isCurrentlyEquipped = self:isEquipped(itemId)
    local slotType = item.slot
    local isDualSlot = (slotType == "ring" or slotType == "pet")
    local bothOccupied = isDualSlot and not isCurrentlyEquipped and not self.modalSourceSlot
        and (self.saveData.equipped[slotType .. "1"] ~= nil)
        and (self.saveData.equipped[slotType .. "2"] ~= nil)

    if isCurrentlyEquipped then
        local equipText = "UNEQUIP"
        local equipTheme = "red"
        if canFuse then
            UI.drawPillButton(mx + 6, btnY, 78, 36, equipText, equipTheme, self.pressedBtn == "equip")
            local upText = string.format("%d G", upgradeCost)
            UI.drawPillButton(mx + 88, btnY, 88, 36, upText, canUpgrade and "blue" or "gray", self.pressedBtn == "upgrade", "shield")
            UI.drawPillButton(mx + 180, btnY, 90, 36, "FUSE", "gold", self.pressedBtn == "fuse", "sparkles")
        else
            UI.drawPillButton(mx + 8, btnY, 126, 36, equipText, equipTheme, self.pressedBtn == "equip")
            local upText = string.format("UPGRADE (%d G)", upgradeCost)
            local upTheme = canUpgrade and "gold" or "gray"
            UI.drawPillButton(mx + 142, btnY, 126, 36, upText, upTheme, self.pressedBtn == "upgrade")
        end
    elseif bothOccupied and not canFuse then
        -- Offre au joueur le choix direct de l'emplacement à remplacer (Anneau 1/2 ou Familier 1/2)
        UI.drawPillButton(mx + 6, btnY, 62, 36, "SLOT 1", "green", self.pressedBtn == "equip1")
        UI.drawPillButton(mx + 72, btnY, 62, 36, "SLOT 2", "green", self.pressedBtn == "equip2")
        local upText = string.format("%d G", upgradeCost)
        local upTheme = canUpgrade and "gold" or "gray"
        UI.drawPillButton(mx + 138, btnY, 130, 36, upText, upTheme, self.pressedBtn == "upgrade")
    else
        local equipText = "EQUIP"
        if self.modalSourceSlot then
            equipText = "EQUIP (" .. self.modalSourceSlot:upper() .. ")"
        end
        local equipTheme = "green"
        if canFuse then
            UI.drawPillButton(mx + 6, btnY, 78, 36, equipText, equipTheme, self.pressedBtn == "equip")
            local upText = string.format("%d G", upgradeCost)
            UI.drawPillButton(mx + 88, btnY, 88, 36, upText, canUpgrade and "blue" or "gray", self.pressedBtn == "upgrade", "shield")
            UI.drawPillButton(mx + 180, btnY, 90, 36, "FUSE", "gold", self.pressedBtn == "fuse", "sparkles")
        else
            UI.drawPillButton(mx + 8, btnY, 126, 36, equipText, equipTheme, self.pressedBtn == "equip")
            local upText = string.format("UPGRADE (%d G)", upgradeCost)
            local upTheme = canUpgrade and "gold" or "gray"
            UI.drawPillButton(mx + 142, btnY, 126, 36, upText, upTheme, self.pressedBtn == "upgrade")
        end
    end
end

-- ============================================================================
-- GESTION TACTILE DU PANNEAU D'INVENTAIRE (STYLUS / TOUCH)
-- ============================================================================
function Inventory:touchpressed(id, tx, ty)
    self.touchStartX = tx
    self.touchStartY = ty
    self.hasDragged = false

    -- 1. Si la modale est ouverte
    if self.modalItem then
        local mx, my, mw, mh = 22, 10, 276, 186
        local copies = Save.getItemCopies(self.modalItemId)
        local effRarity = Save.getItemRarity(self.modalItemId)
        local rData = Items.getRarityData(effRarity)
        local canFuse = (copies >= 3) and (rData.tier < 5)
        local isCurrentlyEquipped = self:isEquipped(self.modalItemId)
        local slotType = self.modalItem and self.modalItem.slot
        local isDualSlot = (slotType == "ring" or slotType == "pet")
        local bothOccupied = isDualSlot and not isCurrentlyEquipped and not self.modalSourceSlot
            and (self.saveData.equipped[slotType .. "1"] ~= nil)
            and (self.saveData.equipped[slotType .. "2"] ~= nil)

        -- Clic sur fermer
        if tx >= mx + mw - 24 and tx <= mx + mw and ty >= my and ty <= my + 24 then
            self:closeModal()
            return true
        end

        local btnY = my + 142
        if bothOccupied and not canFuse then
            if tx >= mx + 6 and tx <= mx + 68 and ty >= btnY and ty <= btnY + 36 then
                self.pressedBtn = "equip1"
                return true
            elseif tx >= mx + 72 and tx <= mx + 134 and ty >= btnY and ty <= btnY + 36 then
                self.pressedBtn = "equip2"
                return true
            elseif tx >= mx + 138 and tx <= mx + 268 and ty >= btnY and ty <= btnY + 36 then
                self.pressedBtn = "upgrade"
                return true
            end
        elseif canFuse then
            if tx >= mx + 6 and tx <= mx + 84 and ty >= btnY and ty <= btnY + 36 then
                self.pressedBtn = "equip"
                return true
            elseif tx >= mx + 88 and tx <= mx + 176 and ty >= btnY and ty <= btnY + 36 then
                self.pressedBtn = "upgrade"
                return true
            elseif tx >= mx + 180 and tx <= mx + 270 and ty >= btnY and ty <= btnY + 36 then
                self.pressedBtn = "fuse"
                return true
            end
        else
            if tx >= mx + 8 and tx <= mx + 134 and ty >= btnY and ty <= btnY + 36 then
                self.pressedBtn = "equip"
                return true
            elseif tx >= mx + 142 and tx <= mx + 268 and ty >= btnY and ty <= btnY + 36 then
                self.pressedBtn = "upgrade"
                return true
            end
        end

        -- Clic hors de la modale pour fermer
        if tx < mx or tx > mx + mw or ty < my or ty > my + mh then
            self:closeModal()
            return true
        end
        return true
    end

    -- 2. Clic sur l'un des 6 slots équipés du haut
    for _, s in ipairs(self.slots) do
        if tx >= s.x and tx <= s.x + s.w and ty >= s.y and ty <= s.y + s.h then
            local itemId = self.saveData.equipped[s.id]
            if itemId then
                self:openModal(itemId, s.id)
            else
                -- Emplacement vide : chercher un objet disponible de ce type dans le sac à dos
                local candidate = nil
                for _, invId in ipairs(self.saveData.inventory or {}) do
                    local it = Items.get(invId)
                    if it and it.slot == s.type and not self:isEquipped(invId) then
                        candidate = invId
                        break
                    end
                end
                if candidate then
                    self:openModal(candidate, s.id)
                    Audio.play("ui_click", 0.05, 0.7)
                else
                    Audio.play("ui_cancel", 0, 0.6)
                end
            end
            return true
        end
    end

    -- 3. Début de défilement ou sélection dans le sac à dos
    if ty >= 88 and ty <= 196 then
        self.scroller:touchDown(tx, ty)
    end
    return false
end

function Inventory:touchmoved(id, tx, ty, dx, dy)
    if self.modalItem then return end

    local distSq = (tx - self.touchStartX)^2 + (ty - self.touchStartY)^2
    if distSq > 196 then
        self.hasDragged = true
    end

    if ty >= 88 and ty <= 196 or self.scroller.isDragging then
        self.scroller:touchMove(tx, ty)
    end
end

function Inventory:touchreleased(id, tx, ty)
    -- 1. Relâchement dans la modale
    if self.modalItem then
        local mx, my, mw, mh = 22, 10, 276, 186
        local btnY = my + 142

        if self.pressedBtn == "equip" then
            self:toggleEquip(self.modalItemId, self.modalSourceSlot)
            self.pressedBtn = nil
            self:closeModal()
            self:refresh()
            return
        elseif self.pressedBtn == "equip1" then
            local slotType = self.modalItem and self.modalItem.slot
            self:toggleEquip(self.modalItemId, slotType .. "1")
            self.pressedBtn = nil
            self:closeModal()
            self:refresh()
            return
        elseif self.pressedBtn == "equip2" then
            local slotType = self.modalItem and self.modalItem.slot
            self:toggleEquip(self.modalItemId, slotType .. "2")
            self.pressedBtn = nil
            self:closeModal()
            self:refresh()
            return
        elseif self.pressedBtn == "upgrade" then
            local lvl = self.saveData.itemLevels[self.modalItemId] or 1
            local effRarity = Save.getItemRarity(self.modalItemId)
            local cost = Items.getUpgradeCost(lvl, effRarity)
            if self.saveData.gold >= cost then
                Save.addGold(-cost)
                self.saveData.itemLevels[self.modalItemId] = lvl + 1
                Save.save()
                self:refresh()
                Audio.play("upgrade", 0.05, 0.8)
            else
                Audio.play("ui_cancel", 0, 0.6)
            end
            self.pressedBtn = nil
            return
        elseif self.pressedBtn == "fuse" then
            local ok, newRar = Save.fuseItem(self.modalItemId)
            if ok then
                self:refresh()
                self.modalItem = Items.get(self.modalItemId)
                Audio.play("chest_reveal", 0, 0.9)
            end
            self.pressedBtn = nil
            return
        end
        self.pressedBtn = nil
        return
    end

    -- 2. Fin de scroll dans la grille
    self.scroller:touchUp(tx, ty)

    -- Si c'était un tap bref sans drag dans la grille : sélection de l'objet !
    if not self.hasDragged and ty >= 106 and ty <= 196 then
        local sx = 4
        local sy = 88
        local offsetY = self.scroller:getOffset()
        local startY = sy + 20 + offsetY

        local cols = 4
        local cardW = 70
        local cardH = 48
        local gapX = 6
        local gapY = 6
        local originX = sx + 7

        for i, itemId in ipairs(self.saveData.inventory) do
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            local cx = originX + col * (cardW + gapX)
            local cy = startY + row * (cardH + gapY)

            if tx >= cx and tx <= cx + cardW and ty >= cy and ty <= cy + cardH then
                self:openModal(itemId, nil)
                return
            end
        end
    end
end

function Inventory:openModal(itemId, sourceSlot)
    self.modalItemId = itemId
    self.modalItem = Items.get(itemId)
    self.modalSourceSlot = sourceSlot
    self.pressedBtn = nil
end

function Inventory:closeModal()
    self.modalItem = nil
    self.modalItemId = nil
    self.modalSourceSlot = nil
    self.pressedBtn = nil
end

function Inventory:toggleEquip(itemId, sourceSlot)
    local item = Items.get(itemId)
    if not item then return end

    local isEq, equippedSlot = Save.isEquipped(itemId)
    if isEq then
        -- L'objet est déjà équipé : on le déséquipe
        local slotToUnequip = sourceSlot or equippedSlot
        Save.unequip(slotToUnequip)
        self:refresh()
        return
    end

    -- L'objet n'est pas équipé : on détermine le bon emplacement selon son type
    local slotType = item.slot
    local targetSlot = nil

    if sourceSlot and Save.EQUIP_SLOTS[sourceSlot] then
        if (slotType == "weapon" and sourceSlot == "weapon")
            or (slotType == "armor" and sourceSlot == "armor")
            or (slotType == "ring" and (sourceSlot == "ring1" or sourceSlot == "ring2"))
            or (slotType == "pet" and (sourceSlot == "pet1" or sourceSlot == "pet2")) then
            targetSlot = sourceSlot
        end
    end

    if not targetSlot then
        if slotType == "weapon" then
            targetSlot = "weapon"
        elseif slotType == "armor" then
            targetSlot = "armor"
        elseif slotType == "ring" then
            if self.saveData.equipped.ring1 == nil then
                targetSlot = "ring1"
            elseif self.saveData.equipped.ring2 == nil then
                targetSlot = "ring2"
            else
                -- Si les deux sont occupés, on remplace le premier
                targetSlot = "ring1"
            end
        elseif slotType == "pet" then
            if self.saveData.equipped.pet1 == nil then
                targetSlot = "pet1"
            elseif self.saveData.equipped.pet2 == nil then
                targetSlot = "pet2"
            else
                -- Si les deux sont occupés, on remplace le premier
                targetSlot = "pet1"
            end
        end
    end

    if targetSlot then
        Save.equip(targetSlot, itemId)
        self:refresh()
    end
end

-- Support manette / boutons physiques 3DS
function Inventory:gamepadpressed(button)
    if self.modalItem then
        if button == "b" then
            self:closeModal()
            Audio.play("ui_cancel", 0, 0.7)
            return true
        elseif button == "a" then
            self:toggleEquip(self.modalItemId, self.modalSourceSlot)
            self:closeModal()
            self:refresh()
            Audio.play("ui_confirm", 0, 0.8)
            return true
        elseif button == "x" then
            local lvl = self.saveData.itemLevels[self.modalItemId] or 1
            local effRarity = Save.getItemRarity(self.modalItemId)
            local cost = Items.getUpgradeCost(lvl, effRarity)
            if self.saveData.gold >= cost then
                Save.addGold(-cost)
                self.saveData.itemLevels[self.modalItemId] = lvl + 1
                Save.save()
                self:refresh()
                Audio.play("upgrade", 0.05, 0.8)
            else
                Audio.play("ui_cancel", 0, 0.6)
            end
            return true
        elseif button == "y" then
            local copies = Save.getItemCopies(self.modalItemId)
            local effRarity = Save.getItemRarity(self.modalItemId)
            local rData = Items.getRarityData(effRarity)
            if copies >= 3 and rData.tier < 5 then
                local ok = Save.fuseItem(self.modalItemId)
                if ok then
                    self:refresh()
                    self.modalItem = Items.get(self.modalItemId)
                    Audio.play("chest_reveal", 0, 0.9)
                end
            end
            return true
        end
        return true
    end
    return false
end

-- Support clavier PC (Flèches, Entrée, Espace, Échap)
function Inventory:keypressed(key)
    if self.modalItem then
        if key == "escape" or key == "backspace" then
            self:closeModal()
            Audio.play("ui_cancel", 0, 0.7)
            return true
        elseif key == "return" or key == "space" or key == "e" then
            self:toggleEquip(self.modalItemId, self.modalSourceSlot)
            self:closeModal()
            self:refresh()
            Audio.play("ui_confirm", 0, 0.8)
            return true
        elseif key == "u" then
            local lvl = self.saveData.itemLevels[self.modalItemId] or 1
            local effRarity = Save.getItemRarity(self.modalItemId)
            local cost = Items.getUpgradeCost(lvl, effRarity)
            if self.saveData.gold >= cost then
                Save.addGold(-cost)
                self.saveData.itemLevels[self.modalItemId] = lvl + 1
                Save.save()
                self:refresh()
                Audio.play("upgrade", 0.05, 0.8)
            else
                Audio.play("ui_cancel", 0, 0.6)
            end
            return true
        end
        return true
    end
    return false
end

return Inventory
