-- src/data/quests.lua
-- Quêtes journalières et Passe de Combat (jauge à paliers) façon Archero.
-- Les compteurs vivent dans la sauvegarde ; ce fichier ne décrit que les règles.

local Quests = {}

-- Missions du jour : remises à zéro à chaque nouveau jour
-- Réserve de missions : 4 sont tirées chaque jour, différentes d'un jour à l'autre.
Quests.POOL = {
    { id = "kills50",    kind = "kills",    goal = 50,   points = 20, name = "Éliminer 50 monstres",      reward = { gold = 150 } },
    { id = "kills120",   kind = "kills",    goal = 120,  points = 30, name = "Éliminer 120 monstres",     reward = { gold = 320 } },
    { id = "rooms10",    kind = "rooms",    goal = 10,   points = 20, name = "Terminer 10 salles",        reward = { gold = 200 } },
    { id = "rooms25",    kind = "rooms",    goal = 25,   points = 30, name = "Terminer 25 salles",        reward = { gold = 420 } },
    { id = "chest1",     kind = "chests",   goal = 1,    points = 20, name = "Ouvrir 1 coffre",           reward = { gems = 5 } },
    { id = "chest3",     kind = "chests",   goal = 3,    points = 30, name = "Ouvrir 3 coffres",          reward = { gems = 12 } },
    { id = "upgrade1",   kind = "upgrades", goal = 1,    points = 20, name = "Améliorer 1 équipement",    reward = { gold = 180 } },
    { id = "upgrade3",   kind = "upgrades", goal = 3,    points = 30, name = "Améliorer 3 équipements",   reward = { gold = 460 } },
    { id = "boss1",      kind = "bosses",   goal = 1,    points = 20, name = "Vaincre 1 boss",            reward = { gems = 8 } },
    { id = "boss3",      kind = "bosses",   goal = 3,    points = 35, name = "Vaincre 3 boss",            reward = { gems = 18 } },
    { id = "skills5",    kind = "skills",   goal = 5,    points = 20, name = "Choisir 5 améliorations",   reward = { gold = 160 } },
    { id = "skills12",   kind = "skills",   goal = 12,   points = 30, name = "Choisir 12 améliorations",  reward = { gold = 380 } },
    { id = "gold600",    kind = "gold",     goal = 600,  points = 20, name = "Ramasser 600 pièces d'or",  reward = { gold = 200 } },
    { id = "gold1500",   kind = "gold",     goal = 1500, points = 30, name = "Ramasser 1500 pièces d'or", reward = { gems = 10 } },
    { id = "pots10",     kind = "pots",     goal = 10,   points = 20, name = "Briser 10 urnes",           reward = { gold = 170 } },
    { id = "pots25",     kind = "pots",     goal = 25,   points = 30, name = "Briser 25 urnes",           reward = { gold = 400 } },
    { id = "runs2",      kind = "runs",     goal = 2,    points = 20, name = "Terminer 2 parties",        reward = { gold = 220 } },
    { id = "runs5",      kind = "runs",     goal = 5,    points = 35, name = "Terminer 5 parties",        reward = { gems = 14 } },
}

-- Missions hebdomadaires : objectifs longs, récompenses nettement plus grosses
Quests.WEEKLY_POOL = {
    { id = "w_kills600",  kind = "kills",    goal = 600,  points = 0, name = "Éliminer 600 monstres",      reward = { gems = 40 } },
    { id = "w_rooms120",  kind = "rooms",    goal = 120,  points = 0, name = "Terminer 120 salles",        reward = { gold = 2500 } },
    { id = "w_boss15",    kind = "bosses",   goal = 15,   points = 0, name = "Vaincre 15 boss",            reward = { gems = 50 } },
    { id = "w_gold10k",   kind = "gold",     goal = 10000, points = 0, name = "Ramasser 10 000 pièces d'or", reward = { gold = 3000 } },
    { id = "w_upgrade12", kind = "upgrades", goal = 12,   points = 0, name = "Améliorer 12 fois",          reward = { gems = 35 } },
    { id = "w_runs15",    kind = "runs",     goal = 15,   points = 0, name = "Terminer 15 parties",        reward = { gold = 2200, gems = 15 } },
}

Quests.DAILY_COUNT = 4
Quests.WEEKLY_COUNT = 3

-- Tirage déterministe : la même clé (jour ou semaine) donne toujours la même sélection,
-- mais deux journées consécutives proposent des missions différentes.
local function pickFrom(pool, key, count)
    local seed = 0
    for i = 1, #key do seed = (seed * 31 + key:byte(i)) % 2147483647 end

    local indices, picked = {}, {}
    for i = 1, #pool do indices[i] = i end
    for i = #indices, 2, -1 do
        seed = (seed * 1103515245 + 12345) % 2147483647
        local j = (seed % i) + 1
        indices[i], indices[j] = indices[j], indices[i]
    end
    for i = 1, math.min(count, #indices) do picked[i] = pool[indices[i]] end
    return picked
end

function Quests.dailySelection(dayKey)
    return pickFrom(Quests.POOL, "D" .. tostring(dayKey or ""), Quests.DAILY_COUNT)
end

function Quests.weeklySelection(weekKey)
    return pickFrom(Quests.WEEKLY_POOL, "W" .. tostring(weekKey or ""), Quests.WEEKLY_COUNT)
end

-- Paliers de la jauge de points (coffres du passe)
Quests.TIERS = {
    { points = 20,  reward = { gold = 200 },            label = "+200 OR" },
    { points = 40,  reward = { gems = 10 },             label = "+10 GEMMES" },
    { points = 60,  reward = { gold = 400 },            label = "+400 OR" },
    { points = 80,  reward = { gems = 20 },             label = "+20 GEMMES" },
    { points = 100, reward = { gold = 800, gems = 25 }, label = "COFFRE D'OR" },
}

Quests.MAX_POINTS = 100

function Quests.get(id)
    for _, q in ipairs(Quests.POOL) do
        if q.id == id then return q end
    end
    for _, q in ipairs(Quests.WEEKLY_POOL) do
        if q.id == id then return q end
    end
    return nil
end

-- État d'une quête : progression, objectif, terminée, déjà réclamée
function Quests.state(quest, saveQuests)
    local progress = math.min(quest.goal, (saveQuests.progress and saveQuests.progress[quest.kind]) or 0)
    local done = progress >= quest.goal
    local claimed = (saveQuests.claimed and saveQuests.claimed[quest.id]) == true
    return progress, done, claimed
end

return Quests
