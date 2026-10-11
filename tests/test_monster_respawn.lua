-- tests/test_monster_respawn.lua
-- Monster slots are pooled: a slot reused for a new monster must not keep the state of the
-- boss that used it before (its brain phase, its phase-change invulnerability).

love = love or {}
love.timer = love.timer or { getTime = function() return 0 end }
love.image = love.image or { newImageData = function() return {} end }
love.filesystem = love.filesystem or { write = function() return true end, read = function() return nil end }
love.graphics = love.graphics or {}
if not getmetatable(love.graphics) then
    setmetatable(love.graphics, { __index = function() return function() return {} end end })
end

local Dummy = require("src.entities.dummy")
local AIController = require("src.core.ai_controller")
local BossBrain = require("src.core.boss_brain")

-- Minimal context: the brain only needs these to enter a phase
local function ctx()
    local c = { player = { x = 320, y = 400, radius = 9 }, mapW = 640, mapH = 480 }
    c.rng = function() return 0.5 end
    c.fire = function() return true end
    c.lob = function() end
    c.summon = function() end
    c.minionCount = function() return 0 end
    c.shotCount = function() return 0 end
    c.clearShots = function() end
    c.steer = function() end
    c.move = function() end
    c.freeSpot = function(x, y) return x, y end
    c.contact = function() return true end
    c.fx = function() end
    return c
end

local function spawnBoss(d, monsterType)
    d:spawn(320, 160, 1000, monsterType)
    d.isBoss = true
    return d
end

local T = {}

T["a boss spawned in a reused slot starts in phase 1"] = function()
    local d = spawnBoss(Dummy.create(1), "golem")
    d.hp = 100
    BossBrain.update(d, 1 / 30, ctx())
    assert(d.brain.phase == 3)

    spawnBoss(d, "skeleton_king")
    BossBrain.update(d, 1 / 30, ctx())
    assert(d.brain.phase == 1, "the new boss inherited the previous boss's phase " .. d.brain.phase)
end

T["a monster spawned in a reused slot can be hurt"] = function()
    local d = spawnBoss(Dummy.create(1), "golem")
    d.hp = 600
    BossBrain.update(d, 1 / 30, ctx()) -- phase 2: stunned and invulnerable
    assert(d.bossInvuln == true)

    d:spawn(320, 160, 50, "slime")
    assert(AIController.canTakeDamage(d), "the slime inherited the boss's phase-change invulnerability")
end

return T
