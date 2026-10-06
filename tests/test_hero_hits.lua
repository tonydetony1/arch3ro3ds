-- tests/test_hero_hits.lua
-- Damage on the hero: the Star bubble, the dash and the revive window block every enemy shot,
-- and the dodge chance applies to shots, blasts and contact hits alike (hazards excepted).

love = love or {}
love.timer = love.timer or { getTime = function() return 0 end }
love.image = love.image or { newImageData = function() return {} end }
love.filesystem = love.filesystem or { write = function() return true end, read = function() return nil end }
love.graphics = love.graphics or {}
if not getmetatable(love.graphics) then
    setmetatable(love.graphics, { __index = function() return function() return {} end end })
end

local AIController = require("src.core.ai_controller")
local Player = require("src.entities.player")
local Dummy = require("src.entities.dummy")
local GameState = require("src.states.game")

-- Particle and floating text pools, without the GPU texture atlas
local VFX = require("src.render.vfx_manager")
local buildAtlas = VFX.buildTextureAtlas
VFX.buildTextureAtlas = function() end
VFX.init()
VFX.buildTextureAtlas = buildAtlas

-- Runs `fn` with math.random returning a fixed value
local function withRoll(value, fn)
    local real = math.random
    math.random = function() return value end
    local ok, err = pcall(fn)
    math.random = real
    assert(ok, err)
end

local function hero(hp)
    local p = Player.new(100, 100)
    p.hp, p.maxHp = hp or 100, 100
    return p
end

local function game(player)
    return setmetatable({ player = player, isGameOver = false, gameOverTimer = 0 }, { __index = GameState })
end

local T = {}

T["the Star bubble blocks damage"] = function()
    local p = hero()
    p.starActive = 1.5
    local dealt, blocked, reason = p:takeDamage(30)
    assert(dealt == 0 and blocked and reason == "invulnerable")
    assert(p.hp == 100)
end

T["a dodge roll blocks damage only when the source can be dodged"] = function()
    withRoll(0.1, function()
        local p = hero()
        p.dodgeChance = 0.5
        local dealt, blocked, reason = p:takeDamage(30, true)
        assert(blocked and reason == "dodge" and p.hp == 100)
        dealt, blocked = p:takeDamage(30)
        assert(not blocked and dealt == 30 and p.hp == 70, "hazards must not be dodgeable")
    end)
end

T["an enemy shot is blocked by the Star bubble"] = function()
    local p = hero()
    p.starActive = 1.5
    local g = game(p)
    assert(g:hurtHero(25) == false)
    assert(p.hp == 100, "the hero lost HP through the Star bubble")
end

T["an enemy shot is blocked by the revive window"] = function()
    local p = hero(50)
    p.starActive = 2.0 -- set when the extra life kicks in
    assert(game(p):hurtHero(25) == false)
    assert(p.hp == 50)
end

T["an enemy shot hurts the hero and can end the run"] = function()
    local p = hero(20)
    local g = game(p)
    assert(g:hurtHero(25) == true)
    assert(p.hp == 0 and g.isGameOver, "the run must end at 0 HP")
end

T["an enemy shot can be dodged"] = function()
    withRoll(0.1, function()
        local p = hero()
        p.dodgeChance = 0.5
        assert(game(p):hurtHero(25) == false and p.hp == 100)
    end)
end

T["a dodged contact hit counts as an attack: the monster waits its cooldown"] = function()
    withRoll(0.1, function()
        AIController.setDamageScale(1)
        local p = hero()
        p.dodgeChance = 0.5
        local slime = Dummy.create(1)
        slime:spawn(100, 100, 50, "slime")
        slime.cooldown = 0
        AIController.update(slime, 0.016, p, nil, nil, nil, nil, 640, 480)
        assert(p.hp == 100, "contact hit not dodged")
        assert(slime.cooldown > 0, "a dodged hit must not be retried every frame")
    end)
end

return T
