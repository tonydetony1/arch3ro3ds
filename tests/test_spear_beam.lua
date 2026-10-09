-- tests/test_spear_beam.lua
-- The Brightspear is a hitscan weapon: its beam hits every monster on its line at once, is
-- stopped by the first rock, and each target after the first takes less damage (piercing rule).
-- It used to test the collision only at the far end of the beam (450 px away), so it never hit.

love = love or {}
love.timer = love.timer or { getTime = function() return 0 end }
love.image = love.image or { newImageData = function() return {} end }
love.filesystem = love.filesystem or { write = function() return true end, read = function() return nil end }
love.graphics = love.graphics or {}
if not getmetatable(love.graphics) then
    setmetatable(love.graphics, { __index = function() return function() return {} end end })
end

local GameState = require("src.states.game")
local Projectile = require("src.entities.projectile")
local ObstacleManager = require("src.core.obstacle_manager")
local Player = require("src.entities.player")
local Dummy = require("src.entities.dummy")
local Pool = require("src.core.pool")
local Audio = require("src.audio.audio")

-- Particle and floating text pools, without the GPU texture atlas
local VFX = require("src.render.vfx_manager")
local buildAtlas = VFX.buildTextureAtlas
VFX.buildTextureAtlas = function() end
VFX.init()
VFX.buildTextureAtlas = buildAtlas

local SPEAR = { damage = 34, range = 450, radius = 3.5, projectile_speed = 1800, is_hitscan = true }

local function beam()
    local proj = Projectile.create(1)
    proj:spawn(100, 100, 1, 0, SPEAR, false, 0, false, {})
    return proj
end

-- A game with monsters at the given x positions on the beam line (y = 100) plus one off the line
local function arena(rocks)
    local om = ObstacleManager.new()
    om.rocks = rocks or {}
    local g = setmetatable({
        dummyPool = Pool.new(8, Dummy.create), player = Player.new(100, 100),
        acquiredSkills = {}, obstacleManager = om, deaths = 0,
    }, { __index = GameState })
    g.handleMonsterDeath = function(self, target)
        self.deaths = self.deaths + 1
        self.dummyPool:free(target)
    end
    return g
end

local function spawn(g, x, y, hp)
    local m = g.dummyPool:obtain()
    m:spawn(x, y, hp or 200, "slime")
    return m
end

local function fire(g, proj)
    local realPlay = Audio.play
    Audio.play = function() end
    g:fireBeam(proj)
    Audio.play = realPlay
end

local T = {}

T["the beam hits every monster on its line, not the ones beside it"] = function()
    local g = arena()
    local a, b, off = spawn(g, 200, 100), spawn(g, 300, 100), spawn(g, 250, 140)
    fire(g, beam())
    assert(a.hp == 200 - 34, "first target lost " .. (200 - a.hp))
    assert(b.hp < 200, "second target not hit")
    assert(off.hp == 200, "a monster beside the beam was hit")
end

T["each target after the first takes 33% less"] = function()
    local g = arena()
    local a, b = spawn(g, 200, 100), spawn(g, 300, 100)
    fire(g, beam())
    assert(a.hp == 166 and b.hp == 200 - 22, "hp " .. a.hp .. " / " .. b.hp)
end

T["the first rock on the way stops the beam"] = function()
    local g = arena({ { x = 150, y = 80, w = 20, h = 40 } })
    local hidden = spawn(g, 250, 100)
    local proj = beam()
    fire(g, proj)
    assert(hidden.hp == 200, "the beam went through a rock")
    assert(proj.laserEndX < 155, "the drawn beam must end at the rock, ends at " .. proj.laserEndX)
end

T["a monster in front of the rock is still hit"] = function()
    local g = arena({ { x = 150, y = 80, w = 20, h = 40 } })
    local near = spawn(g, 125, 100)
    fire(g, beam())
    assert(near.hp < 200)
end

T["a beam only fires once"] = function()
    local g = arena()
    local a = spawn(g, 200, 100)
    local proj = beam()
    fire(g, proj)
    fire(g, proj)
    assert(a.hp == 166, "hit twice: " .. a.hp)
end

T["a monster killed by the beam goes through the death handling"] = function()
    local g = arena()
    spawn(g, 200, 100, 10)
    fire(g, beam())
    assert(g.deaths == 1, "deaths " .. g.deaths)
end

return T
