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
    Art.draw("slime", frame, x, y + 9 - hop, faceLeft(m, px), VFX.isHitFlashing(m), variant)
end

function Monsters.drawBat(m, px, py, t)
    local x, y = basePos(m)
    local altitude = 14 + math.sin(t * 4 + (m.id or 1)) * 3
    VFX.drawDynamicShadow(m.x, m.y + 12, 8, 3, altitude, 0.35)
    local variant = (m.isDashing or m.aiState == "aim") and "charge" or nil
    Art.draw("bat", anim(t, 12, m.id, 4), x, y - altitude + 10, faceLeft(m, px), VFX.isHitFlashing(m), variant)
end

function Monsters.drawSkeleton(m, px, py, t)
    local x, y = basePos(m)
    VFX.drawDynamicShadow(m.x, m.y + 9, 8, 3, 0, 0.40)
    local left = faceLeft(m, px)
    local flash = VFX.isHitFlashing(m)
    Art.draw("skeleton", anim(t, 3, m.id, 2), x, y + 9, left, flash)

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
    Art.draw("wolf", anim(t, fps, m.id, 2), x, y + 8, faceLeft(m, px), VFX.isHitFlashing(m), variant)
end

function Monsters.drawPlant(m, px, py, t)
    local x, y = basePos(m)
    VFX.drawDynamicShadow(m.x, m.y + 9, 10, 3.5, 0, 0.45)
    local frame = (m.aiState == "aim") and 2 or ((anim(t, 0.8, m.id, 5) == 5) and 2 or 1)
    Art.draw("plant", frame, x, y + 9, faceLeft(m, px), VFX.isHitFlashing(m))
end

function Monsters.drawBomber(m, px, py, t)
    local x, y = basePos(m)
    local hover = floor(math.sin(t * 5 + (m.id or 1)) * 2.5 + 0.5)
    local altitude = 8 + hover
    VFX.drawDynamicShadow(m.x, m.y + 11, 8, 3, altitude, 0.35)
    local left = faceLeft(m, px)
    local flash = VFX.isHitFlashing(m)
    Art.draw("bomber", anim(t, 4, m.id, 2), x, y + 10 - hover, left, flash)
    local side = left and -1 or 1
    Art.draw("bomber_bomb", 1, x + side * 9, y + 2 - hover, left, flash)
end

function Monsters.drawBurrower(m, px, py, t)
    if m.isBurrowed then return end
    local x, y = basePos(m)
    VFX.drawDynamicShadow(m.x, m.y + 9, 9, 3, 0, 0.30)
    Art.draw("burrower", anim(t, 6, m.id, 2), x, y + 10, faceLeft(m, px), VFX.isHitFlashing(m))
    if m.aiState == "surface" and not m.hasFired then
        Palette.set(C.leaf, 0.9)
        love.graphics.rectangle("fill", floor(x) - 1, floor(y) - 8, 3, 3)
    end
end

function Monsters.drawSplitter(m, px, py, t)
    local x, y = basePos(m)
    if m.type == "mini_slime" then
        local hop = (anim(t, 8, m.id, 2) == 2) and 2 or 0
        VFX.drawDynamicShadow(m.x, m.y + 5, 6, 2.5, hop * 3, 0.40)
        Art.draw("mini_slime", hop > 0 and 2 or 1, x, y + 5 - hop, faceLeft(m, px), VFX.isHitFlashing(m))
        return
    end
    VFX.drawDynamicShadow(m.x, m.y + 13, 16, 5, 0, 0.42)
    Art.draw("splitter", anim(t, 2.5, m.id, 2), x, y + 13, faceLeft(m, px), VFX.isHitFlashing(m))
end

function Monsters.drawGolem(m, px, py, t)
    local x, y = basePos(m)
    VFX.drawDynamicShadow(m.x, m.y + 17, 20, 6, 0, 0.50)
    local enraged = m.isEnraged or (m.maxHp and m.hp < m.maxHp * 0.5)
    if enraged then
        local pulse = (math.sin(t * 9) + 1) * 0.5
        Palette.set(C.orange, 0.18 + pulse * 0.16)
        love.graphics.ellipse("fill", m.x, m.y + 14, 26, 10)
        Palette.set(C.yellow, 0.35 + pulse * 0.3)
        love.graphics.ellipse("line", m.x, m.y + 14, 26, 10)
        love.graphics.setColor(1, 1, 1, 1)
    end
    Art.draw("golem", anim(t, enraged and 4 or 2, m.id, 2), x, y + 18, faceLeft(m, px), VFX.isHitFlashing(m), enraged and "rage" or nil)
end

function Monsters.drawSummoner(m, px, py, t)
    local x, y = basePos(m)
    VFX.drawDynamicShadow(m.x, m.y + 10, 9, 3.5, 0, 0.42)
    if m.aiState == "summon" then
        local pulse = (math.sin(t * 16) + 1) * 0.5
        Palette.set(C.leaf, 0.25 + pulse * 0.25)
        love.graphics.ellipse("fill", m.x, m.y + 8, 22, 9)
        love.graphics.setColor(1, 1, 1, 1)
    end
    Art.draw("summoner", anim(t, 4, m.id, 2), x, y + 10, faceLeft(m, px), VFX.isHitFlashing(m))
end

function Monsters.drawTurret(m, px, py, t)
    local x, y = basePos(m)
    VFX.drawDynamicShadow(m.x, m.y + 9, 10, 4, 0, 0.45)
    local frame = (m.aiState == "aim") and 1 or 2
    Art.draw("turret", frame, x, y + 9, false, VFX.isHitFlashing(m))
end

function Monsters.drawMage(m, px, py, t)
    local x, y = basePos(m)
    local hover = floor(math.sin(t * 4 + (m.id or 1)) * 2 + 0.5)
    VFX.drawDynamicShadow(m.x, m.y + 10, 8, 3, 6 + hover, 0.35)
    Art.draw("mage", anim(t, 5, m.id, 2), x, y + 9 - hover, faceLeft(m, px), VFX.isHitFlashing(m))
end

function Monsters.drawSkeletonKing(m, px, py, t)
    local x, y = basePos(m)
    VFX.drawDynamicShadow(m.x, m.y + 18, 20, 7, 0, 0.5)
    if m.isEnraged then
        local pulse = (math.sin(t * 9) + 1) * 0.5
        Palette.set(C.red, 0.15 + pulse * 0.15)
        love.graphics.ellipse("fill", m.x, m.y + 15, 28, 11)
        love.graphics.setColor(1, 1, 1, 1)
    end
    Art.draw("skeleton_king", anim(t, m.isEnraged and 4 or 2, m.id, 2), x, y + 18, faceLeft(m, px),
        VFX.isHitFlashing(m), m.isEnraged and "rage" or nil)
end

function Monsters.drawWitch(m, px, py, t)
    local x, y = basePos(m)
    local hover = floor(math.sin(t * 3 + (m.id or 1)) * 3 + 0.5)
    VFX.drawDynamicShadow(m.x, m.y + 16, 16, 6, 8 + hover, 0.42)
    if m.isEnraged then
        local pulse = (math.sin(t * 10) + 1) * 0.5
        Palette.set(C.magenta, 0.18 + pulse * 0.18)
        love.graphics.ellipse("fill", m.x, m.y + 14, 26, 10)
        love.graphics.setColor(1, 1, 1, 1)
    end
    Art.draw("witch", anim(t, 3, m.id, 2), x, y + 16 - hover, faceLeft(m, px),
        VFX.isHitFlashing(m), m.isEnraged and "rage" or nil)
end

function Monsters.drawLavaTitan(m, px, py, t)
    local x, y = basePos(m)
    VFX.drawDynamicShadow(m.x, m.y + 17, 20, 6, 0, 0.5)
    local pulse = (math.sin(t * 6) + 1) * 0.5
    Palette.set(C.orange, 0.15 + pulse * 0.15)
    love.graphics.ellipse("fill", m.x, m.y + 15, 26, 10)
    love.graphics.setColor(1, 1, 1, 1)
    Art.draw("golem", anim(t, m.isEnraged and 4 or 2, m.id, 2), x, y + 18, faceLeft(m, px),
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
    Art.draw("raven", anim(t, 10, m.id, 2), x, y - altitude + 10, faceLeft(m, px), VFX.isHitFlashing(m))
end

-- Feu follet : orbe lumineux en lévitation
function Monsters.drawWisp(m, px, py, t)
    local x, y = basePos(m)
    local altitude = 10 + math.sin(t * 2.6 + (m.id or 1)) * 4
    VFX.drawDynamicShadow(m.x, m.y + 10, 7, 3, altitude, 0.28)
    Palette.set(C.cyan, 0.18 + 0.10 * math.sin(t * 4 + (m.id or 1)))
    love.graphics.circle("fill", m.x, m.y - altitude + 4, 11)
    love.graphics.setColor(1, 1, 1, 1)
    Art.draw("wisp", anim(t, 5, m.id, 2), x, y - altitude + 8, faceLeft(m, px), VFX.isHitFlashing(m))
end

-- Gargouille : statue de pierre trapue
function Monsters.drawGargoyle(m, px, py, t)
    local x, y = basePos(m)
    VFX.drawDynamicShadow(m.x, m.y + 13, 13, 4, 0, 0.45)
    Art.draw("gargoyle", anim(t, 4, m.id, 2), x, y + 13, faceLeft(m, px), VFX.isHitFlashing(m))
end

-- Spectre givré : flotte et laisse une traînée de froid
function Monsters.drawFrostWraith(m, px, py, t)
    local x, y = basePos(m)
    local altitude = 6 + math.sin(t * 2.2 + (m.id or 1)) * 3
    VFX.drawDynamicShadow(m.x, m.y + 12, 10, 4, altitude, 0.30)
    Palette.set(C.cyan, 0.14)
    love.graphics.ellipse("fill", m.x, m.y + 8, 12, 5)
    love.graphics.setColor(1, 1, 1, 1)
    Art.draw("frost_wraith", anim(t, 3.5, m.id, 2), x, y + 10 - altitude, faceLeft(m, px), VFX.isHitFlashing(m))
end

-- Drake des tempêtes : boss des Îles Célestes
function Monsters.drawStormDrake(m, px, py, t)
    local x, y = basePos(m)
    local enraged = m.isEnraged or (m.maxHp and m.hp < m.maxHp * 0.5)
    VFX.drawDynamicShadow(m.x, m.y + 17, 20, 6, 0, 0.48)
    if enraged then
        local pulse = (math.sin(t * 9) + 1) * 0.5
        Palette.set(C.yellow, 0.18 + pulse * 0.16)
        love.graphics.ellipse("fill", m.x, m.y + 14, 26, 10)
        love.graphics.setColor(1, 1, 1, 1)
    end
    Art.draw("storm_drake", anim(t, enraged and 6 or 3, m.id, 2), x, y + 17,
        faceLeft(m, px), VFX.isHitFlashing(m), enraged and "rage" or nil)
end

-- Œil du Vide : boss final, pupille qui suit le héros
function Monsters.drawVoidWatcher(m, px, py, t)
    local x, y = basePos(m)
    local enraged = m.isEnraged or (m.maxHp and m.hp < m.maxHp * 0.5)
    VFX.drawDynamicShadow(m.x, m.y + 18, 20, 7, 0, 0.50)
    Palette.set(C.magenta, 0.16 + 0.08 * math.sin(t * 2.4))
    love.graphics.circle("fill", m.x, m.y + 2, 26)
    love.graphics.setColor(1, 1, 1, 1)
    Art.draw("void_watcher", anim(t, enraged and 5 or 2.5, m.id, 2), x, y + 18,
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

-- Barre de vie pixel (n'apparaît que si le monstre est blessé)
local function drawHealthBar(m, mType)
    local big = (mType == "golem" or mType == "splitter" or mType == "skeleton_king"
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
        Art.px(m.isBoss and "orange" or "red", x, y, fillW, 3)
    end
end

function Monsters.draw(m, px, py, debugMode)
    local mType = m.type or "slime"
    local t = love.timer.getTime()
    love.graphics.setColor(1, 1, 1, 1)

    local drawer = DRAWERS[mType] or Monsters.drawSlime
    drawer(m, px, py, t)
    love.graphics.setColor(1, 1, 1, 1)

    if m.hp and m.maxHp and m.hp < m.maxHp and m.alive and not m.isBurrowed then
        drawHealthBar(m, mType)
    end

    if debugMode and not m.isBurrowed then
        local r = m.radius or 12
        love.graphics.setColor(1, 0, 0, 0.7)
        love.graphics.rectangle("line", m.x - r, m.y - r, r * 2, r * 2)
    end
end

return Monsters
