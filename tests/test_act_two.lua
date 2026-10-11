-- tests/test_act_two.lua
-- Act II: launched from the hub on its first floor with a head start, reached from Act I by
-- CONTINUE, ended by its own victory. Bosses keep scaling with the absolute world depth.

local GameState = require("src.states.game")
local Save = require("src.data.save")
local Balance = require("src.data.balance")
local WorldManager = require("src.core.world_manager")
local EliteAffixes = require("src.core.elite_affixes")
local withLoveStubs = require("tests.love_stubs")

-- A game state whose switches to other states are recorded
local function newGame()
    local g = setmetatable({}, { __index = GameState })
    g.switched = nil
    g.sm = { switch = function(_, name, data) g.switched = { name = name, data = data } end }
    return g
end

-- Runs the game frame by frame until `done(g)` (a hit stop left by another test can hold frames)
local function runUntil(g, done)
    for _ = 1, 900 do
        if done(g) then return end
        g:update(1 / 60)
    end
    error("condition never reached")
end

local T = {}

T["bosses scale with the world depth, not the cycled world"] = function()
    withLoveStubs(function()
        local g = newGame()
        g:enter({ mode = "infinite" })
        g.roomNumber = 70
        g.pendingSpawns = { { x = 100, y = 100, hp = 500, type = "golem", isBoss = true } }
        g:spawnMonstersNow()
        local boss
        for i = 1, g.dummyPool.activeCount do
            local d = g.dummyPool.items[g.dummyPool.activeList[i]]
            if d.isBoss then boss = d end
        end
        assert(boss, "no boss spawned")
        assert(boss.chapterIndex == 7, "boss damage depth " .. tostring(boss.chapterIndex))
    end)
end

T["a volatile elite's blast scales with the world depth, not the cycled world"] = function()
    withLoveStubs(function()
        local g = newGame()
        g:enter({ mode = "infinite" })
        g.roomNumber = 70
        local d = g.dummyPool:obtain()
        d:spawn(100, 100, 50, "slime")
        EliteAffixes.apply(d, { "volatile" })
        assert(g.projectilePool.activeCount == 0, "a projectile is already in flight")
        g:handleMonsterDeath(d)
        assert(g.projectilePool.activeCount == 1, "the volatile elite left no blast")
        local bomb = g.projectilePool.items[g.projectilePool.activeList[1]]
        local expected = EliteAffixes.BLAST_BASE + EliteAffixes.BLAST_PER_CHAPTER * 7
        assert(bomb.damage == expected, "blast damage " .. tostring(bomb.damage) .. ", expected " .. expected)
    end)
end

T["the shooter cap follows the world depth in the Abyss"] = function()
    local Encounters = require("src.data.encounters")
    assert(Encounters.shooterCap(WorldManager.worldDepth(65)) == 3)
    local Director = require("src.core.encounter_director")
    local enc = Director.compose(WorldManager.worldOfRoom(65), 65)
    assert(enc.shooterCap == 3, "shooter cap on floor 65: " .. tostring(enc.shooterCap))
end

-- Runs `fn` with the Glory talent off (it adds a free draft at the start of every run)
local function withoutGlory(fn)
    local talents = Save.getTalents()
    local glory = talents.glory
    talents.glory = 0
    local ok, err = pcall(fn)
    talents.glory = glory
    assert(ok, err)
end

T["an Act II run starts on its first floor with the start wheel"] = function()
    withLoveStubs(function() withoutGlory(function()
        local g = newGame()
        g:enter({ mode = "ascension", act = 2 })
        assert(g.roomNumber == 51, "started on floor " .. g.roomNumber)
        assert(g.phase == "wheel", "no start wheel on floor 51: " .. tostring(g.phase))
    end) end)
end

T["the Act II head start chains its drafts after the wheel"] = function()
    withLoveStubs(function() withoutGlory(function()
        local g = newGame()
        g:enter({ mode = "ascension", act = 2 })
        g:specialRoomDone()
        for i = 1, Balance.ACT2_HEAD_START_DRAFTS do
            assert(g.isDrafting, "draft " .. i .. " did not open")
            g:pickDraft(1)
        end
        assert(not g.isDrafting, "one draft too many")
        assert(#g.acquiredSkills == Balance.ACT2_HEAD_START_DRAFTS)
    end) end)
end

T["a normal Ascension run still starts on floor 1"] = function()
    withLoveStubs(function() withoutGlory(function()
        local g = newGame()
        g:enter({ mode = "ascension" })
        assert(g.roomNumber == 1)
        g:specialRoomDone()
        assert(not g.isDrafting, "no head start in Act I")
    end) end)
end

T["the act is ignored outside the Ascension"] = function()
    withLoveStubs(function() withoutGlory(function()
        local g = newGame()
        g:enter({ mode = "infinite", act = 2 })
        assert(g.roomNumber == 1)
    end) end)
end

return T
