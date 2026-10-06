-- src/entities/dummy.lua
-- Entité Monstre universelle poolée avec Machine d'États (Idle, Chase, Aim, Attack, Dash)
-- Supporte : Traqueur (Slime/Bat), Tireur Statique (Plante), Tireur d'Élite (Squelette Archer) et Boss (Golem)
-- Hit-stop, Knockback physique et projectiles ennemis poolés (ZÉRO allocation)

local Config = require("src.data.config")
local Monsters = require("src.render.monsters")
local AIController = require("src.core.ai_controller")
local VFX = require("src.render.vfx_manager")
local EliteAffixes = require("src.core.elite_affixes")
local Admin = require("src.data.admin")

local Dummy = {}
Dummy.__index = Dummy

-- Elemental statuses. A freeze never stacks or refreshes (it used to be renewed by every hit,
-- locking a monster, boss included, for as long as the hero kept shooting) and is followed by
-- a short immunity. Burn and poison deal a share of max HP, scaled down on bosses.
local FREEZE_TIME = 1.4
local BOSS_FREEZE_TIME = 0.5
local FREEZE_IMMUNITY = 2.0
local BOSS_DOT_SCALE = 0.25
local FIRE_TIME = 2.4
local FIRE_TICK = 0.35
local FIRE_SHARE = 0.04
local POISON_TICK = 0.60
local POISON_SHARE = 0.05

function Dummy.create(index)
    local self = setmetatable({}, Dummy)
    self.id = index
    self.x = 0
    self.y = 0
    self.radius = 12
    self.speed = 45
    self.maxHp = 60
    self.hp = 60
    self.hitFlash = 0
    self.wobble = 0
    self.type = "slime"
    self.isBoss = false

    -- Machine d'États
    self.aiState = "idle"
    self.stateTimer = 0
    self.cooldown = 0
    self.aimTimer = 0
    self.isDashing = false
    self.dashVx = 0
    self.dashVy = 0
    self.targetDirX = 0
    self.targetDirY = 0
    self.targetX = 0
    self.targetY = 0
    self.didHitPlayer = false
    self.isBurrowed = false
    self.aimLocked = false
    self.telegraphActive = false
    self.hasFired = false

    -- Feedbacks : Hit-stop & Knockback
    self.knockX = 0
    self.knockY = 0
    self.hitStop = 0

    return self
end

function Dummy:spawn(x, y, hp, monsterType)
    self.x = x or 200
    self.y = y or 80
    self.type = monsterType or "slime"
    self.isBoss = false
    self.isEnraged = false
    self.darkMark = 0
    self.enrageFlash = 0
    self.attackRateMult = 1.0
    EliteAffixes.reset(self)
    self.isBurrowed = false
    self.aimLocked = false
    self.telegraphActive = false
    self.hasFired = false

    if self.type == "golem" then
        self.radius = 20
        self.speed = 26
        self.maxHp = hp or 220
        self.aiState = "chase"
    elseif self.type == "bat" then
        self.radius = 10
        self.speed = 64
        self.maxHp = hp or 45
        self.aiState = "chase"
    elseif self.type == "wolf" then
        self.radius = 12
        self.speed = 52
        self.maxHp = hp or 70
        self.aiState = "stalk"
    elseif self.type == "skeleton" then
        self.radius = 11
        self.speed = 42
        self.maxHp = hp or 55
        self.aiState = "idle"
    elseif self.type == "plant" then
        self.radius = 12
        self.speed = 0
        self.maxHp = hp or 65
        self.aiState = "idle"
    elseif self.type == "bomber" then
        self.radius = 12
        self.speed = 38
        self.maxHp = hp or 60
        self.aiState = "chase"
    elseif self.type == "burrower" then
        self.radius = 11
        self.speed = 46
        self.maxHp = hp or 75
        self.aiState = "burrowed"
        self.isBurrowed = true
        self.stateTimer = 1.8
    elseif self.type == "splitter" then
        self.radius = 18
        self.speed = 32
        self.maxHp = hp or 115
        self.aiState = "chase"
    elseif self.type == "mini_slime" then
        self.radius = 7.5
        self.speed = 70
        self.maxHp = hp or 30
        self.aiState = "chase"
    elseif self.type == "summoner" then
        self.radius = 12
        self.speed = 34
        self.maxHp = hp or 80
        self.aiState = "idle"
    elseif self.type == "turret" then
        self.radius = 11
        self.speed = 0
        self.maxHp = hp or 90
        self.aiState = "idle"
    elseif self.type == "mage" then
        self.radius = 11
        self.speed = 40
        self.maxHp = hp or 70
        self.aiState = "idle"
        self.blinkTimer = 2.0
    elseif self.type == "skeleton_king" then
        self.radius = 22
        self.speed = 30
        self.maxHp = hp or 900
        self.aiState = "idle"
    elseif self.type == "witch" then
        self.radius = 18
        self.speed = 38
        self.maxHp = hp or 820
        self.aiState = "idle"
        self.blinkTimer = 1.6
    elseif self.type == "lava_titan" then
        self.radius = 22
        self.speed = 24
        self.maxHp = hp or 1100
        self.aiState = "chase"
    elseif self.type == "raven" then
        -- Rapace des cimes : volant rapide et fragile
        self.radius = 10
        self.speed = 88
        self.maxHp = hp or 42
        self.aiState = "chase"
    elseif self.type == "wisp" then
        -- Feu follet : lévite et crache des orbes comme la plante
        self.radius = 9
        self.speed = 30
        self.maxHp = hp or 34
        self.aiState = "idle"
    elseif self.type == "gargoyle" then
        -- Gargouille : chargeur de pierre, lent mais résistant
        self.radius = 15
        self.speed = 42
        self.maxHp = hp or 120
        self.aiState = "chase"
    elseif self.type == "frost_wraith" then
        -- Spectre givré : mage clignotant
        self.radius = 13
        self.speed = 40
        self.maxHp = hp or 95
        self.aiState = "idle"
        self.blinkTimer = 1.4
    elseif self.type == "storm_drake" then
        -- Boss des Îles Célestes
        self.radius = 21
        self.speed = 30
        self.maxHp = hp or 1400
        self.aiState = "chase"
    elseif self.type == "void_watcher" then
        -- Boss de la Cité du Vide
        self.radius = 22
        self.speed = 26
        self.maxHp = hp or 1800
        self.aiState = "idle"
        self.blinkTimer = 1.8
    else -- slime standard
        self.radius = 12
        self.speed = 44
        self.maxHp = hp or 60
        self.aiState = "chase"
    end

    self.hp = self.maxHp
    self.hitFlash = 0
    self.wobble = 0

    self.stateTimer = self.stateTimer or (math.random() * 0.4)
    self.cooldown = 0.6 + math.random() * 0.8
    self.aimTimer = 0
    self.isDashing = false
    self.dashVx = 0
    self.dashVy = 0
    self.targetDirX = 0
    self.targetDirY = 0
    self.targetX = self.x
    self.targetY = self.y
    self.didHitPlayer = false
    self.knockX = 0
    self.knockY = 0
    self.hitStop = 0

    self.status = {
        fire = 0,
        fireTimer = 0,
        poison = 0,
        poisonTimer = 0,
        freeze = 0,
        freezeImmune = 0,
    }
end

-- Réception des dégâts avec vérification d'invulnérabilité sous terre
function Dummy:takeDamage(dmg, hitDirX, hitDirY, elements)
    if not AIController.canTakeDamage(self) then
        return false -- Invincible quand sous terre
    end

    -- Élite : le bouclier absorbe d'abord ; tout coup interrompt la régénération
    if self.elite then
        dmg = EliteAffixes.absorb(self, dmg)
        EliteAffixes.onHit(self)
    end
    -- Panneau admin : HERO DAMAGE et ONE-HIT KILLS
    dmg = dmg * Admin.get("playerDmgMult")
    if Admin.get("oneHit") and dmg > 0 then dmg = math.max(dmg, self.hp) end

    self.hp = self.hp - dmg
    self.hitFlash = 1.0 -- Flash blanc
    VFX.triggerHitFlash(self, 3)
    self.wobble = 0.35  -- Déformation d'impact

    -- Application des effets élémentaires
    -- (a hit only renews the duration: resetting the tick timer too would stop the damage
    -- over time from ever ticking while the target is shot faster than the tick rate)
    local status = self.status
    if elements and status then
        if elements.fire then
            if status.fire <= 0 then status.fireTimer = 0 end
            status.fire = FIRE_TIME
        end
        if elements.poison then
            if status.poison <= 0 then status.poisonTimer = 0 end
            status.poison = 999.0 -- Poison permanent
        end
        if elements.ice and status.freeze <= 0 and (status.freezeImmune or 0) <= 0 then
            status.freeze = self.isBoss and BOSS_FREEZE_TIME or FREEZE_TIME
        end
    end

    -- Hit-stop : fige l'animation et les mouvements pendant 1 frame (~0.025s)
    self.hitStop = 0.025

    -- Knockback : recul physique réactif
    if hitDirX and hitDirY then
        local kForce = (self.type == "golem" or self.type == "splitter") and 5 or 14
        self.knockX = hitDirX * kForce
        self.knockY = hitDirY * kForce
    end

    return (self.hp <= 0)
end

-- Mise à jour principale déléguée à AIController
function Dummy:update(dt, player, projectilePool, obstacleManager, dummyPool, fctPool, mapW, mapH)
    if (self.darkMark or 0) > 0 then self.darkMark = math.max(0, self.darkMark - dt) end
    if self.elite and EliteAffixes.update(self, dt) == "enraged" then
        VFX.addFCT(self.x, self.y - 24, "ENRAGED!", true)
        VFX.addSparks(self.x, self.y, 10, { 1.0, 0.25, 0.2, 1.0 })
        VFX.triggerHitFlash(self, 4)
    end
    -- Décrémentation du compteur de frames exactes du Hit-Flash (3 frames)
    VFX.updateEntity(self)

    -- 1. Gestion du Hit-stop
    local isHitStopped = false
    if self.hitStop > 0 then
        self.hitStop = self.hitStop - dt
        isHitStopped = true
    end

    -- 2. Amortissement des feedbacks visuels et du knockback
    if self.hitFlash > 0 then
        self.hitFlash = math.max(0, self.hitFlash - dt * 8)
    end
    if self.wobble > 0 then
        self.wobble = math.max(0, self.wobble - dt * 4)
    end
    if self.knockX ~= 0 or self.knockY ~= 0 then
        self.knockX = self.knockX * math.max(0, 1.0 - dt * 14)
        self.knockY = self.knockY * math.max(0, 1.0 - dt * 14)
        if math.abs(self.knockX) < 0.2 then self.knockX = 0 end
        if math.abs(self.knockY) < 0.2 then self.knockY = 0 end
    end

    -- 3. Gestion des statuts élémentaires (Feu, Poison, Glace)
    local frozen = false
    if self.status then
        local status = self.status
        local dotScale = self.isBoss and BOSS_DOT_SCALE or 1

        -- Glace / Gel : immobilise totalement le monstre, puis courte immunité
        if status.freeze > 0 then
            frozen = true
            status.freeze = status.freeze - dt
            if status.freeze <= 0 then
                status.freeze = 0
                status.freezeImmune = FREEZE_IMMUNITY
            end
        elseif (status.freezeImmune or 0) > 0 then
            status.freezeImmune = status.freezeImmune - dt
        end

        -- Feu : DoT continu rapide
        if status.fire > 0 then
            status.fire = status.fire - dt
            status.fireTimer = status.fireTimer + dt
            if status.fireTimer >= FIRE_TICK then
                status.fireTimer = 0
                local dot = math.max(3, math.floor(self.maxHp * FIRE_SHARE * dotScale))
                self.hp = self.hp - dot
                VFX.addFCT(self.x, self.y - 14, dot, false)
                VFX.addSparks(self.x, self.y, 3, {1.0, 0.4, 0.1, 1.0})
            end
        end

        -- Poison : DoT régulier permanent
        if status.poison > 0 then
            status.poisonTimer = status.poisonTimer + dt
            if status.poisonTimer >= POISON_TICK then
                status.poisonTimer = 0
                local dot = math.max(4, math.floor(self.maxHp * POISON_SHARE * dotScale))
                self.hp = self.hp - dot
                VFX.addFCT(self.x, self.y - 14, dot, false)
                VFX.addSparks(self.x, self.y, 3, {0.2, 0.9, 0.3, 1.0})
            end
        end
    end

    -- Killed by a status: the game resolves the death (loot, kill count), see GameState:resolveDeaths
    if self.hp <= 0 then return true end

    if frozen then
        self.vx = 0
        self.vy = 0
        self.dashVx = 0
        self.dashVy = 0
        return true
    end

    if isHitStopped then return true end
    if not player or player.hp <= 0 then return true end

    -- 4. Délégation complète de la logique de déplacement, attaque et télégraphing à AIController
    EliteAffixes.shooter = self -- marque les tirs créés par cette IA (affixe frost)
    AIController.update(self, dt, player, projectilePool, obstacleManager, dummyPool, fctPool, mapW, mapH)
    EliteAffixes.shooter = nil

    return true
end

function Dummy:draw(playerX, playerY)
    -- 1. Rendu du Telegraphing (Ligne rouge pour archers, flèche de charge, monticule souterrain)
    AIController.drawTelegraph(self, playerX, playerY)

    -- 2. Rendu procédural de la créature
    Monsters.draw(self, playerX, playerY, Config.DEBUG_MODE)

    -- 3. Rendu des effets de statut élémentaires (Auras)
    if self.status then
        if self.status.freeze and self.status.freeze > 0 then
            love.graphics.setColor(0.35, 0.85, 1.0, 0.65)
            love.graphics.circle("line", self.x, self.y, self.radius + 3)
            love.graphics.setColor(0.70, 0.95, 1.0, 0.35)
            love.graphics.circle("fill", self.x, self.y, self.radius + 1)
        end
        if self.status.fire and self.status.fire > 0 then
            local ft = love.timer.getTime() * 8
            love.graphics.setColor(1.0, 0.3, 0.1, 0.8)
            love.graphics.circle("fill", self.x + math.sin(ft) * 3, self.y - self.radius - 4, 3)
            love.graphics.setColor(1.0, 0.8, 0.2, 0.9)
            love.graphics.circle("fill", self.x, self.y - self.radius - 2, 2)
        end
        if self.status.poison and self.status.poison > 0 then
            local pt = love.timer.getTime() * 6
            love.graphics.setColor(0.2, 0.9, 0.2, 0.75)
            love.graphics.circle("fill", self.x - 4, self.y - self.radius - 3 + math.sin(pt) * 2, 2)
            love.graphics.circle("fill", self.x + 4, self.y - self.radius - 5 + math.cos(pt) * 2, 1.5)
        end
    end
end

function Dummy:getAABB()
    if self.isBurrowed then
        -- Hitbox désactivée sous terre !
        return -9999, -9999, 0, 0
    end
    return self.x - self.radius, self.y - self.radius, self.radius * 2, self.radius * 2
end

return Dummy
