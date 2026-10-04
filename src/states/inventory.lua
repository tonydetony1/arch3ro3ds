-- src/states/inventory.lua
-- Interface d'Inventaire et d'Équipement ergonomique Archero pour le Bottom Screen (320x240)
-- 6 Slots d'équipement entourant le Héros, Grille d'Inventaire avec Kinetic Scrolling,
-- Raretés 5 paliers colorées et Pop-up Modale détaillée d'Équipement / Amélioration
--
-- Règles d'équipement (src/data/save.lua) : chaque emplacement n'accepte que son type
-- d'objet ; un anneau ou un familier va dans le premier emplacement libre, ou dans celui
-- que le joueur a touché, ou, les deux étant pris, dans celui qu'il choisit (RING 1 / RING 2).
-- Les boutons de la modale sont calculés une fois (rebuildModalButtons) : le dessin et la
-- détection tactile lisent la même liste, ils ne peuvent plus diverger.

local Config = require("src.data.config")
local Save = require("src.data.save")
local Items = require("src.data.items")
local UI = require("src.ui.ui_components")
local Art = require("src.render.art")
local PixelFont = require("src.ui.pixel_font")
local HeroSprites = require("src.render.sprites.heroes")
local Audio = require("src.audio.audio")
local Screen = require("src.core.screen")

local Inventory = {}
Inventory.__index = Inventory

-- Modale d'objet
local MODAL_X, MODAL_Y, MODAL_W, MODAL_H = 22, 10, 276, 186
local CLOSE_SIZE = 24
local BTN_Y, BTN_H = MODAL_Y + 142, 36
local BTN_LEFT, BTN_SPAN, BTN_GAP = MODAL_X + 6, MODAL_W - 12, 4

-- Sac à dos (grille défilante)
local GRID_X, GRID_Y, GRID_W, GRID_H = 4, 88, 312, 108
local GRID_VIEW_TOP, GRID_VIEW_BOTTOM = GRID_Y + 18, GRID_Y + GRID_H - 2
local GRID_COLS, CARD_W, CARD_H, GAP_X, GAP_Y = 4, 70, 48, 6, 6
local GRID_ORIGIN_X = GRID_X + 7
local GRID_ORIGIN_Y = GRID_Y + 20

local TAP_SLOP_SQ = 196 -- au-delà de 14 px de déplacement, l'appui devient un défilement
local RELEASE_SLOP = 8  -- tolérance du relâchement autour d'un bouton
local TOAST_TIME = 1.6

Inventory.SLOT_LABELS = {
    weapon = "WEAPON", armor = "ARMOR", ring1 = "RING 1", ring2 = "RING 2", pet1 = "PET 1", pet2 = "PET 2",
}
local TYPE_LABELS = { weapon = "WEAPON", armor = "ARMOR", ring = "RING", pet = "PET" }

-- Le ciseau se règle en pixels de la fenêtre, sans tenir compte de la translation : sur PC,
-- l'écran du bas est dessiné décalé sous celui du haut (sur 3DS, il a son propre tampon)
local function setLocalScissor(x, y, w, h)
    if Screen.is3DS then
        love.graphics.setScissor(x, y, w, h)
    else
        love.graphics.setScissor(x + Screen.PC_BOT_OFFSET_X, y + Screen.PC_BOT_OFFSET_Y, w, h)
    end
end

local function restoreScissor(px, py, pw, ph)
    if px then love.graphics.setScissor(px, py, pw, ph) else love.graphics.setScissor() end
end

local function inside(r, x, y, slop)
    slop = slop or 0
    return x >= r.x - slop and x <= r.x + r.w + slop and y >= r.y - slop and y <= r.y + r.h + slop
end

function Inventory.new()
    local self = setmetatable({}, Inventory)
    self.saveData = nil

    -- Défilement tactile à inertie (Hauteur vue = 108px)
    self.scroller = UI.newScroller(108, 120)

    -- Pop-up Modale d'objet sélectionné
    self.modalItem = nil
    self.modalItemId = nil
    self.modalSourceSlot = nil -- emplacement touché pour ouvrir la modale (cible de l'équipement)
    self.modalButtons = {}

    -- Emplacement vide touché alors que plusieurs objets peuvent y aller : le prochain
    -- objet compatible touché dans le sac y sera équipé
    self.targetSlot = nil

    -- Message bref affiché à la place du titre du sac (objet équipé, or insuffisant...)
    self.toastText = nil
    self.toastTimer = 0

    -- Détection appui court (Tap) vs glissement (Drag)
    self.touchStartX = 0
    self.touchStartY = 0
    self.hasDragged = false

    -- Élément sous le stylet ("slot_<id>", identifiant de bouton, "close", "outside")
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
    local rows = math.ceil(math.max(1, itemCount) / GRID_COLS)
    local contentH = rows * 56 + 12
    self.scroller:setContentHeight(contentH)
    if self.modalItemId then self:rebuildModalButtons() end
end

function Inventory:update(dt)
    self.scroller:update(dt)
    if self.toastTimer > 0 then
        self.toastTimer = math.max(0, self.toastTimer - dt)
    end
end

-- Vérifie si un objet est équipé dans l'un des 6 slots
function Inventory:isEquipped(itemId)
    return Save.isEquipped(itemId)
end

function Inventory:showToast(text)
    self.toastText = text
    self.toastTimer = TOAST_TIME
end

function Inventory:getSlot(slotId)
    for _, s in ipairs(self.slots) do
        if s.id == slotId then return s end
    end
    return nil
end

-- Objets du sac qui peuvent aller dans un emplacement de ce type sans être déjà portés
function Inventory:candidatesFor(slotType)
    local list = {}
    for _, invId in ipairs(self.saveData.inventory or {}) do
        local it = Items.get(invId)
        if it and it.slot == slotType and not Save.isEquipped(invId) then
            list[#list + 1] = invId
        end
    end
    return list
end

-- Position d'une carte du sac (dessin et détection tactile)
local function cardPosition(index, offsetY)
    local col = (index - 1) % GRID_COLS
    local row = math.floor((index - 1) / GRID_COLS)
    return GRID_ORIGIN_X + col * (CARD_W + GAP_X), GRID_ORIGIN_Y + offsetY + row * (CARD_H + GAP_Y)
end

-- Objet du sac sous le point touché (seulement dans la fenêtre visible de la grille)
function Inventory:itemAt(tx, ty)
    if ty < GRID_VIEW_TOP or ty > GRID_VIEW_BOTTOM then return nil end
    local offsetY = self.scroller:getOffset()
    for i, itemId in ipairs(self.saveData.inventory or {}) do
        local cx, cy = cardPosition(i, offsetY)
        if tx >= cx and tx <= cx + CARD_W and ty >= cy and ty <= cy + CARD_H then
            return itemId
        end
    end
    return nil
end

-- ============================================================================
-- MODALE : BOUTONS D'ACTION
-- ============================================================================
-- Emplacement où ira l'objet si le joueur appuie sur EQUIP : celui qui a ouvert la modale
-- s'il convient, sinon l'unique emplacement du type ou le premier libre. nil quand les
-- deux emplacements d'anneau (ou de familier) sont pris : le joueur choisit.
function Inventory:defaultTargetSlot(itemId)
    local item = Items.get(itemId)
    local slots = item and Save.SLOTS_BY_TYPE[item.slot]
    if not slots then return nil end
    local source = self.modalSourceSlot
    if source and Save.slotAccepts(source, itemId) then return source end
    if #slots == 1 then return slots[1] end
    for _, s in ipairs(slots) do
        if self.saveData.equipped[s] == nil then return s end
    end
    return nil
end

local function fitLabel(long, short, w)
    if PixelFont.getWidth(long, "main") <= w - 10 then return long end
    return short
end

function Inventory:rebuildModalButtons()
    local list = {}
    local itemId = self.modalItemId
    local item = self.modalItem
    self.modalButtons = list
    if not item then return end

    local isEq, eqSlot = Save.isEquipped(itemId)
    if isEq then
        list[#list + 1] = { id = "unequip", slot = eqSlot, label = "UNEQUIP", theme = "red" }
    else
        local target = self:defaultTargetSlot(itemId)
        if target then
            list[#list + 1] = { id = "equip", slot = target, label = "EQUIP", theme = "green" }
        else
            for _, s in ipairs(Save.SLOTS_BY_TYPE[item.slot] or {}) do
                list[#list + 1] = { id = "equip_" .. s, slot = s, label = Inventory.SLOT_LABELS[s], theme = "green" }
            end
        end
    end

    local canFuse = Save.canFuse(itemId)
    local count = #list + 1 + (canFuse and 1 or 0)
    local w = math.floor((BTN_SPAN - BTN_GAP * (count - 1)) / count)
    local cost = Save.getUpgradeCost(itemId)
    local upgrade = { id = "upgrade", theme = (self.saveData.gold >= cost) and "gold" or "gray" }
    if count <= 2 then
        upgrade.label = fitLabel(string.format("UPGRADE (%d G)", cost), string.format("%d G", cost), w)
    else
        upgrade.label, upgrade.icon = string.format("%d G", cost), "shield"
    end
    list[#list + 1] = upgrade
    if canFuse then
        list[#list + 1] = { id = "fuse", label = "FUSE", theme = "violet", icon = "sparkles" }
    end

    for i, b in ipairs(list) do
        b.x, b.y, b.w, b.h = BTN_LEFT + (i - 1) * (w + BTN_GAP), BTN_Y, w, BTN_H
    end
end

function Inventory:getModalButton(id)
    for _, b in ipairs(self.modalButtons) do
        if b.id == id then return b end
    end
    return nil
end

-- Exécute l'action d'un bouton de la modale
function Inventory:runAction(b)
    local itemId = self.modalItemId
    if b.id == "unequip" then
        if Save.unequip(b.slot) then
            Audio.play("ui_cancel", 0, 0.7)
            self:showToast("UNEQUIPPED FROM " .. Inventory.SLOT_LABELS[b.slot])
        end
        self:closeModal()
    elseif b.slot then
        if Save.equip(b.slot, itemId) then
            Audio.play("ui_confirm", 0, 0.8)
            self:showToast("EQUIPPED IN " .. Inventory.SLOT_LABELS[b.slot])
        else
            Audio.play("ui_cancel", 0, 0.6)
        end
        self:closeModal()
    elseif b.id == "upgrade" then
        local ok, newLevel, cost = Save.upgradeItem(itemId)
        if ok then
            Audio.play("upgrade", 0.05, 0.8)
            self:showToast(string.format("%s REACHED LV.%d", self.modalItem.name:upper(), newLevel))
        else
            Audio.play("ui_cancel", 0, 0.6)
            self:showToast(string.format("NOT ENOUGH GOLD (%d NEEDED)", cost))
        end
    elseif b.id == "fuse" then
        local ok, rarity, stars = Save.fuseItem(itemId)
        if ok then
            Audio.play("chest_reveal", 0, 0.9)
            self:showToast(stars and string.format("FUSED: %d STARS", stars)
                or ("FUSED: " .. Items.getRarityData(rarity).name:upper()))
        else
            Audio.play("ui_cancel", 0, 0.6)
        end
    end
    self:refresh()
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
    local fontTiny = UI.getFont("tiny")
    for _, s in ipairs(self.slots) do
        local itemId = self.saveData.equipped[s.id]
        local item = itemId and Items.get(itemId)
        local lvl = itemId and (self.saveData.itemLevels[itemId] or 1) or 0

        if item then
            local effRarity = Save.getItemRarity(itemId)
            UI.drawItemCard(s.x, s.y, s.w, s.h, item, lvl, false, false, effRarity)

            -- Libellé du slot aéré avec micro-pastille sombre protectrice au bas
            local prevFont = love.graphics.getFont()
            love.graphics.setFont(fontTiny)

            love.graphics.setColor(0.06, 0.08, 0.12, 0.75)
            love.graphics.rectangle("fill", s.x + 3, s.y + s.h - 11, s.w - 6, 9, 2, 2)
            UI.drawTextAligned(s.name, s.x, s.y + s.h - 11, s.w, "center", {0.85, 0.90, 0.98, 0.90}, {0.02, 0.03, 0.05, 0.9}, 1, 1)

            love.graphics.setFont(prevFont)
        else
            -- Emplacement vide Bento (bordure dorée pulsée s'il attend un objet du sac)
            local isTarget = (self.targetSlot == s.id)
            local pulse = 0.65 + 0.35 * math.sin(t * 6)
            UI.drawBentoCard(s.x, s.y, s.w, s.h, {
                r = 6,
                bg = isTarget and {0.16, 0.14, 0.08, 0.95} or {0.09, 0.11, 0.16, 0.85},
                borderColor = isTarget and {1.0, 0.85, 0.25, pulse} or {0.18, 0.22, 0.32, 0.70},
                borderWidth = isTarget and 2 or 1,
            })

            -- Icône silhouette discrète
            UI.drawItemIcon(s.type, s.x + s.w / 2, s.y + 14, 10, isTarget and {1.0, 0.85, 0.30, 0.9} or {0.35, 0.40, 0.50, 0.6})

            -- Libellé du slot vide sous l'icône silhouette
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
            local st = Save.getItemStats(id)
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

-- Titre du sac : message bref, consigne de l'emplacement visé, ou nombre d'objets
function Inventory:backpackTitle()
    if self.toastTimer > 0 and self.toastText then
        return self.toastText, {1.0, 0.88, 0.30, 1.0}
    end
    local target = self.targetSlot and self:getSlot(self.targetSlot)
    if target then
        return string.format("CHOOSE A %s FOR %s", TYPE_LABELS[target.type], Inventory.SLOT_LABELS[target.id]), {0.45, 0.90, 1.0, 1.0}
    end
    local count = #(self.saveData.inventory or {})
    return string.format("BACKPACK (%d ITEM%s)", count, count > 1 and "S" or ""), {0.80, 0.85, 0.95, 1.0}
end

-- Section inférieure : Sac à Dos & Grille avec Scissor
function Inventory:drawBackpackSection()
    local sx, sy, sw, sh = GRID_X, GRID_Y, GRID_W, GRID_H

    -- Bannière Bento du Sac à dos
    UI.drawBentoCard(sx, sy, sw, sh, {
        r = 8,
        bg = {0.08, 0.10, 0.15, 0.96},
        borderColor = {0.18, 0.23, 0.33, 0.85},
    })

    local fontSmall = UI.getFont("small")
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(fontSmall)
    local title, titleColor = self:backpackTitle()
    UI.drawText(title, sx + 8, sy + 4, titleColor, {0.08, 0.10, 0.14, 1.0})
    love.graphics.setFont(prevFont)

    -- ZONE DE CISEAUX POUR LE KINETIC SCROLLER
    local px, py, pw, ph
    if love.graphics.getScissor then px, py, pw, ph = love.graphics.getScissor() end
    setLocalScissor(sx + 2, sy + 18, sw - 4, sh - 20)

    local offsetY = self.scroller:getOffset()
    local target = self.targetSlot and self:getSlot(self.targetSlot)

    for i, itemId in ipairs(self.saveData.inventory) do
        local cx, cy = cardPosition(i, offsetY)

        -- Ne dessine que les cartes visibles
        if cy + CARD_H >= sy + 18 and cy <= sy + sh then
            local item = Items.get(itemId)
            local lvl = self.saveData.itemLevels[itemId] or 1
            local isEq = Save.isEquipped(itemId)
            local isSel = (self.modalItemId == itemId)
            local effRarity = Save.getItemRarity(itemId)

            UI.drawItemCard(cx, cy, CARD_W, CARD_H, item, lvl, isEq, isSel, effRarity)

            -- Emplacement visé : les objets qui n'y vont pas sont assombris
            if target and (not item or item.slot ~= target.type or isEq) then
                love.graphics.setColor(0.04, 0.05, 0.08, 0.62)
                love.graphics.rectangle("fill", cx, cy, CARD_W, CARD_H, 5, 5)
            end
        end
    end

    restoreScissor(px, py, pw, ph)

    -- Indicateur de défilement (Scrollbar subtile)
    local totalContentH = self.scroller.contentH
    if totalContentH > (sh - 20) then
        local barH = math.max(12, math.floor(((sh - 20) / totalContentH) * (sh - 20)))
        local progress = (-self.scroller.offsetY) / math.max(1, totalContentH - (sh - 20))
        progress = math.max(0, math.min(1, progress))
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
    local mx, my, mw, mh = MODAL_X, MODAL_Y, MODAL_W, MODAL_H
    local item = self.modalItem
    local itemId = self.modalItemId
    local lvl = self.saveData.itemLevels[itemId] or 1
    local effRarity = Save.getItemRarity(itemId)
    local rData = Items.getRarityData(effRarity)
    local copies = Save.getItemCopies(itemId)
    local stars = Save.getItemStars(itemId)

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
    local copiesText = string.format("Copies: %d/3", copies)
    if stars > 0 then copiesText = copiesText .. string.format("  Stars: %d", stars) end
    UI.drawText(copiesText, mx + 126, my + 24, {0.60, 0.70, 0.85, 0.9}, {0.05, 0.08, 0.12, 1.0})

    -- Statistiques Actuelles et Prochain Niveau dans une sous-carte Bento
    local curStats = Save.getItemStats(itemId)
    local nextStats = Items.getStats(itemId, lvl + 1, effRarity, stars)

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
    -- La description (2 lignes au plus, dans la carte) cède sa place au message d'une
    -- action (amélioration, fusion, or manquant)
    if self.toastTimer > 0 and self.toastText then
        PixelFont.printf(self.toastText, mx + 10, my + 63, mw - 20, "center", {1.0, 0.88, 0.30, 1.0}, "tiny", 1, nil, 1)
    else
        PixelFont.printf(item.desc, mx + 10, my + 60, mw - 20, "center", {0.80, 0.85, 0.95, 1.0}, "tiny", 1, nil, 2, 7)
    end
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
            -- Une ligne par passif, tronquée au bord de la carte
            PixelFont.printf(string.format("[%s] %s: %s", tInfo.name, pInfo.name, pInfo.desc), mx + 24, lineY + 3, mw - 36, "left", pColor, "tiny", 1, nil, 1)
        end
    end
    love.graphics.setFont(prevFont)

    -- 4. Boutons d'action (même liste que la détection tactile)
    for _, b in ipairs(self.modalButtons) do
        UI.drawPillButton(b.x, b.y, b.w, b.h, b.label, b.theme, self.pressedBtn == b.id, b.icon)
    end
end

-- ============================================================================
-- GESTION TACTILE DU PANNEAU D'INVENTAIRE (STYLUS / TOUCH)
-- L'appui repère l'élément touché, le relâchement sur ce même élément déclenche l'action
-- ============================================================================
function Inventory:touchpressed(id, tx, ty)
    self.touchStartX = tx
    self.touchStartY = ty
    self.hasDragged = false
    self.pressedBtn = nil

    -- 1. Si la modale est ouverte, elle capte tout l'écran
    if self.modalItem then
        if tx >= MODAL_X + MODAL_W - CLOSE_SIZE and tx <= MODAL_X + MODAL_W and ty >= MODAL_Y and ty <= MODAL_Y + CLOSE_SIZE then
            self.pressedBtn = "close"
            return true
        end
        for _, b in ipairs(self.modalButtons) do
            if inside(b, tx, ty) then
                self.pressedBtn = b.id
                return true
            end
        end
        -- Toucher hors de la carte referme la modale
        if tx < MODAL_X or tx > MODAL_X + MODAL_W or ty < MODAL_Y or ty > MODAL_Y + MODAL_H then
            self.pressedBtn = "outside"
        end
        return true
    end

    -- 2. L'un des 6 slots équipés du haut
    for _, s in ipairs(self.slots) do
        if inside(s, tx, ty) then
            self.pressedBtn = "slot_" .. s.id
            return true
        end
    end

    -- 3. Début de défilement ou sélection dans le sac à dos
    if ty >= GRID_Y and ty <= GRID_Y + GRID_H then
        self.scroller:touchDown(tx, ty)
    end
    return false
end

function Inventory:touchmoved(id, tx, ty, dx, dy)
    if self.modalItem then return end

    local distSq = (tx - self.touchStartX)^2 + (ty - self.touchStartY)^2
    if distSq > TAP_SLOP_SQ then
        self.hasDragged = true
    end

    if self.scroller.isDragging then
        self.scroller:touchMove(tx, ty)
    end
end

function Inventory:touchreleased(id, tx, ty)
    local pressed = self.pressedBtn
    self.pressedBtn = nil

    -- 1. Relâchement dans la modale
    if self.modalItem then
        if pressed == "outside" then
            self:closeModal()
        elseif pressed == "close" then
            if tx >= MODAL_X + MODAL_W - CLOSE_SIZE - RELEASE_SLOP and ty <= MODAL_Y + CLOSE_SIZE + RELEASE_SLOP then
                self:closeModal()
            end
        elseif pressed then
            local b = self:getModalButton(pressed)
            if b and inside(b, tx, ty, RELEASE_SLOP) then
                self:runAction(b)
            end
        end
        return
    end

    -- 2. Emplacement équipé
    if pressed and pressed:sub(1, 5) == "slot_" then
        local s = self:getSlot(pressed:sub(6))
        if s and inside(s, tx, ty, RELEASE_SLOP) then
            self:onSlotTapped(s)
        end
        return
    end

    -- 3. Fin de défilement ; un appui bref sans glissement sélectionne l'objet
    local wasScrolling = self.scroller.isDragging
    self.scroller:touchUp(tx, ty)
    if wasScrolling and not self.hasDragged then
        local itemId = self:itemAt(tx, ty)
        if itemId then self:onItemTapped(itemId) end
    end
end

-- Emplacement touché : objet porté -> sa fiche ; emplacement vide -> l'objet compatible
-- s'il est seul, sinon le sac attend que le joueur en choisisse un
function Inventory:onSlotTapped(s)
    local itemId = self.saveData.equipped[s.id]
    if itemId then
        self.targetSlot = nil
        self:openModal(itemId, s.id)
        return
    end
    if self.targetSlot == s.id then
        self.targetSlot = nil
        return
    end
    local candidates = self:candidatesFor(s.type)
    if #candidates == 0 then
        self.targetSlot = nil
        self:showToast(string.format("NO %s TO EQUIP IN THE BACKPACK", TYPE_LABELS[s.type]))
        Audio.play("ui_cancel", 0, 0.6)
    elseif #candidates == 1 then
        self.targetSlot = nil
        self:openModal(candidates[1], s.id)
    else
        self.targetSlot = s.id
        self.toastTimer = 0
    end
end

-- Objet du sac touché : sa fiche, en visant l'emplacement choisi juste avant s'il convient
function Inventory:onItemTapped(itemId)
    local target = self.targetSlot
    self.targetSlot = nil
    if target and Save.slotAccepts(target, itemId) and not Save.isEquipped(itemId) then
        self:openModal(itemId, target)
    else
        self:openModal(itemId, nil)
    end
end

function Inventory:openModal(itemId, sourceSlot)
    self.modalItemId = itemId
    self.modalItem = Items.get(itemId)
    self.modalSourceSlot = sourceSlot
    self.pressedBtn = nil
    self.toastTimer = 0
    if not self.saveData then self.saveData = Save.get() end
    self:rebuildModalButtons()
end

function Inventory:closeModal()
    self.modalItem = nil
    self.modalItemId = nil
    self.modalSourceSlot = nil
    self.modalButtons = {}
    self.pressedBtn = nil
end

-- Ferme la modale et oublie l'emplacement visé (changement d'onglet)
function Inventory:reset()
    self:closeModal()
    self.targetSlot = nil
end

-- Bouton « retour » (B, Échap) : ferme la modale, sinon annule l'emplacement visé.
-- Renvoie true si l'appui a servi.
function Inventory:back()
    if self.modalItem then
        self:closeModal()
        Audio.play("ui_cancel", 0, 0.7)
        return true
    end
    if self.targetSlot then
        self.targetSlot = nil
        Audio.play("ui_cancel", 0, 0.7)
        return true
    end
    return false
end

-- Déclenche un bouton de la modale sans le toucher (boutons physiques, clavier)
function Inventory:pressModalButton(id)
    local b = id and self:getModalButton(id) or self.modalButtons[1]
    if b then self:runAction(b) end
    return true
end

-- Boutons physiques 3DS dans la modale : A équipe / déséquipe, X améliore, Y fusionne, B ferme
function Inventory:gamepadpressed(button)
    if button == "b" then return self:back() end
    if not self.modalItem then return false end
    if button == "a" then
        return self:pressModalButton(nil)
    elseif button == "x" then
        return self:pressModalButton("upgrade")
    elseif button == "y" then
        if self:getModalButton("fuse") then self:pressModalButton("fuse") end
        return true
    end
    return true
end

-- Clavier PC : Entrée / Espace / E équipe, U améliore, F fusionne, Échap ferme
function Inventory:keypressed(key)
    if key == "escape" or key == "backspace" then return self:back() end
    if not self.modalItem then return false end
    if key == "return" or key == "space" or key == "e" then
        return self:pressModalButton(nil)
    elseif key == "u" then
        return self:pressModalButton("upgrade")
    elseif key == "f" then
        if self:getModalButton("fuse") then self:pressModalButton("fuse") end
        return true
    end
    return true
end

return Inventory
