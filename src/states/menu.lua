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
local SettingsPanel = require("src.ui.settings_panel")

local MenuState = {}
MenuState.__index = MenuState

local MODE_LABELS = { ascension = "Ascension", infinite = "The Abyss", boss_rush = "Boss Rush", survival = "Arena" }

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
    self.settingsPanel = SettingsPanel.new()
    self.bestiarySelected = "slime"

    -- Dedicated inventory manager with kinetic scrolling
    self.inventory = Inventory.new()

    -- Chapters with distinct biomes and floors
    self.chapters = {
        { id = 1, name = "Emerald Plains", floors = 50, theme = "green", desc = "Slimes & Forest Wolves", bg = {0.10, 0.22, 0.14} },
        { id = 2, name = "Crystal Caverns", floors = 30, theme = "blue", desc = "Bats & Stalactites", bg = {0.08, 0.16, 0.28} },
        { id = 3, name = "Scorching Dunes", floors = 20, theme = "gold", desc = "Scorpions & Magma Worms", bg = {0.28, 0.18, 0.08} },
        { id = 4, name = "Shadow Citadel", floors = 50, theme = "purple", desc = "Wraiths & Dark Skeletons", bg = {0.20, 0.10, 0.28} },
    }

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
        tab.x, tab.y, tab.w, tab.h = 6 + (i - 1) * 44, 207, 41, 26
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

-- ============================================================================
-- ============================================================================
-- TOP SCREEN (400x240) : VITRINE BENTO 2026, PIÉDESTAL 3D & DIORAMA ART-DIRECTED
-- ============================================================================
-- Diorama du hub : ciel, nuages, île flottante et piédestal de pierre
function MenuState:drawHubBackdrop(t)
    local w, h = Config.TOP_WIDTH, Config.TOP_HEIGHT

    -- Ciel dégradé
    local top, bottom = Palette.hex("2c4a86"), Palette.hex("7fc0ea")
    local bands = 10
    for i = 0, bands - 1 do
        local f = i / (bands - 1)
        love.graphics.setColor(top[1] + (bottom[1] - top[1]) * f, top[2] + (bottom[2] - top[2]) * f, top[3] + (bottom[3] - top[3]) * f, 1)
        love.graphics.rectangle("fill", 0, i * (h / bands), w, h / bands + 1)
    end

    -- Nuages en lente dérive (les étoiles d'un pixel coûtaient 24 appels GPU pour un effet
    -- invisible sur l'écran 3DS : retirées)
    love.graphics.setColor(1, 1, 1, 1)
    Art.draw("cloud_c", 1, (40 + t * 5) % (w + 120) - 60, 42)
    Art.draw("cloud_a", 1, (250 - t * 4) % (w + 120) - 60, 26)
    Art.draw("cloud_b", 1, (150 + t * 3) % (w + 120) - 60, 66)
    Art.draw("far_island_b", 1, 60, 96)
    Art.draw("far_island_a", 1, 348, 120)

    -- Île centrale : falaise + herbe + bordure de buissons
    local ix, iw = 96, 208
    local groundY = 150
    for x = ix, ix + iw - 16, 16 do
        Art.draw("cliff", 1 + (math.floor(x / 16) % 4), x, groundY + 6)
    end
    Palette.set(Palette.C.grass)
    love.graphics.rectangle("fill", ix, groundY, iw, 10)
    Palette.set(Palette.C.moss)
    love.graphics.rectangle("fill", ix, groundY - 2, iw, 2)
    Palette.set(Palette.C.grassDark)
    love.graphics.rectangle("fill", ix, groundY + 8, iw, 2)
    love.graphics.setColor(1, 1, 1, 1)
    for x = ix + 6, ix + iw - 6, 14 do
        Art.draw((x % 28 == 0) and "bush_a" or "bush_b", 1, x, groundY + 1)
    end
    Art.draw("tall_tree_a", 1, ix + 12, groundY + 4)
    Art.draw("tall_tree_b", 1, ix + iw - 14, groundY + 2)

    -- Dalles du piédestal
    for i = -1, 1 do
        Art.draw("slab", 2 + (i + 1), math.floor(w / 2) + i * 16 - 8, groundY - 12)
    end
    return groundY
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
    for _, itemId in pairs(self.saveData.equipped) do
        local lvl = self.saveData.itemLevels[itemId] or 1
        local effR = Save.getItemRarity(itemId)
        local st = Items.getStats(itemId, lvl, effR, Save.getItemStars(itemId))
        totalAtk = totalAtk + st.atk
        totalHp = totalHp + st.hp
    end
    local talents = Save.getTalents()
    totalAtk = totalAtk + (talents.strength or 0) * 5
    totalHp = totalHp + (talents.vitality or 0) * 80
    self.powerCache = { seq = seq, hero = heroId, expires = t + POWER_REFRESH, atk = totalAtk, hp = totalHp }
    return totalAtk, totalHp
end

-- ============================================================================
-- TOP SCREEN (400x240) : DIORAMA DU HUB, HÉROS PIXEL & FICHE DE PUISSANCE
-- ============================================================================
function MenuState:drawTop()
    local w = Config.TOP_WIDTH
    local h = Config.TOP_HEIGHT
    local t = love.timer.getTime()
    local curHeroId = self.saveData.selectedHero or "atreus"
    local hData = Heroes.get(curHeroId)

    local groundY = self:drawHubBackdrop(t)

    -- Rayons de lumière derrière le héros
    UI.drawGodRays(w / 2, groundY - 30, 150, 12, self.godRaysAngle * 0.4,
        { hData.color[1], hData.color[2], hData.color[3], 0.10 })
    if self.openingChest and self.chestTimer >= 0.7 then
        local rData = self.rewardItem and Items.getRarityData(self.rewardItem.rarity) or Items.RARITIES.rare
        UI.drawGodRays(w / 2, 130, 220, 16, self.godRaysAngle, { rData.color[1], rData.color[2], rData.color[3], 0.22 })
    end

    -- ------------------------------------------------------------------
    -- Héros pixel sur son piédestal (échelle 3) + familiers équipés
    -- ------------------------------------------------------------------
    local heroX = math.floor(w / 2)
    local bob = math.floor(math.sin(t * 2.2) * 2)
    local heroBottom = groundY - 12 + bob
    local variant = (curHeroId ~= "atreus") and curHeroId or nil

    Palette.set(Palette.C.ink, 0.35)
    love.graphics.ellipse("fill", heroX, groundY - 8, 26 - bob, 7)
    love.graphics.setColor(1, 1, 1, 1)
    Art.drawEx("hero_legs", 1, heroX, heroBottom, 0, 3, 3)
    Art.drawEx("hero_body", 1, heroX, heroBottom - 9, 0, 3, 3, false, variant)
    local acc = HeroSprites.ACCESSORY_BY_HERO[curHeroId]
    if acc then
        local offs = { feather = { 3, -14 }, mask = { -2, -8 }, crest = { 0, -15 }, horns = { 0, -13 }, tiara = { 0, -15 } }
        local o = offs[acc]
        Art.drawEx("hero_acc_" .. acc, 1, heroX + o[1] * 3, heroBottom - 9 + o[2] * 3, 0, 3, 3)
    end
    Art.drawEx("bow", 1, heroX + 26, heroBottom - 34, 0.35, 2, 2)

    -- Familiers équipés (sprites de combat, échelle 2)
    local petFloat = math.floor(math.sin(t * 4.6) * 3)
    if self.saveData.equipped.pet1 or self.saveData.equipped.pet then
        Art.drawEx("pet_bat", (math.floor(t * 8) % 2) + 1, heroX - 58, heroBottom - 44 + petFloat, 0, 2, 2)
    end
    if self.saveData.equipped.pet2 then
        Art.drawEx("pet_ghost", (math.floor(t * 4) % 2) + 1, heroX + 58, heroBottom - 44 - petFloat, 0, 2, 2)
    end

    -- ------------------------------------------------------------------
    -- En-tête : niveau, or, gemmes, énergie
    -- ------------------------------------------------------------------
    UI.drawBentoCard(6, 4, w - 12, 24, {})
    UI.drawPillBadge(10, 7, 50, 18, string.format("LV. %d", self.saveData.accountLevel or 1),
        { 0.14, 0.18, 0.28, 0.95 }, { 1.0, 0.82, 0.20, 0.9 }, { 1.0, 0.88, 0.30, 1.0 })
    UI.drawIcon("gold", 76, 16, 11)
    UI.drawText(string.format("%d", self.saveData.gold), 86, 10, Palette.C.yellow)
    UI.drawIcon("gem", 156, 16, 11)
    UI.drawText(string.format("%d", self.saveData.gems), 166, 10, Palette.C.leaf)
    UI.drawIcon("energy", 232, 16, 11)
    UI.drawText(string.format("%d/%d", self.saveData.energy, self.saveData.maxEnergy), 242, 10, Palette.C.cyan)
    -- Réglages : onglet SETTINGS de l'écran tactile (l'écran du haut n'est pas tactile)
    UI.setFont("tiny")
    UI.drawTextAligned("Y: SETTINGS", w - 76, 12, 68, "center", Palette.C.fog)
    UI.setFont("main")

    -- ------------------------------------------------------------------
    -- Power Card (attack / max health)
    -- ------------------------------------------------------------------
    local totalAtk, totalHp = self:powerTotals(curHeroId, hData, t)

    UI.drawBentoCard(6, 36, 92, 40, { accentColor = { 0.95, 0.28, 0.30, 0.9 } })
    UI.drawIcon("swords", 18, 52, 11)
    UI.drawText("ATTACK", 28, 46, { 1.0, 0.45, 0.45, 1.0 })
    UI.drawTextAligned(string.format("%d", totalAtk), 6, 60, 92, "center", Palette.C.white)

    UI.drawBentoCard(w - 98, 36, 92, 40, { accentColor = { 0.30, 0.92, 0.48, 0.9 } })
    UI.drawIcon("heart", w - 86, 52, 11)
    UI.drawText("HEALTH", w - 76, 46, { 0.45, 1.0, 0.65, 1.0 })
    UI.drawTextAligned(string.format("%d", totalHp), w - 98, 60, 92, "center", Palette.C.white)

    -- Badge Titre Officiel "ARCH3RO" au centre supérieur
    UI.drawPillBadge(w / 2 - 45, 36, 90, 18, "ARCH3RO",
        { 0.10, 0.14, 0.22, 0.95 }, { 1.0, 0.82, 0.20, 0.95 }, { 1.0, 0.88, 0.30, 1.0 })

    -- ------------------------------------------------------------------
    -- Banners: hero and passive
    -- ------------------------------------------------------------------
    Skin.ribbon(w / 2, 186, 214, 20, "gold")
    UI.drawTextAligned(string.format("%s - %s", hData.name:upper(), hData.title:upper()), w / 2 - 107, 190, 214, "center", Palette.C.white)

    UI.drawBentoCard(14, 212, w - 28, 24, {})
    UI.setFont("tiny")
    UI.drawTextAligned(string.format("PASSIVE: %s", hData.passiveName:upper()), 18, 215, w - 36, "center", Palette.C.yellow)
    UI.drawTextAligned(hData.passiveDesc, 18, 224, w - 36, "center", { 0.85, 0.92, 1.0, 0.95 })
    UI.setFont("main")
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

    -- 2. Barre de Navigation Flottante Bento Dock (308x32)
    local dockX, dockY, dockW, dockH = 6, 204, 308, 32
    UI.drawBentoCard(dockX, dockY, dockW, dockH, {
        r = 10,
        bg = {0.07, 0.09, 0.13, 0.98},
        borderColor = {0.18, 0.22, 0.32, 0.90},
        borderWidth = 1,
        isElevated = true,
    })

    for _, tab in ipairs(self.tabs) do
        local isActive = (self.currentTab == tab.id)
        local isPressed = (self.pressedBtn == "tab_" .. tab.id)
        local btnTheme = isActive and tab.theme or "dark"
        UI.drawPillButton(tab.x, tab.y, tab.w, tab.h, tab.name, btnTheme, isPressed, tab.icon)
    end
end

-- ============================================================================
-- ONGLET 1 : JOUER (BENTO GRID 2026 : MONDE, PATROUILLE, MODES & LAUNCHER)
-- ============================================================================
function MenuState:drawPlayTab()
    local t = love.timer.getTime()
    local chapIdx = self.saveData.selectedChapter or 1
    local chap = self.chapters[chapIdx] or self.chapters[1]

    -- 1. BENTO 1 (HAUT-GAUCHE, 194x88) : VITRINE DU MONDE & PROGRESSION
    local cx, cy, cw, ch = 6, 6, 194, 88
    local chapBg = {chap.bg[1] * 0.7 + 0.04, chap.bg[2] * 0.7 + 0.04, chap.bg[3] * 0.7 + 0.06, 0.96}
    UI.drawBentoCard(cx, cy, cw, ch, {
        r = 8,
        bg = chapBg,
        borderColor = {0.26, 0.34, 0.48, 0.90},
        accentColor = {1.0, 0.82, 0.20, 0.85},
        isElevated = true,
    })

    -- Header: Chapter Badge + Integrated Nav Chevrons
    UI.drawPillBadge(cx + 8, cy + 8, 70, 18, string.format("CHAPTER %d", chap.id), {0.14, 0.18, 0.26, 0.9}, {1.0, 0.80, 0.20, 0.9}, {1.0, 0.88, 0.30, 1.0})
    UI.drawPillButton(cx + cw - 48, cy + 8, 20, 18, "", "blue", self.pressedBtn == "chap_prev", "arrow_left")
    UI.drawPillButton(cx + cw - 24, cy + 8, 20, 18, "", "blue", self.pressedBtn == "chap_next", "arrow_right")

    -- Chapter Name
    UI.drawText(chap.name:upper(), cx + 10, cy + 30, {0.98, 0.98, 1.0, 1.0}, {0.05, 0.06, 0.09, 1.0})
    local prevF = love.graphics.getFont()
    love.graphics.setFont(UI.getFont("tiny"))
    UI.drawText(chap.desc, cx + 10, cy + 46, {0.72, 0.80, 0.92, 1.0})

    -- Floor progress bar
    local barW = cw - 20
    local barX = cx + 10
    local barY = cy + 62
    local progress = math.min(1.0, (self.saveData.records.ascensionMax or 1) / chap.floors)
    UI.drawText(string.format("Floor %d / %d", math.min(chap.floors, self.saveData.records.ascensionMax or 1), chap.floors), barX, barY - 2, {0.85, 0.92, 1.0, 0.95})
    love.graphics.setFont(prevF)

    -- Track de barre
    love.graphics.setColor(0.06, 0.08, 0.12, 0.95)
    love.graphics.rectangle("fill", barX, barY + 12, barW, 6, 3, 3)
    -- Remplissage lumineux
    love.graphics.setColor(0.20, 0.85, 0.45, 1.0)
    love.graphics.rectangle("fill", barX, barY + 12, math.max(4, barW * progress), 6, 3, 3)

    -- 2. BENTO 2: AFK PATROL (IDLE CHEST)
    local px, py, pw, ph = 206, 6, 108, 88
    local patrolAmt = math.floor(self.saveData.patrolGold or 0)
    local canClaim = (patrolAmt > 0)
    UI.drawBentoCard(px, py, pw, ph, {
        r = 8,
        bg = {0.10, 0.12, 0.18, 0.96},
        borderColor = {0.45, 0.35, 0.15, 0.85},
        accentColor = {1.0, 0.80, 0.20, 0.85},
        isElevated = true,
    })

    -- Bouncing chest & Amount
    local bounce = math.sin(t * 3.5) * 2.0
    UI.drawIcon("chest", px + 22, py + 26 + bounce, 14, {1.0, 0.85, 0.20, 1.0})
    UI.drawText("PATROL", px + 38, py + 12, {1.0, 0.88, 0.35, 1.0})
    UI.drawText(string.format("+%d G", patrolAmt), px + 38, py + 26, {0.35, 0.95, 0.55, 1.0})

    -- Claim button
    UI.drawPillButton(px + 10, py + 58, pw - 20, 20, "COLLECT", canClaim and "gold" or "gray", self.pressedBtn == "claim_patrol", "gold")

    -- Feedback
    if self.patrolRewardTimer and self.patrolRewardTimer > 0 then
        UI.drawTextAligned(self.patrolRewardText or "+GOLD", px, py + 38, pw, "center", {1.0, 0.95, 0.20, 1.0}, {0.05, 0.05, 0.05, 1.0})
    end

    -- 3. MODE SELECTOR (4 cards: Ascension, Abyss, Boss Rush, Survival)
    local events = Save.getEvents()
    local mx, my, mw = 6, 100, 118
    UI.drawBentoCard(mx, my, mw, 96, {})

    local modes = {
        { id = "ascension", name = "ASCENSION", sub = "50 floors | Best " .. (self.saveData.records.ascensionMax or 1), theme = { 0.40, 0.85, 1.0, 1.0 } },
        { id = "infinite",  name = "THE ABYSS", sub = "Endless | Best " .. (self.saveData.records.infiniteMax or 0), theme = { 0.90, 0.45, 1.0, 1.0 } },
        { id = "boss_rush", name = "BOSS RUSH",  sub = "Consecutive bosses | Best " .. (events.bossRushBest or 0), theme = { 1.0, 0.45, 0.35, 1.0 } },
        { id = "survival",  name = "ARENA",      sub = "Waves | Best " .. (events.survivalBest or 0), theme = { 0.45, 1.0, 0.60, 1.0 } },
    }

    for i, mode in ipairs(modes) do
        local my2 = my + (i - 1) * 24
        local active = (self.selectedMode == mode.id)
        UI.drawBentoCard(mx + 2, my2 + 1, mw - 4, 22, { accentColor = active and mode.theme or nil })
        UI.drawText(mode.name, mx + 8, my2 + 2, active and mode.theme or { 0.75, 0.80, 0.90, 1.0 })
        UI.setFont("tiny")
        UI.drawText(mode.sub, mx + 8, my2 + 14, { 0.62, 0.70, 0.84, 0.95 })
        UI.setFont("main")
    end

    -- 4. BENTO 4: MASTER LAUNCHER TILE
    local lx, ly, lw, lh = 130, 100, 184, 96
    local hasEnergy = (self.saveData.energy or 0) >= Balance.energyCost(self.selectedMode)
    local pulse = 0.5 + 0.5 * math.sin(t * 3.2)
    local launchGlow = {0.20 + pulse * 0.15, 0.85 + pulse * 0.15, 0.45, 1.0}
    UI.drawBentoCard(lx, ly, lw, lh, {
        r = 8,
        bg = {0.05, 0.24, 0.14, 0.98},
        borderColor = hasEnergy and launchGlow or {0.25, 0.30, 0.40, 0.8},
        borderWidth = hasEnergy and 1.6 or 1,
        accentColor = hasEnergy and {0.35, 0.95, 0.55, 0.9} or nil,
        isElevated = true,
    })

    -- Energy bonus badge
    local bonusLabel = hasEnergy and "BONUS +50% GOLD" or "NO BONUS"
    UI.drawPillBadge(lx + 8, ly + 8, 92, 18, bonusLabel,
        hasEnergy and {0.08, 0.32, 0.20, 0.9} or {0.16, 0.18, 0.24, 0.9},
        hasEnergy and {0.30, 0.85, 0.50, 0.9} or {0.35, 0.40, 0.50, 0.9},
        hasEnergy and {0.80, 1.0, 0.90, 1.0} or {0.65, 0.70, 0.80, 1.0}, "energy")

    -- Main battle / resume button
    local run = Save.getRun()
    local bx, by, bw, bh = lx + 8, ly + 30, lw - 16, 40
    if hasEnergy then
        Skin.roundRect(Palette.C.leaf, bx - 2, by - 2, bw + 4, bh + 4, 3, 0.25 + pulse * 0.35)
    end
    local oy = Skin.button(bx, by, bw, bh, "green", self.pressedBtn == "play")
    local label = run and "RESUME" or "BATTLE"
    local labelW = PixelFont.getWidth(label, "main", 2)
    local tx = math.floor(bx + (bw - 18 - (labelW + 20)) / 2)
    local midY = by + oy + math.floor((bh - 3) / 2)
    UI.drawIcon("swords", tx + 7, midY, 20)
    PixelFont.print(label, tx + 20, midY - 11, Palette.C.white, "main", 2, "shadow")
    Skin.pill(bx + bw - 20, midY - 6, 14, 12, "dark", "A")

    -- Subtitle Mode & Chapter
    local subLabel = run and string.format("Room %d - in progress", run.room or 1)
        or string.format("%s - Ch.%d", MODE_LABELS[self.selectedMode] or "Ascension", chap.id)
    PixelFont.printf(subLabel, lx, ly + 78, lw, "center", {0.60, 0.95, 0.75, 1.0}, "main")
    if run then
        UI.drawPillButton(lx + lw - 66, ly + 8, 58, 18, "ABANDON", "red", self.pressedBtn == "abandon_run")
    end
end

-- ============================================================================
-- ONGLET : QUÊTES DU JOUR & PASSE DE COMBAT
-- ============================================================================
local QUEST_ICONS = { kills = "skull", rooms = "door", chests = "chest", upgrades = "upgrade", bosses = "swords" }

function MenuState:drawQuestsTab()
    local q = Save.getDailyQuests()
    local W = Config.BOTTOM_WIDTH

    UI.drawBentoCard(6, 4, W - 12, 42, {})
    UI.drawText("DAILY QUESTS", 14, 7, Palette.C.yellow)
    UI.drawPillButton(W - 122, 5, 56, 16, "QUESTS", "gold", false)
    UI.drawPillButton(W - 64, 5, 56, 16, "ACHIEV.", "dark", self.pressedBtn == "tab_achievements")

    -- Battle pass gauge and tiers
    local barX, barY, barW = 14, 24, W - 28
    UI.drawBar(barX, barY, barW, 12, (q.points or 0) / Quests.MAX_POINTS, "gold")
    UI.setFont("tiny")
    UI.drawTextAligned(string.format("%d / %d PTS", q.points or 0, Quests.MAX_POINTS), barX, barY + 3, barW, "center", Palette.C.white)
    UI.setFont("main")

    for i, tier in ipairs(Quests.TIERS) do
        local tx = barX + math.floor(barW * (tier.points / Quests.MAX_POINTS)) - 9
        local reached = (q.points or 0) >= tier.points
        local claimed = q.claimedTiers[i]
        local theme = claimed and "gray" or (reached and "gold" or "dark")
        Skin.button(tx, barY + 13, 18, 14, theme, self.pressedBtn == ("tier_" .. i))
        UI.drawIcon(claimed and "check" or "chest", tx + 9, barY + 19, 9)
    end

    -- Mission list
    local dailyList = Save.getDailyQuestList()
    for i, quest in ipairs(dailyList) do
        local progress, done, claimed = Quests.state(quest, q)
        local y = 52 + (i - 1) * 29
        UI.drawBentoCard(6, y, W - 12, 27, { accentColor = done and (claimed and { 0.35, 0.40, 0.50, 0.8 } or { 0.25, 0.85, 0.45, 0.9 }) or nil })
        UI.drawIcon(QUEST_ICONS[quest.kind] or "star", 20, y + 13, 11)
        UI.drawText(quest.name, 32, y + 3, claimed and Palette.C.fog or Palette.C.white)

        UI.drawBar(32, y + 16, 150, 8, progress / quest.goal, done and "green" or "blue")
        UI.setFont("tiny")
        UI.drawTextAligned(string.format("%d/%d", progress, quest.goal), 32, y + 17, 150, "center", Palette.C.white)
        local rewardText = quest.reward.gold and (quest.reward.gold .. " GOLD") or ((quest.reward.gems or 0) .. " GEMS")
        UI.drawTextAligned("+" .. rewardText, 188, y + 17, 60, "center", Palette.C.yellow)
        UI.setFont("main")

        if claimed then
            UI.drawPillBadge(252, y + 5, 58, 18, "CLAIMED", { 0.14, 0.17, 0.24, 0.95 }, { 0.30, 0.35, 0.45, 0.8 }, Palette.C.fog, "check")
        elseif done then
            UI.drawPillButton(252, y + 4, 58, 20, "CLAIM", "gold", self.pressedBtn == ("quest_" .. quest.id))
        else
            UI.drawPillBadge(252, y + 5, 58, 18, "ACTIVE", { 0.10, 0.12, 0.18, 0.9 }, { 0.22, 0.26, 0.36, 0.8 }, Palette.C.steel)
        end
    end

    -- Weekly missions
    local weeklyList, w = Save.getWeeklyQuestList()
    local baseY = 52 + #dailyList * 29 + 2
    UI.setFont("tiny")
    UI.drawTextAligned("WEEKLY MISSIONS", 6, baseY, W - 12, "left", Palette.C.cyan)
    UI.setFont("main")
    for i, quest in ipairs(weeklyList) do
        local progress, done, claimed = Quests.state(quest, w)
        local y = baseY + 11 + (i - 1) * 22
        if y + 20 <= 200 then
            UI.drawBentoCard(6, y, W - 12, 20, { accentColor = done and not claimed and { 0.25, 0.85, 0.45, 0.9 } or nil })
            UI.setFont("tiny")
            UI.drawText(quest.name, 12, y + 3, claimed and Palette.C.fog or Palette.C.white)
            UI.drawTextAligned(string.format("%d/%d", progress, quest.goal), 150, y + 3, 50, "right", Palette.C.silver)
            local rewardText = quest.reward.gold and (quest.reward.gold .. " GOLD") or ((quest.reward.gems or 0) .. " GEMS")
            UI.drawTextAligned("+" .. rewardText, 204, y + 3, 50, "right", Palette.C.yellow)
            UI.setFont("main")
            if claimed then
                UI.drawPillBadge(258, y + 3, 52, 14, "CLAIMED", { 0.14, 0.17, 0.24, 0.95 }, { 0.30, 0.35, 0.45, 0.8 }, Palette.C.fog)
            elseif done then
                UI.drawPillButton(258, y + 2, 52, 16, "CLAIM", "gold", self.pressedBtn == ("weekly_" .. quest.id))
            else
                UI.drawPillBadge(258, y + 3, 52, 14, "ACTIVE", { 0.10, 0.12, 0.18, 0.9 }, { 0.22, 0.26, 0.36, 0.8 }, Palette.C.steel)
            end
        end
    end
end

-- ============================================================================
-- PAGE : SUCCÈS PERMANENTS
-- ============================================================================
function MenuState:drawAchievementsPage()
    local W = Config.BOTTOM_WIDTH
    local d = Save.get()

    UI.drawBentoCard(6, 4, W - 12, 22, {})
    UI.drawText("ACHIEVEMENTS", 14, 7, Palette.C.yellow)
    UI.drawPillButton(W - 122, 5, 56, 16, "QUESTS", "dark", self.pressedBtn == "tab_quests")
    UI.drawPillButton(W - 64, 5, 56, 16, "ACHIEV.", "gold", false)

    for i, a in ipairs(Achievements.LIST) do
        local value, done, claimed = Achievements.state(a, d)
        local y = 28 + (i - 1) * 14
        local accent = claimed and { 0.35, 0.40, 0.50, 0.7 } or (done and { 0.25, 0.85, 0.45, 0.9 } or nil)
        UI.drawBentoCard(6, y, W - 12, 13, { accentColor = accent })
        UI.drawIcon(a.icon, 16, y + 7, 9)
        UI.setFont("tiny")
        PixelFont.printf(a.name:upper(), 26, y + 3, 80, "left", claimed and Palette.C.fog or Palette.C.white, "tiny", 1, nil, 1)
        PixelFont.printf(a.desc, 106, y + 3, 104, "left", Palette.C.steel, "tiny", 1, nil, 1)
        UI.drawBar(214, y + 3, 44, 7, value / a.goal, done and "green" or "blue")
        UI.drawTextAligned(string.format("%d/%d", value, a.goal), 214, y + 4, 44, "center", Palette.C.white)
        if claimed then
            UI.drawTextAligned("OK", 262, y + 3, 48, "center", Palette.C.leaf)
        elseif done then
            UI.drawPillButton(262, y + 1, 48, 11, "CLAIM", "gold", self.pressedBtn == ("ach_" .. a.id))
        else
            local reward = a.reward.gold and (a.reward.gold .. " GOLD") or ((a.reward.gems or 0) .. " GEMS")
            UI.drawTextAligned(reward, 262, y + 3, 48, "center", Palette.C.fog)
        end
        UI.setFont("main")
    end
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

function MenuState:drawShopPage()
    local W = Config.BOTTOM_WIDTH
    local shop = Save.getShop()
    local offers = self:getShopOffers()

    UI.drawBentoCard(6, 4, W - 12, 22, {})
    UI.drawText("DAILY SHOP", 14, 7, Palette.C.yellow)
    UI.drawPillButton(W - 122, 5, 56, 16, "CHESTS", "dark", self.pressedBtn == "tab_chests")
    UI.drawPillButton(W - 64, 5, 56, 16, "SHOP", "gold", false)

    for i, offer in ipairs(offers) do
        local x = 6 + (i - 1) * 103
        local bought = shop.bought[i]
        UI.drawBentoCard(x, 30, 99, 150, { accentColor = bought and { 0.35, 0.40, 0.50, 0.8 } or { 1.0, 0.82, 0.20, 0.9 } })
        UI.drawIcon(offer.icon, x + 49, 62, 22)
        UI.setFont("tiny")
        UI.drawTextAligned(offer.label:upper(), x + 4, 88, 91, "center", Palette.C.white)
        UI.setFont("main")
        if offer.kind == "item" then
            UI.drawItemIcon(Items.get(offer.id) and Items.get(offer.id).icon or "bow", x + 49, 120, 14)
        else
            UI.drawTextAligned("x" .. (offer.amount or 1), x + 4, 112, 91, "center", Palette.C.silver)
        end
        if bought then
            UI.drawPillBadge(x + 8, 152, 83, 20, "PURCHASED", { 0.14, 0.17, 0.24, 0.95 }, { 0.30, 0.35, 0.45, 0.8 }, Palette.C.fog, "check")
        else
            local theme = (offer.currency == "gems") and "violet" or "gold"
            UI.drawPillButton(x + 8, 150, 83, 22, offer.price .. ((offer.currency == "gems") and " GEMS" or " GOLD"),
                theme, self.pressedBtn == ("shop_" .. i), offer.currency == "gems" and "gem" or "gold")
        end
    end

    UI.setFont("tiny")
    UI.drawTextAligned("New offers available every day", 6, 186, W - 12, "center", Palette.C.steel)
    UI.setFont("main")
end

-- ============================================================================
-- PAGE : BESTIARY (fiches, éliminations et maîtrise)
-- ============================================================================
function MenuState:drawBestiaryPage()
    local counters = Save.getBestiary()
    local W = Config.BOTTOM_WIDTH
    local t = love.timer.getTime()

    UI.drawBentoCard(6, 4, W - 12, 24, {})
    UI.drawText("BESTIARY", 14, 8, Palette.C.yellow)
    UI.setFont("tiny")
    UI.drawTextAligned("MASTERY: 50 / 200 / 500 KILLS", 14, 10, W - 90, "right", Palette.C.fog)
    UI.setFont("main")
    UI.drawPillButton(W - 68, 5, 60, 20, "BACK", "gray", self.pressedBtn == "bestiary_back")

    -- Monster grid (6 x 3)
    for i, entry in ipairs(Bestiary.ENTRIES) do
        local col = (i - 1) % 6
        local row = math.floor((i - 1) / 6)
        local cx = 5 + col * 52
        local cy = 30 + row * 48
        local kills = counters[entry.type] or 0
        local isSel = (self.bestiarySelected == entry.type)
        local isBoss = (entry.family == "Boss")

        UI.drawBentoCard(cx, cy, 50, 46, { accentColor = isSel and { 1.0, 0.85, 0.25, 0.9 } or (isBoss and { 0.9, 0.25, 0.3, 0.8 } or nil) })
        love.graphics.setColor(1, 1, 1, kills > 0 and 1 or 0.3)
        local frame = Art.frame(entry.type, 1)
        if frame then
            local scale = (frame.h > 26) and 0.5 or 1
            Art.drawEx(entry.type, (math.floor(t * 3) % 2) + 1, cx + 25, cy + 8 + math.min(24, frame.h * scale), 0, scale, scale)
        end
        love.graphics.setColor(1, 1, 1, 1)
        UI.setFont("tiny")
        UI.drawTextAligned(kills > 0 and entry.name:upper() or "???", cx + 1, cy + 32, 48, "center",
            isSel and Palette.C.yellow or Palette.C.silver)
        UI.drawTextAligned(tostring(kills), cx + 1, cy + 39, 48, "center", Palette.C.white)
        UI.setFont("main")

        for tier = 1, 3 do
            local reached = kills >= Bestiary.THRESHOLDS[tier].kills
            Skin.rect(reached and Palette.C.yellow or Palette.C.slate, cx + 17 + (tier - 1) * 6, cy + 2, 4, 3)
        end
    end

    -- Detail card of selected monster
    local entry = Bestiary.entry(self.bestiarySelected) or Bestiary.ENTRIES[1]
    local kills = counters[entry.type] or 0
    UI.drawBentoCard(5, 174, W - 10, 28, { accentColor = { 0.45, 0.75, 1.0, 0.9 } })
    UI.drawText(entry.name:upper(), 12, 176, Palette.C.white)
    UI.setFont("tiny")
    UI.drawTextAligned(string.format("%s | %s | WEAKNESS: %s", entry.family:upper(), entry.attack:upper(), entry.weakness:upper()), 12, 176, W - 24, "right", Palette.C.fog)
    UI.drawTextAligned(entry.desc, 12, 186, W - 24, "left", Palette.C.silver)

    local bonus = Bestiary.bonusFor(kills)
    local nextTier = Bestiary.nextTier(kills)
    local infoText = string.format("MASTERY: +%d%% DAMAGE", math.floor(bonus * 100 + 0.5))
    if nextTier then
        infoText = infoText .. string.format("  (NEXT TIER: %d)", nextTier.kills)
    end
    UI.drawTextAligned(infoText, 12, 194, W - 24, "right", Palette.C.yellow)
    UI.setFont("main")
end

-- ============================================================================
-- ONGLET 2 : HÉROS (BENTO GRID 2026 : ROSTER TOP BAR & DETAIL SPEC TILES)
-- ============================================================================
function MenuState:drawHeroesTab()
    local hList = Heroes.getAll()
    local curPreview = self.selectedHeroPreview or self.saveData.selectedHero or "atreus"
    local hData = Heroes.get(curPreview)
    local isSelected = (self.saveData.selectedHero == curPreview)
    local isUnlocked = self.saveData.unlockedHeroes and self.saveData.unlockedHeroes[curPreview]
    local t = love.timer.getTime()

    -- 1. Grille supérieure des 5 avatars Bento (58px chacun, hauteur 48px)
    for i, h in ipairs(hList) do
        local ax = 6 + (i - 1) * 62
        local ay = 6
        local aw = 58
        local ah = 48
        local isCur = (h.id == curPreview)
        local isAct = (self.saveData.selectedHero == h.id)
        local isUnl = self.saveData.unlockedHeroes and self.saveData.unlockedHeroes[h.id]

        local borderCol = isCur and {1.0, 0.85, 0.25, 1.0} or (isAct and {0.25, 0.85, 0.45, 1.0} or {0.18, 0.23, 0.33, 0.85})
        UI.drawBentoCard(ax, ay, aw, ah, {
            r = 7,
            bg = isCur and {0.12, 0.16, 0.24, 0.98} or {0.08, 0.10, 0.15, 0.95},
            borderColor = borderCol,
            borderWidth = (isCur or isAct) and 1.5 or 1,
            accentColor = isCur and h.color or nil,
        })

        -- Portrait pixel du héros
        love.graphics.setColor(1, 1, 1, isUnl and 1 or 0.4)
        local variant = (h.id ~= "atreus") and h.id or nil
        Art.drawEx("hero_body", 1, ax + aw / 2, ay + 32, 0, 2, 2, false, variant)
        local acc = HeroSprites.ACCESSORY_BY_HERO[h.id]
        if acc and isUnl then
            local offs = { feather = { 3, -14 }, mask = { -2, -8 }, crest = { 0, -15 }, horns = { 0, -13 }, tiara = { 0, -15 } }
            local o = offs[acc]
            Art.drawEx("hero_acc_" .. acc, 1, ax + aw / 2 + o[1] * 2, ay + 32 + o[2] * 2, 0, 2, 2)
        end
        love.graphics.setColor(1, 1, 1, 1)
        if not isUnl then
            UI.drawIcon("lock", ax + aw / 2, ay + 20, 12)
        end

        UI.setFont("tiny")
        local nameCol = isAct and { 0.35, 0.95, 0.55, 1.0 } or (isCur and { 1.0, 0.90, 0.40, 1.0 } or { 0.70, 0.75, 0.85, 1.0 })
        UI.drawTextAligned(h.name:upper(), ax, ay + 37, aw, "center", nameCol)
        UI.setFont("main")
    end

    -- 2. Bento Gauche : Dossier Spécifications du Héros (194x138)
    local cx, cy, cw, ch = 6, 58, 194, 138
    UI.drawBentoCard(cx, cy, cw, ch, {
        r = 8,
        bg = {0.09, 0.11, 0.17, 0.96},
        borderColor = {hData.color[1] * 0.7, hData.color[2] * 0.7, hData.color[3] * 0.7, 0.85},
        accentColor = hData.color,
        isElevated = true,
    })

    -- Nom & Titre
    UI.drawText(string.format("%s - %s", hData.name:upper(), hData.title:upper()), cx + 10, cy + 8, hData.color, {0.05, 0.05, 0.05, 1.0})
    local prevF = love.graphics.getFont()
    love.graphics.setFont(UI.getFont("tiny"))
    UI.drawText(hData.desc, cx + 10, cy + 24, {0.75, 0.80, 0.90, 1.0})
    love.graphics.setFont(prevF)

    -- Encadré Bento du passif unique
    UI.drawBentoCard(cx + 8, cy + 42, cw - 16, 42, {
        r = 6,
        bg = {0.07, 0.09, 0.13, 0.95},
        borderColor = {0.18, 0.24, 0.34, 0.75},
    })
    UI.drawIcon("sparkles", cx + 20, cy + 54, 9, hData.accentColor)
    UI.drawText(hData.passiveName, cx + 32, cy + 46, hData.accentColor)
    love.graphics.setFont(UI.getFont("tiny"))
    UI.setFont("tiny")
    UI.drawTextAligned(hData.passiveDesc, cx + 12, cy + 60, cw - 24, "left", {0.85, 0.90, 0.98, 1.0})
    UI.setFont("main")
    love.graphics.setFont(prevF)

    -- Micro-badges des stats de base du héros
    UI.drawPillBadge(cx + 8, cy + 96, 84, 22, string.format("+%d BASE ATK", hData.baseAtkBonus), {0.20, 0.08, 0.10, 0.9}, {0.80, 0.25, 0.28, 0.85}, {1.0, 0.45, 0.45, 1.0}, "swords")
    UI.drawPillBadge(cx + 100, cy + 96, 84, 22, string.format("+%d MAX HP", hData.baseHpBonus), {0.08, 0.20, 0.12, 0.9}, {0.25, 0.75, 0.40, 0.85}, {0.45, 1.0, 0.65, 1.0}, "heart")

    -- 3. Bento Right: Status & Action Button (108x138)
    UI.drawPillButton(14, 176, 178, 18, "BESTIARY", "violet", self.pressedBtn == "open_bestiary", "hero")

    local bx, by, bw, bh = 206, 58, 108, 138
    UI.drawBentoCard(bx, by, bw, bh, {
        r = 8,
        bg = {0.08, 0.10, 0.15, 0.96},
        borderColor = {0.18, 0.24, 0.34, 0.85},
    })

    if isSelected then
        UI.drawIcon("check", bx + bw / 2, by + 40, 20, {0.25, 0.95, 0.45, 1.0})
        UI.drawTextAligned("EQUIPPED", bx, by + 68, bw, "center", {0.35, 0.95, 0.55, 1.0})
        UI.drawPillBadge(bx + 8, by + 96, bw - 16, 26, "ACTIVE HERO", {0.08, 0.24, 0.14, 0.9}, {0.25, 0.80, 0.45, 0.9}, {0.80, 1.0, 0.88, 1.0})
    elseif isUnlocked then
        UI.drawIcon("hero", bx + bw / 2, by + 40, 18, {0.45, 0.75, 1.0, 1.0})
        UI.drawTextAligned("UNLOCKED", bx, by + 68, bw, "center", {0.70, 0.80, 0.95, 1.0})
        UI.drawPillButton(bx + 8, by + 96, bw - 16, 30, "SELECT", "emerald", self.pressedBtn == "select_hero", "check")
    else
        UI.drawIcon("lock", bx + bw / 2, by + 34, 18, {0.95, 0.80, 0.20, 1.0})
        local costStr = string.format("%d %s", hData.cost, hData.costType:upper())
        UI.drawTextAligned(costStr, bx, by + 58, bw, "center", {1.0, 0.88, 0.30, 1.0})
        local canAfford = (hData.costType == "gold" and self.saveData.gold >= hData.cost) or (hData.costType == "gems" and self.saveData.gems >= hData.cost)
        UI.drawPillButton(bx + 8, by + 96, bw - 16, 30, "UNLOCK", canAfford and "gold" or "gray", self.pressedBtn == "unlock_hero", hData.costType)
    end
end

-- ============================================================================
-- ONGLET 4 : ARBRE DES TALENTS PERMANENTS (SCEAU SACRÉ & RUNES BENTO 2026)
-- ============================================================================
function MenuState:drawTalentsTab()
    local botW = Config.BOTTOM_WIDTH
    local talents = Save.getTalents()
    local totalLevel = (talents.strength or 0) + (talents.vitality or 0) + (talents.recovery or 0) + (talents.agility or 0) + (talents.glory or 0)
    local cost = 80 + totalLevel * 40
    local canUpgrade = (self.saveData.gold >= cost)
    local t = love.timer.getTime()

    -- 1. Bento Top: Sacred Seal & Overview (308x52)
    local hx, hy, hw, hh = 6, 6, 308, 52
    UI.drawBentoCard(hx, hy, hw, hh, {
        r = 8,
        bg = {0.09, 0.11, 0.17, 0.96},
        borderColor = {0.45, 0.20, 0.65, 0.85},
        accentColor = {0.80, 0.35, 1.0, 0.85},
        isElevated = true,
    })

    -- Rotating rune
    love.graphics.push()
    love.graphics.translate(hx + 30, hy + 26)
    love.graphics.rotate(t * 0.8)
    UI.drawIcon("rune", 0, 0, 20, {0.95, 0.50, 1.0, 1.0})
    love.graphics.pop()

    UI.drawText("SACRED TALENT SEAL", hx + 58, hy + 10, {1.0, 0.88, 0.25, 1.0})
    UI.drawPillBadge(hx + 58, hy + 26, 120, 18, string.format("TOTAL LEVEL: %d", totalLevel), {0.18, 0.10, 0.28, 0.9}, {0.70, 0.30, 0.90, 0.9}, {0.95, 0.85, 1.0, 1.0})

    -- 2. 4 Bento Cards (2x2 grid)
    -- Strength (+5 ATK)
    local t1x, t1y, t1w, t1h = 6, 62, 150, 36
    UI.drawBentoCard(t1x, t1y, t1w, t1h, { r = 6, bg = {0.09, 0.11, 0.16, 0.95}, borderColor = {0.45, 0.20, 0.24, 0.8} })
    UI.drawIcon("swords", t1x + 14, t1y + 18, 8, {1.0, 0.45, 0.45, 1.0})
    UI.drawText("STRENGTH (+5 ATK)", t1x + 28, t1y + 6, {1.0, 0.45, 0.45, 1.0})
    local prevF = love.graphics.getFont()
    love.graphics.setFont(UI.getFont("tiny"))
    UI.drawText(string.format("Level %d", talents.strength or 0), t1x + 28, t1y + 20, {0.80, 0.85, 0.95, 1.0})

    -- Vitality (+80 HP)
    local t2x, t2y, t2w, t2h = 164, 62, 150, 36
    UI.drawBentoCard(t2x, t2y, t2w, t2h, { r = 6, bg = {0.09, 0.11, 0.16, 0.95}, borderColor = {0.20, 0.45, 0.28, 0.8} })
    UI.drawIcon("heart", t2x + 14, t2y + 18, 8, {0.45, 1.0, 0.65, 1.0})
    UI.drawText("VITALITY (+80 HP)", t2x + 28, t2y + 6, {0.45, 1.0, 0.65, 1.0})
    UI.drawText(string.format("Level %d", talents.vitality or 0), t2x + 28, t2y + 20, {0.80, 0.85, 0.95, 1.0})

    -- Agility (+1% Dodge)
    local t3x, t3y, t3w, t3h = 6, 102, 150, 36
    UI.drawBentoCard(t3x, t3y, t3w, t3h, { r = 6, bg = {0.09, 0.11, 0.16, 0.95}, borderColor = {0.20, 0.35, 0.55, 0.8} })
    UI.drawIcon("sparkles", t3x + 14, t3y + 18, 8, {0.35, 0.85, 1.0, 1.0})
    UI.drawText("AGILITY (+1% DODGE)", t3x + 28, t3y + 6, {0.40, 0.85, 1.0, 1.0})
    UI.drawText(string.format("Level %d", talents.agility or 0), t3x + 28, t3y + 20, {0.80, 0.85, 0.95, 1.0})

    -- Recovery (+50 Heal)
    local t4x, t4y, t4w, t4h = 164, 102, 150, 36
    UI.drawBentoCard(t4x, t4y, t4w, t4h, { r = 6, bg = {0.09, 0.11, 0.16, 0.95}, borderColor = {0.45, 0.38, 0.18, 0.8} })
    UI.drawIcon("hero", t4x + 14, t4y + 18, 8, {1.0, 0.85, 0.30, 1.0})
    UI.drawText("RECOVERY (+50 HEAL)", t4x + 28, t4y + 6, {1.0, 0.85, 0.30, 1.0})
    UI.drawText(string.format("Level %d", talents.recovery or 0), t4x + 28, t4y + 20, {0.80, 0.85, 0.95, 1.0})
    love.graphics.setFont(prevF)

    -- 3. Bento Bottom: Upgrade action (308x52)
    local ax, ay, aw, ah = 6, 142, 308, 52
    UI.drawBentoCard(ax, ay, aw, ah, {
        r = 8,
        bg = {0.08, 0.10, 0.15, 0.96},
        borderColor = {0.18, 0.23, 0.33, 0.85},
    })

    local btnText = string.format("UPGRADE SEAL  (%d GOLD)", cost)
    UI.drawPillButton(24, 148, 272, 38, btnText, canUpgrade and "violet" or "gray", self.pressedBtn == "upgrade_talent", "rune")

    if self.talentUpgradeTimer and self.talentUpgradeTimer > 0 and self.lastUpgradedTalent then
        UI.drawTextAligned(string.format("TALENT UPGRADED: +1 %s!", self.lastUpgradedTalent:upper()), 0, 188, botW, "center", {0.35, 0.95, 0.55, 1.0})
    end
end

-- ============================================================================
-- ONGLET 5 : COFFRES (BENTO GRID 2026 : MONOLITHES DORÉ & OBSIDIENNE)
-- ============================================================================
function MenuState:drawChestsTab()
    local canGold = (self.saveData.gold >= Balance.COSTS.goldChest)
    local canObs = (self.saveData.gems >= Balance.COSTS.obsidianChest)

    -- 1. MONOLITH 1 : GOLDEN CHEST (150x190)
    local c1x, c1y, c1w, c1h = 6, 6, 150, 190
    UI.drawBentoCard(c1x, c1y, c1w, c1h, {
        r = 8,
        bg = {0.10, 0.12, 0.18, 0.96},
        borderColor = {0.75, 0.55, 0.15, 0.90},
        accentColor = {1.0, 0.82, 0.20, 0.90},
        isElevated = true,
    })

    -- Rarity badge
    UI.drawPillBadge(c1x + 14, c1y + 10, c1w - 28, 18, "COMMON / RARE", {0.25, 0.16, 0.05, 0.9}, {0.85, 0.65, 0.15, 0.9}, {1.0, 0.90, 0.35, 1.0})

    -- Chest sprite
    self:drawChestSprite(c1x + c1w / 2, c1y + 56, "gold", 0)

    -- Titles
    UI.drawTextAligned("GOLDEN CHEST", c1x, c1y + 86, c1w, "center", {1.0, 0.88, 0.25, 1.0})
    local prevF = love.graphics.getFont()
    love.graphics.setFont(UI.getFont("tiny"))
    UI.drawTextAligned("Weapons & Equipment", c1x, c1y + 102, c1w, "center", {0.70, 0.75, 0.85, 1.0})
    love.graphics.setFont(prevF)

    -- Pill button
    UI.drawPillButton(c1x + 12, c1y + 122, c1w - 24, 34, Balance.COSTS.goldChest .. " GOLD", canGold and "gold" or "gray", self.pressedBtn == "open_gold", "gold")

    love.graphics.setFont(UI.getFont("tiny"))
    UI.drawTextAligned("Instant open", c1x, c1y + 164, c1w, "center", {0.50, 0.55, 0.65, 0.8})
    love.graphics.setFont(prevF)

    -- 2. MONOLITH 2 : OBSIDIAN CHEST (150x190)
    local c2x, c2y, c2w, c2h = 164, 6, 150, 190
    UI.drawBentoCard(c2x, c2y, c2w, c2h, {
        r = 8,
        bg = {0.10, 0.12, 0.18, 0.96},
        borderColor = {0.65, 0.25, 0.85, 0.90},
        accentColor = {0.85, 0.35, 1.0, 0.90},
        isElevated = true,
    })

    -- Rarity badge
    UI.drawPillBadge(c2x + 14, c2y + 10, c2w - 28, 18, "EPIC GUARANTEED", {0.20, 0.08, 0.28, 0.9}, {0.75, 0.30, 0.95, 0.9}, {0.95, 0.80, 1.0, 1.0})

    -- Chest sprite
    self:drawChestSprite(c2x + c2w / 2, c2y + 56, "obsidian", 0)

    -- Titles
    UI.drawTextAligned("OBSIDIAN CHEST", c2x, c2y + 86, c2w, "center", {0.90, 0.45, 1.0, 1.0})
    love.graphics.setFont(UI.getFont("tiny"))
    UI.drawTextAligned("Superior Equipment", c2x, c2y + 102, c2w, "center", {0.70, 0.75, 0.85, 1.0})
    love.graphics.setFont(prevF)

    -- Pill button 50 GEMS
    UI.drawPillButton(c2x + 12, c2y + 122, c2w - 24, 34, Balance.COSTS.obsidianChest .. " GEMS", canObs and "violet" or "gray", self.pressedBtn == "open_obsidian", "gem")

    love.graphics.setFont(UI.getFont("tiny"))
    UI.drawTextAligned("High tier gear", c2x, c2y + 164, c2w, "center", {0.50, 0.55, 0.65, 0.8})
    love.graphics.setFont(prevF)
end

-- Rendu soigné d'un sprite de coffre
function MenuState:drawChestSprite(cx, cy, chestType, shake)
    local t = love.timer.getTime()
    local chestPulse = 1.0 + math.sin(t * 3.0 + (chestType == "gold" and 0 or 1.5)) * 0.035
    local auraAlpha = 0.16 + 0.08 * math.sin(t * 3.6 + (chestType == "gold" and 0 or 1.5))

    love.graphics.push()
    love.graphics.translate(cx + shake, cy)
    love.graphics.scale(chestPulse, chestPulse)

    if chestType == "gold" then
        love.graphics.setColor(1.0, 0.85, 0.20, auraAlpha)
    else
        love.graphics.setColor(0.80, 0.30, 1.0, auraAlpha)
    end
    love.graphics.ellipse("fill", 0, 6, 30, 18)

    if chestType == "gold" then
        love.graphics.setColor(0.42, 0.25, 0.12, 1.0)
        love.graphics.rectangle("fill", -24, -14, 48, 30, 4, 4)
        love.graphics.setColor(1.0, 0.82, 0.18, 1.0)
        love.graphics.rectangle("fill", -20, -14, 8, 30)
        love.graphics.rectangle("fill", 12, -14, 8, 30)
        local glint = 0.5 + 0.5 * math.sin(t * 4.5)
        love.graphics.setColor(1, 1, 1, glint * 0.35)
        love.graphics.rectangle("fill", -19, -13, 3, 28)
        love.graphics.rectangle("fill", 13, -13, 3, 28)
        love.graphics.setColor(1.0, 0.85, 0.20, 1.0)
        love.graphics.circle("fill", 0, 2, 4)
        love.graphics.setColor(0.1, 0.1, 0.1, 1.0)
        love.graphics.circle("fill", 0, 2, 1.8)
    else
        love.graphics.setColor(0.24, 0.10, 0.32, 1.0)
        love.graphics.rectangle("fill", -24, -14, 48, 30, 4, 4)
        love.graphics.setColor(0.85, 0.35, 1.0, 1.0)
        love.graphics.polygon("fill", -16, -14, -12, -4, -16, 6, -20, -4)
        love.graphics.polygon("fill", 16, -14, 20, -4, 16, 6, 12, -4)
        local gemGlint = 0.5 + 0.5 * math.sin(t * 4.5 + 1.0)
        love.graphics.setColor(1, 1, 1, gemGlint * 0.45)
        love.graphics.polygon("fill", -15, -12, -13, -4, -15, 4, -18, -4)
        love.graphics.setColor(1.0, 0.45, 1.0, 1.0)
        love.graphics.polygon("fill", 0, -5, 6, 2, 0, 9, -6, 2)
    end

    love.graphics.pop()
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
-- ENTRÉES TACTILES DU HUB (BOTTOM SCREEN 320x240)
-- ============================================================================
function MenuState:touchpressed(id, tx, ty)
    Audio.play("ui_click", 0.05, 0.5)

    -- Onglet Réglages : le panneau reçoit tout l'écran sauf la barre d'onglets
    if self.currentTab == "settings" and ty < 202 and not self.openingChest then
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

    -- 1. Navigation des 5 Onglets Bento Dock Flottant
    if ty >= 200 then
        for _, tab in ipairs(self.tabs) do
            if tx >= tab.x - 3 and tx <= tab.x + tab.w + 3 and ty >= 202 and ty <= 238 then
                self.pressedBtn = "tab_" .. tab.id
                return
            end
        end
    end

    -- 2. Entrées selon l'onglet
    if self.currentTab == "quests" then
        local W = Config.BOTTOM_WIDTH
        -- Bascule Quêtes / Succès
        if ty >= 5 and ty <= 22 then
            if tx >= W - 122 and tx <= W - 66 then
                self.pressedBtn = "tab_quests"
                return
            elseif tx >= W - 64 and tx <= W - 8 then
                self.pressedBtn = "tab_achievements"
                return
            end
        end
        if self.questSubPage == "achievements" then
            for i, a in ipairs(Achievements.LIST) do
                local ay = 28 + (i - 1) * 14
                if tx >= 262 and tx <= 310 and ty >= ay and ty <= ay + 13 then
                    self.pressedBtn = "ach_" .. a.id
                    return
                end
            end
            return
        end
        local q = Save.getDailyQuests()
        local W = Config.BOTTOM_WIDTH
        local barX, barW = 14, W - 28
        for i, tier in ipairs(Quests.TIERS) do
            local px = barX + math.floor(barW * (tier.points / Quests.MAX_POINTS)) - 9
            if tx >= px and tx <= px + 18 and ty >= 37 and ty <= 51 then
                self.pressedBtn = "tier_" .. i
                return
            end
        end
        local dailyList = Save.getDailyQuestList()
        for i, quest in ipairs(dailyList) do
            local qy = 52 + (i - 1) * 29
            if tx >= 252 and tx <= 310 and ty >= qy + 4 and ty <= qy + 24 then
                self.pressedBtn = "quest_" .. quest.id
                return
            end
        end
        -- Missions hebdomadaires
        local weeklyList = Save.getWeeklyQuestList()
        local baseY = 52 + #dailyList * 29 + 2
        for i, quest in ipairs(weeklyList) do
            local qy = baseY + 11 + (i - 1) * 22
            if tx >= 258 and tx <= 310 and ty >= qy + 2 and ty <= qy + 18 then
                self.pressedBtn = "weekly_" .. quest.id
                return
            end
        end
        return

    elseif self.currentTab == "chests" then
        local W = Config.BOTTOM_WIDTH
        if ty >= 5 and ty <= 22 then
            if tx >= W - 122 and tx <= W - 66 then
                self.pressedBtn = "tab_chests"
                return
            elseif tx >= W - 64 and tx <= W - 8 then
                self.pressedBtn = "tab_shop"
                return
            end
        end
        if self.chestSubPage == "shop" then
            for i = 1, 3 do
                local x = 6 + (i - 1) * 103
                if tx >= x + 8 and tx <= x + 91 and ty >= 150 and ty <= 172 then
                    self.pressedBtn = "shop_" .. i
                    return
                end
            end
            return
        end

    elseif self.currentTab == "heroes" and self.heroSubPage == "bestiary" then
        local W = Config.BOTTOM_WIDTH
        if tx >= W - 68 and tx <= W - 8 and ty >= 5 and ty <= 25 then
            self.pressedBtn = "bestiary_back"
            return
        end
        for i, entry in ipairs(Bestiary.ENTRIES) do
            local col = (i - 1) % 6
            local row = math.floor((i - 1) / 6)
            local cx = 5 + col * 52
            local cy = 30 + row * 48
            if tx >= cx and tx <= cx + 50 and ty >= cy and ty <= cy + 46 then
                self.pressedBtn = "bestiary_" .. entry.type
                return
            end
        end
        return

    elseif self.currentTab == "heroes" then
        if tx >= 14 and tx <= 192 and ty >= 176 and ty <= 194 then
            self.pressedBtn = "open_bestiary"
            return
        end
    end

    if self.currentTab == "play" then
        -- Chevrons Carrousel Chapitres
        if (tx >= 140 and tx <= 168 and ty >= 6 and ty <= 32) or (tx >= 6 and tx <= 44 and ty >= 6 and ty <= 40) then
            self.pressedBtn = "chap_prev"
        elseif (tx >= 168 and tx <= 202 and ty >= 6 and ty <= 32) or (tx >= 160 and tx <= 204 and ty >= 6 and ty <= 40) then
            self.pressedBtn = "chap_next"
        -- Modes de jeu (4 cartes empilées)
        elseif tx >= 6 and tx <= 126 and ty >= 100 and ty <= 122 then
            self.pressedBtn = "mode_asc"
        elseif tx >= 6 and tx <= 126 and ty >= 124 and ty <= 146 then
            self.pressedBtn = "mode_inf"
        elseif tx >= 6 and tx <= 126 and ty >= 148 and ty <= 170 then
            self.pressedBtn = "mode_boss"
        elseif tx >= 6 and tx <= 126 and ty <= 198 and ty >= 172 then
            self.pressedBtn = "mode_surv"
        -- Récolte Patrouille AFK
        elseif tx >= 206 and tx <= 316 and ty >= 6 and ty <= 96 then
            self.pressedBtn = "claim_patrol"
        -- Abandon de la course sauvegardée (pastille en haut à droite du bouton Jouer)
        elseif Save.getRun() and tx >= 248 and tx <= 308 and ty >= 106 and ty <= 128 then
            self.pressedBtn = "abandon_run"
        -- Bouton Master Jouer
        elseif tx >= 130 and tx <= 316 and ty >= 100 and ty <= 198 then
            self.pressedBtn = "play"
        end

    elseif self.currentTab == "heroes" then
        -- Clic sur l'un des 5 avatars Bento en haut
        local hList = Heroes.getAll()
        for i, h in ipairs(hList) do
            local ax = 6 + (i - 1) * 62
            if tx >= ax and tx <= ax + 58 and ty >= 6 and ty <= 54 then
                self.selectedHeroPreview = h.id
                return
            end
        end
        -- Bouton d'action droit
        if tx >= 206 and tx <= 316 and ty >= 58 and ty <= 198 then
            local curPreview = self.selectedHeroPreview or "atreus"
            local isUnlocked = self.saveData.unlockedHeroes and self.saveData.unlockedHeroes[curPreview]
            if isUnlocked then
                self.pressedBtn = "select_hero"
            else
                self.pressedBtn = "unlock_hero"
            end
        end

    elseif self.currentTab == "equipment" then
        self.inventory:touchpressed(id, tx, ty)

    elseif self.currentTab == "talents" then
        if tx >= 20 and tx <= 300 and ty >= 136 and ty <= 194 then
            self.pressedBtn = "upgrade_talent"
        end

    elseif self.currentTab == "chests" then
        if tx >= 6 and tx <= 158 and ty >= 6 and ty <= 196 then
            self.pressedBtn = "open_gold"
        elseif tx >= 162 and tx <= 316 and ty >= 6 and ty <= 196 then
            self.pressedBtn = "open_obsidian"
        end
    end
end

function MenuState:touchmoved(id, tx, ty, dx, dy)
    if self.currentTab == "equipment" and not self.openingChest then
        self.inventory:touchmoved(id, tx, ty, dx, dy)
    end
end

function MenuState:touchreleased(id, tx, ty)
    if self.pressedBtn == "settings_panel" then
        self.pressedBtn = nil
        self:handlePanelRequest(self.settingsPanel:touchreleased())
        return
    end

    if self.openingChest then
        if self.pressedBtn == "claim" then
            self.openingChest = nil
            self.rewardItem = nil
            self.particles = {}
            self.inventory:refresh()
        end
        self.pressedBtn = nil
        return
    end

    -- 1. Navigation Onglets
    for _, tab in ipairs(self.tabs) do
        if self.pressedBtn == "tab_" .. tab.id then
            self.currentTab = tab.id
            if tab.id == "equipment" then
                self.inventory:refresh()
            elseif tab.id == "settings" then
                self.settingsPanel:open()
            end
            self.pressedBtn = nil
            return
        end
    end

    -- 2. Actions par onglet
    if self.currentTab == "play" then
        if self.pressedBtn == "chap_prev" then
            local curC = self.saveData.selectedChapter or 1
            Save.setChapter(curC > 1 and (curC - 1) or #self.chapters)
        elseif self.pressedBtn == "chap_next" then
            local curC = self.saveData.selectedChapter or 1
            Save.setChapter(curC < #self.chapters and (curC + 1) or 1)
        elseif self.pressedBtn == "claim_patrol" then
            local claimed = Save.claimPatrol()
            if claimed > 0 then
                self.patrolRewardText = string.format("+%d OR RECOLTE !", claimed)
                self.patrolRewardTimer = 1.6
            end
        elseif self.pressedBtn == "mode_asc" then
            self.selectedMode = "ascension"
        elseif self.pressedBtn == "mode_inf" then
            self.selectedMode = "infinite"
        elseif self.pressedBtn == "mode_boss" then
            self.selectedMode = "boss_rush"
        elseif self.pressedBtn == "mode_surv" then
            self.selectedMode = "survival"
        elseif self.pressedBtn == "play" then
            self:launchGame()
        elseif self.pressedBtn == "abandon_run" then
            local run = Save.getRun()
            if run and (run.gold or 0) > 0 then Save.addGold(run.gold) end
            Save.clearRun()
            Audio.play("ui_cancel", 0, 0.8)
            self.saveData = Save.get()
        end

    elseif self.currentTab == "quests" then
        if self.pressedBtn == "tab_quests" then
            self.questSubPage = "quests"
        elseif self.pressedBtn == "tab_achievements" then
            self.questSubPage = "achievements"
        elseif self.pressedBtn and self.pressedBtn:sub(1, 4) == "ach_" then
            if Save.claimAchievement(self.pressedBtn:sub(5)) then
                Audio.play("ui_confirm", 0, 0.9)
                self.saveData = Save.get()
            end
        elseif self.pressedBtn and self.pressedBtn:sub(1, 7) == "weekly_" then
            if Save.claimWeeklyQuest(self.pressedBtn:sub(8)) then
                Audio.play("ui_confirm", 0, 0.9)
            end
            self.saveData = Save.get()
        elseif self.pressedBtn and self.pressedBtn:sub(1, 6) == "quest_" then
            Save.claimQuest(self.pressedBtn:sub(7))
            self.saveData = Save.get()
        elseif self.pressedBtn and self.pressedBtn:sub(1, 5) == "tier_" then
            Save.claimQuestTier(tonumber(self.pressedBtn:sub(6)))
            self.saveData = Save.get()
        end

    elseif self.currentTab == "heroes" and self.heroSubPage == "bestiary" then
        if self.pressedBtn == "bestiary_back" then
            self.heroSubPage = "roster"
        elseif self.pressedBtn and self.pressedBtn:sub(1, 9) == "bestiary_" then
            self.bestiarySelected = self.pressedBtn:sub(10)
        end

    elseif self.currentTab == "heroes" then
        if self.pressedBtn == "open_bestiary" then
            self.heroSubPage = "bestiary"
        elseif self.pressedBtn == "select_hero" then
            Save.selectHero(self.selectedHeroPreview)
        elseif self.pressedBtn == "unlock_hero" then
            local ok = Save.unlockHero(self.selectedHeroPreview)
            if ok then
                Save.selectHero(self.selectedHeroPreview)
            end
        end

    elseif self.currentTab == "equipment" then
        self.inventory:touchreleased(id, tx, ty)

    elseif self.currentTab == "talents" then
        if self.pressedBtn == "upgrade_talent" then
            local success, chosen, newLvl, cost = Save.upgradeTalent()
            if success then
                self.saveData = Save.get()
                self.lastUpgradedTalent = chosen
                self.talentUpgradeTimer = 1.5
            end
        end

    elseif self.currentTab == "chests" then
        if self.pressedBtn == "tab_chests" then
            self.chestSubPage = "chests"
        elseif self.pressedBtn == "tab_shop" then
            self.chestSubPage = "shop"
        elseif self.pressedBtn and self.pressedBtn:sub(1, 5) == "shop_" then
            local idx = tonumber(self.pressedBtn:sub(6))
            local offers = self:getShopOffers()
            local offer = offers[idx]
            local shop = Save.getShop()
            if offer and not shop.bought[idx] then
                local canBuy = (offer.currency == "gems") and (self.saveData.gems >= offer.price)
                    or (self.saveData.gold >= offer.price)
                if canBuy then
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
                    Save.addQuestProgress("chests", 0)
                    Audio.play("ui_confirm", 0, 0.9)
                    self.saveData = Save.get()
                else
                    Audio.play("ui_cancel", 0, 0.8)
                end
            end
        elseif self.pressedBtn == "open_gold" and self.saveData.gold >= Balance.COSTS.goldChest then
            Save.addGold(-Balance.COSTS.goldChest)
            self:openChest("gold")
        elseif self.pressedBtn == "open_obsidian" and self.saveData.gems >= Balance.COSTS.obsidianChest then
            Save.addGems(-Balance.COSTS.obsidianChest)
            self:openChest("obsidian")
        end
    end

    self.pressedBtn = nil
end

-- Requêtes du panneau de réglages (src/ui/settings_panel.lua)
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
    -- La partie se lance toujours ; l'énergie disponible sert uniquement de bonus d'or.
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

    -- Tirage pondéré par la rareté, plafonné par la progression du joueur :
    -- un objet épique ou légendaire n'apparaît qu'une fois le palier atteint.
    local pickedId = Items.rollDrop(chestType, nil, Balance.maxRarity(self.saveData))
    self.rewardItem = Items.get(pickedId)
    local isNew, msg = Save.addItem(pickedId)
    self.rewardMessage = msg
end

-- Boutons physiques 3DS : A valide, B revient, L/R changent d'onglet, START lance la partie
function MenuState:gamepadpressed(joystick, button)
    local order = {}
    for i, tab in ipairs(self.tabs or {}) do order[i] = tab.id end

    if button == "b" then
        if self.currentTab == "settings" then
            self.currentTab = "play"
        elseif self.questSubPage == "achievements" then
            self.questSubPage = "quests"
        elseif self.heroSubPage == "bestiary" then
            self.heroSubPage = "roster"
        elseif self.chestSubPage == "shop" then
            self.chestSubPage = "chests"
        elseif self.currentTab ~= "play" then
            self.currentTab = "play"
        end
        Audio.play("ui_cancel", 0, 0.7)
        return
    elseif button == "y" then
        if self.currentTab == "settings" then
            self.currentTab = "play"
        else
            self.currentTab = "settings"
            self.settingsPanel:open()
        end
        Audio.play("ui_click", 0.05, 0.7)
        return
    elseif self.currentTab == "settings" and (button ~= "leftshoulder" and button ~= "rightshoulder"
        or self.settingsPanel:isAdminUnlocked()) then
        -- Réglages : la croix, A et (admin débloqué) L/R pilotent le panneau
        self:handlePanelRequest(self.settingsPanel:gamepadpressed(button))
        return
    elseif button == "leftshoulder" or button == "l" or button == "rightshoulder" or button == "r" then
        if #order > 0 then
            local idx = 1
            for i, id in ipairs(order) do if id == self.currentTab then idx = i end end
            local step = (button == "leftshoulder" or button == "l") and -1 or 1
            idx = ((idx - 1 + step) % #order) + 1
            self.currentTab = order[idx]
            if self.currentTab == "equipment" then self.inventory:refresh() end
            Audio.play("ui_click", 0.05, 0.7)
        end
        return
    elseif button == "a" or button == "start" then
        self:keypressed("return")
        return
    end

    self:keypressed(button)
end

function MenuState:keypressed(key)
    if key == "return" or key == "start" or key == "space" then
        if self.currentTab == "play" then
            self:launchGame()
        elseif self.currentTab == "talents" then
            local success, chosen = Save.upgradeTalent()
            if success then
                self.saveData = Save.get()
                self.lastUpgradedTalent = chosen
                self.talentUpgradeTimer = 1.5
            end
        end
    elseif key == "1" then
        self.currentTab = "play"
    elseif key == "2" then
        self.currentTab = "heroes"
    elseif key == "3" then
        self.currentTab = "equipment"
        self.inventory:refresh()
    elseif key == "4" then
        self.currentTab = "talents"
    elseif key == "5" then
        self.currentTab = "chests"
    end
end

return MenuState
