-- src/core/special_room_manager.lua
-- Gestionnaire des Salles Spéciales pour Arch3ro (3DS & PC)
-- Implémente le Sanctuaire de l'Ange (Salles 5, 15, 25...), le Démon (Pactes maudits après Boss)
-- et le Marchand Mystérieux avec rendu procédural sur Top Screen et UI tactile Gummy sur Bottom Screen

local Config = require("src.data.config")
local UI = require("src.ui.ui_components")
local Audio = require("src.audio.audio")
local Skills = require("src.data.skills")
local VFX = require("src.render.vfx_manager")

local SpecialRoomManager = {}
SpecialRoomManager.__index = SpecialRoomManager

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

function SpecialRoomManager:setup(roomType, player, roomNumber, variant)
    self.activeType = roomType or "angel"
    self.variant = variant
    self.isActive = true
    self.isResolved = false
    self.animTime = 0
    self.pressedBtn = nil
    self.hoverCard = nil

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

        -- Choix B : Bénédiction Divine Aléatoire
        local divineBuffs = {
            {
                id = "atk",
                title = "Force Divine",
                desc = "+18% Dégâts bruts",
                statText = "+18% ATQ",
                color = { 0.95, 0.40, 0.20 },
                apply = function(p)
                    p.damageMult = (p.damageMult or 1.0) + 0.18
                end,
            },
            {
                id = "speed",
                title = "Célérité Divine",
                desc = "+15% Vitesse de tir",
                statText = "+15% VITESSE",
                color = { 0.22, 0.72, 0.95 },
                apply = function(p)
                    p.speed = (p.speed or 130) * 1.15
                end,
            },
            {
                id = "maxhp",
                title = "Vitalité Sacrée",
                desc = "+25% PV Max & Soin",
                statText = "+25% PV MAX",
                color = { 0.88, 0.32, 0.75 },
                apply = function(p)
                    local bonus = math.floor((p.maxHp or 200) * 0.25)
                    p.maxHp = p.maxHp + bonus
                    p.hp = math.min(p.maxHp, p.hp + bonus)
                end,
            },
            {
                id = "crit",
                title = "Oeil du Faucon",
                desc = "+15% Coup Critique",
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
                title = "Soin Vital",
                desc = string.format("+%d PV Immédiats", healAmount),
                statText = "+40% PV",
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
        -- 2. PACTE AVEC LE DIABLE (Sacrifice de 20% PV Max contre Pouvoir Interdit)
        local cost = math.max(15, math.floor((player.maxHp or 200) * 0.20))

        local devilSkills = {
            {
                skillId = "devil_multishot",
                title = "Tir Obscur +1",
                desc = "Tire une flèche frontale supplémentaire permanente",
                icon = "multishot",
            },
            {
                skillId = "devil_rage",
                title = "Fureur Démoniaque",
                desc = "+35% de Dégâts d'attaque permanents",
                icon = "damage",
            },
            {
                skillId = "devil_haste",
                title = "Célérité Infernale",
                desc = "+25% Vitesse de tir et d'esquive",
                icon = "speed",
            },
            {
                skillId = "devil_ghost",
                title = "Forme Spectrale",
                desc = "Permet de traverser rochers et obstacles sans entrave",
                icon = "shield",
            },
        }
        local chosen = devilSkills[math.random(1, #devilSkills)]

        self.devilPact = {
            costHp = cost,
            skillId = chosen.skillId,
            title = chosen.title,
            desc = chosen.desc,
            icon = chosen.icon,
        }

    elseif self.activeType == "wheel" then
        -- 3. LA ROUE DE LA FORTUNE TACTILE (LUCKY WHEEL)
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
        self.wheelSegments = {
            { type = "gold", val = 60, label = "+60 OR", short = "+60", color = {0.92, 0.70, 0.18}, icon = "gold" },
            { type = "heal", val = 0.35, label = "+35% PV", short = "+35%", color = {0.20, 0.82, 0.35}, icon = "heart" },
            { type = "gold", val = 120, label = "+120 OR", short = "+120", color = {0.95, 0.52, 0.15}, icon = "gold" },
            { type = "skill", id = "attack_boost", label = "+30% ATK", short = "+30%", color = {0.90, 0.22, 0.25}, icon = "swords" },
            { type = "gold", val = 80, label = "+80 OR", short = "+80", color = {0.92, 0.70, 0.18}, icon = "gold" },
            { type = "gems", val = 5, label = "+5 GEM", short = "+5", color = {0.22, 0.68, 0.95}, icon = "gem" },
            { type = "skill", id = "speed_boost", label = "+20% VIT", short = "+20%", color = {0.85, 0.30, 0.85}, icon = "energy" },
            { type = "gold", val = 200, label = "JACKPOT", short = "MAX", color = {1.0, 0.88, 0.20}, icon = "star" },
        }

        -- ROUE DE BOSS : récompenses exclusives après un grand boss
        if variant == "boss" then
            self.wheelSegments = {
                { type = "gold", val = 300, label = "+300 OR", short = "+300", color = {0.92, 0.70, 0.18}, icon = "gold" },
                { type = "heal", val = 1.0, label = "SOIN TOTAL", short = "100%", color = {0.20, 0.82, 0.35}, icon = "heart" },
                { type = "gems", val = 15, label = "+15 GEM", short = "+15", color = {0.22, 0.68, 0.95}, icon = "gem" },
                { type = "skill", id = "attack_boost", label = "+50% ATK", short = "+50%", color = {0.90, 0.22, 0.25}, icon = "swords" },
                { type = "gold", val = 500, label = "JACKPOT", short = "MAX", color = {1.0, 0.88, 0.20}, icon = "star" },
                { type = "heal", val = 0.6, label = "+60% PV", short = "+60%", color = {0.20, 0.82, 0.35}, icon = "heart" },
                { type = "gems", val = 8, label = "+8 GEM", short = "+8", color = {0.22, 0.68, 0.95}, icon = "gem" },
                { type = "skill", id = "speed_boost", label = "+35% VIT", short = "+35%", color = {0.85, 0.30, 0.85}, icon = "energy" },
            }
        end

    elseif self.activeType == "merchant" then
        -- 4. LE MARCHAND MYSTÉRIEUX AMBULANT
        self.merchantOffers = {
            { id = "potion", name = "Potion de Soin", desc = "+50% PV immédiat", cost = 70, icon = "heal", bought = false, apply = function(p) p.hp = math.min(p.maxHp, p.hp + math.floor(p.maxHp * 0.5)) end },
            { id = "scroll", name = "Lot de Parchemins", desc = "+3 Parchemins d'arme", cost = 90, icon = "scroll", bought = false, apply = function(p) local s = require("src.data.save"); s.addScrolls("weapon", 3) end },
            { id = "strength", name = "Élixir de Force", desc = "+15% ATK permanente", cost = 120, icon = "damage", bought = false, apply = function(p) p.damageMult = (p.damageMult or 1.0) + 0.15 end },
        }
    end
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

    local cx = (mapW or 640) / 2
    local cy = (mapH or 480) - 148      -- placé face au joueur qui entre par le sud
    local t = self.animTime
    local float = math.floor(math.sin(t * 2.2) * 3 + 0.5)

    local SETUP = {
        angel = { sprite = "npc_angel", glow = C.yellow, label = "ANGE GARDIEN", labelColor = C.yellow, pedestal = true },
        devil = { sprite = "npc_devil", glow = C.red, label = "DÉMON", labelColor = C.red, pedestal = false },
        merchant = { sprite = "npc_merchant", glow = C.cyan, label = "MARCHAND MYSTÉRIEUX", labelColor = C.cyan, pedestal = false },
        wheel = { sprite = nil, glow = C.amber, label = "ROUE DE LA FORTUNE", labelColor = C.amber, pedestal = true },
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
    if setup.pedestal then
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
function SpecialRoomManager:drawBottom()
    if not self.isActive then return end

    if self.activeType == "angel" then
        -- --------------------------------------------------------------------
        -- 1. ÉCRAN DU BAS : CHOIX DE BÉNÉDICTION CÉLESTE
        -- --------------------------------------------------------------------
        -- Fond céleste apaisant avec dégradé doux
        love.graphics.setColor(0.08, 0.12, 0.20, 1.0)
        love.graphics.rectangle("fill", 0, 0, 320, 240)

        -- Bannière supérieure dorée
        love.graphics.setFont(UI.getFont("title"))
        UI.drawTextAligned("SANCTUAIRE DE L'ANGE", 0, 12, 320, "center", {1.0, 0.92, 0.40, 1.0}, {0.04, 0.06, 0.10, 0.9})
        love.graphics.setFont(UI.getFont("small"))
        UI.drawTextAligned("Choisis une grâce sacrée pour ta progression", 0, 32, 320, "center", {0.80, 0.88, 0.98, 1.0}, {0.04, 0.06, 0.10, 0.9})

        -- 2 Grandes Cartes Tactiles Gummy
        local cardW = 136
        local cardH = 160
        local cardY = 58

        for i = 1, 2 do
            local choice = self.angelChoices[i]
            if choice then
                local cardX = (i == 1) and 18 or 166
                local isPressed = (self.pressedBtn == ("angel_" .. i))

                -- Décalage tactile
                local dy = isPressed and 3 or 0

                -- Ombre portée de la carte
                love.graphics.setColor(0.04, 0.06, 0.10, 0.65)
                love.graphics.rectangle("fill", cardX + 2, cardY + 5, cardW, cardH, 10, 10)

                -- Corps bombé de la carte (Gummy UI)
                local baseCol = choice.color or {0.2, 0.6, 0.9}
                love.graphics.setColor(baseCol[1] * 0.45, baseCol[2] * 0.45, baseCol[3] * 0.45, 1.0)
                love.graphics.rectangle("fill", cardX, cardY + dy, cardW, cardH, 10, 10)

                -- Face supérieure
                love.graphics.setColor(baseCol[1], baseCol[2], baseCol[3], 1.0)
                love.graphics.rectangle("fill", cardX + 2, cardY + 2 + dy, cardW - 4, cardH - 6, 8, 8)

                -- Reflet lumineux supérieur
                love.graphics.setColor(1.0, 1.0, 1.0, 0.28)
                love.graphics.rectangle("fill", cardX + 4, cardY + 4 + dy, cardW - 8, 18, 6, 6)

                -- Icône centrale
                local iconY = cardY + 38 + dy
                if choice.icon == "heart" then
                    -- Cœur de soin
                    love.graphics.setColor(1.0, 0.25, 0.35, 1.0)
                    love.graphics.circle("fill", cardX + cardW / 2 - 8, iconY, 11)
                    love.graphics.circle("fill", cardX + cardW / 2 + 8, iconY, 11)
                    love.graphics.polygon("fill", cardX + cardW / 2 - 18, iconY + 3,
                                                 cardX + cardW / 2 + 18, iconY + 3,
                                                 cardX + cardW / 2, iconY + 22)
                else
                    -- Étoile sacrée
                    love.graphics.setColor(1.0, 0.92, 0.25, 1.0)
                    love.graphics.circle("fill", cardX + cardW / 2, iconY + 8, 14)
                    love.graphics.setColor(1.0, 1.0, 1.0, 0.9)
                    love.graphics.circle("fill", cardX + cardW / 2, iconY + 8, 7)
                end

                -- Titre du don
                love.graphics.setFont(UI.getFont("normal"))
                UI.drawTextAligned(choice.title, cardX + 4, cardY + 76 + dy, cardW - 8, "center", {1, 1, 1, 1}, {0.05, 0.08, 0.12, 0.9})

                -- Badge de stat
                love.graphics.setColor(0.08, 0.12, 0.16, 0.70)
                love.graphics.rectangle("fill", cardX + 16, cardY + 98 + dy, cardW - 32, 20, 5, 5)
                love.graphics.setFont(UI.getFont("small"))
                UI.drawTextAligned(choice.statText, cardX + 16, cardY + 102 + dy, cardW - 32, "center", {1.0, 0.95, 0.40, 1.0})

                -- Bouton "RECEVOIR" au bas de la carte
                local btnY = cardY + cardH - 32 + dy
                local btnCol = isPressed and {0.18, 0.55, 0.25} or {0.24, 0.75, 0.35}
                love.graphics.setColor(btnCol[1], btnCol[2], btnCol[3], 1.0)
                love.graphics.rectangle("fill", cardX + 12, btnY, cardW - 24, 24, 6, 6)
                love.graphics.setFont(UI.getFont("small"))
                UI.drawTextAligned("RECEVOIR", cardX + 12, btnY + 5, cardW - 24, "center", {1, 1, 1, 1})
            end
        end

    elseif self.activeType == "devil" then
        -- --------------------------------------------------------------------
        -- 2. ÉCRAN DU BAS : PACTE AVEC LE DIABLE
        -- --------------------------------------------------------------------
        -- Fond sombre infernal avec lueurs de braises
        love.graphics.setColor(0.12, 0.05, 0.06, 1.0)
        love.graphics.rectangle("fill", 0, 0, 320, 240)

        -- En-tête ténébreux
        love.graphics.setFont(UI.getFont("title"))
        UI.drawTextAligned("PACTE AVEC LE DIABLE", 0, 10, 320, "center", {1.0, 0.28, 0.28, 1.0}, {0.15, 0.02, 0.02, 0.9})
        love.graphics.setFont(UI.getFont("small"))
        UI.drawTextAligned("Le pouvoir exige un sacrifice mortel...", 0, 28, 320, "center", {0.95, 0.75, 0.75, 1.0}, {0.15, 0.02, 0.02, 0.9})

        local pact = self.devilPact
        if pact then
            -- Grande Carte Centrale du Pacte Maudit
            local cardX = 24
            local cardY = 48
            local cardW = 272
            local cardH = 118

            -- Ombre et fond de carte obsidienne
            love.graphics.setColor(0.04, 0.02, 0.02, 0.75)
            love.graphics.rectangle("fill", cardX + 3, cardY + 5, cardW, cardH, 10, 10)
            love.graphics.setColor(0.26, 0.08, 0.10, 1.0)
            love.graphics.rectangle("fill", cardX, cardY, cardW, cardH, 10, 10)
            love.graphics.setColor(0.18, 0.05, 0.07, 1.0)
            love.graphics.rectangle("fill", cardX + 2, cardY + 2, cardW - 4, cardH - 4, 8, 8)

            -- Bandeau du Sacrifice de PV Max
            love.graphics.setColor(0.70, 0.10, 0.15, 0.90)
            love.graphics.rectangle("fill", cardX + 8, cardY + 8, cardW - 16, 26, 6, 6)
            love.graphics.setFont(UI.getFont("small"))
            local costStr = string.format("SACRIFICE : -20%% PV MAX (-%d PV)", pact.costHp)
            UI.drawTextAligned(costStr, cardX + 8, cardY + 14, cardW - 16, "center", {1.0, 0.95, 0.95, 1.0})

            -- Pouvoir Interdit Offert
            love.graphics.setFont(UI.getFont("normal"))
            UI.drawTextAligned(pact.title, cardX + 12, cardY + 44, cardW - 24, "center", {1.0, 0.88, 0.35, 1.0})

            love.graphics.setFont(UI.getFont("small"))
            UI.drawTextAligned(pact.desc, cardX + 14, cardY + 68, cardW - 28, "center", {0.90, 0.85, 0.85, 1.0})

            -- 2 BOUTONS TACTILES GUMMY (ACCEPTER vs REFUSER)
            -- Bouton 1 : ACCEPTER LE PACTE (Rouge sang)
            local btn1X = 24
            local btn1Y = 178
            local btn1W = 178
            local btn1H = 46
            local isP1 = (self.pressedBtn == "devil_accept")
            local dy1 = isP1 and 3 or 0

            love.graphics.setColor(0.45, 0.05, 0.08, 1.0)
            love.graphics.rectangle("fill", btn1X, btn1Y + 3, btn1W, btn1H, 8, 8)
            love.graphics.setColor(isP1 and {0.75, 0.12, 0.18} or {0.92, 0.18, 0.24})
            love.graphics.rectangle("fill", btn1X, btn1Y + dy1, btn1W, btn1H - 2, 8, 8)
            love.graphics.setFont(UI.getFont("normal"))
            UI.drawTextAligned("SCELLER LE PACTE", btn1X, btn1Y + 14 + dy1, btn1W, "center", {1, 1, 1, 1})

            -- Bouton 2 : REFUSER (Gris sobre)
            local btn2X = 212
            local btn2Y = 178
            local btn2W = 84
            local btn2H = 46
            local isP2 = (self.pressedBtn == "devil_refuse")
            local dy2 = isP2 and 3 or 0

            love.graphics.setColor(0.14, 0.16, 0.20, 1.0)
            love.graphics.rectangle("fill", btn2X, btn2Y + 3, btn2W, btn2H, 8, 8)
            love.graphics.setColor(isP2 and {0.24, 0.28, 0.35} or {0.35, 0.40, 0.50})
            love.graphics.rectangle("fill", btn2X, btn2Y + dy2, btn2W, btn2H - 2, 8, 8)
            love.graphics.setFont(UI.getFont("small"))
            UI.drawTextAligned("REFUSER", btn2X, btn2Y + 16 + dy2, btn2W, "center", {0.85, 0.90, 0.95, 1.0})
        end

    elseif self.activeType == "wheel" then
        -- --------------------------------------------------------------------
        -- 3. ÉCRAN DU BAS : LA ROUE DE LA FORTUNE TACTILE
        -- --------------------------------------------------------------------
        love.graphics.setColor(0.06, 0.08, 0.14, 1.0)
        love.graphics.rectangle("fill", 0, 0, 320, 240)

        love.graphics.setFont(UI.getFont("title"))
        UI.drawTextAligned("ROUE DE LA FORTUNE", 0, 7, 320, "center", {1.0, 0.88, 0.35, 1.0}, {0.1, 0.05, 0.02, 0.9})
        love.graphics.setFont(UI.getFont("small"))
        UI.drawTextAligned("Tentez votre chance pour débuter la run !", 0, 24, 320, "center", {0.85, 0.90, 0.98, 1.0})

        local cx, cy = 160, 106
        local rad = 66
        local count = #self.wheelSegments
        local segArc = (math.pi * 2) / count

        -- 1. Ombre portée douce
        love.graphics.setColor(0.03, 0.04, 0.06, 0.6)
        love.graphics.circle("fill", cx + 2, cy + 4, rad + 5)

        -- 2. Cerclage extérieur luxueux (biseau métallique & or)
        love.graphics.setColor(0.18, 0.14, 0.10, 1.0)
        love.graphics.circle("fill", cx, cy, rad + 4)
        love.graphics.setColor(0.85, 0.68, 0.22, 1.0)
        love.graphics.setLineWidth(3.0)
        love.graphics.circle("line", cx, cy, rad + 2)
        love.graphics.setLineWidth(1.0)

        -- 3. Secteurs de la roue avec icônes et textes rotatifs
        for i, seg in ipairs(self.wheelSegments) do
            local a1 = self.wheelAngle + (i - 1) * segArc
            local a2 = a1 + segArc
            local midAngle = a1 + segArc * 0.5
            local isWinning = (self.wheelStopped and self.winningIndex == i)

            -- Remplissage couleur du secteur
            love.graphics.setColor(seg.color[1], seg.color[2], seg.color[3], 0.95)
            love.graphics.arc("fill", "pie", cx, cy, rad, a1, a2)

            -- Surbrillance pulsante si secteur gagnant
            if isWinning then
                local winPulse = (math.sin(self.winAnimTimer * 8) + 1) * 0.5
                love.graphics.setColor(1.0, 1.0, 0.60, 0.30 + winPulse * 0.25)
                love.graphics.arc("fill", "pie", cx, cy, rad, a1, a2)
            end

            -- Rayon séparateur doré
            love.graphics.setColor(1.0, 0.90, 0.45, 0.75)
            love.graphics.setLineWidth(1.2)
            love.graphics.line(cx, cy, cx + math.cos(a1) * rad, cy + math.sin(a1) * rad)
            love.graphics.setLineWidth(1.0)

            -- Éléments visuels rotatifs (Icône + Label)
            love.graphics.push()
            love.graphics.translate(cx, cy)
            love.graphics.rotate(midAngle)

            -- Icône vectorielle vers l'extérieur
            if seg.icon then
                UI.drawIcon(seg.icon, 45, 0, 10, {1, 1, 1, 0.95})
            end

            -- Label condensé vers le centre
            local prevFont = love.graphics.getFont()
            love.graphics.setFont(UI.getFont("tiny"))
            local lbl = seg.short or seg.label
            local textW = love.graphics.getFont():getWidth(lbl)
            UI.drawText(lbl, 23 - textW * 0.5, -4, {1, 1, 1, 1}, {0.1, 0.1, 0.1, 0.9})
            love.graphics.setFont(prevFont)

            love.graphics.pop()
        end

        -- 4. Picots métalliques dorés sur le pourtour (Pins)
        for i = 1, count do
            local pegA = self.wheelAngle + (i - 1) * segArc
            local px = cx + math.cos(pegA) * (rad + 1)
            local py = cy + math.sin(pegA) * (rad + 1)

            -- Picot en bronze/or avec éclat
            love.graphics.setColor(0.98, 0.85, 0.30, 1.0)
            love.graphics.circle("fill", px, py, 2.4)
            love.graphics.setColor(1, 1, 1, 0.9)
            love.graphics.circle("fill", px - 0.7, py - 0.7, 0.9)
        end

        -- 5. Bordure extérieure
        love.graphics.setColor(1.0, 0.85, 0.25, 1.0)
        love.graphics.setLineWidth(2.5)
        love.graphics.circle("line", cx, cy, rad)
        love.graphics.setLineWidth(1.0)

        -- 6. Moyeu central rubis / or
        love.graphics.setColor(0.12, 0.14, 0.18, 1.0)
        love.graphics.circle("fill", cx, cy, 18)
        love.graphics.setColor(0.95, 0.80, 0.25, 1.0)
        love.graphics.setLineWidth(2.0)
        love.graphics.circle("line", cx, cy, 18)
        love.graphics.setLineWidth(1.0)
        -- Gemme centrale
        love.graphics.setColor(0.90, 0.25, 0.30, 1.0)
        love.graphics.circle("fill", cx, cy, 10)
        love.graphics.setColor(1.0, 0.85, 0.35, 1.0)
        love.graphics.circle("fill", cx, cy, 4)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.circle("fill", cx - 2, cy - 2, 1.8)

        -- 7. Aiguille indicatrice dynamique (Ticker Needle avec physique élastique)
        local needlePivotX = cx
        local needlePivotY = cy - rad - 5
        love.graphics.push()
        love.graphics.translate(needlePivotX, needlePivotY)
        love.graphics.rotate(self.needleAngle or 0)

        -- Ombre de l'aiguille
        love.graphics.setColor(0.04, 0.04, 0.06, 0.45)
        love.graphics.polygon("fill", -6, -2, 6, -2, 0, 17)

        -- Corps de l'aiguille rouge vif laqué
        love.graphics.setColor(0.96, 0.18, 0.22, 1.0)
        love.graphics.polygon("fill", -7, -3, 7, -3, 0, 16)
        love.graphics.setColor(1.0, 0.85, 0.30, 1.0)
        love.graphics.setLineWidth(1.2)
        love.graphics.polygon("line", -7, -3, 7, -3, 0, 16)
        love.graphics.setLineWidth(1.0)

        -- Vis pivot dorée
        love.graphics.setColor(1.0, 0.88, 0.35, 1.0)
        love.graphics.circle("fill", 0, -2, 3.5)
        love.graphics.setColor(0.20, 0.15, 0.10, 1.0)
        love.graphics.circle("fill", 0, -2, 1.6)

        -- Étincelle lumineuse au contact d'un picot
        if (self.needleSpark or 0) > 0.05 then
            love.graphics.setColor(1.0, 0.95, 0.50, self.needleSpark * 0.9)
            love.graphics.circle("fill", 0, 16, 3.2 * self.needleSpark)
        end

        love.graphics.pop()

        -- 8. Zone interactive basse (Boutons et états)
        if not self.isSpinning and not self.wheelStopped then
            local isP = (self.pressedBtn == "wheel_spin")
            local dy = isP and 3 or 0
            love.graphics.setColor(0.10, 0.42, 0.18, 1.0)
            love.graphics.rectangle("fill", 60, 186 + 3, 200, 42, 8, 8)
            love.graphics.setColor(isP and {0.20, 0.75, 0.32} or {0.28, 0.90, 0.42})
            love.graphics.rectangle("fill", 60, 186 + dy, 200, 40, 8, 8)
            love.graphics.setFont(UI.getFont("normal"))
            UI.drawTextAligned("TOURNER LA ROUE", 60, 196 + dy, 200, "center", {1, 1, 1, 1})
            love.graphics.setFont(UI.getFont("tiny"))
            UI.drawTextAligned("(ou touchez directement la roue)", 0, 228, 320, "center", {0.65, 0.70, 0.80, 0.8})
        elseif self.isSpinning then
            love.graphics.setFont(UI.getFont("normal"))
            local dots = string.rep(".", math.floor(self.animTime * 4) % 4)
            UI.drawTextAligned("La roue tourne" .. dots, 0, 196, 320, "center", {1.0, 0.85, 0.30, 1.0})
        elseif self.wheelStopped and self.spinReward then
            local isP = (self.pressedBtn == "wheel_claim")
            local dy = isP and 3 or 0
            love.graphics.setColor(0.55, 0.40, 0.08, 1.0)
            love.graphics.rectangle("fill", 50, 186 + 3, 220, 42, 8, 8)
            love.graphics.setColor(isP and {0.90, 0.70, 0.18} or {1.0, 0.85, 0.25})
            love.graphics.rectangle("fill", 50, 186 + dy, 220, 40, 8, 8)
            love.graphics.setFont(UI.getFont("normal"))
            local claimTxt = "OBTENU : " .. self.spinReward.label
            UI.drawTextAligned(claimTxt, 50, 196 + dy, 220, "center", {0.12, 0.08, 0.02, 1})
            love.graphics.setFont(UI.getFont("tiny"))
            UI.drawTextAligned("Touchez pour récupérer et combattre !", 0, 228, 320, "center", {0.85, 0.85, 0.60, 0.9})
        end

    elseif self.activeType == "merchant" then
        -- --------------------------------------------------------------------
        -- 4. ÉCRAN DU BAS : LE MARCHAND MYSTÉRIEUX
        -- --------------------------------------------------------------------
        love.graphics.setColor(0.08, 0.06, 0.12, 1.0)
        love.graphics.rectangle("fill", 0, 0, 320, 240)

        love.graphics.setFont(UI.getFont("title"))
        UI.drawTextAligned("MARCHAND MYSTÉRIEUX", 0, 8, 320, "center", {0.95, 0.85, 0.40, 1.0}, {0.1, 0.05, 0.02, 0.9})
        love.graphics.setFont(UI.getFont("small"))
        local sData = require("src.data.save").get()
        local gStr = string.format("Votre solde : %d Or", sData.gold)
        UI.drawTextAligned(gStr, 0, 26, 320, "center", {1.0, 0.90, 0.50, 1.0})

        local cardW = 94
        local cardH = 120
        local startX = 14
        local cardY = 46

        for i, offer in ipairs(self.merchantOffers) do
            local cx = startX + (i - 1) * 100
            local isP = (self.pressedBtn == ("merchant_" .. i))
            local dy = isP and 2 or 0

            love.graphics.setColor(0.04, 0.03, 0.07, 0.7)
            love.graphics.rectangle("fill", cx + 2, cardY + 3, cardW, cardH, 6, 6)
            love.graphics.setColor(0.18, 0.14, 0.25, 1.0)
            love.graphics.rectangle("fill", cx, cardY, cardW, cardH, 6, 6)

            love.graphics.setFont(UI.getFont("small"))
            UI.drawTextAligned(offer.name, cx + 4, cardY + 8, cardW - 8, "center", {1, 0.9, 0.4, 1})
            love.graphics.setFont(UI.getFont("tiny"))
            UI.drawTextAligned(offer.desc, cx + 4, cardY + 38, cardW - 8, "center", {0.85, 0.85, 0.9, 1})

            local btnY = cardY + 76
            local btnH = 34
            if offer.bought then
                love.graphics.setColor(0.15, 0.15, 0.18, 1.0)
                love.graphics.rectangle("fill", cx + 6, btnY, cardW - 12, btnH, 4, 4)
                love.graphics.setFont(UI.getFont("small"))
                UI.drawTextAligned("VENDU", cx + 6, btnY + 10, cardW - 12, "center", {0.5, 0.5, 0.5, 1})
            else
                local canAfford = sData.gold >= offer.cost
                love.graphics.setColor(canAfford and {0.75, 0.55, 0.15} or {0.35, 0.25, 0.25})
                love.graphics.rectangle("fill", cx + 6, btnY + dy, cardW - 12, btnH - 2, 4, 4)
                love.graphics.setFont(UI.getFont("small"))
                UI.drawTextAligned(tostring(offer.cost) .. " OR", cx + 6, btnY + 8 + dy, cardW - 12, "center", {1, 1, 1, 1})
            end
        end

        local isExitP = (self.pressedBtn == "merchant_exit")
        local dyE = isExitP and 2 or 0
        love.graphics.setColor(0.25, 0.28, 0.35, 1.0)
        love.graphics.rectangle("fill", 80, 186 + dyE, 160, 36, 6, 6)
        love.graphics.setFont(UI.getFont("small"))
        UI.drawTextAligned("QUITTER LE MARCHAND", 80, 196 + dyE, 160, "center", {0.95, 0.95, 1, 1})
    end
end

-- ============================================================================
-- GESTION DES INTERACTIONS TACTILES (BOTTOM SCREEN)
-- ============================================================================
function SpecialRoomManager:touchpressed(id, x, y)
    if not self.isActive or self.isResolved then return end

    if self.activeType == "angel" then
        local cardW = 136
        local cardH = 160
        local cardY = 58

        if x >= 18 and x <= 18 + cardW and y >= cardY and y <= cardY + cardH then
            self.pressedBtn = "angel_1"
        elseif x >= 166 and x <= 166 + cardW and y >= cardY and y <= cardY + cardH then
            self.pressedBtn = "angel_2"
        end

    elseif self.activeType == "devil" then
        if x >= 24 and x <= 24 + 178 and y >= 178 and y <= 178 + 46 then
            self.pressedBtn = "devil_accept"
        elseif x >= 212 and x <= 212 + 84 and y >= 178 and y <= 178 + 46 then
            self.pressedBtn = "devil_refuse"
        end

    elseif self.activeType == "wheel" then
        if not self.isSpinning and not self.wheelStopped then
            local cx, cy, rad = 160, 106, 66
            local dx = x - cx
            local dy = y - cy
            local isWheelTouch = (dx * dx + dy * dy <= (rad + 14) * (rad + 14))
            local isBtnTouch = (y >= 170 and y <= 240)
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
        if y >= 180 and y <= 230 and x >= 80 and x <= 240 then
            self.pressedBtn = "merchant_exit"
        elseif y >= 46 and y <= 166 then
            if x >= 14 and x <= 14 + 94 then
                self.pressedBtn = "merchant_1"
            elseif x >= 114 and x <= 114 + 94 then
                self.pressedBtn = "merchant_2"
            elseif x >= 214 and x <= 214 + 94 then
                self.pressedBtn = "merchant_3"
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
            local r = self.spinReward
            local Save = require("src.data.save")
            if r.type == "gold" then
                Save.addGold(r.val)
                if fctPool then VFX.addFCT(player.x, player.y - 16, "+" .. r.val .. " OR", false) end
            elseif r.type == "gems" then
                Save.addGems(r.val)
                if fctPool then VFX.addFCT(player.x, player.y - 16, "+" .. r.val .. " GEM", true) end
            elseif r.type == "heal" then
                local h = math.floor(player.maxHp * r.val)
                player.hp = math.min(player.maxHp, player.hp + h)
                if fctPool then VFX.addFCT(player.x, player.y - 16, "+" .. h .. " PV", false) end
            elseif r.type == "skill" then
                local sk = Skills.get(r.id)
                if sk and sk.hooks and sk.hooks.onApply then
                    sk.hooks.onApply(player)
                end
                if fctPool then VFX.addFCT(player.x, player.y - 16, r.label, true) end
            end
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
