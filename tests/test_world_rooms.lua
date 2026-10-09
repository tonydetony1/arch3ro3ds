local Rooms = require("src.data.rooms")
local WorldManager = require("src.core.world_manager")

local T = {}

local SAFE = { ["."] = true, o = true, m = true }

local function chapterRooms(chapter)
    local first = (chapter - 1) * 10 + 1
    local list = {}
    for room = first, first + 9 do
        if WorldManager.getRoomType(room) == "combat" then list[#list + 1] = room end
    end
    return list
end

local function isWorldLayout(world, layout)
    for _, l in ipairs(Rooms.WORLDS[world]) do
        if l == layout then return true end
    end
    return false
end

T["each world has 4 rooms, exactly one of them total"] = function()
    for world = 1, 6 do
        local rooms, totals = Rooms.WORLDS[world], 0
        assert(#rooms == 4, "world " .. world .. ": " .. #rooms .. " rooms")
        for _, l in ipairs(rooms) do
            if l.total then totals = totals + 1 end
        end
        assert(totals == 1, "world " .. world .. ": " .. totals .. " total rooms")
    end
end

T["every world room is valid, mirrored too"] = function()
    for world = 1, 6 do
        for _, l in ipairs(Rooms.WORLDS[world]) do
            for _, grid in ipairs({ l.grid, Rooms.mirror(l.grid) }) do
                local ok, err = Rooms.validate({ id = l.id, grid = grid }, "combat")
                assert(ok, err)
            end
        end
    end
end

-- Total rooms that hurt (lava, void rifts): a hazard-free path from the entry to the gate,
-- and monsters always appear on safe ground
T["damaging total rooms keep a safe path and safe spawns"] = function()
    for _, world in ipairs({ 4, 6 }) do
        for _, l in ipairs(Rooms.WORLDS[world]) do
            if l.total then
                local g = l.grid
                local seen, stack = {}, { { 7, Rooms.ROWS } }
                while #stack > 0 do
                    local c, r = unpack(table.remove(stack))
                    local key = r * 100 + c
                    if not seen[key] and c >= 1 and c <= Rooms.COLS and r >= 1 and r <= Rooms.ROWS
                        and SAFE[g[r]:sub(c, c)] then
                        seen[key] = true
                        stack[#stack + 1] = { c + 1, r }
                        stack[#stack + 1] = { c - 1, r }
                        stack[#stack + 1] = { c, r + 1 }
                        stack[#stack + 1] = { c, r - 1 }
                    end
                end
                assert(seen[100 + 7], l.id .. ": no hazard-free path to the gate")
                for r = 1, Rooms.ROWS do
                    for c = 1, Rooms.COLS do
                        if g[r]:sub(c, c) == "m" then
                            assert(seen[r * 100 + c], l.id .. ": spawn " .. c .. "," .. r .. " not on safe ground")
                        end
                    end
                end
            end
        end
    end
end

T["a chapter plays its 4 world rooms (total once) and 3 common rooms, no repeat"] = function()
    for chapter = 1, 6 do
        local seen, own, totals = {}, 0, 0
        local rooms = chapterRooms(chapter)
        assert(#rooms == 7, "chapter " .. chapter .. ": " .. #rooms .. " combat rooms")
        for _, room in ipairs(rooms) do
            local layout = Rooms.pick("combat", room, chapter)
            assert(not seen[layout.id], "chapter " .. chapter .. ": " .. layout.id .. " repeated")
            seen[layout.id] = true
            if isWorldLayout(chapter, layout) then own = own + 1 end
            if layout.total then totals = totals + 1 end
        end
        assert(own == 4 and totals == 1, "chapter " .. chapter .. ": " .. own .. " world rooms, " .. totals .. " total")
    end
end

T["pick is deterministic and unchanged without a world"] = function()
    for room = 1, 60 do
        local a, ma = Rooms.pick("combat", room, 3)
        local b, mb = Rooms.pick("combat", room, 3)
        assert(a == b and ma == mb, "room " .. room)
        local c = Rooms.pick("combat", room)
        local found = false
        for _, l in ipairs(Rooms.COMBAT) do
            if l == c then found = true end
        end
        assert(found, "room " .. room .. ": world room picked without a world")
    end
end

return T
