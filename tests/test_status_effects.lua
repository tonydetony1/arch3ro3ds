-- tests/test_status_effects.lua
-- Elemental statuses on monsters: poison and fire keep ticking while the target is shot
-- continuously, a freeze cannot be chained forever, bosses are only lightly affected, and
-- a monster killed by anything other than an arrow still goes through the death handling.

love = love or {}
love.timer = love.timer or { getTime = function() return 0 end }
love.image = love.image or { newImageData = function() return {} end }
love.filesystem = love.filesystem or { write = function() return true end, read = function() return nil end }
love.graphics = love.graphics or {}
if not getmetatable(love.graphics) then
    setmetatable(love.graphics, { __index = function() return function() return {} end end })
end

local Dummy = require("src.entities.dummy")
local Player = require("src.entities.player")
local Pool = require("src.core.pool")
local GameState = require("src.states.game")

-- Particle and floating text pools, without the GPU texture atlas
local VFX = require("src.render.vfx_manager")
local buildAtlas = VFX.buildTextureAtlas
VFX.buildTextureAtlas = function() end
VFX.init()
VFX.buildTextureAtlas = buildAtlas

local DT = 1 / 60

local function hero()
    local p = Player.new(100, 100)
    p.hp, p.maxHp = 1e9, 1e9
    return p
end

local function monster(x, hp, kind, isBoss)
    local d = Dummy.create(1)
    d:spawn(x, 100, hp, kind or "slime")
    d.isBoss = isBoss or false
    return d
end

-- Hits `d` with 1-damage arrows every `hitEvery` seconds for `seconds`; returns the HP lost
-- beyond the arrows themselves (the status damage) and the number of hits
local function shoot(d, p, elements, hitEvery, seconds)
    local t, nextHit, hits = 0, 0, 0
    local start = d.hp
    while t < seconds and d.hp > 0 do
        if t >= nextHit then
            d:takeDamage(1, 1, 0, elements)
            hits = hits + 1
            nextHit = nextHit + hitEvery
        end
        d:update(DT, p, nil, nil, nil, nil, 2000, 2000)
        t = t + DT
    end
    return start - d.hp - hits, hits
end

local T = {}

T["poison keeps ticking while the target is shot continuously"] = function()
    local lost = shoot(monster(900, 400), hero(), { poison = true }, 0.16, 5)
    assert(lost >= 100, "poison dealt only " .. lost)
end

T["fire keeps ticking while the target is shot continuously"] = function()
    local lost = shoot(monster(900, 400), hero(), { fire = true }, 0.16, 5)
    assert(lost >= 150, "fire dealt only " .. lost)
end

T["a boss takes far less from burning and poison than a normal monster"] = function()
    local normal = shoot(monster(900, 4000), hero(), { fire = true, poison = true }, 0.35, 5)
    local boss = shoot(monster(900, 4000, "golem", true), hero(), { fire = true, poison = true }, 0.35, 5)
    assert(boss < normal * 0.4, string.format("boss lost %d, normal lost %d", boss, normal))
end

T["a monster killed by poison stays for the game to resolve"] = function()
    local d, p = monster(900, 10), hero()
    d:takeDamage(1, 1, 0, { poison = true })
    local keepAlive = true
    for _ = 1, 600 do
        keepAlive = d:update(DT, p, nil, nil, nil, nil, 2000, 2000)
        if d.hp <= 0 then break end
    end
    assert(d.hp <= 0, "poison never killed the monster")
    assert(keepAlive ~= false, "update must not free the monster silently")
end

T["a freeze is not extended by further hits"] = function()
    local d, p = monster(900, 1e6), hero()
    local t, nextHit = 0, 0
    while t < 1.0 do
        if t >= nextHit then d:takeDamage(1, 1, 0, { ice = true }); nextHit = nextHit + 0.35 end
        d:update(DT, p, nil, nil, nil, nil, 2000, 2000)
        t = t + DT
    end
    assert(d.status.freeze <= 0.45, "freeze still " .. d.status.freeze .. " s after 1 s")
end

T["a monster moves again after a freeze even if it keeps being hit"] = function()
    local d, p = monster(500, 1e6, "wolf"), hero()
    local x0, t, nextHit = d.x, 0, 0
    while t < 6 do
        if t >= nextHit then d:takeDamage(1, 1, 0, { ice = true }); nextHit = nextHit + 0.35 end
        d:update(DT, p, nil, nil, nil, nil, 2000, 2000)
        t = t + DT
    end
    assert(x0 - d.x > 100, "wolf only moved " .. (x0 - d.x) .. " px in 6 s")
end

T["a boss is frozen only briefly"] = function()
    local d, p = monster(900, 1e6, "golem", true), hero()
    d:takeDamage(1, 1, 0, { ice = true })
    for _ = 1, 40 do d:update(DT, p, nil, nil, nil, nil, 2000, 2000) end -- 0.67 s
    assert(d.status.freeze <= 0, "boss still frozen after 0.67 s")
end

T["every monster at 0 HP goes through the death handling, once"] = function()
    local g = setmetatable({ dummyPool = Pool.new(8, Dummy.create), deaths = {} }, { __index = GameState })
    g.handleMonsterDeath = function(self, target)
        self.deaths[#self.deaths + 1] = target
        self.dummyPool:free(target)
    end
    local alive = g.dummyPool:obtain(); alive:spawn(0, 0, 50, "slime")
    local burnt = g.dummyPool:obtain(); burnt:spawn(0, 0, 50, "slime"); burnt.hp = -4
    local orbited = g.dummyPool:obtain(); orbited:spawn(0, 0, 50, "slime"); orbited.hp = 0
    g:resolveDeaths()
    assert(#g.deaths == 2, "expected 2 deaths, got " .. #g.deaths)
    assert(alive.alive and not burnt.alive and not orbited.alive)
    g:resolveDeaths()
    assert(#g.deaths == 2, "a dead monster must not be resolved twice")
end

return T
