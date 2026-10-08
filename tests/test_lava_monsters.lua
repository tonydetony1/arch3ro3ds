-- tests/test_lava_monsters.lua
-- Lava burns the ground monsters standing in it, whether or not the hero is in the lava.
-- It used to burn them only on the frames when the hero took lava damage himself.

love = love or {}
love.timer = love.timer or { getTime = function() return 0 end }
love.image = love.image or { newImageData = function() return {} end }
love.filesystem = love.filesystem or { write = function() return true end, read = function() return nil end }
love.graphics = love.graphics or {}
if not getmetatable(love.graphics) then
    setmetatable(love.graphics, { __index = function() return function() return {} end end })
end

local ObstacleManager = require("src.core.obstacle_manager")
local Dummy = require("src.entities.dummy")
local Pool = require("src.core.pool")

-- Particle and floating text pools, without the GPU texture atlas
local VFX = require("src.render.vfx_manager")
local buildAtlas = VFX.buildTextureAtlas
VFX.buildTextureAtlas = function() end
VFX.init()
VFX.buildTextureAtlas = buildAtlas

local function lavaRoom()
    local om = ObstacleManager.new()
    om.hazards = { { kind = "lava", x = 0, y = 0, w = 200, h = 200 } }
    local pool = Pool.new(8, Dummy.create)
    return om, pool
end

local function monster(pool, x, y, kind)
    local m = pool:obtain()
    m:spawn(x, y, 500, kind or "slime")
    return m
end

local function run(om, pool, seconds)
    local t = 0
    while t < seconds do
        om:update(1 / 60, nil, nil, pool)
        t = t + 1 / 60
    end
end

local T = {}

T["a monster standing in lava burns even without the hero"] = function()
    local om, pool = lavaRoom()
    local m = monster(pool, 100, 100)
    run(om, pool, 1.3)
    assert(500 - m.hp >= 24, "lost only " .. (500 - m.hp))
    assert(500 - m.hp <= 48, "burns too fast: " .. (500 - m.hp))
end

T["a monster outside the lava is not hurt"] = function()
    local om, pool = lavaRoom()
    local m = monster(pool, 400, 400)
    run(om, pool, 1.3)
    assert(m.hp == 500)
end

T["flying monsters ignore the lava"] = function()
    local om, pool = lavaRoom()
    local bat = monster(pool, 100, 100, "bat")
    run(om, pool, 1.3)
    assert(bat.hp == 500)
end

return T
