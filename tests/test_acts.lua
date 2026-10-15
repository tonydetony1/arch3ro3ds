-- tests/test_acts.lua
-- Acts of the Ascension: Act I = worlds 1-5 (floors 1-50), Act II = worlds 6-10 (floors 51-100).
-- Act II ends with the last world that exists, so it grows as new worlds ship.
local WorldManager = require("src.core.world_manager")
local Save = require("src.data.save")

local LAST_FLOOR = #WorldManager.CHAPTERS * WorldManager.ROOMS_PER_WORLD

local T = {}

T["Act I covers floors 1 to 50"] = function()
    local first, last = WorldManager.actFloors(1)
    assert(first == 1 and last == 50, tostring(first) .. "-" .. tostring(last))
end

T["Act II starts on floor 51 and ends with the last world"] = function()
    local first, last = WorldManager.actFloors(2)
    assert(first == 51 and last == LAST_FLOOR, tostring(first) .. "-" .. tostring(last))
end

T["there is no Act III"] = function()
    assert(WorldManager.actFloors(3) == nil)
end

T["act of a floor"] = function()
    assert(WorldManager.actOfRoom(1) == 1)
    assert(WorldManager.actOfRoom(50) == 1)
    assert(WorldManager.actOfRoom(51) == 2)
    assert(WorldManager.actOfRoom(LAST_FLOOR) == 2)
    assert(WorldManager.actOfRoom(LAST_FLOOR + 1) == nil, "Abyss floors past the last act")
end

T["act of a world"] = function()
    assert(WorldManager.actOfWorld(1) == 1)
    assert(WorldManager.actOfWorld(5) == 1)
    assert(WorldManager.actOfWorld(6) == 2)
end

T["the end of Act I offers the next act, the end of Act II does not"] = function()
    assert(WorldManager.offersNextAct("ascension", 50) == true)
    assert(WorldManager.offersNextAct("ascension", LAST_FLOOR) == false)
    assert(WorldManager.offersNextAct("ascension", 49) == false)
    assert(WorldManager.offersNextAct("infinite", 50) == false)
end

T["the world depth keeps counting past the last world"] = function()
    assert(WorldManager.worldDepth(1) == 1)
    assert(WorldManager.worldDepth(60) == 6)
    assert(WorldManager.worldDepth(61) == 7)
    assert(WorldManager.worldDepth(125) == 13)
end

T["the Abyss cycles the worlds past the last floor"] = function()
    local n = #WorldManager.CHAPTERS
    assert(WorldManager.worldOfRoom(LAST_FLOOR) == n)
    assert(WorldManager.worldOfRoom(LAST_FLOOR + 1) == 1)
    assert(WorldManager.worldOfRoom(LAST_FLOOR + 10) == 1)
    assert(WorldManager.worldOfRoom(LAST_FLOOR + 11) == 2)
end

T["a missing or zero floor counts as floor 1"] = function()
    assert(WorldManager.actOfRoom(nil) == 1)
    assert(WorldManager.actOfRoom(0) == 1)
    assert(WorldManager.isFinalFloor("ascension", nil) == false)
    assert(WorldManager.offersNextAct("ascension", nil) == false)
    assert(WorldManager.floorTotal("ascension", 0) == 50)
end

-- Runs fn with WorldManager.CHAPTERS resized to `count` entries (cut down, or extended with
-- copies of the last world), then restores it
local function withWorlds(count, fn)
    local original = WorldManager.CHAPTERS
    local resized = {}
    for i = 1, count do resized[i] = original[i] or original[#original] end
    WorldManager.CHAPTERS = resized
    local ok, err = pcall(fn)
    WorldManager.CHAPTERS = original
    assert(ok, err)
end

T["without Act II worlds, Act II does not exist and Act I offers no next act"] = function()
    withWorlds(5, function()
        assert(WorldManager.actFloors(2) == nil)
        assert(WorldManager.offersNextAct("ascension", 50) == false)
    end)
end

T["an act ends with the last world that exists"] = function()
    withWorlds(3, function()
        local first, last = WorldManager.actFloors(1)
        assert(first == 1 and last == 30, tostring(first) .. "-" .. tostring(last))
    end)
end

-- Runs `fn(records)` on fresh records, then restores them
local function withRecords(fn)
    local records = Save.get().records
    local saved = {}
    for k, v in pairs(records) do saved[k] = v end
    for k in pairs(saved) do records[k] = nil end
    records.ascensionMax, records.infiniteMax = 1, 0
    local ok, err = pcall(fn, records)
    for k in pairs(records) do records[k] = nil end
    for k, v in pairs(saved) do records[k] = v end
    assert(ok, err)
end

T["Act I is always open"] = function()
    withRecords(function() assert(Save.isActUnlocked(1)) end)
end

T["Act II opens with the first Act I clear"] = function()
    withRecords(function(records)
        assert(not Save.isActUnlocked(2))
        records.ascensionClears = 1
        assert(Save.isActUnlocked(2))
    end)
end

T["Act II is open on saves that went past floor 50 before the victory existed"] = function()
    withRecords(function(records)
        records.ascensionMax = 57
        assert(Save.isActUnlocked(2))
    end)
end

T["an Abyss record does not unlock Act II"] = function()
    withRecords(function(records)
        records.infiniteMax = 80
        assert(not Save.isActUnlocked(2))
    end)
end

T["Act II needs a floor past 50 or a clear: floor 50 alone keeps it locked"] = function()
    withRecords(function(records)
        records.ascensionMax = 50
        assert(not Save.isActUnlocked(2))
        records.ascensionMax = 51
        assert(Save.isActUnlocked(2))
    end)
end

T["a missing act counts as Act I"] = function()
    assert(Save.isActUnlocked(nil))
end

T["the world carousel reaches the last world"] = function()
    local saved = Save.get().selectedChapter
    local real = Save.save
    Save.save = function() end
    -- 8 worlds: a clamp stuck on the old hard-coded 6 would stop short of the last one
    local ok, err = pcall(withWorlds, 8, function()
        assert(Save.setChapter(99) == 8)
        assert(Save.setChapter(0) == 1)
    end)
    Save.save = real
    Save.get().selectedChapter = saved
    assert(ok, err)
end

-- The menu module loads drawing modules: it needs LOVE stubbed
local withLoveStubs = require("tests.love_stubs")

T["the hub launches Act II only for an unlocked Act II world in Ascension"] = function()
    withLoveStubs(function()
        local MenuState = require("src.states.menu")
        assert(MenuState.launchAct("ascension", 6, true) == 2)
        assert(MenuState.launchAct("ascension", 6, false) == 1, "locked Act II falls back to Act I")
        assert(MenuState.launchAct("ascension", 3, true) == 1)
        assert(MenuState.launchAct("infinite", 6, true) == nil, "the Abyss has no act")
    end)
end

-- A hub menu whose switches are recorded; the energy and the saved run do not touch the save
local function launchFrom(selectedChapter, mode)
    local MenuState = require("src.states.menu")
    local launched
    local menu = MenuState.new({ switch = function(_, name, params) launched = { name = name, params = params } end })
    menu.saveData = Save.get()
    menu.selectedMode = mode
    local savedChapter, spend, getRun = menu.saveData.selectedChapter, Save.spendEnergy, Save.getRun
    menu.saveData.selectedChapter = selectedChapter
    Save.spendEnergy = function() return false end
    Save.getRun = function() return nil end
    local ok, err = pcall(menu.launchGame, menu)
    menu.saveData.selectedChapter = savedChapter
    Save.spendEnergy, Save.getRun = spend, getRun
    assert(ok, err)
    return launched
end

T["BATTLE on an unlocked Act II world launches Act II"] = function()
    withLoveStubs(function() withRecords(function(records)
        records.ascensionClears = 1
        local launched = launchFrom(6, "ascension")
        assert(launched.name == "game" and launched.params.mode == "ascension")
        assert(launched.params.act == 2, "act " .. tostring(launched.params.act))
        assert(launched.params.chapter == nil, "the ignored chapter parameter is back")
    end) end)
end

T["BATTLE on a locked Act II world, or on an Act I world, launches Act I"] = function()
    withLoveStubs(function() withRecords(function(records)
        assert(launchFrom(6, "ascension").params.act == 1, "locked Act II was launched")
        records.ascensionClears = 1
        assert(launchFrom(3, "ascension").params.act == 1)
        assert(launchFrom(6, "infinite").params.act == nil, "the Abyss got an act")
    end) end)
end

-- Texts drawn by the Play tab of a hub whose carousel stands on `world`
local function playTabTexts(world)
    local MenuState = require("src.states.menu")
    local PixelFont = require("src.ui.pixel_font")
    local menu = MenuState.new({ switch = function() end })
    menu.saveData = Save.get()
    local savedChapter = menu.saveData.selectedChapter
    menu.saveData.selectedChapter = world
    local printed = {}
    local printf = PixelFont.printf
    PixelFont.printf = function(text, ...) printed[#printed + 1] = tostring(text) end
    local ok, err = pcall(menu.drawPlayTab, menu)
    PixelFont.printf = printf
    menu.saveData.selectedChapter = savedChapter
    assert(ok, err)
    return table.concat(printed, "|")
end

T["the Void City card says to clear Act I while Act II is locked"] = function()
    withLoveStubs(function() withRecords(function()
        local seen = playTabTexts(6)
        assert(seen:find("LOCKED: CLEAR ACT I", 1, true), "no act lock text: " .. seen)
    end) end)
end

T["the Void City card is open once Act II is unlocked"] = function()
    withLoveStubs(function() withRecords(function(records)
        records.ascensionClears = 1
        local seen = playTabTexts(6)
        assert(not seen:find("LOCKED", 1, true), "still locked: " .. seen)
    end) end)
end

T["an Abyss record past floor 50 does not open the Void City card"] = function()
    withLoveStubs(function() withRecords(function(records)
        records.infiniteMax = 80
        local seen = playTabTexts(6)
        assert(seen:find("LOCKED: CLEAR ACT I", 1, true), "the card looks open: " .. seen)
    end) end)
end

T["an Act I world card keeps its floor lock"] = function()
    withLoveStubs(function() withRecords(function()
        local seen = playTabTexts(5)
        assert(seen:find("LOCKED: FLOOR 41+", 1, true), "no floor lock text: " .. seen)
        assert(not seen:find("CLEAR ACT I", 1, true))
    end) end)
end

T["the hub BEST card counts floors out of the act the record is in"] = function()
    withLoveStubs(function() withRecords(function(records)
        local MenuState = require("src.states.menu")
        local MenuTop = require("src.ui.menu_top")
        local PixelFont = require("src.ui.pixel_font")
        local _, last2 = WorldManager.actFloors(2)
        local function bestCard(best)
            records.ascensionMax = best
            local menu = MenuState.new({ switch = function() end })
            menu.saveData = Save.get()
            local printed = {}
            local printf = PixelFont.printf
            PixelFont.printf = function(text, ...) printed[#printed + 1] = tostring(text) end
            local ok, err = pcall(MenuTop.draw, menu, 0)
            PixelFont.printf = printf
            assert(ok, err)
            return "|" .. table.concat(printed, "|") .. "|"
        end
        assert(bestCard(30):find("|30/50|", 1, true), "Act I record")
        assert(bestCard(55):find("|55/" .. last2 .. "|", 1, true), "Act II record")
    end) end)
end

return T
