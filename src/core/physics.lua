-- src/core/physics.lua
-- Module physique haute performance pour Nintendo 3DS (LÖVEPotion) & PC Desktop (LÖVE2D)
-- Glissement vectoriel fluide contre les murs (Wall Sliding), détection de collisions
-- et Raycasting de Ligne de Vue (Line of Sight) sans aucune allocation mémoire dans la boucle

local Physics = {}

-- Test d'intersection Cercle vs Boîte Rectangulaire AABB
function Physics.circleIntersectsRect(cx, cy, radius, rx, ry, rw, rh)
    local closestX = math.max(rx, math.min(cx, rx + rw))
    local closestY = math.max(ry, math.min(cy, ry + rh))
    local dx = cx - closestX
    local dy = cy - closestY
    return (dx * dx + dy * dy) < (radius * radius)
end

-- Test de collision AABB vs AABB
function Physics.checkAABB(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and
           x1 + w1 > x2 and
           y1 < y2 + h2 and
           y1 + h1 > y2
end

local LOS_RADIUS = 2       -- rayon de l'échantillon de visée
local losCandidates = {}   -- rochers proches du segment (réutilisé : aucune allocation)

-- Raycasting optimisé pour la Ligne de Vue (Line of Sight)
-- Vérifie si un tir direct est obstrué par des rochers ou des parois
function Physics.checkLineOfSight(x1, y1, x2, y2, obstacleManager)
    if not obstacleManager or not obstacleManager.rocks or #obstacleManager.rocks == 0 then
        return true
    end

    local dx = x2 - x1
    local dy = y2 - y1
    local distSq = dx * dx + dy * dy
    if distSq < 144 then return true end -- Moins de 12px : contact direct

    local dist = math.sqrt(distSq)
    local steps = math.floor(dist / 14)
    if steps <= 1 then return true end

    -- Seuls les rochers qui touchent la boîte englobante du segment (élargie du rayon de
    -- l'échantillon) peuvent bloquer : on ne teste qu'eux à chaque pas (souvent aucun)
    local rocks = obstacleManager.rocks
    local minX, maxX = math.min(x1, x2) - LOS_RADIUS, math.max(x1, x2) + LOS_RADIUS
    local minY, maxY = math.min(y1, y2) - LOS_RADIUS, math.max(y1, y2) + LOS_RADIUS
    local n = 0
    for i = 1, #rocks do
        local r = rocks[i]
        if r.x < maxX and r.x + r.w > minX and r.y < maxY and r.y + r.h > minY then
            n = n + 1
            losCandidates[n] = r
        end
    end
    if n == 0 then return true end

    local stepX = dx / steps
    local stepY = dy / steps
    local hit = obstacleManager.circleIntersectsRect

    for s = 1, steps - 1 do
        local sx = x1 + stepX * s
        local sy = y1 + stepY * s
        for k = 1, n do
            local r = losCandidates[k]
            if hit(sx, sy, LOS_RADIUS, r.x, r.y, r.w, r.h) then
                return false
            end
        end
    end

    return true
end

-- ============================================================================
-- GLISSADE VECTORIELLE CONTRE LES MURS (WALL SLIDING)
-- Décompose le déplacement sur les axes X et Y séparément.
-- Si l'axe X heurte un mur, la composante Y continue de glisser librement, et vice-versa.
-- ============================================================================
function Physics.moveAndSlide(entity, vx, vy, dt, radius, obstacleManager, allowFlight, mapW, mapH, isGateOpen)
    radius = radius or entity.radius or 10
    local minX = 20 + radius
    local maxX = (mapW or 640) - 20 - radius
    local minY = 34 + radius
    local maxY = (mapH or 480) - 20 - radius

    -- Si la porte nord est ouverte, permet à l'entité de s'engager dans l'arche au nord
    local gateCenterX = (mapW or 640) / 2
    if isGateOpen and math.abs(entity.x - gateCenterX) <= 28 then
        minY = 14 + radius
    end

    local nextX = entity.x + vx * dt
    local nextY = entity.y + vy * dt

    local blockedX = false
    local blockedY = false

    -- 1. Test de l'axe X seul
    if nextX < minX or nextX > maxX then
        blockedX = true
        nextX = math.max(minX, math.min(maxX, nextX))
    elseif obstacleManager and obstacleManager:isBlocked(nextX, entity.y, radius, allowFlight, entity.canGhostWalk) then
        blockedX = true
        nextX = entity.x
    end

    -- 2. Test de l'axe Y seul
    if nextY < minY or nextY > maxY then
        blockedY = true
        nextY = math.max(minY, math.min(maxY, nextY))
    elseif obstacleManager and obstacleManager:isBlocked(entity.x, nextY, radius, allowFlight, entity.canGhostWalk) then
        blockedY = true
        nextY = entity.y
    end

    -- 3. Application du mouvement glissé
    entity.x = nextX
    entity.y = nextY

    -- 4. Retourne les axes bloqués pour la gestion de l'accélération
    return blockedX, blockedY
end

-- Steering d'évitement tangentiel doux pour les monstres qui butent sur un obstacle
function Physics.steerAroundObstacle(entity, targetX, targetY, speed, dt, radius, obstacleManager, allowFlight, mapW, mapH)
    local dx = targetX - entity.x
    local dy = targetY - entity.y
    local dist = math.sqrt(dx * dx + dy * dy)
    if dist < 0.1 then return 0, 0 end

    local dirX = dx / dist
    local dirY = dy / dist

    local vx = dirX * speed
    local vy = dirY * speed

    local blockedX, blockedY = Physics.moveAndSlide(entity, vx, vy, dt, radius, obstacleManager, allowFlight, mapW, mapH)

    -- Si bloqué dans la direction directe, glisse tangentiellement (steering)
    if blockedX and not blockedY then
        entity.y = entity.y + (dirY >= 0 and 1 or -1) * speed * dt * 0.6
    elseif blockedY and not blockedX then
        entity.x = entity.x + (dirX >= 0 and 1 or -1) * speed * dt * 0.6
    end

    return dirX, dirY
end

return Physics
