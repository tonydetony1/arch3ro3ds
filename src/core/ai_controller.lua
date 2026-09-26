-- src/core/ai_controller.lua
-- Contrôleur d'Intelligence Artificielle complet style "Archero" pour Nintendo 3DS & PC
-- Gère les 6 archétypes stricts :
-- 1. Melee Chargers (Loups avec Stalking / Chauves-souris)
-- 2. Ranged Snipers (Squelettes Archers avec Ligne rouge et visée verrouillée)
-- 3. Spread Ranged (Plantes à tir en éventail 3-way / Golems à onde de choc en étoile)
-- 4. Bombers (Projectiles lobés en cloche par-dessus les murs et cercle AoE au sol)
-- 5. Hidden / Burrowers (Vers de terre invincibles sous le sol, émergence et tir)
-- 6. Splitters (Gros Slimes se divisant en 2 mini-slimes à la mort via le Pool)
-- Règle d'or : "Move vs Attack" stricte (les monstres s'arrêtent pour attaquer)
-- Glissade vectorielle (Wall Sliding) et zéro allocation mémoire (GC-free)

local Physics = require("src.core.physics")
local VFX = require("src.render.vfx_manager")
local Audio = require("src.audio.audio")

local AIController = {}

-- Vérifie si l'entité est vulnérable aux dégâts
function AIController.canTakeDamage(dummy)
    if dummy.isBurrowed then
        return false -- Invincible lorsqu'il est sous terre
    end
    return true
end

-- ============================================================================
-- 1. MISE À JOUR PRINCIPALE DE L'IA SELON L'ARCHÉTYPE
-- ============================================================================
function AIController.update(dummy, dt, player, projectilePool, obstacleManager, dummyPool, fctPool, mapW, mapH)
    -- PHASE 2 : rage du boss sous 50 % de PV (vitesse +30 %, cadence d'attaque +40 %)
    if dummy.isBoss and not dummy.isEnraged and dummy.maxHp and dummy.hp <= dummy.maxHp * 0.5 then
        dummy.isEnraged = true
        dummy.enrageFlash = 1.0
        dummy.speed = dummy.speed * 1.3
        dummy.attackRateMult = 0.6
        VFX.shakeHeavy()
        VFX.hitStop(0.08)
        VFX.triggerHitFlash(dummy, 6)
        VFX.addSparks(dummy.x, dummy.y, 18, { 1.0, 0.35, 0.1, 1.0 })
        VFX.addFCT(dummy.x, dummy.y - 28, "RAGE !", true)
        Audio.play("boss_roar", 0, 1.0)
    end
    if dummy.enrageFlash and dummy.enrageFlash > 0 then
        dummy.enrageFlash = math.max(0, dummy.enrageFlash - dt)
    end

    if not player or player.hp <= 0 then return true end

    -- Vecteur et distance vers le joueur
    local dx = player.x - dummy.x
    local dy = player.y - dummy.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local dirX = (dist > 0.1) and (dx / dist) or 0
    local dirY = (dist > 0.1) and (dy / dist) or 1

    -- Gestion du temps de recharge universel
    if dummy.cooldown > 0 then
        dummy.cooldown = math.max(0, dummy.cooldown - dt)
    end

    local mType = dummy.type or "slime"

    -- ------------------------------------------------------------------------
    -- ARCHÉTYPE 1 : MELEE CHARGERS (Loup stalker / Chauve-souris rapide)
    -- ------------------------------------------------------------------------
    if mType == "wolf" or mType == "bat" or mType == "raven" or mType == "gargoyle" then
        -- Rapace : chauve-souris plus agressive. Gargouille : loup de pierre, plus lourde.
        local isWolf = (mType == "wolf" or mType == "gargoyle")
        local allowFlight = not isWolf -- Les volants survolent les trous d'eau

        if dummy.aiState == "chase" or dummy.aiState == "stalk" then
            dummy.isDashing = false
            dummy.telegraphActive = false

            -- Particularité du loup : "Stalking" (anticipe la trajectoire du joueur)
            local targetX = player.x
            local targetY = player.y
            if isWolf and (player.vx ~= 0 or player.vy ~= 0) then
                -- Interception prédictive (0.35s dans le futur)
                targetX = player.x + player.vx * 0.35
                targetY = player.y + player.vy * 0.35
            end

            -- Déplacement avec glissade vectorielle fluide le long des parois
            Physics.steerAroundObstacle(dummy, targetX, targetY, dummy.speed, dt, dummy.radius, obstacleManager, allowFlight, mapW, mapH)

            -- Déclenchement de la charge (Trigger Range : ~95px)
            local triggerRange = isWolf and 105 or 85
            if dist < triggerRange and dummy.cooldown <= 0 then
                -- RÈGLE D'OR : S'ARRÊTE pour préparer son attaque (0.2s d'arrêt)
                dummy.aiState = "aim"
                dummy.stateTimer = 0.20
                dummy.targetDirX = dirX
                dummy.targetDirY = dirY
                dummy.telegraphActive = true
            end

        elseif dummy.aiState == "aim" then
            -- Phase d'anticipation et d'avertissement visuel (Telegraphing)
            -- Le monstre est IMMOBILE pendant 0.2s
            dummy.stateTimer = dummy.stateTimer - dt
            if dummy.stateTimer <= 0 then
                -- Déclenchement du Dash ultra-rapide
                dummy.aiState = "dash"
                dummy.isDashing = true
                dummy.telegraphActive = false
                dummy.stateTimer = isWolf and 0.26 or 0.24
                local dashSpeed = isWolf and 215 or 185
                dummy.dashVx = dummy.targetDirX * dashSpeed
                dummy.dashVy = dummy.targetDirY * dashSpeed
                dummy.didHitPlayer = false
            end

        elseif dummy.aiState == "dash" then
            dummy.stateTimer = dummy.stateTimer - dt
            Physics.moveAndSlide(dummy, dummy.dashVx, dummy.dashVy, dt, dummy.radius, obstacleManager, allowFlight, mapW, mapH)

            -- Dégâts de contact
            if not dummy.didHitPlayer and dist < (dummy.radius + player.radius) then
                dummy.didHitPlayer = true
                local dmg = isWolf and 16 or 13
                player.hp = math.max(0, player.hp - dmg)
                VFX.triggerHitFlash(player, 3)
                VFX.shakeMedium()
                VFX.addFCT(player.x, player.y - 12, dmg, false)
                VFX.addSparks(player.x, player.y, 6, {1, 0.2, 0.2, 1})
            end

            if dummy.stateTimer <= 0 then
                dummy.aiState = isWolf and "stalk" or "chase"
                dummy.isDashing = false
                dummy.cooldown = (isWolf and 1.6 or 1.9) * (dummy.attackRateMult or 1)
            end
        end

    -- ------------------------------------------------------------------------
    -- ARCHÉTYPE 2 : RANGED SNIPERS (Squelette Archer avec ligne rouge verrouillée)
    -- ------------------------------------------------------------------------
    elseif mType == "skeleton" then
        local hasLoS = Physics.checkLineOfSight(dummy.x, dummy.y, player.x, player.y, obstacleManager)

        if not hasLoS then
            -- Masqué par un rocher : déplacement latéral pour retrouver une ligne de vue
            dummy.aiState = "chase"
            dummy.telegraphActive = false
            dummy.aimLocked = false
            local sideX = -dirY * dummy.speed
            local sideY = dirX * dummy.speed
            Physics.moveAndSlide(dummy, sideX, sideY, dt, dummy.radius, obstacleManager, false, mapW, mapH)
        else
            -- Ligne de vue dégagée !
            if dummy.cooldown <= 0 and dummy.aiState ~= "aim" then
                -- RÈGLE D'OR : S'ARRÊTE et commence sa visée laser (Telegraphing de 1.2s)
                dummy.aiState = "aim"
                dummy.stateTimer = 1.20
                dummy.targetDirX = dirX
                dummy.targetDirY = dirY
                dummy.aimLocked = false
                dummy.telegraphActive = true
            end

            if dummy.aiState == "aim" then
                dummy.stateTimer = dummy.stateTimer - dt

                if dummy.stateTimer > 0.30 then
                    -- Phase 1 : La ligne rouge suit le joueur en temps réel
                    dummy.targetDirX = dirX
                    dummy.targetDirY = dirY
                    dummy.aimLocked = false
                else
                    -- Phase 2 : Les 0.3 dernières secondes, la ligne se VERROUILLE (figée) !
                    -- Le joueur peut esquiver en se décalant !
                    dummy.aimLocked = true
                end

                if dummy.stateTimer <= 0 then
                    -- Tir d'une flèche rapide le long de la ligne rouge verrouillée
                    if projectilePool then
                        local p = projectilePool:obtain()
                        if p then
                            p:spawn(dummy.x, dummy.y - 4, dummy.targetDirX, dummy.targetDirY, {
                                projectile_speed = 320,
                                damage = 18,
                                range = 520,
                                radius = 3.2,
                                color = { 1.0, 0.18, 0.18, 1.0 }
                            }, false, 0, true)
                        end
                    end

                    dummy.aiState = "idle"
                    dummy.telegraphActive = false
                    dummy.aimLocked = false
                    dummy.cooldown = 1.8 * (dummy.attackRateMult or 1)
                end

            elseif dummy.aiState == "idle" then
                dummy.telegraphActive = false
                -- Recul tactique (kiting) si le joueur s'approche trop près (< 85px)
                if dist < 85 then
                    local backVx = -dirX * (dummy.speed * 0.8)
                    local backVy = -dirY * (dummy.speed * 0.8)
                    Physics.moveAndSlide(dummy, backVx, backVy, dt, dummy.radius, obstacleManager, false, mapW, mapH)
                end
            end
        end

    -- ------------------------------------------------------------------------
    -- ARCHÉTYPE 3 : SPREAD RANGED (Plante cracheuse 3-way / Golem en étoile)
    -- ------------------------------------------------------------------------
    elseif mType == "plant" or mType == "golem" or mType == "lava_titan"
        or mType == "wisp" or mType == "storm_drake" then
        -- Feu follet : crache comme la plante. Drake des tempêtes : boss de type golem.
        local isGolem = (mType == "golem" or mType == "lava_titan" or mType == "storm_drake")

        if isGolem then
            -- Le golem avance lentement vers le joueur quand il n'attaque pas
            if dummy.aiState ~= "aim" then
                Physics.steerAroundObstacle(dummy, player.x, player.y, dummy.speed, dt, dummy.radius, obstacleManager, false, mapW, mapH)
            end
        end

        if dummy.cooldown <= 0 and dummy.aiState ~= "aim" then
            -- RÈGLE D'OR : S'ARRÊTE pour préparer la salve
            dummy.aiState = "aim"
            dummy.stateTimer = isGolem and 0.50 or 0.40
            dummy.targetDirX = dirX
            dummy.targetDirY = dirY
            dummy.telegraphActive = true
        end

        if dummy.aiState == "aim" then
            dummy.stateTimer = dummy.stateTimer - dt
            if dummy.stateTimer <= 0 then
                if projectilePool then
                    if isGolem then
                        -- Salve en étoile à 4 ou 8 tirs radiaux
                        local numShots = dummy.isBoss and (dummy.isEnraged and 12 or 8) or 4
                        local step = (math.pi * 2) / numShots
                        for i = 1, numShots do
                            local ang = (i - 1) * step
                            local p = projectilePool:obtain()
                            if p then
                                p:spawn(dummy.x, dummy.y, math.cos(ang), math.sin(ang), {
                                    projectile_speed = 165,
                                    damage = 16,
                                    range = 460,
                                    radius = 4.0,
                                    color = { 1.0, 0.45, 0.15, 1.0 }
                                }, false, 0, true)
                            end
                        end
                    else
                        -- Plante : Salve lente en éventail de 3 tirs frontaux (-18°, 0°, +18°)
                        local baseAng = math.atan2(dirY, dirX)
                        local spreadAngles = { baseAng - 0.28, baseAng, baseAng + 0.28 }
                        for _, ang in ipairs(spreadAngles) do
                            local p = projectilePool:obtain()
                            if p then
                                p:spawn(dummy.x, dummy.y, math.cos(ang), math.sin(ang), {
                                    projectile_speed = 175,
                                    damage = 12,
                                    range = 420,
                                    radius = 3.5,
                                    color = { 0.95, 0.25, 0.35, 1.0 }
                                }, false, 0, true)
                            end
                        end
                    end
                end

                dummy.aiState = "idle"
                dummy.telegraphActive = false
                dummy.cooldown = (isGolem and 2.4 or 1.8) * (dummy.attackRateMult or 1)
            end
        end

    -- ------------------------------------------------------------------------
    -- ARCHÉTYPE 4 : BOMBERS (Projectiles lobés en cloche par-dessus les murs)
    -- ------------------------------------------------------------------------
    elseif mType == "bomber" then
        -- Maintient une distance moyenne
        if dummy.aiState == "chase" or dummy.aiState == "idle" then
            dummy.telegraphActive = false
            if dist < 120 then
                -- Trop près : recul
                local backVx = -dirX * dummy.speed
                local backVy = -dirY * dummy.speed
                Physics.moveAndSlide(dummy, backVx, backVy, dt, dummy.radius, obstacleManager, true, mapW, mapH)
            elseif dist > 180 then
                -- Trop loin : rapprochement
                Physics.steerAroundObstacle(dummy, player.x, player.y, dummy.speed, dt, dummy.radius, obstacleManager, true, mapW, mapH)
            end

            if dummy.cooldown <= 0 then
                -- RÈGLE D'OR : S'ARRÊTE et commence le lancement de la bombe
                dummy.aiState = "aim"
                dummy.stateTimer = 0.35
                dummy.targetX = player.x
                dummy.targetY = player.y
                dummy.telegraphActive = true
            end

        elseif dummy.aiState == "aim" then
            -- S'arrête pendant le jet
            dummy.stateTimer = dummy.stateTimer - dt
            if dummy.stateTimer <= 0 then
                -- Lancement du projectile lobé vers la position T du joueur !
                if projectilePool then
                    local p = projectilePool:obtain()
                    if p then
                        p:spawnLobbed(dummy.x, dummy.y - 6, dummy.targetX, dummy.targetY, 1.35, 20, 30, {0.85, 0.25, 0.95, 1.0})
                    end
                end

                dummy.aiState = "idle"
                dummy.telegraphActive = false
                dummy.cooldown = 2.4 * (dummy.attackRateMult or 1)
            end
        end

    -- ------------------------------------------------------------------------
    -- ARCHÉTYPE 5 : HIDDEN / BURROWERS (Ver de terre sous-sol invincible)
    -- ------------------------------------------------------------------------
    elseif mType == "burrower" then
        dummy.telegraphActive = false

        if dummy.aiState == "burrowed" then
            -- 1. SOUS TERRE : Invincible, hitbox désactivée
            dummy.isBurrowed = true
            dummy.stateTimer = dummy.stateTimer - dt

            -- Se déplace sous terre vers un angle tactique autour du joueur
            Physics.steerAroundObstacle(dummy, player.x, player.y, dummy.speed * 1.1, dt, dummy.radius, obstacleManager, true, mapW, mapH)

            if dummy.stateTimer <= 0 then
                -- Déclenchement de l'émergence
                dummy.aiState = "emerging"
                dummy.stateTimer = 0.35
            end

        elseif dummy.aiState == "emerging" then
            -- 2. ÉMERGENCE : La terre s'ouvre, le ver surgit
            dummy.stateTimer = dummy.stateTimer - dt
            if dummy.stateTimer <= 0 then
                dummy.isBurrowed = false -- DEVIENT VULNÉRABLE !
                dummy.aiState = "surface"
                dummy.stateTimer = 1.20
                dummy.hasFired = false
            end

        elseif dummy.aiState == "surface" then
            -- 3. À LA SURFACE : Vulnérable, s'arrête et crache un projectile
            dummy.stateTimer = dummy.stateTimer - dt

            if not dummy.hasFired and dummy.stateTimer <= 0.85 then
                dummy.hasFired = true
                if projectilePool then
                    local p = projectilePool:obtain()
                    if p then
                        p:spawn(dummy.x, dummy.y, dirX, dirY, {
                            projectile_speed = 210,
                            damage = 14,
                            range = 440,
                            radius = 3.5,
                            color = { 0.88, 0.40, 0.12, 1.0 }
                        }, false, 0, true)
                    end
                end
            end

            if dummy.stateTimer <= 0 then
                -- Replongée sous terre
                dummy.aiState = "burrowing"
                dummy.stateTimer = 0.30
            end

        elseif dummy.aiState == "burrowing" then
            -- 4. REPLONGÉE
            dummy.stateTimer = dummy.stateTimer - dt
            if dummy.stateTimer <= 0 then
                dummy.isBurrowed = true
                dummy.aiState = "burrowed"
                dummy.stateTimer = 2.2 -- Reste sous terre pendant 2.2s
            end
        end

    -- ------------------------------------------------------------------------
    -- ARCHÉTYPE 6 : SPLITTERS (Gros Slime de mêlée lent qui se divise à la mort)
    -- ------------------------------------------------------------------------
    -- ------------------------------------------------------------------------
    -- ARCHÉTYPE 6 : INVOCATEUR (tient ses distances et appelle des renforts)
    -- ------------------------------------------------------------------------
    elseif mType == "summoner" then
        if dummy.aiState ~= "summon" then
            if dist < 150 then
                Physics.moveAndSlide(dummy, -dirX * dummy.speed, -dirY * dummy.speed, dt, dummy.radius, obstacleManager, false, mapW, mapH)
            elseif dist > 210 then
                Physics.moveAndSlide(dummy, dirX * dummy.speed, dirY * dummy.speed, dt, dummy.radius, obstacleManager, false, mapW, mapH)
            end
            if dummy.cooldown <= 0 then
                dummy.aiState = "summon"
                dummy.stateTimer = 0.85
                dummy.telegraphActive = true
                dummy.cooldown = 6.0 * (dummy.attackRateMult or 1)
            end
        else
            dummy.stateTimer = dummy.stateTimer - dt
            if dummy.stateTimer <= 0 then
                dummy.aiState = "idle"
                dummy.telegraphActive = false
                if dummyPool then
                    for i = 1, 2 do
                        local minion = dummyPool:obtain()
                        if minion then
                            local ang = math.random() * math.pi * 2
                            minion:spawn(dummy.x + math.cos(ang) * 26, dummy.y + math.sin(ang) * 26,
                                math.floor((dummy.maxHp or 60) * 0.35), "mini_slime")
                            VFX.addSparks(minion.x, minion.y, 6, { 0.45, 0.95, 0.35, 1.0 })
                        end
                    end
                    VFX.shakeLight()
                end
            end
        end

    -- ------------------------------------------------------------------------
    -- ARCHÉTYPE 7 : TOURELLE DE PIERRE (immobile, salves croisées)
    -- ------------------------------------------------------------------------
    elseif mType == "turret" then
        if dummy.cooldown <= 0 then
            dummy.aiState = "aim"
            dummy.stateTimer = 0.5
            dummy.telegraphActive = true
            dummy.cooldown = 2.4 * (dummy.attackRateMult or 1)
        end
        if dummy.aiState == "aim" then
            dummy.stateTimer = dummy.stateTimer - dt
            if dummy.stateTimer <= 0 then
                dummy.aiState = "idle"
                dummy.telegraphActive = false
                dummy.volleyPhase = ((dummy.volleyPhase or 0) + 1) % 2
                if projectilePool then
                    local offset = (dummy.volleyPhase == 1) and (math.pi / 4) or 0
                    for i = 0, 3 do
                        local ang = offset + i * (math.pi / 2)
                        local p = projectilePool:obtain()
                        if p then
                            p:spawn(dummy.x, dummy.y - 2, math.cos(ang), math.sin(ang), {
                                projectile_speed = 190, damage = 14, range = 420, radius = 3.4,
                                color = { 1.0, 0.55, 0.15, 1.0 },
                            }, false, 0, true)
                        end
                    end
                end
            end
        end

    -- ------------------------------------------------------------------------
    -- ARCHÉTYPE 8 : MAGE TÉLÉPORTEUR & SORCIÈRE (clignote puis lance des orbes)
    -- ------------------------------------------------------------------------
    elseif mType == "mage" or mType == "witch" or mType == "frost_wraith" or mType == "void_watcher" then
        -- Spectre givré : mage clignotant. Œil du Vide : boss, gerbe d'orbes comme la sorcière.
        local isWitch = (mType == "witch" or mType == "void_watcher")
        dummy.blinkTimer = (dummy.blinkTimer or 3.0) - dt
        if dummy.blinkTimer <= 0 then
            dummy.blinkTimer = isWitch and 2.6 or 3.4
            VFX.addSparks(dummy.x, dummy.y, 8, { 0.65, 0.35, 1.0, 1.0 })
            local ang = math.random() * math.pi * 2
            local radius = 110 + math.random() * 70
            local nx = math.max(30, math.min((mapW or 640) - 30, player.x + math.cos(ang) * radius))
            local ny = math.max(40, math.min((mapH or 480) - 30, player.y + math.sin(ang) * radius))
            if not (obstacleManager and obstacleManager:isBlocked(nx, ny, dummy.radius)) then
                dummy.x, dummy.y = nx, ny
                VFX.addSparks(nx, ny, 10, { 0.35, 0.85, 1.0, 1.0 })
            end
        end

        if dummy.cooldown <= 0 then
            dummy.aiState = "aim"
            dummy.stateTimer = 0.55
            dummy.telegraphActive = true
            dummy.targetDirX, dummy.targetDirY = dirX, dirY
            dummy.cooldown = (isWitch and 2.4 or 2.0) * (dummy.attackRateMult or 1)
        end
        if dummy.aiState == "aim" then
            dummy.stateTimer = dummy.stateTimer - dt
            if dummy.stateTimer <= 0 then
                dummy.aiState = "idle"
                dummy.telegraphActive = false
                if projectilePool then
                    local shots = isWitch and 5 or 1
                    local spread = 0.32
                    for i = 1, shots do
                        local a = math.atan2(dummy.targetDirY, dummy.targetDirX) + (i - (shots + 1) / 2) * spread
                        local p = projectilePool:obtain()
                        if p then
                            p:spawn(dummy.x, dummy.y - 6, math.cos(a), math.sin(a), {
                                projectile_speed = isWitch and 215 or 240, damage = isWitch and 20 or 16,
                                range = 480, radius = 3.6, color = { 0.65, 0.35, 1.0, 1.0 },
                            }, false, 0, true)
                        end
                    end
                end
                -- La sorcière appelle des chauves-souris
                if isWitch and dummyPool and (dummy.summonTimer or 0) <= 0 then
                    dummy.summonTimer = 8.0
                    for i = 1, 2 do
                        local minion = dummyPool:obtain()
                        if minion then
                            minion:spawn(dummy.x + (i == 1 and -30 or 30), dummy.y + 10,
                                math.floor((dummy.maxHp or 200) * 0.12), "bat")
                        end
                    end
                end
            end
        end
        dummy.summonTimer = math.max(0, (dummy.summonTimer or 0) - dt)

    -- ------------------------------------------------------------------------
    -- ARCHÉTYPE 9 : ROI SQUELETTE (avance, salve de 3 flèches, renforts en rage)
    -- ------------------------------------------------------------------------
    elseif mType == "skeleton_king" then
        if dummy.aiState ~= "aim" and dist > 140 then
            Physics.moveAndSlide(dummy, dirX * dummy.speed, dirY * dummy.speed, dt, dummy.radius, obstacleManager, false, mapW, mapH)
        end
        if dummy.cooldown <= 0 then
            dummy.aiState = "aim"
            dummy.stateTimer = 0.9
            dummy.telegraphActive = true
            dummy.targetDirX, dummy.targetDirY = dirX, dirY
            dummy.cooldown = 2.6 * (dummy.attackRateMult or 1)
        end
        if dummy.aiState == "aim" then
            dummy.stateTimer = dummy.stateTimer - dt
            dummy.aimLocked = dummy.stateTimer <= 0.3
            if not dummy.aimLocked then
                dummy.targetDirX, dummy.targetDirY = dirX, dirY
            end
            if dummy.stateTimer <= 0 then
                dummy.aiState = "idle"
                dummy.telegraphActive = false
                dummy.aimLocked = false
                if projectilePool then
                    local baseAng = math.atan2(dummy.targetDirY, dummy.targetDirX)
                    local shots = dummy.isEnraged and 5 or 3
                    for i = 1, shots do
                        local a = baseAng + (i - (shots + 1) / 2) * 0.22
                        local p = projectilePool:obtain()
                        if p then
                            p:spawn(dummy.x, dummy.y - 8, math.cos(a), math.sin(a), {
                                projectile_speed = 300, damage = 22, range = 520, radius = 3.4,
                                color = { 1.0, 0.85, 0.35, 1.0 },
                            }, false, 0, true)
                        end
                    end
                end
                -- Renforts squelettes quand le roi est enragé
                if dummy.isEnraged and dummyPool and (dummy.summonTimer or 0) <= 0 then
                    dummy.summonTimer = 7.0
                    for i = 1, 2 do
                        local minion = dummyPool:obtain()
                        if minion then
                            minion:spawn(dummy.x + (i == 1 and -34 or 34), dummy.y + 16,
                                math.floor((dummy.maxHp or 300) * 0.12), "skeleton")
                        end
                    end
                    VFX.shakeMedium()
                end
            end
        end
        dummy.summonTimer = math.max(0, (dummy.summonTimer or 0) - dt)

    elseif mType == "splitter" or mType == "mini_slime" or mType == "slime" then
        local isSplitter = (mType == "splitter")
        local isMini = (mType == "mini_slime")

        -- Poursuite au sol avec glissade vectorielle
        Physics.steerAroundObstacle(dummy, player.x, player.y, dummy.speed, dt, dummy.radius, obstacleManager, false, mapW, mapH)

        -- Dégâts de contact
        if dist < (dummy.radius + player.radius) then
            if dummy.cooldown <= 0 then
                local dmg = isSplitter and 18 or (isMini and 8 or 12)
                player.hp = math.max(0, player.hp - dmg)
                VFX.triggerHitFlash(player, 3)
                VFX.shakeMedium()
                VFX.addFCT(player.x, player.y - 12, dmg, false)
                VFX.addSparks(player.x, player.y, 6, {1, 0.2, 0.2, 1})
                dummy.cooldown = 1.0 -- Cooldown de contact pour ne pas one-shot
            end
        end
    end

    return true
end

-- ============================================================================
-- 2. DEATH HOOK DES ARCHÉTYPES (Ex: Division des Splitters en 2 Mini-Slimes)
-- ============================================================================
function AIController.onDeath(dummy, dummyPool, fctPool)
    if dummy.type == "splitter" and dummyPool then
        -- Instancie 2 versions plus petites et plus rapides depuis le Pool (ZÉRO GC)
        local mini1 = dummyPool:obtain()
        if mini1 then
            mini1:spawn(dummy.x - 12, dummy.y, math.floor(dummy.maxHp * 0.45), "mini_slime")
            mini1.speed = 68
            mini1.radius = 7.5
        end

        local mini2 = dummyPool:obtain()
        if mini2 then
            mini2:spawn(dummy.x + 12, dummy.y, math.floor(dummy.maxHp * 0.45), "mini_slime")
            mini2.speed = 68
            mini2.radius = 7.5
        end

        if fctPool then
            local f = fctPool:obtain()
            if f then f:spawn(dummy.x, dummy.y - 12, "SPLIT!", false) end
        end
    end
end

-- ============================================================================
-- 3. RENDU DU TELEGRAPHING (Ligne laser pour snipers, cercle AoE mortier, anticipation)
-- ============================================================================
function AIController.drawTelegraph(dummy, playerX, playerY)
    local t = love.timer.getTime()
    local mType = dummy.type or "slime"

    -- 1. SQUELETTE ARCHER : LIGNE ROUGE DE VISÉE LASER (PULSANTE 0.3-0.8 -> VERROUILLÉE 1.0)
    if mType == "skeleton" and (dummy.aiState == "aim" or dummy.telegraphActive) then
        local targetX, targetY
        local isLocked = (dummy.aimLocked == true)
        if isLocked and dummy.targetDirX and dummy.targetDirY then
            -- Ligne verrouillée (phase finale d'anticipation)
            targetX = dummy.x + dummy.targetDirX * 360
            targetY = dummy.y + dummy.targetDirY * 360
        else
            -- Ligne dynamique suivant le joueur
            targetX = playerX
            targetY = playerY
        end

        VFX.drawSniperLine(dummy.x, dummy.y - 4, targetX, targetY, isLocked)

        -- Indicateur "!" d'alerte rouge
        love.graphics.setColor(1.0, 0.18, 0.18, 1.0)
        love.graphics.circle("fill", dummy.x, dummy.y - 24, 6)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("!", dummy.x - 2, dummy.y - 30)

    -- 2. BOMBER : CERCLE DE MORTIER AU SOL EN EXPANSION
    elseif mType == "bomber" and (dummy.aiState == "aim" or dummy.telegraphActive) then
        local progress = math.min(1.0, math.max(0, (0.35 - (dummy.stateTimer or 0)) / 0.35))
        VFX.drawBombTelegraph(dummy.targetX or playerX, dummy.targetY or playerY, 28, progress)

    -- 3. MELEE CHARGERS : FLÈCHE ROUGE D'ANTICIPATION DU DASH (0.2s)
    elseif (mType == "wolf" or mType == "bat" or mType == "raven" or mType == "gargoyle") and dummy.aiState == "aim" then

        local len = (mType == "wolf" or mType == "gargoyle") and 55 or 45
        local endX = dummy.x + (dummy.targetDirX or 1) * len
        local endY = dummy.y + (dummy.targetDirY or 0) * len

        love.graphics.setColor(1.0, 0.20, 0.20, 0.75)
        love.graphics.setLineWidth(2)
        love.graphics.line(dummy.x, dummy.y, endX, endY)
        -- Pointe de flèche
        love.graphics.circle("fill", endX, endY, 3.5)
        love.graphics.setLineWidth(1)

    -- 4. HIDDEN / BURROWER : MONTICULE DE TERRE QUAND SOUS TERRE
    elseif mType == "burrower" and dummy.isBurrowed then
        local moundPulse = math.sin(t * 8) * 1.5
        -- Ombre et monticule
        love.graphics.setColor(0.18, 0.12, 0.08, 0.8)
        love.graphics.ellipse("fill", dummy.x, dummy.y + 4, 11 + moundPulse, 6)
        love.graphics.setColor(0.38, 0.26, 0.16, 1.0)
        love.graphics.ellipse("fill", dummy.x, dummy.y + 2, 9, 4.5)
        -- Petits éclats de roche/poussière
        love.graphics.setColor(0.55, 0.40, 0.25, 0.9)
        love.graphics.circle("fill", dummy.x - 4, dummy.y, 2)
        love.graphics.circle("fill", dummy.x + 5, dummy.y + 1, 1.8)
    end
end

return AIController
