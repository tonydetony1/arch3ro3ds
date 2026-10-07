local Config = require("src.data.config")
local VFX = require("src.render.vfx_manager")
local EliteAffixes = require("src.core.elite_affixes")
local CombatRules = require("src.data.combat_rules")

local Projectile = {}
Projectile.__index = Projectile

function Projectile.create(index)
    local self = setmetatable({}, Projectile)
    self.id = index
    self.x = 0
    self.y = 0
    self.vx = 0
    self.vy = 0
    self.dirX = 0
    self.dirY = 0
    self.speed = 0
    self.damage = 0
    self.radius = 3
    self.maxRange = 320
    self.distanceTraveled = 0
    self.color = {1, 1, 1, 1}
    self.isCrit = false
    self.isEnemy = false
    self.bouncesLeft = 0
    self.lastHitTargetId = nil
    self.isLobbed = false
    self.startX = 0
    self.startY = 0
    self.targetX = 0
    self.targetY = 0
    self.flightTimer = 0
    self.flightDuration = 1.4
    self.arcZ = 0
    self.aoeRadius = 28
    self.hasDetonated = false
    -- Movesets uniques d'armes
    self.behavior = "arrow"
    self.rotAngle = 0
    self.executeThreshold = nil
    self.knockbackMult = 1.0
    self.trackingSpeed = 0
    self.pierceAll = false
    self.isReturning = false
    self.returnDamageMult = 1.0
    self.baseDamage = 0
    self.isHitscan = false
    self.laserStartX = 0
    self.laserStartY = 0
    self.laserEndX = 0
    self.laserEndY = 0
    self.laserTimer = 0
    self.laserDuration = 0.12
    self.playerRef = nil
    return self
end

function Projectile:spawn(startX, startY, dirX, dirY, weapon, isCrit, bounces, isEnemy, extra)
    self.x = startX
    self.y = startY
    self.dirX = dirX
    self.dirY = dirY
    self.speed = weapon.projectile_speed or 260
    self.vx = dirX * self.speed
    self.vy = dirY * self.speed
    self.isCrit = isCrit or false
    self.isEnemy = isEnemy or false
    self.isLobbed = false
    self.arcZ = 0
    self.hasDetonated = false

    local baseDmg = weapon.damage or 15
    self.damage = self.isCrit and math.floor(baseDmg * (weapon.crit_mult or CombatRules.BASE_CRIT_MULTIPLIER)) or baseDmg
    self.baseDamage = self.damage

    self.radius = self.isCrit and ((weapon.radius or 3) * 1.3) or (weapon.radius or 3)
    self.maxRange = weapon.range or 380
    self.distanceTraveled = 0

    -- Movesets d'armes & passifs
    self.behavior = weapon.type or "arrow"
    self.rotAngle = math.atan2(dirY, dirX)
    self.executeThreshold = weapon.execute_threshold or nil
    self.knockbackMult = weapon.knockback_mult or 1.0
    self.trackingSpeed = weapon.tracking_speed or 0
    self.pierceAll = weapon.pierce_all or false
    self.isReturning = false
    self.returnDamageMult = weapon.return_damage_mult or 0.65
    self.isHitscan = weapon.is_hitscan or false
    self.laserTimer = 0
    self.playerRef = extra and extra.playerRef or nil

    if self.isHitscan then
        self.laserStartX = startX
        self.laserStartY = startY
        self.laserEndX = startX + dirX * self.maxRange
        self.laserEndY = startY + dirY * self.maxRange
        self.laserTimer = self.laserDuration
        self.x = self.laserEndX
        self.y = self.laserEndY
    end

    self.canBounceWalls = (extra and extra.canBounceWalls) or false
    self.wallBouncesLeft = (extra and extra.wallBouncesLeft) or 0
    self.canPierce = (extra and extra.canPierce) or self.pierceAll
    self.pierceCount = self.pierceAll and 999 or ((extra and extra.pierceCount) or 0)
    self.elements = (extra and extra.elements) or nil

    if self.isEnemy then
        self.color = {1.0, 0.20, 0.20, 1.0} -- Rouge vif ennemi
    else
        if self.elements and self.elements.fire then
            self.color = {1.0, 0.35, 0.1, 1.0} -- Flamme vive
        elseif self.elements and self.elements.poison then
            self.color = {0.2, 0.95, 0.3, 1.0} -- Toxique vert
        elseif self.elements and self.elements.lightning then
            self.color = {0.45, 0.75, 1.0, 1.0} -- Éclair bleu cyan
        elseif self.elements and self.elements.ice then
            self.color = {0.4, 0.95, 1.0, 1.0} -- Givre
        else
            self.color = self.isCrit and {1.0, 0.45, 0.1, 1.0} or (weapon.color or {1, 1, 1, 1})
        end
    end

    self.bouncesLeft = bounces or 0
    self.lastHitTargetId = nil
    -- Tir d'une élite "frost" : ralentit le héros à l'impact
    self.chill = (isEnemy and EliteAffixes.chillsShots(EliteAffixes.shooter)) or false
end

-- Damage lost on each ricochet to a nearby monster and on each piercing hit (see CombatRules)
function Projectile:onRicochet()
    self.damage = CombatRules.scaled(self.damage, CombatRules.RICOCHET_FACTOR)
end

function Projectile:onPierce()
    self.damage = CombatRules.scaled(self.damage, CombatRules.PIERCE_FACTOR)
end

-- Projectile lobé en cloche qui passe par-dessus les murs et les obstacles
function Projectile:spawnLobbed(startX, startY, targetX, targetY, flightDuration, damage, aoeRadius, color, isEnemy, kind)
    self.x = startX
    self.y = startY
    self.startX = startX
    self.startY = startY
    self.targetX = targetX
    self.targetY = targetY
    self.flightDuration = flightDuration or 1.4
    self.flightTimer = 0
    self.damage = damage or 22
    self.baseDamage = self.damage
    self.aoeRadius = aoeRadius or 30
    self.radius = 6
    self.isCrit = false
    self.isEnemy = (isEnemy ~= false)
    self.lobKind = kind        -- "meteor_fire" | "meteor_ice" | "meteor_thunder" | nil (bombe)
    self.isLobbed = true
    self.hasDetonated = false
    self.arcZ = 0
    self.color = color or {0.85, 0.20, 0.90, 1.0}
    self.vx = 0
    self.vy = 0
    self.dirX = 0
    self.dirY = 1
    self.distanceTraveled = 0
    self.maxRange = 9999
    self.bouncesLeft = 0
    self.lastHitTargetId = nil
    self.behavior = "lobbed"
    self.isReturning = false
    self.isHitscan = false
    self.chill = (isEnemy and EliteAffixes.chillsShots(EliteAffixes.shooter)) or false
end

function Projectile:update(dt, mapW, mapH, obstacleManager, dummyPool, player)
    -- Hitscan Instantané (Lance Brillante)
    if self.isHitscan then
        self.laserTimer = self.laserTimer - dt
        if self.laserTimer <= 0 then
            return false
        end
        return true
    end

    if self.isLobbed then
        self.flightTimer = self.flightTimer + dt
        local t = math.min(1.0, self.flightTimer / self.flightDuration)

        -- Position horizontale interpolée
        self.x = self.startX + (self.targetX - self.startX) * t
        self.y = self.startY + (self.targetY - self.startY) * t

        -- Élévation parabolique en cloche (franchit les obstacles rocheux !)
        self.arcZ = math.sin(t * math.pi) * 55

        if t >= 1.0 then
            self.hasDetonated = true
            return false -- Explosion à l'impact au sol
        end
        return true
    end

    -- 1. Animation de rotation pour la Faux et le Boomerang
    if self.behavior == "scythe" or self.behavior == "boomerang" or self.behavior == "saw" then
        self.rotAngle = self.rotAngle + dt * 14.0
    end

    -- 2. Bâton de Rôdeur : Trajectoire courbe à tête chercheuse (Tracking)
    if self.behavior == "staff" and not self.isEnemy and dummyPool and dummyPool.activeCount > 0 then
        local closestSq = 320 * 320
        local target = nil
        for d = 1, dummyPool.activeCount do
            local dIdx = dummyPool.activeList[d]
            local monster = dummyPool.items[dIdx]
            if monster and monster.alive and (not monster.isBurrowed) then
                local mdx = monster.x - self.x
                local mdy = monster.y - self.y
                local distSq = mdx * mdx + mdy * mdy
                if distSq < closestSq then
                    closestSq = distSq
                    target = monster
                end
            end
        end

        if target then
            local targetAng = math.atan2(target.y - self.y, target.x - self.x)
            local curAng = math.atan2(self.dirY, self.dirX)
            local diff = (targetAng - curAng + math.pi) % (2 * math.pi) - math.pi
            local maxTurn = (self.trackingSpeed > 0 and self.trackingSpeed or 6.5) * dt
            local turn = math.max(-maxTurn, math.min(maxTurn, diff))
            local newAng = curAng + turn
            self.dirX = math.cos(newAng)
            self.dirY = math.sin(newAng)
            self.vx = self.dirX * self.speed
            self.vy = self.dirY * self.speed
        end
    end

    -- 3. Boomerang / Tornade : Vol de retour vers le joueur
    if self.behavior == "boomerang" and self.isReturning then
        local pRef = player or self.playerRef
        if pRef then
            local pdx = pRef.x - self.x
            local pdy = pRef.y - self.y
            local pdist = math.sqrt(pdx * pdx + pdy * pdy)
            if pdist < 18 then
                VFX.addSparks(self.x, self.y, 4, {1.0, 0.8, 0.2, 0.8})
                return false -- Rattrapé par le héros !
            end
            self.dirX = pdx / pdist
            self.dirY = pdy / pdist
            self.vx = self.dirX * self.speed
            self.vy = self.dirY * self.speed
        end
    end

    local moveDist = self.speed * dt
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
    self.distanceTraveled = self.distanceTraveled + moveDist

    -- Dépassement de portée maximale (ou amorce du retour du Boomerang)
    if self.distanceTraveled >= self.maxRange then
        if self.behavior == "boomerang" and not self.isReturning then
            self.isReturning = true
            self.damage = math.max(4, math.floor(self.baseDamage * self.returnDamageMult))
            self.lastHitTargetId = nil
            self.distanceTraveled = 0
            return true
        else
            return false
        end
    end

    -- 2. Rebond sur les parois de l'arène (Bouncy Wall) ou sortie de la carte
    local limitW = mapW or Config.TOP_WIDTH
    local limitH = mapH or Config.TOP_HEIGHT

    if self.canBounceWalls and self.wallBouncesLeft and self.wallBouncesLeft > 0 then
        local didBounce = false
        if self.x < 20 and self.vx < 0 then
            self.x = 20
            self.dirX = math.abs(self.dirX)
            self.vx = math.abs(self.vx)
            didBounce = true
        elseif self.x > limitW - 20 and self.vx > 0 then
            self.x = limitW - 20
            self.dirX = -math.abs(self.dirX)
            self.vx = -math.abs(self.vx)
            didBounce = true
        end

        if self.y < 36 and self.vy < 0 then
            self.y = 36
            self.dirY = math.abs(self.dirY)
            self.vy = math.abs(self.vy)
            didBounce = true
        elseif self.y > limitH - 22 and self.vy > 0 then
            self.y = limitH - 22
            self.dirY = -math.abs(self.dirY)
            self.vy = -math.abs(self.vy)
            didBounce = true
        end

        if didBounce then
            self.wallBouncesLeft = self.wallBouncesLeft - 1
            self.damage = CombatRules.scaled(self.damage, CombatRules.WALL_BOUNCE_FACTOR)
            VFX.addSparks(self.x, self.y, 4, self.color)
            return true
        end
    end

    if self.x < 16 or self.x > limitW - 16 or
       self.y < 32 or self.y > limitH - 18 then
        if self.behavior == "boomerang" and not self.isReturning then
            self.isReturning = true
            self.damage = math.max(4, math.floor(self.baseDamage * self.returnDamageMult))
            self.lastHitTargetId = nil
            self.distanceTraveled = 0
            return true
        end
        return false
    end

    -- 3. SYSTÈME DE COUVERTURE : Destruction nette contre les Rochers/Murs pour tirs directs !
    if obstacleManager and obstacleManager:blocksProjectile(self.x, self.y, self.radius) then
        if self.behavior == "boomerang" and not self.isReturning then
            self.isReturning = true
            self.damage = math.max(4, math.floor(self.baseDamage * self.returnDamageMult))
            self.lastHitTargetId = nil
            self.distanceTraveled = 0
            return true
        end
        return false
    end

    return true
end

function Projectile:draw()
    -- 0. Tir Laser Hitscan (Lance Brillante)
    if self.isHitscan then
        local alpha = math.max(0, math.min(1.0, self.laserTimer / self.laserDuration))
        -- Halo extérieur lumineux
        love.graphics.setColor(self.color[1], self.color[2], self.color[3], alpha * 0.45)
        love.graphics.setLineWidth(self.radius * 2.8)
        love.graphics.line(self.laserStartX, self.laserStartY, self.laserEndX, self.laserEndY)
        -- Cœur éclatant blanc-or
        love.graphics.setColor(1.0, 1.0, 0.9, alpha * 0.95)
        love.graphics.setLineWidth(self.radius * 1.2)
        love.graphics.line(self.laserStartX, self.laserStartY, self.laserEndX, self.laserEndY)
        love.graphics.setLineWidth(1)
        -- Impact étincelant à la cible
        love.graphics.setColor(1.0, 1.0, 1.0, alpha)
        love.graphics.circle("fill", self.laserEndX, self.laserEndY, self.radius * 1.5)
        return
    end

    if self.isLobbed then
        local t = math.min(1.0, self.flightTimer / self.flightDuration)

        -- 1. CERCLE ROUGE DE MORTIER AU SOL (TELEGRAPHING EN EXPANSION)
        VFX.drawBombTelegraph(self.targetX, self.targetY, self.aoeRadius, t)

        -- 2. Ombre dynamique au sol de la bombe en vol (reste au sol et rétrécit avec arcZ)
        VFX.drawDynamicShadow(self.x, self.y, 6.0, 3.0, self.arcZ, 0.40)

        -- 3. Bombe lobée en l'air (X, Y - arcZ)
        local drawY = self.y - self.arcZ
        love.graphics.setColor(0.18, 0.14, 0.24, 1.0)
        love.graphics.circle("fill", self.x, drawY, self.radius)

        -- Reflet et mèche étincelante
        love.graphics.setColor(self.color[1], self.color[2], self.color[3], 0.9)
        love.graphics.circle("fill", self.x - 1.5, drawY - 1.5, 2.5)

        -- Mèche brûlante (flamme)
        love.graphics.setColor(1.0, 0.7, 0.1, 1.0)
        love.graphics.circle("fill", self.x + 2, drawY - self.radius - 2, 2.2)
        love.graphics.setColor(1.0, 0.2, 0.1, 1.0)
        love.graphics.circle("fill", self.x + 3, drawY - self.radius - 4, 1.2)
        return
    end

    -- 1. Faux de la Mort (Crescent rotatif lourd)
    if self.behavior == "scythe" then
        VFX.drawDynamicShadow(self.x, self.y + 8, self.radius * 1.4, self.radius * 0.6, 0, 0.35)
        love.graphics.push()
        love.graphics.translate(self.x, self.y)
        love.graphics.rotate(self.rotAngle)
        love.graphics.setColor(0.18, 0.06, 0.10, 1.0)
        love.graphics.arc("fill", 0, 0, self.radius * 1.3, -math.pi * 0.6, math.pi * 0.6)
        love.graphics.setColor(self.color[1], self.color[2], self.color[3], 1.0)
        love.graphics.setLineWidth(2.4)
        love.graphics.arc("line", 0, 0, self.radius * 1.3, -math.pi * 0.6, math.pi * 0.6)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.circle("fill", math.cos(0) * self.radius * 1.1, math.sin(0) * self.radius * 1.1, 1.8)
        love.graphics.pop()
        return
    end

    -- 2. Boomerang / Tornade (Ailes aérodynamiques rotatives)
    if self.behavior == "boomerang" then
        VFX.drawDynamicShadow(self.x, self.y + 8, self.radius * 1.3, self.radius * 0.5, 0, 0.32)
        love.graphics.push()
        love.graphics.translate(self.x, self.y)
        love.graphics.rotate(self.rotAngle)
        love.graphics.setColor(self.color[1], self.color[2], self.color[3], 1.0)
        love.graphics.setLineWidth(3.0)
        love.graphics.line(-self.radius * 1.2, -self.radius * 0.6, 0, 0)
        love.graphics.line(0, 0, self.radius * 1.2, -self.radius * 0.6)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(1, 1, 0.9, 0.9)
        love.graphics.circle("fill", -self.radius * 1.2, -self.radius * 0.6, 1.8)
        love.graphics.circle("fill", self.radius * 1.2, -self.radius * 0.6, 1.8)
        love.graphics.circle("fill", 0, 0, 2.2)
        love.graphics.pop()
        return
    end

    -- 3. Bâton de Rôdeur (Orbe magique stellaire)
    if self.behavior == "staff" then
        VFX.drawDynamicShadow(self.x, self.y + 8, self.radius * 1.1, self.radius * 0.5, 0, 0.30)
        love.graphics.setColor(self.color[1], self.color[2], self.color[3], 0.40)
        love.graphics.circle("fill", self.x, self.y, self.radius * 1.6)
        love.graphics.setColor(self.color[1], self.color[2], self.color[3], 0.90)
        love.graphics.circle("fill", self.x, self.y, self.radius)
        love.graphics.setColor(1, 1, 1, 0.95)
        love.graphics.circle("fill", self.x - 1, self.y - 1, self.radius * 0.5)
        return
    end

    -- Projectile standard en ligne droite (Flèche / Dague)
    -- 1. Ombre dynamique au sol
    VFX.drawDynamicShadow(self.x, self.y + 8, self.radius * 1.2, self.radius * 0.5, 0, 0.30)

    -- 2. Traînée de particules / sillage
    local trailLen = self.radius * 3.2
    for tr = 1, 3 do
        local factor = tr * 0.33
        local tx = self.x - self.dirX * (trailLen * factor)
        local ty = self.y - self.dirY * (trailLen * factor)
        love.graphics.setColor(self.color[1], self.color[2], self.color[3], 0.35 / tr)
        love.graphics.circle("fill", tx, ty, self.radius * (1.0 - factor * 0.4))
    end

    -- 3. Corps du projectile
    love.graphics.setColor(self.color[1], self.color[2], self.color[3], 1.0)
    local pTipX = self.x + self.dirX * self.radius * 1.6
    local pTipY = self.y + self.dirY * self.radius * 1.6
    local pTailX = self.x - self.dirX * self.radius * 2.0
    local pTailY = self.y - self.dirY * self.radius * 2.0

    love.graphics.setLineWidth(self.radius * 0.9)
    love.graphics.line(pTailX, pTailY, pTipX, pTipY)
    love.graphics.setLineWidth(1)

    -- Pointe incandescente
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.circle("fill", pTipX, pTipY, self.radius * 0.7)

    -- Hitbox AABB en mode Débogage
    if Config.DEBUG_MODE then
        love.graphics.setColor(self.isEnemy and {1, 0, 0, 0.7} or {0, 1, 0, 0.7})
        love.graphics.rectangle("line", self.x - self.radius, self.y - self.radius, self.radius * 2, self.radius * 2)
    end
end

function Projectile:getAABB()
    return self.x - self.radius, self.y - self.radius, self.radius * 2, self.radius * 2
end

return Projectile
