local WorldManager = require("src.core.world_manager")
local Balance = require("src.data.balance")

local T = {}

-- Total HP of every monster in a room (bosses excluded) and the boss HP, if any
local function roomHp(chapter, room)
    local enc = WorldManager.generateEncounter(chapter, room, 640, 480)
    local total, boss = 0, 0
    for _, wave in ipairs(enc.waves) do
        for _, s in ipairs(wave) do
            if s.isBoss then boss = s.hp else total = total + s.hp end
        end
    end
    return total, boss
end

local chapterOf = WorldManager.worldOfRoom

-- Closest combat room before the given room (sanctuaries hold no monster)
local function combatBefore(room)
    repeat room = room - 1 until WorldManager.getRoomType(room) == "combat"
    return room
end

T["angel room: no wave"] = function()
    local enc = WorldManager.generateEncounter(1, 5, 640, 480)
    assert(#enc.waves == 0)
end

T["boss room: one wave holding the boss"] = function()
    local enc = WorldManager.generateEncounter(1, 10, 640, 480)
    assert(#enc.waves == 1)
    local boss = 0
    for _, s in ipairs(enc.waves[1]) do if s.isBoss then boss = boss + 1 end end
    assert(boss == 1)
end

T["HP: total = hpMult x room HP budget"] = function()
    local room, chapter = 24, 3
    local enc = WorldManager.generateEncounter(chapter, room, 640, 480)
    local count, total = 0, 0
    for _, wave in ipairs(enc.waves) do
        for _, s in ipairs(wave) do count = count + 1; total = total + s.hp end
    end
    local expected = Balance.ENCOUNTER.hpMult
        * WorldManager.hpBudget(WorldManager.baseHp(room), math.max(4, math.min(10, count)))
    assert(math.abs(total - expected) <= count, string.format("%d vs %.0f", total, expected))
end

T["HP curve: never more than +25% from one room to the next"] = function()
    for room = 1, 120 do
        local a, b = WorldManager.baseHp(room), WorldManager.baseHp(room + 1)
        assert(b >= a, "room " .. room .. " must not be weaker than the previous one")
        assert(b <= a * 1.25, string.format("room %d -> %d: %.0f -> %.0f", room, room + 1, a, b))
    end
end

T["HP curve: entering a new world does not double the room HP"] = function()
    for world = 1, 5 do
        local last, first = combatBefore(world * 10), world * 10 + 1
        local before = roomHp(chapterOf(last), last)
        local after = roomHp(chapterOf(first), first)
        assert(before > 0, "room " .. last .. " must hold monsters")
        -- 3 rooms apart (devil sanctuary and boss in between): the old per-world base HP
        -- gave x2.4 here, the curve alone gives at most x1.55
        assert(after <= before * 1.6, string.format("room %d -> %d: %d -> %d", last, first, before, after))
    end
end

T["HP curve: room 49 stays under 40x room 1"] = function()
    local first = roomHp(1, 1)
    local last = roomHp(5, 49)
    assert(last <= first * 40, string.format("%d vs %d (x%.1f)", last, first, last / first))
end

T["boss: at least 1.5x the HP of the previous combat room"] = function()
    for room = 10, 100, 10 do
        local _, boss = roomHp(chapterOf(room), room)
        local previous = roomHp(chapterOf(combatBefore(room)), combatBefore(room))
        assert(previous > 0, "room " .. combatBefore(room) .. " must hold monsters")
        assert(boss >= previous * 1.5, string.format("room %d: boss %d vs room %d", room, boss, previous))
    end
end

T["boss: at most 2.5x the HP of the previous combat room"] = function()
    for room = 10, 100, 10 do
        local _, boss = roomHp(chapterOf(room), room)
        local previous = roomHp(chapterOf(combatBefore(room)), combatBefore(room))
        assert(previous > 0, "room " .. combatBefore(room) .. " must hold monsters")
        assert(boss <= previous * 2.5, string.format("room %d: boss %d vs room %d", room, boss, previous))
    end
end

T["boss rush: no HP jump between two consecutive rooms"] = function()
    local previous
    for room = 1, 30 do
        local spawns = WorldManager.generateBossRush(chapterOf(room), room, 640, 480)
        local boss = spawns[1].hp
        if previous then
            assert(boss <= previous * 1.4, string.format("room %d: %d -> %d", room, previous, boss))
        end
        previous = boss
    end
end

T["monster damage: x1 in room 1, about x2 in room 50, always rising"] = function()
    assert(WorldManager.damageMult(1) == 1)
    local m50 = WorldManager.damageMult(50)
    assert(m50 >= 1.8 and m50 <= 2.2, tostring(m50))
    for room = 1, 100 do
        assert(WorldManager.damageMult(room + 1) > WorldManager.damageMult(room))
    end
end

T["elite tougher than a normal monster of the same type"] = function()
    for room = 20, 40 do
        if WorldManager.getRoomType(room) == "combat" and room % 10 ~= 7 then
            local enc = WorldManager.generateEncounter(3, room, 640, 480)
            local elite, normal = {}, {}
            for _, wave in ipairs(enc.waves) do
                for _, s in ipairs(wave) do
                    if s.affixes then elite[s.type] = s.hp else normal[s.type] = s.hp end
                end
            end
            for t, hp in pairs(elite) do
                if normal[t] then assert(hp > normal[t] * 2, t) return end
            end
        end
    end
end

T["spawn positions inside the room"] = function()
    local enc = WorldManager.generateEncounter(2, 13, 640, 480)
    for _, wave in ipairs(enc.waves) do
        for _, s in ipairs(wave) do
            assert(s.x > 0 and s.x < 640 and s.y > 0 and s.y < 480)
        end
    end
end

return T
