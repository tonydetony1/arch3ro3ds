-- tests/test_ai_damage.lua
-- Monster damage on the hero: scaled with the room depth (WorldManager.damageMult) and
-- blocked by the hero's dash invulnerability, like projectiles already are.

-- Minimal LÖVE environment: every graphics call is a no-op
love = love or {}
love.timer = love.timer or { getTime = function() return 0 end }
love.image = love.image or { newImageData = function() return {} end }
love.graphics = love.graphics or {}
if not getmetatable(love.graphics) then
    setmetatable(love.graphics, { __index = function() return function() return {} end end })
end

local AIController = require("src.core.ai_controller")
local Player = require("src.entities.player")
local Dummy = require("src.entities.dummy")

-- Particle and floating text pools, without the GPU texture atlas
local VFX = require("src.render.vfx_manager")
local buildAtlas = VFX.buildTextureAtlas
VFX.buildTextureAtlas = function() end
VFX.init()
VFX.buildTextureAtlas = buildAtlas

local T = {}

-- A slime standing on the hero, its contact attack ready
local function slimeOnHero()
    local player = Player.new(100, 100)
    player.hp, player.maxHp = 100, 100
    local slime = Dummy.create(1)
    slime:spawn(100, 100, 50, "slime")
    slime.cooldown = 0
    return player, slime
end

local function touch(player, slime)
    AIController.update(slime, 0.016, player, nil, nil, nil, nil, 640, 480)
end

T["contact damage: base value with a x1 scale"] = function()
    AIController.setDamageScale(1)
    local player, slime = slimeOnHero()
    touch(player, slime)
    assert(player.hp == 88, "slime contact must deal 12, hero has " .. player.hp)
end

T["contact damage: scaled by the room damage multiplier"] = function()
    AIController.setDamageScale(1.5)
    local player, slime = slimeOnHero()
    touch(player, slime)
    AIController.setDamageScale(1)
    assert(player.hp == 82, "12 x 1.5 = 18 expected, hero has " .. player.hp)
end

T["contact damage: ignored while the hero dashes"] = function()
    AIController.setDamageScale(1)
    local player, slime = slimeOnHero()
    player.isDashing = true
    touch(player, slime)
    assert(player.hp == 100, "a dashing hero is invulnerable, hero has " .. player.hp)
end

T["shot damage: scaled by the room damage multiplier"] = function()
    AIController.setDamageScale(2)
    local value = AIController.scaleDamage(14)
    AIController.setDamageScale(1)
    assert(value == 28, tostring(value))
end

return T
