-- tests/test_save_equipment.lua
-- Forge (equip / unequip weapons, armor, rings, pets), talents, quests and hub navigation.
-- Interactions go through real taps (touchpressed then touchreleased) at the coordinates of
-- the drawn elements, like on the touch screen.

-- Minimal LÖVE environment + in-memory filesystem (no real save is touched)
local files = {}
love = love or {}
love.timer = love.timer or { getTime = function() return 0 end }
love.filesystem = {
    write = function(path, content) files[path] = content; return true end,
    read = function(path) return files[path] end,
}
love.graphics = love.graphics or {}
for _, name in ipairs({ "setFont", "setColor", "rectangle", "circle", "line", "print", "printf", "push", "pop",
    "translate", "scale", "rotate", "setScissor", "ellipse", "setLineWidth", "polygon" }) do
    love.graphics[name] = love.graphics[name] or function() end
end
love.graphics.getFont = love.graphics.getFont or function()
    return { getWidth = function() return 10 end, getHeight = function() return 10 end }
end
love.graphics.newImage = love.graphics.newImage or function() return {} end
love.graphics.newQuad = love.graphics.newQuad or function() return {} end
love.image = love.image or { newImageData = function() return {} end }

local Save = require("src.data.save")
local Items = require("src.data.items")
local Talents = require("src.data.talents")
local Quests = require("src.data.quests")
local Balance = require("src.data.balance")
-- Text measurement without the graphics atlas: 6 px per character (main font)
require("src.ui.pixel_font").getWidth = function(text) return #tostring(text) * 6 end

local T = {}

local BACKPACK = {
    "starter_bow", "rapid_daggers", "vest_dexterity", "phantom_cloak",
    "wolf_ring", "bear_ring", "bat_companion", "ghost_familiar",
}

local function resetSave(inventory)
    Save.reset()
    local d = Save.get()
    d.gold = 50000
    d.gems = 1000
    d.inventory = {}
    for i, id in ipairs(inventory or BACKPACK) do d.inventory[i] = id end
    return d
end

-- Reloads the save from "disk" (like a console restart)
local function reloadSave()
    Save.data = nil
    return Save.load()
end

local function tap(obj, x, y)
    obj:touchpressed(1, x, y)
    obj:touchreleased(1, x, y)
end

local function center(r)
    return r.x + math.floor(r.w / 2), r.y + math.floor(r.h / 2)
end

local function newInventory()
    local inv = require("src.states.inventory").new()
    inv:refresh()
    return inv
end

-- Center of an item tile in the backpack grid (no scrolling, ALL filter): 8 columns of
-- 35 px tiles every 38 px from (9, 86), see src/states/inventory.lua
local function cardCenter(inv, itemId)
    for i, id in ipairs(inv.visible) do
        if id == itemId then
            local col, row = (i - 1) % 8, math.floor((i - 1) / 8)
            local x, y = 9 + col * 38 + 17, 86 + row * 38 + 17
            assert(y <= 196, "card not visible without scrolling: " .. itemId)
            return x, y
        end
    end
    error("item not in backpack: " .. tostring(itemId))
end

local function tapCard(inv, itemId) tap(inv, cardCenter(inv, itemId)) end
local function tapSlot(inv, slotId) tap(inv, center(inv:getSlot(slotId))) end

local function buttonIds(inv)
    local ids = {}
    for i, b in ipairs(inv.modalButtons) do ids[i] = b.id end
    return table.concat(ids, ",")
end

local function tapButton(inv, id)
    local b = inv:getModalButton(id)
    assert(b, "button '" .. id .. "' missing, got: " .. buttonIds(inv))
    tap(inv, center(b))
end

-- ============================================================================
-- SAVE: slots, migration, validation
-- ============================================================================
T["new save only uses the six slot keys"] = function()
    local d = resetSave()
    for key in pairs(d.equipped) do
        assert(Save.EQUIP_SLOTS[key], "unexpected equipped key: " .. key)
    end
    assert(d.equipped.ring1 == "wolf_ring" and d.equipped.pet1 == "bat_companion")
end

T["legacy ring/pet keys migrate to ring1/pet1 and disappear"] = function()
    files[Save.SAVE_FILE] = "return { saveSeq = 1, gold = 10, inventory = { \"starter_bow\", \"wolf_ring\", \"bat_companion\" },"
        .. " equipped = { weapon = \"starter_bow\", ring = \"wolf_ring\", pet = \"bat_companion\" } }\n-- fin arch3ro\n"
    files[Save.BACKUP_FILE] = nil
    local d = reloadSave()
    assert(d.equipped.ring1 == "wolf_ring", "ring must move to ring1")
    assert(d.equipped.pet1 == "bat_companion", "pet must move to pet1")
    assert(d.equipped.ring == nil and d.equipped.pet == nil, "legacy keys must be removed")
end

T["loading an unchanged save does not rewrite it"] = function()
    resetSave()
    Save.save()
    local seq = Save.get().saveSeq
    local d = reloadSave()
    assert(d.saveSeq == seq, "a clean save must not be rewritten at boot (SD write)")
end

T["sanitize drops duplicates, wrong types and unowned items"] = function()
    local d = resetSave()
    d.equipped = { weapon = "starter_bow", ring1 = "wolf_ring", ring2 = "wolf_ring", pet1 = "wolf_ring", armor = "falcon_ring" }
    Save.sanitizeEquipment()
    d = Save.get()
    assert(d.equipped.ring1 == "wolf_ring")
    assert(d.equipped.ring2 == nil, "same ring cannot be worn twice")
    assert(d.equipped.pet1 == nil, "a ring cannot sit in a pet slot")
    -- falcon_ring is not owned: replaced by the owned starter armor
    assert(d.equipped.armor == "vest_dexterity", "unowned item falls back to the starter piece")
end

T["equip rejects wrong slot types and unowned items"] = function()
    local d = resetSave()
    assert(Save.equip("pet2", "bear_ring") == false, "ring into pet slot must fail")
    assert(Save.equip("weapon", "vest_dexterity") == false, "armor into weapon slot must fail")
    assert(Save.equip("ring2", "falcon_ring") == false, "unowned item must fail")
    assert(Save.equip("bogus", "wolf_ring") == false)
    assert(d.equipped.pet2 == nil and d.equipped.ring2 == nil)
end

T["moving a ring from ring1 to ring2 frees ring1"] = function()
    local d = resetSave()
    assert(Save.equip("ring2", "wolf_ring"))
    assert(d.equipped.ring2 == "wolf_ring" and d.equipped.ring1 == nil)
end

T["unequipped slots survive a reload"] = function()
    resetSave()
    assert(Save.unequip("weapon"))
    assert(Save.unequip("ring1"))
    assert(Save.unequip("pet1"))
    assert(Save.equip("pet2", "ghost_familiar"))
    local d = reloadSave()
    assert(d.equipped.weapon == nil, "weapon must stay empty")
    assert(d.equipped.ring1 == nil, "ring1 must stay empty")
    assert(d.equipped.pet1 == nil, "pet1 must stay empty")
    assert(d.equipped.pet2 == "ghost_familiar", "pet2 must stay equipped")
    assert(Save.unequip("ring1") == false, "unequipping an empty slot reports false")
end

T["forge upgrade uses the displayed cost and counts for upgrade quests"] = function()
    local d = resetSave()
    local cost = Items.getUpgradeCost(1, Save.getItemRarity("starter_bow"))
    local before = Save.getDailyQuests().progress.upgrades or 0
    local gold = d.gold
    local ok, lvl, paid = Save.upgradeItem("starter_bow")
    assert(ok and lvl == 2 and paid == cost)
    assert(d.gold == gold - cost)
    assert((Save.getDailyQuests().progress.upgrades or 0) == before + 1, "daily upgrade quest must progress")
end

T["legendary items can still fuse for stars"] = function()
    local d = resetSave()
    d.itemRarities.starter_bow = "legendary"
    d.itemCopies.starter_bow = 3
    assert(Save.canFuse("starter_bow"), "legendary with < 5 stars can fuse")
    d.itemStars.starter_bow = Save.MAX_ITEM_STARS
    assert(not Save.canFuse("starter_bow"), "max stars cannot fuse")
end

T["item power ratio follows level, rarity and stars"] = function()
    assert(math.abs(Items.powerRatio("starter_bow", 1, "common", 0) - 1) < 1e-9)
    assert(math.abs(Items.powerRatio("starter_bow", 2, "common", 0) - 1.16) < 1e-9)
    assert(Items.powerRatio("starter_bow", 1, "rare", 0) > 1.5)
    assert(Items.powerRatio("starter_bow", 1, "common", 1) > 1.05)
end

-- ============================================================================
-- TALENTS
-- ============================================================================
T["talents: the chosen talent is the one upgraded"] = function()
    local d = resetSave()
    for _, t in ipairs(Talents.LIST) do
        local before = d.talents[t.id] or 0
        local ok, chosen = Save.upgradeTalent(t.id)
        assert(ok and chosen == t.id, "upgrade must hit " .. t.id)
        assert(d.talents[t.id] == before + 1)
    end
end

T["talents: no choice, unknown talent or no gold spends nothing"] = function()
    local d = resetSave()
    local gold = d.gold
    assert(Save.upgradeTalent(nil) == false)
    assert(Save.upgradeTalent("luck") == false)
    d.gold = 0
    assert(Save.upgradeTalent("strength") == false)
    assert(d.talents.strength == 0)
    d.gold = gold
end

T["talents: glory is bought once and costs follow the total"] = function()
    local d = resetSave()
    local cost0 = Save.getTalentCost()
    assert(cost0 == Balance.COSTS.talentBase)
    assert(Save.upgradeTalent("glory"))
    assert(Save.upgradeTalent("glory") == false, "glory is a one-time purchase")
    assert(Save.getTalentCost() == Balance.COSTS.talentBase + Balance.COSTS.talentStep)
end

T["talents: combat effects match the displayed values"] = function()
    local player = { damageMult = 1, maxHp = 100, hp = 100, dodgeChance = 0 }
    Talents.apply(player, { strength = 2, vitality = 3, agility = 1, recovery = 2, glory = 0 })
    assert(math.abs(player.damageMult - 1.10) < 1e-9)
    assert(player.maxHp == 190 and player.hp == 190)
    assert(math.abs(player.dodgeChance - 0.02) < 1e-9)
    assert(math.abs(player.healMult - 1.20) < 1e-9)
    assert(Talents.LIST[1].effect == "+5% DMG" and Talents.LIST[2].effect == "+30 HP")
    assert(Talents.LIST[3].effect == "+2% DODGE" and Talents.LIST[4].effect == "+10% HEAL")
end

-- ============================================================================
-- FORGE: real taps on the grid, the slots and the buttons
-- ============================================================================
T["forge: equip a second ring from the backpack"] = function()
    local d = resetSave()
    local inv = newInventory()
    tapCard(inv, "bear_ring")
    assert(inv.modalItemId == "bear_ring", "tapping a card opens its sheet")
    tapButton(inv, "equip")
    assert(d.equipped.ring2 == "bear_ring", "first free ring slot is ring2")
    assert(d.equipped.ring1 == "wolf_ring")
    assert(inv.modalItem == nil, "sheet closes after equipping")
end

T["forge: unequip from the slot, then re-equip from the backpack"] = function()
    local d = resetSave()
    local inv = newInventory()
    tapSlot(inv, "pet1")
    assert(inv.modalItemId == "bat_companion")
    tapButton(inv, "unequip")
    assert(d.equipped.pet1 == nil, "pet1 must be empty")
    assert(Save.ownsItem("bat_companion"), "unequipped item stays in the backpack")
    tapCard(inv, "bat_companion")
    tapButton(inv, "equip")
    assert(d.equipped.pet1 == "bat_companion", "pet goes back to the first free slot")
end

T["forge: weapons and armor swap and unequip"] = function()
    local d = resetSave()
    local inv = newInventory()
    tapCard(inv, "rapid_daggers")
    tapButton(inv, "equip")
    assert(d.equipped.weapon == "rapid_daggers", "weapon replaced")
    tapCard(inv, "phantom_cloak")
    tapButton(inv, "equip")
    assert(d.equipped.armor == "phantom_cloak", "armor replaced")
    tapSlot(inv, "armor")
    tapButton(inv, "unequip")
    assert(d.equipped.armor == nil, "armor slot empty")
end

T["forge: both ring slots taken -> player picks which one to replace"] = function()
    local d = resetSave()
    table.insert(d.inventory, 5, "serpent_ring")
    assert(Save.equip("ring2", "bear_ring"))
    local inv = newInventory()
    tapCard(inv, "serpent_ring")
    assert(buttonIds(inv) == "equip_ring1,equip_ring2,upgrade", "got " .. buttonIds(inv))
    tapButton(inv, "equip_ring2")
    assert(d.equipped.ring2 == "serpent_ring" and d.equipped.ring1 == "wolf_ring")
    assert(not Save.isEquipped("bear_ring"), "replaced ring returns to the backpack")
end

T["forge: empty slot with several candidates waits for a backpack pick"] = function()
    local d = resetSave()
    table.insert(d.inventory, 5, "serpent_ring")
    local inv = newInventory()
    tapSlot(inv, "ring2")
    assert(inv.targetSlot == "ring2" and inv.modalItem == nil, "slot armed, no sheet yet")
    tapCard(inv, "serpent_ring")
    assert(inv.modalSourceSlot == "ring2")
    tapButton(inv, "equip")
    assert(d.equipped.ring2 == "serpent_ring")
    -- Second tap on the targeted slot: cancel
    Save.unequip("ring2")
    tapSlot(inv, "ring2")
    tapSlot(inv, "ring2")
    assert(inv.targetSlot == nil)
end

T["forge: empty slot with one candidate opens it, with none shows a hint"] = function()
    local d = resetSave()
    local inv = newInventory()
    -- pet2 empty and only ghost_familiar is free: its sheet opens, targeting pet2
    tapSlot(inv, "pet2")
    assert(inv.modalItemId == "ghost_familiar" and inv.modalSourceSlot == "pet2")
    tapButton(inv, "equip")
    assert(d.equipped.pet2 == "ghost_familiar")

    -- No free armor in the backpack: hint instead of a sheet
    Save.unequip("armor")
    d.inventory = { "starter_bow", "wolf_ring", "bat_companion", "ghost_familiar" }
    inv:refresh()
    tapSlot(inv, "armor")
    assert(inv.modalItem == nil and inv.targetSlot == nil, "no candidate: no sheet")
    assert(inv.toastTimer > 0 and inv.toastText:find("ARMOR"), "hint names the missing type")
end

T["forge: a drag in the backpack does not open a sheet"] = function()
    resetSave()
    local inv = newInventory()
    local x, y = cardCenter(inv, "bear_ring")
    inv:touchpressed(1, x, y)
    inv:touchmoved(1, x, y - 30, 0, -30)
    inv:touchreleased(1, x, y - 30)
    assert(inv.modalItem == nil)
end

T["forge: releasing away from a button cancels it"] = function()
    local d = resetSave()
    local inv = newInventory()
    tapCard(inv, "bear_ring")
    local b = inv:getModalButton("equip")
    inv:touchpressed(1, center(b))
    inv:touchreleased(1, b.x + b.w + 40, b.y - 40)
    assert(d.equipped.ring2 == nil, "no action when the stylus slides off")
end

T["forge: upgrade button levels the item and keeps the sheet open"] = function()
    local d = resetSave()
    local inv = newInventory()
    tapCard(inv, "starter_bow")
    local gold = d.gold
    tapButton(inv, "upgrade")
    assert(Save.getItemLevel("starter_bow") == 2)
    assert(d.gold < gold)
    assert(inv.modalItemId == "starter_bow", "sheet stays open for more upgrades")
end

T["forge: modal buttons fit inside the sheet without overlapping"] = function()
    local d = resetSave()
    table.insert(d.inventory, 5, "serpent_ring")
    d.itemCopies.serpent_ring = 3
    assert(Save.equip("ring2", "bear_ring"))
    local inv = newInventory()
    for _, id in ipairs({ "wolf_ring", "serpent_ring", "starter_bow", "rapid_daggers" }) do
        inv:openModal(id, nil)
        local prevRight = 4
        for _, b in ipairs(inv.modalButtons) do
            assert(b.x >= prevRight, "buttons overlap for " .. id)
            prevRight = b.x + b.w
        end
        assert(prevRight <= 4 + 312, "buttons overflow the sheet for " .. id)
    end
    inv:openModal("serpent_ring", nil)
    assert(buttonIds(inv) == "equip_ring1,equip_ring2,upgrade,fuse", "got " .. buttonIds(inv))
end

T["forge: console buttons A / X / B in the sheet"] = function()
    local d = resetSave()
    local inv = newInventory()
    inv:openModal("ghost_familiar", nil)
    assert(inv:gamepadpressed("x"))
    assert(Save.getItemLevel("ghost_familiar") == 2, "X upgrades")
    assert(inv:gamepadpressed("a"))
    assert(d.equipped.pet2 == "ghost_familiar", "A equips")
    inv:openModal("ghost_familiar", "pet2")
    assert(inv:gamepadpressed("b") and inv.modalItem == nil, "B closes")
    inv:openModal("ghost_familiar", "pet2")
    inv:gamepadpressed("a")
    assert(d.equipped.pet2 == nil, "A unequips an equipped item")
end

-- ============================================================================
-- COMBAT: the actual equipment is applied
-- ============================================================================
T["combat uses each equipped slot exactly once"] = function()
    local d = resetSave()
    Save.unequip("pet1")
    Save.equip("pet2", "ghost_familiar")
    Save.equip("ring2", "bear_ring")
    d.itemLevels.starter_bow = 3
    local GameState = require("src.states.game")
    local player = { damageMult = 1, critChance = 0, maxHp = 100, hp = 100, dodgeChance = 0,
        equipWeapon = function(p, id) p.weaponId = id end }
    GameState.applyEquipment({ player = player }, d.equipped)
    assert(#player.pets == 1, "only pet2 is equipped")
    assert(player.pets[1].type == "ghost_mage" and player.pets[1].slotIndex == 2)
    local wolf = Save.getItemStats("wolf_ring")
    local bear = Save.getItemStats("bear_ring")
    local vest = Save.getItemStats("vest_dexterity")
    assert(player.maxHp == 100 + vest.hp + bear.hp, "ring HP counted once")
    local expected = 1 + (Save.getItemPower("starter_bow") - 1) + wolf.atk / 30
    assert(math.abs(player.damageMult - expected) < 1e-9, "weapon level and ring ATK applied once")
end

-- ============================================================================
-- HUB: talents, quests, chests, modes
-- ============================================================================
local function newMenu()
    local MenuState = require("src.states.menu")
    local menu = MenuState.new({ switch = function() end })
    menu.saveData = Save.get()
    menu.inventory:refresh()
    return menu
end

local TALENT_CENTERS = { strength = { 81, 64 }, vitality = { 239, 64 }, agility = { 81, 128 }, recovery = { 239, 128 }, glory = { 262, 17 } }
local UPGRADE_BTN = { 160, 182 }

T["hub talents: tap a card, then upgrade exactly that talent"] = function()
    local d = resetSave()
    local menu = newMenu()
    menu.currentTab = "talents"
    for _, id in ipairs({ "agility", "recovery", "strength", "vitality" }) do
        local before = d.talents[id]
        tap(menu, TALENT_CENTERS[id][1], TALENT_CENTERS[id][2])
        assert(menu.selectedTalent == id, "card tap selects " .. id)
        tap(menu, UPGRADE_BTN[1], UPGRADE_BTN[2])
        assert(d.talents[id] == before + 1, id .. " must be the upgraded talent")
    end
end

T["hub talents: glory badge, d-pad and failure feedback"] = function()
    local d = resetSave()
    local menu = newMenu()
    menu.currentTab = "talents"
    tap(menu, TALENT_CENTERS.glory[1], TALENT_CENTERS.glory[2])
    assert(menu.selectedTalent == "glory")
    tap(menu, UPGRADE_BTN[1], UPGRADE_BTN[2])
    assert(d.talents.glory == 1 and menu.selectedTalent == "strength", "glory bought, selection back to strength")
    tap(menu, TALENT_CENTERS.glory[1], TALENT_CENTERS.glory[2])
    assert(menu.selectedTalent == "strength", "owned glory cannot be selected again")

    menu:gamepadpressed(nil, "dpdown")
    assert(menu.selectedTalent == "agility")
    menu:gamepadpressed(nil, "dpright")
    assert(menu.selectedTalent == "recovery")
    menu:gamepadpressed(nil, "a")
    assert(d.talents.recovery == 1, "A upgrades the selected talent")

    d.gold = 0
    menu:gamepadpressed(nil, "a")
    assert(d.talents.recovery == 1 and menu.talentFailTimer > 0, "no gold: nothing bought, message shown")
end

-- Touch geometry of the hub (src/states/menu.lua): 7 tabs of 45 px from x = 2 at y = 208..239,
-- full-width sub-tab row at y = 4..30
local function tabCenter(index) return 24 + (index - 1) * 45, 222 end
local QUEST_SUBTAB_CENTERS = { quests = { 54, 17 }, weekly = { 159, 17 }, achievements = { 264, 17 } }

T["hub quests: every subtab is reachable from every page"] = function()
    resetSave()
    local menu = newMenu()
    tap(menu, tabCenter(2)) -- QUESTS tab
    assert(menu.currentTab == "quests" and menu.questSubPage == "quests")
    for _, from in ipairs({ "quests", "weekly", "achievements" }) do
        for _, to in ipairs({ "quests", "weekly", "achievements" }) do
            menu.questSubPage = from
            tap(menu, QUEST_SUBTAB_CENTERS[to][1], QUEST_SUBTAB_CENTERS[to][2])
            assert(menu.questSubPage == to, from .. " -> " .. to)
        end
    end
    menu.questSubPage = "achievements"
    menu:gamepadpressed(nil, "b")
    assert(menu.questSubPage == "quests", "B goes back to daily quests")
    menu:gamepadpressed(nil, "b")
    assert(menu.currentTab == "play", "B again goes back to PLAY")
end

T["hub quests: a finished weekly mission can be claimed"] = function()
    local d = resetSave()
    local menu = newMenu()
    menu.currentTab = "quests"
    menu.questSubPage = "weekly"
    local list, w = Save.getWeeklyQuestList()
    local quest = list[1]
    w.progress[quest.kind] = quest.goal
    local gold, gems = d.gold, d.gems
    tap(menu, 279, 34 + 15) -- CLAIM button of the first weekly row
    assert(w.claimed[quest.id], "weekly mission claimed")
    assert(d.gold > gold or d.gems > gems, "reward granted")
end

T["hub chests: SHOP subtab, chest quest progress"] = function()
    local d = resetSave()
    local menu = newMenu()
    tap(menu, tabCenter(6)) -- CHESTS tab
    assert(menu.currentTab == "chests" and menu.chestSubPage == "chests")
    tap(menu, 155, 17) -- SHOP subtab
    assert(menu.chestSubPage == "shop")
    tap(menu, 53, 17) -- CHESTS subtab
    assert(menu.chestSubPage == "chests")
    local before = Save.getDailyQuests().progress.chests or 0
    tap(menu, 81, 150) -- golden chest
    assert(menu.openingChest == "gold")
    assert((Save.getDailyQuests().progress.chests or 0) == before + 1, "opening a chest counts for chest quests")
end

T["hub play: every mode card is selectable, including Arena"] = function()
    resetSave()
    local menu = newMenu()
    local modes = { "ascension", "infinite", "boss_rush", "survival" }
    for i, mode in ipairs(modes) do
        tap(menu, 4 + (i - 1) * 79 + 38, 124) -- mode chips row
        assert(menu.selectedMode == mode, "mode card " .. i .. " selects " .. mode)
    end
    menu:gamepadpressed(nil, "dpdown")
    assert(menu.selectedMode == "ascension", "d-pad cycles modes")
end

T["hub: leaving the forge closes the item sheet"] = function()
    resetSave()
    local menu = newMenu()
    tap(menu, tabCenter(4)) -- FORGE tab
    assert(menu.currentTab == "equipment")
    menu.inventory:openModal("bear_ring", nil)
    tap(menu, tabCenter(5)) -- TALENTS tab
    assert(menu.currentTab == "talents" and menu.inventory.modalItem == nil)
end

return T
