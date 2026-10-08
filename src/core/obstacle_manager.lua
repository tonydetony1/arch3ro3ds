-- src/core/obstacle_manager.lua
-- Gestionnaire des obstacles tactiques (Rochers, Eau/Trous, Pièges à pics)
-- Système de couverture contre les projectiles et contraintes de déplacement.
-- Les dispositions viennent des grilles dessinées de src/data/rooms.lua.

local Audio = require("src.audio.audio")
local Balance = require("src.data.balance")
local Rooms = require("src.data.rooms")
local Physics = require("src.core.physics")

local WIND_PUSH = 120 -- px/s, gusts of the sky world

local ObstacleManager = {}
ObstacleManager.__index = ObstacleManager

function ObstacleManager.new()
    local self = setmetatable({}, ObstacleManager)
    self.rocks = {}      -- { x, y, w, h } : Bloquent entités ET détruisent projectiles
    self.waters = {}     -- { x, y, w, h } : Bloquent sol, mais tirs et monstres volants passent
    self.spikes = {}     -- { x, y, w, h, timer, state } : Pics au sol cycliques
    self.barrels = {}    -- { x, y, radius, isExploded } : Barils explosifs interactifs
    self.pots = {}       -- { x, y, radius, broken } : Urnes destructibles (cœurs / or)
    self.hazards = {}    -- { x, y, w, h, kind } : sable mouvant, glace, lave
    self.spikeCycle = 2.0 -- 2 secondes par cycle
    self.trapCooldown = 0
    return self
end

-- Zones dangereuses du chapitre : sables mouvants, plaques de glace, mares de lave
local HAZARD_KIND = { sand = "sand", ice = "ice", lava = "lava", wind = "wind", void = "void" }
local LAVA_MONSTER_TICK = 0.6   -- seconds between two burns of a monster standing in lava
local LAVA_MONSTER_DAMAGE = 12
local SPIKE_INSET = 3
local STUMP_SIZE = 40
local HAZARD_INSET = 2

-- Construction de la salle à partir d'une grille dessinée (src/data/rooms.lua).
-- `kind` : "combat" (défaut), "arena" ou "sanctuary" ; `layout` force une grille précise.
function ObstacleManager:generate(mapW, mapH, roomNumber, kind, layout, world)
    self.roomNumber = roomNumber or 1
    self.mapW, self.mapH = mapW, mapH
    self.rocks = {}
    self.pots = {}
    self.hazards = {}
    self.waters = {}
    self.spikes = {}
    self.barrels = {}
    self.spawnPoints = {}
    self.trapCooldown = 0

    local mirrored = false
    if not layout then
        layout, mirrored = Rooms.pick(kind or "combat", self.roomNumber, world)
    end
    self.layoutId = layout.id
    self.layoutMirrored = mirrored
    local parsed = Rooms.parse(mirrored and Rooms.mirror(layout.grid) or layout.grid)

    local cell, ox, oy = Rooms.fit(mapW, mapH)
    local function toRect(r, inset)
        return { x = ox + (r.col - 1) * cell + inset, y = oy + (r.row - 1) * cell + inset,
                 w = r.w * cell - inset * 2, h = r.h * cell - inset * 2 }
    end
    local function toPoint(p)
        return ox + (p.col - 0.5) * cell, oy + (p.row - 0.5) * cell
    end

    for _, r in ipairs(parsed.rocks) do
        local rock
        if r.w == 1 and r.h == 1 and #self.rocks % 2 == 0 then
            -- Souche d'arbre : sprite de 40 px, la collision suit le sprite (pas la case)
            rock = toRect(r, math.floor((cell - STUMP_SIZE) / 2))
            rock.stump = true
        else
            rock = toRect(r, 0)
        end
        self.rocks[#self.rocks + 1] = rock
    end
    for _, r in ipairs(parsed.waters) do
        -- Case entière : la berge est peinte à l'intérieur, côté terre (voir bakeWater)
        local wtr = toRect(r, 0)
        wtr.cells, wtr.shapeKey, wtr.cell = r.cells, r.shapeKey, cell
        self.waters[#self.waters + 1] = wtr
    end
    for i, r in ipairs(parsed.spikes) do
        local s = toRect(r, SPIKE_INSET)
        s.timer = (i % 2) * 1.0 -- plaques voisines déphasées : on passe entre deux cycles
        self.spikes[#self.spikes + 1] = s
    end
    local hazardKind = HAZARD_KIND[self.hazardKind or ""]
    if hazardKind then
        for _, r in ipairs(parsed.hazards) do
            local hz = toRect(r, HAZARD_INSET)
            hz.kind = hazardKind
            if hazardKind == "wind" then
                -- Chaque bourrasque souffle dans une direction propre
                local angle = ((#self.hazards * 2.3) % 6.28)
                hz.windX = math.cos(angle)
                hz.windY = math.sin(angle) * 0.6
            end
            self.hazards[#self.hazards + 1] = hz
        end
    end
    for _, p in ipairs(parsed.barrels) do
        local x, y = toPoint(p)
        self.barrels[#self.barrels + 1] = { x = x, y = y, radius = 9, isExploded = false }
    end
    for _, p in ipairs(parsed.pots) do
        local x, y = toPoint(p)
        self.pots[#self.pots + 1] = { x = x, y = y, radius = 7, broken = false }
    end
    for _, p in ipairs(parsed.spawns) do
        local x, y = toPoint(p)
        self.spawnPoints[#self.spawnPoints + 1] = { x = x, y = y }
    end
end

-- Placement des monstres : les repères "m" de la grille d'abord (en tournant selon la
-- salle), puis repli sur la place libre la plus proche. Le boss garde sa position.
local SPAWN_CLEARANCE = 14
local SEARCH_STEP = 10
local SEARCH_MAX = 200
local SEARCH_DIRS = 12
local EDGE_MARGIN = 30

function ObstacleManager:findFreeSpot(x, y, radius)
    local mapW, mapH = self.mapW or 640, self.mapH or 480
    local function fits(px, py)
        return px >= EDGE_MARGIN and px <= mapW - EDGE_MARGIN
           and py >= EDGE_MARGIN + 14 and py <= mapH - EDGE_MARGIN
           and not self:isBlocked(px, py, radius)
    end
    if fits(x, y) then return x, y end
    for dist = SEARCH_STEP, SEARCH_MAX, SEARCH_STEP do
        for k = 0, SEARCH_DIRS - 1 do
            local a = k * (math.pi * 2 / SEARCH_DIRS)
            local nx, ny = x + math.cos(a) * dist, y + math.sin(a) * dist
            if fits(nx, ny) then return nx, ny end
        end
    end
    return x, y
end

function ObstacleManager:placeSpawns(spawns)
    local points = self.spawnPoints or {}
    local offset = (self.roomNumber or 1) % math.max(1, #points)
    local used = 0
    local placed = {}
    for i, sp in ipairs(spawns) do
        local copy = {}
        for k, v in pairs(sp) do copy[k] = v end
        if not sp.isBoss and used < #points then
            local p = points[(offset + used) % #points + 1]
            copy.x, copy.y = p.x, p.y
            used = used + 1
        end
        copy.x, copy.y = self:findFreeSpot(copy.x, copy.y, SPAWN_CLEARANCE)
        placed[i] = copy
    end
    return placed
end

-- Test de collision cercle vs boîte AABB. Rejet immédiat si les boîtes englobantes ne se
-- touchent pas (le cas courant : appelé pour chaque rocher, chaque projectile, chaque image) ;
-- sinon distance au point le plus proche. Même résultat que le seul calcul de distance.
local function circleIntersectsRect(cx, cy, radius, rx, ry, rw, rh)
    local rx2, ry2 = rx + rw, ry + rh
    if cx + radius <= rx or cx - radius >= rx2 or cy + radius <= ry or cy - radius >= ry2 then
        return false
    end
    local px = (cx < rx) and rx or ((cx > rx2) and rx2 or cx)
    local py = (cy < ry) and ry or ((cy > ry2) and ry2 or cy)
    local dx, dy = cx - px, cy - py
    return (dx * dx + dy * dy) < (radius * radius)
end
ObstacleManager.circleIntersectsRect = circleIntersectsRect

-- Test si un point/cercle est bloqué dans le décor
function ObstacleManager:isBlocked(x, y, radius, allowFlight, allowGhost)
    if allowGhost then return false end
    radius = radius or 8

    -- 1. Rochers : bloquent les entités ordinaires
    for _, r in ipairs(self.rocks) do
        if circleIntersectsRect(x, y, radius, r.x, r.y, r.w, r.h) then
            return true, "rock"
        end
    end

    -- 2. Eau : bloque les entités terrestres, mais les volants (chauves-souris) survolent
    if not allowFlight then
        for _, w in ipairs(self.waters) do
            if circleIntersectsRect(x, y, radius, w.x, w.y, w.w, w.h) then
                return true, "water"
            end
        end
    end

    -- 3. Barils explosifs : bloquent les entités tant qu'ils ne sont pas explosés
    for _, b in ipairs(self.barrels) do
        if not b.isExploded then
            local dx = x - b.x
            local dy = y - b.y
            local combined = radius + b.radius
            if (dx * dx + dy * dy) < (combined * combined) then
                return true, "barrel"
            end
        end
    end

    return false
end

-- Test si un projectile est arrêté (SEULS les rochers détruisent les projectiles, pas l'eau !)
function ObstacleManager:blocksProjectile(x, y, radius)
    radius = radius or 3
    local rocks = self.rocks
    for i = 1, #rocks do
        local r = rocks[i]
        if circleIntersectsRect(x, y, radius, r.x, r.y, r.w, r.h) then
            return true
        end
    end
    return false
end

-- Segment against an axis-aligned box (slab method): no allocation, called per rock and per
-- candidate target while the hero aims
local function segmentHitsBox(x0, y0, dx, dy, bx0, by0, bx1, by1)
    local tmin, tmax = 0, 1
    if dx == 0 then
        if x0 < bx0 or x0 > bx1 then return false end
    else
        local inv = 1 / dx
        local t1, t2 = (bx0 - x0) * inv, (bx1 - x0) * inv
        if t1 > t2 then t1, t2 = t2, t1 end
        if t1 > tmin then tmin = t1 end
        if t2 < tmax then tmax = t2 end
        if tmin > tmax then return false end
    end
    if dy == 0 then
        if y0 < by0 or y0 > by1 then return false end
    else
        local inv = 1 / dy
        local t1, t2 = (by0 - y0) * inv, (by1 - y0) * inv
        if t1 > t2 then t1, t2 = t2, t1 end
        if t1 > tmin then tmin = t1 end
        if t2 < tmax then tmax = t2 end
        if tmin > tmax then return false end
    end
    return tmin -- where along the segment (0..1) it first enters the box; a number is truthy
end

-- Test if a shot flying from (x0, y0) to (x1, y1) is stopped by a rock on the way (only rocks
-- stop projectiles). Used by the hero's auto-aim to skip monsters hiding behind cover.
function ObstacleManager:isShotBlocked(x0, y0, x1, y1, radius)
    radius = radius or 3
    local dx, dy = x1 - x0, y1 - y0
    local minX, maxX = x0, x1
    if minX > maxX then minX, maxX = maxX, minX end
    local minY, maxY = y0, y1
    if minY > maxY then minY, maxY = maxY, minY end

    local rocks = self.rocks
    for i = 1, #rocks do
        local r = rocks[i]
        local bx0, by0 = r.x - radius, r.y - radius
        local bx1, by1 = r.x + r.w + radius, r.y + r.h + radius
        -- cheap reject on the bounding boxes first: most rocks are nowhere near the line
        if maxX >= bx0 and minX <= bx1 and maxY >= by0 and minY <= by1
            and segmentHitsBox(x0, y0, dx, dy, bx0, by0, bx1, by1) then
            return true
        end
    end
    return false
end

-- How far a shot from (x0, y0) to (x1, y1) gets before the first rock, as a fraction of the
-- segment (1 = it is never stopped). Used to cut the hitscan beam short.
function ObstacleManager:shotReach(x0, y0, x1, y1, radius)
    radius = radius or 3
    local dx, dy = x1 - x0, y1 - y0
    local reach = 1
    local rocks = self.rocks
    for i = 1, #rocks do
        local r = rocks[i]
        local t = segmentHitsBox(x0, y0, dx, dy, r.x - radius, r.y - radius, r.x + r.w + radius, r.y + r.h + radius)
        if t and t < reach then reach = t end
    end
    return reach
end

-- Destruction d'une urne : cœur de soin ou pièces d'or
function ObstacleManager:breakPot(pot, lootPool)
    -- Compte pour les missions "briser des urnes"
    pcall(function() require("src.data.save").addQuestProgress("pots", 1) end)
    pot.broken = true
    local VFX = require("src.render.vfx_manager")
    VFX.shakeLight()
    Audio.play("pot_break", 0.12, 0.7)
    VFX.addSparks(pot.x, pot.y, 8, { 0.72, 0.43, 0.31, 1.0 })
    if not lootPool then return end
    if math.random() < 0.35 then
        local l = lootPool:obtain()
        if l then l:spawn(pot.x, pot.y, "heart", 80) end
    else
        for _ = 1, math.random(2, 3) do
            local l = lootPool:obtain()
            local depth = Balance.depthMultiplier(self.roomNumber)
            if l then l:spawn(pot.x, pot.y, "coin",
                math.floor(math.random(Balance.LOOT.potCoinMin, Balance.LOOT.potCoinMax) * depth + 0.5)) end
        end
    end
end

-- Détection d'impact projectile sur un baril explosif (AoE + Stun + Brûlure) ou une urne
function ObstacleManager:checkProjectileHit(proj, dummyPool, fctPool, player, lootPool)
    for _, pot in ipairs(self.pots) do
        if not pot.broken then
            local dx = proj.x - pot.x
            local dy = proj.y - pot.y
            local hitRad = (proj.radius or 3) + pot.radius
            if (dx * dx + dy * dy) < (hitRad * hitRad) then
                self:breakPot(pot, lootPool)
                return true
            end
        end
    end

    for _, b in ipairs(self.barrels) do
        if not b.isExploded then
            local dx = proj.x - b.x
            local dy = proj.y - b.y
            local hitRad = (proj.radius or 3) + b.radius
            if (dx * dx + dy * dy) < (hitRad * hitRad) then
                b.isExploded = true
                local VFX = require("src.render.vfx_manager")
                Audio.play("explosion", 0.08, 1.0)
                VFX.shakeHeavy()
                VFX.addSparks(b.x, b.y, 14, {1.0, 0.45, 0.1, 1.0})
                if fctPool then
                    local f = fctPool:obtain()
                    if f then f:spawn(b.x, b.y - 12, "BOOM!", true) end
                end

                -- Dégâts de zone (AoE 55px) : 65 dégâts + brûlure aux ennemis proches
                local aoeRadSq = 55 * 55
                if dummyPool and dummyPool.activeCount > 0 then
                    for i = 1, dummyPool.activeCount do
                        local dIdx = dummyPool.activeList[i]
                        local monster = dummyPool.items[dIdx]
                        if monster and monster.alive then
                            local mdx = monster.x - b.x
                            local mdy = monster.y - b.y
                            local distSq = mdx * mdx + mdy * mdy
                            if distSq <= aoeRadSq then
                                local dist = math.max(1, math.sqrt(distSq))
                                monster:takeDamage(65, mdx / dist, mdy / dist, { fire = true })
                                VFX.triggerHitFlash(monster, 3)
                                if fctPool then
                                    local f2 = fctPool:obtain()
                                    if f2 then f2:spawn(monster.x, monster.y - 10, 65, true) end
                                end
                            end
                        end
                    end
                end

                -- Dégâts au joueur s'il est pris dans le souffle (20 dégâts)
                if player then
                    local pdx = player.x - b.x
                    local pdy = player.y - b.y
                    if (pdx * pdx + pdy * pdy) <= aoeRadSq then
                        player:takeDamage(20)
                        VFX.triggerHitFlash(player, 3)
                        if fctPool then
                            local fp = fctPool:obtain()
                            if fp then fp:spawn(player.x, player.y - 12, 20, true) end
                        end
                    end
                end

                return true
            end
        end
    end
    return false
end

-- Mise à jour des pièges et dégâts au joueur ET aux monstres
function ObstacleManager:update(dt, player, fctPool, dummyPool)
    if self.trapCooldown > 0 then
        self.trapCooldown = math.max(0, self.trapCooldown - dt)
    end

    -- Zones dangereuses : sable (ralenti), glace (glissade), lave (brûlures)
    if player then
        player.terrainSpeedMult = 1.0
        player.terrainSlip = 0
    end
    self.lavaCooldown = math.max(0, (self.lavaCooldown or 0) - dt)
    for _, hz in ipairs(self.hazards) do
        if player and circleIntersectsRect(player.x, player.y, player.radius, hz.x, hz.y, hz.w, hz.h) then
            if hz.kind == "sand" then
                player.terrainSpeedMult = 0.55
            elseif hz.kind == "ice" then
                player.terrainSlip = 1.0
            elseif hz.kind == "wind" then
                -- Gust: pushes the hero, through collisions (it used to shove him into rocks)
                Physics.moveAndSlide(player, WIND_PUSH * (hz.windX or 1), WIND_PUSH * (hz.windY or -0.35), dt,
                    player.radius, self, false, (player.maxX or 600) + 22, (player.maxY or 440) + 22)
            elseif hz.kind == "void" and self.lavaCooldown <= 0 then
                -- Faille du Vide : ralentit et grignote les PV
                player.terrainSpeedMult = 0.7
                self.lavaCooldown = 0.75
                local dmg = 10
                local taken = player:takeDamage(dmg)
                if taken and taken > 0 then
                    local VFX = require("src.render.vfx_manager")
                    VFX.triggerHitFlash(player, 2)
                    Audio.play("player_hurt", 0.1, 0.5)
                    if fctPool then
                        local f = fctPool:obtain()
                        if f then f:spawn(player.x, player.y - 12, dmg, true) end
                    end
                end
            elseif hz.kind == "lava" and self.lavaCooldown <= 0 then
                self.lavaCooldown = 0.6
                local dmg = 16
                local taken = player:takeDamage(dmg)
                if taken and taken > 0 then
                    local VFX = require("src.render.vfx_manager")
                    VFX.triggerHitFlash(player, 2)
                    VFX.shakeLight()
                    Audio.play("player_hurt", 0.1, 0.6)
                    if fctPool then
                        local f = fctPool:obtain()
                        if f then f:spawn(player.x, player.y - 12, dmg, true) end
                    end
                end
            end
        end
    end

    -- Lava also burns the ground monsters standing in it. It has its own timer: it used to be
    -- tied to the hero's lava cooldown, so monsters only burned when the hero did.
    self.monsterLavaTimer = (self.monsterLavaTimer or 0) - dt
    if self.monsterLavaTimer <= 0 then
        self.monsterLavaTimer = LAVA_MONSTER_TICK
        if dummyPool and dummyPool.activeCount > 0 then
            for _, hz in ipairs(self.hazards) do
                if hz.kind == "lava" then
                    for i = 1, dummyPool.activeCount do
                        local m = dummyPool.items[dummyPool.activeList[i]]
                        if m and m.alive and not m.isBurrowed and m.type ~= "bat" and m.type ~= "bomber" then
                            if circleIntersectsRect(m.x, m.y, m.radius, hz.x, hz.y, hz.w, hz.h) then
                                m:takeDamage(LAVA_MONSTER_DAMAGE, 0, -1, { fire = true })
                            end
                        end
                    end
                end
            end
        end
    end

    for _, s in ipairs(self.spikes) do
        s.timer = (s.timer + dt) % self.spikeCycle
        -- Les pics sont armés/sortis entre 1.0s et 1.9s du cycle
        local isArmed = (s.timer >= 1.0 and s.timer <= 1.9)
        s.isArmed = isArmed

        -- 1. Détection de marche sur les pics armés pour le joueur
        if isArmed and player and self.trapCooldown <= 0 then
            if circleIntersectsRect(player.x, player.y, player.radius, s.x, s.y, s.w, s.h) then
                local dmg = 12
                player:takeDamage(dmg)
                self.trapCooldown = 0.6 -- Invincibilité temporaire aux pièges

                if fctPool then
                    local f = fctPool:obtain()
                    if f then f:spawn(player.x, player.y - 12, dmg, true) end
                end
            end
        end

        -- 2. Détection de marche des monstres sur les pics armés (Danger universel)
        if isArmed and dummyPool and dummyPool.activeCount > 0 then
            for i = 1, dummyPool.activeCount do
                local dIdx = dummyPool.activeList[i]
                local monster = dummyPool.items[dIdx]
                if monster and monster.alive and not monster.isBurrowed then
                    if circleIntersectsRect(monster.x, monster.y, monster.radius, s.x, s.y, s.w, s.h) then
                        monster.spikeCooldown = (monster.spikeCooldown or 0) - dt
                        if monster.spikeCooldown <= 0 then
                            monster.spikeCooldown = 0.5
                            monster:takeDamage(15, 0, -1)
                            local VFX = require("src.render.vfx_manager")
                            VFX.triggerHitFlash(monster, 2)
                            if fctPool then
                                local f = fctPool:obtain()
                                if f then f:spawn(monster.x, monster.y - 10, 15, false) end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- ============================================================================
-- RENDU PIXEL ART
-- bakeStatic() : parties fixes cuites dans le Canvas de la salle (appelé par Arena)
-- draw()       : parties animées uniquement (pics, reflets d'eau)
-- ============================================================================
local Art = require("src.render.art")
local Palette = require("src.render.palette")
local SpriteAtlas = require("src.render.sprite_atlas")
local Slice = require("src.core.slice")
local C = Palette.C

local BLOCK_HEIGHT = 14
local STUMP_LIFT = 5
-- Single-cell obstacle drawn per world (same collision box as the forest stump)
local STUMP_SPRITES = {
    sand = "obstacle_cactus", crystal = "obstacle_ice", lava = "obstacle_obsidian",
    sky = "obstacle_floatstone", void = "obstacle_monolith",
}

local WATER_DEEP = Palette.hex("1d4f91")
local WATER_MID = Palette.hex("2a78c2")
local WATER_LIGHT = Palette.hex("5fb3e6")
local SPIKE_CELL = 14

-- ============================================================================
-- Peintre hors écran : les fonds statiques d'une salle (eau, lave, glace, sable, plaques
-- de pics) sont rastérisés UNE fois dans un tampon Lua puis envoyés en texture. Avant, ils
-- étaient dessinés directement pendant la construction de la salle (reliquat de l'ancien
-- Canvas) et n'apparaissaient donc jamais à l'écran.
-- ============================================================================
local Painter = {}
Painter.__index = Painter

-- Tampons partagés : un seul peintre est actif à la fois (bakeRegion) et toImage() les lit
-- avant le suivant. Seul l'alpha est remis à zéro : là où l'alpha est nul, les anciennes
-- valeurs RVB sont multipliées par 0 (k = 0) et ne changent donc pas le résultat.
-- Libérés à la fin de chaque bakeStatic (plusieurs Mo en Lua 5.1 pour une grande zone).
local bufR, bufG, bufB, bufA = {}, {}, {}, {}

local function releasePainterBuffers()
    bufR, bufG, bufB, bufA = {}, {}, {}, {}
end

function Painter.new(x, y, w, h)
    local self = setmetatable({ ox = math.floor(x), oy = math.floor(y), w = math.floor(w), h = math.floor(h) }, Painter)
    local n = self.w * self.h
    local R, G, B, A = bufR, bufG, bufB, bufA
    for i = #A + 1, n do R[i], G[i], B[i] = 0, 0, 0 end
    for py = 0, self.h - 1 do
        Slice.check()
        for i = py * self.w + 1, (py + 1) * self.w do A[i] = 0 end
    end
    self.r, self.g, self.b, self.a = R, G, B, A
    return self
end

-- Rectangle plein avec mélange alpha "par-dessus"
function Painter:rect(c, x, y, w, h, alpha)
    local sa = alpha or 1
    if sa <= 0 then return end
    local x0 = math.max(0, math.floor(x) - self.ox)
    local y0 = math.max(0, math.floor(y) - self.oy)
    local x1 = math.min(self.w, math.floor(x + w) - self.ox)
    local y1 = math.min(self.h, math.floor(y + h) - self.oy)
    local cr, cg, cb = c[1], c[2], c[3]
    local R, G, B, A = self.r, self.g, self.b, self.a
    local stride = self.w
    if sa == 1 then
        -- Opaque : oa = 1 et k = 0, le mélange se réduit à une copie (résultat identique)
        for py = y0, y1 - 1 do
            Slice.check()
            local row = py * stride + 1
            for i = row + x0, row + x1 - 1 do
                R[i], G[i], B[i], A[i] = cr, cg, cb, 1
            end
        end
        return
    end
    local inv = 1 - sa
    for py = y0, y1 - 1 do
        Slice.check()
        local row = py * stride + 1
        for i = row + x0, row + x1 - 1 do
            local da = A[i]
            local oa = sa + da * inv
            if oa > 0 then
                local k = da * inv
                R[i] = (cr * sa + R[i] * k) / oa
                G[i] = (cg * sa + G[i] * k) / oa
                B[i] = (cb * sa + B[i] * k) / oa
                A[i] = oa
            end
        end
    end
end

function Painter:toImage()
    local data = love.image.newImageData(self.w, self.h)
    local R, G, B, A = self.r, self.g, self.b, self.a
    for py = 0, self.h - 1 do
        Slice.check()
        local row = py * self.w
        for px = 0, self.w - 1 do
            local i = row + px + 1
            if A[i] > 0 then data:setPixel(px, py, R[i], G[i], B[i], A[i]) end
        end
    end
    local img = love.graphics.newImage(data)
    img:setFilter("nearest", "nearest")
    return img
end

local paint = nil -- peintre actif pendant bakeStatic (nil = dessin direct à l'écran)

local function fill(color, x, y, w, h, alpha)
    if paint then
        paint:rect(color, x, y, w, h, alpha)
        return
    end
    love.graphics.setColor(color[1], color[2], color[3], alpha or 1)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Rectangle aux coins arrondis "pixel" (coupe de r pixels en escalier)
local function roundRect(color, x, y, w, h, r, alpha)
    if r <= 0 then
        fill(color, x, y, w, h, alpha)
        return
    end
    fill(color, x + r, y, w - r * 2, h, alpha)
    for i = 1, r do
        local inset = r - i + 1
        fill(color, x + i - 1, y + inset, 1, h - inset * 2, alpha)
        fill(color, x + w - i, y + inset, 1, h - inset * 2, alpha)
    end
end
ObstacleManager.roundRect = roundRect

local function makeRng(seed)
    local s = seed % 4294967296
    return function()
        s = (s * 1664525 + 1013904223) % 4294967296
        return s / 4294967296
    end
end

-- Bloc de pierre en relief : face supérieure (emprise) + face avant (hauteur), mousse, fissures
local BLOCK_PAL = {
    T = "8b9bb4", t = "7d8ca6", L = "c0cbdc", e = "a9b6ca", c = "5a6988",
    F = "5a6988", f = "6c7b99", j = "3a4466", B = "3a4466",
    M = "3e8948", m = "63c74d",
}

-- Variantes de décor par chapitre (pierre, grès, cristal, obsidienne)
local BLOCK_THEMES = {
    sand = { T = "d6ac72", t = "c9a06a", L = "e8cf9c", e = "dcb87e", c = "a07c4a",
             F = "a07c4a", f = "b98f5c", j = "6b4b28", B = "6b4b28", M = "6f8f3a", m = "9ac24a" },
    crystal = { T = "5c6a9e", t = "4e5a88", L = "8fa0d6", e = "6f7cb8", c = "323a63",
                F = "3f4a7a", f = "4a5488", j = "232a4d", B = "1b2038", M = "0099db", m = "2ce8f5" },
    lava = { T = "5a4444", t = "4a3b3b", L = "6b5450", e = "5c4747", c = "332828",
             F = "3a2e2e", f = "4a3b3b", j = "1c1515", B = "140f0f", M = "b23a12", m = "f77622" },
    sky = { T = "c0cbdc", t = "a9b6ca", L = "e8f0ff", e = "cfdae8", c = "7d8ca6",
            F = "8b9bb4", f = "9fb2cc", j = "5a6988", B = "46536b", M = "0099db", m = "2ce8f5" },
    void = { T = "3d2c57", t = "2a1f3d", L = "5c4580", e = "473466", c = "231838",
             F = "2a1f3d", f = "36264d", j = "140d24", B = "0f0a18", M = "7a3ea8", m = "b06ce0" },
}

local WATER_THEMES = {
    sand = { deep = "1d6f91", mid = "2a9ac2", light = "6fd0e6", bank = "b98f5c", bankDark = "8a6437", sand = "e4c48c" },
    crystal = { deep = "1b3a7a", mid = "2f63c2", light = "6fd0ff", bank = "3f4a7a", bankDark = "232a4d", sand = "8fa0d6" },
    lava = { deep = "8a2b0c", mid = "d64a11", light = "ffb03a", bank = "4a3b3b", bankDark = "241c1c", sand = "6b3a24" },
    sky = { deep = "2f63c2", mid = "4f9be8", light = "cdeeff", bank = "8b9bb4", bankDark = "5a6988", sand = "c0cbdc" },
    void = { deep = "2a1050", mid = "5c2a7a", light = "b06ce0", bank = "2a1f3d", bankDark = "0f0a18", sand = "4a3566" },
}

function ObstacleManager:setTheme(variant, hazardKind)
    self.themeVariant = variant
    self.hazardKind = hazardKind
    self.blockPalette = variant and BLOCK_THEMES[variant] or BLOCK_PAL
    self.waterTheme = variant and WATER_THEMES[variant] or nil
end

-- Grille du bloc en tableau plat (cells[y * w + x + 1], y de 0 à h + H - 1) : mêmes tirages
-- et mêmes opérations que l'ancienne version PixGen, sans table par ligne ni chaînes
local function blockCells(w, h, H, seed)
    local W, HH = w, h + H
    local floor, ceil = math.floor, math.ceil
    local m = {}
    for i = 1, W * HH do m[i] = "." end
    local s = seed or 1
    local function rand()
        s = (s * 1664525 + 1013904223) % 4294967296
        return s / 4294967296
    end
    local function set(x, y, ch)
        x, y = floor(x), floor(y)
        if x >= 0 and y >= 0 and x < W and y < HH then m[y * W + x + 1] = ch end
    end
    local function get(x, y)
        if x < 0 or y < 0 or x >= W or y >= HH then return "." end
        return m[y * W + x + 1]
    end
    -- only : ensemble des caractères sur lesquels on peut peindre (nil = partout)
    local function rect(x, y, rw, rh, ch, only)
        for yy = y, y + rh - 1 do
            Slice.check()
            for xx = x, x + rw - 1 do
                if not only or only[get(xx, yy)] then set(xx, yy, ch) end
            end
        end
    end
    local function ellipse(cx, cy, rx, ry, ch, only)
        for y = floor(cy - ry), ceil(cy + ry) do
            for x = floor(cx - rx), ceil(cx + rx) do
                local dx = (x + 0.5 - cx) / rx
                local dy = (y + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1.0 and only[get(x, y)] then set(x, y, ch) end
            end
        end
    end
    local function sprinkle(ch, density, on)
        for y = 0, HH - 1 do
            Slice.check()
            for i = y * W + 1, y * W + W do
                if m[i] == on and rand() < density then m[i] = ch end
            end
        end
    end
    local TOP = { T = true, t = true, L = true, e = true }
    local TOP_FRONT = { T = true, t = true, e = true, F = true }
    local FRONT = { F = true, f = true }

    rect(0, h, w, H, "F")
    rect(0, h, w, 1, "f")
    rect(0, h + H - 3, w, 3, "B")
    for x = 5 + floor(rand() * 6), w - 5, 12 do
        rect(x, h + 2, 1, H - 5, "j")
    end
    rect(0, 0, w, h, "T")
    sprinkle("t", 0.10, "T")
    rect(1, 0, w - 2, 1, "L")
    rect(0, 1, 1, h - 2, "L")
    rect(1, h - 1, w - 2, 1, "e")
    for _ = 1, 2 do
        local x = 6 + floor(rand() * (w - 14))
        local y = 4 + floor(rand() * math.max(1, h - 12))
        set(x, y, "c"); set(x + 1, y + 1, "c"); set(x + 1, y + 2, "c"); set(x + 2, y + 3, "c")
    end
    ellipse(5, 3, 6, 4, "M", TOP)
    ellipse(w - 7, h - 2, 6, 3, "M", TOP_FRONT)
    rect(w - 9, h, 2, 4, "M", FRONT)
    rect(3, h, 2, 3, "M", FRONT)
    sprinkle("m", 0.35, "M")
    set(0, 0, "."); set(w - 1, 0, "."); set(0, HH - 1, "."); set(w - 1, HH - 1, ".")
    return m, W, HH
end

-- Eau en autotile : chaque case de la grille reçoit sa berge côté terre et ses coins
-- rentrants ; rien ne déborde du rectangle, donc deux bassins voisins se raccordent net.
local BANK = 4

local function bakeWaterCell(px, py, size, c, pal)
    fill(pal.deep, px, py, size, size)
    local mt, mr = c.n and 0 or BANK + 1, c.e and 0 or 2
    local mb, ml = c.s and 0 or 2, c.w and 0 or 2
    fill(pal.mid, px + ml, py + mt, size - ml - mr, size - mt - mb)
    if not c.n then
        fill(pal.bankDark, px, py, size, 1)
        fill(pal.bank, px, py + 1, size, BANK - 1)
        fill(pal.sand, px, py + 1, size, 1)
    end
    if not c.s then
        fill(pal.bank, px, py + size - BANK, size, BANK - 1)
        fill(pal.bankDark, px, py + size - 1, size, 1)
    end
    if not c.w then
        fill(pal.bankDark, px, py, 1, size)
        fill(pal.bank, px + 1, py, BANK - 1, size)
    end
    if not c.e then
        fill(pal.bank, px + size - BANK, py, BANK - 1, size)
        fill(pal.bankDark, px + size - 1, py, 1, size)
    end
    -- Coins rentrants : les deux côtés continuent en eau mais pas la diagonale
    local corners = {
        { c.n and c.w and not c.nw, px, py },
        { c.n and c.e and not c.ne, px + size - BANK, py },
        { c.s and c.w and not c.sw, px, py + size - BANK },
        { c.s and c.e and not c.se, px + size - BANK, py + size - BANK },
    }
    for _, k in ipairs(corners) do
        if k[1] then fill(pal.bank, k[2], k[3], BANK, BANK) end
    end
end

local function bakeWater(wtr, rng, theme)
    local x, y, w, h = wtr.x, wtr.y, wtr.w, wtr.h
    local pal = {
        deep = theme and Palette.hex(theme.deep) or WATER_DEEP,
        mid = theme and Palette.hex(theme.mid) or WATER_MID,
        bank = theme and Palette.hex(theme.bank) or C.dirt,
        bankDark = theme and Palette.hex(theme.bankDark) or C.dirtDark,
        sand = theme and Palette.hex(theme.sand) or C.tan,
    }
    local light = theme and Palette.hex(theme.light) or WATER_LIGHT
    local size = wtr.cell or 40
    for _, c in ipairs(wtr.cells or {}) do
        bakeWaterCell(x + c.dc * size, y + c.dr * size, size, c, pal)
    end
    for ly = y + 10, y + h - 8, 9 do
        local lx = x + 6 + math.floor(rng() * math.max(1, w - 30))
        fill(light, lx, ly, 8 + math.floor(rng() * 10), 1)
    end
    if theme then return end
    local out = paint and paint.sprites
    if not out then return end
    if w >= 40 and h >= 30 then
        out[#out + 1] = { "lily", 1, x + 12 + rng() * 6, y + 14 + rng() * 4 }
        out[#out + 1] = { "lily", 2, x + w - 14 - rng() * 6, y + h - 12 - rng() * 4 }
    else
        out[#out + 1] = { "lily", 2, x + w / 2, y + h / 2 }
    end
    out[#out + 1] = { "reeds", 1, x + 2, y + h - 2 }
    out[#out + 1] = { "reeds", 1, x + w - 2, y + 8 }
end

local function bakeSpikePlate(s)
    roundRect(C.ink, s.x - 1, s.y - 1, s.w + 2, s.h + 2, 2)
    roundRect(C.slate, s.x, s.y, s.w, s.h, 1)
    fill(C.steel, s.x + 1, s.y, s.w - 2, 1)
    fill(C.night, s.x + 1, s.y + s.h - 1, s.w - 2, 1)
    local cols = math.floor(s.w / SPIKE_CELL)
    local rows = math.floor(s.h / SPIKE_CELL)
    local ox = s.x + math.floor((s.w - cols * SPIKE_CELL) / 2)
    local oy = s.y + math.floor((s.h - rows * SPIKE_CELL) / 2)
    for cx = 0, cols - 1 do
        for ry = 0, rows - 1 do
            local px, py = ox + cx * SPIKE_CELL, oy + ry * SPIKE_CELL
            for _, hp in ipairs({ { 2, 5 }, { 9, 5 }, { 2, 12 }, { 9, 12 } }) do
                fill(C.ink, px + hp[1], py + hp[2] - 1, 3, 2)
                fill(C.steel, px + hp[1], py + hp[2] + 1, 3, 1)
                fill(C.fog, px + hp[1] + 1, py + hp[2] - 2, 1, 2)
            end
        end
    end
    -- bandes d'avertissement jaunes aux coins
    fill(C.amber, s.x + 1, s.y + 1, 3, 1); fill(C.amber, s.x + 1, s.y + 1, 1, 3)
    fill(C.amber, s.x + s.w - 4, s.y + s.h - 2, 3, 1); fill(C.amber, s.x + s.w - 2, s.y + s.h - 4, 1, 3)
end

local function isStump(_, r)
    return r.stump == true
end

-- Sol : eau, dalles de pièges et ombres portées des obstacles (cuits dans le Canvas de salle)
local HAZARD_COLORS = {
    sand = { base = "e4c48c", rim = "b98f5c", detail = "d6ac72" },
    ice  = { base = "8fd8f0", rim = "4a9fc4", detail = "ffffff" },
    lava = { base = "d64a11", rim = "6b2a10", detail = "ffb03a" },
    wind = { base = "cfe6ff", rim = "7aa8d8", detail = "ffffff" },   -- bourrasque des Îles Célestes
    void = { base = "3d2c57", rim = "18102a", detail = "b06ce0" },   -- faille du Vide
}

local function bakeHazard(hz, rng)
    local col = HAZARD_COLORS[hz.kind]
    if not col then return end
    local base, rim, detail = Palette.hex(col.base), Palette.hex(col.rim), Palette.hex(col.detail)
    roundRect(rim, hz.x - 2, hz.y - 2, hz.w + 4, hz.h + 4, 5)
    roundRect(base, hz.x, hz.y, hz.w, hz.h, 4)
    for _ = 1, math.floor(hz.w * hz.h / 260) do
        local dx = hz.x + 4 + math.floor(rng() * (hz.w - 8))
        local dy = hz.y + 4 + math.floor(rng() * (hz.h - 8))
        if hz.kind == "ice" then
            fill(detail, dx, dy, 3 + math.floor(rng() * 4), 1, 0.65)
        elseif hz.kind == "sand" then
            fill(detail, dx, dy, 2 + math.floor(rng() * 3), 1, 0.8)
        else
            fill(detail, dx, dy, 2, 1, 0.5)
        end
    end
    if hz.kind == "lava" then
        fill(Palette.hex("8a2b0c"), hz.x + 1, hz.y + 1, hz.w - 2, 2)
    end
end

-- Fonds statiques de la salle : une texture par zone (eau, danger, plaque de pics),
-- mise en cache d'une salle à l'autre, + sprites de berge et ombres portées des rochers.
local STATIC_CACHE_MAX = 24
local staticCache = {}
local staticOrder = {}

local function bakeRegion(key, x, y, w, h, bakeFn)
    local entry = staticCache[key]
    if not entry then
        paint = Painter.new(x - 6, y - 6, w + 12, h + 12)
        paint.sprites = {}
        bakeFn()
        entry = { img = paint:toImage(), sprites = paint.sprites, dx = -6, dy = -6 }
        paint = nil
        staticCache[key] = entry
        staticOrder[#staticOrder + 1] = key
        if #staticOrder > STATIC_CACHE_MAX then
            staticCache[table.remove(staticOrder, 1)] = nil
        end
    end
    return entry
end

function ObstacleManager:bakeStatic()
    local rng = makeRng(#self.rocks * 31 + #self.waters * 17 + #self.spikes * 7 + 3)
    self.staticImages = {}
    self.staticSprites = {}
    local function add(entry, x, y)
        self.staticImages[#self.staticImages + 1] = { entry.img, x + entry.dx, y + entry.dy, entry.img:getWidth(), entry.img:getHeight() }
        for _, sp in ipairs(entry.sprites) do
            -- les sprites sont enregistrés en coordonnées absolues de la première salle qui les a cuits
            self.staticSprites[#self.staticSprites + 1] = { sp[1], sp[2], sp[3] - entry.bx + x, sp[4] - entry.by + y }
        end
    end
    local theme = self.waterTheme
    for i, hz in ipairs(self.hazards) do
        local key = "hz:" .. hz.kind .. ":" .. hz.w .. "x" .. hz.h .. ":" .. i
        local e = bakeRegion(key, hz.x, hz.y, hz.w, hz.h, function() bakeHazard(hz, rng) end)
        e.bx, e.by = e.bx or hz.x, e.by or hz.y
        add(e, hz.x, hz.y)
    end
    for i, wtr in ipairs(self.waters) do
        local key = "wt:" .. tostring(theme) .. ":" .. wtr.w .. "x" .. wtr.h .. ":" .. (wtr.shapeKey or "") .. ":" .. i
        local e = bakeRegion(key, wtr.x, wtr.y, wtr.w, wtr.h, function() bakeWater(wtr, rng, theme) end)
        e.bx, e.by = e.bx or wtr.x, e.by or wtr.y
        add(e, wtr.x, wtr.y)
    end
    for _, sp in ipairs(self.spikes) do
        local key = "sp:" .. sp.w .. "x" .. sp.h
        local e = bakeRegion(key, sp.x, sp.y, sp.w, sp.h, function() bakeSpikePlate(sp) end)
        e.bx, e.by = e.bx or sp.x, e.by or sp.y
        add(e, sp.x, sp.y)
    end

    releasePainterBuffers()

    -- Ombres portées des rochers et souches (polygones rejoués à chaque image)
    self.rockShadows = {}
    for i, r in ipairs(self.rocks) do
        if isStump(i, r) then
            self.rockShadows[#self.rockShadows + 1] = { "ellipse", r.x + r.w / 2 + 6, r.y + r.h - 3, r.w * 0.52, r.h * 0.26 }
        else
            local x, y, w, h = r.x, r.y, r.w, r.h
            self.rockShadows[#self.rockShadows + 1] = { "poly", x + 4, y + h, x + w, y + h, x + w + 10, y + h + 6, x + 14, y + h + 6 }
            self.rockShadows[#self.rockShadows + 1] = { "poly", x + w, y + 2, x + w + 10, y + 8, x + w + 10, y + h + 6, x + w, y + h }
        end
    end
end

-- Dessin des fonds statiques visibles (appelé par l'arène, sous les personnages)
function ObstacleManager:drawStaticGround(x0, y0, x1, y1)
    love.graphics.setColor(1, 1, 1, 1)
    for _, e in ipairs(self.staticImages or {}) do
        if e[2] < x1 and e[2] + e[4] > x0 and e[3] < y1 and e[3] + e[5] > y0 then
            love.graphics.draw(e[1], e[2], e[3])
        end
    end
    for _, sp in ipairs(self.staticSprites or {}) do
        Art.draw(sp[1], sp[2], sp[3], sp[4])
    end
    local ink = C.abyss
    love.graphics.setColor(ink[1], ink[2], ink[3], 0.38)
    for _, sh in ipairs(self.rockShadows or {}) do
        if sh[1] == "ellipse" then
            love.graphics.ellipse("fill", sh[2], sh[3], sh[4], sh[5])
        else
            love.graphics.polygon("fill", sh[2], sh[3], sh[4], sh[5], sh[6], sh[7], sh[8], sh[9])
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- Objets en relief triés en profondeur avec les personnages
function ObstacleManager:buildProps()
    if self.props then
        for _, p in ipairs(self.props) do
            -- Images partagées via le cache de blocs (blockImage) : ne pas les libérer ici
        end
    end
    self.props = {}
    for _, b in ipairs(self.barrels) do
        self.props[#self.props + 1] = { baseY = b.y + b.radius, barrel = b, x = b.x, y = b.y + b.radius }
    end
    for _, pot in ipairs(self.pots) do
        self.props[#self.props + 1] = { baseY = pot.y + pot.radius, pot = pot, x = pot.x, y = pot.y + pot.radius }
    end
    for i, r in ipairs(self.rocks) do
        local prop = { baseY = r.y + r.h, rect = r }
        if isStump(i, r) then
            prop.sprite = STUMP_SPRITES[self.themeVariant or ""] or "stump_l"
            prop.x = r.x + r.w / 2
            prop.y = r.y + r.h / 2 - STUMP_LIFT
        elseif love.graphics.newCanvas then
            prop.canvas = self:blockImage(r.w, r.h, r.w * 7 + r.h * 13 + (i % 2) * 101)
            prop.x = r.x - 1
            prop.y = r.y - BLOCK_HEIGHT - 1
        end
        self.props[#self.props + 1] = prop
    end
end

-- Images de blocs de pierre : générées pixel par pixel (coûteux sur 3DS, ~0,1 s chacune),
-- donc mises en cache par (taille, graine, palette) et réutilisées d'une salle à l'autre.
local BLOCK_CACHE_MAX = 48
local blockCache = {}
local blockCacheOrder = {}

function ObstacleManager:blockImage(w, h, seed)
    local pal = self.blockPalette or BLOCK_PAL
    local key = w .. "x" .. h .. ":" .. seed .. ":" .. tostring(pal)
    local img = blockCache[key]
    if img then return img end
    local cells, gw, gh = blockCells(w, h, BLOCK_HEIGHT, seed)
    img = SpriteAtlas.cellsToImage(cells, gw, gh, pal, "262b44", { depth = 6, strength = 0.75 })
    blockCache[key] = img
    blockCacheOrder[#blockCacheOrder + 1] = key
    if #blockCacheOrder > BLOCK_CACHE_MAX then
        -- Pas de release() : la salle courante peut encore l'afficher ; le GC la libérera
        blockCache[table.remove(blockCacheOrder, 1)] = nil
    end
    return img
end

function ObstacleManager:drawProp(prop)
    love.graphics.setColor(1, 1, 1, 1)
    if prop.pot then
        local pot = prop.pot
        if pot.broken then
            Art.draw("pot_broken", 1, pot.x, pot.y + pot.radius + 1)
        else
            local VFX = require("src.render.vfx_manager")
            VFX.drawDynamicShadow(pot.x, pot.y + pot.radius - 1, 6, 2.5, 0, 0.38)
            Art.draw("pot", 1, pot.x, pot.y + pot.radius + 2)
        end
    elseif prop.barrel then
        local b = prop.barrel
        if b.isExploded then
            Art.draw("barrel_crater", 1, b.x, b.y + 2)
        else
            local VFX = require("src.render.vfx_manager")
            VFX.drawDynamicShadow(b.x, b.y + b.radius - 1, 7, 3, 0, 0.40)
            Art.draw("barrel", 1, b.x, b.y + b.radius + 2)
        end
    elseif prop.canvas then
        love.graphics.draw(prop.canvas, prop.x, prop.y)
    elseif prop.sprite then
        -- variante de biome : souche mousse / sable / cristal / lave / ciel / vide
        Art.draw(prop.sprite, 1, prop.x, prop.y, false, false, self.themeVariant)
    end
end

-- Parties animées (pics télégraphiés, reflets sur l'eau)
function ObstacleManager:draw()
    local t = love.timer.getTime()

    -- Dangers animés : bulles de lave, reflets de glace, tourbillons de sable. Aplats
    -- précolorés de l'atlas (Art.px) : ils restent dans le lot de sprites au lieu d'un
    -- appel GPU par rectangle semi-transparent
    for i, hz in ipairs(self.hazards) do
        if hz.kind == "lava" then
            for b = 0, 3 do
                local phase = (t * 0.7 + b * 0.27 + i * 0.13) % 1
                local bx = hz.x + 8 + ((b * 37 + i * 19) % math.max(1, hz.w - 16))
                local by = hz.y + hz.h - 6 - phase * (hz.h - 12)
                local r = math.floor(2 + phase * 2)
                Art.px("amber", math.floor(bx), math.floor(by), r, r, 0.85 * (1 - phase))
            end
            Art.px("orange", hz.x + 2, hz.y + 2, hz.w - 4, hz.h - 4, 0.10 + 0.06 * math.sin(t * 3 + i))
        elseif hz.kind == "ice" then
            local shift = math.floor((t * 14 + i * 20) % (hz.w + 30) - 30)
            Art.px("white", hz.x + shift, hz.y + 4, 12, 1, 0.5)
            Art.px("white", hz.x + shift + 6, hz.y + hz.h - 8, 8, 1, 0.35)
        else
            for b = 0, 2 do
                local phase = (t * 0.5 + b * 0.33 + i * 0.2) % 1
                local sx = hz.x + 6 + phase * (hz.w - 12)
                local sy = hz.y + 6 + ((b * 23 + i * 11) % math.max(1, hz.h - 12))
                Art.px("sand", math.floor(sx), math.floor(sy), 2, 1, 0.5 * (1 - phase))
            end
        end
    end


    for i, wtr in ipairs(self.waters) do
        local phase = (t * 0.6 + i * 0.37) % 1
        love.graphics.setColor(1, 1, 1, 0.55 * (1 - math.abs(phase - 0.5) * 2))
        Art.draw("ripple", 1, wtr.x + wtr.w * 0.35, wtr.y + wtr.h * 0.55 - phase * 3)
        Art.draw("ripple", 1, wtr.x + wtr.w * 0.7, wtr.y + wtr.h * 0.3 + phase * 2)
    end

    for _, s in ipairs(self.spikes) do
        local cols = math.floor(s.w / SPIKE_CELL)
        local rows = math.floor(s.h / SPIKE_CELL)
        local ox = s.x + math.floor((s.w - cols * SPIKE_CELL) / 2)
        local oy = s.y + math.floor((s.h - rows * SPIKE_CELL) / 2)
        local warning = (s.timer or 0) >= 0.7 and (s.timer or 0) < 1.0
        if warning then
            local pulse = (math.sin(t * 30) + 1) * 0.5
            Art.px("red", s.x, s.y, s.w, s.h, 0.15 + pulse * 0.2)
        end
        if s.isArmed or warning then
            love.graphics.setColor(1, 1, 1, 1)
            local name = s.isArmed and "spikes_up" or "spikes_mid"
            for cx = 0, cols - 1 do
                for ry = 0, rows - 1 do
                    Art.draw(name, 1, ox + cx * SPIKE_CELL, oy + ry * SPIKE_CELL)
                end
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

-- ============================================================================
-- Préparation de la salle suivante pendant la salle courante. Le choix des salles est
-- déterministe : on construit la prochaine dans un gestionnaire jetable, par tranches de
-- quelques millisecondes par image (src/core/slice.lua). Ses blocs et fonds statiques
-- remplissent les caches partagés (blockImage, bakeRegion) : au changement de salle, la
-- construction réelle ne fait plus que des lectures de cache au lieu de geler l'écran.
-- spec = { key, mapW, mapH, room, kind, variant, hazard }
-- ============================================================================
local prefetchTask = nil
ObstacleManager.lastPrefetchTime = 0 -- secondes passées dans la dernière tranche

function ObstacleManager.prefetch(spec)
    if prefetchTask and prefetchTask.key == spec.key then return end
    local om = ObstacleManager.new()
    om:setTheme(spec.variant, spec.hazard)
    prefetchTask = {
        key = spec.key,
        paint = nil,
        co = coroutine.create(function()
            om:generate(spec.mapW, spec.mapH, spec.room, spec.kind, nil, spec.chapterIndex)
            om:bakeStatic()
            om:buildProps()
        end),
    }
end

-- Avance la préparation de `budget` secondes ; renvoie true quand il n'y a plus rien à faire
function ObstacleManager.stepPrefetch(budget)
    local task = prefetchTask
    ObstacleManager.lastPrefetchTime = 0
    if not task then return true end
    -- `paint` redirige fill() vers le tampon du peintre : il ne doit être actif que pendant
    -- l'exécution de la tâche, jamais pendant le dessin direct de l'image en cours
    local screenPaint = paint
    paint = task.paint
    local t0 = love.timer.getTime()
    local done, err = Slice.resume(task.co, budget)
    ObstacleManager.lastPrefetchTime = love.timer.getTime() - t0
    task.paint = paint
    paint = screenPaint
    if err then print("[PREFETCH] abandon : " .. tostring(err)) end
    if done then prefetchTask = nil end
    return done
end

-- Avant de construire la salle `key` : termine sa préparation, ou abandonne celle d'une
-- autre salle (partie relancée, mode changé…)
function ObstacleManager.settlePrefetch(key)
    if not prefetchTask then return end
    if prefetchTask.key == key then
        ObstacleManager.stepPrefetch(math.huge)
    else
        prefetchTask = nil
    end
end

return ObstacleManager
