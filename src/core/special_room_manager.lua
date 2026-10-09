-- src/core/special_room_manager.lua
-- Gestionnaire des Salles Spéciales pour Arch3ro (3DS & PC)
-- Implémente le Sanctuaire de l'Ange (Salles 5, 15, 25...), le Démon (Pactes maudits après Boss)
-- et le Marchand Mystérieux avec rendu procédural sur Top Screen et UI tactile Gummy sur Bottom Screen

local Config = require("src.data.config")
local UI = require("src.ui.ui_components")
local Audio = require("src.audio.audio")
local Skills = require("src.data.skills")
local PlayerStats = require("src.data.player_stats")
local VFX = require("src.render.vfx_manager")
local Palette = require("src.render.palette")
local Skin = require("src.ui.skin")
local PixelFont = require("src.ui.pixel_font")
local Art = require("src.render.art")
local Icons = require("src.render.sprites.icons")

local SpecialRoomManager = {}

-- Lucky wheel layout (bottom screen). Labels stay upright and sit between the hub and the
-- icons, so the hub never covers them; icons, pegs and texts are atlas sprites (batched).
local WHEEL = { cx = 160, cy = 114, rad = 78, hub = 12, iconR = 60, labelR = 38 }
local WHEEL_BTN = { x = 30, y = 197, w = 260, h = 40 }
local WHEEL_ICON = { gold = "icon_coin", heart = "icon_heart", swords = "icon_sword", gem = "icon_gem",
    energy = "icon_bolt", star = "icon_star" }
SpecialRoomManager.__index = SpecialRoomManager

-- Pacts the Devil can offer this hero. Dark Multishot is left out once the hero already fires
-- the maximum number of front arrows: the pact would cost 20% of max HP for nothing.
local DEVIL_PACTS = {
    { skillId = "devil_multishot", title = "Dark Multishot +1", desc = "Permanently fire +1 front arrow", icon = "multishot" },
    { skillId = "devil_rage", title = "Demonic Rage", desc = "+35% permanent attack damage", icon = "damage" },
    { skillId = "devil_haste", title = "Infernal Haste", desc = "+25% attack speed and move speed", icon = "speed" },
    { skillId = "devil_ghost", title = "Spectral Form", desc = "Walk through obstacles and walls freely", icon = "shield" },
}

function SpecialRoomManager.devilPacts(player)
    local frontCapped = player and (player.frontArrows or 1) >= PlayerStats.max_front_arrows
    local offers = {}
    for _, pact in ipairs(DEVIL_PACTS) do
        if not (frontCapped and pact.skillId == "devil_multishot") then
            offers[#offers + 1] = pact
        end
    end
    return offers
end

-- Lucky wheel segments (start of run) and boss wheel (after each boss).
-- "boost" multiplies a hero stat by `mult`: the label must show exactly that percentage.
local GOLD, ORANGE, HEAL = { 0.92, 0.70, 0.18 }, { 0.95, 0.52, 0.15 }, { 0.20, 0.82, 0.35 }
local GEM, ATK, SPD, JACKPOT = { 0.22, 0.68, 0.95 }, { 0.90, 0.22, 0.25 }, { 0.85, 0.30, 0.85 }, { 1.0, 0.88, 0.20 }
SpecialRoomManager.WHEELS = {
    normal = {
        { type = "gold", val = 60, label = "+60 GOLD", short = "+60", color = GOLD, icon = "gold" },
        { type = "heal", val = 0.35, label = "+35% HP", short = "+35%", color = HEAL, icon = "heart" },
        { type = "gold", val = 120, label = "+120 GOLD", short = "+120", color = ORANGE, icon = "gold" },
        { type = "boost", stat = "damageMult", mult = 1.30, label = "+30% ATK", short = "+30%", color = ATK, icon = "swords" },
        { type = "gold", val = 80, label = "+80 GOLD", short = "+80", color = GOLD, icon = "gold" },
        { type = "gems", val = 5, label = "+5 GEM", short = "+5", color = GEM, icon = "gem" },
        { type = "boost", stat = "attackSpeedMult", mult = 1.20, label = "+20% SPD", short = "+20%", color = SPD, icon = "energy" },
        { type = "gold", val = 200, label = "JACKPOT", short = "MAX", color = JACKPOT, icon = "star" },
    },
    boss = {
        { type = "gold", val = 300, label = "+300 GOLD", short = "+300", color = GOLD, icon = "gold" },
        { type = "heal", val = 1.0, label = "FULL HEAL", short = "100%", color = HEAL, icon = "heart" },
        { type = "gems", val = 15, label = "+15 GEM", short = "+15", color = GEM, icon = "gem" },
        { type = "boost", stat = "damageMult", mult = 1.50, label = "+50% ATK", short = "+50%", color = ATK, icon = "swords" },
        { type = "gold", val = 500, label = "JACKPOT", short = "MAX", color = JACKPOT, icon = "star" },
        { type = "heal", val = 0.6, label = "+60% HP", short = "+60%", color = HEAL, icon = "heart" },
        { type = "gems", val = 8, label = "+8 GEM", short = "+8", color = GEM, icon = "gem" },
        { type = "boost", stat = "attackSpeedMult", mult = 1.35, label = "+35% SPD", short = "+35%", color = SPD, icon = "energy" },
    },
}

-- Applies a wheel segment to the hero (gold and gems go to `save`).
-- Returns the floating text to show and whether it is highlighted.
function SpecialRoomManager.applyWheelReward(player, r, save)
    if r.type == "gold" then
        save.addGold(r.val)
        return "+" .. r.val .. " GOLD", false
    elseif r.type == "gems" then
        save.addGems(r.val)
        return "+" .. r.val .. " GEM", true
    elseif r.type == "heal" then
        local h = math.floor(player.maxHp * r.val)
        player.hp = math.min(player.maxHp, player.hp + h)
        return "+" .. h .. " HP", false
    elseif r.type == "boost" then
        player[r.stat] = (player[r.stat] or 1.0) * r.mult
        return r.label, true
    end
    return r.label, false
end

function SpecialRoomManager.new()
    local self = setmetatable({}, SpecialRoomManager)
    self.activeType = "none" -- "none", "angel", "devil", "merchant"
    self.isActive = false
    self.isResolved = false
    self.animTime = 0
    self.pressedBtn = nil
    self.hoverCard = nil

    -- Offrandes de l'Ange
    self.angelChoices = {}

    -- Offre du Démon
    self.devilPact = nil

    -- Roue de la Fortune (Lucky Wheel)
    self.wheelAngle = 0
    self.wheelSpeed = 0
    self.isSpinning = false
    self.wheelStopped = false
    self.wheelSegments = {}
    self.spinReward = nil
    self.needleAngle = 0
    self.needleSpark = 0
    self.lastPegIndex = -1
    self.winAnimTimer = 0
    self.winningIndex = nil

    -- Marchand Mystérieux
    self.merchantOffers = {}

    -- Particules d'ambiance pré-allouées (étoiles dorées ou braises)
    self.particles = {}
    for i = 1, 18 do
        table.insert(self.particles, {
            x = 0, y = 0, vx = 0, vy = 0,
            life = 1.0, maxLife = 1.0,
            scale = 1.0, alpha = 1.0,
        })
    end

    return self
end

-- opts.approach : sanctuaire (Ange, Démon), le personnage attend au centre de la salle
-- que le héros s'approche pour ouvrir son offre (voir checkApproach)
function SpecialRoomManager:setup(roomType, player, roomNumber, variant, opts)
    self.activeType = roomType or "angel"
    self.variant = variant
    self.isActive = true
    self.isResolved = false
    self.animTime = 0
    self.pressedBtn = nil
    self.hoverCard = nil
    self.inSanctuary = (opts and opts.approach) or false
    self.waitingApproach = self.inSanctuary

    -- Réinitialisation des particules
    for _, p in ipairs(self.particles) do
        p.x = math.random(-80, 80)
        p.y = math.random(-60, 60)
        p.life = math.random() * 2.0
        p.maxLife = 2.0 + math.random()
        p.vy = (roomType == "devil") and (-math.random(20, 50)) or (math.random(10, 25))
        p.vx = math.random(-15, 15)
        p.scale = 0.6 + math.random() * 0.8
    end

    if self.activeType == "angel" then
        -- 1. SANCTUAIRE DE L'ANGE (2 Choix Tactiles)
        local healAmount = math.floor((player.maxHp or 200) * 0.40)

        -- Choice B: Random Divine Blessing
        local divineBuffs = {
            {
                id = "atk",
                title = "Divine Strength",
                desc = "+18% Raw Damage",
                statText = "+18% ATK",
                color = { 0.95, 0.40, 0.20 },
                apply = function(p)
                    p.damageMult = (p.damageMult or 1.0) + 0.18
                end,
            },
            {
                id = "speed",
                title = "Divine Celerity",
                desc = "+15% Attack Speed",
                statText = "+15% SPEED",
                color = { 0.22, 0.72, 0.95 },
                apply = function(p)
                    p.speed = (p.speed or 130) * 1.15
                end,
            },
            {
                id = "maxhp",
                title = "Sacred Vitality",
                desc = "+25% Max HP & Heal",
                statText = "+25% MAX HP",
                color = { 0.88, 0.32, 0.75 },
                apply = function(p)
                    local bonus = math.floor((p.maxHp or 200) * 0.25)
                    p.maxHp = p.maxHp + bonus
                    p.hp = math.min(p.maxHp, p.hp + bonus)
                end,
            },
            {
                id = "crit",
                title = "Falcon Eye",
                desc = "+15% Critical Chance",
                statText = "+15% CRIT",
                color = { 1.0, 0.82, 0.20 },
                apply = function(p)
                    p.critChance = (p.critChance or 0.05) + 0.15
                end,
            }
        }
        local buff = divineBuffs[math.random(1, #divineBuffs)]

        self.angelChoices = {
            [1] = {
                id = "heal",
                title = "Vital Heal",
                desc = string.format("+%d Instant HP", healAmount),
                statText = "+40% HP",
                healVal = healAmount,
                color = { 0.18, 0.82, 0.40 },
                icon = "heart",
                apply = function(p)
                    p.hp = math.min(p.maxHp, p.hp + healAmount)
                end,
            },
            [2] = {
                id = buff.id,
                title = buff.title,
                desc = buff.desc,
                statText = buff.statText,
                color = buff.color,
                icon = "star",
                apply = buff.apply,
            }
        }

    elseif self.activeType == "devil" then
        -- 2. DEVIL'S PACT (Sacrifice 20% Max HP for Forbidden Power)
        local cost = math.max(15, math.floor((player.maxHp or 200) * 0.20))

        local devilSkills = SpecialRoomManager.devilPacts(player)
        local chosen = devilSkills[math.random(1, #devilSkills)]

        self.devilPact = {
            costHp = cost,
            skillId = chosen.skillId,
            title = chosen.title,
            desc = chosen.desc,
            icon = chosen.icon,
        }

    elseif self.activeType == "wheel" then
        -- 3. LUCKY WHEEL
        self.wheelAngle = 0
        self.wheelSpeed = 0
        self.isSpinning = false
        self.wheelStopped = false
        self.spinReward = nil
        self.needleAngle = 0
        self.needleSpark = 0
        self.lastPegIndex = -1
        self.winAnimTimer = 0
        self.winningIndex = nil
        self.wheelSegments = (variant == "boss") and SpecialRoomManager.WHEELS.boss or SpecialRoomManager.WHEELS.normal

    elseif self.activeType == "merchant" then
        -- 4. MYSTERIOUS MERCHANT
        self.merchantOffers = {
            { id = "potion", name = "Healing Potion", desc = "+50% Instant HP", cost = 70, icon = "heal", bought = false, apply = function(p) p.hp = math.min(p.maxHp, p.hp + math.floor(p.maxHp * 0.5)) end },
            { id = "haste", name = "Swift Tonic", desc = "+15% Attack speed", cost = 90, icon = "speed", bought = false, apply = function(p) p.attackSpeedMult = (p.attackSpeedMult or 1.0) * 1.15 end },
            { id = "strength", name = "Elixir of Might", desc = "+15% Permanent ATK", cost = 120, icon = "damage", bought = false, apply = function(p) p.damageMult = (p.damageMult or 1.0) + 0.15 end },
        }
    end
end

SpecialRoomManager.APPROACH_RADIUS = 40

-- Position du personnage : centre du sanctuaire, ou face à l'entrée sud d'une grande salle
function SpecialRoomManager:npcPosition(mapW, mapH)
    mapW, mapH = mapW or 640, mapH or 480
    if self.inSanctuary then
        return mapW / 2, mapH / 2 - 4
    end
    return mapW / 2, mapH - 148
end

-- Offre affichée : l'écran tactile et les boutons lui reviennent
function SpecialRoomManager:isOfferOpen()
    return self.isActive and not self.waitingApproach
end

-- Ouvre l'offre quand le héros arrive près du personnage ; renvoie true à l'ouverture
function SpecialRoomManager:checkApproach(px, py, mapW, mapH)
    if not (self.isActive and self.waitingApproach) then return false end
    local nx, ny = self:npcPosition(mapW, mapH)
    local dx, dy = px - nx, py - ny
    local r = SpecialRoomManager.APPROACH_RADIUS
    if dx * dx + dy * dy > r * r then return false end
    self.waitingApproach = false
    Audio.play("ui_confirm", 0, 0.8)
    return true
end

function SpecialRoomManager:update(dt)
    if not self.isActive then return end
    self.animTime = self.animTime + dt

    -- Mise à jour des particules d'ambiance
    for _, p in ipairs(self.particles) do
        p.life = p.life - dt
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        if p.life <= 0 then
            p.life = p.maxLife
            p.x = math.random(-70, 70)
            p.y = (self.activeType == "devil") and (math.random(10, 50)) or (math.random(-50, -10))
        end
    end

    -- Rotation physique de la Roue de la Fortune avec friction
    if self.activeType == "wheel" then
        if self.isSpinning then
            local count = #self.wheelSegments
            local segArc = (math.pi * 2) / count
            local topAngle = math.pi * 1.5

            -- Sécurité : si la vitesse est à 0 ou non initialisée alors que isSpinning est vrai
            if not self.wheelSpeed or self.wheelSpeed <= 0 then
                self.wheelSpeed = 30
            end

            self.wheelAngle = (self.wheelAngle + self.wheelSpeed * dt) % (math.pi * 2)
            -- Résistance aérodynamique combinée à la friction mécanique
            self.wheelSpeed = math.max(0, self.wheelSpeed - (self.wheelSpeed * 0.52 + 3.4) * dt)

            -- Détection du passage des picots sous l'aiguille (cliquetis & rebond élastique)
            local curPeg = math.floor(((topAngle - self.wheelAngle) % (math.pi * 2)) / segArc)
            if curPeg ~= self.lastPegIndex then
                self.lastPegIndex = curPeg
                self.needleAngle = 0.34
                self.needleSpark = 1.0
                if self.wheelSpeed < 8 then
                    VFX.shake(1.0, 0.04)
                end
            end

            -- Amortissement dynamique de l'aiguille
            local damp = math.exp(-12.0 * dt)
            self.needleAngle = self.needleAngle * damp
            self.needleSpark = math.max(0, self.needleSpark - dt * 6.0)

            -- Arrêt franc dès que la vitesse devient négligeable (<= 0.05 rad/s)
            if self.wheelSpeed <= 0.05 then
                self.wheelSpeed = 0
                self.isSpinning = false
                self.wheelStopped = true
                self.needleAngle = 0
                local relativeAngle = (topAngle - self.wheelAngle) % (math.pi * 2)
                local segIndex = math.floor(relativeAngle / segArc) + 1
                if segIndex > count then segIndex = 1 end
                self.spinReward = self.wheelSegments[segIndex]
                self.winningIndex = segIndex
                self.winAnimTimer = 0
                VFX.shakeMedium()
            end
        elseif self.wheelStopped then
            self.winAnimTimer = self.winAnimTimer + dt
            local damp = math.exp(-12.0 * dt)
            self.needleAngle = self.needleAngle * damp
            self.needleSpark = math.max(0, self.needleSpark - dt * 6.0)
        end
    end
end

-- ============================================================================
-- RENDU TOP SCREEN (400x240 - SOUS LA CAMÉRA)
-- ============================================================================
function SpecialRoomManager:drawTop(mapW, mapH)
    if not self.isActive then return end
    local Art = require("src.render.art")
    local Palette = require("src.render.palette")
    local PixelFont = require("src.ui.pixel_font")
    local C = Palette.C

    local cx, cy = self:npcPosition(mapW, mapH)
    local t = self.animTime
    local float = math.floor(math.sin(t * 2.2) * 3 + 0.5)

    local SETUP = {
        angel = { sprite = "npc_angel", glow = C.yellow, label = "GUARDIAN ANGEL", labelColor = C.yellow, pedestal = true },
        devil = { sprite = "npc_devil", glow = C.red, label = "DEMON", labelColor = C.red, pedestal = false },
        merchant = { sprite = "npc_merchant", glow = C.cyan, label = "MYSTERIOUS MERCHANT", labelColor = C.cyan, pedestal = false },
        wheel = { sprite = nil, glow = C.amber, label = "LUCKY WHEEL", labelColor = C.amber, pedestal = true },
    }
    local setup = SETUP[self.activeType]
    if not setup then return end

    -- Halo de lumière au sol
    local pulse = (math.sin(t * 2.5) + 1) * 0.5
    for i = 5, 1, -1 do
        local a = 0.05 + pulse * 0.03
        love.graphics.setColor(setup.glow[1], setup.glow[2], setup.glow[3], a)
        love.graphics.ellipse("fill", cx, cy + 20, 18 + i * 9, 7 + i * 3.5)
    end

    -- Piédestal de pierre
    -- Dans un sanctuaire, l'autel (src/render/sanctuary.lua) remplace le piédestal
    if setup.pedestal and not self.inSanctuary then
        love.graphics.setColor(1, 1, 1, 1)
        for i = -1, 1 do
            Art.draw("slab", 2 + (i + 1), cx + i * 16 - 8, cy + 10)
        end
    end

    -- Rayons célestes / infernaux
    for i = 0, 7 do
        local ang = t * 0.5 + i * math.pi / 4
        love.graphics.setColor(setup.glow[1], setup.glow[2], setup.glow[3], 0.05 + pulse * 0.03)
        love.graphics.polygon("fill", cx, cy - 4,
            cx + math.cos(ang - 0.10) * 80, cy - 4 + math.sin(ang - 0.10) * 52,
            cx + math.cos(ang + 0.10) * 80, cy - 4 + math.sin(ang + 0.10) * 52)
    end

    -- Le personnage (ou le totem de la roue)
    love.graphics.setColor(1, 1, 1, 1)
    if setup.sprite then
        Art.drawEx(setup.sprite, 1, cx, cy + 8 - float, 0, 2, 2)
    else
        Art.drawEx("icon_star", 1, cx, cy - 12 - float, t * 0.8, 3, 3)
    end

    -- Particules existantes (poussière d'or / cendres)
    for _, p in ipairs(self.particles) do
        local a = math.max(0, p.life / p.maxLife)
        love.graphics.setColor(setup.glow[1], setup.glow[2], setup.glow[3], a * 0.8)
        love.graphics.rectangle("fill", math.floor(cx + p.x), math.floor(cy + p.y - 10), 2, 2)
    end

    -- Bannière du nom au-dessus
    local label = setup.label
    local w = PixelFont.getWidth(label, "main")
    love.graphics.setColor(C.ink[1], C.ink[2], C.ink[3], 0.75)
    love.graphics.rectangle("fill", cx - w / 2 - 6, cy - 46, w + 12, 14)
    PixelFont.print(label, cx - w / 2, cy - 44, setup.labelColor, "main")
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- RENDU BOTTOM SCREEN (320x240 - INTERFACE TACTILE GUMMY)
-- ============================================================================
-- ============================================================================
-- LUCKY WHEEL (bottom screen)
-- ============================================================================
-- Primitives first (rim, sectors, separators, hub, needle), then every sprite (pegs, icons,
-- labels, button) so the auto-batcher merges them: ~30 GPU calls for the whole screen.
function SpecialRoomManager:drawWheelBottom()
    local C = Palette.C
    local w = WHEEL
    local segs = self.wheelSegments
    local count = #segs
    local segArc = (math.pi * 2) / count
    local cos, sin, floor = math.cos, math.sin, math.floor

    love.graphics.setColor(C.night[1], C.night[2], C.night[3], 1)
    love.graphics.rectangle("fill", 0, 0, 320, 240)

    -- Rim and sectors
    Skin.disc(C.ink, w.cx, w.cy, w.rad + 5)
    Skin.disc(C.amber, w.cx, w.cy, w.rad + 3)
    for i, seg in ipairs(segs) do
        local a1 = self.wheelAngle + (i - 1) * segArc
        love.graphics.setColor(seg.color[1], seg.color[2], seg.color[3], 1)
        love.graphics.arc("fill", "pie", w.cx, w.cy, w.rad, a1, a1 + segArc, 12)
        if self.wheelStopped and self.winningIndex == i then
            local pulse = (math.sin(self.winAnimTimer * 8) + 1) * 0.5
            love.graphics.setColor(1, 1, 1, 0.20 + pulse * 0.25)
            love.graphics.arc("fill", "pie", w.cx, w.cy, w.rad, a1, a1 + segArc, 12)
        end
    end
    love.graphics.setColor(C.ink[1], C.ink[2], C.ink[3], 0.7)
    love.graphics.setLineWidth(2)
    for i = 1, count do
        local a = self.wheelAngle + (i - 1) * segArc
        love.graphics.line(w.cx, w.cy, w.cx + cos(a) * w.rad, w.cy + sin(a) * w.rad)
    end
    love.graphics.setLineWidth(1)

    -- Hub (small, so it never covers the labels)
    Skin.disc(C.ink, w.cx, w.cy, w.hub + 2)
    Skin.disc(C.amber, w.cx, w.cy, w.hub)
    Skin.disc(C.yellow, w.cx, w.cy - 1, w.hub - 5)

    -- Needle with its elastic kick on each peg
    love.graphics.push()
    love.graphics.translate(w.cx, w.cy - w.rad - 6)
    love.graphics.rotate(self.needleAngle or 0)
    love.graphics.setColor(C.ink[1], C.ink[2], C.ink[3], 1)
    love.graphics.polygon("fill", -9, -4, 9, -4, 0, 17)
    love.graphics.setColor(C.red[1], C.red[2], C.red[3], 1)
    love.graphics.polygon("fill", -7, -3, 7, -3, 0, 14)
    Skin.disc(C.yellow, 0, -2, 3)
    love.graphics.pop()

    -- Sprites: pegs, icons (2x) and upright labels
    for i = 1, count do
        local a = self.wheelAngle + (i - 1) * segArc
        Skin.rect(C.yellow, floor(w.cx + cos(a) * (w.rad + 1)) - 1, floor(w.cy + sin(a) * (w.rad + 1)) - 1, 3, 3)
    end
    love.graphics.setColor(1, 1, 1, 1)
    for i, seg in ipairs(segs) do
        local m = self.wheelAngle + (i - 0.5) * segArc
        local icon = WHEEL_ICON[seg.icon]
        if icon then
            Art.drawEx(icon, 1, floor(w.cx + cos(m) * w.iconR), floor(w.cy + sin(m) * w.iconR), 0, 2, 2)
        end
    end
    for i, seg in ipairs(segs) do
        local m = self.wheelAngle + (i - 0.5) * segArc
        local lx, ly = floor(w.cx + cos(m) * w.labelR), floor(w.cy + sin(m) * w.labelR)
        PixelFont.printf(seg.short or seg.label, lx - 20, ly - 6, 40, "center", C.white, "main")
    end

    PixelFont.printf("LUCKY WHEEL", 0, 4, 320, "center", C.yellow, "main")

    -- Action button: spin, spinning, then claim with the reward spelled out
    local b = WHEEL_BTN
    if self.isSpinning then
        Skin.panel(b.x, b.y, b.w, b.h, "raised")
        local dots = string.rep(".", floor(self.animTime * 4) % 4)
        PixelFont.printf("SPINNING" .. dots, b.x, b.y + 13, b.w, "center", C.silver, "main")
        return
    end
    local claim = self.wheelStopped and self.spinReward
    local pressed = (self.pressedBtn == (claim and "wheel_claim" or "wheel_spin"))
    local oy = Skin.button(b.x, b.y, b.w, b.h, claim and "gold" or "green", pressed)
    local label = claim and ("CLAIM " .. self.spinReward.label) or "SPIN  (A)"
    PixelFont.printf(label, b.x, b.y + oy + 9, b.w, "center", C.white, "main", 2)
end

-- ============================================================================
-- OFFER SCREENS (bottom screen): angel, devil, merchant
-- ============================================================================
local ANGEL_CARDS = { { x = 4, y = 38, w = 154, h = 198 }, { x = 162, y = 38, w = 154, h = 198 } }
local DEVIL_CARD = { x = 4, y = 38, w = 312, h = 140 }
local DEVIL_ACCEPT = { x = 4, y = 184, w = 204, h = 50 }
local DEVIL_REFUSE = { x = 212, y = 184, w = 104, h = 50 }
local MERCHANT_CARD_Y, MERCHANT_CARD_W, MERCHANT_CARD_H, MERCHANT_STEP = 38, 101, 140, 105
local MERCHANT_EXIT = { x = 60, y = 186, w = 200, h = 48 }
local OFFER_SPRITES = { heal = "icon_skill_heal", speed = "icon_skill_speed", damage = "icon_skill_damage",
    heart = "icon_heart", star = "icon_star" }

local function inBox(r, x, y)
    return x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h
end

-- Header strip shared by the offer screens
local function drawOfferHeader(title, color, right, rightColor)
    local C = Palette.C
    Skin.panel(4, 4, 312, 30, "dark")
    PixelFont.print(title, 12, 12, color, "main")
    if right then PixelFont.printf(right, 4, 12, 304, "right", rightColor or C.fog, "main") end
end

-- Console button glyph drawn inside a button (round A / B)
local function buttonGlyph(x, y, letter)
    local C = Palette.C
    Skin.disc(C.ink, x + 8, y + 7, 9)
    Skin.disc(C.slate, x + 8, y + 7, 8)
    PixelFont.printf(letter, x + 1, y + 1, 15, "center", C.white, "main")
end

-- Glyph + label centred in a button rectangle (y offset follows the pressed state)
local function buttonLabel(r, letter, label, pressedOffset)
    local w = 22 + PixelFont.getWidth(label, "main")
    local x = math.floor(r.x + (r.w - w) / 2)
    local y = math.floor(r.y + (r.h - 3 - 14) / 2) + pressedOffset
    buttonGlyph(x, y, letter)
    PixelFont.print(label, x + 22, y + 1, Palette.C.white, "main")
end

function SpecialRoomManager:drawAngelBottom()
    local C = Palette.C
    love.graphics.setColor(0.08, 0.12, 0.20, 1)
    love.graphics.rectangle("fill", 0, 0, 320, 240)
    for i, r in ipairs(ANGEL_CARDS) do
        local choice = self.angelChoices[i]
        if choice then
            local theme = (choice.icon == "heart") and "green" or "gold"
            local th = Skin.theme(theme)
            Skin.panel(r.x, r.y, r.w, r.h, "dark")
            Skin.roundRect(th.dark, r.x + 1, r.y + 1, r.w - 2, 17, 2)
            Skin.rect(th.main, r.x + 3, r.y + 1, r.w - 6, 14)
            Skin.disc(th.main, r.x + r.w / 2, r.y + 44, 22, 0.25)
            Skin.button(r.x + 6, r.y + r.h - 46, r.w - 12, 42, theme, self.pressedBtn == ("angel_" .. i))
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    drawOfferHeader("ANGEL SANCTUARY", C.yellow, "CHOOSE ONE", C.silver)
    for i, r in ipairs(ANGEL_CARDS) do
        local choice = self.angelChoices[i]
        if choice then
            local pressed = (self.pressedBtn == ("angel_" .. i)) and 2 or 0
            PixelFont.printf(choice.title, r.x, r.y + 4, r.w, "center", C.white, "main", 1, nil, 1)
            Art.drawEx(OFFER_SPRITES[choice.icon] or "icon_star", 1, r.x + r.w / 2, r.y + 44, 0, 3, 3)
            local statScale = (PixelFont.getWidth(choice.statText, "main", 2) <= r.w - 10) and 2 or 1
            PixelFont.printf(choice.statText, r.x, r.y + (statScale == 2 and 78 or 82), r.w, "center", C.yellow, "main", statScale)
            PixelFont.printf(choice.desc or "", r.x + 6, r.y + 104, r.w - 12, "center", C.silver, "main", 1, nil, 3, 12)
            buttonLabel({ x = r.x + 6, y = r.y + r.h - 46, w = r.w - 12, h = 42 }, i == 1 and "A" or "B", "CLAIM", pressed)
        end
    end
end

function SpecialRoomManager:drawDevilBottom()
    local C = Palette.C
    love.graphics.setColor(0.12, 0.05, 0.06, 1)
    love.graphics.rectangle("fill", 0, 0, 320, 240)
    local pact = self.devilPact
    if not pact then return end
    local r = DEVIL_CARD
    Skin.panel(r.x, r.y, r.w, r.h, "dark")
    Skin.roundRect(C.wine, r.x + 6, r.y + 6, r.w - 12, 24, 3)
    Skin.disc(C.red, r.x + 34, r.y + 76, 20, 0.25)
    Skin.button(DEVIL_ACCEPT.x, DEVIL_ACCEPT.y, DEVIL_ACCEPT.w, DEVIL_ACCEPT.h, "red", self.pressedBtn == "devil_accept")
    Skin.button(DEVIL_REFUSE.x, DEVIL_REFUSE.y, DEVIL_REFUSE.w, DEVIL_REFUSE.h, "gray", self.pressedBtn == "devil_refuse")
    love.graphics.setColor(1, 1, 1, 1)
    drawOfferHeader("DEVIL'S PACT", C.red, "A PRICE IN BLOOD", C.pink)
    Art.draw("icon_heart", 1, r.x + 20, r.y + 18)
    PixelFont.print(string.format("SACRIFICE -%d MAX HP", pact.costHp), r.x + 32, r.y + 12, C.white, "main")
    Art.drawEx(Icons.skillIcon(pact.icon), 1, r.x + 34, r.y + 76, 0, 3, 3)
    PixelFont.printf(pact.title, r.x + 62, r.y + 44, r.w - 70, "left", C.yellow, "main", 1, nil, 1)
    PixelFont.printf(pact.desc or "", r.x + 62, r.y + 62, r.w - 70, "left", C.silver, "main", 1, nil, 5, 12)
    local a, b = DEVIL_ACCEPT, DEVIL_REFUSE
    local pa = (self.pressedBtn == "devil_accept") and 2 or 0
    local pb = (self.pressedBtn == "devil_refuse") and 2 or 0
    buttonLabel(a, "A", "SEAL PACT", pa)
    buttonLabel(b, "B", "NO", pb)
end

function SpecialRoomManager:drawMerchantBottom()
    local C = Palette.C
    love.graphics.setColor(0.08, 0.06, 0.12, 1)
    love.graphics.rectangle("fill", 0, 0, 320, 240)
    local gold = require("src.data.save").get().gold or 0
    for i, offer in ipairs(self.merchantOffers) do
        local x = 4 + (i - 1) * MERCHANT_STEP
        Skin.panel(x, MERCHANT_CARD_Y, MERCHANT_CARD_W, MERCHANT_CARD_H, offer.bought and "dark" or "raised")
        local by = MERCHANT_CARD_Y + MERCHANT_CARD_H - 34
        if offer.bought then
            Skin.panel(x + 5, by, MERCHANT_CARD_W - 10, 30, "dark")
        else
            Skin.button(x + 5, by, MERCHANT_CARD_W - 10, 30, gold >= offer.cost and "gold" or "gray",
                self.pressedBtn == ("merchant_" .. i))
        end
    end
    local e = MERCHANT_EXIT
    Skin.button(e.x, e.y, e.w, e.h, "gray", self.pressedBtn == "merchant_exit")
    love.graphics.setColor(1, 1, 1, 1)
    drawOfferHeader("MERCHANT", C.yellow)
    Art.draw("icon_coin", 1, 252, 18)
    PixelFont.print(tostring(gold), 262, 12, C.yellow, "main")
    for i, offer in ipairs(self.merchantOffers) do
        local x = 4 + (i - 1) * MERCHANT_STEP
        Art.drawEx(OFFER_SPRITES[offer.icon] or "icon_star", 1, x + MERCHANT_CARD_W / 2, MERCHANT_CARD_Y + 18, 0, 2, 2)
        PixelFont.printf(offer.name, x + 4, MERCHANT_CARD_Y + 32, MERCHANT_CARD_W - 8, "center", C.white, "main", 1, nil, 1)
        PixelFont.printf(offer.desc or "", x + 4, MERCHANT_CARD_Y + 50, MERCHANT_CARD_W - 8, "center", C.silver, "main", 1, nil, 4, 12)
        local by = MERCHANT_CARD_Y + MERCHANT_CARD_H - 34
        if offer.bought then
            PixelFont.printf("SOLD", x, by + 9, MERCHANT_CARD_W, "center", C.fog, "main")
        else
            local pressed = (self.pressedBtn == ("merchant_" .. i)) and 2 or 0
            Art.draw("icon_coin", 1, x + 26, by + 14 + pressed)
            PixelFont.print(tostring(offer.cost), x + 36, by + 8 + pressed, C.white, "main")
        end
    end
    local pe = (self.pressedBtn == "merchant_exit") and 2 or 0
    buttonLabel(e, "B", "LEAVE", pe)
end

function SpecialRoomManager:drawBottom()
    if not self.isActive then return end
    if self.activeType == "angel" then
        self:drawAngelBottom()
    elseif self.activeType == "devil" then
        self:drawDevilBottom()
    elseif self.activeType == "wheel" then
        self:drawWheelBottom()
    elseif self.activeType == "merchant" then
        self:drawMerchantBottom()
    end
end

function SpecialRoomManager:touchpressed(id, x, y)
    if not self.isActive or self.isResolved then return end

    if self.activeType == "angel" then
        for i, r in ipairs(ANGEL_CARDS) do
            if inBox(r, x, y) then self.pressedBtn = "angel_" .. i end
        end

    elseif self.activeType == "devil" then
        if inBox(DEVIL_ACCEPT, x, y) then
            self.pressedBtn = "devil_accept"
        elseif inBox(DEVIL_REFUSE, x, y) then
            self.pressedBtn = "devil_refuse"
        end

    elseif self.activeType == "wheel" then
        if not self.isSpinning and not self.wheelStopped then
            local dx = x - WHEEL.cx
            local dy = y - WHEEL.cy
            local reach = WHEEL.rad + 8
            local isWheelTouch = (dx * dx + dy * dy <= reach * reach)
            local isBtnTouch = (y >= WHEEL_BTN.y - 4)
            if isBtnTouch or isWheelTouch then
                self.pressedBtn = "wheel_spin"
            end
        elseif self.isSpinning then
            -- Taper pendant la rotation accélère la décélération pour obtenir le résultat sans attendre
            self.wheelSpeed = math.min(self.wheelSpeed, 3.5)
        elseif self.wheelStopped then
            self.pressedBtn = "wheel_claim"
        end

    elseif self.activeType == "merchant" then
        if inBox(MERCHANT_EXIT, x, y) then
            self.pressedBtn = "merchant_exit"
        elseif y >= MERCHANT_CARD_Y and y <= MERCHANT_CARD_Y + MERCHANT_CARD_H then
            for i = 1, #self.merchantOffers do
                local cx = 4 + (i - 1) * MERCHANT_STEP
                if x >= cx and x <= cx + MERCHANT_CARD_W then self.pressedBtn = "merchant_" .. i end
            end
        end
    end
end

function SpecialRoomManager:touchreleased(id, x, y, player, fctPool, onComplete)
    if not self.isActive or self.isResolved then return end
    local btn = self.pressedBtn
    self.pressedBtn = nil

    if self.activeType == "angel" then
        if btn == "angel_1" and self.angelChoices[1] then
            -- Choix Soin Vital
            local choice = self.angelChoices[1]
            choice.apply(player)
            if fctPool then
                VFX.addFCT(player.x, player.y - 16, choice.healVal, false)
            end
            VFX.shakeLight()
            self.isResolved = true
            self.isActive = false
            if onComplete then onComplete() end

        elseif btn == "angel_2" and self.angelChoices[2] then
            -- Choix Bénédiction Divine
            local choice = self.angelChoices[2]
            choice.apply(player)
            if fctPool then
                VFX.addFCT(player.x, player.y - 16, 777, true) -- Pop FCT critique d'or
            end
            VFX.shakeLight()
            self.isResolved = true
            self.isActive = false
            if onComplete then onComplete() end
        end

    elseif self.activeType == "devil" then
        if btn == "devil_accept" and self.devilPact then
            -- PACTE SCELLÉ : Sacrifice de 20% PV Max
            local pact = self.devilPact
            player.maxHp = math.max(10, (player.maxHp or 200) - pact.costHp)
            player.hp = math.min(player.hp, player.maxHp)

            -- Application du Pouvoir Interdit
            local sk = Skills.get(pact.skillId)
            if sk and sk.hooks and sk.hooks.onApply then
                sk.hooks.onApply(player)
            end

            -- Feedback dramatique rougeoyant
            VFX.shakeHeavy()
            if fctPool then
                VFX.addFCT(player.x, player.y - 16, 666, true) -- Pop démoniaque
            end

            self.isResolved = true
            self.isActive = false
            if onComplete then onComplete() end

        elseif btn == "devil_refuse" then
            -- PACTE REFUSÉ : Départ sain et sauf
            VFX.shakeLight()
            self.isResolved = true
            self.isActive = false
            if onComplete then onComplete() end
        end

    elseif self.activeType == "wheel" then
        if (btn == "wheel_spin" or (not self.isSpinning and not self.wheelStopped)) and not self.isSpinning and not self.wheelStopped then
            self.wheelSpeed = 34 + math.random() * 6
            self.isSpinning = true
            self.lastPegIndex = -1
            self.winningIndex = nil
            VFX.shakeLight()
        elseif (btn == "wheel_claim" or self.wheelStopped) and self.wheelStopped and self.spinReward then
            local text, highlight = SpecialRoomManager.applyWheelReward(player, self.spinReward, require("src.data.save"))
            if fctPool then VFX.addFCT(player.x, player.y - 16, text, highlight) end
            VFX.shakeLight()
            self.isResolved = true
            self.isActive = false
            if onComplete then onComplete() end
        end

    elseif self.activeType == "merchant" then
        if btn == "merchant_exit" then
            VFX.shakeLight()
            self.isResolved = true
            self.isActive = false
            if onComplete then onComplete() end
        elseif btn == "merchant_1" or btn == "merchant_2" or btn == "merchant_3" then
            local idx = (btn == "merchant_1") and 1 or ((btn == "merchant_2") and 2 or 3)
            local offer = self.merchantOffers[idx]
            local Save = require("src.data.save")
            local sData = Save.get()
            if offer and not offer.bought and sData.gold >= offer.cost then
                Save.addGold(-offer.cost)
                offer.bought = true
                offer.apply(player)
                VFX.shakeLight()
                if fctPool then VFX.addFCT(player.x, player.y - 16, offer.name, true) end
            end
        end
    end
end

return SpecialRoomManager
