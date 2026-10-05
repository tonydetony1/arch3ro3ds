-- tests/test_loot_bounds.lua
-- Loot bounces inside the current room, not inside the old 400 x 240 screen area: a chest
-- dropped by a boss in a far corner must land there.

-- Minimal LÖVE environment: every graphics call is a no-op
love = love or {}
love.timer = love.timer or { getTime = function() return 0 end }
love.image = love.image or { newImageData = function() return {} end }
love.graphics = love.graphics or {}
if not getmetatable(love.graphics) then
    setmetatable(love.graphics, { __index = function() return function() return {} end end })
end

local Loot = require("src.entities.loot")

local T = {}

T["loot dropped near the far corner of a room stays near it"] = function()
    math.randomseed(3)
    Loot.setBounds(640, 480)
    local l = Loot.create(1)
    l:spawn(560, 420, "chest", 1)
    for _ = 1, 120 do l:update(1 / 60, -1000, -1000) end -- hero far away: no pickup
    assert(l.x > 400 and l.y > 240, string.format("loot moved to %.0f, %.0f", l.x, l.y))
    assert(l.x <= 640 - 24 and l.y <= 480 - 24, string.format("loot left the room: %.0f, %.0f", l.x, l.y))
end

return T
