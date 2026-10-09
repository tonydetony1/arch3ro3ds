-- src/states/menu.lua
-- Hub & Menu Principal style Archero 2 / Gummy UI pour Nintendo 3DS & PC
-- Vitrine Top Screen (400x240) Diorama 3D & Interface Tactile Gummy Bottom Screen (320x240)
-- 5 Onglets : JOUER (Carousel Mondes & Patrouille), HÉROS (5 Rôdeurs & Passifs), FORGE (Inventaire & Fusion 3->1), TALENTS, COFFRES

local Config = require("src.data.config")
local Save = require("src.data.save")
local Audio = require("src.audio.audio")
local Items = require("src.data.items")
local Heroes = require("src.data.heroes")
local UI = require("src.ui.ui_components")
local Art = require("src.render.art")
local Palette = require("src.render.palette")
local Skin = require("src.ui.skin")
local PixelFont = require("src.ui.pixel_font")
local HeroSprites = require("src.render.sprites.heroes")
local Quests = require("src.data.quests")
local Bestiary = require("src.data.bestiary")
local Achievements = require("src.data.achievements")
local Inventory = require("src.states.inventory")
local Balance = require("src.data.balance")
local Talents = require("src.data.talents")
local Pet = require("src.entities.pet")
local SettingsPanel = require("src.ui.settings_panel")
local WorldManager = require("src.core.world_manager")
local MenuTop = require("src.ui.menu_top")

local MenuState = {}
MenuState.__index = MenuState


-- Background of each world card in the Play tab (forest, desert, crystal, inferno, sky, void)
local WORLD_CARD_BG = {
    { 0.10, 0.22, 0.14 }, { 0.28, 0.18, 0.08 }, { 0.08, 0.16, 0.28 },
    { 0.28, 0.10, 0.08 }, { 0.10, 0.18, 0.30 }, { 0.20, 0.10, 0.28 },
}
-- Mode card order on the PLAY tab (drawing, touch, d-pad)
local PLAY_MODE_ORDER = { "ascension", "infinite", "boss_rush", "survival" }

-- Tab bar geometry (drawing and touch) and look
local TAB_X0, TAB_STEP, TAB_Y, TAB_W, TAB_H = 2, 45, 208, 44, 31
local TAB_THEMES = { play = "green", quests = "gold", heroes = "blue", equipment = "blue", talents = "purple",
    chests = "gold", settings = "gray" }
local TAB_ICONS = { play = "icon_sword", quests = "icon_check", equipment = "item_armor", settings = "icon_gear" }

function MenuState.new(stateMachine)
    local self = setmetatable({}, MenuState)
    self.sm = stateMachine
    self.saveData = nil

    -- Active tab: "play", "heroes", "equipment", "talents", "chests"
    self.currentTab = "play"
    self.selectedMode = "ascension"
    self.selectedHeroPreview = "atreus"
    self.heroSubPage = "roster"
    self.questSubPage = "quests"
    self.chestSubPage = "chests"
    self.selectedTalent = "strength"
    self.selectedChest = "gold" -- chest shown on the top screen (d-pad or touch)
    self.settingsPanel = SettingsPanel.new()
    self.bestiarySelected = "slime"

    -- Dedicated inventory manager with kinetic scrolling
    self.inventory = Inventory.new()

    -- World cards: the worlds a run goes through, 10 floors each (src/core/world_manager.lua)
    self.chapters = {}
    for i, chap in ipairs(WorldManager.CHAPTERS) do
        self.chapters[i] = { id = i, name = chap.name, boss = Bestiary.nameOf(chap.boss), bg = WORLD_CARD_BG[i] }
    end

    -- Séquence Gacha d'ouverture de coffre
    self.openingChest = nil -- "gold" ou "obsidian"
    self.chestTimer = 0
    self.rewardItem = nil
    self.rewardMessage = ""
    self.godRaysAngle = 0
    self.particles = {}

    -- 24 Particules d'ambiance célestes pré-allouées pour le Top Screen (Zéro allocation GC)
    self.bgParticles = {}
    for i = 1, 24 do
        table.insert(self.bgParticles, {
            x = math.random(4, Config.TOP_WIDTH - 4),
            y = math.random(0, Config.TOP_HEIGHT),
            speedY = math.random(14, 26),
            driftSpeed = math.random(2, 4),
            driftAmp = math.random(3, 8),
            phase = (i / 24) * math.pi * 2,
            size = math.random(2, 4),
            rot = math.random() * math.pi * 2,
            rotSpeed = (math.random() > 0.5 and 1 or -1) * (math.random(10, 25) / 10),
            baseAlpha = math.random(30, 65) / 100,
            isGold = (i % 3 == 0),
        })
    end

    -- Suivi de l'appui sur les boutons (Tactile)
    self.pressedBtn = nil
    self.lastUpgradedTalent = nil
    self.talentUpgradeTimer = 0
    self.talentFailTimer = 0
    self.patrolRewardText = nil
    self.patrolRewardTimer = 0

    -- Floating Bento touch navigation bar
    -- 7 onglets de 41 px (pas de 44 px) : le 7ᵉ ouvre les réglages (+ panneau admin caché)
    self.tabs = {
        { id = "play",      name = "PLAY",     icon = "swords", theme = "emerald" },
        { id = "quests",    name = "QUESTS",   icon = "check",  theme = "amber"   },
        { id = "heroes",    name = "HEROES",   icon = "hero",   theme = "sapphire"},
        { id = "equipment", name = "FORGE",    icon = "shield", theme = "sapphire"},
        { id = "talents",   name = "TALENTS",  icon = "rune",   theme = "violet"  },
        { id = "chests",    name = "CHESTS",   icon = "chest",  theme = "amber"   },
        { id = "settings",  name = "SETTINGS", icon = "gear",   theme = "gray"    },
    }
    for i, tab in ipairs(self.tabs) do
        tab.x, tab.y, tab.w, tab.h = TAB_X0 + (i - 1) * TAB_STEP, TAB_Y, TAB_W, TAB_H
    end


    return self
end

function MenuState:enter()
    Audio.playMusic("hub", 0.5)
    Save.updateEnergyRegen()
    self.saveData = Save.load()
    self.selectedHeroPreview = self.saveData.selectedHero or "atreus"
    self.inventory:refresh()
    self.openingChest = nil
    self.rewardItem = nil
    self.particles = {}
end

function MenuState:update(dt)
    self.godRaysAngle = (self.godRaysAngle + dt * 1.4) % (math.pi * 2)
    self.settingsPanel:update(dt)

    -- Accumulation de la patrouille AFK
    Save.updatePatrol(dt)

    if self.talentUpgradeTimer and self.talentUpgradeTimer > 0 then
        self.talentUpgradeTimer = math.max(0, self.talentUpgradeTimer - dt)
    end
    if self.talentFailTimer and self.talentFailTimer > 0 then
        self.talentFailTimer = math.max(0, self.talentFailTimer - dt)
    end

    if self.patrolRewardTimer and self.patrolRewardTimer > 0 then
        self.patrolRewardTimer = math.max(0, self.patrolRewardTimer - dt)
    end

    -- Mise à jour des 24 particules d'ambiance célestes du Top Screen (sans allocation)
    for _, p in ipairs(self.bgParticles) do
        p.y = p.y - p.speedY * dt
        p.rot = (p.rot + p.rotSpeed * dt) % (math.pi * 2)
        if p.y < -8 then
            p.y = Config.TOP_HEIGHT + math.random(2, 10)
            p.x = math.random(4, Config.TOP_WIDTH - 4)
        end
    end

    -- Mise à jour de l'onglet Inventaire (Kinetic Scroller)
    if self.currentTab == "equipment" then
        self.inventory:update(dt)
    end

    -- Mise à jour de la séquence cinématique Gacha
    if self.openingChest then
        self.chestTimer = self.chestTimer + dt

        if self.chestTimer >= 0.7 and #self.particles < 35 then
            local rData = self.rewardItem and Items.getRarityData(self.rewardItem.rarity) or Items.RARITIES.rare
            table.insert(self.particles, {
                x = Config.BOTTOM_WIDTH / 2,
                y = 105,
                vx = (math.random() * 2 - 1) * math.random(60, 180),
                vy = (math.random() * 2 - 1) * math.random(60, 180),
                size = math.random(2, 5),
                alpha = 1.0,
                color = rData.color,
            })
        end

        for i = #self.particles, 1, -1 do
            local p = self.particles[i]
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.alpha = math.max(0, p.alpha - dt * 1.5)
            if p.alpha <= 0 then
                table.remove(self.particles, i)
            end
        end
    end
end

-- Attaque et PV totaux (héros + équipement + talents). Le calcul parcourt tout l'équipement :
-- il n'est refait que si la sauvegarde ou le héros change, et au plus tard chaque seconde
local POWER_REFRESH = 1.0
function MenuState:powerTotals(heroId, hData, t)
    local seq = self.saveData.saveSeq
    local cache = self.powerCache
    if cache and cache.seq == seq and cache.hero == heroId and t < cache.expires then
        return cache.atk, cache.hp
    end
    local totalAtk = hData.baseAtkBonus or 0
    local totalHp = 100 + (hData.baseHpBonus or 0)
    for _, slot in ipairs(Save.EQUIP_SLOT_ORDER) do
        local itemId = self.saveData.equipped[slot]
        if itemId then
            local st = Save.getItemStats(itemId)
            totalAtk = totalAtk + st.atk
            totalHp = totalHp + st.hp
        end
    end
    -- Talents: Strength multiplies damage, Vitality adds HP (src/data/talents.lua)
    local talents = Save.getTalents()
    totalAtk = math.floor(totalAtk * (1 + Talents.damageBonus(talents)) + 0.5)
    totalHp = totalHp + Talents.hpBonus(talents)
    self.powerCache = { seq = seq, hero = heroId, expires = t + POWER_REFRESH, atk = totalAtk, hp = totalHp }
    return totalAtk, totalHp
end

-- ============================================================================
-- TOP SCREEN (400x240): world backdrop, island and page cards (src/ui/menu_top.lua)
-- ============================================================================
function MenuState:drawTop()
    MenuTop.draw(self, love.timer.getTime())
end

-- ============================================================================
-- BOTTOM SCREEN (320x240) : NAVIGATION BENTO DOCK & 5 ONGLETS MODERNES 2026
-- ============================================================================
function MenuState:drawBottom()
    local botW = Config.BOTTOM_WIDTH
    local botH = Config.BOTTOM_HEIGHT

    love.graphics.setColor(0.06, 0.07, 0.10, 1.0)
    love.graphics.rectangle("fill", 0, 0, botW, botH)

    -- 1. Contenu selon l'onglet actif (Zone utile : y=4 à y=200)
    if self.openingChest then
        self:drawGachaSequence()
    elseif self.currentTab == "settings" then
        self.settingsPanel:draw()
    elseif self.currentTab == "play" then
        self:drawPlayTab()
    elseif self.currentTab == "quests" then
        if self.questSubPage == "achievements" then
            self:drawAchievementsPage()
        elseif self.questSubPage == "weekly" then
            self:drawWeeklyPage()
        else
            self:drawQuestsTab()
        end
    elseif self.currentTab == "heroes" then
        if self.heroSubPage == "bestiary" then
            self:drawBestiaryPage()
        else
            self:drawHeroesTab()
        end
    elseif self.currentTab == "equipment" then
        self.inventory:draw()
    elseif self.currentTab == "talents" then
        self:drawTalentsTab()
    elseif self.currentTab == "chests" then
        if self.chestSubPage == "shop" then
            self:drawShopPage()
        else
            self:drawChestsTab()
        end
    end

    self:drawTabBar()
end

-- Tab bar: big icons only (the page name is on the top screen), the active tab is a raised
-- button in its colour. Primitives first, then the icons (batched sprites).
function MenuState:drawTabBar()
    Skin.rect(Palette.C.ink, 0, TAB_Y - 1, Config.BOTTOM_WIDTH, Config.BOTTOM_HEIGHT - TAB_Y + 1)
    for _, tab in ipairs(self.tabs) do
        if self.currentTab == tab.id then
            Skin.button(tab.x, tab.y - 1, tab.w, tab.h + 1, TAB_THEMES[tab.id] or "blue", self.pressedBtn == "tab_" .. tab.id)
        else
            Skin.roundRect(Palette.C.night, tab.x + 1, tab.y + 3, tab.w - 2, tab.h - 3, 3)
            Skin.rect(Palette.C.slate, tab.x + 3, tab.y + 3, tab.w - 6, 1)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    local heroId = self.saveData.selectedHero or "atreus"
    for _, tab in ipairs(self.tabs) do
        local active = (self.currentTab == tab.id)
        local cx, cy = tab.x + math.floor(tab.w / 2), tab.y + (active and 13 or 17)
        local icon = TAB_ICONS[tab.id]
        if tab.id == "heroes" then
            Art.drawEx("hero_body", 1, cx, cy + 8, 0, 1, 1, false, (heroId ~= "atreus") and heroId or nil)
        elseif tab.id == "chests" then
            Art.drawEx("menu_chest_gold", 1, cx - 8, cy - 7, 0, 0.5, 0.5)
        elseif tab.id == "talents" then
            Skin.disc(Palette.C.ink, cx, cy, 8)
            Skin.disc(Palette.C.plum, cx, cy, 7)
            Skin.disc(Palette.C.magenta, cx, cy - 1, 5)
            love.graphics.setColor(1, 1, 1, 1)
            Art.draw("icon_star", 1, cx, cy - 1)
        elseif icon then
            Art.drawEx(icon, 1, cx, cy, 0, (tab.id == "equipment") and 1 or 2, (tab.id == "equipment") and 1 or 2)
        end
    end
    -- Inactive tabs are dimmed after their icons are drawn
    for _, tab in ipairs(self.tabs) do
        if self.currentTab ~= tab.id then
            Skin.rect(Palette.C.night, tab.x + 1, tab.y + 3, tab.w - 2, tab.h - 3, 0.45)
        end
    end
end

-- ============================================================================
-- ONGLET 1 : JOUER (BENTO GRID 2026 : MONDE, PATROUILLE, MODES & LAUNCHER)
-- ============================================================================
-- Layout of the PLAY tab (drawing and touch)
local PLAY_PREV = { x = 4, y = 34, w = 22, h = 36 }
local PLAY_NEXT = { x = 294, y = 34, w = 22, h = 36 }
local PLAY_WORLD = { x = 30, y = 4, w = 260, h = 96 }
local PLAY_MODE_Y, PLAY_MODE_W, PLAY_MODE_H, PLAY_MODE_STEP = 104, 76, 40, 79
local PLAY_PATROL = { x = 4, y = 148, w = 100, h = 52 }
local PLAY_COLLECT = { x = 10, y = 170, w = 88, h = 26 }
local PLAY_BATTLE = { x = 108, y = 148, w = 208, h = 52 }
local PLAY_ABANDON = { x = 112, y = 151, w = 64, h = 16 }
local MODE_CHIPS = {
    ascension = { name = "ASCENSION", theme = "blue" },
    infinite = { name = "ABYSS", theme = "purple" },
    boss_rush = { name = "BOSS RUSH", theme = "red" },
    survival = { name = "ARENA", theme = "green" },
}
-- Special floors of a world (slot within its 10 floors), as on the in-run floor path
local FLOOR_NODES = { [5] = { bg = "navy", sprite = "npc_angel", dy = 8 }, [7] = { bg = "plum", sprite = "icon_affix_enraged", dy = 0 },
    [9] = { bg = "wine", sprite = "npc_devil", dy = 8 }, [10] = { bg = "wine", sprite = "icon_skull", dy = 0 } }

local function inRect(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

-- 10-floor path of a world: done floors green, best floor marked, special floors iconed
local function drawFloorPath(x0, y, w, reached, unlocked)
    local C = Palette.C
    local step = w / 9
    Skin.rect(C.slate, x0, y, w, 2)
    if reached > 1 then Skin.rect(C.leaf, x0, y, math.floor(step * (reached - 1)), 2) end
    for i = 1, 10 do
        local nx = math.floor(x0 + step * (i - 1))
        local node = FLOOR_NODES[i]
        local ring = (i == reached) and C.yellow or ((i < reached) and C.leaf or C.ink)
        if node then
            Skin.roundRect(ring, nx - 8, y - 7, 17, 17, 3)
            Skin.roundRect(C[node.bg], nx - 7, y - 6, 15, 15, 3)
        else
            Skin.roundRect(C.ink, nx - 5, y - 4, 11, 11, 3)
            Skin.roundRect(ring == C.ink and C.slate or ring, nx - 4, y - 3, 9, 9, 3)
        end
    end
    love.graphics.setColor(1, 1, 1, unlocked and 1 or 0.45)
    for i, node in pairs(FLOOR_NODES) do
        Art.draw(node.sprite, 1, math.floor(x0 + step * (i - 1)), y + 1 + node.dy)
    end
    love.graphics.setColor(1, 1, 1, 1)
    if unlocked and reached >= 1 then
        local bx = math.max(x0 - 6, math.min(x0 + w - 34, math.floor(x0 + step * (reached - 1)) - 20))
        Skin.pill(bx, y - 26, 40, 15, "gold")
        PixelFont.printf("BEST", bx, y - 24, 40, "center", C.white, "main")
    end
end

function MenuState:modeBest(mode)
    local records = self.saveData.records or {}
    local events = Save.getEvents()
    if mode == "ascension" then return records.ascensionMax or 1 end
    if mode == "infinite" then return records.infiniteMax or 0 end
    if mode == "boss_rush" then return events.bossRushBest or 0 end
    return events.survivalBest or 0
end

function MenuState:drawPlayTab()
    local C = Palette.C
    local chapIdx = self.saveData.selectedChapter or 1
    local chap = self.chapters[chapIdx] or self.chapters[1]
    local records = self.saveData.records or {}
    local best = math.max(records.ascensionMax or 1, records.infiniteMax or 0)
    local prog = WorldManager.worldProgress(chap.id, best)

    -- 1. World carousel: tall arrows on both sides, world card in the middle
    Skin.button(PLAY_PREV.x, PLAY_PREV.y, PLAY_PREV.w, PLAY_PREV.h, "blue", self.pressedBtn == "chap_prev")
    Skin.button(PLAY_NEXT.x, PLAY_NEXT.y, PLAY_NEXT.w, PLAY_NEXT.h, "blue", self.pressedBtn == "chap_next")
    local wc = PLAY_WORLD
    Skin.panel(wc.x, wc.y, wc.w, wc.h, "dark")
    Skin.pill(wc.x + 6, wc.y + 5, 64, 16, prog.unlocked and "green" or "gray")
    if prog.total then
        drawFloorPath(wc.x + 16, wc.y + 76, wc.w - 32, prog.reached, prog.unlocked)
    end
    love.graphics.setColor(1, 1, 1, 1)
    Art.draw("icon_arrow_l", 1, PLAY_PREV.x + 11, PLAY_PREV.y + 16)
    Art.draw("icon_arrow_r", 1, PLAY_NEXT.x + 11, PLAY_NEXT.y + 16)
    Art.draw("icon_skull", 1, wc.x + 12, wc.y + 31)
    PixelFont.printf("WORLD " .. chap.id, wc.x + 6, wc.y + 7, 64, "center", C.white, "main")
    PixelFont.printf(chap.name, wc.x + 76, wc.y + 7, wc.w - 80, "left", prog.unlocked and C.yellow or C.fog, "main", 1, nil, 1)
    PixelFont.printf(chap.boss:upper(), wc.x + 20, wc.y + 27, wc.w - 26, "left", C.silver, "main", 1, nil, 1)
    if not prog.unlocked then
        PixelFont.printf(string.format("LOCKED: FLOOR %d+", prog.first), wc.x, wc.y + 48, wc.w, "center", C.fog, "main")
    elseif not prog.total then
        PixelFont.printf(string.format("ENDLESS - BEST %d", best), wc.x, wc.y + 56, wc.w, "center", C.pink, "main")
    end

    -- 2. Game modes
    for i, mode in ipairs(PLAY_MODE_ORDER) do
        local x = 4 + (i - 1) * PLAY_MODE_STEP
        local chip = MODE_CHIPS[mode]
        if self.selectedMode == mode then
            Skin.button(x, PLAY_MODE_Y, PLAY_MODE_W, PLAY_MODE_H, chip.theme, false)
        else
            Skin.panel(x, PLAY_MODE_Y + 2, PLAY_MODE_W, PLAY_MODE_H - 2, "raised")
        end
    end
    for i, mode in ipairs(PLAY_MODE_ORDER) do
        local x = 4 + (i - 1) * PLAY_MODE_STEP
        local sel = (self.selectedMode == mode)
        local y = PLAY_MODE_Y + (sel and 6 or 8)
        PixelFont.printf(MODE_CHIPS[mode].name, x, y, PLAY_MODE_W, "center", sel and C.white or C.silver, "main")
        PixelFont.printf("BEST " .. self:modeBest(mode), x, y + 14, PLAY_MODE_W, "center", sel and C.white or C.fog, "main")
    end

    -- 3. Patrol (idle gold) and the battle button
    local patrolAmt = math.floor(self.saveData.patrolGold or 0)
    local pc = PLAY_PATROL
    Skin.panel(pc.x, pc.y, pc.w, pc.h, "dark")
    local cb = PLAY_COLLECT
    Skin.button(cb.x, cb.y, cb.w, cb.h, patrolAmt > 0 and "gold" or "gray", self.pressedBtn == "claim_patrol")
    local run = Save.getRun()
    local bt = PLAY_BATTLE
    local oy = Skin.button(bt.x, bt.y, bt.w, bt.h, "green", self.pressedBtn == "play")
    local cost = Balance.energyCost(self.selectedMode)
    local hasEnergy = (self.saveData.energy or 0) >= cost
    if run then
        Skin.pill(PLAY_ABANDON.x, PLAY_ABANDON.y, PLAY_ABANDON.w, PLAY_ABANDON.h, "red")
    else
        Skin.pill(bt.x + bt.w - 50, bt.y + 4, 44, 16, "dark")
    end

    love.graphics.setColor(1, 1, 1, 1)
    Art.draw("icon_coin", 1, pc.x + 22, pc.y + 11)
    PixelFont.print("+" .. patrolAmt, pc.x + 32, pc.y + 6, C.yellow, "main")
    PixelFont.printf("COLLECT", cb.x, cb.y + 7, cb.w, "center", C.white, "main")
    if self.patrolRewardTimer and self.patrolRewardTimer > 0 then
        PixelFont.printf(self.patrolRewardText or "+GOLD", 0, bt.y - 14, Config.BOTTOM_WIDTH, "center", C.yellow, "main")
    end
    local label = run and "RESUME" or "BATTLE"
    local labelW = PixelFont.getWidth(label, "main", 2) + 22
    local lx = math.floor(bt.x + (bt.w - labelW) / 2)
    Art.drawEx("icon_sword", 1, lx + 7, bt.y + oy + 21, 0, 2, 2)
    PixelFont.print(label, lx + 22, bt.y + oy + 11, C.white, "main", 2)
    local sub = run and string.format("ROOM %d IN PROGRESS", run.room or 1)
        or (hasEnergy and "+50% GOLD BONUS" or (MODE_CHIPS[self.selectedMode] or MODE_CHIPS.ascension).name)
    PixelFont.printf(sub, bt.x, bt.y + oy + 34, bt.w, "center", C.mint, "main")
    if run then
        PixelFont.printf("ABANDON", PLAY_ABANDON.x, PLAY_ABANDON.y + 2, PLAY_ABANDON.w, "center", C.white, "main")
    else
        Art.draw("icon_bolt", 1, bt.x + bt.w - 39, bt.y + 12)
        PixelFont.print(tostring(cost), bt.x + bt.w - 30, bt.y + 6, hasEnergy and C.cyan or C.fog, "main")
    end
end

-- ============================================================================
-- TAB: QUESTS (DAILY + BATTLE PASS, WEEKLY, ACHIEVEMENTS)
-- ============================================================================
-- Icon sprite of a quest kind / achievement icon name (atlas sprites, batched)
local QUEST_SPRITES = { kills = "icon_skull", rooms = "icon_door", chests = "icon_coin", upgrades = "icon_star",
    bosses = "icon_sword", gold = "icon_coin", skull = "icon_skull", swords = "icon_sword", door = "icon_door",
    star = "icon_star", gem = "icon_gem", heart = "icon_heart", chest = "icon_coin", hero = "icon_star" }

-- Sub-tab row: same place on every page that has one (quests, chests)
local QUEST_SUBTABS = {
    { id = "quests",       label = "DAILY" },
    { id = "weekly",       label = "WEEKLY" },
    { id = "achievements", label = "FEATS" },
}
local CHEST_SUBTABS = {
    { id = "chests", label = "CHESTS" },
    { id = "shop",   label = "SHOP" },
}
local SUBTAB_X, SUBTAB_Y, SUBTAB_H, SUBTAB_GAP = 4, 4, 26, 4
local SUBTAB_SPAN = { quests = 312, chests = 200 }
local CONTENT_Y = 34

local function subtabRect(index, count, span)
    local w = math.floor((span - (count - 1) * SUBTAB_GAP) / count)
    return SUBTAB_X + (index - 1) * (w + SUBTAB_GAP), SUBTAB_Y, w, SUBTAB_H
end

function MenuState:drawSubtabs(tabs, current, span)
    local C = Palette.C
    for i, tab in ipairs(tabs) do
        local x, y, w, h = subtabRect(i, #tabs, span)
        if tab.id == current then
            Skin.button(x, y - 1, w, h + 1, "gold", self.pressedBtn == ("subtab_" .. tab.id))
        else
            Skin.panel(x, y + 1, w, h - 1, "raised")
        end
    end
    for i, tab in ipairs(tabs) do
        local x, y, w = subtabRect(i, #tabs, span)
        local active = (tab.id == current)
        PixelFont.printf(tab.label, x, y + (active and 7 or 9), w, "center", active and C.white or C.fog, "main")
    end
end

-- Id of the subtab under the touch point (nil if none)
local function subtabAt(tabs, span, tx, ty)
    for i, tab in ipairs(tabs) do
        local x, y, w, h = subtabRect(i, #tabs, span)
        if tx >= x and tx <= x + w and ty >= y - 2 and ty <= y + h + 2 then return tab.id end
    end
    return nil
end

-- Quest rows: same template for daily and weekly missions and for achievements
local QUEST_ROW_H, QUEST_ROW_STEP = 31, 33
local QUEST_BTN = { x = 246, w = 66, h = 27 }
local DAILY_FIRST_Y, WEEKLY_FIRST_Y = 68, CONTENT_Y
local POINTS_BAR = { x = 62, y = CONTENT_Y + 9, w = 238, h = 12 }
local FEATS_PER_PAGE = 4
local FEAT_PREV = { x = 4, y = 170, w = 48, h = 30 }
local FEAT_NEXT = { x = 268, y = 170, w = 48, h = 30 }

-- Reward of a quest: first currency (gold, else gems) as icon + amount
local function rewardParts(reward)
    if reward.gold then return "icon_coin", "+" .. reward.gold, Palette.C.yellow end
    if reward.gems then return "icon_gem", "+" .. reward.gems, Palette.C.mint end
    return nil, "", Palette.C.white
end

-- One row: icon disc, name, progress bar and count, reward, CLAIM button or check mark
function MenuState:drawQuestRow(y, iconName, name, progress, goal, reward, done, claimed, btnId)
    local C = Palette.C
    Skin.panel(4, y, 312, QUEST_ROW_H, (done and not claimed) and "raised" or "dark")
    Skin.disc(C.ink, 19, y + 15, 12)
    Skin.disc(claimed and C.slate or C.night, 19, y + 15, 11)
    local ratio = math.max(0, math.min(1, progress / math.max(1, goal)))
    Skin.roundRect(C.ink, 36, y + 17, 96, 11, 2)
    Skin.rect(C.night, 37, y + 18, 94, 9)
    if ratio > 0 then Skin.rect(done and C.leaf or C.blue, 37, y + 18, math.floor(94 * ratio), 9) end
    if done and not claimed then
        Skin.button(QUEST_BTN.x, y + 2, QUEST_BTN.w, QUEST_BTN.h, "gold", self.pressedBtn == btnId)
    end
    love.graphics.setColor(1, 1, 1, 1)
    Art.draw(QUEST_SPRITES[iconName] or "icon_star", 1, 19, y + 15)
    PixelFont.printf(name, 36, y + 3, 200, "left", claimed and C.fog or C.white, "main", 1, nil, 1)
    PixelFont.print(string.format("%d/%d", math.min(progress, goal), goal), 136, y + 17, C.silver, "main")
    local icon, amount, color = rewardParts(reward)
    if icon then
        Art.draw(icon, 1, 198, y + 22)
        PixelFont.print(amount, 206, y + 17, color, "main")
    end
    if claimed then
        Art.drawEx("icon_check", 1, QUEST_BTN.x + 33, y + 15, 0, 2, 2)
    elseif done then
        PixelFont.printf("CLAIM", QUEST_BTN.x, y + 9, QUEST_BTN.w, "center", C.white, "main")
    end
end

function MenuState:drawMissionRow(quest, saveQuests, y, btnPrefix)
    local progress, done, claimed = Quests.state(quest, saveQuests)
    self:drawQuestRow(y, quest.kind, quest.name, progress, quest.goal, quest.reward, done, claimed, btnPrefix .. quest.id)
end

-- Mission whose CLAIM button is under the touch point
local function questRowAt(list, firstY, tx, ty)
    if tx < QUEST_BTN.x or tx > QUEST_BTN.x + QUEST_BTN.w then return nil end
    for i, quest in ipairs(list) do
        local qy = firstY + (i - 1) * QUEST_ROW_STEP
        if ty >= qy and ty <= qy + QUEST_ROW_H then return quest end
    end
    return nil
end

-- x of a battle pass tier chest on the points bar
local function tierX(tier)
    local b = POINTS_BAR
    return math.min(b.x + b.w - 6, b.x + math.floor(b.w * (tier.points / Quests.MAX_POINTS)) - 6)
end

function MenuState:drawQuestsTab()
    local C = Palette.C
    local q = Save.getDailyQuests()
    self:drawSubtabs(QUEST_SUBTABS, "quests", SUBTAB_SPAN.quests)

    -- Battle pass: points bar with its tier chests
    local b = POINTS_BAR
    Skin.panel(4, CONTENT_Y, 312, 30, "dark")
    Skin.roundRect(C.ink, b.x, b.y, b.w, b.h, 2)
    Skin.rect(C.night, b.x + 1, b.y + 1, b.w - 2, b.h - 2)
    local fw = math.floor((b.w - 2) * math.min(1, (q.points or 0) / Quests.MAX_POINTS))
    if fw > 0 then
        Skin.rect(C.amber, b.x + 1, b.y + 1, fw, b.h - 2)
        Skin.rect(C.yellow, b.x + 1, b.y + 1, fw, 1)
    end
    for i, tier in ipairs(Quests.TIERS) do
        if (q.points or 0) >= tier.points and not q.claimedTiers[i] then
            Skin.disc(C.yellow, tierX(tier), b.y + 6, 11, 0.45)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    PixelFont.print(string.format("%d/%d", q.points or 0, Quests.MAX_POINTS), 9, b.y + 2, C.white, "main")
    for i, tier in ipairs(Quests.TIERS) do
        local x = tierX(tier)
        Art.drawEx("menu_chest_gold", 1, x - 8, b.y - 1, 0, 0.5, 0.5)
        if q.claimedTiers[i] then Art.draw("icon_check", 1, x + 6, b.y + 10) end
    end

    for i, quest in ipairs(Save.getDailyQuestList()) do
        self:drawMissionRow(quest, q, DAILY_FIRST_Y + (i - 1) * QUEST_ROW_STEP, "quest_")
    end
end

-- ============================================================================
-- PAGE: WEEKLY MISSIONS
-- ============================================================================
function MenuState:drawWeeklyPage()
    local weeklyList, w = Save.getWeeklyQuestList()
    self:drawSubtabs(QUEST_SUBTABS, "weekly", SUBTAB_SPAN.quests)
    for i, quest in ipairs(weeklyList) do
        self:drawMissionRow(quest, w, WEEKLY_FIRST_Y + (i - 1) * QUEST_ROW_STEP, "weekly_")
    end
    PixelFont.printf("NEW MISSIONS EVERY MONDAY", 0, WEEKLY_FIRST_Y + 3 * QUEST_ROW_STEP + 12, Config.BOTTOM_WIDTH,
        "center", Palette.C.fog, "main")
end

-- ============================================================================
-- PAGE: PERMANENT ACHIEVEMENTS (pages of 4, d-pad up/down or the arrows)
-- ============================================================================
function MenuState:featPageCount()
    return math.max(1, math.ceil(#Achievements.LIST / FEATS_PER_PAGE))
end

function MenuState:drawAchievementsPage()
    local C = Palette.C
    local d = Save.get()
    self:drawSubtabs(QUEST_SUBTABS, "achievements", SUBTAB_SPAN.quests)
    local page = self.featPage or 1
    local first = (page - 1) * FEATS_PER_PAGE
    for i = 1, FEATS_PER_PAGE do
        local a = Achievements.LIST[first + i]
        if a then
            local value, done, claimed = Achievements.state(a, d)
            self:drawQuestRow(CONTENT_Y + (i - 1) * QUEST_ROW_STEP, a.icon, a.name, value, a.goal, a.reward, done, claimed, "ach_" .. a.id)
        end
    end
    local pages = self:featPageCount()
    Skin.button(FEAT_PREV.x, FEAT_PREV.y, FEAT_PREV.w, FEAT_PREV.h, page > 1 and "blue" or "gray", self.pressedBtn == "feat_prev")
    Skin.button(FEAT_NEXT.x, FEAT_NEXT.y, FEAT_NEXT.w, FEAT_NEXT.h, page < pages and "blue" or "gray", self.pressedBtn == "feat_next")
    love.graphics.setColor(1, 1, 1, 1)
    Art.drawEx("icon_arrow_l", 1, FEAT_PREV.x + 24, FEAT_PREV.y + 13, 0, 2, 2)
    Art.drawEx("icon_arrow_r", 1, FEAT_NEXT.x + 24, FEAT_NEXT.y + 13, 0, 2, 2)
    PixelFont.printf(string.format("PAGE %d/%d", page, pages), 0, FEAT_PREV.y + 9, Config.BOTTOM_WIDTH, "center", C.silver, "main")
end

-- Achievement whose CLAIM button is under the touch point (current page only)
function MenuState:featAt(tx, ty)
    if tx < QUEST_BTN.x or tx > QUEST_BTN.x + QUEST_BTN.w then return nil end
    local first = ((self.featPage or 1) - 1) * FEATS_PER_PAGE
    for i = 1, FEATS_PER_PAGE do
        local a = Achievements.LIST[first + i]
        local qy = CONTENT_Y + (i - 1) * QUEST_ROW_STEP
        if a and ty >= qy and ty <= qy + QUEST_ROW_H then return a end
    end
    return nil
end

function MenuState:turnFeatPage(step)
    local pages = self:featPageCount()
    local nextPage = math.max(1, math.min(pages, (self.featPage or 1) + step))
    if nextPage == (self.featPage or 1) then return false end
    self.featPage = nextPage
    return true
end

-- ============================================================================
-- PAGE : BOUTIQUE DU JOUR
-- ============================================================================
local SHOP_ITEM_POOL = { "rapid_daggers", "heavy_ballista", "phantom_cloak", "golden_chestplate",
                         "serpent_ring", "falcon_ring", "dragon_pet", "saw_blade" }

function MenuState:getShopOffers()
    local day = tonumber(os.date("%j")) or 1
    local seed = day * 7919
    local function rnd(n)
        seed = (seed * 1103515245 + 12345) % 2147483648
        return (seed % n) + 1
    end
    local itemId = SHOP_ITEM_POOL[rnd(#SHOP_ITEM_POOL)]
    return {
        { kind = "item", id = itemId, price = 400 + rnd(6) * 50, currency = "gold",
          label = (Items.get(itemId) and Items.get(itemId).name or itemId), icon = "chest" },
        { kind = "gold", amount = 1500, price = 25, currency = "gems", label = "1,500 GOLD", icon = "gold" },
        { kind = "energy", amount = 10, price = 12, currency = "gems", label = "+10 ENERGY", icon = "energy" },
    }
end

local SHOP_CARD_Y, SHOP_CARD_W, SHOP_CARD_H, SHOP_CARD_STEP = 34, 101, 166, 105
local SHOP_BTN_Y, SHOP_BTN_H = 156, 40
local SHOP_ICONS = { gold = "icon_coin", energy = "icon_bolt", gem = "icon_gem" }

function MenuState:drawShopPage()
    local C = Palette.C
    local shop = Save.getShop()
    local offers = self:getShopOffers()
    self:drawSubtabs(CHEST_SUBTABS, "shop", SUBTAB_SPAN.chests)
    self:drawWallet()

    for i, offer in ipairs(offers) do
        local x = 4 + (i - 1) * SHOP_CARD_STEP
        local bought = shop.bought[i]
        Skin.panel(x, SHOP_CARD_Y, SHOP_CARD_W, SHOP_CARD_H, bought and "dark" or "raised")
        if bought then
            Skin.panel(x + 6, SHOP_BTN_Y, SHOP_CARD_W - 12, SHOP_BTN_H, "dark")
        else
            local canBuy = (offer.currency == "gems") and (self.saveData.gems >= offer.price)
                or (offer.currency ~= "gems" and self.saveData.gold >= offer.price)
            Skin.button(x + 6, SHOP_BTN_Y, SHOP_CARD_W - 12, SHOP_BTN_H,
                canBuy and ((offer.currency == "gems") and "purple" or "gold") or "gray", self.pressedBtn == ("shop_" .. i))
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    for i, offer in ipairs(offers) do
        local x = 4 + (i - 1) * SHOP_CARD_STEP
        local cx = x + math.floor(SHOP_CARD_W / 2)
        if offer.kind == "item" then
            UI.drawItemIcon(Items.get(offer.id) and Items.get(offer.id).icon or "bow", cx, SHOP_CARD_Y + 40, 18)
        else
            Art.drawEx(SHOP_ICONS[offer.icon] or "icon_star", 1, cx, SHOP_CARD_Y + 40, 0, 3, 3)
        end
        PixelFont.printf(offer.label:upper(), x + 4, SHOP_CARD_Y + 74, SHOP_CARD_W - 8, "center", C.white, "main", 1, nil, 2, 12)
        if offer.kind ~= "item" then
            PixelFont.printf("x" .. (offer.amount or 1), x, SHOP_CARD_Y + 102, SHOP_CARD_W, "center", C.silver, "main")
        end
        if shop.bought[i] then
            PixelFont.printf("SOLD", x, SHOP_BTN_Y + 14, SHOP_CARD_W, "center", C.fog, "main")
        else
            Art.draw(offer.currency == "gems" and "icon_gem" or "icon_coin", 1, x + 22, SHOP_BTN_Y + 19)
            PixelFont.print(tostring(offer.price), x + 32, SHOP_BTN_Y + 13, C.white, "main")
        end
    end
end

-- Gold and gems at the right of the sub-tab row (chests and shop pages)
function MenuState:drawWallet()
    love.graphics.setColor(1, 1, 1, 1)
    Art.draw("icon_coin", 1, 214, 17)
    PixelFont.print(tostring(self.saveData.gold or 0), 222, 11, Palette.C.yellow, "main")
    Art.draw("icon_gem", 1, 274, 17)
    PixelFont.print(tostring(self.saveData.gems or 0), 282, 11, Palette.C.mint, "main")
end

-- ============================================================================
-- PAGE : BESTIARY (fiches, éliminations et maîtrise)
-- ============================================================================
-- Layout of the BESTIARY page: 8 x 3 grid, the selected monster is detailed on the top
-- screen and in the strip under the grid
local BEST_BACK = { x = 4, y = 4, w = 70, h = 26 }
local BEST_COLS, BEST_CELL_W, BEST_CELL_H, BEST_STEP_X, BEST_STEP_Y = 8, 36, 40, 39, 42
local BEST_X0, BEST_Y0 = 5, 34
local BEST_INFO = { x = 4, y = 162, w = 312, h = 38 }

local function bestiaryCell(i)
    return BEST_X0 + ((i - 1) % BEST_COLS) * BEST_STEP_X, BEST_Y0 + math.floor((i - 1) / BEST_COLS) * BEST_STEP_Y
end

function MenuState:drawBestiaryPage()
    local C = Palette.C
    local counters = Save.getBestiary()
    local t = love.timer.getTime()

    Skin.button(BEST_BACK.x, BEST_BACK.y - 1, BEST_BACK.w, BEST_BACK.h + 1, "gray", self.pressedBtn == "bestiary_back")
    for i, entry in ipairs(Bestiary.ENTRIES) do
        local x, y = bestiaryCell(i)
        local isSel = (self.bestiarySelected == entry.type)
        Skin.roundRect(isSel and C.yellow or ((entry.family == "Boss") and C.wine or C.ink), x, y, BEST_CELL_W, BEST_CELL_H, 3)
        Skin.roundRect(C.night, x + 1, y + 1, BEST_CELL_W - 2, BEST_CELL_H - 2, 2)
        local kills = counters[entry.type] or 0
        for tier = 1, 3 do
            Skin.rect(kills >= Bestiary.THRESHOLDS[tier].kills and C.yellow or C.slate, x + 7 + (tier - 1) * 8, y + 3, 6, 3)
        end
    end
    Skin.panel(BEST_INFO.x, BEST_INFO.y, BEST_INFO.w, BEST_INFO.h, "dark")

    love.graphics.setColor(1, 1, 1, 1)
    PixelFont.printf("BACK", BEST_BACK.x, BEST_BACK.y + 7, BEST_BACK.w, "center", C.white, "main")
    PixelFont.print("BESTIARY", 84, 11, C.yellow, "main")
    PixelFont.printf("MASTERY 50/200/500", 150, 11, 162, "right", C.fog, "main")
    for i, entry in ipairs(Bestiary.ENTRIES) do
        local x, y = bestiaryCell(i)
        local kills = counters[entry.type] or 0
        local frame = Art.frame(entry.type, 1)
        if frame then
            local scale = (frame.h > 24 or frame.w > 30) and 0.5 or 1
            love.graphics.setColor(1, 1, 1, kills > 0 and 1 or 0.3)
            Art.drawEx(entry.type, (math.floor(t * 3) % 2) + 1, x + BEST_CELL_W / 2, y + 28, 0, scale, scale)
        end
        love.graphics.setColor(1, 1, 1, 1)
        PixelFont.printf(tostring(kills), x, y + 28, BEST_CELL_W, "center", kills > 0 and C.white or C.steel, "main")
    end
    local entry = Bestiary.entry(self.bestiarySelected) or Bestiary.ENTRIES[1]
    local kills = counters[entry.type] or 0
    local seen = kills > 0
    PixelFont.printf(seen and entry.name:upper() or "???", BEST_INFO.x + 8, BEST_INFO.y + 5, 150, "left", C.yellow, "main", 1, nil, 1)
    PixelFont.printf(string.format("+%d%% DAMAGE", math.floor(Bestiary.bonusFor(kills) * 100 + 0.5)), BEST_INFO.x,
        BEST_INFO.y + 5, BEST_INFO.w - 8, "right", C.mint, "main")
    PixelFont.printf(seen and ("WEAK TO " .. entry.weakness:upper()) or "DEFEAT IT TO LEARN MORE", BEST_INFO.x + 8,
        BEST_INFO.y + 21, BEST_INFO.w - 16, "left", C.silver, "main", 1, nil, 1)
end

-- Layout of the HEROES tab (drawing and touch)
local HERO_CARD_Y, HERO_CARD_W, HERO_CARD_H, HERO_CARD_STEP = 4, 60, 100, 63
local HERO_PASSIVE = { x = 4, y = 108, w = 206, h = 92 }
local HERO_BESTIARY = { x = 214, y = 108, w = 102, h = 40 }
local HERO_ACTION = { x = 214, y = 152, w = 102, h = 48 }

local function heroCardX(i) return 4 + (i - 1) * HERO_CARD_STEP end

function MenuState:drawHeroesTab()
    local C = Palette.C
    local hList = Heroes.getAll()
    local curPreview = self.selectedHeroPreview or self.saveData.selectedHero or "atreus"
    local hData = Heroes.get(curPreview)
    local isSelected = (self.saveData.selectedHero == curPreview)
    local isUnlocked = self.saveData.unlockedHeroes and self.saveData.unlockedHeroes[curPreview]
    local unlocked = self.saveData.unlockedHeroes or {}

    -- 1. Roster cards (primitives)
    for i, h in ipairs(hList) do
        local x = heroCardX(i)
        local isCur = (h.id == curPreview)
        Skin.roundRect(isCur and C.yellow or C.ink, x, HERO_CARD_Y, HERO_CARD_W, HERO_CARD_H, 3)
        Skin.roundRect(C.night, x + 1, HERO_CARD_Y + 1, HERO_CARD_W - 2, HERO_CARD_H - 2, 2)
        love.graphics.setColor(h.color[1], h.color[2], h.color[3], 1)
        love.graphics.rectangle("fill", x + 2, HERO_CARD_Y + 2, HERO_CARD_W - 4, 3)
        Skin.rect(C.slate, x + 6, HERO_CARD_Y + 60, HERO_CARD_W - 12, 2)
    end
    -- 2. Passive panel and right column
    local p = HERO_PASSIVE
    Skin.panel(p.x, p.y, p.w, p.h, "dark")
    Skin.rect(C.slate, p.x + 6, p.y + 36, p.w - 12, 1)
    local bb = HERO_BESTIARY
    Skin.button(bb.x, bb.y, bb.w, bb.h, "purple", self.pressedBtn == "open_bestiary")
    local ab = HERO_ACTION
    local canAfford = (hData.costType == "gold" and self.saveData.gold >= hData.cost)
        or (hData.costType == "gems" and self.saveData.gems >= hData.cost)
    if isSelected then
        Skin.panel(ab.x, ab.y, ab.w, ab.h, "raised")
    elseif isUnlocked then
        Skin.button(ab.x, ab.y, ab.w, ab.h, "green", self.pressedBtn == "select_hero")
    else
        Skin.button(ab.x, ab.y, ab.w, ab.h, canAfford and "gold" or "gray", self.pressedBtn == "unlock_hero")
    end

    -- 3. Sprites and texts
    love.graphics.setColor(1, 1, 1, 1)
    for i, h in ipairs(hList) do
        local x = heroCardX(i)
        local isUnl = unlocked[h.id]
        local cx = x + math.floor(HERO_CARD_W / 2)
        love.graphics.setColor(1, 1, 1, isUnl and 1 or 0.45)
        local variant = (h.id ~= "atreus") and h.id or nil
        Art.drawEx("hero_body", 1, cx, HERO_CARD_Y + 58, 0, 3, 3, false, variant)
        local acc = HeroSprites.ACCESSORY_BY_HERO[h.id]
        if acc and isUnl then
            local o = HeroSprites.ACCESSORY_OFFSETS[acc]
            Art.drawEx("hero_acc_" .. acc, 1, cx + o[1] * 3, HERO_CARD_Y + 58 + o[2] * 3, 0, 3, 3)
        end
        love.graphics.setColor(1, 1, 1, 1)
        if not isUnl then Art.drawEx("icon_lock", 1, cx, HERO_CARD_Y + 34, 0, 2, 2) end
        local isCur, isAct = (h.id == curPreview), (self.saveData.selectedHero == h.id)
        PixelFont.printf(h.name:upper(), x, HERO_CARD_Y + 66, HERO_CARD_W, "center",
            isCur and C.yellow or (isUnl and C.silver or C.fog), "main", 1, nil, 1)
        if isAct then
            Art.drawEx("icon_check", 1, cx, HERO_CARD_Y + 87, 0, 2, 2)
        elseif not isUnl then
            Art.draw(h.costType == "gems" and "icon_gem" or "icon_coin", 1, x + 12, HERO_CARD_Y + 87)
            PixelFont.print(tostring(h.cost), x + 20, HERO_CARD_Y + 82, h.costType == "gems" and C.mint or C.yellow, "main")
        end
    end
    PixelFont.print("PASSIVE", p.x + 8, p.y + 5, C.fog, "main")
    Art.draw("icon_star", 1, p.x + 12, p.y + 25)
    PixelFont.printf(hData.passiveName, p.x + 22, p.y + 19, p.w - 28, "left", C.yellow, "main", 1, nil, 1)
    PixelFont.printf(hData.passiveDesc, p.x + 8, p.y + 42, p.w - 16, "left", C.white, "main", 1, nil, 4, 12)
    PixelFont.printf("BESTIARY", bb.x, bb.y + 14, bb.w, "center", C.white, "main")
    if isSelected then
        Art.drawEx("icon_check", 1, ab.x + 18, ab.y + 24, 0, 2, 2)
        PixelFont.print("ACTIVE", ab.x + 32, ab.y + 18, C.mint, "main")
    elseif isUnlocked then
        PixelFont.printf("SELECT", ab.x, ab.y + 18, ab.w, "center", C.white, "main")
    else
        PixelFont.printf("UNLOCK", ab.x, ab.y + 10, ab.w, "center", C.white, "main")
        PixelFont.printf(hData.cost .. " " .. hData.costType:upper(), ab.x, ab.y + 25, ab.w, "center", C.white, "main")
    end
end

-- ============================================================================
-- TAB 4: PERMANENT TALENTS (SACRED SEAL)
-- The player picks a talent (card or GLORY badge), then buys it with the bottom button.
-- ============================================================================
local TALENT_CARD_W, TALENT_CARD_H = 154, 60
local TALENT_CARD_POS = { { 4, 34 }, { 162, 34 }, { 4, 98 }, { 162, 98 } } -- Talents.LIST order
local GLORY_BADGE = { x = 212, y = 7, w = 100, h = 20 }
local TALENT_BTN = { x = 4, y = 164, w = 312, h = 36 }
local TALENT_THEMES = { strength = "red", vitality = "green", agility = "blue", recovery = "gold" }
local TALENT_SPRITES = { strength = "icon_sword", vitality = "icon_heart", agility = "icon_skill_boots", recovery = "icon_skill_heal" }
local TALENT_FEEDBACK_TIME = 1.5

local function talentCardRect(index)
    local pos = TALENT_CARD_POS[index]
    return pos[1], pos[2], TALENT_CARD_W, TALENT_CARD_H
end

-- Talent under the touch point ("glory" for the badge), nil otherwise
local function talentAt(tx, ty)
    for i, t in ipairs(Talents.LIST) do
        local x, y, w, h = talentCardRect(i)
        if tx >= x and tx <= x + w and ty >= y and ty <= y + h then return t.id end
    end
    local g = GLORY_BADGE
    if tx >= g.x and tx <= g.x + g.w and ty >= g.y - 2 and ty <= g.y + g.h + 2 then return "glory" end
    return nil
end

function MenuState:drawTalentsTab()
    local C = Palette.C
    local talents = Save.getTalents()
    local cost, totalLevel = Save.getTalentCost()
    local selected = self.selectedTalent
    local canUpgrade = Talents.canUpgrade(selected, talents) and (self.saveData.gold >= cost)

    -- 1. Header: total level and the one-time GLORY talent
    Skin.panel(4, 4, 312, 26, "dark")
    local g = GLORY_BADGE
    local gloryOwned = Talents.isMaxed("glory", talents)
    Skin.pill(g.x, g.y, g.w, g.h, gloryOwned and "green" or (selected == "glory" and "gold" or "red"))
    Skin.disc(C.ink, 18, 17, 11)
    Skin.disc(C.plum, 18, 17, 10)
    Skin.disc(C.magenta, 18, 16, 8)

    -- 2. Talent cards: icon disc, name, per-level effect, level pips, total
    for i, talent in ipairs(Talents.LIST) do
        local x, y, w, h = talentCardRect(i)
        local isSel = (selected == talent.id)
        if isSel then Skin.roundRect(C.yellow, x - 1, y - 1, w + 2, h + 2, 4) end
        Skin.panel(x, y, w, h, isSel and "raised" or "dark")
        local th = Skin.theme(TALENT_THEMES[talent.id] or "gray")
        Skin.disc(C.ink, x + 17, y + 17, 13)
        Skin.disc(th.dark, x + 17, y + 17, 12)
        Skin.disc(th.main, x + 17, y + 16, 10)
        local lvl = talents[talent.id] or 0
        local filled = (lvl == 0) and 0 or ((lvl - 1) % 10 + 1)
        for pip = 1, 10 do
            local px = x + 6 + (pip - 1) * 14
            Skin.roundRect(C.ink, px, y + 33, 13, 8, 2)
            Skin.rect(pip <= filled and th.main or C.night, px + 1, y + 34, 11, 6)
        end
    end

    -- 3. Upgrade button with the price
    local b = TALENT_BTN
    local oy = Skin.button(b.x, b.y, b.w, b.h, canUpgrade and "purple" or "gray", self.pressedBtn == "upgrade_talent")
    local selTalent = Talents.get(selected)
    local maxed = selTalent and Talents.isMaxed(selected, talents)
    if selTalent and not maxed then Skin.pill(b.x + b.w - 90, b.y + oy + 7, 82, 20, "gold") end

    love.graphics.setColor(1, 1, 1, 1)
    Art.draw("icon_star", 1, 18, 16)
    PixelFont.print("TOTAL LEVEL " .. totalLevel, 34, 10, C.yellow, "main")
    Art.draw(gloryOwned and "icon_check" or (selected == "glory" and "icon_star" or "icon_lock"), 1, g.x + 13, g.y + 10)
    PixelFont.print("GLORY", g.x + 24, g.y + 4, C.white, "main")
    for i, talent in ipairs(Talents.LIST) do
        local x, y = talentCardRect(i)
        Art.draw(TALENT_SPRITES[talent.id] or "icon_star", 1, x + 17, y + 16)
        PixelFont.print(talent.name, x + 34, y + 5, C.white, "main")
        PixelFont.print(talent.effect, x + 34, y + 18, C.fog, "main")
        local lvl = talents[talent.id] or 0
        PixelFont.print(Talents.isMaxed(talent.id, talents) and "MAX" or ("LV " .. lvl), x + 6, y + 45, C.silver, "main")
        PixelFont.printf(Talents.totalText(talent, lvl), x, y + 45, TALENT_CARD_W - 8, "right", C.mint, "main")
    end

    -- Button text: feedback of the last purchase first, then the selected talent
    local text, color = "SELECT A TALENT", C.white
    if self.talentUpgradeTimer and self.talentUpgradeTimer > 0 and self.lastUpgradedTalent then
        local done = Talents.get(self.lastUpgradedTalent)
        text, color = "+1 " .. (done and done.name or self.lastUpgradedTalent:upper()), C.mint
    elseif self.talentFailTimer and self.talentFailTimer > 0 then
        text, color = "NOT ENOUGH GOLD", C.pink
    elseif maxed then
        text = selTalent.name .. " MAXED"
    elseif selTalent then
        text = "UPGRADE " .. selTalent.name
    end
    PixelFont.print(text, b.x + 10, b.y + oy + 11, color, "main")
    if selTalent and not maxed then
        Art.draw("icon_coin", 1, b.x + b.w - 76, b.y + oy + 17)
        PixelFont.print(tostring(cost), b.x + b.w - 66, b.y + oy + 11, C.white, "main")
    end
end

-- Buys one level of the selected talent (touch button, A, Return)
function MenuState:upgradeSelectedTalent()
    local success, chosen = Save.upgradeTalent(self.selectedTalent)
    if success then
        self.saveData = Save.get()
        self.lastUpgradedTalent = chosen
        self.talentUpgradeTimer = TALENT_FEEDBACK_TIME
        self.talentFailTimer = 0
        -- Glory is bought once: selection goes back to Strength
        if Talents.isMaxed(chosen, Save.getTalents()) then self.selectedTalent = "strength" end
        Audio.play("upgrade", 0.05, 0.8)
    else
        self.talentUpgradeTimer = 0
        self.talentFailTimer = TALENT_FEEDBACK_TIME
        Audio.play("ui_cancel", 0, 0.7)
    end
    return success
end

-- Selects a talent (ignored when Glory is already owned)
function MenuState:selectTalent(id)
    if Talents.canUpgrade(id, Save.getTalents()) then
        self.selectedTalent = id
        self.talentFailTimer = 0
        return true
    end
    return false
end

-- D-pad: 2 x 2 grid, Glory above the top row
local TALENT_NAV = {
    glory    = { dpdown = "strength", dpleft = "strength", dpright = "vitality" },
    strength = { dpright = "vitality", dpdown = "agility", dpup = "glory" },
    vitality = { dpleft = "strength", dpdown = "recovery", dpup = "glory" },
    agility  = { dpright = "recovery", dpup = "strength" },
    recovery = { dpleft = "agility", dpup = "vitality" },
}

function MenuState:moveTalentSelection(button)
    local nextId = (TALENT_NAV[self.selectedTalent] or TALENT_NAV.strength)[button]
    if nextId and self:selectTalent(nextId) then
        Audio.play("ui_click", 0.05, 0.6)
    end
    return nextId ~= nil
end

-- ============================================================================
-- ONGLET 5 : COFFRES (BENTO GRID 2026 : MONOLITHES DORÉ & OBSIDIENNE)
-- ============================================================================
-- Both chest monoliths share one layout (drawing and touch area)
local CHEST_CARD_Y, CHEST_CARD_H, CHEST_CARD_W = 34, 166, 154
local CHEST_CARDS = {
    { id = "gold", x = 4, btn = "open_gold", name = "GOLDEN", theme = "gold", currency = "icon_coin", sprite = "menu_chest_gold" },
    { id = "obsidian", x = 162, btn = "open_obsidian", name = "OBSIDIAN", theme = "purple", currency = "icon_gem",
      sprite = "menu_chest_obsidian" },
}

function MenuState:drawChestsTab()
    local C = Palette.C
    self:drawSubtabs(CHEST_SUBTABS, "chests", SUBTAB_SPAN.chests)
    self:drawWallet()
    local y, w, h = CHEST_CARD_Y, CHEST_CARD_W, CHEST_CARD_H
    local t = love.timer.getTime()

    for _, card in ipairs(CHEST_CARDS) do
        local isGold = (card.id == "gold")
        local price = isGold and Balance.COSTS.goldChest or Balance.COSTS.obsidianChest
        local funds = isGold and self.saveData.gold or self.saveData.gems
        local th = Skin.theme(card.theme)
        if self.selectedChest == card.id then Skin.roundRect(C.yellow, card.x - 1, y - 1, w + 2, h + 2, 4) end
        Skin.panel(card.x, y, w, h, "dark")
        Skin.roundRect(th.dark, card.x + 1, y + 1, w - 2, 17, 2)
        Skin.rect(th.main, card.x + 3, y + 1, w - 6, 14)
        Skin.disc(th.main, card.x + w / 2, y + 62, 40, 0.18)
        Skin.button(card.x + 6, y + 118, w - 12, 44, (funds >= price) and card.theme or "gray", self.pressedBtn == card.btn)
        card.price = price
    end
    love.graphics.setColor(1, 1, 1, 1)
    for _, card in ipairs(CHEST_CARDS) do
        PixelFont.printf(card.name, card.x, y + 4, w, "center", C.white, "main")
        local frame = Art.frame(card.sprite, 1)
        local bob = math.floor(math.sin(t * 2.5 + (card.id == "gold" and 0 or 1.5)) * 1.5)
        Art.drawEx(card.sprite, 1, card.x + w / 2 - frame.w, y + 102 - frame.h * 2 + bob, 0, 2, 2)
        local labelW = PixelFont.getWidth(tostring(card.price), "main", 2) + 22
        local lx = math.floor(card.x + (w - labelW) / 2)
        Art.drawEx(card.currency, 1, lx + 7, y + 138, 0, 2, 2)
        PixelFont.print(tostring(card.price), lx + 22, y + 128, C.white, "main", 2)
    end
end

-- Chest sprite of the opening sequence: shakes, then bursts open (src/render/sprites/menu_art.lua)
function MenuState:drawChestSprite(cx, cy, chestType, shake)
    local name = (chestType == "obsidian") and "menu_chest_obsidian" or "menu_chest_gold"
    local frame = Art.frame(name, 1)
    local glow = (chestType == "obsidian") and Palette.C.magenta or Palette.C.amber
    Skin.disc(glow, cx, cy, 44, 0.18)
    love.graphics.setColor(1, 1, 1, 1)
    Art.drawEx(name, 1, math.floor(cx - frame.w * 1.5 + shake), math.floor(cy - frame.h * 1.5), 0, 3, 3)
end

-- ============================================================================
-- SÉQUENCE GACHA SPECTACULAIRE (GOD RAYS & CARTE RÉVÉLÉE)
-- ============================================================================
function MenuState:drawGachaSequence()
    local botW = Config.BOTTOM_WIDTH
    local botH = Config.BOTTOM_HEIGHT
    local cx, cy = botW / 2, 85

    love.graphics.setColor(0.04, 0.05, 0.08, 0.94)
    love.graphics.rectangle("fill", 0, 0, botW, botH)

    if self.chestTimer < 0.7 then
        local shake = math.sin(self.chestTimer * 45) * 5
        self:drawChestSprite(cx, cy, self.openingChest, shake)
        UI.printfOutlined("OPENING CHEST...", 0, 126, botW, "center", {1.0, 0.85, 0.25, 1.0})
    else
        local rData = self.rewardItem and Items.getRarityData(self.rewardItem.rarity) or Items.RARITIES.rare
        UI.drawGodRays(cx, cy, 140, 14, self.godRaysAngle, {rData.color[1], rData.color[2], rData.color[3], 0.32})

        for _, p in ipairs(self.particles) do
            love.graphics.setColor(p.color[1], p.color[2], p.color[3], p.alpha)
            love.graphics.circle("fill", p.x, p.y, p.size)
        end

        if self.rewardItem then
            local cardW = 160
            local cardH = 88
            local cardX = cx - cardW / 2
            local cardY = cy - cardH / 2 + 5

            UI.drawItemCard(cardX, cardY, cardW, cardH, self.rewardItem, 1, false, true)
            UI.printfOutlined(self.rewardItem.name, 0, cardY + cardH + 6, botW, "center", {1, 1, 1, 1}, {0.08, 0.10, 0.14, 1.0}, 1)
            UI.printfOutlined(string.format("[%s]", rData.name), 0, cardY + cardH + 20, botW, "center", rData.color, {0.08, 0.10, 0.14, 1.0}, 1)
        end

        local isRecupPressed = (self.pressedBtn == "claim")
        UI.drawPillButton(cx - 70, 154, 140, 36, "CLAIM", "emerald", isRecupPressed, "check")
    end
end

-- ============================================================================
-- HUB TOUCH INPUT (BOTTOM SCREEN 320x240)
-- Press records the touched element (self.pressedBtn), release triggers the action.
-- Each tab has its own press (PRESS) and release (RELEASE) handler.
-- ============================================================================
local PRESS, RELEASE = {}, {}

function PRESS.play(self, tx, ty)
    if tx <= PLAY_PREV.x + PLAY_PREV.w + 2 and ty <= PLAY_WORLD.y + PLAY_WORLD.h then return "chap_prev" end
    if tx >= PLAY_NEXT.x - 2 and ty <= PLAY_WORLD.y + PLAY_WORLD.h then return "chap_next" end
    if ty >= PLAY_MODE_Y and ty <= PLAY_MODE_Y + PLAY_MODE_H then
        for i, mode in ipairs(PLAY_MODE_ORDER) do
            local x = 4 + (i - 1) * PLAY_MODE_STEP
            if tx >= x and tx <= x + PLAY_MODE_W then return "mode_" .. mode end
        end
    end
    if inRect(PLAY_PATROL, tx, ty) then return "claim_patrol" end
    if Save.getRun() and inRect(PLAY_ABANDON, tx, ty) then return "abandon_run" end
    if inRect(PLAY_BATTLE, tx, ty) then return "play" end
    return nil
end

function PRESS.quests(self, tx, ty)
    local sub = subtabAt(QUEST_SUBTABS, SUBTAB_SPAN.quests, tx, ty)
    if sub then return "subtab_" .. sub end

    if self.questSubPage == "achievements" then
        if inRect(FEAT_PREV, tx, ty) then return "feat_prev" end
        if inRect(FEAT_NEXT, tx, ty) then return "feat_next" end
        local a = self:featAt(tx, ty)
        return a and ("ach_" .. a.id) or nil
    elseif self.questSubPage == "weekly" then
        local quest = questRowAt(Save.getWeeklyQuestList(), WEEKLY_FIRST_Y, tx, ty)
        return quest and ("weekly_" .. quest.id) or nil
    end

    if ty >= CONTENT_Y and ty <= CONTENT_Y + 30 then
        for i, tier in ipairs(Quests.TIERS) do
            local x = tierX(tier)
            if tx >= x - 12 and tx <= x + 12 then return "tier_" .. i end
        end
    end
    local quest = questRowAt(Save.getDailyQuestList(), DAILY_FIRST_Y, tx, ty)
    return quest and ("quest_" .. quest.id) or nil
end

function PRESS.heroes(self, tx, ty)
    local W = Config.BOTTOM_WIDTH
    if self.heroSubPage == "bestiary" then
        if inRect(BEST_BACK, tx, ty) then return "bestiary_back" end
        for i, entry in ipairs(Bestiary.ENTRIES) do
            local cx, cy = bestiaryCell(i)
            if tx >= cx - 1 and tx <= cx + BEST_CELL_W + 1 and ty >= cy - 1 and ty <= cy + BEST_CELL_H + 1 then
                return "bestiary_" .. entry.type
            end
        end
        return nil
    end

    if inRect(HERO_BESTIARY, tx, ty) then return "open_bestiary" end
    for i, h in ipairs(Heroes.getAll()) do
        local x = heroCardX(i)
        if tx >= x and tx <= x + HERO_CARD_W and ty >= HERO_CARD_Y and ty <= HERO_CARD_Y + HERO_CARD_H then
            return "hero_" .. h.id
        end
    end
    if inRect(HERO_ACTION, tx, ty) and self.saveData.selectedHero ~= self.selectedHeroPreview then
        return self:isPreviewUnlocked() and "select_hero" or "unlock_hero"
    end
    return nil
end

function PRESS.talents(self, tx, ty)
    local talentId = talentAt(tx, ty)
    if talentId then return "talent_" .. talentId end
    local b = TALENT_BTN
    if tx >= b.x - 4 and tx <= b.x + b.w + 4 and ty >= b.y - 4 and ty <= b.y + b.h + 4 then
        return "upgrade_talent"
    end
    return nil
end

function PRESS.chests(self, tx, ty)
    local sub = subtabAt(CHEST_SUBTABS, SUBTAB_SPAN.chests, tx, ty)
    if sub then return "subtab_" .. sub end

    if self.chestSubPage == "shop" then
        for i = 1, 3 do
            local x = 4 + (i - 1) * SHOP_CARD_STEP
            if tx >= x and tx <= x + SHOP_CARD_W and ty >= SHOP_BTN_Y - 4 and ty <= SHOP_BTN_Y + SHOP_BTN_H then
                return "shop_" .. i
            end
        end
        return nil
    end
    for _, card in ipairs(CHEST_CARDS) do
        if tx >= card.x and tx <= card.x + CHEST_CARD_W and ty >= CHEST_CARD_Y and ty <= CHEST_CARD_Y + CHEST_CARD_H then
            self.selectedChest = card.id
            return card.btn
        end
    end
    return nil
end

function MenuState:touchpressed(id, tx, ty)
    Audio.play("ui_click", 0.05, 0.5)
    self.pressedBtn = nil

    -- Settings tab: the panel gets the whole screen except the tab bar
    if self.currentTab == "settings" and ty < TAB_Y - 2 and not self.openingChest then
        self.settingsPanel:touchpressed(tx, ty)
        self.pressedBtn = "settings_panel"
        return
    end

    if self.openingChest then
        if self.chestTimer >= 0.7 then
            local cx = Config.BOTTOM_WIDTH / 2
            if tx >= cx - 70 and tx <= cx + 70 and ty >= 150 and ty <= 194 then
                self.pressedBtn = "claim"
            end
        end
        return
    end

    -- 1. Tab bar (drawn over the content, takes priority)
    if ty >= 200 then
        for _, tab in ipairs(self.tabs) do
            if tx >= tab.x and tx < tab.x + TAB_STEP and ty >= TAB_Y - 2 then
                self.pressedBtn = "tab_" .. tab.id
                return
            end
        end
    end

    -- 2. Active tab content
    if self.currentTab == "equipment" then
        self.inventory:touchpressed(id, tx, ty)
        return
    end
    local press = PRESS[self.currentTab]
    if press then self.pressedBtn = press(self, tx, ty) end
end

function MenuState:touchmoved(id, tx, ty, dx, dy)
    if self.currentTab == "equipment" and not self.openingChest then
        self.inventory:touchmoved(id, tx, ty, dx, dy)
    end
end

function RELEASE.play(self, pressed)
    if pressed == "chap_prev" then
        local curC = self.saveData.selectedChapter or 1
        Save.setChapter(curC > 1 and (curC - 1) or #self.chapters)
    elseif pressed == "chap_next" then
        local curC = self.saveData.selectedChapter or 1
        Save.setChapter(curC < #self.chapters and (curC + 1) or 1)
    elseif pressed == "claim_patrol" then
        local claimed = Save.claimPatrol()
        if claimed > 0 then
            self.patrolRewardText = string.format("+%d GOLD COLLECTED!", claimed)
            self.patrolRewardTimer = 1.6
        end
    elseif pressed:sub(1, 5) == "mode_" then
        self.selectedMode = pressed:sub(6)
    elseif pressed == "play" then
        self:launchGame()
    elseif pressed == "abandon_run" then
        local run = Save.getRun()
        if run and (run.gold or 0) > 0 then Save.addGold(run.gold) end
        Save.clearRun()
        Audio.play("ui_cancel", 0, 0.8)
        self.saveData = Save.get()
    end
end

function RELEASE.quests(self, pressed)
    local ok = false
    if pressed:sub(1, 7) == "subtab_" then
        self.questSubPage = pressed:sub(8)
        self.featPage = 1
    elseif pressed == "feat_prev" or pressed == "feat_next" then
        if self:turnFeatPage(pressed == "feat_prev" and -1 or 1) then Audio.play("ui_click", 0.05, 0.6) end
    elseif pressed:sub(1, 4) == "ach_" then
        ok = Save.claimAchievement(pressed:sub(5))
    elseif pressed:sub(1, 7) == "weekly_" then
        ok = Save.claimWeeklyQuest(pressed:sub(8))
    elseif pressed:sub(1, 6) == "quest_" then
        ok = Save.claimQuest(pressed:sub(7))
    elseif pressed:sub(1, 5) == "tier_" then
        ok = Save.claimQuestTier(tonumber(pressed:sub(6)))
    end
    if ok then Audio.play("ui_confirm", 0, 0.9) end
    self.saveData = Save.get()
end

function RELEASE.heroes(self, pressed)
    if pressed == "bestiary_back" then
        self.heroSubPage = "roster"
    elseif pressed:sub(1, 9) == "bestiary_" then
        self.bestiarySelected = pressed:sub(10)
    elseif pressed == "open_bestiary" then
        self.heroSubPage = "bestiary"
    elseif pressed:sub(1, 5) == "hero_" then
        self.selectedHeroPreview = pressed:sub(6)
    elseif pressed == "select_hero" then
        Save.selectHero(self.selectedHeroPreview)
    elseif pressed == "unlock_hero" then
        if Save.unlockHero(self.selectedHeroPreview) then
            Save.selectHero(self.selectedHeroPreview)
            Audio.play("ui_confirm", 0, 0.9)
        else
            Audio.play("ui_cancel", 0, 0.7)
        end
    end
end

function RELEASE.talents(self, pressed)
    if pressed:sub(1, 7) == "talent_" then
        self:selectTalent(pressed:sub(8))
    elseif pressed == "upgrade_talent" then
        self:upgradeSelectedTalent()
    end
end

function RELEASE.chests(self, pressed)
    if pressed:sub(1, 7) == "subtab_" then
        self.chestSubPage = pressed:sub(8)
    elseif pressed:sub(1, 5) == "shop_" then
        self:buyShopOffer(tonumber(pressed:sub(6)))
    elseif pressed == "open_gold" or pressed == "open_obsidian" then
        local isGold = (pressed == "open_gold")
        local cost = isGold and Balance.COSTS.goldChest or Balance.COSTS.obsidianChest
        local funds = isGold and self.saveData.gold or self.saveData.gems
        if funds >= cost then
            if isGold then Save.addGold(-cost) else Save.addGems(-cost) end
            self:openChest(isGold and "gold" or "obsidian")
        else
            Audio.play("ui_cancel", 0, 0.8)
        end
    end
end

function MenuState:touchreleased(id, tx, ty)
    local pressed = self.pressedBtn
    self.pressedBtn = nil

    if pressed == "settings_panel" then
        self:handlePanelRequest(self.settingsPanel:touchreleased())
        return
    end

    if self.openingChest then
        if pressed == "claim" then self:claimChest() end
        return
    end

    -- 1. Tab navigation
    if pressed and pressed:sub(1, 4) == "tab_" then
        self:switchTab(pressed:sub(5))
        return
    end

    -- 2. Per-tab actions
    if self.currentTab == "equipment" then
        self.inventory:touchreleased(id, tx, ty)
        return
    end
    local release = pressed and RELEASE[self.currentTab]
    if release then release(self, pressed) end
end

-- Buys an offer of the daily shop
function MenuState:buyShopOffer(idx)
    local offer = self:getShopOffers()[idx]
    local shop = Save.getShop()
    if not offer or shop.bought[idx] then return end
    local canBuy = (offer.currency == "gems") and (self.saveData.gems >= offer.price)
        or (offer.currency ~= "gems" and self.saveData.gold >= offer.price)
    if not canBuy then
        Audio.play("ui_cancel", 0, 0.8)
        return
    end
    if offer.currency == "gems" then Save.addGems(-offer.price) else Save.addGold(-offer.price) end
    if offer.kind == "item" then
        Save.addItem(offer.id)
    elseif offer.kind == "gold" then
        Save.addGold(offer.amount)
    elseif offer.kind == "energy" then
        local d = Save.get()
        d.energy = math.min(d.maxEnergy, d.energy + offer.amount)
    end
    Save.markShopBought(idx)
    Audio.play("ui_confirm", 0, 0.9)
    self.saveData = Save.get()
    self.inventory:refresh()
end

-- ============================================================================
-- NAVIGATION: TABS, BACK, D-PAD
-- ============================================================================
-- Switches tab: each tab opens on its main page, and the Forge item sheet closes when
-- leaving the Forge
function MenuState:switchTab(tabId)
    if self.currentTab == "equipment" and tabId ~= "equipment" then
        self.inventory:reset()
    end
    self.currentTab = tabId
    if tabId == "quests" then
        self.questSubPage = "quests"
    elseif tabId == "chests" then
        self.chestSubPage = "chests"
    elseif tabId == "heroes" then
        self.heroSubPage = "roster"
    elseif tabId == "equipment" then
        self.inventory:refresh()
    elseif tabId == "settings" then
        self.settingsPanel:open()
    end
end

-- Previous / next tab (L / R shoulders)
function MenuState:cycleTab(step)
    local idx = 1
    for i, tab in ipairs(self.tabs) do
        if tab.id == self.currentTab then idx = i end
    end
    self:switchTab(self.tabs[((idx - 1 + step) % #self.tabs) + 1].id)
    Audio.play("ui_click", 0.05, 0.7)
end

-- Back (B, Escape, Backspace): closes whatever is open, then returns to PLAY.
-- Returns false when there was nothing to close.
function MenuState:goBack()
    -- Chest opening sequence: back claims the item (never quits the game)
    if self.openingChest then
        if self.chestTimer >= 0.7 then self:claimChest() end
        return true
    end
    if self.currentTab == "equipment" and self.inventory:back() then return true end
    if self.currentTab == "quests" and self.questSubPage ~= "quests" then
        self.questSubPage = "quests"
    elseif self.currentTab == "heroes" and self.heroSubPage == "bestiary" then
        self.heroSubPage = "roster"
    elseif self.currentTab == "chests" and self.chestSubPage == "shop" then
        self.chestSubPage = "chests"
    elseif self.currentTab ~= "play" then
        self:switchTab("play")
    else
        return false
    end
    Audio.play("ui_cancel", 0, 0.7)
    return true
end

-- Next element of a (wrapping) list, matched by value or by its `key` field
local function cycleIn(list, current, step, key)
    local idx = 1
    for i, v in ipairs(list) do
        if (key and v[key] or v) == current then idx = i end
    end
    local nextValue = list[((idx - 1 + step) % #list) + 1]
    return key and nextValue[key] or nextValue
end

local DPAD_STEP = { dpleft = -1, dpright = 1, dpup = -1, dpdown = 1 }

-- D-pad: talents, subpages, mode and chapter, heroes
function MenuState:navigate(button)
    local step = DPAD_STEP[button]
    if not step then return false end
    local horizontal = (button == "dpleft" or button == "dpright")
    local tab = self.currentTab

    if tab == "talents" then
        return self:moveTalentSelection(button)
    elseif tab == "quests" and horizontal then
        self.questSubPage = cycleIn(QUEST_SUBTABS, self.questSubPage, step, "id")
    elseif tab == "chests" and horizontal and self.chestSubPage == "chests" then
        self.selectedChest = (self.selectedChest == "obsidian") and "gold" or "obsidian"
    elseif tab == "chests" and not horizontal then
        self.chestSubPage = cycleIn(CHEST_SUBTABS, self.chestSubPage, step, "id")
    elseif tab == "play" and horizontal then
        local n = #self.chapters
        Save.setChapter(((self.saveData.selectedChapter or 1) - 1 + step) % n + 1)
    elseif tab == "play" then
        self.selectedMode = cycleIn(PLAY_MODE_ORDER, self.selectedMode, step)
    elseif tab == "heroes" and self.heroSubPage == "roster" and horizontal then
        self.selectedHeroPreview = cycleIn(Heroes.getAll(), self.selectedHeroPreview, step, "id")
    else
        return false
    end
    Audio.play("ui_click", 0.05, 0.6)
    return true
end

function MenuState:isPreviewUnlocked()
    local cur = self.selectedHeroPreview or "atreus"
    return self.saveData.unlockedHeroes and self.saveData.unlockedHeroes[cur]
end

-- A / Return: main action of the tab
function MenuState:confirm()
    if self.currentTab == "play" then
        self:launchGame()
    elseif self.currentTab == "talents" then
        self:upgradeSelectedTalent()
    elseif self.currentTab == "heroes" and self.heroSubPage == "roster" then
        RELEASE.heroes(self, self:isPreviewUnlocked() and "select_hero" or "unlock_hero")
    elseif self.currentTab == "chests" and self.chestSubPage == "chests" then
        RELEASE.chests(self, (self.selectedChest == "obsidian") and "open_obsidian" or "open_gold")
    end
end

-- Settings panel requests (src/ui/settings_panel.lua)
function MenuState:handlePanelRequest(request)
    if not request then return end
    if request.refresh then
        self.saveData = Save.get()
        self.inventory:refresh()
    end
    if request.launch then
        self.sm:switch("game", { mode = "ascension", startRoom = request.launch.startRoom })
    end
end

function MenuState:launchGame()
    Audio.play("ui_confirm", 0, 0.8)
    local run = Save.getRun()
    if run then
        self.sm:switch("game", { mode = run.mode, resume = run })
        return
    end
    -- The run always starts; available energy only grants a gold bonus.
    local boosted = Save.spendEnergy(self.selectedMode)
    self.saveData = Save.get()
    self.sm:switch("game", {
        mode = self.selectedMode,
        chapter = self.saveData.selectedChapter or 1,
        boosted = boosted,
    })
end

function MenuState:openChest(chestType)
    self.openingChest = chestType
    self.chestTimer = 0
    self.particles = {}

    -- Rarity-weighted roll capped by player progression: epic or legendary items only
    -- appear once the matching tier is reached.
    local pickedId = Items.rollDrop(chestType, nil, Balance.maxRarity(self.saveData))
    self.rewardItem = Items.get(pickedId)
    -- "Open N chests" missions (saved by Save.addItem right after)
    Save.addQuestProgress("chests", 1)
    local isNew, msg = Save.addItem(pickedId)
    self.rewardMessage = msg
end

-- End of the opening sequence: back to the Chests tab
function MenuState:claimChest()
    self.openingChest = nil
    self.rewardItem = nil
    self.particles = {}
    self.inventory:refresh()
end

-- 3DS buttons: A confirms, B goes back, L/R switch tabs, Y opens settings, START launches
-- a run, the d-pad navigates inside the tab
function MenuState:gamepadpressed(joystick, button)
    if self.openingChest then
        if (button == "a" or button == "b") and self.chestTimer >= 0.7 then self:claimChest() end
        return
    end
    if button == "b" then
        self:goBack()
        return
    end

    if self.currentTab == "settings" then
        if button == "y" then
            self:switchTab("play")
            Audio.play("ui_click", 0.05, 0.7)
            return
        end
        -- Settings: d-pad, A and (admin unlocked) L/R drive the panel
        local isShoulder = (button == "leftshoulder" or button == "rightshoulder")
        if not isShoulder or self.settingsPanel:isAdminUnlocked() then
            self:handlePanelRequest(self.settingsPanel:gamepadpressed(button))
            return
        end
    end

    if button == "leftshoulder" or button == "l" or button == "rightshoulder" or button == "r" then
        self:cycleTab((button == "leftshoulder" or button == "l") and -1 or 1)
        return
    end
    -- Forge: A / X / Y act on the open item sheet
    if self.currentTab == "equipment" and self.inventory:gamepadpressed(button) then return end

    if button == "y" then
        self:switchTab("settings")
        Audio.play("ui_click", 0.05, 0.7)
    elseif button == "start" then
        self:launchGame()
    elseif button == "a" then
        self:confirm()
    else
        self:navigate(button)
    end
end

local KEY_TO_DPAD = { left = "dpleft", right = "dpright", up = "dpup", down = "dpdown" }

-- PC keyboard: Return / Space confirm, arrows = d-pad, digits = tabs, Backspace and
-- Escape go back. Returns true when the key was used.
function MenuState:keypressed(key)
    if self.openingChest then
        if (key == "return" or key == "space") and self.chestTimer >= 0.7 then self:claimChest() end
        return true
    end
    if self.currentTab == "equipment" and self.inventory:keypressed(key) then return true end
    if key == "escape" or key == "backspace" then return self:goBack() end
    if key == "return" or key == "space" then
        self:confirm()
        return true
    end
    if KEY_TO_DPAD[key] then return self:navigate(KEY_TO_DPAD[key]) end
    local n = tonumber(key)
    if n and self.tabs[n] then
        self:switchTab(self.tabs[n].id)
        return true
    end
    return false
end

return MenuState
