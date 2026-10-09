-- src/states/inventory.lua
-- Archero-style inventory and equipment panel for the bottom screen (320x240):
-- 6 equipment slots around the hero, a kinetic-scrolling backpack grid, 5 colored
-- rarity tiers and a detailed item sheet (equip / upgrade / fuse).
--
-- Equipment rules (src/data/save.lua): each slot only accepts its item type; a ring or
-- pet goes to the first free slot, or to the slot the player tapped, or, when both are
-- taken, to the one the player picks (RING 1 / RING 2).
-- The sheet buttons are computed once (rebuildModalButtons): drawing and touch handling
-- read the same list, so they can no longer drift apart.

local Config = require("src.data.config")
local Save = require("src.data.save")
local Items = require("src.data.items")
local UI = require("src.ui.ui_components")
local Art = require("src.render.art")
local PixelFont = require("src.ui.pixel_font")
local HeroSprites = require("src.render.sprites.heroes")
local Audio = require("src.audio.audio")
local Screen = require("src.core.screen")
local Skin = require("src.ui.skin")
local Palette = require("src.render.palette")

local Inventory = {}
Inventory.__index = Inventory

-- Item sheet (modal): the top screen shows the item's stats, the sheet keeps the passives
-- and the action buttons
local MODAL_X, MODAL_Y, MODAL_W, MODAL_H = 4, 4, 312, 196
local CLOSE_SIZE = 28
local BTN_Y, BTN_H = MODAL_Y + 152, 40
local BTN_LEFT, BTN_SPAN, BTN_GAP = MODAL_X + 6, MODAL_W - 12, 4

-- Equipped slots row, filter chips and the backpack (scrolling grid of square tiles)
local SLOT_SIZE, SLOT_STEP, SLOT_X0, SLOT_Y = 40, 51, 10, 8
local FILTER_Y, FILTER_W, FILTER_H, FILTER_STEP = 55, 42, 24, 45
local FILTERS = {
    { id = "all", label = "ALL" }, { id = "weapon", label = "WPN" }, { id = "armor", label = "ARM" },
    { id = "ring", label = "RING" }, { id = "pet", label = "PET" },
}
local GRID_X, GRID_Y, GRID_W, GRID_H = 4, 82, 312, 118
local GRID_VIEW_TOP, GRID_VIEW_BOTTOM = GRID_Y + 2, GRID_Y + GRID_H - 2
local GRID_COLS, CARD_W, CARD_H, GAP_X, GAP_Y = 8, 35, 35, 3, 3
local GRID_ORIGIN_X = GRID_X + 5
local GRID_ORIGIN_Y = GRID_Y + 4

local TAP_SLOP_SQ = 196 -- beyond 14 px of movement, a tap becomes a scroll
local RELEASE_SLOP = 8  -- release tolerance around a button
local TOAST_TIME = 1.6

Inventory.SLOT_LABELS = {
    weapon = "WEAPON", armor = "ARMOR", ring1 = "RING 1", ring2 = "RING 2", pet1 = "PET 1", pet2 = "PET 2",
}
local TYPE_LABELS = { weapon = "WEAPON", armor = "ARMOR", ring = "RING", pet = "PET" }

-- Scissor rectangles are in window pixels and ignore the current translation: on PC the
-- bottom screen is drawn offset below the top one (on 3DS it has its own framebuffer)
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

    -- Kinetic touch scrolling of the backpack grid
    self.scroller = UI.newScroller(GRID_H - 6, 120)
    self.filter = "all"

    -- Item sheet of the selected item
    self.modalItem = nil
    self.modalItemId = nil
    self.modalSourceSlot = nil -- slot tapped to open the sheet (equip target)
    self.modalButtons = {}

    -- Empty slot tapped while several items could go there: the next compatible item
    -- tapped in the backpack is equipped into it
    self.targetSlot = nil

    -- Short message shown instead of the backpack title (item equipped, not enough gold...)
    self.toastText = nil
    self.toastTimer = 0

    -- Tap vs drag detection
    self.touchStartX = 0
    self.touchStartY = 0
    self.hasDragged = false

    -- Element under the stylus ("slot_<id>", a button id, "close", "outside")
    self.pressedBtn = nil

    -- 6 equipped slots in one row (the hero and the totals are on the top screen)
    self.slots = {
        { id = "weapon", name = "WPN",  type = "weapon" },
        { id = "armor",  name = "ARM",  type = "armor" },
        { id = "ring1",  name = "RING", type = "ring" },
        { id = "ring2",  name = "RING", type = "ring" },
        { id = "pet1",   name = "PET",  type = "pet" },
        { id = "pet2",   name = "PET",  type = "pet" },
    }
    for i, s in ipairs(self.slots) do
        s.x, s.y, s.w, s.h = SLOT_X0 + (i - 1) * SLOT_STEP, SLOT_Y, SLOT_SIZE, SLOT_SIZE
    end

    return self
end

function Inventory:refresh()
    self.saveData = Save.get()
    self:rebuildVisible()
    if self.modalItemId then self:rebuildModalButtons() end
end

-- Backpack items shown by the current filter, and the scroller's content height
function Inventory:rebuildVisible()
    local list = self.visible or {}
    for i = #list, 1, -1 do list[i] = nil end
    for _, invId in ipairs(self.saveData.inventory or {}) do
        local it = Items.get(invId)
        if self.filter == "all" or (it and it.slot == self.filter) then list[#list + 1] = invId end
    end
    self.visible = list
    local rows = math.ceil(math.max(1, #list) / GRID_COLS)
    self.scroller:setContentHeight(rows * (CARD_H + GAP_Y) + 6)
end

function Inventory:setFilter(id)
    if self.filter == id then return end
    self.filter = id
    self.scroller.offsetY = 0
    self.scroller.velocity = 0
    self:rebuildVisible()
end

function Inventory:update(dt)
    self.scroller:update(dt)
    if self.toastTimer > 0 then
        self.toastTimer = math.max(0, self.toastTimer - dt)
    end
end

-- Is the item equipped in one of the 6 slots?
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

-- Backpack items of this slot type that are not already worn
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

-- Position of a backpack card (drawing and touch handling)
local function cardPosition(index, offsetY)
    local col = (index - 1) % GRID_COLS
    local row = math.floor((index - 1) / GRID_COLS)
    return GRID_ORIGIN_X + col * (CARD_W + GAP_X), GRID_ORIGIN_Y + offsetY + row * (CARD_H + GAP_Y)
end

-- Backpack item under the touch point (only inside the visible grid window)
function Inventory:itemAt(tx, ty)
    if ty < GRID_VIEW_TOP or ty > GRID_VIEW_BOTTOM then return nil end
    local offsetY = self.scroller:getOffset()
    for i, itemId in ipairs(self.visible or {}) do
        local cx, cy = cardPosition(i, offsetY)
        if tx >= cx - 1 and tx <= cx + CARD_W + 1 and ty >= cy - 1 and ty <= cy + CARD_H + 1 then
            return itemId
        end
    end
    return nil
end

-- ============================================================================
-- ITEM SHEET: ACTION BUTTONS
-- ============================================================================
-- Slot the item goes to when the player presses EQUIP: the slot that opened the sheet if
-- it fits, otherwise the only slot of that type or the first free one. nil when both ring
-- (or pet) slots are taken: the player picks one.
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

-- Runs the action of a sheet button
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
-- INVENTORY PANEL RENDERING (BOTTOM SCREEN 320x240)
-- ============================================================================
function Inventory:draw()
    if not self.saveData then self:refresh() end
    local t = love.timer.getTime()

    -- 1. TOP: THE 6 EQUIPPED SLOTS AROUND THE HERO
    self:drawEquippedSection(t)

    -- 2. BOTTOM: BACKPACK GRID WITH KINETIC SCROLLING
    self:drawBackpackSection()

    -- 3. ITEM SHEET (WHEN OPEN)
    if self.modalItem then
        self:drawItemModal(t)
    end
end

-- Upper section: the 6 equipped slots in one row, then the filter chips
function Inventory:drawEquippedSection(t)
    local C = Palette.C
    Skin.panel(4, 4, 312, 48, "dark")
    for _, s in ipairs(self.slots) do
        local itemId = self.saveData.equipped[s.id]
        if itemId then
            UI.drawItemTile(s.x, s.y, s.w, Items.get(itemId), self.saveData.itemLevels[itemId] or 1, false, false,
                Save.getItemRarity(itemId))
        else
            local isTarget = (self.targetSlot == s.id)
            if isTarget and math.floor(t * 4) % 2 == 0 then Skin.roundRect(C.yellow, s.x - 2, s.y - 2, s.w + 4, s.h + 4, 3) end
            Skin.roundRect(C.slate, s.x, s.y, s.w, s.h, 3)
            Skin.rect(C.night, s.x + 1, s.y + 1, s.w - 2, s.h - 2)
        end
    end
    for _, f in ipairs(FILTERS) do
        local x = 4 + (_ - 1) * FILTER_STEP
        if self.filter == f.id then
            Skin.button(x, FILTER_Y, FILTER_W, FILTER_H, "blue", self.pressedBtn == "filter_" .. f.id)
        else
            Skin.panel(x, FILTER_Y + 1, FILTER_W, FILTER_H - 1, "raised")
        end
    end
    for i, f in ipairs(FILTERS) do
        local x = 4 + (i - 1) * FILTER_STEP
        PixelFont.printf(f.label, x, FILTER_Y + (self.filter == f.id and 6 or 7), FILTER_W, "center",
            self.filter == f.id and C.white or C.fog, "main")
    end
    for _, s in ipairs(self.slots) do
        if not self.saveData.equipped[s.id] then
            PixelFont.printf(s.name, s.x, s.y + 14, s.w, "center", self.targetSlot == s.id and C.yellow or C.steel, "main")
        end
    end
    -- Right of the chips: what the backpack shows (or which slot is waiting for an item)
    local title, color = self:backpackTitle()
    PixelFont.printf(title, 4 + 5 * FILTER_STEP, FILTER_Y + 6, 312 - 5 * FILTER_STEP, "center", color, "main", 1, nil, 1)
end

-- Backpack title: targeted slot hint, or item count
function Inventory:backpackTitle()
    local target = self.targetSlot and self:getSlot(self.targetSlot)
    if target then
        return "PICK " .. TYPE_LABELS[target.type], Palette.C.yellow
    end
    local count = #(self.visible or {})
    return string.format("%d ITEM%s", count, count > 1 and "S" or ""), Palette.C.silver
end

-- Lower section: backpack grid with scissor
function Inventory:drawBackpackSection()
    local C = Palette.C
    local sx, sy, sw, sh = GRID_X, GRID_Y, GRID_W, GRID_H
    Skin.panel(sx, sy, sw, sh, "inset")

    local px, py, pw, ph
    if love.graphics.getScissor then px, py, pw, ph = love.graphics.getScissor() end
    setLocalScissor(sx + 2, sy + 2, sw - 4, sh - 4)

    local offsetY = self.scroller:getOffset()
    local target = self.targetSlot and self:getSlot(self.targetSlot)
    local list = self.visible or {}
    local slotsShown = math.max(#list, GRID_COLS * 3)
    for i = 1, slotsShown do
        local cx, cy = cardPosition(i, offsetY)
        if cy + CARD_H >= sy and cy <= sy + sh then
            local itemId = list[i]
            if itemId then
                local item = Items.get(itemId)
                local isEq = Save.isEquipped(itemId)
                UI.drawItemTile(cx, cy, CARD_W, item, self.saveData.itemLevels[itemId] or 1, isEq,
                    self.modalItemId == itemId, Save.getItemRarity(itemId))
                if target and (not item or item.slot ~= target.type or isEq) then
                    Skin.rect(C.ink, cx, cy, CARD_W, CARD_H, 0.6)
                end
            else
                Skin.roundRect(C.slate, cx, cy, CARD_W, CARD_H, 3)
                Skin.rect(C.night, cx + 1, cy + 1, CARD_W - 2, CARD_H - 2)
            end
        end
    end

    restoreScissor(px, py, pw, ph)

    -- Scrollbar
    local viewH = sh - 6
    local totalContentH = self.scroller.contentH
    if totalContentH > viewH then
        local barH = math.max(12, math.floor((viewH / totalContentH) * viewH))
        local progress = math.max(0, math.min(1, (-self.scroller.offsetY) / math.max(1, totalContentH - viewH)))
        Skin.rect(C.steel, sx + sw - 4, sy + 3 + math.floor(progress * (viewH - barH)), 2, barH)
    end

    -- Result of the last action (equipped, upgraded, missing gold...)
    if self.toastTimer > 0 and self.toastText then
        Skin.pill(sx + 10, sy + sh - 22, sw - 20, 18, "dark")
        PixelFont.printf(self.toastText, sx + 10, sy + sh - 19, sw - 20, "center", C.yellow, "main", 1, nil, 1)
    end
end

-- ============================================================================
-- ITEM SHEET (EQUIP / UPGRADE)
-- ============================================================================
function Inventory:drawItemModal(t)
    local C = Palette.C
    Skin.rect(C.ink, 0, 0, Config.BOTTOM_WIDTH, Config.BOTTOM_HEIGHT, 0.75)

    local mx, my, mw, mh = MODAL_X, MODAL_Y, MODAL_W, MODAL_H
    local item = self.modalItem
    local itemId = self.modalItemId
    local lvl = self.saveData.itemLevels[itemId] or 1
    local effRarity = Save.getItemRarity(itemId)
    local rData = Items.getRarityData(effRarity)
    local copies = Save.getItemCopies(itemId)
    local stars = Save.getItemStars(itemId)
    local tiers = {
        { id = "uncommon", minTier = 2 }, { id = "rare", minTier = 3 },
        { id = "epic", minTier = 4 }, { id = "legendary", minTier = 5 },
    }

    -- 1. Card, rarity header, close button, passives box
    Skin.panel(mx, my, mw, mh, "dark")
    love.graphics.setColor(rData.bg[1], rData.bg[2], rData.bg[3], 1)
    love.graphics.rectangle("fill", mx + 2, my + 2, mw - 4, 38)
    Skin.disc(C.ink, mx + mw - 18, my + 18, 12)
    Skin.disc(C.wine, mx + mw - 18, my + 18, 11)
    Skin.panel(mx + 6, my + 62, mw - 12, 70, "inset")
    for _, b in ipairs(self.modalButtons) do
        UI.drawPillButton(b.x, b.y, b.w, b.h, b.label, b.theme, self.pressedBtn == b.id, b.icon)
    end

    -- 2. Sprites and texts
    UI.drawItemIcon(item.icon, mx + 24, my + 21, 16, rData.color)
    PixelFont.printf(item.name, mx + 46, my + 6, mw - 80, "left", C.white, "main", 1, nil, 1)
    local starText = stars > 0 and string.format("  %d STAR%s", stars, stars > 1 and "S" or "") or ""
    PixelFont.print(string.format("%s  LV %d%s", rData.name:upper(), lvl, starText), mx + 46, my + 22, rData.color, "main")
    PixelFont.printf("X", mx + mw - 30, my + 12, 24, "center", C.white, "main")
    PixelFont.print(string.format("COPIES %d/3", copies), mx + 8, my + 46, C.fog, "main")
    if self.toastTimer > 0 and self.toastText then
        PixelFont.printf(self.toastText, mx + 90, my + 46, mw - 96, "right", C.yellow, "main", 1, nil, 1)
    end
    local line = 0
    for _, tInfo in ipairs(tiers) do
        local pInfo = item.passives and item.passives[tInfo.id]
        if pInfo then
            local unlocked = (rData.tier >= tInfo.minTier)
            local y = my + 67 + line * 15
            local color = unlocked and Items.getRarityData(tInfo.id).color or C.steel
            love.graphics.setColor(1, 1, 1, 1)
            Art.draw(unlocked and "icon_check" or "icon_lock", 1, mx + 16, y + 6)
            PixelFont.printf(pInfo.name .. ": " .. pInfo.desc, mx + 26, y, mw - 40, "left", color, "main", 1, nil, 1)
            line = line + 1
        end
    end
    if line == 0 then
        PixelFont.printf(item.desc or "", mx + 12, my + 70, mw - 24, "center", C.silver, "main", 1, nil, 4, 12)
    end
end

-- ============================================================================
-- INVENTORY TOUCH HANDLING (STYLUS)
-- Press records the touched element; releasing on that same element triggers the action
-- ============================================================================
function Inventory:touchpressed(id, tx, ty)
    self.touchStartX = tx
    self.touchStartY = ty
    self.hasDragged = false
    self.pressedBtn = nil

    -- 1. An open sheet captures the whole screen
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
        -- Touching outside the card closes the sheet
        if tx < MODAL_X or tx > MODAL_X + MODAL_W or ty < MODAL_Y or ty > MODAL_Y + MODAL_H then
            self.pressedBtn = "outside"
        end
        return true
    end

    -- 2. Filter chips, then one of the 6 equipped slots
    if ty >= FILTER_Y and ty <= FILTER_Y + FILTER_H then
        for i, f in ipairs(FILTERS) do
            local x = 4 + (i - 1) * FILTER_STEP
            if tx >= x and tx <= x + FILTER_W then
                self.pressedBtn = "filter_" .. f.id
                return true
            end
        end
    end
    for _, s in ipairs(self.slots) do
        if inside(s, tx, ty) then
            self.pressedBtn = "slot_" .. s.id
            return true
        end
    end

    -- 3. Scroll start or backpack selection
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

    -- 1. Release inside the sheet
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

    -- 2. Filter chip or equipped slot
    if pressed and pressed:sub(1, 7) == "filter_" then
        self:setFilter(pressed:sub(8))
        return
    end
    if pressed and pressed:sub(1, 5) == "slot_" then
        local s = self:getSlot(pressed:sub(6))
        if s and inside(s, tx, ty, RELEASE_SLOP) then
            self:onSlotTapped(s)
        end
        return
    end

    -- 3. Scroll end; a short tap without drag selects the item
    local wasScrolling = self.scroller.isDragging
    self.scroller:touchUp(tx, ty)
    if wasScrolling and not self.hasDragged then
        local itemId = self:itemAt(tx, ty)
        if itemId then self:onItemTapped(itemId) end
    end
end

-- Slot tapped: worn item -> its sheet; empty slot -> the only compatible item, or the
-- backpack waits for the player to pick one
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

-- Backpack item tapped: its sheet, targeting the slot chosen just before if it fits
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

-- Closes the sheet and forgets the targeted slot (tab change)
function Inventory:reset()
    self:closeModal()
    self.targetSlot = nil
end

-- Back (B, Escape): closes the sheet, otherwise cancels the targeted slot.
-- Returns true when the press was used.
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

-- Triggers a sheet button without touching it (console buttons, keyboard)
function Inventory:pressModalButton(id)
    local b = id and self:getModalButton(id) or self.modalButtons[1]
    if b then self:runAction(b) end
    return true
end

-- 3DS buttons in the sheet: A equips / unequips, X upgrades, Y fuses, B closes
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

-- PC keyboard: Return / Space / E equips, U upgrades, F fuses, Escape closes
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
