-- src/render/vfx_manager.lua
-- Moteur d'effets visuels (VFX), Game Feel ("Juice") et SpriteBatching optimisé 3DS
-- Gère :
-- 1. Hit-Flash blanc pur (3 frames exactes sur ennemis et joueur)
-- 2. Floating Combat Text (FCT) avec physique de saut, pop d'échelle et différenciation critique
-- 3. Screen Shake multicouche (Micro-secousses 2-3px, Moyennes 5-8px, Lourdes 9-14px)
-- 4. Hit-Stop physique (Micro-pause de 0.05s sur coups critiques ou morts de monstres)
-- 5. Telegraphing parfait (Ligne laser pulsante 0.3-0.8 -> locked 1.0, Cercle de mortier qui grandit)
-- 6. Ombres dynamiques au sol dépendantes de l'altitude / saut
-- 7. Texture Atlas procédural 128x128 & SpriteBatching (1 seul draw call pour tous les projectiles/loot)

local Config = require("src.data.config")
local Art = require("src.render.art")

local VFX = {
    -- Shake
    shakeTimer = 0,
    shakeDuration = 0,
    shakeIntensity = 0,
    shakeOffsetX = 0,
    shakeOffsetY = 0,

    -- Hit-Stop
    hitStopTimer = 0,

    -- Floating Combat Text (Pool pré-alloué sans allocation mémoire)
    FCT_MAX = 48,
    fctItems = {},
    fctActive = {},
    fctActiveCount = 0,
    fctFree = {},
    fctFreeCount = 0,

    -- Particules légères poolées
    PARTICLE_MAX = 64,
    particles = {},
    activeParticles = 0,

    -- Atlas & SpriteBatch
    atlasImage = nil,
    quads = {},
    projectileBatch = nil,
    lootBatch = nil,
    shadowBatch = nil,
    particleBatch = nil,
    isBatchReady = false,
}

-- ============================================================================
-- 1. INITIALISATION DU POOL FCT ET DU TEXTURE ATLAS PROCÉDURAL
-- ============================================================================
function VFX.init()
    -- 1. Pré-allocation du pool FCT
    VFX.fctItems = {}
    VFX.fctActive = {}
    VFX.fctFree = {}
    VFX.fctActiveCount = 0
    VFX.fctFreeCount = VFX.FCT_MAX

    for i = 1, VFX.FCT_MAX do
        VFX.fctItems[i] = {
            id = i,
            x = 0,
            y = 0,
            vx = 0,
            vy = 0,
            text = "0",
            isCrit = false,
            life = 0,
            maxLife = 0.65,
            scale = 1.0,
            color = {1, 1, 1, 1},
        }
        VFX.fctFree[i] = i
        VFX.fctActive[i] = 0
    end

    -- 2. Pré-allocation des particules d'impact
    VFX.particles = {}
    for i = 1, VFX.PARTICLE_MAX do
        VFX.particles[i] = {
            alive = false,
            x = 0, y = 0, vx = 0, vy = 0,
            life = 0, maxLife = 0.35,
            size = 3, color = {1, 1, 1, 1},
            quadName = "spark"
        }
    end
    VFX.activeParticles = 0

    -- 3. Construction du Texture Atlas procédural 128x128
    VFX.buildTextureAtlas()
end

-- Branche les SpriteBatches sur l'atlas pixel art partagé (src/render/art.lua)
function VFX.buildTextureAtlas()
    local Art = require("src.render.art")
    Art.init()
    VFX.atlasImage = Art.image

    VFX.frames = {
        arrow     = Art.frame("fx_arrow", 1),
        meteor    = Art.frame("fx_meteor", 1),
        spore     = Art.frame("fx_spore", 1),
        fireball  = Art.frame("fx_orb", 1),
        bomb      = Art.frame("bomber_bomb", 1),
        coin      = Art.frame("fx_coin", 1),
        coinEdge  = Art.frame("fx_coin", 2),
        xp        = Art.frame("fx_gem", 1),
        heart     = Art.frame("fx_heart", 1),
        scroll    = Art.frame("fx_scroll", 1),
        spark     = Art.frame("fx_spark", 1),
        shockwave = Art.frame("fx_ring", 1),
    }
    VFX.quads = {}
    for k, f in pairs(VFX.frames) do VFX.quads[k] = f.quad end

    -- Lots portables : sur 3DS, SpriteBatch ignore les couleurs (voir src/core/gpu.lua)
    local Gpu = require("src.core.gpu")
    VFX.projectileBatch = Gpu.newBatch(VFX.atlasImage, 240, "dynamic")
    VFX.lootBatch       = Gpu.newBatch(VFX.atlasImage, 140, "dynamic")
    VFX.shadowBatch     = Gpu.newBatch(VFX.atlasImage, 100, "dynamic")
    VFX.particleBatch   = Gpu.newBatch(VFX.atlasImage, 80,  "dynamic")
    VFX.isBatchReady    = true
end

-- ============================================================================
-- 2. HIT-FLASH BLANC PUR (3 FRAMES EXACTES)
-- ============================================================================
-- Active le flash blanc pur sur n'importe quelle entité (joueur ou monstre)
function VFX.triggerHitFlash(entity, frames)
    if entity then
        entity.hitFlashFrames = frames or 3
        entity.hitFlash = 1.0
    end
end

-- Décrémente le compteur de frames exactes du flash blanc
function VFX.updateEntity(entity)
    if entity and entity.hitFlashFrames and entity.hitFlashFrames > 0 then
        entity.hitFlashFrames = entity.hitFlashFrames - 1
    end
end

-- Vérifie si une entité doit être dessinée en blanc pur
function VFX.isHitFlashing(entity)
    return entity and entity.hitFlashFrames and entity.hitFlashFrames > 0
end

-- ============================================================================
-- 3. SCREEN SHAKE MULTICOUCHE (MICRO / MOYEN / LOURD)
-- ============================================================================
function VFX.shake(intensity, duration)
    -- Si une secousse plus intense est déjà en cours, on préserve l'intensité max
    if intensity >= VFX.shakeIntensity or VFX.shakeTimer <= 0 then
        VFX.shakeIntensity = intensity or 4.0
        VFX.shakeDuration = duration or 0.15
        VFX.shakeTimer = VFX.shakeDuration
    end
end

-- Raccourcis sémantiques Archero
function VFX.shakeLight()  VFX.shake(2.5, 0.10) end -- Tir puissant / flèche
function VFX.shakeMedium() VFX.shake(6.5, 0.18) end -- Joueur blessé / contact
function VFX.shakeHeavy()  VFX.shake(11.0, 0.26) end -- Coup critique / explosion / mort boss

-- Kill feedback. A regular mob gets a micro shake that never restarts one already running
-- (a pack dying together is one pulse, not a rolling quake) and no freeze frame; a boss keeps
-- the heavy shake and the hit-stop.
local KILL_SHAKE_INTENSITY = 2.0
local KILL_SHAKE_DURATION = 0.08
local BOSS_KILL_HIT_STOP = 0.14

function VFX.onKill(isBoss)
    if isBoss then
        VFX.shakeHeavy()
        VFX.hitStop(BOSS_KILL_HIT_STOP)
    elseif VFX.shakeTimer <= 0 then
        VFX.shake(KILL_SHAKE_INTENSITY, KILL_SHAKE_DURATION)
    end
end

function VFX.getShakeOffset()
    return VFX.shakeOffsetX, VFX.shakeOffsetY
end

-- ============================================================================
-- 4. HIT-STOP PHYSIQUE (MICRO-PAUSE D'IMPACT 0.05s)
-- ============================================================================
function VFX.hitStop(duration)
    VFX.hitStopTimer = duration or 0.05
end

function VFX.isHitStopped()
    return VFX.hitStopTimer > 0
end

-- ============================================================================
-- 5. FLOATING COMBAT TEXT (DÉGÂTS FLOTTANTS & CRITIQUES)
-- ============================================================================
function VFX.addFCT(x, y, damage, isCrit)
    if VFX.showDamage == false then return end       -- option "Dégâts affichés"
    if VFX.fctFreeCount <= 0 then return end

    -- Dépile un index libre
    local idx = VFX.fctFree[VFX.fctFreeCount]
    VFX.fctFreeCount = VFX.fctFreeCount - 1

    VFX.fctActiveCount = VFX.fctActiveCount + 1
    VFX.fctActive[VFX.fctActiveCount] = idx

    local f = VFX.fctItems[idx]
    f.x = x + math.random(-6, 6)
    f.y = y - 10
    f.text = tostring(damage)
    f.isCrit = isCrit or false
    f.maxLife = f.isCrit and 0.85 or 0.58
    f.life = f.maxLife

    -- Physique de saut initial vertical avec gravité
    f.vy = f.isCrit and -82 or -52
    f.vx = math.random(-14, 14)
    f.scale = f.isCrit and 1.6 or 1.15
end

-- Émission de petites particules d'étincelles lors des impacts
function VFX.addSparks(x, y, count, color)
    -- particleScale : réduit par le mode économie (Old 3DS)
    count = math.min(math.floor((count or 4) * (VFX.particleScale or 1.0)), 8)
    if count <= 0 then return end
    for i = 1, count do
        for p = 1, VFX.PARTICLE_MAX do
            local pt = VFX.particles[p]
            if not pt.alive then
                pt.alive = true
                pt.x = x
                pt.y = y
                local ang = math.random() * math.pi * 2
                local spd = math.random(50, 160)
                pt.vx = math.cos(ang) * spd
                pt.vy = math.sin(ang) * spd
                pt.maxLife = math.random(15, 30) * 0.01
                pt.life = pt.maxLife
                pt.size = math.random(2, 4)
                pt.color = color or {1, 0.8, 0.2, 1}
                pt.quadName = (math.random() < 0.5) and "spark" or "shockwave"
                VFX.activeParticles = VFX.activeParticles + 1
                break
            end
        end
    end
end

-- ============================================================================
-- 6. MISE À JOUR DE TOUS LES SYSTÈMES VFX
-- ============================================================================
-- Retourne true si le jeu est gelé par un Hit-Stop
function VFX.update(dt)
    -- 1. Gestion du Hit-Stop
    if VFX.hitStopTimer > 0 then
        VFX.hitStopTimer = VFX.hitStopTimer - dt
        return true -- Fige la boucle de jeu !
    end

    -- 2. Amortissement du Screen Shake
    if VFX.shakeTimer > 0 then
        VFX.shakeTimer = math.max(0, VFX.shakeTimer - dt)
        local progress = VFX.shakeTimer / VFX.shakeDuration
        local curIntensity = VFX.shakeIntensity * progress
        -- Whole pixels only: a fractional translate blurs the pixel art on the 3DS
        VFX.shakeOffsetX = math.floor((math.random() * 2 - 1) * curIntensity + 0.5)
        VFX.shakeOffsetY = math.floor((math.random() * 2 - 1) * curIntensity + 0.5)
    else
        VFX.shakeIntensity = 0
        VFX.shakeOffsetX = 0
        VFX.shakeOffsetY = 0
    end

    -- 3. Mise à jour du pool FCT (Physique de gravité et Pop Scale)
    for i = VFX.fctActiveCount, 1, -1 do
        local idx = VFX.fctActive[i]
        local f = VFX.fctItems[idx]

        f.x = f.x + f.vx * dt
        f.y = f.y + f.vy * dt
        f.vy = f.vy + 140 * dt -- Gravité naturelle vers le bas

        f.life = f.life - dt
        local prog = 1.0 - (f.life / f.maxLife)

        -- Animation d'échelle (Pop à l'impact puis stabilisation)
        if prog < 0.20 then
            local t = prog / 0.20
            f.scale = (f.isCrit and 1.8 or 1.3) * (0.6 + t * 0.4)
        else
            f.scale = (f.isCrit and 1.4 or 1.0)
        end

        if f.life <= 0 then
            -- Libération du FCT sans GC
            local lastSlot = VFX.fctActiveCount
            if i ~= lastSlot then
                local lastIdx = VFX.fctActive[lastSlot]
                VFX.fctActive[i] = lastIdx
            end
            VFX.fctActive[lastSlot] = 0
            VFX.fctActiveCount = VFX.fctActiveCount - 1

            VFX.fctFreeCount = VFX.fctFreeCount + 1
            VFX.fctFree[VFX.fctFreeCount] = idx
        end
    end

    -- 4. Particules légères
    if VFX.activeParticles > 0 then
        for i = 1, VFX.PARTICLE_MAX do
            local pt = VFX.particles[i]
            if pt.alive then
                pt.x = pt.x + pt.vx * dt
                pt.y = pt.y + pt.vy * dt
                pt.vx = pt.vx * math.max(0, 1.0 - dt * 8)
                pt.vy = pt.vy * math.max(0, 1.0 - dt * 8)
                pt.life = pt.life - dt
                if pt.life <= 0 then
                    pt.alive = false
                    VFX.activeParticles = math.max(0, VFX.activeParticles - 1)
                end
            end
        end
    end

    return false
end

-- ============================================================================
-- 7. RENDU DU TELEGRAPHING HAUTE LISIBILITÉ (BLEND MODE ALPHA)
-- ============================================================================
-- Ligne laser des tireurs d'élite avec pulsation (0.3 - 0.8) et verrouillage opaque (1.0)
function VFX.drawSniperLine(startX, startY, targetX, targetY, isLocked, progressTimer)

    local t = love.timer.getTime()

    if isLocked then
        -- Phase Verrouillée : Rouge vif opaque et ligne épaissie (2.5px)
        love.graphics.setColor(1.0, 0.05, 0.05, 1.0)
        love.graphics.setLineWidth(2.5)
        love.graphics.line(startX, startY, targetX, targetY)

        -- Cœur blanc brillant à l'intérieur
        love.graphics.setColor(1, 1, 1, 0.85)
        love.graphics.setLineWidth(1.0)
        love.graphics.line(startX, startY, targetX, targetY)
    else
        -- Phase de Ciblage : Pulsation fluide entre 0.3 et 0.8 d'opacité
        local pulse = (math.sin(t * 18) + 1) * 0.5
        local opacity = 0.30 + pulse * 0.50

        love.graphics.setColor(1.0, 0.18, 0.18, opacity)
        love.graphics.setLineWidth(1.5)
        love.graphics.line(startX, startY, targetX, targetY)

        -- Pointeur laser au contact du joueur
        love.graphics.setColor(1.0, 0.25, 0.25, opacity * 1.2)
        love.graphics.circle("fill", targetX, targetY, 3.5)
    end

    love.graphics.setLineWidth(1)
end

-- Cercle de mortier / bombe avec cercle intérieur qui grandit jusqu'à l'explosion
local TG_RING = { red = "fx_tg_ring_red", amber = "fx_tg_ring_amber" }
local TG_DISC = { red = "fx_tg_disc_red", amber = "fx_tg_disc_amber" }

function VFX.drawBombTelegraph(cx, cy, maxRadius, currentProgress, friendly)
    -- Sprites pré-colorés étirés (src/render/sprites/overlays.lua) : tout reste dans le lot
    -- de sprites, sans primitive ni changement de couleur (6 appels GPU par bombe avant)
    maxRadius = maxRadius or 30
    local progress = math.min(1.0, math.max(0, currentProgress or 0))
    local tint = friendly and "amber" or "red"
    local fx, fy = math.floor(cx + 0.5), math.floor(cy + 0.5)
    love.graphics.setColor(1, 1, 1, 1)
    local ringScale = maxRadius / 15
    Art.drawEx(TG_RING[tint], 1, fx, fy, 0, ringScale, ringScale)
    local discScale = maxRadius / 7 * progress
    if discScale > 0.15 then
        Art.drawEx(TG_DISC[tint], 1, fx, fy, 0, discScale, discScale)
    end
    -- Réticule d'impact
    Art.px("yellow", fx - 4, fy, 9, 1)
    Art.px("yellow", fx, fy - 4, 1, 9)
end

-- ============================================================================
-- 8. PROFONDEUR & OMBRES DYNAMIQUES AU SOL
-- ============================================================================
-- Dessine une ombre au sol dont l'échelle et l'opacité diminuent avec l'altitude (Z)
-- Optimisé 3DS : Rendu par sprite quad (0 flush GPU, 60 FPS constant)
function VFX.drawDynamicShadow(x, y, radiusX, radiusY, altitude, baseAlpha)
    altitude = altitude or 0
    baseAlpha = baseAlpha or 0.40
    local maxAlt = 70

    local scale = math.max(0.20, 1.0 - (altitude / maxAlt))
    local alpha = math.max(0.08, baseAlpha * scale)

    -- Le sprite fx_shadow est un ovale 10x6 (centre en 5, 3)
    local sx = (radiusX * scale * 2) / 10
    local sy = (radiusY * scale * 2) / 6

    -- Ombre pré-colorée (3 intensités) dessinée en blanc : fusionnée avec les sprites voisins
    -- par l'auto-batcher au lieu d'un appel GPU par ombre sur 3DS
    local name = (alpha >= 0.33) and "fx_shadow_d1" or ((alpha >= 0.2) and "fx_shadow_d2" or "fx_shadow_d3")
    love.graphics.setColor(1, 1, 1, 1)
    Art.drawEx(name, 1, x + 1, y, 0, sx, sy, false)
end

-- ============================================================================
-- 9. SPRITEBATCHING POUR PROJECTILES, LOOT & PARTICULES (OPTIMISATION 3DS)
-- ============================================================================
-- Rendu de tous les projectiles actifs : sprites pré-teintés (src/render/sprites/overlays.lua)
-- dessinés en blanc directement dans le lot automatique (src/core/gpu.lua)
local Overlays = require("src.render.sprites.overlays")
local tintByColor = setmetatable({}, { __mode = "k" })
local tintFrames = { arrow = {}, orb = {}, spark = {}, ring = {} }

local function tintName(c)
    if not c then return "white" end
    local hit = tintByColor[c]
    if hit then return hit end
    local Palette = require("src.render.palette")
    local best, bestD = "white", math.huge
    for _, name in ipairs(Overlays.TINTS) do
        local p = Palette.C[name]
        local dr, dg, db = p[1] - (c[1] or 1), p[2] - (c[2] or 1), p[3] - (c[3] or 1)
        local d = dr * dr + dg * dg + db * db
        if d < bestD then best, bestD = name, d end
    end
    tintByColor[c] = best
    return best
end

local function tintFrame(kind, c)
    local name = tintName(c)
    local f = tintFrames[kind][name]
    if f == nil then
        f = Art.has("fx_" .. kind .. "_" .. name) and Art.frame("fx_" .. kind .. "_" .. name, 1) or false
        tintFrames[kind][name] = f
    end
    return f or nil
end

function VFX.drawProjectileBatch(projectilePool)
    if not VFX.isBatchReady or not projectilePool or projectilePool.activeCount == 0 then return end

    local Gpu = require("src.core.gpu")
    local img = VFX.atlasImage
    local F = VFX.frames
    local floor = math.floor
    love.graphics.setColor(1, 1, 1, 1)

    for i = 1, projectilePool.activeCount do
        local p = projectilePool.items[projectilePool.activeList[i]]
        if p and p.alive then
            local c = p.color
            if p.isLobbed then
                local f = p.lobKind and F.meteor or F.bomb
                local s = p.lobKind and 2 or 1
                Gpu.addSprite(img, f.quad, floor(p.x + 0.5), floor(p.y - (p.arcZ or 0) + 0.5), 0, s, s, f.ox, f.oy)
            elseif p.isEnemy then
                local f = tintFrame("orb", c) or F.fireball
                local s = ((p.radius or 3) >= 4) and 2 or 1
                Gpu.addSprite(img, f.quad, floor(p.x + 0.5), floor(p.y + 0.5), 0, s, s, f.ox, f.oy)
            else
                local f = tintFrame("arrow", c) or F.arrow
                local s = ((p.radius or 3) >= 4) and 2 or 1
                Gpu.addSprite(img, f.quad, p.x, p.y, math.atan2(p.dirY or 0, p.dirX or 1), s, s, f.ox, f.oy)
            end
        end
    end
end

-- Rendu groupé de tout le butin au sol en un SEUL draw call
function VFX.drawLootBatch(lootPool)
    if not VFX.isBatchReady or not lootPool or lootPool.activeCount == 0 then return end

    local batch = VFX.lootBatch
    batch:clear()
    local F = VFX.frames
    local spin = love.timer.getTime() * 6

    for i = 1, lootPool.activeCount do
        local l = lootPool.items[lootPool.activeList[i]]
        if l and l.alive then
            local f = F.coin
            if l.type == "xp" then f = F.xp
            elseif l.type == "heart" then f = F.heart
            elseif l.type == "scroll" then f = F.scroll
            elseif math.floor(spin + i) % 4 == 0 then f = F.coinEdge end
            batch:setColor(1, 1, 1, 1)
            batch:add(f.quad, math.floor(l.x + 0.5), math.floor(l.y - (l.z or 0) + 0.5), 0, 1, 1, f.ox, f.oy)
        end
    end

    batch:draw()
end

-- Rendu de toutes les particules d'impact en un SEUL draw call
function VFX.drawParticles()
    if not VFX.isBatchReady or VFX.activeParticles == 0 then return end

    -- Étincelles pré-teintées dessinées en blanc (lot automatique) ; plus de fondu translucide,
    -- qui coûtait 1 appel GPU par particule sur 3DS : elles rétrécissent puis disparaissent
    local Gpu = require("src.core.gpu")
    local img = VFX.atlasImage
    love.graphics.setColor(1, 1, 1, 1)
    for i = 1, VFX.PARTICLE_MAX do
        local pt = VFX.particles[i]
        if pt.alive then
            local kind = (pt.quadName == "shockwave") and "ring" or "spark"
            local f = tintFrame(kind, pt.color) or VFX.frames[pt.quadName or "spark"] or VFX.frames.spark
            local life = math.max(0, pt.life / pt.maxLife)
            local scale = (life > 0.5) and 1 or 0.5
            Gpu.addSprite(img, f.quad, math.floor(pt.x + 0.5), math.floor(pt.y + 0.5), 0, scale, scale, f.ox, f.oy)
        end
    end
end

-- ============================================================================
-- 10. RENDU DU FLOATING COMBAT TEXT (TEXTE ROUGE CRITIQUE / JAUNE NORMAL)
-- ============================================================================
-- Au plus FCT_VISIBLE textes affichés (les plus récents) : chaque lettre est un sprite
local FCT_VISIBLE = 10
function VFX.drawFCT()
    if VFX.fctActiveCount == 0 then return end
    local PixelFont = require("src.ui.pixel_font")
    local Palette = require("src.render.palette")

    for i = math.max(1, VFX.fctActiveCount - FCT_VISIBLE + 1), VFX.fctActiveCount do
        local f = VFX.fctItems[VFX.fctActive[i]]
        local scale = f.isCrit and 2 or 1
        local w = PixelFont.getWidth(f.text, "main", scale)
        -- Couleur de palette opaque (précuite) : lettres regroupées dans le lot. Un fondu
        -- translucide imposait 1 appel GPU par lettre sur 3DS ; le texte disparaît en fin de vie.
        local color = f.isCrit and Palette.C.amber or Palette.C.white
        PixelFont.print(f.text, math.floor(f.x - w / 2), math.floor(f.y - 6 * scale), color, "main", scale, nil)
    end
end

return VFX
