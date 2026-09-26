local Config = require("src.data.config")
local Screen = require("src.core.screen")
local PlayerStats = require("src.data.player_stats")
local Weapons = require("src.data.weapons")
local VFX = require("src.render.vfx_manager")
local Pet = require("src.entities.pet")
local Art = require("src.render.art")
local Audio = require("src.audio.audio")
local Palette = require("src.render.palette")
local PixelFont = require("src.ui.pixel_font")
local HeroSprites = require("src.render.sprites.heroes")

local Player = {}
Player.__index = Player

function Player.new(startX, startY)
    local self = setmetatable({}, Player)
    
    self.x = startX or (Config.TOP_WIDTH / 2)
    self.y = startY or (Config.TOP_HEIGHT / 2 + 10)
    self.vx = 0
    self.vy = 0

    -- Caractéristiques de base
    self.baseSpeed = PlayerStats.base_speed
    self.speed = self.baseSpeed
    -- Effets de terrain : sable (ralenti), glace (glissade)
    self.terrainSpeedMult = 1.0
    self.terrainSlip = 0
    self.maxHp = PlayerStats.max_hp
    self.hp = self.maxHp
    self.radius = PlayerStats.hitbox_radius
    self.detectionRadius = PlayerStats.detection_radius

    -- Arme & Modificateurs
    self.weaponId = PlayerStats.initial_weapon
    self.currentWeapon = Weapons[self.weaponId]
    self.fireCooldown = 0
    self.damageMult = 1.0
    self.attackSpeedMult = 1.0
    self.critChance = 0.15
    self.critMultiplier = 2.0
    self.furyBonus = 0
    self.arrowRadiusBonus = 0
    self.goldMultiplier = 1.0
    self.dodgeChance = 0

    -- Compétences de tirs (Multishot Archero)
    self.frontArrows = 1
    self.diagArrows = 0
    self.rearArrows = 0
    self.sideArrows = 0
    self.hasRicochet = false
    self.hasPiercing = false
    self.hasBouncyWalls = false
    self.elements = {}
    self.orbitals = {}
    self.pets = {
        Pet.new("laser_bat", 1),
        Pet.new("ghost_mage", 2),
    }

    -- Progression (XP exponentielle Archero : 50 * (Niv ^ 1.5))
    self.level = 1
    self.xp = 0
    self.nextLevelXp = math.floor(50 * (self.level ^ 1.5))

    -- Mouvement & Orientation
    self.isMoving = false
    self.wasMoving = false
    self.currentAngle = 0
    self.targetAngle = 0
    self.aimDirX = 1.0
    self.aimDirY = 0.0
    self.currentTarget = nil

    -- Game Feel (Squash & Stretch, Recul)
    self.animTime = 0
    self.squashTimer = 0
    self.squashX = 1.0
    self.squashY = 1.0
    self.recoil = 0

    -- Limites physiques de l'arène
    self.minX = 22
    self.maxX = Config.TOP_WIDTH - 22
    self.minY = 36
    self.maxY = Config.TOP_HEIGHT - 22

    -- Dash / Roulade d'esquive (0.2s I-Frames, cooldown 1.5s)
    self.isDashing = false
    self.dashDuration = 0.20
    self.dashTimer = 0
    self.dashCooldown = 1.50
    self.dashCooldownTimer = 0
    self.dashSpeed = 380
    self.dashDirX = 1.0
    self.dashDirY = 0.0
    self.ghostTrails = {}
    for g = 1, 6 do
        self.ghostTrails[g] = { x = 0, y = 0, alpha = 0, angle = 0 }
    end
    self.ghostTimer = 0

    -- Épées volantes (dagues qui plongent sur les ennemis)
    self.flyingSwordCount = 0
    self.flyingSwords = {}
    for i = 1, 4 do
        self.flyingSwords[i] = { state = "hover", x = 0, y = 0, angle = 0, timer = 0, vx = 0, vy = 0, life = 0, lastHitId = nil }
    end

    -- Étoile d'invincibilité (bulle dorée cyclique)
    self.hasStar = false
    self.starActive = 0
    self.starCooldown = 6.0

    -- Clone d'ombre
    self.hasShadowClone = false
    self.shadowClone = { x = 0, y = 0, timer = 0 }

    -- Familiers intercepteurs (Wingman) et météores célestes
    self.hasWingman = false
    self.meteorLevel = 0
    self.meteorTimer = 0

    -- Berserk & Invulnérabilité
    self.isInvulnerable = false
    self.isBerserk = false
    self.berserkTimer = 0

    return self
end

function Player:triggerDash()
    if self.dashCooldownTimer <= 0 and not self.isDashing then
        self.isDashing = true
        self.dashTimer = self.dashDuration
        self.dashCooldownTimer = self.dashCooldown

        local dx, dy = self.vx, self.vy
        local mag = math.sqrt(dx * dx + dy * dy)
        if mag > 10 then
            self.dashDirX = dx / mag
            self.dashDirY = dy / mag
        else
            self.dashDirX = self.aimDirX or math.cos(self.currentAngle)
            self.dashDirY = self.aimDirY or math.sin(self.currentAngle)
        end
        self.currentAngle = math.atan2(self.dashDirY, self.dashDirX)
        self.targetAngle = self.currentAngle

        VFX.shakeLight()
        VFX.addSparks(self.x, self.y, 8, {0.35, 0.85, 1.0, 1.0})
        Audio.play("dash", 0.1, 0.8)
        return true
    end
    return false
end

function Player:takeDamage(dmg)
    if self.isDashing or self.isInvulnerable or (self.starActive or 0) > 0 then
        return 0, true
    end
    local finalDmg = dmg or 15
    self.hp = math.max(0, self.hp - finalDmg)
    return finalDmg, false
end

function Player:equipWeapon(weaponId)
    if Weapons[weaponId] then
        self.weaponId = weaponId
        self.currentWeapon = Weapons[weaponId]
        self.fireCooldown = 0
    end
end

-- Système d'XP exponentiel Archero
function Player:addXp(amount)
    self.xp = self.xp + amount
    local leveledUp = false
    while self.xp >= self.nextLevelXp do
        self.xp = self.xp - self.nextLevelXp
        self.level = self.level + 1
        -- Formule exponentielle : premiers niveaux rapides, puis progression exigeante
        self.nextLevelXp = math.floor(50 * (self.level ^ 1.5))
        self.hp = math.min(self.maxHp, self.hp + 20)
        leveledUp = true
    end
    return leveledUp
end

function Player:handleInput(dt)
    local inputX = 0
    local inputY = 0

    -- 1. Circle Pad 3DS
    local joysticks = love.joystick.getJoysticks()
    if #joysticks > 0 then
        local joy = joysticks[1]
        local rawX = joy:getAxis(1) or 0
        local rawY = joy:getAxis(2) or 0
        local mag = math.sqrt(rawX * rawX + rawY * rawY)

        if mag > Config.INPUT.DEADZONE then
            local factor = (mag - Config.INPUT.DEADZONE) / (1.0 - Config.INPUT.DEADZONE)
            inputX = (rawX / mag) * factor
            inputY = (rawY / mag) * factor
        end
    end

    -- 2. Clavier PC (uniquement hors console 3DS)
    if inputX == 0 and inputY == 0 and not Screen.is3DS and love.keyboard and love.keyboard.isDown then
        local isDown = function(k)
            local ok, down = pcall(love.keyboard.isDown, k)
            return ok and down
        end
        if isDown("left") or isDown("q") or isDown("a") then
            inputX = inputX - 1
        end
        if isDown("right") or isDown("d") then
            inputX = inputX + 1
        end
        if isDown("up") or isDown("z") or isDown("w") then
            inputY = inputY - 1
        end
        if isDown("down") or isDown("s") then
            inputY = inputY + 1
        end

        if inputX ~= 0 and inputY ~= 0 then
            local inv = 0.70710678
            inputX = inputX * inv
            inputY = inputY * inv
        end
    end

    -- Règle d'or Move vs Attack : Détection stricte d'input
    local hasInput = (inputX ~= 0 or inputY ~= 0)
    self.hasInput = hasInput

    -- Physique d'accélération et glissade (le terrain modifie vitesse et adhérence)
    local speed = self.speed * (self.terrainSpeedMult or 1.0)
    local grip = 25 * (1.0 - (self.terrainSlip or 0) * 0.82)
    local targetVx = inputX * speed
    local targetVy = inputY * speed

    if hasInput then
        self.vx = self.vx + (targetVx - self.vx) * math.min(1.0, dt * grip)
        self.vy = self.vy + (targetVy - self.vy) * math.min(1.0, dt * grip)
        self.isMoving = true
        self.wasMoving = true
        self.targetAngle = math.atan2(self.vy, self.vx)
        self.currentTarget = nil -- Le moindre input annule instantanément le cycle de tir en cours !
    else
        local friction = 24 * (1.0 - (self.terrainSlip or 0) * 0.85)
        self.vx = self.vx * math.max(0, 1.0 - dt * friction)
        self.vy = self.vy * math.max(0, 1.0 - dt * friction)

        if math.abs(self.vx) < 1.0 and math.abs(self.vy) < 1.0 then
            self.vx = 0
            self.vy = 0
            if self.wasMoving then
                self.squashTimer = 0.16
                self.squashX = 1.25
                self.squashY = 0.78
                self.wasMoving = false
            end
            self.isMoving = false
        else
            self.isMoving = true
            self.currentTarget = nil
        end
    end
end

function Player:findNearestTarget(dummyPool)
    local closestDistSq = self.detectionRadius * self.detectionRadius
    local bestTarget = nil

    if dummyPool and dummyPool.activeCount > 0 then
        for i = 1, dummyPool.activeCount do
            local dIdx = dummyPool.activeList[i]
            local target = dummyPool.items[dIdx]
            if target and target.alive then
                local dx = target.x - self.x
                local dy = target.y - self.y
                local distSq = dx * dx + dy * dy
                if distSq < closestDistSq then
                    closestDistSq = distSq
                    bestTarget = target
                end
            end
        end
    end

    return bestTarget
end

-- Tir modulaire gérant toutes les combinaisons de flèches (Frontale, Diagonale, Arrière, Latérale)
function Player:shoot(projectilePool)
    local isCrit = (math.random() < self.critChance)
    local bounces = self.hasRicochet and 1 or 0
    local effectiveDmg = math.floor(self.currentWeapon.damage * (self.damageMult + self.furyBonus))
    local rad = (self.currentWeapon.radius or 3) + self.arrowRadiusBonus

    local wData = {
        id = self.currentWeapon.id,
        type = self.currentWeapon.type,
        projectile_speed = self.currentWeapon.projectile_speed,
        damage = effectiveDmg,
        range = self.currentWeapon.range,
        radius = rad,
        color = self.currentWeapon.color,
        knockback_mult = self.currentWeapon.knockback_mult,
        execute_threshold = self.currentWeapon.execute_threshold,
        tracking_speed = self.currentWeapon.tracking_speed,
        pierce_all = self.currentWeapon.pierce_all,
        return_damage_mult = self.currentWeapon.return_damage_mult,
        is_hitscan = self.currentWeapon.is_hitscan,
        sprite = self.currentWeapon.sprite,
    }

    local extra = {
        canBounceWalls = self.hasBouncyWalls,
        wallBouncesLeft = self.hasBouncyWalls and 2 or 0,
        canPierce = self.hasPiercing or self.currentWeapon.pierce_all,
        pierceCount = self.currentWeapon.pierce_all and 999 or (self.hasPiercing and 3 or 0),
        elements = self.elements,
        playerRef = self,
    }

    Audio.playWeapon(self.weaponId)

    local function spawnProj(ang)
        local p = projectilePool:obtain()
        if p then
            local dx = math.cos(ang)
            local dy = math.sin(ang)
            p:spawn(self.x + dx * 10, self.y + dy * 10, dx, dy, wData, isCrit, bounces, false, extra)
        end
    end

    -- 1. Flèches Frontales
    if self.frontArrows <= 1 then
        spawnProj(self.currentAngle)
    elseif self.frontArrows == 2 then
        spawnProj(self.currentAngle - 0.10)
        spawnProj(self.currentAngle + 0.10)
    else
        spawnProj(self.currentAngle - 0.18)
        spawnProj(self.currentAngle)
        spawnProj(self.currentAngle + 0.18)
    end

    -- 2. Flèches Diagonales
    if self.diagArrows > 0 then
        spawnProj(self.currentAngle - math.pi / 4)
        spawnProj(self.currentAngle + math.pi / 4)
    end

    -- 3. Flèche Arrière
    if self.rearArrows > 0 then
        spawnProj(self.currentAngle + math.pi)
    end

    -- 4. Flèches Latérales
    if self.sideArrows > 0 then
        spawnProj(self.currentAngle - math.pi / 2)
        spawnProj(self.currentAngle + math.pi / 2)
    end

    self.recoil = 4.5

    -- Screen shake léger (2-3px) lors du tir
    VFX.shakeLight()
end

-- ============================================================================
-- ÉPÉES VOLANTES : vol stationnaire au-dessus du héros, plongeon sur la cible, retour
-- ============================================================================
local SWORD_HOVER_R = 15
local SWORD_SPEED = 430

function Player:updateFlyingSwords(dt, dummyPool, fctPool)
    local count = self.flyingSwordCount or 0
    if count <= 0 then return end
    local t = love.timer.getTime()
    local damage = math.floor((self.currentWeapon.damage * (self.damageMult or 1.0)) * 1.2 + (self.baseHeroAtk or 0) * 0.5)

    for i = 1, count do
        local s = self.flyingSwords[i]
        local hoverAng = t * 2.4 + (i - 1) * (math.pi * 2 / count)
        local hx = self.x + math.cos(hoverAng) * SWORD_HOVER_R
        local hy = self.y - 19 + math.sin(hoverAng) * 3

        if s.state == "hover" then
            s.x, s.y = hx, hy
            s.angle = math.sin(hoverAng) * 0.25
            s.timer = s.timer - dt
            if s.timer <= 0 and dummyPool and dummyPool.activeCount > 0 then
                local bestD, best = 240 * 240, nil
                for k = 1, dummyPool.activeCount do
                    local d = dummyPool.items[dummyPool.activeList[k]]
                    if d and d.alive and not d.isBurrowed then
                        local dx, dy = d.x - self.x, d.y - self.y
                        local dsq = dx * dx + dy * dy
                        if dsq < bestD then bestD, best = dsq, d end
                    end
                end
                if best then
                    local dx, dy = best.x - s.x, best.y - s.y
                    local len = math.max(1, math.sqrt(dx * dx + dy * dy))
                    s.vx, s.vy = dx / len * SWORD_SPEED, dy / len * SWORD_SPEED
                    s.angle = math.atan2(dy, dx) + math.pi / 2
                    s.state = "dive"
                    s.life = 0.85
                    s.lastHitId = nil
                end
            end

        elseif s.state == "dive" then
            s.x = s.x + s.vx * dt
            s.y = s.y + s.vy * dt
            s.life = s.life - dt
            if dummyPool and dummyPool.activeCount > 0 then
                for k = 1, dummyPool.activeCount do
                    local d = dummyPool.items[dummyPool.activeList[k]]
                    if d and d.alive and not d.isBurrowed and d.id ~= s.lastHitId then
                        local dx, dy = d.x - s.x, d.y - s.y
                        local hit = d.radius + 7
                        if (dx * dx + dy * dy) < hit * hit then
                            local len = math.max(1, math.sqrt(dx * dx + dy * dy))
                            d:takeDamage(damage, dx / len, dy / len, self.elements)
                            VFX.triggerHitFlash(d, 3)
                            VFX.addSparks(d.x, d.y, 4, { 0.85, 0.92, 1.0, 1.0 })
                            if fctPool then
                                local f = fctPool:obtain()
                                if f then f:spawn(d.x, d.y - 8, damage, false) end
                            end
                            s.lastHitId = d.id
                            s.state = "return"
                            break
                        end
                    end
                end
            end
            if s.life <= 0 then s.state = "return" end

        else -- retour au vol stationnaire
            local dx, dy = hx - s.x, hy - s.y
            local len = math.sqrt(dx * dx + dy * dy)
            if len < 6 then
                s.state = "hover"
                s.timer = 1.4
            else
                s.x = s.x + (dx / len) * SWORD_SPEED * 0.9 * dt
                s.y = s.y + (dy / len) * SWORD_SPEED * 0.9 * dt
                s.angle = math.atan2(dy, dx) + math.pi / 2
            end
        end
    end
end

-- ============================================================================
-- CLONE D'OMBRE : double spectral qui suit le héros et tire à 45 % des dégâts
-- ============================================================================
function Player:updateShadowClone(dt, projectilePool, dummyPool)
    if not self.hasShadowClone then return end
    local c = self.shadowClone
    local tx = self.x - (self.aimDirX or 0) * 26
    local ty = self.y - (self.aimDirY or -1) * 20 + 8
    c.x = c.x + (tx - c.x) * math.min(1.0, dt * 6)
    c.y = c.y + (ty - c.y) * math.min(1.0, dt * 6)
    c.timer = (c.timer or 0) - dt

    if c.timer > 0 or not projectilePool or not dummyPool or dummyPool.activeCount == 0 then return end

    local bestSq, best = 320 * 320, nil
    for i = 1, dummyPool.activeCount do
        local d = dummyPool.items[dummyPool.activeList[i]]
        if d and d.alive and not d.isBurrowed then
            local dx, dy = d.x - c.x, d.y - c.y
            local dsq = dx * dx + dy * dy
            if dsq < bestSq then bestSq, best = dsq, d end
        end
    end
    if not best then return end

    c.timer = (self.currentWeapon.fire_rate or 0.35) * 1.7
    local dx, dy = best.x - c.x, best.y - c.y
    local len = math.max(1, math.sqrt(dx * dx + dy * dy))
    local w = self.currentWeapon
    local proj = projectilePool:obtain()
    if proj then
        proj:spawn(c.x, c.y, dx / len, dy / len, {
            projectile_speed = w.projectile_speed,
            damage = math.floor(w.damage * (self.damageMult or 1.0) * 0.45),
            range = w.range,
            radius = w.radius,
            color = { 0.70, 0.40, 1.00, 1.0 },
        }, false, 0, false)
    end
end

-- ============================================================================
-- ÉTOILE D'INVINCIBILITÉ : bulle dorée de 2 s toutes les 10 s
-- ============================================================================
function Player:updateStar(dt)
    if not self.hasStar then return end
    if (self.starActive or 0) > 0 then
        self.starActive = self.starActive - dt
        if self.starActive <= 0 then
            self.starActive = 0
            self.starCooldown = 10.0
        end
    else
        self.starCooldown = (self.starCooldown or 10.0) - dt
        if self.starCooldown <= 0 then
            self.starActive = 2.0
            VFX.addSparks(self.x, self.y, 8, { 1.0, 0.85, 0.25, 1.0 })
        end
    end
end

function Player:setBounds(mapW, mapH)
    self.minX = 22
    self.maxX = (mapW or Config.TOP_WIDTH) - 22
    self.minY = 36
    self.maxY = (mapH or Config.TOP_HEIGHT) - 22
end

function Player:update(dt, projectilePool, dummyPool, fctPool, obstacleManager, isGateOpen)
    -- Décrémentation du Hit-Flash (exactement 3 frames)
    VFX.updateEntity(self)

    -- Régénération passive (compétences de soin) : accumulée puis appliquée par point entier
    if (self.hpRegen or 0) > 0 and self.hp < self.maxHp then
        self.regenPool = (self.regenPool or 0) + self.hpRegen * dt
        if self.regenPool >= 1 then
            local whole = math.floor(self.regenPool)
            self.regenPool = self.regenPool - whole
            self.hp = math.min(self.maxHp, self.hp + whole)
        end
    end

    -- Trait passif Berserker (Helix) : Dégâts croissants avec les PV perdus
    if self.hasBerserkFury then
        local missingRatio = math.max(0, 1.0 - (self.hp / math.max(1, self.maxHp)))
        self.furyBonus = missingRatio * 1.20
    end

    -- Gestion du mode Berserk actif (Ultime Helix)
    if self.berserkTimer > 0 then
        self.berserkTimer = self.berserkTimer - dt
        self.isInvulnerable = true
        if self.berserkTimer <= 0 then
            self.berserkTimer = 0
            self.isBerserk = false
            self.isInvulnerable = false
            self.attackSpeedMult = self.attackSpeedMult / 2.0
        end
    end

    -- Gestion du Dash (Esquive I-Frames)
    self.dashCooldownTimer = math.max(0, self.dashCooldownTimer - dt)

    local Physics = require("src.core.physics")
    if self.isDashing then
        self.dashTimer = self.dashTimer - dt

        -- Enregistrement du sillage fantôme (Ghost Trail)
        self.ghostTimer = self.ghostTimer + dt
        if self.ghostTimer >= 0.035 then
            self.ghostTimer = 0
            for g = #self.ghostTrails, 2, -1 do
                self.ghostTrails[g].x = self.ghostTrails[g-1].x
                self.ghostTrails[g].y = self.ghostTrails[g-1].y
                self.ghostTrails[g].alpha = self.ghostTrails[g-1].alpha
                self.ghostTrails[g].angle = self.ghostTrails[g-1].angle
            end
            self.ghostTrails[1].x = self.x
            self.ghostTrails[1].y = self.y
            self.ghostTrails[1].alpha = 0.65
            self.ghostTrails[1].angle = self.currentAngle
        end

        local dashVx = self.dashDirX * self.dashSpeed
        local dashVy = self.dashDirY * self.dashSpeed
        Physics.moveAndSlide(self, dashVx, dashVy, dt, self.radius, obstacleManager, false, self.maxX + 22, self.maxY + 22, isGateOpen)

        if self.dashTimer <= 0 then
            self.isDashing = false
        end
    else
        self:handleInput(dt)
        local blockedX, blockedY = Physics.moveAndSlide(self, self.vx, self.vy, dt, self.radius, obstacleManager, false, self.maxX + 22, self.maxY + 22, isGateOpen)
        if blockedX then self.vx = 0 end
        if blockedY then self.vy = 0 end
    end

    -- Dissipation progressive des silhouettes d'esquive
    for g = 1, #self.ghostTrails do
        if self.ghostTrails[g].alpha > 0 then
            self.ghostTrails[g].alpha = math.max(0, self.ghostTrails[g].alpha - dt * 3.5)
        end
    end

    if self.recoil > 0 then
        self.recoil = math.max(0, self.recoil - dt * 25)
    end

    -- Mise à jour des Épées / Orbes orbitaux
    if self.orbitals and #self.orbitals > 0 then
        for _, orb in ipairs(self.orbitals) do
            orb.angle = (orb.angle + dt * 4.2) % (math.pi * 2)
            orb.x = self.x + math.cos(orb.angle) * orb.dist
            orb.y = self.y + math.sin(orb.angle) * orb.dist

            -- Collisions orbitales avec les monstres
            if dummyPool and dummyPool.activeCount > 0 then
                for i = 1, dummyPool.activeCount do
                    local dIdx = dummyPool.activeList[i]
                    local target = dummyPool.items[dIdx]
                    if target and target.alive then
                        local odx = target.x - orb.x
                        local ody = target.y - orb.y
                        if (odx * odx + ody * ody) < (target.radius + 6) * (target.radius + 6) then
                            target:takeDamage(orb.dmg or 15)
                            if fctPool then
                                local f = fctPool:obtain()
                                if f then f:spawn(target.x, target.y - 8, orb.dmg or 15, false) end
                            end
                        end
                    end
                end
            end
        end
    end

    self:updateFlyingSwords(dt, dummyPool, fctPool)
    self:updateStar(dt)
    self:updateShadowClone(dt, projectilePool, dummyPool)

    -- Mise à jour des Familiers (Pets / Spirits)
    if self.pets and #self.pets > 0 then
        for _, pet in ipairs(self.pets) do
            pet:update(dt, self, projectilePool, dummyPool)
        end
    end

    -- Règle d'or Move vs Attack : Le joueur ne tire QUE s'il est à l'arrêt absolu
    local isStrictlyStopped = (not self.hasInput) and (self.vx == 0) and (self.vy == 0) and (not self.isMoving) and (not self.isDashing)

    -- Squash & Stretch et Visée / Tir
    if not isStrictlyStopped then
        self.animTime = self.animTime + dt * 14
        self.currentTarget = nil
        self.squashX = 0.90 + math.cos(self.animTime) * 0.08
        self.squashY = 1.12 + math.sin(self.animTime) * 0.08
    else
        self.animTime = 0
        if self.squashTimer > 0 then
            self.squashTimer = self.squashTimer - dt
            local t = math.max(0, self.squashTimer / 0.16)
            self.squashX = 1.0 + (1.25 - 1.0) * t
            self.squashY = 1.0 + (0.78 - 1.0) * t
        else
            self.squashX = 1.0
            self.squashY = 1.0
        end

        -- Visée et tir à l'arrêt
        self.currentTarget = self:findNearestTarget(dummyPool)
        if self.currentTarget then
            local dx = self.currentTarget.x - self.x
            local dy = self.currentTarget.y - self.y
            self.targetAngle = math.atan2(dy, dx)
        end

        local diff = (self.targetAngle - self.currentAngle + math.pi) % (math.pi * 2) - math.pi
        self.currentAngle = self.currentAngle + diff * math.min(1.0, dt * 20)
        self.aimDirX = math.cos(self.currentAngle)
        self.aimDirY = math.sin(self.currentAngle)

        local effectiveFireRate = self.currentWeapon.fire_rate / self.attackSpeedMult
        if self.fireCooldown > 0 then
            self.fireCooldown = self.fireCooldown - dt
        end

        if self.currentTarget and self.fireCooldown <= 0 then
            self:shoot(projectilePool)
            self.fireCooldown = effectiveFireRate
        end
    end
end

-- Décalages des accessoires de tête (repère : ancre du corps, héros tourné vers la droite)
local ACC_OFFSET = {
    feather = { 3, -14 }, mask = { -2, -8 }, crest = { 0, -15 }, horns = { 0, -13 }, tiara = { 0, -15 },
}
local RUN_LEGS = { 2, 3, 4, 3 }

local function drawOrbitals(self)
    if not self.orbitals or #self.orbitals == 0 then return end
    for _, orb in ipairs(self.orbitals) do
        local ox = math.floor(self.x + math.cos(orb.angle) * orb.dist + 0.5)
        local oy = math.floor(self.y + math.sin(orb.angle) * orb.dist + 0.5)
        if orb.isShield then
            Palette.set(Palette.C.ink)
            love.graphics.circle("fill", ox, oy, 5)
            love.graphics.setColor(orb.color[1], orb.color[2], orb.color[3], 1.0)
            love.graphics.circle("fill", ox, oy, 4)
            Palette.set(Palette.C.white, 0.8)
            love.graphics.rectangle("fill", ox - 2, oy - 2, 2, 2)
        else
            local tang = orb.angle + math.pi / 2
            local tx, ty = math.cos(tang) * 6, math.sin(tang) * 6
            Palette.set(Palette.C.ink)
            love.graphics.setLineWidth(4)
            love.graphics.line(ox - tx, oy - ty, ox + tx, oy + ty)
            love.graphics.setColor(orb.color[1], orb.color[2], orb.color[3], 1.0)
            love.graphics.setLineWidth(2)
            love.graphics.line(ox - tx, oy - ty, ox + tx, oy + ty)
            love.graphics.setLineWidth(1)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Barre de vie façon Archero : PV chiffrés au-dessus d'une jauge verte segmentée
local function drawHealthBar(self)
    local barW = 24
    local x = math.floor(self.x - barW / 2)
    local y = math.floor(self.y - 23)
    local ratio = math.max(0, math.min(1, self.hp / self.maxHp))
    local C = Palette.C

    Palette.set(C.ink)
    love.graphics.rectangle("fill", x - 1, y - 1, barW + 2, 6)
    Palette.set(C.night)
    love.graphics.rectangle("fill", x, y, barW, 4)
    local fillW = math.floor(barW * ratio + 0.5)
    if fillW > 0 then
        local low = ratio < 0.3
        Palette.set(low and C.red or C.leaf)
        love.graphics.rectangle("fill", x, y, fillW, 4)
        Palette.set(low and C.pink or Palette.hex("a8e890"))
        love.graphics.rectangle("fill", x, y, fillW, 1)
        Palette.set(low and C.wine or C.moss)
        love.graphics.rectangle("fill", x, y + 3, fillW, 1)
    end
    Palette.set(C.ink, 0.6)
    for seg = x + 6, x + barW - 1, 6 do
        love.graphics.rectangle("fill", seg, y, 1, 4)
    end

    local hpText = tostring(math.max(0, math.floor(self.hp)))
    PixelFont.print(hpText, math.floor(self.x - PixelFont.getWidth(hpText, "tiny") / 2), y - 8, C.white, "tiny")
    love.graphics.setColor(1, 1, 1, 1)
end

-- Héros, arc et effets liés au corps (dessiné dans la passe triée en profondeur)
function Player:drawBody()
    local t = love.timer.getTime()
    local heroId = self.heroId or "atreus"
    local variant = (heroId ~= "atreus") and heroId or nil
    local acc = HeroSprites.ACCESSORY_BY_HERO[heroId]
    local flash = VFX.isHitFlashing(self)
    local moving = self.isMoving or self.vx ~= 0 or self.vy ~= 0

    if moving and self.vx ~= 0 then
        self.faceLeft = self.vx < 0
    elseif not moving then
        self.faceLeft = self.aimDirX < 0
    end
    local left = self.faceLeft == true

    -- 0. Sillage fantôme du Dash (silhouettes cyan)
    for g = 1, #self.ghostTrails do
        local gt = self.ghostTrails[g]
        if gt.alpha > 0.02 then
            love.graphics.setColor(0.35, 0.85, 1.0, gt.alpha * 0.55)
            Art.draw("hero_body", 1, gt.x, gt.y + 6, left, true)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)

    -- 0b. Aura de Fureur Berserker (Helix)
    if self.isBerserk then
        local pulse = 0.35 + math.sin(t * 14) * 0.15
        Palette.set(Palette.C.orange, pulse * 0.45)
        love.graphics.ellipse("fill", self.x, self.y + 6, 16, 7)
        Palette.set(Palette.C.yellow, pulse * 0.7)
        love.graphics.ellipse("line", self.x, self.y + 6, 16, 7)
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- 0c. Clone d'ombre
    if self.hasShadowClone then
        local c = self.shadowClone
        VFX.drawDynamicShadow(c.x, c.y + 9, 7, 3, 0, 0.25)
        love.graphics.setColor(0.62, 0.36, 0.95, 0.62)
        Art.draw("hero_legs", 1, c.x, c.y + 7, left, true)
        Art.draw("hero_body", 1, c.x, c.y + 6, left, true)
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- 1. Ombre au sol
    VFX.drawDynamicShadow(self.x, self.y + 9, 8, 3, 0, 0.38)

    -- 2. Armes orbitales
    drawOrbitals(self)

    -- 3. Héros : jambes, corps, accessoire, arc orienté vers la visée
    local drawX = math.floor(self.x - self.aimDirX * self.recoil + 0.5)
    local drawY = math.floor(self.y - self.aimDirY * self.recoil + 0.5)
    local bodyY = drawY + 6

    local legFrame, bob = 1, 0
    if moving then
        local step = math.floor(self.animTime / (math.pi / 2)) % 4
        legFrame = RUN_LEGS[step + 1]
        bob = (step % 2 == 1) and -1 or 0
    end
    local bodyFrame = ((t % 3.2) < 0.12) and 2 or 1

    local angle = math.atan2(self.aimDirY, self.aimDirX)
    local bowX = drawX + math.floor(self.aimDirX * 8 + 0.5)
    local bowY = drawY + 1 + math.floor(self.aimDirY * 6 + 0.5)
    local bowBehind = self.aimDirY < -0.35

    love.graphics.setColor(1, 1, 1, 1)
    if bowBehind then Art.drawEx("bow", 1, bowX, bowY, angle, 1, 1, flash) end
    Art.draw("hero_legs", legFrame, drawX, bodyY + 1, left, flash)
    Art.draw("hero_body", bodyFrame, drawX, bodyY + bob, left, flash, variant)
    if acc and not flash then
        local o = ACC_OFFSET[acc]
        Art.draw("hero_acc_" .. acc, 1, drawX + (left and -o[1] or o[1]), bodyY + bob + o[2], left)
    end
    if not bowBehind then Art.drawEx("bow", 1, bowX, bowY, angle, 1, 1, flash) end

    -- 4. Épées volantes
    for i = 1, (self.flyingSwordCount or 0) do
        local sw = self.flyingSwords[i]
        love.graphics.setColor(1, 1, 1, 1)
        Art.drawEx("fx_sword", 1, sw.x, sw.y, sw.angle, 1, 1)
    end

    -- 5. Bulle d'invincibilité
    if (self.starActive or 0) > 0 then
        local pulse = 0.5 + math.sin(t * 16) * 0.2
        Palette.set(Palette.C.yellow, 0.18 + pulse * 0.12)
        love.graphics.circle("fill", self.x, self.y, 17)
        Palette.set(Palette.C.amber, 0.75)
        love.graphics.circle("line", self.x, self.y, 17)
        Palette.set(Palette.C.white, 0.8)
        love.graphics.circle("line", self.x, self.y, 15)
        for k = 0, 3 do
            local a = t * 3 + k * math.pi / 2
            Palette.set(Palette.C.yellow, 0.9)
            love.graphics.rectangle("fill", math.floor(self.x + math.cos(a) * 17), math.floor(self.y + math.sin(a) * 17), 2, 2)
        end
        love.graphics.setColor(1, 1, 1, 1)
    end
end

-- Jauge de vie (dessinée au premier plan, au-dessus du décor)
function Player:drawOverlay()
    drawHealthBar(self)
end

function Player:draw()
    self:drawBody()
    self:drawOverlay()
    if self.pets and #self.pets > 0 then
        for _, pet in ipairs(self.pets) do
            pet:draw()
        end
    end
end

function Player:getAABB()
    return self.x - self.radius, self.y - self.radius, self.radius * 2, self.radius * 2
end

return Player
