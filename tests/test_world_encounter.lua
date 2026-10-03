local WorldManager = require("src.core.world_manager")
local Balance = require("src.data.balance")

local T = {}

T["salle d'ange : aucune vague"] = function()
    local enc = WorldManager.generateEncounter(1, 5, 640, 480)
    assert(#enc.waves == 0)
end

T["salle de boss : une vague avec le boss"] = function()
    local enc = WorldManager.generateEncounter(1, 10, 640, 480)
    assert(#enc.waves == 1)
    local boss = 0
    for _, s in ipairs(enc.waves[1]) do if s.isBoss then boss = boss + 1 end end
    assert(boss == 1)
end

T["PV : total = hpMult x budget de PV historique"] = function()
    local room, chapter = 24, 3
    local enc = WorldManager.generateEncounter(chapter, room, 640, 480)
    local count, total = 0, 0
    for _, wave in ipairs(enc.waves) do
        for _, s in ipairs(wave) do count = count + 1; total = total + s.hp end
    end
    local chap = WorldManager.getChapter(chapter)
    local baseHp = chap.baseHp + (room - 1) * chap.hpScaling
    local expected = Balance.ENCOUNTER.hpMult * WorldManager.hpBudget(baseHp, math.max(4, math.min(10, count)))
    assert(math.abs(total - expected) <= count, string.format("%d vs %.0f", total, expected))
end

T["élite plus robuste que le même type normal"] = function()
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

T["positions dans la salle"] = function()
    local enc = WorldManager.generateEncounter(2, 13, 640, 480)
    for _, wave in ipairs(enc.waves) do
        for _, s in ipairs(wave) do
            assert(s.x > 0 and s.x < 640 and s.y > 0 and s.y < 480)
        end
    end
end

return T
