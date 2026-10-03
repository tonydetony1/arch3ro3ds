local Director = require("src.core.encounter_director")
local Encounters = require("src.data.encounters")
local WorldManager = require("src.core.world_manager")

local T = {}

local function chapterOf(room) return math.min(6, math.floor((room - 1) / 10) + 1) end
local function isCombat(room) return WorldManager.getRoomType(room) == "combat" end

local function eachCombatRoom(fn)
    for room = 1, 150 do
        if isCombat(room) then fn(room, chapterOf(room), Director.compose(chapterOf(room), room)) end
    end
end

local function threat(spawn)
    return Encounters.COST[spawn.type] * (spawn.affixes and Encounters.ELITE_COST_MULT or 1)
end

T["déterministe"] = function()
    for room = 1, 60 do
        if isCombat(room) then
            local a, b = Director.compose(chapterOf(room), room), Director.compose(chapterOf(room), room)
            assert(#a.waves == #b.waves, "salle " .. room)
            for w = 1, #a.waves do
                for i = 1, #a.waves[w] do
                    assert(a.waves[w][i].type == b.waves[w][i].type, "salle " .. room)
                end
            end
        end
    end
end

T["plafonds par vague et par salle"] = function()
    eachCombatRoom(function(room, _, enc)
        local total = 0
        for _, wave in ipairs(enc.waves) do
            assert(#wave >= 1 and #wave <= Encounters.MAX_PER_WAVE, "salle " .. room .. " : " .. #wave)
            total = total + #wave
        end
        assert(total <= Encounters.MAX_PER_ROOM, "salle " .. room .. " total " .. total)
        assert(#enc.waves >= 1 and #enc.waves <= 3, "salle " .. room)
    end)
end

T["budget respecté (un monstre de dépassement au plus)"] = function()
    eachCombatRoom(function(room, _, enc)
        local sum = 0
        for _, wave in ipairs(enc.waves) do
            for _, s in ipairs(wave) do
                if not s.champion then sum = sum + threat(s) end
            end
        end
        assert(sum <= enc.budget + 3.0, string.format("salle %d : %.1f > %.1f", room, sum, enc.budget))
    end)
end

T["chaque vague commence par un monstre de pression"] = function()
    eachCombatRoom(function(room, _, enc)
        for w, wave in ipairs(enc.waves) do
            local role = Encounters.ROLE[wave[1].type]
            assert(Encounters.PRESSURE[role], "salle " .. room .. " vague " .. w .. " : " .. wave[1].type)
        end
    end)
end

T["invocateurs et tireurs plafonnés"] = function()
    eachCombatRoom(function(room, chapter, enc)
        for _, wave in ipairs(enc.waves) do
            local summoners, shooters = 0, 0
            for _, s in ipairs(wave) do
                if s.type == "summoner" then summoners = summoners + 1 end
                if Encounters.ROLE[s.type] == "shooter" then shooters = shooters + 1 end
            end
            assert(summoners <= 1, "salle " .. room)
            assert(shooters <= Encounters.shooterCap(chapter), "salle " .. room)
        end
    end)
end

T["au plus 3 exemplaires du même type par vague"] = function()
    eachCombatRoom(function(room, _, enc)
        for w, wave in ipairs(enc.waves) do
            local n = {}
            for _, s in ipairs(wave) do
                n[s.type] = (n[s.type] or 0) + 1
                assert(n[s.type] <= Encounters.MAX_SAME_TYPE, "salle " .. room .. " vague " .. w .. " : " .. s.type)
            end
        end
    end)
end

T["types issus du groupe du chapitre"] = function()
    eachCombatRoom(function(room, chapter, enc)
        local pool = {}
        for _, t in ipairs(WorldManager.getChapter(chapter).monsterPool) do pool[t] = true end
        for _, wave in ipairs(enc.waves) do
            for _, s in ipairs(wave) do assert(pool[s.type], "salle " .. room .. " : " .. s.type) end
        end
    end)
end

T["signature différente de la salle précédente"] = function()
    for room = 2, 150 do
        if isCombat(room) and isCombat(room - 1) and chapterOf(room) == chapterOf(room - 1) then
            local a = Director.compose(chapterOf(room - 1), room - 1).signature
            local b = Director.compose(chapterOf(room), room).signature
            assert(a ~= b, "salles " .. (room - 1) .. "/" .. room .. " : " .. tostring(a))
        end
    end
end

T["nouveau type présent dans la salle de son apparition"] = function()
    eachCombatRoom(function(room, _, enc)
        if enc.newType then
            local found = false
            for _, wave in ipairs(enc.waves) do
                for _, s in ipairs(wave) do
                    if s.type == enc.newType then
                        found = true
                        assert(not s.affixes, "salle " .. room .. " : nouveau type élite")
                    end
                end
            end
            assert(found, "salle " .. room .. " : " .. enc.newType .. " absent")
        end
    end)
end

T["nombre d'élites selon le barème"] = function()
    eachCombatRoom(function(room, _, enc)
        if not Encounters.isChampionRoom(room) then
            local elites = 0
            for _, wave in ipairs(enc.waves) do
                for _, s in ipairs(wave) do if s.affixes then elites = elites + 1 end end
            end
            assert(elites == Encounters.eliteCount(room), "salle " .. room .. " : " .. elites)
        end
    end)
end

T["affixes compatibles avec le rôle"] = function()
    eachCombatRoom(function(room, _, enc)
        for _, wave in ipairs(enc.waves) do
            for _, s in ipairs(wave) do
                for _, name in ipairs(s.affixes or {}) do
                    local def = Encounters.AFFIXES[name]
                    assert(def, name)
                    assert(not def.roles or def.roles[Encounters.ROLE[s.type]], "salle " .. room .. " : " .. name .. " sur " .. s.type)
                end
            end
        end
    end)
end

T["champion en dernière vague des salles x7"] = function()
    eachCombatRoom(function(room, _, enc)
        local champions = 0
        for w, wave in ipairs(enc.waves) do
            for _, s in ipairs(wave) do
                if s.champion then
                    champions = champions + 1
                    assert(w == #enc.waves, "salle " .. room)
                    assert(#s.affixes == 2 and s.affixes[1] ~= s.affixes[2], "salle " .. room)
                end
            end
        end
        assert(champions == (Encounters.isChampionRoom(room) and 1 or 0), "salle " .. room)
    end)
end

T["salle 1 : une seule vague légère"] = function()
    local enc = Director.compose(1, 1)
    assert(#enc.waves == 1 and #enc.waves[1] <= 5)
end

T["abysse : surplus converti en PV"] = function()
    local enc = Director.compose(6, 121)
    assert(enc.budget <= Encounters.BUDGET_CAP + 1e-9)
    assert(enc.hpMult > 1)
end

return T
