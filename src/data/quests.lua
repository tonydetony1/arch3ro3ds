-- src/data/quests.lua
-- Quêtes journalières et Passe de Combat (jauge à paliers) façon Archero.
-- Les compteurs vivent dans la sauvegarde ; ce fichier ne décrit que les règles.

local Quests = {}

-- Missions du jour : remises à zéro à chaque nouveau jour
-- Réserve de missions : 4 sont tirées chaque jour, différentes d'un jour à l'autre.
Quests.POOL = {
    { id = "kills50",    kind = "kills",    goal = 50,   points = 20, name = "Defeat 50 monsters",        reward = { gold = 150 } },
    { id = "kills120",   kind = "kills",    goal = 120,  points = 30, name = "Defeat 120 monsters",       reward = { gold = 320 } },
    { id = "rooms10",    kind = "rooms",    goal = 10,   points = 20, name = "Clear 10 rooms",            reward = { gold = 200 } },
    { id = "rooms25",    kind = "rooms",    goal = 25,   points = 30, name = "Clear 25 rooms",            reward = { gold = 420 } },
    { id = "chest1",     kind = "chests",   goal = 1,    points = 20, name = "Open 1 chest",              reward = { gems = 5 } },
    { id = "chest3",     kind = "chests",   goal = 3,    points = 30, name = "Open 3 chests",             reward = { gems = 12 } },
    { id = "upgrade1",   kind = "upgrades", goal = 1,    points = 20, name = "Upgrade 1 equipment",       reward = { gold = 180 } },
    { id = "upgrade3",   kind = "upgrades", goal = 3,    points = 30, name = "Upgrade 3 equipment",       reward = { gold = 460 } },
    { id = "boss1",      kind = "bosses",   goal = 1,    points = 20, name = "Defeat 1 boss",             reward = { gems = 8 } },
    { id = "boss3",      kind = "bosses",   goal = 3,    points = 35, name = "Defeat 3 bosses",           reward = { gems = 18 } },
    { id = "skills5",    kind = "skills",   goal = 5,    points = 20, name = "Pick 5 skills",             reward = { gold = 160 } },
    { id = "skills12",   kind = "skills",   goal = 12,   points = 30, name = "Pick 12 skills",            reward = { gold = 380 } },
    { id = "gold600",    kind = "gold",     goal = 600,  points = 20, name = "Collect 600 gold",          reward = { gold = 200 } },
    { id = "gold1500",   kind = "gold",     goal = 1500, points = 30, name = "Collect 1,500 gold",        reward = { gems = 10 } },
    { id = "pots10",     kind = "pots",     goal = 10,   points = 20, name = "Smash 10 pots",             reward = { gold = 170 } },
    { id = "pots25",     kind = "pots",     goal = 25,   points = 30, name = "Smash 25 pots",             reward = { gold = 400 } },
    { id = "runs2",      kind = "runs",     goal = 2,    points = 20, name = "Complete 2 runs",           reward = { gold = 220 } },
    { id = "runs5",      kind = "runs",     goal = 5,    points = 35, name = "Complete 5 runs",           reward = { gems = 14 } },
}

-- Weekly missions: longer objectives, significantly bigger rewards
Quests.WEEKLY_POOL = {
    { id = "w_kills600",  kind = "kills",    goal = 600,  points = 0, name = "Defeat 600 monsters",       reward = { gems = 40 } },
    { id = "w_rooms120",  kind = "rooms",    goal = 120,  points = 0, name = "Clear 120 rooms",           reward = { gold = 2500 } },
    { id = "w_boss15",    kind = "bosses",   goal = 15,   points = 0, name = "Defeat 15 bosses",          reward = { gems = 50 } },
    { id = "w_gold10k",   kind = "gold",     goal = 10000, points = 0, name = "Collect 10,000 gold",       reward = { gold = 3000 } },
    { id = "w_upgrade12", kind = "upgrades", goal = 12,   points = 0, name = "Upgrade gear 12 times",      reward = { gems = 35 } },
    { id = "w_runs15",    kind = "runs",     goal = 15,   points = 0, name = "Complete 15 runs",          reward = { gold = 2200, gems = 15 } },
}

Quests.DAILY_COUNT = 4
Quests.WEEKLY_COUNT = 3

-- Deterministic pick
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

-- Battle pass point thresholds (chest tiers)
Quests.TIERS = {
    { points = 20,  reward = { gold = 200 },            label = "+200 GOLD" },
    { points = 40,  reward = { gems = 10 },             label = "+10 GEMS" },
    { points = 60,  reward = { gold = 400 },            label = "+400 GOLD" },
    { points = 80,  reward = { gems = 20 },             label = "+20 GEMS" },
    { points = 100, reward = { gold = 800, gems = 25 }, label = "GOLDEN CHEST" },
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
