-- tests/test_combat_physics.lua
-- Combat physics: the hero starts and stops instantly (the stick drives the speed
-- directly, ice excepted), monsters are not stunned by arrows, and arrow skills follow
-- the arrow damage rules: extra front arrows split the damage, a critical hit uses the
-- critical damage stat, a ricochet loses 30% per bounce, a piercing arrow 33%, a wall bounce 50%.

love = love or {}
love.timer = love.timer or { getTime = function() return 0 end }
love.image = love.image or { newImageData = function() return {} end }
love.filesystem = love.filesystem or { write = function() return true end, read = function() return nil end }
love.joystick = love.joystick or { getJoystickCount = function() return 0 end, getJoysticks = function() return {} end }
love.keyboard = love.keyboard or { isDown = function() return false end }
love.graphics = love.graphics or {}
if not getmetatable(love.graphics) then
    setmetatable(love.graphics, { __index = function() return function() return {} end end })
end

local CombatRules = require("src.data.combat_rules")
local Player = require("src.entities.player")
local Projectile = require("src.entities.projectile")
local Dummy = require("src.entities.dummy")
local Pool = require("src.core.pool")
local Audio = require("src.audio.audio")

-- Particle and floating text pools, without the GPU texture atlas
local VFX = require("src.render.vfx_manager")
local buildAtlas = VFX.buildTextureAtlas
VFX.buildTextureAtlas = function() end
VFX.init()
VFX.buildTextureAtlas = buildAtlas

local DT = 1 / 60

local function hero()
    local p = Player.new(300, 300)
    p.critChance = 0
    return p
end

local function stick(p, x, y)
    p.benchInputX, p.benchInputY = x, y
end

-- Arrows fired by one shot of `p`, sorted by angle so the front arrows come in a fixed order
local function shotOf(p)
    local realPlay = Audio.playWeapon
    Audio.playWeapon = function() end
    local pool = Pool.new(16, Projectile.create)
    p:shoot(pool)
    Audio.playWeapon = realPlay
    local out = {}
    for i = 1, pool.activeCount do out[i] = pool.items[pool.activeList[i]] end
    return out, pool
end

local T = {}

-- ----------------------------------------------------------------- movement
T["the hero reaches full speed on the first frame"] = function()
    local p = hero()
    stick(p, 1, 0)
    p:handleInput(DT)
    assert(math.abs(p.vx - p.speed) < 1e-6, "vx " .. p.vx)
end

T["the stick scales the speed directly"] = function()
    local p = hero()
    stick(p, 0.5, 0)
    p:handleInput(DT)
    assert(math.abs(p.vx - p.speed * 0.5) < 1e-6, "vx " .. p.vx)
end

T["the hero stops on the frame the stick is released"] = function()
    local p = hero()
    stick(p, 1, 0)
    p:handleInput(DT)
    stick(p, 0, 0)
    p:handleInput(DT)
    assert(p.vx == 0 and p.vy == 0, "still sliding at " .. p.vx)
    assert(p.isMoving == false)
end

T["the hero still slides on ice"] = function()
    local p = hero()
    stick(p, 1, 0)
    for _ = 1, 10 do p:handleInput(DT) end
    p.terrainSlip = 1.0
    stick(p, 0, 0)
    p:handleInput(DT)
    assert(p.vx > 10, "no slide on ice, vx " .. p.vx)
end

T["a shockwave pushes the hero a short way, whatever the stick does"] = function()
    local p = hero()
    local x0 = p.x
    p:push(320, 0)
    stick(p, 0, 0)
    for _ = 1, 40 do
        p:handleInput(DT)
        p:updatePush(DT, nil)
    end
    assert(p.x - x0 > 15 and p.x - x0 < 45, "pushed " .. (p.x - x0) .. " px")
    assert(p.pushX == 0 and p.pushY == 0, "the push must fade out")
end

-- -------------------------------------------------------- monsters keep coming
T["an arrow does not stun a monster"] = function()
    local d = Dummy.create(1)
    d:spawn(500, 100, 1e6, "wolf")
    d:takeDamage(1, 1, 0)
    assert(d.hitStop == 0, "hit-stun " .. d.hitStop)
end

-- --------------------------------------------------------------- arrow skills
T["a single front arrow deals the full damage"] = function()
    local arrows = shotOf(hero())
    assert(#arrows == 1 and arrows[1].damage == 15, "damage " .. tostring(arrows[1] and arrows[1].damage))
end

T["two front arrows deal 75% each"] = function()
    local p = hero()
    p.frontArrows = 2
    local arrows = shotOf(p)
    assert(#arrows == 2)
    for _, a in ipairs(arrows) do assert(a.damage == 11, "damage " .. a.damage) end
end

T["three front arrows deal about 56% each"] = function()
    local p = hero()
    p.frontArrows = 3
    local arrows = shotOf(p)
    assert(#arrows == 3)
    for _, a in ipairs(arrows) do assert(a.damage == 8, "damage " .. a.damage) end
end

T["diagonal arrows keep the full damage"] = function()
    local p = hero()
    p.diagArrows = 1
    local arrows = shotOf(p)
    assert(#arrows == 3)
    for _, a in ipairs(arrows) do assert(a.damage == 15, "damage " .. a.damage) end
end

T["a critical hit uses the critical damage stat"] = function()
    local p = hero()
    p.critChance = 1
    p.critMultiplier = 3.0
    local arrows = shotOf(p)
    assert(arrows[1].damage == 45, "damage " .. arrows[1].damage)
    p.critMultiplier = 2.0
    assert(shotOf(p)[1].damage == 30)
end

T["a ricochet can bounce three times"] = function()
    local p = hero()
    p.hasRicochet = true
    assert(shotOf(p)[1].bouncesLeft == 3)
end

T["a ricochet loses 30% per bounce"] = function()
    local proj = Projectile.create(1)
    proj.damage = 100
    proj:onRicochet()
    assert(proj.damage == 70)
    proj:onRicochet()
    assert(proj.damage == 49)
end

T["a piercing arrow loses 33% on each target"] = function()
    local proj = Projectile.create(1)
    proj.damage = 100
    proj:onPierce()
    assert(proj.damage == 67)
end

T["a wall bounce halves the damage"] = function()
    local proj = Projectile.create(1)
    proj:spawn(21, 100, -1, 0, { projectile_speed = 260, damage = 40, radius = 3 }, false, 0, false,
        { canBounceWalls = true, wallBouncesLeft = 2 })
    proj:update(DT, 640, 480, nil, nil, nil)
    assert(proj.wallBouncesLeft == 1 and proj.vx > 0, "no bounce")
    assert(proj.damage == 20, "damage " .. proj.damage)
end

T["combat rules expose the arrow constants"] = function()
    assert(CombatRules.frontArrowFactor(1) == 1)
    assert(math.abs(CombatRules.frontArrowFactor(2) - 0.75) < 1e-9)
    assert(CombatRules.RICOCHET_BOUNCES == 3)
end

return T
