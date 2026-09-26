-- src/data/achievements.lua
-- Succès permanents : la progression est déduite de la sauvegarde (aucun compteur en double).

local Bestiary = require("src.data.bestiary")

local Achievements = {}

local function totalKills(d)
    local total = 0
    for _, n in pairs(d.bestiary or {}) do total = total + n end
    return total
end

local function bossKills(d)
    local b = d.bestiary or {}
    return (b.golem or 0) + (b.skeleton_king or 0) + (b.witch or 0) + (b.lava_titan or 0)
end

local function ownedItems(d)
    local n = 0
    for _, copies in pairs(d.itemCopies or {}) do
        if copies > 0 then n = n + 1 end
    end
    return n
end

local function bestItemLevel(d)
    local best = 0
    for _, lvl in pairs(d.itemLevels or {}) do
        if lvl > best then best = lvl end
    end
    return best
end

local function legendaryCount(d)
    local n = 0
    for _, rarity in pairs(d.itemRarities or {}) do
        if rarity == "legendary" then n = n + 1 end
    end
    return n
end

local function talentPoints(d)
    local n = 0
    for _, lvl in pairs(d.talents or {}) do n = n + lvl end
    return n
end

local function heroesUnlocked(d)
    local n = 0
    for _, ok in pairs(d.unlockedHeroes or {}) do
        if ok then n = n + 1 end
    end
    return n
end

Achievements.LIST = {
    { id = "hunter",    name = "Chasseur",         desc = "Éliminer 500 monstres",            goal = 500, icon = "skull",  reward = { gold = 500 },  value = totalKills },
    { id = "explorer",  name = "Explorateur",      desc = "Atteindre la salle 20",            goal = 20,  icon = "door",   reward = { gems = 10 },   value = function(d) return (d.records or {}).ascensionMax or 1 end },
    { id = "slayer",    name = "Briseur de Boss",  desc = "Vaincre 10 boss",                  goal = 10,  icon = "swords", reward = { gems = 15 },   value = bossKills },
    { id = "collector", name = "Collectionneur",   desc = "Posséder 12 équipements",          goal = 12,  icon = "chest",  reward = { gold = 700 },  value = ownedItems },
    { id = "smith",     name = "Forgeron",         desc = "Monter un objet au niveau 20",     goal = 20,  icon = "upgrade", reward = { gold = 900 }, value = bestItemLevel },
    { id = "legend",    name = "Légende Vivante",  desc = "Obtenir 1 objet légendaire",       goal = 1,   icon = "star",   reward = { gems = 25 },   value = legendaryCount },
    { id = "survivor",  name = "Survivant",        desc = "Tenir 15 vagues en Arène",         goal = 15,  icon = "heart",  reward = { gems = 20 },   value = function(d) return (d.events or {}).survivalBest or 0 end },
    { id = "gladiator", name = "Gladiateur",       desc = "Enchaîner 5 boss en Boss Rush",    goal = 5,   icon = "swords", reward = { gold = 1200 }, value = function(d) return (d.events or {}).bossRushBest or 0 end },
    { id = "rich",      name = "Fortune",          desc = "Accumuler 5000 pièces d'or",       goal = 5000, icon = "gold",  reward = { gems = 15 },   value = function(d) return d.gold or 0 end },
    { id = "talented",  name = "Talentueux",       desc = "Investir 20 points de talent",     goal = 20,  icon = "rune",   reward = { gold = 800 },  value = talentPoints },
    { id = "roster",    name = "Compagnons",       desc = "Débloquer 3 héros",                goal = 3,   icon = "hero",   reward = { gems = 20 },   value = heroesUnlocked },
    { id = "master",    name = "Maître du Bestiaire", desc = "Atteindre 50 éliminations sur 5 monstres", goal = 5, icon = "check", reward = { gems = 30 },
      value = function(d)
          local n = 0
          for _, entry in ipairs(Bestiary.ENTRIES) do
              if ((d.bestiary or {})[entry.type] or 0) >= 50 then n = n + 1 end
          end
          return n
      end },
}

function Achievements.state(achievement, saveData)
    local value = math.min(achievement.goal, achievement.value(saveData) or 0)
    local done = value >= achievement.goal
    local claimed = (saveData.achievements or {})[achievement.id] == true
    return value, done, claimed
end

function Achievements.get(id)
    for _, a in ipairs(Achievements.LIST) do
        if a.id == id then return a end
    end
    return nil
end

return Achievements
