-- src/render/monsters.lua
-- Rendu des monstres en sprites pixel art : animation, miroir vers le joueur,
-- ombres dynamiques (altitude), variantes de charge et Hit-Flash (silhouette blanche).

local VFX = require("src.render.vfx_manager")
local Art = require("src.render.art")
local Palette = require("src.render.palette")

local Monsters = {}

local floor = math.floor
local C = Palette.C

local function anim(t, fps, id, count)
    return floor(t * fps + (id or 1) * 0.37) % count + 1
end

local function faceLeft(m, px)
    return px ~= nil and px < m.x
end

local function basePos(m)
    return m.x + (m.knockX or 0), m.y + (m.knockY or 0)
end

-- Colours a monster shatters into when it dies (palette names: main, dark)
local MONSTER_SHARDS = {
    slime = { "leaf", "moss" }, bat = { "magenta", "plum" }, skeleton = { "silver", "fog" },
    wolf = { "fog", "slate" }, plant = { "leaf", "pine" }, bomber = { "red", "wine" },
    burrower = { "clay", "bark" }, splitter = { "mint", "leaf" }, mini_slime = { "mint", "leaf" },
    golem = { "fog", "steel" }, summoner = { "magenta", "plum" }, turret = { "steel", "slate" },
    mage = { "blue", "navy" }, skeleton_king = { "silver", "amber" }, witch = { "magenta", "plum" },
    lava_titan = { "orange", "red" }, raven = { "slate", "night" }, wisp = { "cyan", "sky" },
    gargoyle = { "steel", "slate" }, frost_wraith = { "cyan", "sky" }, storm_drake = { "blue", "cyan" },
    void_watcher = { "magenta", "plum" },
}
local DEFAULT_SHARDS = { "fog", "steel" }

function Monsters.shardColors(mType)
    return MONSTER_SHARDS[mType] or DEFAULT_SHARDS
end

-- Squash and stretch of the body sprite: a hit squashes it wide (m.wobble, set by
-- Dummy:takeDamage), a spawn pops it in tall and thin (m.spawnPop). Sprites are anchored at
-- the feet, so the monster stays on the ground. Gameplay hitboxes are untouched.
local WOBBLE_TIME = 0.35      -- Dummy:takeDamage
local SPAWN_POP_TIME = 0.22   -- Dummy:spawn
local bodySX, bodySY = 1, 1

-- Soft light under a monster (src/render/sprites/overlays.lua fx_glow_*, 15 x 15): one sprite
-- in the automatic batch instead of a translucent ellipse costing its own GPU call
local GLOW_SPRITES = {}
for _, tint in ipairs({ "orange", "leaf", "red", "magenta", "cyan", "yellow" }) do GLOW_SPRITES[tint] = "fx_glow_" .. tint end

local function glow(tint, cx, cy, rx, ry)
    love.graphics.setColor(1, 1, 1, 1)
    Art.drawEx(GLOW_SPRITES[tint], 1, floor(cx + 0.5), floor(cy + 0.5), 0, rx / 7.5, ry / 7.5)
end

local function body(name, frame, x, y, flip, flash, variant)
    if bodySX == 1 and bodySY == 1 then
        Art.draw(name, frame, x, y, flip, flash, variant)
    else
        Art.drawEx(name, frame, floor(x + 0.5), floor(y + 0.5), 0, flip and -bodySX or bodySX, bodySY, flash, variant)
    end
end

-- Hauteur visuelle au-dessus du centre (pour placer la barre de vie)
local TOP_OFFSET = {
    slime = 8, bat = 16, skeleton = 12, wolf = 8, plant = 10, bomber = 18,
    burrower = 14, splitter = 12, mini_slime = 5, golem = 22,
    summoner = 16, turret = 12, mage = 16, skeleton_king = 24, witch = 22, lava_titan = 22,
    raven = 14, wisp = 14, gargoyle = 18, frost_wraith = 18, storm_drake = 24, void_watcher = 24,
}

function Monsters.drawSlime(m, px, py, t)
    local x, y = basePos(m)
    local bounce = math.sin(t * 7 + (m.id or 1))
    local frame, hop = 1, 0
    if m.aiState == "dash" or m.isDashing then
        frame = 2
    elseif bounce > 0.55 then
        frame = 2
    elseif bounce < -0.45 then
        frame = 3
        hop = floor(-bounce * 5)
    end
    VFX.drawDynamicShadow(m.x, m.y + 9, 9, 3.5, hop * 3, 0.40)
    local variant = m.isDashing and "charge" or nil
    body("slime", frame, x, y + 9 - hop, faceLeft(m, px), VFX.isHitFlashing(m), variant)
end

function Monsters.drawBat(m, px, py, t)
    local x, y = basePos(m)
    local altitude = 14 + math.sin(t * 4 + (m.id or 1)) * 3
    VFX.drawDynamicShadow(m.x, m.y + 12, 8, 3, altitude, 0.35)
    local variant = (m.isDashing or m.aiState == "aim") and "charge" or nil
    body("bat", anim(t, 12, m.id, 4), x, y - altitude + 10, faceLeft(m, px), VFX.isHitFlashing(m), variant)
end

function Monsters.drawSkeleton(m, px, py, t)
    local x, y = basePos(m)
    VFX.drawDynamicShadow(m.x, m.y + 9, 8, 3, 0, 0.40)
    local left = faceLeft(m, px)
    local flash = VFX.isHitFlashing(m)
    body("skeleton", anim(t, 3, m.id, 2), x, y + 9, left, flash)

    local dx, dy = (px or m.x + 1) - m.x, (py or m.y) - m.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 0.1 then dx, dy = dx / len, dy / len else dx, dy = 1, 0 end
    Art.drawEx("bow", 1, floor(x + dx * 7 + 0.5), floor(y + 1 + dy * 5 + 0.5), math.atan2(dy, dx), 1, 1, flash, "bone")
end

function Monsters.drawWolf(m, px, py, t)
    local x, y = basePos(m)
    VFX.drawDynamicShadow(m.x, m.y + 8, 11, 3.5, 0, 0.45)
    local fps = m.isDashing and 14 or 5
    local variant = m.isDashing and "charge" or nil
    body("wolf", anim(t, fps, m.id, 2), x, y + 8, faceLeft(m, px), VFX.isHitFlashing(m), variant)
end

function Monsters.drawPlant(m, px, py, t)
    local x, y = basePos(m)
    VFX.drawDynamicShadow(m.x, m.y + 9, 10, 3.5, 0, 0.45)
    local frame = (m.aiState == "aim") and 2 or ((anim(t, 0.8, m.id, 5) == 5) and 2 or 1)
    body("plant", frame, x, y + 9, faceLeft(m, px), VFX.isHitFlashing(m))
end

function Monsters.drawBomber(m, px, py, t)
    local x, y = basePos(m)
    local hover = floor(math.sin(t * 5 + (m.id or 1)) * 2.5 + 0.5)
    local altitude = 8 + hover
    VFX.drawDynamicShadow(m.x, m.y + 11, 8, 3, altitude, 0.35)
    local left = faceLeft(m, px)
    local flash = VFX.isHitFlashing(m)
    body("bomber", anim(t, 4, m.id, 2), x, y + 10 - hover, left, flash)
    local side = left and -1 or 1
    Art.draw("bomber_bomb", 1, x + side * 9, y + 2 - hover, left, flash)
end

function Monsters.drawBurrower(m, px, py, t)
    if m.isBurrowed then return end
    local x, y = basePos(m)
    VFX.drawDynamicShadow(m.x, m.y + 9, 9, 3, 0, 0.30)
    body("burrower", anim(t, 6, m.id, 2), x, y + 10, faceLeft(m, px), VFX.isHitFlashing(m))
    if m.aiState == "surface" and not m.hasFired then
        Art.px("leaf", floor(x) - 1, floor(y) - 8, 3, 3)
    end
end

function Monsters.drawSplitter(m, px, py, t)
    local x, y = basePos(m)
    if m.type == "mini_slime" then
        local hop = (anim(t, 8, m.id, 2) == 2) and 2 or 0
        VFX.drawDynamicShadow(m.x, m.y + 5, 6, 2.5, hop * 3, 0.40)
        body("mini_slime", hop > 0 and 2 or 1, x, y + 5 - hop, faceLeft(m, px), VFX.isHitFlashing(m))
        return
    end
    VFX.drawDynamicShadow(m.x, m.y + 13, 16, 5, 0, 0.42)
    body("splitter", anim(t, 2.5, m.id, 2), x, y + 13, faceLeft(m, px), VFX.isHitFlashing(m))
end

function Monsters.drawGolem(m, px, py, t)
    local x, y = basePos(m)
    VFX.drawDynamicShadow(m.x, m.y + 17, 20, 6, 0, 0.50)
    local enraged = m.isEnraged or (m.maxHp and m.hp < m.maxHp * 0.5)
    if enraged then
        local pulse = (math.sin(t * 9) + 1) * 0.5
        glow("orange", m.x, m.y + 14, 26 + pulse * 3, 10 + pulse)
    end
    body("golem", anim(t, enraged and 4 or 2, m.id, 2), x, y + 18, faceLeft(m, px), VFX.isHitFlashing(m), enraged and "rage" or nil)
end

function Monsters.drawSummoner(m, px, py, t)
    local x, y = basePos(m)
    VFX.drawDynamicShadow(m.x, m.y + 10, 9, 3.5, 0, 0.42)
    if m.aiState == "summon" then
        local pulse = (math.sin(t * 16) + 1) * 0.5
        glow("leaf", m.x, m.y + 8, 22 + pulse * 3, 9 + pulse)
    end
    body("summoner", anim(t, 4, m.id, 2), x, y + 10, faceLeft(m, px), VFX.isHitFlashing(m))
end

function Monsters.drawTurret(m, px, py, t)
    local x, y = basePos(m)
    VFX.drawDynamicShadow(m.x, m.y + 9, 10, 4, 0, 0.45)
    local frame = (m.aiState == "aim") and 1 or 2
    body("turret", frame, x, y + 9, false, VFX.isHitFlashing(m))
end

function Monsters.drawMage(m, px, py, t)
    local x, y = basePos(m)
    local hover = floor(math.sin(t * 4 + (m.id or 1)) * 2 + 0.5)
    VFX.drawDynamicShadow(m.x, m.y + 10, 8, 3, 6 + hover, 0.35)
    body("mage", anim(t, 5, m.id, 2), x, y + 9 - hover, faceLeft(m, px), VFX.isHitFlashing(m))
end

function Monsters.drawSkeletonKing(m, px, py, t)
    local x, y = basePos(m)
    VFX.drawDynamicShadow(m.x, m.y + 18, 20, 7, 0, 0.5)
    if m.isEnraged then
        local pulse = (math.sin(t * 9) + 1) * 0.5
        glow("red", m.x, m.y + 15, 28 + pulse * 3, 11 + pulse)
    end
    body("skeleton_king", anim(t, m.isEnraged and 4 or 2, m.id, 2), x, y + 18, faceLeft(m, px),
        VFX.isHitFlashing(m), m.isEnraged and "rage" or nil)
end

function Monsters.drawWitch(m, px, py, t)
    local x, y = basePos(m)
    local hover = floor(math.sin(t * 3 + (m.id or 1)) * 3 + 0.5)
    VFX.drawDynamicShadow(m.x, m.y + 16, 16, 6, 8 + hover, 0.42)
    if m.isEnraged then
        local pulse = (math.sin(t * 10) + 1) * 0.5
        glow("magenta", m.x, m.y + 14, 26 + pulse * 3, 10 + pulse)
    end
    body("witch", anim(t, 3, m.id, 2), x, y + 16 - hover, faceLeft(m, px),
        VFX.isHitFlashing(m), m.isEnraged and "rage" or nil)
end

function Monsters.drawLavaTitan(m, px, py, t)
    local x, y = basePos(m)
    VFX.drawDynamicShadow(m.x, m.y + 17, 20, 6, 0, 0.5)
    local pulse = (math.sin(t * 6) + 1) * 0.5
    glow("orange", m.x, m.y + 15, 28 + pulse * 3, 11 + pulse)
    body("golem", anim(t, m.isEnraged and 4 or 2, m.id, 2), x, y + 18, faceLeft(m, px),
        VFX.isHitFlashing(m), "lava")
end

-- ============================================================================
-- MONSTRES DES ÎLES CÉLESTES ET DE LA CITÉ DU VIDE
-- ============================================================================

-- Rapace : vol rapide, plonge sur le héros
function Monsters.drawRaven(m, px, py, t)
    local x, y = basePos(m)
    local altitude = 12 + math.sin(t * 5 + (m.id or 1)) * 3
    VFX.drawDynamicShadow(m.x, m.y + 12, 9, 3, altitude, 0.35)
    body("raven", anim(t, 10, m.id, 2), x, y - altitude + 10, faceLeft(m, px), VFX.isHitFlashing(m))
end

-- Feu follet : orbe lumineux en lévitation
function Monsters.drawWisp(m, px, py, t)
    local x, y = basePos(m)
    local altitude = 10 + math.sin(t * 2.6 + (m.id or 1)) * 4
    VFX.drawDynamicShadow(m.x, m.y + 10, 7, 3, altitude, 0.28)
    glow("cyan", m.x, m.y - altitude + 4, 12, 12)
    body("wisp", anim(t, 5, m.id, 2), x, y - altitude + 8, faceLeft(m, px), VFX.isHitFlashing(m))
end

-- Gargouille : statue de pierre trapue
function Monsters.drawGargoyle(m, px, py, t)
    local x, y = basePos(m)
    VFX.drawDynamicShadow(m.x, m.y + 13, 13, 4, 0, 0.45)
    body("gargoyle", anim(t, 4, m.id, 2), x, y + 13, faceLeft(m, px), VFX.isHitFlashing(m))
end

-- Spectre givré : flotte et laisse une traînée de froid
function Monsters.drawFrostWraith(m, px, py, t)
    local x, y = basePos(m)
    local altitude = 6 + math.sin(t * 2.2 + (m.id or 1)) * 3
    VFX.drawDynamicShadow(m.x, m.y + 12, 10, 4, altitude, 0.30)
    glow("cyan", m.x, m.y + 8, 14, 6)
    body("frost_wraith", anim(t, 3.5, m.id, 2), x, y + 10 - altitude, faceLeft(m, px), VFX.isHitFlashing(m))
end

-- Drake des tempêtes : boss des Îles Célestes
function Monsters.drawStormDrake(m, px, py, t)
    local x, y = basePos(m)
    local enraged = m.isEnraged or (m.maxHp and m.hp < m.maxHp * 0.5)
    VFX.drawDynamicShadow(m.x, m.y + 17, 20, 6, 0, 0.48)
    if enraged then
        local pulse = (math.sin(t * 9) + 1) * 0.5
        glow("yellow", m.x, m.y + 14, 26 + pulse * 3, 10 + pulse)
    end
    body("storm_drake", anim(t, enraged and 6 or 3, m.id, 2), x, y + 17,
        faceLeft(m, px), VFX.isHitFlashing(m), enraged and "rage" or nil)
end

-- Œil du Vide : boss final, pupille qui suit le héros
function Monsters.drawVoidWatcher(m, px, py, t)
    local x, y = basePos(m)
    local enraged = m.isEnraged or (m.maxHp and m.hp < m.maxHp * 0.5)
    VFX.drawDynamicShadow(m.x, m.y + 18, 20, 7, 0, 0.50)
    glow("magenta", m.x, m.y + 2, 28 + math.sin(t * 2.4) * 2, 28 + math.sin(t * 2.4) * 2)
    body("void_watcher", anim(t, enraged and 5 or 2.5, m.id, 2), x, y + 18,
        faceLeft(m, px), VFX.isHitFlashing(m), enraged and "rage" or nil)
end

local DRAWERS = {
    summoner = Monsters.drawSummoner,
    turret = Monsters.drawTurret,
    mage = Monsters.drawMage,
    skeleton_king = Monsters.drawSkeletonKing,
    witch = Monsters.drawWitch,
    lava_titan = Monsters.drawLavaTitan,
    bat = Monsters.drawBat,
    wolf = Monsters.drawWolf,
    skeleton = Monsters.drawSkeleton,
    plant = Monsters.drawPlant,
    golem = Monsters.drawGolem,
    bomber = Monsters.drawBomber,
    burrower = Monsters.drawBurrower,
    splitter = Monsters.drawSplitter,
    mini_slime = Monsters.drawSplitter,
    raven = Monsters.drawRaven,
    wisp = Monsters.drawWisp,
    gargoyle = Monsters.drawGargoyle,
    frost_wraith = Monsters.drawFrostWraith,
    storm_drake = Monsters.drawStormDrake,
    void_watcher = Monsters.drawVoidWatcher,
}

-- Barre de vie pixel (monstre blessé, ou élite : toujours visible, avec bouclier et affixes)
local function drawHealthBar(m, mType)
    local big = m.champion or (mType == "golem" or mType == "splitter" or mType == "skeleton_king"
        or mType == "witch" or mType == "lava_titan"
        or mType == "storm_drake" or mType == "void_watcher")
    local barW = big and 30 or 18
    local x = floor(m.x - barW / 2)
    local y = floor(m.y - (TOP_OFFSET[mType] or 10) - 7)
    local ratio = math.max(0, math.min(1, m.hp / m.maxHp))

    -- Pixels pré-colorés : la barre reste dans le lot des sprites (pas d'appel GPU en plus)
    Art.px("ink", x - 1, y - 1, barW + 2, 5)
    local fillW = floor(barW * ratio + 0.5)
    if fillW > 0 then
        Art.px((m.isBoss or m.champion) and "orange" or (m.elite and "amber" or "red"), x, y, fillW, 3)
    end
    if (m.shieldMax or 0) > 0 and m.shieldHp > 0 then
        Art.px("cyan", x, y - 2, floor(barW * m.shieldHp / m.shieldMax + 0.5), 1)
    end
    if m.affixIcons then
        for i, icon in ipairs(m.affixIcons) do
            Art.draw(icon, 1, x - 6 - (i - 1) * 9, y + 1)
        end
    end
end

function Monsters.draw(m, px, py, debugMode)
    local mType = m.type or "slime"
    local t = love.timer.getTime()
    love.graphics.setColor(1, 1, 1, 1)

    -- Élite : anneau pré-teinté aplati sous le monstre (même lot que les sprites)
    if m.elite and m.ringSprite and not m.isBurrowed then
        local pulse = 0.25 * math.sin(t * 6 + (m.id or 0))
        local s = m.champion and 6.2 or 3.4
        Art.drawEx(m.ringSprite, 1, floor(m.x), floor(m.y + (m.radius or 10) * 0.7), 0, s + pulse, (s + pulse) * 0.45)
    end
    bodySX, bodySY = 1, 1
    local wobble = m.wobble or 0
    local pop = m.spawnPop or 0
    if pop > 0 then
        local k = pop / SPAWN_POP_TIME
        bodySX, bodySY = 1 - 0.45 * k, 1 + 0.35 * k
    elseif wobble > 0 then
        local k = wobble / WOBBLE_TIME
        bodySX, bodySY = 1 + 0.22 * k, 1 - 0.18 * k
    end
    local drawer = DRAWERS[mType] or Monsters.drawSlime
    drawer(m, px, py, t)
    bodySX, bodySY = 1, 1
    love.graphics.setColor(1, 1, 1, 1)

    if m.hp and m.maxHp and (m.hp < m.maxHp or m.elite) and m.alive and not m.isBurrowed then
        drawHealthBar(m, mType)
    end

    if debugMode and not m.isBurrowed then
        local r = m.radius or 12
        love.graphics.setColor(1, 0, 0, 0.7)
        love.graphics.rectangle("line", m.x - r, m.y - r, r * 2, r * 2)
    end
end

return Monsters
