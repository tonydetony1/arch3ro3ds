if not love then
    love = {
        timer = { getTime = function() return 0 end },
        filesystem = {
            write = function() return true end,
            read = function() return nil end,
        },
        graphics = {
            getFont = function() return { getWidth = function() return 10 end, getHeight = function() return 10 end } end,
            setFont = function() end,
            newImage = function() return {} end,
            newQuad = function() return {} end,
            setColor = function() end,
            rectangle = function() end,
            circle = function() end,
            line = function() end,
            print = function() end,
            printf = function() end,
            push = function() end,
            pop = function() end,
            translate = function() end,
            scale = function() end,
            rotate = function() end,
            setScissor = function() end,
        },
        image = {
            newImageData = function() return {} end,
        }
    }
end

local Save = require("src.data.save")
local Balance = require("src.data.balance")

local T = {}

local function resetSave()
    Save.reset()
    local d = Save.get()
    d.gold = 50000
    d.gems = 1000
    d.inventory = {
        "starter_bow",
        "rapid_daggers",
        "vest_dexterity",
        "phantom_cloak",
        "wolf_ring",
        "bear_ring",
        "falcon_ring",
        "bat_companion",
        "ghost_familiar",
    }
    return d
end

T["equip into empty slots (ring2, pet2) succeeds"] = function()
    local d = resetSave()
    assert(d.equipped.ring2 == nil, "ring2 should start nil")
    assert(d.equipped.pet2 == nil, "pet2 should start nil")

    local okRing = Save.equip("ring2", "bear_ring")
    assert(okRing == true, "Save.equip('ring2') must succeed")
    assert(d.equipped.ring2 == "bear_ring", "ring2 must contain bear_ring")

    local okPet = Save.equip("pet2", "ghost_familiar")
    assert(okPet == true, "Save.equip('pet2') must succeed")
    assert(d.equipped.pet2 == "ghost_familiar", "pet2 must contain ghost_familiar")
end

T["unequip slots and re-equip succeeds"] = function()
    local d = resetSave()
    -- Initial: weapon = starter_bow, ring1 = wolf_ring, pet1 = bat_companion
    assert(d.equipped.weapon == "starter_bow")
    assert(d.equipped.ring1 == "wolf_ring")
    assert(d.equipped.pet1 == "bat_companion")

    -- Unequip weapon
    local okW = Save.unequip("weapon")
    assert(okW == true, "Save.unequip('weapon') must succeed")
    assert(d.equipped.weapon == nil, "weapon must now be nil")

    -- Re-equip weapon
    local okW2 = Save.equip("weapon", "rapid_daggers")
    assert(okW2 == true, "Save.equip('weapon') must succeed after unequip")
    assert(d.equipped.weapon == "rapid_daggers")

    -- Unequip ring1
    local okR = Save.unequip("ring1")
    assert(okR == true, "Save.unequip('ring1') must succeed")
    assert(d.equipped.ring1 == nil, "ring1 must now be nil")
    assert(d.equipped.ring == nil, "legacy ring mirror must be nil when ring1 is nil")

    -- Re-equip ring1
    local okR2 = Save.equip("ring1", "falcon_ring")
    assert(okR2 == true, "Save.equip('ring1') must succeed after unequip")
    assert(d.equipped.ring1 == "falcon_ring")
    assert(d.equipped.ring == "falcon_ring", "legacy ring mirror must sync with ring1")

    -- Unequip pet1
    local okP = Save.unequip("pet1")
    assert(okP == true, "Save.unequip('pet1') must succeed")
    assert(d.equipped.pet1 == nil, "pet1 must now be nil")
    assert(d.equipped.pet == nil, "legacy pet mirror must be nil when pet1 is nil")

    -- Re-equip pet1
    local okP2 = Save.equip("pet1", "ghost_familiar")
    assert(okP2 == true, "Save.equip('pet1') must succeed after unequip")
    assert(d.equipped.pet1 == "ghost_familiar")
    assert(d.equipped.pet == "ghost_familiar", "legacy pet mirror must sync with pet1")
end

T["Save.isEquipped detects slot accurately"] = function()
    local d = resetSave()
    Save.equip("ring2", "bear_ring")

    local eq, slot = Save.isEquipped("starter_bow")
    assert(eq == true and slot == "weapon")

    local eqRing2, slotRing2 = Save.isEquipped("bear_ring")
    assert(eqRing2 == true and slotRing2 == "ring2")

    local eqNone, slotNone = Save.isEquipped("falcon_ring")
    assert(eqNone == false and slotNone == nil)

    -- After unequipping ring1:
    Save.unequip("ring1")
    local eqWolf, slotWolf = Save.isEquipped("wolf_ring")
    assert(eqWolf == false and slotWolf == nil, "wolf_ring must not be equipped after unequip")
end

T["invalid slots are rejected by Save.equip and Save.unequip"] = function()
    resetSave()
    assert(Save.equip("nonexistent_slot", "wolf_ring") == false)
    assert(Save.unequip("nonexistent_slot") == false)
end

T["talents: upgrade specific stat"] = function()
    local d = resetSave()
    d.talents = { strength = 0, vitality = 0, recovery = 0, agility = 0, glory = 0 }
    d.gold = 50000

    -- Upgrade strength specifically
    local okS, chosenS, lvlS = Save.upgradeTalent("strength")
    assert(okS == true, "upgradeTalent('strength') must succeed")
    assert(chosenS == "strength", "chosen stat must be strength")
    assert(d.talents.strength == 1, "strength must be 1")
    assert(d.talents.vitality == 0, "vitality must still be 0")

    -- Upgrade agility specifically
    local okA, chosenA, lvlA = Save.upgradeTalent("agility")
    assert(okA == true, "upgradeTalent('agility') must succeed")
    assert(chosenA == "agility", "chosen stat must be agility")
    assert(d.talents.agility == 1, "agility must be 1")
    assert(d.talents.vitality == 0, "vitality must still be 0")

    -- Upgrade recovery specifically
    local okR, chosenR, lvlR = Save.upgradeTalent("recovery")
    assert(okR == true, "upgradeTalent('recovery') must succeed")
    assert(chosenR == "recovery", "chosen stat must be recovery")
    assert(d.talents.recovery == 1, "recovery must be 1")
    assert(d.talents.vitality == 0, "vitality must still be 0")

    -- Upgrade vitality specifically
    local okV, chosenV, lvlV = Save.upgradeTalent("vitality")
    assert(okV == true, "upgradeTalent('vitality') must succeed")
    assert(chosenV == "vitality", "chosen stat must be vitality")
    assert(d.talents.vitality == 1, "vitality must be 1")
end

T["talents: cost formula is consistent with Save.getTalentCost"] = function()
    local d = resetSave()
    d.talents = { strength = 2, vitality = 1, recovery = 1, agility = 1, glory = 0 }
    local totalLevel = 5
    local expectedCost = Balance.COSTS.talentBase + totalLevel * Balance.COSTS.talentStep
    assert(Save.getTalentCost() == expectedCost, "Save.getTalentCost() must match Balance.COSTS formula")
end

T["talents: upgrade with no arg picks from pool"] = function()
    local d = resetSave()
    d.talents = { strength = 0, vitality = 0, recovery = 0, agility = 0, glory = 0 }
    d.gold = 10000

    local ok, chosen, lvl = Save.upgradeTalent()
    assert(ok == true, "random upgrade must succeed")
    assert(chosen == "strength" or chosen == "vitality" or chosen == "recovery" or chosen == "agility" or chosen == "glory")
    assert(d.talents[chosen] == 1)
end

T["inventory toggleEquip equips and unequips weapons, armor, rings, pets"] = function()
    local d = resetSave()
    local Inventory = require("src.states.inventory")
    local inv = Inventory.new()
    inv:refresh()

    -- Initial: weapon = starter_bow, armor = vest_dexterity, ring1 = wolf_ring, pet1 = bat_companion
    assert(inv:isEquipped("starter_bow") == true)
    assert(inv:isEquipped("vest_dexterity") == true)
    assert(inv:isEquipped("wolf_ring") == true)
    assert(inv:isEquipped("bat_companion") == true)
    assert(inv:isEquipped("bear_ring") == false)
    assert(inv:isEquipped("ghost_familiar") == false)

    -- 1. Unequip weapon
    inv:toggleEquip("starter_bow", "weapon")
    assert(inv:isEquipped("starter_bow") == false, "starter_bow should now be unequipped")
    assert(d.equipped.weapon == nil)

    -- 2. Equip another weapon
    inv:toggleEquip("rapid_daggers", nil)
    assert(inv:isEquipped("rapid_daggers") == true, "rapid_daggers should now be equipped")
    assert(d.equipped.weapon == "rapid_daggers")

    -- 3. Unequip armor
    inv:toggleEquip("vest_dexterity", "armor")
    assert(inv:isEquipped("vest_dexterity") == false, "vest_dexterity should now be unequipped")
    assert(d.equipped.armor == nil)

    -- 4. Equip second ring (ring2)
    assert(d.equipped.ring2 == nil)
    inv:toggleEquip("bear_ring", nil)
    assert(inv:isEquipped("bear_ring") == true, "bear_ring should be equipped")
    assert(d.equipped.ring2 == "bear_ring", "bear_ring should be in ring2")
    assert(d.equipped.ring1 == "wolf_ring", "ring1 should still be wolf_ring")

    -- 5. Unequip ring1
    inv:toggleEquip("wolf_ring", "ring1")
    assert(inv:isEquipped("wolf_ring") == false, "wolf_ring should now be unequipped")
    assert(d.equipped.ring1 == nil)
    assert(d.equipped.ring2 == "bear_ring", "ring2 should still have bear_ring")

    -- 6. Equip third ring into freed ring1
    inv:toggleEquip("falcon_ring", nil)
    assert(inv:isEquipped("falcon_ring") == true)
    assert(d.equipped.ring1 == "falcon_ring", "falcon_ring should occupy empty ring1")

    -- 7. Equip second pet (pet2)
    assert(d.equipped.pet2 == nil)
    inv:toggleEquip("ghost_familiar", nil)
    assert(inv:isEquipped("ghost_familiar") == true)
    assert(d.equipped.pet2 == "ghost_familiar", "ghost_familiar should occupy pet2")
    assert(d.equipped.pet1 == "bat_companion", "pet1 should still be bat_companion")

    -- 8. Unequip pet1
    inv:toggleEquip("bat_companion", "pet1")
    assert(inv:isEquipped("bat_companion") == false, "bat_companion should now be unequipped")
    assert(d.equipped.pet1 == nil)
    assert(d.equipped.pet2 == "ghost_familiar")
end

T["inventory: tapping empty slot opens candidate modal with targeted slot"] = function()
    local d = resetSave()
    local Inventory = require("src.states.inventory")
    local inv = Inventory.new()
    inv:refresh()

    -- pet2 starts empty. Tapping slot pet2 (x=218, y=46, w=46, h=37)
    assert(d.equipped.pet2 == nil)
    -- ghost_familiar is in inventory and unequipped
    inv:touchpressed(1, 230, 55)
    assert(inv.modalItem ~= nil, "Modal must open for available pet")
    assert(inv.modalItemId == "ghost_familiar", "Available unequipped pet should be loaded")
    assert(inv.modalSourceSlot == "pet2", "Target slot must be pet2")

    -- Now confirm equip
    inv.pressedBtn = "equip"
    inv:touchreleased(1, 40, 160)
    assert(d.equipped.pet2 == "ghost_familiar", "pet2 should now be equipped with ghost_familiar")
end

T["inventory: choosing slot1 or slot2 explicitly replaces target slot"] = function()
    local d = resetSave()
    local Inventory = require("src.states.inventory")
    local inv = Inventory.new()
    -- Equip ring1 (wolf_ring) and ring2 (bear_ring)
    Save.equip("ring1", "wolf_ring")
    Save.equip("ring2", "bear_ring")
    inv:refresh()

    -- Open unequipped falcon_ring from backpack
    inv:openModal("falcon_ring", nil)
    assert(inv.modalItem ~= nil)

    -- Player taps SLOT 2 button (equip2)
    inv.pressedBtn = "equip2"
    inv:touchreleased(1, 100, 160)
    assert(d.equipped.ring2 == "falcon_ring", "ring2 should be replaced by falcon_ring")
    assert(d.equipped.ring1 == "wolf_ring", "ring1 should remain wolf_ring")
end

T["save load preserves unequipped slots without forced reset"] = function()
    local d = resetSave()
    Save.unequip("weapon")
    Save.unequip("ring2")
    Save.unequip("pet2")
    assert(d.equipped.weapon == nil)
    assert(d.equipped.ring2 == nil)
    assert(d.equipped.pet2 == nil)

    -- Re-load save
    Save.load()
    local loaded = Save.get()
    assert(loaded.equipped.weapon == nil, "weapon should stay nil")
    assert(loaded.equipped.ring2 == nil, "ring2 should stay nil")
    assert(loaded.equipped.pet2 == nil, "pet2 should stay nil")
end

T["inventory: gamepad and keyboard support"] = function()
    local d = resetSave()
    local Inventory = require("src.states.inventory")
    local inv = Inventory.new()
    inv:refresh()

    -- Open modal
    inv:openModal("wolf_ring", "ring1")
    assert(inv.modalItem ~= nil)

    -- Gamepad B closes modal
    inv:gamepadpressed("b")
    assert(inv.modalItem == nil, "Gamepad B should close modal")

    -- Open modal again and test Gamepad A (toggle equip)
    inv:openModal("wolf_ring", "ring1")
    assert(inv:isEquipped("wolf_ring") == true)
    inv:gamepadpressed("a")
    assert(inv:isEquipped("wolf_ring") == false, "Gamepad A should unequip wolf_ring")

    -- Re-open and test Keyboard Space/Return to re-equip
    inv:openModal("wolf_ring", "ring1")
    inv:keypressed("return")
    assert(inv:isEquipped("wolf_ring") == true, "Keyboard return should re-equip wolf_ring")
end

T["quests and achievements subpage switching"] = function()
    local MenuState = require("src.states.menu")
    local menu = MenuState.new({})
    menu.currentTab = "quests"
    menu.questSubPage = "quests"

    -- 1. Switch to achievements using subtab_achievements
    menu.pressedBtn = "subtab_achievements"
    menu:touchreleased(1, 280, 10)
    assert(menu.questSubPage == "achievements", "Should switch to achievements")

    -- 2. Switch back to quests using subtab_quests
    menu.pressedBtn = "subtab_quests"
    menu:touchreleased(1, 220, 10)
    assert(menu.questSubPage == "quests", "Should switch back to quests via subtab_quests")

    -- 3. If on achievements and user taps the dock tab_quests, should also reset to quests
    menu.questSubPage = "achievements"
    menu.pressedBtn = "tab_quests"
    menu:touchreleased(1, 50, 220)
    assert(menu.questSubPage == "quests", "Tapping dock tab_quests should reset questSubPage to quests")
end

return T
