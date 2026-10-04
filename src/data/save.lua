-- src/data/save.lua
-- Player data persistence system (Gold, Gems, Inventory, Equipment, Records)
-- 100% compatible with Nintendo 3DS (LÖVE-Potion) and PC Desktop (LÖVE2D) via love.filesystem

local Balance = require("src.data.balance")
local Admin = require("src.data.admin")
local Talents = require("src.data.talents")

local Save = {
    SAVE_FILE = "arch3ro_save.lua",
    BACKUP_FILE = "arch3ro_save_secours.lua",
    data = nil,
}

-- End marker: a file without this was truncated (interrupted during write)
local END_MARK = "-- fin arch3ro"

-- Default data for a new game
local function getDefaultData()
    return {
        gold = 350,
        gems = 60,
        energy = 20,
        maxEnergy = 20,
        accountLevel = 1,
        accountXp = 0,
        records = {
            ascensionMax = 1,
            infiniteMax = 0,
        },
        talents = {
            strength = 0,
            vitality = 0,
            recovery = 0,
            agility = 0,
            glory = 0,
        },
        selectedHero = "atreus",
        unlockedHeroes = {
            atreus = true,
            urasil = true,
            phoren = false,
            helix = false,
            rolla = false,
        },
        selectedChapter = 1,
        audio = { music = 0.55, sfx = 0.85 },

        -- Daily quests & battle pass
        dailyQuests = {
            day = "",
            points = 0,
            progress = { kills = 0, rooms = 0, chests = 0, upgrades = 0, bosses = 0 },
            claimed = {},
            claimedTiers = {},
        },
        -- Weekly quests (tracked separately from daily quests)
        weeklyQuests = { week = "", progress = {}, claimed = {}, selected = {} },
        -- Bestiary: kills per monster type
        bestiary = {},
        -- Event mode records
        events = { bossRushBest = 0, survivalBest = 0 },

        patrolGold = 150,
        patrolMax = 500,
        -- Starting equipment: only common Ranger gear.
        -- Everything else unlocks via chests (see Items.DROP_TABLES).
        itemCopies = {
            starter_bow = 1,
            vest_dexterity = 1,
            wolf_ring = 1,
            bat_companion = 1,
        },
        itemRarities = {},
        itemStars = {},
        achievements = {},
        shop = { day = "", bought = {} },
        energyStamp = 0,
        -- Six slots (see Save.EQUIP_SLOTS); an empty slot is simply absent
        equipped = {
            weapon = "starter_bow",
            armor = "vest_dexterity",
            ring1 = "wolf_ring",
            pet1 = "bat_companion",
        },
        dualSlotsV2 = true, -- 6-slot equipment layout (see Save.migrateEquipment)
        itemLevels = {
            starter_bow = 1,
            vest_dexterity = 1,
            wolf_ring = 1,
            bat_companion = 1,
        },
        inventory = {
            "starter_bow",
            "vest_dexterity",
            "wolf_ring",
            "bat_companion",
        },
        -- Migration flag: older saves owned the entire catalog by default
        itemUnlockRework = true,
        settings = {
            debugMode = true,
            sound = true,
            depth3d = 1.0,       -- stereoscopic 3D depth intensity (0 to 1.5)
            showDamage = true,   -- floating combat damage numbers
            lowPower = false,    -- power saving mode: fewer particles (Old 3DS)
            autoDash = false,    -- automatic dodge dash when a projectile nears
        },
    }
end

-- Native recursive Lua serializer (zero external dependencies, reliable on Old 3DS)
local function serializeTable(val, indent)
    indent = indent or ""
    local t = type(val)
    if t == "number" or t == "boolean" then
        return tostring(val)
    elseif t == "string" then
        return string.format("%q", val)
    elseif t == "table" then
        local parts = { "{\n" }
        local nextIndent = indent .. "  "
        local keys = {}
        for k in pairs(val) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b)
            if type(a) == type(b) then return a < b end
            return type(a) < type(b)
        end)
        for _, k in ipairs(keys) do
            local v = val[k]
            local keyStr = (type(k) == "string" and string.match(k, "^[a-zA-Z_][a-zA-Z0-9_]*$"))
                and k or "[" .. serializeTable(k) .. "]"
            table.insert(parts, nextIndent .. keyStr .. " = " .. serializeTable(v, nextIndent) .. ",\n")
        end
        table.insert(parts, indent .. "}")
        return table.concat(parts)
    else
        return "nil"
    end
end

-- Safely reads a save file: complete content (end marker) executed in a sandbox
-- (a modified save cannot invoke any external functions).
local function readSaveFile(path)
    -- Direct read (missing file returns nil): no prior getInfo call,
    -- since each file lookup is costly on 3DS SD cards
    local okRead, content = pcall(love.filesystem.read, path)
    if not okRead or type(content) ~= "string" then return nil end
    -- Older saves (before the end marker) are still accepted if they end with "}"
    if not content:find(END_MARK, 1, true) and not content:match("}%s*$") then return nil end
    local chunk = loadstring(content, "=" .. path)
    if not chunk then return nil end
    setfenv(chunk, {})
    local ok, data = pcall(chunk)
    if ok and type(data) == "table" then return data end
    return nil
end

-- Between the two valid save files, pick the one with the highest sequence number
-- (legacy saves without a sequence number default to 0; main save wins on ties)
local function newestSave()
    local main = readSaveFile(Save.SAVE_FILE)
    local backup = readSaveFile(Save.BACKUP_FILE)
    if main and backup then
        local seqMain = tonumber(main.saveSeq) or 0
        local seqBackup = tonumber(backup.saveSeq) or 0
        return (seqBackup > seqMain) and backup or main
    end
    return main or backup
end

-- Load from persistent storage (picks the newest valid slot)
function Save.load()
    if Save.data then return Save.data end

    local loadedData = newestSave()
    if loadedData then
        Save.data = loadedData
        -- Fingerprint before migrations: only rewrite the save if a migration changed
        -- something (writing to an SD card costs ~0.1 s on boot)
        local loadedText = serializeTable(loadedData)
        -- Before default values: they would introduce the dualSlotsV2 flag
        Save.migrateEquipment()
        -- Safety: inject missing keys in case schema was updated
        local defaultData = getDefaultData()
        for k, v in pairs(defaultData) do
            if Save.data[k] == nil then
                Save.data[k] = v
            end
        end
        if Save.data.inventory then
            local existing = {}
            for _, id in ipairs(Save.data.inventory) do
                existing[id] = true
            end
            for _, id in ipairs(defaultData.inventory) do
                if not existing[id] then
                    table.insert(Save.data.inventory, id)
                    existing[id] = true
                end
            end
        end
        if Save.data.itemLevels then
            for k, lvl in pairs(defaultData.itemLevels) do
                if Save.data.itemLevels[k] == nil then
                    Save.data.itemLevels[k] = lvl
                end
            end
        end
        if Save.data.talents == nil then
            Save.data.talents = {
                strength = 0,
                vitality = 0,
                recovery = 0,
                agility = 0,
                glory = 0,
            }
        end
        -- Migration: older saves gave the entire item catalog up front.
        -- We only keep the starter set; the rest unlocks via chests.
        if not Save.data.itemUnlockRework then
            Save.applyUnlockRework()
        end
        Save.sanitizeEquipment()
        Admin.load(Save.data.admin)
        if serializeTable(Save.data) ~= loadedText then Save.save() end
        return Save.data
    end

    -- First game or corrupted file: default initialization
    Save.data = getDefaultData()
    Admin.load(nil)
    Save.save()
    return Save.data
end

-- Clear all progress and start fresh
function Save.reset()
    -- Sequence number continues: older progress with higher seq must not overwrite
    local seq = Save.data and Save.data.saveSeq
    Save.data = getDefaultData()
    Save.data.saveSeq = seq
    Admin.load(nil)
    Save.save()
    Save.applySettings()
    return Save.data
end

-- Apply Settings page configuration to relevant modules
function Save.applySettings()
    local d = Save.get()
    local st = d.settings or {}

    local okDepth, Depth = pcall(require, "src.render.depth")
    if okDepth and Depth then Depth.userScale = st.depth3d or 1.0 end

    local okVfx, VFX = pcall(require, "src.render.vfx_manager")
    if okVfx and VFX then
        VFX.showDamage = (st.showDamage ~= false)
        VFX.particleScale = st.lowPower and 0.4 or 1.0
    end
end

-- Starter equipment retained during the unlock rework
Save.STARTER_ITEMS = { "starter_bow", "vest_dexterity", "wolf_ring", "bat_companion" }

-- Remove unearned items from inventory: only starter equipment remains.
-- Compensate player with gold so they can immediately open chests.
function Save.applyUnlockRework()
    local d = Save.data
    if not d then return end

    local keep = {}
    for _, id in ipairs(Save.STARTER_ITEMS) do keep[id] = true end

    local removed = 0
    local newInventory = {}
    for _, id in ipairs(d.inventory or {}) do
        if keep[id] then
            table.insert(newInventory, id)
        else
            removed = removed + 1
            if d.itemCopies then d.itemCopies[id] = nil end
            if d.itemLevels then d.itemLevels[id] = nil end
            if d.itemRarities then d.itemRarities[id] = nil end
            if d.itemStars then d.itemStars[id] = nil end
        end
    end
    d.inventory = newInventory

    -- Compensation: enough gold to open two gold chests
    if removed > 0 then
        d.gold = (d.gold or 0) + 300
    end
    d.itemUnlockRework = true
end

-- Migration: before dual slots, rings and pets lived in equipped.ring / equipped.pet.
-- These keys duplicated ring1 / pet1 and caused double counting: remove them.
function Save.migrateEquipment()
    local d = Save.data
    local eq = d and d.equipped
    if type(eq) ~= "table" then return end
    if not d.dualSlotsV2 then
        eq.ring1 = eq.ring1 or eq.ring
        eq.pet1 = eq.pet1 or eq.pet
        d.dualSlotsV2 = true
    end
    eq.ring, eq.pet = nil, nil
end

-- Clean up equipment: only keep the 6 valid slot keys, each with an owned item
-- of the correct type equipped once. Missing items fallback to starter gear.
function Save.sanitizeEquipment()
    local d = Save.data
    if not d or not d.equipped then return end

    local owned = {}
    for _, id in ipairs(d.inventory or {}) do owned[id] = true end

    local fallback = { weapon = "starter_bow", armor = "vest_dexterity", ring1 = "wolf_ring", pet1 = "bat_companion" }
    local clean, worn = {}, {}
    for _, slot in ipairs(Save.EQUIP_SLOT_ORDER) do
        local itemId = d.equipped[slot]
        if itemId and not owned[itemId] then
            itemId = (fallback[slot] and owned[fallback[slot]]) and fallback[slot] or nil
        end
        if itemId and Save.slotAccepts(slot, itemId) and not worn[itemId] then
            clean[slot] = itemId
            worn[itemId] = true
        end
    end
    -- Modify in-place only where needed: an already clean save remains identical
    -- and is not rewritten at boot (see Save.load)
    for slot, itemId in pairs(d.equipped) do
        if clean[slot] ~= itemId then d.equipped[slot] = nil end
    end
    for slot, itemId in pairs(clean) do
        if d.equipped[slot] ~= itemId then d.equipped[slot] = itemId end
    end
end

-- Ping-pong save writing: each save increments sequence number and writes to
-- the older slot. A power loss during write leaves the other slot intact,
-- and Save.load recovers the newest valid slot. Single write per save:
-- on 3DS SD cards, every write takes ~0.1 s regardless of size.
function Save.save()
    if not Save.data then return false end
    local seq = (Save.data.saveSeq or 0) + 1
    Save.data.saveSeq = seq
    local content = "return " .. serializeTable(Save.data) .. "\n" .. END_MARK .. "\n"
    local target = (seq % 2 == 1) and Save.SAVE_FILE or Save.BACKUP_FILE
    if love and love.filesystem and love.filesystem.write then
        return love.filesystem.write(target, content)
    end
    return true
end

-- ============================================================================
-- RUN RESUME: snapshot of the run at the start of each room
-- ============================================================================
-- Hero fields that must not be restored (position, velocity, timers)
local RUN_SKIP = {
    x = true, y = true, vx = true, vy = true, targetAngle = true, currentTarget = true,
    isMoving = true, wasMoving = true, hasInput = true, benchInputX = true, benchInputY = true,
}

function Save.saveRun(game)
    local d = Save.get()
    if game.gameMode ~= "ascension" and game.gameMode ~= "infinite" then return end
    local stats = {}
    for k, v in pairs(game.player) do
        local t = type(v)
        if not RUN_SKIP[k] and (t == "number" or t == "boolean" or t == "string") then
            stats[k] = v
        end
    end
    local skills = {}
    for i, sk in ipairs(game.acquiredSkills or {}) do skills[i] = sk.id end
    d.run = {
        mode = game.gameMode,
        room = game.roomNumber,
        gold = game.goldEarnedRun or 0,
        kills = game.kills or 0,
        ultimate = game.ultimateCharge or 0,
        heroId = game.player.heroId,
        weapon = game.player.currentWeapon and game.player.currentWeapon.id,
        skills = skills,
        player = stats,
    }
    Save.save()
end

function Save.getRun()
    local d = Save.get()
    return d.run
end

function Save.clearRun()
    local d = Save.get()
    if d.run then
        d.run = nil
        Save.save()
    end
end

function Save.get()
    if not Save.data then
        Save.load()
    end
    return Save.data
end

-- Add gold
function Save.addGold(amount)
    local d = Save.get()
    d.gold = math.max(0, d.gold + amount)
    Save.save()
    return d.gold
end

-- Add gems
function Save.addGems(amount)
    local d = Save.get()
    d.gems = math.max(0, d.gems + amount)
    Save.save()
    return d.gems
end

-- Add item to inventory
function Save.addItem(itemId)
    local d = Save.get()
    d.itemCopies = d.itemCopies or {}
    for _, id in ipairs(d.inventory) do
        if id == itemId then
            -- Already owned: increment copy count for fusion and award gold bonus
            d.itemCopies[itemId] = (d.itemCopies[itemId] or 1) + 1
            Save.addGold(75)
            Save.save()
            return false, string.format("COPY OBTAINED (%d/3)", d.itemCopies[itemId])
        end
    end
    table.insert(d.inventory, itemId)
    d.itemCopies[itemId] = (d.itemCopies[itemId] or 0) + 1
    if not d.itemLevels[itemId] then
        d.itemLevels[itemId] = 1
    end
    Save.save()
    return true, "NEW ITEM"
end

-- ============================================================================
-- EQUIPMENT: 6 slots, each reserved for a specific item type
-- ============================================================================
Save.EQUIP_SLOT_ORDER = { "weapon", "armor", "ring1", "ring2", "pet1", "pet2" }
Save.EQUIP_SLOTS = {
    weapon = "weapon",
    armor = "armor",
    ring1 = "ring",
    ring2 = "ring",
    pet1 = "pet",
    pet2 = "pet",
}
-- Candidate slots for each item type in order of filling
Save.SLOTS_BY_TYPE = {
    weapon = { "weapon" },
    armor = { "armor" },
    ring = { "ring1", "ring2" },
    pet = { "pet1", "pet2" },
}

local function itemSlotType(itemId)
    local Items = require("src.data.items")
    local item = itemId and Items.get(itemId)
    return item and item.slot or nil
end

-- Does the slot accept this item type? (e.g. a ring cannot go into a pet slot)
function Save.slotAccepts(slot, itemId)
    local slotType = Save.EQUIP_SLOTS[slot]
    return slotType ~= nil and slotType == itemSlotType(itemId)
end

function Save.ownsItem(itemId)
    local d = Save.get()
    for _, id in ipairs(d.inventory or {}) do
        if id == itemId then return true end
    end
    return false
end

-- Check if item is equipped, returns (isEquipped, slotId)
function Save.isEquipped(itemId)
    local d = Save.get()
    if not d or not d.equipped or not itemId then return false, nil end
    for _, slot in ipairs(Save.EQUIP_SLOT_ORDER) do
        if d.equipped[slot] == itemId then
            return true, slot
        end
    end
    return false, nil
end

-- Equips an owned item into a compatible slot (replaces existing item).
-- An item already equipped elsewhere moves to the new slot.
function Save.equip(slot, itemId)
    local d = Save.get()
    if not d or not d.equipped then return false end
    if not Save.slotAccepts(slot, itemId) or not Save.ownsItem(itemId) then return false end
    for _, otherSlot in ipairs(Save.EQUIP_SLOT_ORDER) do
        if otherSlot ~= slot and d.equipped[otherSlot] == itemId then
            d.equipped[otherSlot] = nil
        end
    end
    d.equipped[slot] = itemId
    Save.save()
    return true
end

-- Clear a slot
function Save.unequip(slot)
    local d = Save.get()
    if not d or not d.equipped or not Save.EQUIP_SLOTS[slot] then return false end
    if d.equipped[slot] == nil then return false end
    d.equipped[slot] = nil
    Save.save()
    return true
end

-- Get item level
function Save.getItemLevel(itemId)
    local d = Save.get()
    return d.itemLevels[itemId] or 1
end

-- Current item stats (level, fused rarity, stars)
function Save.getItemStats(itemId)
    local Items = require("src.data.items")
    return Items.getStats(itemId, Save.getItemLevel(itemId), Save.getItemRarity(itemId), Save.getItemStars(itemId))
end

-- Item power ratio relative to base starter version (see Items.powerRatio)
function Save.getItemPower(itemId)
    local Items = require("src.data.items")
    return Items.powerRatio(itemId, Save.getItemLevel(itemId), Save.getItemRarity(itemId), Save.getItemStars(itemId))
end

-- Upgrade cost for next level (depends on level and current rarity)
function Save.getUpgradeCost(itemId)
    local Items = require("src.data.items")
    return Items.getUpgradeCost(Save.getItemLevel(itemId), Save.getItemRarity(itemId))
end

-- Equipment upgrade (Forge): returns (success, level, cost)
function Save.upgradeItem(itemId)
    local d = Save.get()
    local lvl = Save.getItemLevel(itemId)
    local cost = Save.getUpgradeCost(itemId)

    if Save.ownsItem(itemId) and d.gold >= cost then
        d.gold = d.gold - cost
        d.itemLevels[itemId] = lvl + 1
        Save.addQuestProgress("upgrades", 1)
        Save.save()
        return true, lvl + 1, cost
    end
    return false, lvl, cost
end

-- Get talents
function Save.getTalents()
    local d = Save.get()
    if not d.talents then
        d.talents = { strength = 0, vitality = 0, recovery = 0, agility = 0, glory = 0 }
    end
    return d.talents
end

-- Next talent upgrade cost (scales with total purchased talents)
function Save.getTalentCost()
    local totalLevel = Talents.totalLevel(Save.getTalents())
    return Balance.COSTS.talentBase + totalLevel * Balance.COSTS.talentStep, totalLevel
end

-- Buy a level for player-selected talent: returns (success, talent, level, cost)
function Save.upgradeTalent(talentName)
    local d = Save.get()
    local talents = Save.getTalents()
    local cost = Save.getTalentCost()

    if not Talents.canUpgrade(talentName, talents) or d.gold < cost then
        return false, talentName, talents[talentName] or 0, cost
    end
    d.gold = d.gold - cost
    talents[talentName] = (talents[talentName] or 0) + 1
    Save.save()
    return true, talentName, talents[talentName], cost
end

-- ============================================================================
-- ARCHERO 2 SYSTEMS: HEROES, AFK PATROL, CHAPTERS & FUSION
-- ============================================================================

-- Active hero selection
function Save.selectHero(heroId)
    local d = Save.get()
    d.unlockedHeroes = d.unlockedHeroes or { atreus = true, urasil = true }
    if d.unlockedHeroes[heroId] then
        d.selectedHero = heroId
        Save.save()
        return true
    end
    return false
end

-- Unlock hero with Gold or Gems
function Save.unlockHero(heroId)
    local Heroes = require("src.data.heroes")
    local h = Heroes.get(heroId)
    local d = Save.get()
    d.unlockedHeroes = d.unlockedHeroes or { atreus = true, urasil = true }
    if not h then return false end
    if d.unlockedHeroes[heroId] then return true end

    if h.costType == "free" then
        d.unlockedHeroes[heroId] = true
        Save.save()
        return true
    elseif h.costType == "gold" and (d.gold or 0) >= (h.cost or 0) then
        d.gold = d.gold - h.cost
        d.unlockedHeroes[heroId] = true
        Save.save()
        return true
    elseif h.costType == "gems" and (d.gems or 0) >= (h.cost or 0) then
        d.gems = d.gems - h.cost
        d.unlockedHeroes[heroId] = true
        Save.save()
        return true
    end
    return false
end

-- Claim AFK Patrol (Idle Chest)
function Save.claimPatrol()
    local d = Save.get()
    local amt = math.floor(d.patrolGold or 0)
    if amt > 0 then
        d.gold = d.gold + amt
        d.patrolGold = 0
        Save.save()
        return amt
    end
    return 0
end

-- Passive AFK patrol gold accumulation
function Save.updatePatrol(dt)
    local d = Save.get()
    d.patrolMax = d.patrolMax or 500
    if (d.patrolGold or 0) < d.patrolMax then
        d.patrolGold = math.min(d.patrolMax, (d.patrolGold or 0) + dt * 1.5)
    end
end

-- ============================================================================
-- DAILY QUESTS & BATTLE PASS
-- ============================================================================
local Quests = require("src.data.quests")

local function todayKey()
    return os.date("%Y-%j")
end

local function weekKey()
    return os.date("%Y-W%W")
end

-- Returns quest state, resetting if date has rolled over
function Save.getDailyQuests()
    local d = Save.get()
    d.dailyQuests = d.dailyQuests or { day = "", points = 0, progress = {}, claimed = {}, claimedTiers = {} }
    local q = d.dailyQuests
    q.progress = q.progress or {}
    q.claimed = q.claimed or {}
    q.claimedTiers = q.claimedTiers or {}
    if q.day ~= todayKey() then
        q.day = todayKey()
        q.points = 0
        q.progress = { kills = 0, rooms = 0, chests = 0, upgrades = 0, bosses = 0, skills = 0, gold = 0, pots = 0, runs = 0 }
        q.claimed = {}
        q.claimedTiers = {}
        -- Fresh mission draw: daily pool rotates each day
        q.selected = {}
        for _, quest in ipairs(Quests.dailySelection(q.day)) do
            q.selected[#q.selected + 1] = quest.id
        end
        Save.save()
    end
    if not q.selected or #q.selected == 0 then
        q.selected = {}
        for _, quest in ipairs(Quests.dailySelection(q.day)) do
            q.selected[#q.selected + 1] = quest.id
        end
    end
    return q
end

-- Daily quests currently drawn (full quest objects, not just ids)
function Save.getDailyQuestList()
    local q = Save.getDailyQuests()
    local list = {}
    for _, id in ipairs(q.selected or {}) do
        local quest = Quests.get(id)
        if quest then list[#list + 1] = quest end
    end
    return list, q
end

-- Weekly quests: separate progress counters, reset weekly
function Save.getWeeklyQuests()
    local d = Save.get()
    d.weeklyQuests = d.weeklyQuests or { week = "", progress = {}, claimed = {}, selected = {} }
    local w = d.weeklyQuests
    w.progress = w.progress or {}
    w.claimed = w.claimed or {}
    if w.week ~= weekKey() then
        w.week = weekKey()
        w.progress = { kills = 0, rooms = 0, chests = 0, upgrades = 0, bosses = 0, skills = 0, gold = 0, pots = 0, runs = 0 }
        w.claimed = {}
        w.selected = {}
        for _, quest in ipairs(Quests.weeklySelection(w.week)) do
            w.selected[#w.selected + 1] = quest.id
        end
        Save.save()
    end
    return w
end

function Save.getWeeklyQuestList()
    local w = Save.getWeeklyQuests()
    local list = {}
    for _, id in ipairs(w.selected or {}) do
        local quest = Quests.get(id)
        if quest then list[#list + 1] = quest end
    end
    return list, w
end

-- Progress a quest counter ("kills", "rooms", "chests", "upgrades", "bosses")
-- persist = true writes immediately (outside combat)
function Save.addQuestProgress(kind, amount, persist)
    local q = Save.getDailyQuests()
    q.progress[kind] = (q.progress[kind] or 0) + (amount or 1)

    -- Same actions also advance weekly missions
    local w = Save.getWeeklyQuests()
    w.progress[kind] = (w.progress[kind] or 0) + (amount or 1)

    if persist then Save.save() end
    return q.progress[kind]
end

-- Claim a completed weekly quest
function Save.claimWeeklyQuest(questId)
    local quest = Quests.get(questId)
    if not quest then return false end
    local w = Save.getWeeklyQuests()
    local progress, done, claimed = Quests.state(quest, w)
    if not done or claimed then return false end

    w.claimed[questId] = true
    if quest.reward.gold then Save.addGold(quest.reward.gold) end
    if quest.reward.gems then Save.addGems(quest.reward.gems) end
    Save.save()
    return true
end

-- Claim a completed daily quest
function Save.claimQuest(questId)
    local quest = Quests.get(questId)
    if not quest then return false end
    local q = Save.getDailyQuests()
    local progress, done, claimed = Quests.state(quest, q)
    if not done or claimed then return false end

    q.claimed[questId] = true
    q.points = math.min(Quests.MAX_POINTS, (q.points or 0) + quest.points)
    if quest.reward.gold then Save.addGold(quest.reward.gold) end
    if quest.reward.gems then Save.addGems(quest.reward.gems) end
    Save.save()
    return true
end

-- Claim a battle pass gauge tier
function Save.claimQuestTier(tierIndex)
    local tier = Quests.TIERS[tierIndex]
    if not tier then return false end
    local q = Save.getDailyQuests()
    if (q.points or 0) < tier.points or q.claimedTiers[tierIndex] then return false end

    q.claimedTiers[tierIndex] = true
    if tier.reward.gold then Save.addGold(tier.reward.gold) end
    if tier.reward.gems then Save.addGems(tier.reward.gems) end
    Save.save()
    return true
end

-- ============================================================================
-- BESTIARY & EVENT RECORDS
-- ============================================================================
function Save.recordKill(monsterType, count)
    if not monsterType then return end
    local d = Save.get()
    d.bestiary = d.bestiary or {}
    d.bestiary[monsterType] = (d.bestiary[monsterType] or 0) + (count or 1)
end

function Save.getBestiary()
    local d = Save.get()
    d.bestiary = d.bestiary or {}
    return d.bestiary
end

function Save.setEventRecord(mode, value)
    local d = Save.get()
    d.events = d.events or { bossRushBest = 0, survivalBest = 0 }
    local key = (mode == "survival") and "survivalBest" or "bossRushBest"
    if (value or 0) > (d.events[key] or 0) then
        d.events[key] = value
        Save.save()
        return true
    end
    return false
end

function Save.getEvents()
    local d = Save.get()
    d.events = d.events or { bossRushBest = 0, survivalBest = 0 }
    return d.events
end

function Save.setChapter(chapIndex)
    local d = Save.get()
    d.selectedChapter = math.max(1, math.min(6, chapIndex))
    Save.save()
    return d.selectedChapter
end

-- Achievements: claim completed achievement reward
function Save.claimAchievement(id)
    local Achievements = require("src.data.achievements")
    local a = Achievements.get(id)
    if not a then return false end
    local d = Save.get()
    d.achievements = d.achievements or {}
    local _, done, claimed = Achievements.state(a, d)
    if not done or claimed then return false end

    d.achievements[id] = true
    if a.reward.gold then Save.addGold(a.reward.gold) end
    if a.reward.gems then Save.addGems(a.reward.gems) end
    Save.save()
    return true
end

-- Daily shop: 3 daily offers seeded from the current date (consistent all day)
function Save.getShop()
    local d = Save.get()
    d.shop = d.shop or { day = "", bought = {} }
    local today = os.date("%Y-%j")
    if d.shop.day ~= today then
        d.shop.day = today
        d.shop.bought = {}
        Save.save()
    end
    return d.shop
end

function Save.markShopBought(index)
    local shop = Save.getShop()
    shop.bought[index] = true
    Save.save()
end

function Save.getItemStars(itemId)
    local d = Save.get()
    d.itemStars = d.itemStars or {}
    return d.itemStars[itemId] or 0
end

function Save.addItemStar(itemId)
    local d = Save.get()
    d.itemStars = d.itemStars or {}
    local cur = d.itemStars[itemId] or 0
    if cur >= Save.MAX_ITEM_STARS then return false end
    d.itemStars[itemId] = cur + 1
    Save.save()
    return true
end

-- Energy regen: +1 every 6 minutes, even when game is closed
local ENERGY_PERIOD = Balance.ENERGY.period

function Save.updateEnergyRegen()
    local d = Save.get()
    local now = os.time()
    d.energyStamp = d.energyStamp or now
    if d.energy >= d.maxEnergy then
        d.energyStamp = now
        return 0
    end
    local elapsed = now - d.energyStamp
    if elapsed < ENERGY_PERIOD then return 0 end
    local gained = math.floor(elapsed / ENERGY_PERIOD)
    local before = d.energy
    d.energy = math.min(d.maxEnergy, d.energy + gained)
    d.energyStamp = now - (elapsed % ENERGY_PERIOD)
    if d.energy ~= before then Save.save() end
    return d.energy - before
end

-- Spend energy to boost a run. Returns false if energy is insufficient
-- (run still launches, simply without the bonus).
function Save.spendEnergy(mode)
    local d = Save.get()
    Save.updateEnergyRegen()
    local cost = Balance.energyCost(mode)
    if (d.energy or 0) < cost then
        return false, cost
    end
    if d.energy >= d.maxEnergy then
        d.energyStamp = os.time()
    end
    d.energy = d.energy - cost
    Save.save()
    return true, cost
end

-- Time remaining (in seconds) until next energy point
function Save.energyCountdown()
    local d = Save.get()
    if d.energy >= d.maxEnergy then return 0 end
    local elapsed = os.time() - (d.energyStamp or os.time())
    return math.max(0, ENERGY_PERIOD - (elapsed % ENERGY_PERIOD))
end

function Save.getItemRarity(itemId)
    local d = Save.get()
    if d.itemRarities and d.itemRarities[itemId] then
        return d.itemRarities[itemId]
    end
    local Items = require("src.data.items")
    local item = Items.get(itemId)
    return item and item.rarity or "common"
end

-- Number of owned copies of an item
function Save.getItemCopies(itemId)
    local d = Save.get()
    d.itemCopies = d.itemCopies or {}
    return d.itemCopies[itemId] or 1
end

-- Is fusion possible? Requires 3 copies and an available tier upgrade:
-- higher rarity, or additional star (up to 5) once legendary
Save.MAX_ITEM_STARS = 5
function Save.canFuse(itemId)
    if Save.getItemCopies(itemId) < 3 then return false end
    return Save.getItemRarity(itemId) ~= "legendary" or Save.getItemStars(itemId) < Save.MAX_ITEM_STARS
end

-- Equipment fusion (3 -> 1 next tier)
function Save.fuseItem(itemId)
    local d = Save.get()
    d.itemCopies = d.itemCopies or {}
    d.itemRarities = d.itemRarities or {}

    local copies = Save.getItemCopies(itemId)
    if copies < 3 then
        return false, "NOT ENOUGH COPIES (3 NEEDED)"
    end

    local curRarity = Save.getItemRarity(itemId)
    local nextTiers = {
        common = "uncommon",
        uncommon = "rare",
        rare = "epic",
        epic = "legendary",
    }
    local nextRarity = nextTiers[curRarity]
    if not nextRarity then
        -- Maximum rarity: fusion adds a star (+6% stats)
        if Save.getItemStars(itemId) >= Save.MAX_ITEM_STARS then
            return false, "MAXIMUM STARS"
        end
        d.itemCopies[itemId] = copies - 2
        Save.addItemStar(itemId)
        Save.save()
        return true, curRarity, Save.getItemStars(itemId)
    end

    -- Consumes 2 copies to upgrade item to next rarity tier (3 -> 1)
    d.itemCopies[itemId] = copies - 2
    d.itemRarities[itemId] = nextRarity
    Save.save()
    return true, nextRarity
end

return Save

