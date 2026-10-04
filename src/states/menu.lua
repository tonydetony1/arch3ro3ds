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

local MenuState = {}
MenuState.__index = MenuState

local MODE_LABELS = { ascension = "Ascension", infinite = "The Abyss", boss_rush = "Boss Rush", survival = "Arena" }
-- Mode card order on the PLAY tab (drawing, touch, d-pad)
local PLAY_MODE_ORDER = { "ascension", "infinite", "boss_rush", "survival" }

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
        local o = HeroSprites.ACCESSORY_OFFSETS[acc]
        Art.drawEx("hero_acc_" .. acc, 1, heroX + o[1] * 3, heroBottom - 9 + o[2] * 3, 0, 3, 3)
    end
    Art.drawEx("bow", 1, heroX + 26, heroBottom - 34, 0.35, 2, 2)

    -- Equipped pets (combat sprites, scale 2): Pet 1 on the left, Pet 2 on the right,
    -- facing the hero
    local petFloat = math.floor(math.sin(t * 4.6) * 3)
    local p1, p2 = self.saveData.equipped.pet1, self.saveData.equipped.pet2
    if p1 then Pet.drawSprite(p1, heroX - 58, heroBottom - 44 + petFloat, t, false, 2) end
    if p2 then Pet.drawSprite(p2, heroX + 58, heroBottom - 44 - petFloat, t, true, 2) end

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
-- TAB: QUESTS (DAILY + BATTLE PASS, WEEKLY, ACHIEVEMENTS)
-- ============================================================================
local QUEST_ICONS = { kills = "skull", rooms = "door", chests = "chest", upgrades = "upgrade", bosses = "swords", gold = "gold" }

-- Subtabs at the top right of the page (same geometry for drawing and touch)
local QUEST_SUBTABS = {
    { id = "quests",       label = "DAILY" },
    { id = "weekly",       label = "WEEKLY" },
    { id = "achievements", label = "ACHIEV." },
}
local CHEST_SUBTABS = {
    { id = "chests", label = "CHESTS" },
    { id = "shop",   label = "SHOP" },
}
local SUBTAB_W, SUBTAB_H, SUBTAB_Y, SUBTAB_GAP = 54, 16, 5, 4

local function subtabX(index, count)
    return Config.BOTTOM_WIDTH - 8 - (count - index + 1) * SUBTAB_W - (count - index) * SUBTAB_GAP
end

function MenuState:drawSubtabs(tabs, current)
    for i, tab in ipairs(tabs) do
        local isActive = (tab.id == current)
        UI.drawPillButton(subtabX(i, #tabs), SUBTAB_Y, SUBTAB_W, SUBTAB_H, tab.label,
            isActive and "gold" or "dark", self.pressedBtn == ("subtab_" .. tab.id))
    end
end

-- Id of the subtab under the touch point (nil if none)
local function subtabAt(tabs, tx, ty)
    if ty < SUBTAB_Y - 2 or ty > SUBTAB_Y + SUBTAB_H + 2 then return nil end
    for i, tab in ipairs(tabs) do
        local x = subtabX(i, #tabs)
        if tx >= x and tx <= x + SUBTAB_W then return tab.id end
    end
    return nil
end

local function rewardLabel(reward)
    local parts = {}
    if reward.gold then parts[#parts + 1] = reward.gold .. " GOLD" end
    if reward.gems then parts[#parts + 1] = reward.gems .. " GEMS" end
    return "+" .. table.concat(parts, " + ")
end

-- Mission rows: same template for daily and weekly
local QUEST_ROW_H, QUEST_ROW_STEP = 27, 29
local QUEST_BTN_X, QUEST_BTN_W = 252, 58

function MenuState:drawQuestRow(quest, saveQuests, y, btnPrefix)
    local W = Config.BOTTOM_WIDTH
    local progress, done, claimed = Quests.state(quest, saveQuests)
    UI.drawBentoCard(6, y, W - 12, QUEST_ROW_H, { accentColor = done and (claimed and { 0.35, 0.40, 0.50, 0.8 } or { 0.25, 0.85, 0.45, 0.9 }) or nil })
    UI.drawIcon(QUEST_ICONS[quest.kind] or "star", 20, y + 13, 11)
    UI.drawText(quest.name, 32, y + 3, claimed and Palette.C.fog or Palette.C.white)

    UI.drawBar(32, y + 16, 216, 8, progress / quest.goal, done and "green" or "blue")
    UI.setFont("tiny")
    UI.drawTextAligned(string.format("%d/%d", progress, quest.goal), 32, y + 17, 216, "center", Palette.C.white)
    UI.drawTextAligned(rewardLabel(quest.reward), 140, y + 5, 108, "right", Palette.C.yellow)
    UI.setFont("main")

    if claimed then
        UI.drawPillBadge(QUEST_BTN_X, y + 5, QUEST_BTN_W, 18, "CLAIMED", { 0.14, 0.17, 0.24, 0.95 }, { 0.30, 0.35, 0.45, 0.8 }, Palette.C.fog, "check")
    elseif done then
        UI.drawPillButton(QUEST_BTN_X, y + 4, QUEST_BTN_W, 20, "CLAIM", "gold", self.pressedBtn == (btnPrefix .. quest.id))
    else
        UI.drawPillBadge(QUEST_BTN_X, y + 5, QUEST_BTN_W, 18, "ACTIVE", { 0.10, 0.12, 0.18, 0.9 }, { 0.22, 0.26, 0.36, 0.8 }, Palette.C.steel)
    end
end

-- Mission whose CLAIM button is under the touch point
local function questRowAt(list, firstY, tx, ty)
    for i, quest in ipairs(list) do
        local qy = firstY + (i - 1) * QUEST_ROW_STEP
        if tx >= QUEST_BTN_X and tx <= QUEST_BTN_X + QUEST_BTN_W and ty >= qy + 2 and ty <= qy + QUEST_ROW_H - 1 then
            return quest
        end
    end
    return nil
end

local DAILY_FIRST_Y, WEEKLY_FIRST_Y = 52, 32

function MenuState:drawQuestsTab()
    local q = Save.getDailyQuests()
    local W = Config.BOTTOM_WIDTH

    UI.drawBentoCard(6, 4, W - 12, 42, {})
    UI.drawText("DAILY QUESTS", 14, 7, Palette.C.yellow)
    self:drawSubtabs(QUEST_SUBTABS, "quests")

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
    for i, quest in ipairs(Save.getDailyQuestList()) do
        self:drawQuestRow(quest, q, DAILY_FIRST_Y + (i - 1) * QUEST_ROW_STEP, "quest_")
    end

    UI.setFont("tiny")
    UI.drawTextAligned("NEW MISSIONS EVERY DAY", 6, 172, W - 12, "center", Palette.C.steel)
    UI.setFont("main")
end

-- ============================================================================
-- PAGE: WEEKLY MISSIONS
-- ============================================================================
function MenuState:drawWeeklyPage()
    local W = Config.BOTTOM_WIDTH
    local weeklyList, w = Save.getWeeklyQuestList()

    UI.drawBentoCard(6, 4, W - 12, 22, {})
    UI.drawText("WEEKLY MISSIONS", 14, 7, Palette.C.cyan)
    self:drawSubtabs(QUEST_SUBTABS, "weekly")

    for i, quest in ipairs(weeklyList) do
        self:drawQuestRow(quest, w, WEEKLY_FIRST_Y + (i - 1) * QUEST_ROW_STEP, "weekly_")
    end

    UI.setFont("tiny")
    UI.drawTextAligned("NEW MISSIONS EVERY MONDAY", 6, 172, W - 12, "center", Palette.C.steel)
    UI.setFont("main")
end

-- ============================================================================
-- PAGE: PERMANENT ACHIEVEMENTS
-- ============================================================================
function MenuState:drawAchievementsPage()
    local W = Config.BOTTOM_WIDTH
    local d = Save.get()

    UI.drawBentoCard(6, 4, W - 12, 22, {})
    UI.drawText("ACHIEVEMENTS", 14, 7, Palette.C.yellow)
    self:drawSubtabs(QUEST_SUBTABS, "achievements")

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
            UI.drawTextAligned(rewardLabel(a.reward):sub(2), 262, y + 3, 48, "center", Palette.C.fog)
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
    self:drawSubtabs(CHEST_SUBTABS, "shop")

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
            local o = HeroSprites.ACCESSORY_OFFSETS[acc]
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
-- TAB 4: PERMANENT TALENTS (SACRED SEAL)
-- The player picks a talent (card or GLORY badge), then buys it with the bottom button.
-- ============================================================================
local TALENT_CARD_W, TALENT_CARD_H = 150, 36
local TALENT_CARD_POS = { { 6, 62 }, { 164, 62 }, { 6, 102 }, { 164, 102 } } -- Talents.LIST order
local GLORY_BADGE = { x = 186, y = 32, w = 116, h = 18 }
local TALENT_BTN = { x = 24, y = 148, w = 272, h = 38 }
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
    local botW = Config.BOTTOM_WIDTH
    local talents = Save.getTalents()
    local cost, totalLevel = Save.getTalentCost()
    local selected = self.selectedTalent
    local canUpgrade = Talents.canUpgrade(selected, talents) and (self.saveData.gold >= cost)
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
    UI.drawPillBadge(hx + 58, hy + 26, 116, 18, string.format("TOTAL LEVEL: %d", totalLevel), {0.18, 0.10, 0.28, 0.9}, {0.70, 0.30, 0.90, 0.9}, {0.95, 0.85, 1.0, 1.0})

    -- Glory: one-time purchase, selectable like a card until owned
    local g = GLORY_BADGE
    if Talents.isMaxed("glory", talents) then
        UI.drawPillBadge(g.x, g.y, g.w, g.h, "GLORY ACTIVE", {0.12, 0.22, 0.16, 0.9}, {0.35, 0.95, 0.55, 0.9}, {0.85, 1.0, 0.90, 1.0}, "check")
    elseif selected == "glory" then
        UI.drawPillBadge(g.x, g.y, g.w, g.h, "GLORY SELECTED", {0.30, 0.22, 0.08, 0.95}, {1.0, 0.85, 0.30, 1.0}, {1.0, 0.92, 0.55, 1.0}, "star")
    else
        UI.drawPillBadge(g.x, g.y, g.w, g.h, "GLORY: LOCKED", {0.18, 0.12, 0.12, 0.9}, {0.65, 0.25, 0.25, 0.8}, {0.95, 0.80, 0.80, 1.0}, "lock")
    end

    -- 2. 4 bento cards (2x2 grid), one per talent of Talents.LIST
    local prevF = love.graphics.getFont()
    for i, talent in ipairs(Talents.LIST) do
        local x, y, w, h = talentCardRect(i)
        local c = talent.color
        local isSel = (selected == talent.id)
        UI.drawBentoCard(x, y, w, h, {
            r = 6,
            bg = isSel and {c[1] * 0.24, c[2] * 0.24, c[3] * 0.24, 0.98} or {0.09, 0.11, 0.16, 0.95},
            borderColor = isSel and {c[1], c[2], c[3], 1.0} or {c[1] * 0.45, c[2] * 0.45, c[3] * 0.45, 0.8},
            borderWidth = isSel and 2 or 1,
        })
        UI.drawIcon(talent.icon, x + 14, y + 18, 8, c)
        UI.drawText(string.format("%s (%s)", talent.name, talent.effect), x + 28, y + 6, c)
        if isSel then UI.drawIcon("check", x + w - 12, y + 18, 7, c) end
        love.graphics.setFont(UI.getFont("tiny"))
        local lvl = talents[talent.id] or 0
        UI.drawText(string.format("Level %d  (%s)", lvl, Talents.totalText(talent, lvl)), x + 28, y + 20, {0.80, 0.85, 0.95, 1.0})
        love.graphics.setFont(prevF)
    end

    -- 3. Bento Bottom: Upgrade action (308x52)
    local ax, ay, aw, ah = 6, 142, 308, 52
    UI.drawBentoCard(ax, ay, aw, ah, {
        r = 8,
        bg = {0.08, 0.10, 0.15, 0.96},
        borderColor = {0.18, 0.23, 0.33, 0.85},
    })

    local selTalent = Talents.get(selected)
    local btnText = selTalent and string.format("UPGRADE %s  (%d GOLD)", selTalent.name, cost) or "SELECT A TALENT"
    local b = TALENT_BTN
    UI.drawPillButton(b.x, b.y, b.w, b.h, btnText, canUpgrade and "violet" or "gray", self.pressedBtn == "upgrade_talent", "rune")

    -- Info line: result of the last purchase, otherwise the Glory effect
    UI.setFont("tiny")
    if self.talentUpgradeTimer and self.talentUpgradeTimer > 0 and self.lastUpgradedTalent then
        local done = Talents.get(self.lastUpgradedTalent)
        UI.drawTextAligned(string.format("TALENT UPGRADED: +1 %s!", done and done.name or self.lastUpgradedTalent:upper()), 0, 188, botW, "center", {0.35, 0.95, 0.55, 1.0})
    elseif self.talentFailTimer and self.talentFailTimer > 0 then
        UI.drawTextAligned(string.format("NOT ENOUGH GOLD: %d NEEDED", cost), 0, 188, botW, "center", {1.0, 0.45, 0.45, 1.0})
    elseif selected == "glory" then
        UI.drawTextAligned("GLORY: " .. Talents.GLORY.desc, 0, 188, botW, "center", {1.0, 0.88, 0.30, 1.0})
    end
    UI.setFont("main")
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
local CHEST_CARD_Y, CHEST_CARD_H, CHEST_CARD_W = 30, 166, 150
local CHEST_CARDS = {
    { id = "gold", x = 6, btn = "open_gold" },
    { id = "obsidian", x = 164, btn = "open_obsidian" },
}

function MenuState:drawChestsTab()
    local W = Config.BOTTOM_WIDTH
    local canGold = (self.saveData.gold >= Balance.COSTS.goldChest)
    local canObs = (self.saveData.gems >= Balance.COSTS.obsidianChest)

    UI.drawBentoCard(6, 4, W - 12, 22, {})
    UI.drawText("CHESTS", 14, 7, Palette.C.yellow)
    self:drawSubtabs(CHEST_SUBTABS, "chests")

    local prevF = love.graphics.getFont()
    local y, w, h = CHEST_CARD_Y, CHEST_CARD_W, CHEST_CARD_H

    -- 1. MONOLITH 1 : GOLDEN CHEST
    local c1x = CHEST_CARDS[1].x
    UI.drawBentoCard(c1x, y, w, h, {
        r = 8,
        bg = {0.10, 0.12, 0.18, 0.96},
        borderColor = {0.75, 0.55, 0.15, 0.90},
        accentColor = {1.0, 0.82, 0.20, 0.90},
        isElevated = true,
    })
    UI.drawPillBadge(c1x + 14, y + 8, w - 28, 18, "COMMON / RARE", {0.25, 0.16, 0.05, 0.9}, {0.85, 0.65, 0.15, 0.9}, {1.0, 0.90, 0.35, 1.0})
    self:drawChestSprite(c1x + w / 2, y + 48, "gold", 0)
    UI.drawTextAligned("GOLDEN CHEST", c1x, y + 74, w, "center", {1.0, 0.88, 0.25, 1.0})
    love.graphics.setFont(UI.getFont("tiny"))
    UI.drawTextAligned("Weapons & Equipment", c1x, y + 88, w, "center", {0.70, 0.75, 0.85, 1.0})
    love.graphics.setFont(prevF)
    UI.drawPillButton(c1x + 12, y + 102, w - 24, 34, Balance.COSTS.goldChest .. " GOLD", canGold and "gold" or "gray", self.pressedBtn == "open_gold", "gold")
    love.graphics.setFont(UI.getFont("tiny"))
    UI.drawTextAligned("Instant open", c1x, y + 144, w, "center", {0.50, 0.55, 0.65, 0.8})
    love.graphics.setFont(prevF)

    -- 2. MONOLITH 2 : OBSIDIAN CHEST
    local c2x = CHEST_CARDS[2].x
    UI.drawBentoCard(c2x, y, w, h, {
        r = 8,
        bg = {0.10, 0.12, 0.18, 0.96},
        borderColor = {0.65, 0.25, 0.85, 0.90},
        accentColor = {0.85, 0.35, 1.0, 0.90},
        isElevated = true,
    })
    UI.drawPillBadge(c2x + 14, y + 8, w - 28, 18, "EPIC GUARANTEED", {0.20, 0.08, 0.28, 0.9}, {0.75, 0.30, 0.95, 0.9}, {0.95, 0.80, 1.0, 1.0})
    self:drawChestSprite(c2x + w / 2, y + 48, "obsidian", 0)
    UI.drawTextAligned("OBSIDIAN CHEST", c2x, y + 74, w, "center", {0.90, 0.45, 1.0, 1.0})
    love.graphics.setFont(UI.getFont("tiny"))
    UI.drawTextAligned("Superior Equipment", c2x, y + 88, w, "center", {0.70, 0.75, 0.85, 1.0})
    love.graphics.setFont(prevF)
    UI.drawPillButton(c2x + 12, y + 102, w - 24, 34, Balance.COSTS.obsidianChest .. " GEMS", canObs and "violet" or "gray", self.pressedBtn == "open_obsidian", "gem")
    love.graphics.setFont(UI.getFont("tiny"))
    UI.drawTextAligned("High tier gear", c2x, y + 144, w, "center", {0.50, 0.55, 0.65, 0.8})
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
-- HUB TOUCH INPUT (BOTTOM SCREEN 320x240)
-- Press records the touched element (self.pressedBtn), release triggers the action.
-- Each tab has its own press (PRESS) and release (RELEASE) handler.
-- ============================================================================
local PRESS, RELEASE = {}, {}

function PRESS.play(self, tx, ty)
    -- Chapter carousel chevrons
    if (tx >= 140 and tx <= 168 and ty >= 6 and ty <= 32) or (tx >= 6 and tx <= 44 and ty >= 6 and ty <= 40) then
        return "chap_prev"
    elseif (tx >= 168 and tx <= 202 and ty >= 6 and ty <= 32) or (tx >= 160 and tx <= 204 and ty >= 6 and ty <= 40) then
        return "chap_next"
    end
    -- Game modes (4 stacked cards, see drawPlayTab)
    if tx >= 6 and tx <= 126 then
        for i, mode in ipairs(PLAY_MODE_ORDER) do
            local my = 100 + (i - 1) * 24
            if ty >= my and ty <= my + 22 then return "mode_" .. mode end
        end
    end
    -- AFK patrol collection
    if tx >= 206 and tx <= 316 and ty >= 6 and ty <= 96 then return "claim_patrol" end
    -- Abandon the saved run (pill at the top right of the Play button)
    if Save.getRun() and tx >= 248 and tx <= 308 and ty >= 106 and ty <= 128 then return "abandon_run" end
    -- Main Play button
    if tx >= 130 and tx <= 316 and ty >= 100 and ty <= 198 then return "play" end
    return nil
end

function PRESS.quests(self, tx, ty)
    local sub = subtabAt(QUEST_SUBTABS, tx, ty)
    if sub then return "subtab_" .. sub end

    if self.questSubPage == "achievements" then
        for i, a in ipairs(Achievements.LIST) do
            local ay = 28 + (i - 1) * 14
            if tx >= 262 and tx <= 310 and ty >= ay and ty <= ay + 13 then return "ach_" .. a.id end
        end
        return nil
    elseif self.questSubPage == "weekly" then
        local quest = questRowAt(Save.getWeeklyQuestList(), WEEKLY_FIRST_Y, tx, ty)
        return quest and ("weekly_" .. quest.id) or nil
    end

    local barX, barW = 14, Config.BOTTOM_WIDTH - 28
    for i, tier in ipairs(Quests.TIERS) do
        local px = barX + math.floor(barW * (tier.points / Quests.MAX_POINTS)) - 9
        if tx >= px and tx <= px + 18 and ty >= 37 and ty <= 51 then return "tier_" .. i end
    end
    local quest = questRowAt(Save.getDailyQuestList(), DAILY_FIRST_Y, tx, ty)
    return quest and ("quest_" .. quest.id) or nil
end

function PRESS.heroes(self, tx, ty)
    local W = Config.BOTTOM_WIDTH
    if self.heroSubPage == "bestiary" then
        if tx >= W - 68 and tx <= W - 8 and ty >= 5 and ty <= 25 then return "bestiary_back" end
        for i, entry in ipairs(Bestiary.ENTRIES) do
            local cx = 5 + ((i - 1) % 6) * 52
            local cy = 30 + math.floor((i - 1) / 6) * 48
            if tx >= cx and tx <= cx + 50 and ty >= cy and ty <= cy + 46 then return "bestiary_" .. entry.type end
        end
        return nil
    end

    if tx >= 14 and tx <= 192 and ty >= 176 and ty <= 194 then return "open_bestiary" end
    -- One of the 5 hero avatars at the top
    for i, h in ipairs(Heroes.getAll()) do
        local ax = 6 + (i - 1) * 62
        if tx >= ax and tx <= ax + 58 and ty >= 6 and ty <= 54 then return "hero_" .. h.id end
    end
    -- Right action button
    if tx >= 206 and tx <= 316 and ty >= 58 and ty <= 198 then
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
    local sub = subtabAt(CHEST_SUBTABS, tx, ty)
    if sub then return "subtab_" .. sub end

    if self.chestSubPage == "shop" then
        for i = 1, 3 do
            local x = 6 + (i - 1) * 103
            if tx >= x + 8 and tx <= x + 91 and ty >= 150 and ty <= 172 then return "shop_" .. i end
        end
        return nil
    end
    for _, card in ipairs(CHEST_CARDS) do
        if tx >= card.x and tx <= card.x + CHEST_CARD_W and ty >= CHEST_CARD_Y and ty <= CHEST_CARD_Y + CHEST_CARD_H then
            return card.btn
        end
    end
    return nil
end

function MenuState:touchpressed(id, tx, ty)
    Audio.play("ui_click", 0.05, 0.5)
    self.pressedBtn = nil

    -- Settings tab: the panel gets the whole screen except the tab bar
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

    -- 1. Tab bar (drawn over the content, takes priority)
    if ty >= 200 then
        for _, tab in ipairs(self.tabs) do
            if tx >= tab.x - 3 and tx <= tab.x + tab.w + 3 and ty >= 202 and ty <= 238 then
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
    elseif tab == "chests" and horizontal then
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
