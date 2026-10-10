-- tests/test_orbitals.lua
-- Orbiting blades and shields hit a monster they touch on a fixed interval, so their damage
-- does not depend on the frame rate (60 FPS on PC, 30 to 45 on Old 3DS).

love = love or {}
love.timer = love.timer or { getTime = function() return 0 end }
love.image = love.image or { newImageData = function() return {} end }
love.filesystem = love.filesystem or { write = function() return true end, read = function() return nil end }
love.graphics = love.graphics or {}
if not getmetatable(love.graphics) then
    setmetatable(love.graphics, { __index = function() return function() return {} end end })
end

local Player = require("src.entities.player")
local Dummy = require("src.entities.dummy")

local HP = 100000

-- Hero with one blade and a monster big enough to touch the blade all the way round
local function setup()
    local p = Player.new(200, 200)
    p.orbitals = { { type = "fire", angle = 0, dist = 26, dmg = 20 } }
    local d = Dummy.create(1)
    d:spawn(200, 200, HP, "golem")
    d.radius = 40
    d.alive = true -- set by Pool:obtain in game
    local pool = { activeCount = 1, activeList = { 1 }, items = { d } }
    return p, d, pool
end

-- Damage dealt by the blade in `seconds` at `fps`
local function damageOver(seconds, fps)
    local p, d, pool = setup()
    local dt = 1 / fps
    for _ = 1, math.floor(seconds * fps + 0.5) do p:updateOrbitals(dt, pool, nil) end
    return HP - d.hp
end

local T = {}

T["orbital damage does not depend on the frame rate"] = function()
    local at30, at60 = damageOver(1, 30), damageOver(1, 60)
    assert(at30 == at60, string.format("30 FPS dealt %d, 60 FPS dealt %d", at30, at60))
end

T["an orbital hits a touching monster on an interval, not every frame"] = function()
    local dealt = damageOver(1, 60)
    assert(dealt > 0, "the blade never hit")
    assert(dealt <= 20 * (1 / Player.ORBITAL_HIT_INTERVAL + 1),
        string.format("%d damage in 1 s: the blade hits every frame", dealt))
end

return T
