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

-- Runs `fn` with the Glory talent at `level` (it adds a free draft at the start of every run).
-- The talent is restored and no saved run is left behind, whatever happens in `fn`.
local function withGlory(level, fn)
    local talents = Save.getTalents()
    local glory = talents.glory
    talents.glory = level
    Save.clearRun()
    local ok, err = pcall(fn)
    talents.glory = glory
    Save.clearRun()
    assert(ok, err)
end

local function withoutGlory(fn) withGlory(0, fn) end

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
        assert(g.queuedDrafts == 0)
    end) end)
end

T["an Act II launch saves no run before the first floor is played"] = function()
    withLoveStubs(function() withoutGlory(function()
        local g = newGame()
        g:enter({ mode = "ascension", act = 2 })
        assert(Save.getRun() == nil, "a run snapshot was saved on entry: it would resume without the head start")
    end) end)
end

T["entering the first floor of Act II does not count a cleared room for the quests"] = function()
    withLoveStubs(function() withoutGlory(function()
        local before = Save.getDailyQuests().progress.rooms or 0
        local g = newGame()
        g:enter({ mode = "ascension", act = 2 })
        local after = Save.getDailyQuests().progress.rooms or 0
        assert(after == before, "room quest went from " .. before .. " to " .. after)
    end) end)
end

T["the Glory draft waits for the start wheel, then opens once"] = function()
    withLoveStubs(function() withGlory(1, function()
        local g = newGame()
        g:enter({ mode = "ascension" })
        assert(g.phase == "wheel", "floor 1 does not start with the wheel")
        assert(not g.isDrafting, "the Glory draft opened over the wheel")
        g:specialRoomDone()
        assert(g.isDrafting, "the Glory draft did not open after the wheel")
        g:pickDraft(1)
        assert(not g.isDrafting, "a second draft opened")
        assert(g.queuedDrafts == 0)
    end) end)
end

T["Glory adds one draft to the Act II head start"] = function()
    withLoveStubs(function() withGlory(1, function()
        local g = newGame()
        g:enter({ mode = "ascension", act = 2 })
        assert(not g.isDrafting, "a draft opened over the wheel")
        g:specialRoomDone()
        local total = Balance.ACT2_HEAD_START_DRAFTS + 1
        for i = 1, total do
            assert(g.isDrafting, "draft " .. i .. " did not open")
            g:pickDraft(1)
        end
        assert(not g.isDrafting, "one draft too many")
        assert(#g.acquiredSkills == total)
    end) end)
end

T["an admin start room skips the Act II head start"] = function()
    withLoveStubs(function() withoutGlory(function()
        local g = newGame()
        g:enter({ mode = "ascension", act = 2, startRoom = 30 })
        assert(g.roomNumber == 30, "started on floor " .. g.roomNumber)
        assert(g.queuedDrafts == 0, "queued " .. g.queuedDrafts .. " drafts")
        assert(not g.isDrafting)
    end) end)
end

-- Runs `fn(records)` and restores the records afterwards; no saved run is left behind either
-- (continuing into Act II writes a run snapshot on floor 51)
local function withRecords(fn)
    local records = Save.get().records
    local saved = {}
    for k, v in pairs(records) do saved[k] = v end
    Save.clearRun()
    local ok, err = pcall(fn, records)
    for k in pairs(records) do records[k] = nil end
    for k, v in pairs(saved) do records[k] = v end
    Save.clearRun()
    assert(ok, err)
end

-- An Ascension run that just cleared `room`
local function clearedFloor(room)
    local g = newGame()
    g:enter({ mode = "ascension" })
    g.roomNumber = room
    g:winRun()
    return g
end

-- Runs until the Act I choice is shown and its input grace has elapsed
local function reachChoice(g)
    runUntil(g, function(s) return s.phase == "act_choice" end)
    runUntil(g, function(s) return (s.actChoiceGrace or 0) <= 0 end)
end

T["clearing floor 50 offers to continue into Act II"] = function()
    withLoveStubs(function() withRecords(function()
        local g = clearedFloor(50)
        runUntil(g, function(s) return s.phase == "act_choice" or s.switched end)
        assert(g.phase == "act_choice", "the run ended without the choice")
    end) end)
end

T["CONTINUE goes on to floor 51 with the same build and gold"] = function()
    withLoveStubs(function() withRecords(function(records)
        local clears = records.ascensionClears or 0
        local g = clearedFloor(50)
        reachChoice(g)
        g.goldEarnedRun = 500
        local skills = #g.acquiredSkills
        g:chooseAct("continue")
        runUntil(g, function(s) return s.roomNumber == 51 end)
        assert(not g.switched, "the run ended")
        assert(g.goldEarnedRun == 500, "gold lost: " .. g.goldEarnedRun)
        assert(#g.acquiredSkills == skills)
        assert(records.ascensionClears == clears + 1, "the Act I clear was not counted")
    end) end)
end

T["END THE RUN opens the Act I victory screen"] = function()
    withLoveStubs(function() withRecords(function()
        local g = clearedFloor(50)
        reachChoice(g)
        g:chooseAct("finish")
        assert(g.switched and g.switched.name == "gameover" and g.switched.data.victory)
        assert(g.switched.data.act == 1)
    end) end)
end

T["clearing the last floor of Act II ends the run with its own victory"] = function()
    withLoveStubs(function() withRecords(function(records)
        local _, last = WorldManager.actFloors(2)
        local clears = records.act2Clears or 0
        local g = clearedFloor(last)
        runUntil(g, function(s) return s.switched or s.phase == "act_choice" end)
        assert(g.switched and g.switched.data.victory, "no victory screen")
        assert(g.switched.data.act == 2)
        assert(records.act2Clears == clears + 1, "the Act II clear was not counted")
    end) end)
end

T["the Act I choice answers to keys, console buttons and touch"] = function()
    withLoveStubs(function() withRecords(function()
        local g = clearedFloor(50)
        reachChoice(g)
        assert(g.actChoiceCursor == 1)
        g:drawBottom() -- the panel draws without error
        g:keypressed("down")
        assert(g.actChoiceCursor == 2, "down did not move the cursor")
        g:gamepadpressed(nil, "dpup")
        assert(g.actChoiceCursor == 1, "dpup did not move the cursor")
        g:gamepadpressed(nil, "dpdown")
        assert(g.actChoiceCursor == 2, "dpdown did not move the cursor")
        g:gamepadpressed(nil, "a") -- END THE RUN
        assert(g.switched and g.switched.name == "gameover", "A on the second button did not end the run")

        local g2 = clearedFloor(50)
        reachChoice(g2)
        g2:keypressed("return") -- confirms the choice instead of pausing (the stub has no push)
        assert(g2.phase == "transition", "return did not continue: " .. tostring(g2.phase))

        local g3 = clearedFloor(50)
        reachChoice(g3)
        g3:touchpressed(1, 160, 180) -- END THE RUN button
        assert(g3.switched and g3.switched.name == "gameover", "touching END THE RUN did not end the run")
    end) end)
end

T["the choice is ignored outside the end of Act I"] = function()
    withLoveStubs(function() withRecords(function()
        local g = newGame()
        g:enter({ mode = "ascension" })
        g.roomNumber = 20
        g:chooseAct("finish")
        assert(not g.switched, "chooseAct acted outside the choice")
    end) end)
end

T["pausing on the Act I choice is refused: abandoning would forfeit the clear"] = function()
    withLoveStubs(function() withRecords(function()
        local g = clearedFloor(50)
        local pushes = 0
        g.sm.push = function() pushes = pushes + 1 end
        reachChoice(g)
        local pb = g.pauseBtn
        g:gamepadpressed(nil, "start")
        g:touchpressed(1, pb.x + pb.w / 2, pb.y + pb.h / 2)
        g:keypressed("escape")
        g:keypressed("p")
        assert(pushes == 0, "the pause screen opened " .. pushes .. " time(s) on the choice")
        assert(g.phase == "act_choice", "the choice was lost: " .. tostring(g.phase))
    end) end)
end

T["a tap right after the Act I choice appears is ignored"] = function()
    withLoveStubs(function() withRecords(function()
        local g = clearedFloor(50)
        runUntil(g, function(s) return s.phase == "act_choice" end)
        g:chooseAct("continue")
        g:touchpressed(1, 160, 120) -- on the CONTINUE button
        assert(g.phase == "act_choice", "an early tap picked: " .. tostring(g.phase))
        runUntil(g, function(s) return (s.actChoiceGrace or 0) <= 0 end)
        g:chooseAct("continue")
        assert(g.phase == "transition", "the choice never opened: " .. tostring(g.phase))
    end) end)
end

T["RETRY after an Act II run starts Act II again"] = function()
    withLoveStubs(function()
        local GameOverState = require("src.states.gameover")
        local launched
        local screen = setmetatable({
            sm = { switch = function(_, name, params) launched = { name = name, params = params } end },
            data = { mode = "ascension", act = 2, room = 55 },
        }, { __index = GameOverState })
        screen:retryRun()
        assert(launched.name == "game" and launched.params.act == 2, "RETRY lost the act")
    end)
end

T["the end-of-run screen names the act and clamps the best floor to it"] = function()
    withLoveStubs(function()
        local GameOverState = require("src.states.gameover")
        local PixelFont = require("src.ui.pixel_font")
        local printed = {}
        local printf = PixelFont.printf
        PixelFont.printf = function(text, ...) printed[#printed + 1] = tostring(text) end
        local ok, err = pcall(function()
            for _, act in ipairs({ 1, 2 }) do
                local _, last = WorldManager.actFloors(act)
                local screen = GameOverState.new({})
                screen:enter({ mode = "ascension", act = act, room = last, victory = true, bestRoom = 99 })
                screen:drawTop()
                screen:drawBottom()
            end
        end)
        PixelFont.printf = printf
        assert(ok, err)
        local seen = table.concat(printed, "|")
        local _, last2 = WorldManager.actFloors(2)
        -- The subtitle gives the floor reached, not a floor count (an Act II run starts on floor 51)
        assert(seen:find("ACT I COMPLETE - FLOOR 50", 1, true), "no ACT I title: " .. seen)
        assert(seen:find("ACT II COMPLETE - FLOOR " .. last2, 1, true), "no ACT II title: " .. seen)
        assert(not seen:find("FLOORS", 1, true), "a floor count is still shown: " .. seen)
        assert(seen:find("BEST 50/50", 1, true), "BEST not clamped to Act I: " .. seen)
        assert(seen:find("BEST " .. last2 .. "/" .. last2, 1, true), "BEST not clamped to Act II")
    end)
end

return T
