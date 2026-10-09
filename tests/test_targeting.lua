-- tests/test_targeting.lua
-- Auto-aim: the hero targets the nearest monster it can actually hit. Rocks stop arrows, so a
-- monster hiding behind one is only chosen when nothing else is in sight.

love = love or {}
love.timer = love.timer or { getTime = function() return 0 end }
love.image = love.image or { newImageData = function() return {} end }
love.filesystem = love.filesystem or { write = function() return true end, read = function() return nil end }
love.graphics = love.graphics or {}
if not getmetatable(love.graphics) then
    setmetatable(love.graphics, { __index = function() return function() return {} end end })
end

local Player = require("src.entities.player")
local ObstacleManager = require("src.core.obstacle_manager")

-- A 40x40 rock at (100, 80)-(140, 120)
local function rockRoom()
    local om = ObstacleManager.new()
    om.rocks = { { x = 100, y = 80, w = 40, h = 40 } }
    return om
end

local function pool(...)
    local items, list = {}, {}
    for i, m in ipairs({ ... }) do
        m.alive = true
        items[i], list[i] = m, i
    end
    return { items = items, activeList = list, activeCount = #list }
end

local function hero()
    local p = Player.new(50, 100)
    p.detectionRadius = 350
    return p
end

local T = {}

T["a shot is blocked by a rock in the way, not by one beside it"] = function()
    local om = rockRoom()
    assert(om:isShotBlocked(50, 100, 200, 100, 3) == true)
    assert(om:isShotBlocked(50, 40, 200, 40, 3) == false)
    assert(om:isShotBlocked(50, 100, 90, 100, 3) == false, "the shot stops before the rock")
end

T["a diagonal shot clipping the rock corner is blocked"] = function()
    local om = rockRoom()
    assert(om:isShotBlocked(60, 60, 150, 130, 3) == true)
    assert(om:isShotBlocked(60, 60, 150, 70, 3) == false)
end

T["targets the nearest monster in sight rather than a nearer one behind a rock"] = function()
    local hidden = { x = 200, y = 100 }   -- 150 px away, behind the rock
    local exposed = { x = 50, y = 270 }   -- 170 px away, in the open
    local target = hero():findNearestTarget(pool(hidden, exposed), rockRoom())
    assert(target == exposed, "the hero aimed into the rock")
end

T["still aims at a hidden monster when nothing is in sight"] = function()
    local hidden = { x = 200, y = 100 }
    assert(hero():findNearestTarget(pool(hidden), rockRoom()) == hidden)
end

T["without obstacles the nearest monster wins"] = function()
    local near, far = { x = 120, y = 100 }, { x = 300, y = 100 }
    assert(hero():findNearestTarget(pool(far, near), nil) == near)
    assert(hero():findNearestTarget(pool(far, near), ObstacleManager.new()) == near)
end

T["monsters out of detection range are ignored"] = function()
    assert(hero():findNearestTarget(pool({ x = 900, y = 100 }), nil) == nil)
end

return T
