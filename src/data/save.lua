-- src/data/save.lua
-- Système de persistance des données joueur (Or, Gemmes, Inventaire, Équipement, Records)
-- Compatible 100% LÖVEPotion 3DS et LÖVE2D PC via love.filesystem

local Balance = require("src.data.balance")
local Admin = require("src.data.admin")

local Save = {
    SAVE_FILE = "arch3ro_save.lua",
    BACKUP_FILE = "arch3ro_save_secours.lua",
    data = nil,
}

-- Marqueur de fin : un fichier sans lui a été tronqué (coupure pendant l'écriture)
local END_MARK = "-- fin arch3ro"

-- Données par défaut pour une nouvelle partie
local function getDefaultData()
    return {
        gold = 350,
        gems = 60,
        energy = 20,
        maxEnergy = 20,
        accountLevel = 1,
        accountXp = 0,
        records = {
            ascensionMax = 1,
            infiniteMax = 0,
        },
        talents = {
            strength = 0,
            vitality = 0,
            recovery = 0,
            agility = 0,
            glory = 0,
        },
        selectedHero = "atreus",
        unlockedHeroes = {
            atreus = true,
            urasil = true,
            phoren = false,
            helix = false,
            rolla = false,
        },
        selectedChapter = 1,
        audio = { music = 0.55, sfx = 0.85 },

        -- Quêtes journalières & passe de combat
        dailyQuests = {
            day = "",
            points = 0,
            progress = { kills = 0, rooms = 0, chests = 0, upgrades = 0, bosses = 0 },
            claimed = {},
            claimedTiers = {},
        },
        -- Missions hebdomadaires (compteurs séparés des quotidiennes)
        weeklyQuests = { week = "", progress = {}, claimed = {}, selected = {} },
        -- Bestiaire : éliminations par type de monstre
        bestiary = {},
        -- Records des modes événement
        events = { bossRushBest = 0, survivalBest = 0 },

        patrolGold = 150,
        patrolMax = 500,
        -- Équipement de départ : uniquement la panoplie commune du Rôdeur.
        -- Tout le reste se débloque dans les coffres (voir Items.DROP_TABLES).
        itemCopies = {
            starter_bow = 1,
            vest_dexterity = 1,
            wolf_ring = 1,
            bat_companion = 1,
        },
        itemRarities = {},
        itemStars = {},
        achievements = {},
        shop = { day = "", bought = {} },
        energyStamp = 0,
        equipped = {
            weapon = "starter_bow",
            armor = "vest_dexterity",
            ring = "wolf_ring",
            ring1 = "wolf_ring",
            ring2 = nil,
            pet = "bat_companion",
            pet1 = "bat_companion",
            pet2 = nil,
        },
        itemLevels = {
            starter_bow = 1,
            vest_dexterity = 1,
            wolf_ring = 1,
            bat_companion = 1,
        },
        inventory = {
            "starter_bow",
            "vest_dexterity",
            "wolf_ring",
            "bat_companion",
        },
        -- Marqueur de migration : les anciennes sauvegardes possédaient tout le catalogue
        itemUnlockRework = true,
        settings = {
            debugMode = true,
            sound = true,
            depth3d = 1.0,       -- intensité du relief stéréoscopique (0 à 1.5)
            showDamage = true,   -- chiffres de dégâts flottants
            lowPower = false,    -- mode économie : moins de particules (Old 3DS)
            autoDash = false,    -- esquive automatique quand un projectile arrive
        },
    }
end

-- Sérialiseur Lua natif récursif (Zéro dépendance externe, infaillible sur Old 3DS)
local function serializeTable(val, indent)
    indent = indent or ""
    local t = type(val)
    if t == "number" or t == "boolean" then
        return tostring(val)
    elseif t == "string" then
        return string.format("%q", val)
    elseif t == "table" then
        local parts = { "{\n" }
        local nextIndent = indent .. "  "
        for k, v in pairs(val) do
            local keyStr = (type(k) == "string" and string.match(k, "^[a-zA-Z_][a-zA-Z0-9_]*$"))
                and k or "[" .. serializeTable(k) .. "]"
            table.insert(parts, nextIndent .. keyStr .. " = " .. serializeTable(v, nextIndent) .. ",\n")
        end
        table.insert(parts, indent .. "}")
        return table.concat(parts)
    else
        return "nil"
    end
end

-- Lit un fichier de sauvegarde en sécurité : contenu complet (marqueur de fin) et exécuté
-- dans un environnement vide (une sauvegarde modifiée ne peut appeler aucune fonction).
local function readSaveFile(path)
    -- Lecture directe (un fichier absent renvoie nil) : pas de getInfo préalable, chaque
    -- recherche de fichier coûte cher sur la carte SD de la 3DS
    local okRead, content = pcall(love.filesystem.read, path)
    if not okRead or type(content) ~= "string" then return nil end
    -- Les anciennes sauvegardes (avant le marqueur) restent acceptées si elles se terminent par "}"
    if not content:find(END_MARK, 1, true) and not content:match("}%s*$") then return nil end
    local chunk = loadstring(content, "=" .. path)
    if not chunk then return nil end
    setfenv(chunk, {})
    local ok, data = pcall(chunk)
    if ok and type(data) == "table" then return data end
    return nil
end

-- Des deux fichiers valides, celui qui porte le numéro de sauvegarde le plus élevé
-- (anciennes sauvegardes sans numéro : 0, le fichier principal l'emporte à égalité)
local function newestSave()
    local main = readSaveFile(Save.SAVE_FILE)
    local backup = readSaveFile(Save.BACKUP_FILE)
    if main and backup then
        local seqMain = tonumber(main.saveSeq) or 0
        local seqBackup = tonumber(backup.saveSeq) or 0
        return (seqBackup > seqMain) and backup or main
    end
    return main or backup
end

-- Chargement depuis le stockage persistant (le plus récent des deux fichiers valides)
function Save.load()
    if Save.data then return Save.data end

    local loadedData = newestSave()
    if loadedData then
        Save.data = loadedData
        -- Empreinte avant migrations : on ne réécrit la sauvegarde que si elles ont changé
        -- quelque chose (une écriture sur carte SD coûte ~0,1 s au démarrage)
        local loadedText = serializeTable(loadedData)
        -- Sécurité : injection des valeurs manquantes si mise à jour du schéma
        local defaultData = getDefaultData()
        for k, v in pairs(defaultData) do
            if Save.data[k] == nil then
                Save.data[k] = v
            end
        end
        if Save.data.equipped then
            Save.data.equipped.ring1 = Save.data.equipped.ring1 or Save.data.equipped.ring or "wolf_ring"
            Save.data.equipped.ring2 = Save.data.equipped.ring2 or "bear_ring"
            Save.data.equipped.pet1 = Save.data.equipped.pet1 or Save.data.equipped.pet or "bat_companion"
            Save.data.equipped.pet2 = Save.data.equipped.pet2 or "ghost_familiar"
        end
        if Save.data.inventory then
            local existing = {}
            for _, id in ipairs(Save.data.inventory) do
                existing[id] = true
            end
            for _, id in ipairs(defaultData.inventory) do
                if not existing[id] then
                    table.insert(Save.data.inventory, id)
                    existing[id] = true
                end
            end
        end
        if Save.data.itemLevels then
            for k, lvl in pairs(defaultData.itemLevels) do
                if Save.data.itemLevels[k] == nil then
                    Save.data.itemLevels[k] = lvl
                end
            end
        end
        if Save.data.talents == nil then
            Save.data.talents = {
                strength = 0,
                vitality = 0,
                recovery = 0,
                agility = 0,
                glory = 0,
            }
        end
        -- Migration : les anciennes sauvegardes donnaient tout le catalogue d'entrée.
        -- On ne garde que la panoplie de départ ; le reste se débloque en coffre.
        if not Save.data.itemUnlockRework then
            Save.applyUnlockRework()
        end
        Save.sanitizeEquipment()
        Admin.load(Save.data.admin)
        if serializeTable(Save.data) ~= loadedText then Save.save() end
        return Save.data
    end

    -- Première partie ou fichier corrompu : initialisation par défaut
    Save.data = getDefaultData()
    Admin.load(nil)
    Save.save()
    return Save.data
end

-- Efface toute la progression et repart d'une sauvegarde neuve
function Save.reset()
    -- Le numéro continue : l'ancienne progression (numéro plus élevé) ne doit pas revenir
    local seq = Save.data and Save.data.saveSeq
    Save.data = getDefaultData()
    Save.data.saveSeq = seq
    Admin.load(nil)
    Save.save()
    Save.applySettings()
    return Save.data
end

-- Applique les réglages de la page Paramètres aux modules concernés
function Save.applySettings()
    local d = Save.get()
    local st = d.settings or {}

    local okDepth, Depth = pcall(require, "src.render.depth")
    if okDepth and Depth then Depth.userScale = st.depth3d or 1.0 end

    local okVfx, VFX = pcall(require, "src.render.vfx_manager")
    if okVfx and VFX then
        VFX.showDamage = (st.showDamage ~= false)
        VFX.particleScale = st.lowPower and 0.4 or 1.0
    end
end

-- Équipement de départ conservé lors de la refonte des déblocages
Save.STARTER_ITEMS = { "starter_bow", "vest_dexterity", "wolf_ring", "bat_companion" }

-- Retire du sac tout ce qui n'a pas été gagné : seule la panoplie de départ reste.
-- Compense le joueur avec de l'or pour qu'il puisse ouvrir des coffres immédiatement.
function Save.applyUnlockRework()
    local d = Save.data
    if not d then return end

    local keep = {}
    for _, id in ipairs(Save.STARTER_ITEMS) do keep[id] = true end

    local removed = 0
    local newInventory = {}
    for _, id in ipairs(d.inventory or {}) do
        if keep[id] then
            table.insert(newInventory, id)
        else
            removed = removed + 1
            if d.itemCopies then d.itemCopies[id] = nil end
            if d.itemLevels then d.itemLevels[id] = nil end
            if d.itemRarities then d.itemRarities[id] = nil end
            if d.itemStars then d.itemStars[id] = nil end
        end
    end
    d.inventory = newInventory

    -- Dédommagement : de quoi ouvrir deux coffres dorés
    if removed > 0 then
        d.gold = (d.gold or 0) + 300
    end
    d.itemUnlockRework = true
end

-- Vide les emplacements équipés qui pointent vers un objet non possédé
function Save.sanitizeEquipment()
    local d = Save.data
    if not d or not d.equipped then return end

    local owned = {}
    for _, id in ipairs(d.inventory or {}) do owned[id] = true end

    local fallback = { weapon = "starter_bow", armor = "vest_dexterity", ring1 = "wolf_ring", pet1 = "bat_companion" }
    for slot, itemId in pairs(d.equipped) do
        if itemId and not owned[itemId] then
            d.equipped[slot] = (fallback[slot] and owned[fallback[slot]]) and fallback[slot] or nil
        end
    end
    d.equipped.ring = d.equipped.ring1
    d.equipped.pet = d.equipped.pet1
end

-- Écriture en alternance (ping-pong) : chaque sauvegarde porte un numéro croissant et
-- va dans le fichier qui contient la plus ancienne des deux. Une coupure (batterie,
-- console éteinte) pendant l'écriture laisse donc toujours la précédente intacte, et
-- Save.load reprend le fichier valide le plus récent. Une seule écriture par sauvegarde :
-- sur la carte SD de la 3DS, chaque écriture coûte ~0,1 s quelle que soit sa taille.
function Save.save()
    if not Save.data then return false end
    local seq = (Save.data.saveSeq or 0) + 1
    Save.data.saveSeq = seq
    local content = "return " .. serializeTable(Save.data) .. "\n" .. END_MARK .. "\n"
    local target = (seq % 2 == 1) and Save.SAVE_FILE or Save.BACKUP_FILE
    return love.filesystem.write(target, content)
end

-- ============================================================================
-- REPRISE DE PARTIE : instantané de la course au début de chaque salle
-- ============================================================================
-- Champs du héros qui ne doivent pas être restaurés (position, vitesse, minuteries)
local RUN_SKIP = {
    x = true, y = true, vx = true, vy = true, targetAngle = true, currentTarget = true,
    isMoving = true, wasMoving = true, hasInput = true, benchInputX = true, benchInputY = true,
}

function Save.saveRun(game)
    local d = Save.get()
    if game.gameMode ~= "ascension" and game.gameMode ~= "infinite" then return end
    local stats = {}
    for k, v in pairs(game.player) do
        local t = type(v)
        if not RUN_SKIP[k] and (t == "number" or t == "boolean" or t == "string") then
            stats[k] = v
        end
    end
    local skills = {}
    for i, sk in ipairs(game.acquiredSkills or {}) do skills[i] = sk.id end
    d.run = {
        mode = game.gameMode,
        room = game.roomNumber,
        gold = game.goldEarnedRun or 0,
        kills = game.kills or 0,
        ultimate = game.ultimateCharge or 0,
        heroId = game.player.heroId,
        weapon = game.player.currentWeapon and game.player.currentWeapon.id,
        skills = skills,
        player = stats,
    }
    Save.save()
end

function Save.getRun()
    local d = Save.get()
    return d.run
end

function Save.clearRun()
    local d = Save.get()
    if d.run then
        d.run = nil
        Save.save()
    end
end

function Save.get()
    if not Save.data then
        Save.load()
    end
    return Save.data
end

-- Ajout d'or
function Save.addGold(amount)
    local d = Save.get()
    d.gold = math.max(0, d.gold + amount)
    Save.save()
    return d.gold
end

-- Ajout de gemmes
function Save.addGems(amount)
    local d = Save.get()
    d.gems = math.max(0, d.gems + amount)
    Save.save()
    return d.gems
end

-- Ajout d'un objet à l'inventaire
function Save.addItem(itemId)
    local d = Save.get()
    d.itemCopies = d.itemCopies or {}
    for _, id in ipairs(d.inventory) do
        if id == itemId then
            -- Déjà possédé : incrémente le nombre de copies pour la fusion et donne un bonus d'or
            d.itemCopies[itemId] = (d.itemCopies[itemId] or 1) + 1
            Save.addGold(75)
            Save.save()
            return false, string.format("COPY OBTAINED (%d/3)", d.itemCopies[itemId])
        end
    end
    table.insert(d.inventory, itemId)
    d.itemCopies[itemId] = (d.itemCopies[itemId] or 0) + 1
    if not d.itemLevels[itemId] then
        d.itemLevels[itemId] = 1
    end
    Save.save()
    return true, "NOUVEL OBJET"
end

-- Équiper un objet
function Save.equip(slot, itemId)
    local d = Save.get()
    if d.equipped[slot] ~= nil then
        d.equipped[slot] = itemId
        Save.save()
        return true
    end
    return false
end

-- Obtenir le niveau d'un objet
function Save.getItemLevel(itemId)
    local d = Save.get()
    return d.itemLevels[itemId] or 1
end

-- Amélioration d'un équipement (Forge)
function Save.upgradeItem(itemId)
    local d = Save.get()
    local lvl = Save.getItemLevel(itemId)
    local cost = lvl * 120 -- Coût proportionnel au niveau

    if d.gold >= cost then
        d.gold = d.gold - cost
        d.itemLevels[itemId] = lvl + 1
        Save.addQuestProgress("upgrades", 1)
    Save.save()
        return true, lvl + 1, cost
    end
    return false, lvl, cost
end

-- Obtenir les talents
function Save.getTalents()
    local d = Save.get()
    if not d.talents then
        d.talents = { strength = 0, vitality = 0, recovery = 0, agility = 0, glory = 0 }
    end
    return d.talents
end

-- Amélioration aléatoire d'un talent (Système de Runes Archero)
function Save.upgradeTalent()
    local d = Save.get()
    local talents = Save.getTalents()
    local totalLevel = (talents.strength or 0) + (talents.vitality or 0) + (talents.recovery or 0) + (talents.agility or 0) + (talents.glory or 0)
    local cost = Balance.COSTS.talentBase + totalLevel * Balance.COSTS.talentStep

    if d.gold >= cost then
        d.gold = d.gold - cost
        local pool = { "strength", "vitality", "recovery", "agility" }
        if (talents.glory or 0) == 0 then
            table.insert(pool, "glory")
        end
        local chosen = pool[math.random(1, #pool)]
        talents[chosen] = (talents[chosen] or 0) + 1
        Save.save()
        return true, chosen, talents[chosen], cost
    end
    return false, nil, totalLevel, cost
end

-- ============================================================================
-- NOUVEAUX SYSTÈMES ARCHERO 2 : HÉROS, PATROUILLE AFK, CHAPITRES & FUSION
-- ============================================================================

-- Sélection du Héros Actif
function Save.selectHero(heroId)
    local d = Save.get()
    d.unlockedHeroes = d.unlockedHeroes or { atreus = true, urasil = true }
    if d.unlockedHeroes[heroId] then
        d.selectedHero = heroId
        Save.save()
        return true
    end
    return false
end

-- Déblocage d'un Héros avec Or ou Gemmes
function Save.unlockHero(heroId)
    local Heroes = require("src.data.heroes")
    local h = Heroes.get(heroId)
    local d = Save.get()
    d.unlockedHeroes = d.unlockedHeroes or { atreus = true, urasil = true }
    if not h then return false end
    if d.unlockedHeroes[heroId] then return true end

    if h.costType == "free" then
        d.unlockedHeroes[heroId] = true
        Save.save()
        return true
    elseif h.costType == "gold" and (d.gold or 0) >= (h.cost or 0) then
        d.gold = d.gold - h.cost
        d.unlockedHeroes[heroId] = true
        Save.save()
        return true
    elseif h.costType == "gems" and (d.gems or 0) >= (h.cost or 0) then
        d.gems = d.gems - h.cost
        d.unlockedHeroes[heroId] = true
        Save.save()
        return true
    end
    return false
end

-- Récolte de la Patrouille AFK (Idle Chest)
function Save.claimPatrol()
    local d = Save.get()
    local amt = math.floor(d.patrolGold or 0)
    if amt > 0 then
        d.gold = d.gold + amt
        d.patrolGold = 0
        Save.save()
        return amt
    end
    return 0
end

-- Accumulation passive de la patrouille AFK
function Save.updatePatrol(dt)
    local d = Save.get()
    d.patrolMax = d.patrolMax or 500
    if (d.patrolGold or 0) < d.patrolMax then
        d.patrolGold = math.min(d.patrolMax, (d.patrolGold or 0) + dt * 1.5)
    end
end

-- Sélection du Chapitre
-- ============================================================================
-- QUÊTES JOURNALIÈRES & PASSE DE COMBAT
-- ============================================================================
local Quests = require("src.data.quests")

local function todayKey()
    return os.date("%Y-%j")
end

local function weekKey()
    return os.date("%Y-W%W")
end

-- Récupère l'état des quêtes en réinitialisant si le jour a changé
function Save.getDailyQuests()
    local d = Save.get()
    d.dailyQuests = d.dailyQuests or { day = "", points = 0, progress = {}, claimed = {}, claimedTiers = {} }
    local q = d.dailyQuests
    q.progress = q.progress or {}
    q.claimed = q.claimed or {}
    q.claimedTiers = q.claimedTiers or {}
    if q.day ~= todayKey() then
        q.day = todayKey()
        q.points = 0
        q.progress = { kills = 0, rooms = 0, chests = 0, upgrades = 0, bosses = 0, skills = 0, gold = 0, pots = 0, runs = 0 }
        q.claimed = {}
        q.claimedTiers = {}
        -- Nouvelle sélection de missions : le pool tourne chaque jour
        q.selected = {}
        for _, quest in ipairs(Quests.dailySelection(q.day)) do
            q.selected[#q.selected + 1] = quest.id
        end
        Save.save()
    end
    if not q.selected or #q.selected == 0 then
        q.selected = {}
        for _, quest in ipairs(Quests.dailySelection(q.day)) do
            q.selected[#q.selected + 1] = quest.id
        end
    end
    return q
end

-- Missions du jour effectivement tirées (objets complets, pas des identifiants)
function Save.getDailyQuestList()
    local q = Save.getDailyQuests()
    local list = {}
    for _, id in ipairs(q.selected or {}) do
        local quest = Quests.get(id)
        if quest then list[#list + 1] = quest end
    end
    return list, q
end

-- Missions hebdomadaires : compteurs séparés, remis à zéro chaque semaine
function Save.getWeeklyQuests()
    local d = Save.get()
    d.weeklyQuests = d.weeklyQuests or { week = "", progress = {}, claimed = {}, selected = {} }
    local w = d.weeklyQuests
    w.progress = w.progress or {}
    w.claimed = w.claimed or {}
    if w.week ~= weekKey() then
        w.week = weekKey()
        w.progress = { kills = 0, rooms = 0, chests = 0, upgrades = 0, bosses = 0, skills = 0, gold = 0, pots = 0, runs = 0 }
        w.claimed = {}
        w.selected = {}
        for _, quest in ipairs(Quests.weeklySelection(w.week)) do
            w.selected[#w.selected + 1] = quest.id
        end
        Save.save()
    end
    return w
end

function Save.getWeeklyQuestList()
    local w = Save.getWeeklyQuests()
    local list = {}
    for _, id in ipairs(w.selected or {}) do
        local quest = Quests.get(id)
        if quest then list[#list + 1] = quest end
    end
    return list, w
end

-- Avance un compteur de quête ("kills", "rooms", "chests", "upgrades", "bosses")
-- persist = true pour écrire immédiatement (hors combat)
function Save.addQuestProgress(kind, amount, persist)
    local q = Save.getDailyQuests()
    q.progress[kind] = (q.progress[kind] or 0) + (amount or 1)

    -- Les mêmes actions font avancer les missions de la semaine
    local w = Save.getWeeklyQuests()
    w.progress[kind] = (w.progress[kind] or 0) + (amount or 1)

    if persist then Save.save() end
    return q.progress[kind]
end

-- Réclame une mission hebdomadaire terminée
function Save.claimWeeklyQuest(questId)
    local quest = Quests.get(questId)
    if not quest then return false end
    local w = Save.getWeeklyQuests()
    local progress, done, claimed = Quests.state(quest, w)
    if not done or claimed then return false end

    w.claimed[questId] = true
    if quest.reward.gold then Save.addGold(quest.reward.gold) end
    if quest.reward.gems then Save.addGems(quest.reward.gems) end
    Save.save()
    return true
end

-- Réclame la récompense d'une quête terminée : renvoie true si accordée
function Save.claimQuest(questId)
    local quest = Quests.get(questId)
    if not quest then return false end
    local q = Save.getDailyQuests()
    local progress, done, claimed = Quests.state(quest, q)
    if not done or claimed then return false end

    q.claimed[questId] = true
    q.points = math.min(Quests.MAX_POINTS, (q.points or 0) + quest.points)
    if quest.reward.gold then Save.addGold(quest.reward.gold) end
    if quest.reward.gems then Save.addGems(quest.reward.gems) end
    Save.save()
    return true
end

-- Réclame un palier de la jauge du passe
function Save.claimQuestTier(tierIndex)
    local tier = Quests.TIERS[tierIndex]
    if not tier then return false end
    local q = Save.getDailyQuests()
    if (q.points or 0) < tier.points or q.claimedTiers[tierIndex] then return false end

    q.claimedTiers[tierIndex] = true
    if tier.reward.gold then Save.addGold(tier.reward.gold) end
    if tier.reward.gems then Save.addGems(tier.reward.gems) end
    Save.save()
    return true
end

-- ============================================================================
-- BESTIAIRE & RECORDS D'ÉVÉNEMENTS
-- ============================================================================
function Save.recordKill(monsterType, count)
    if not monsterType then return end
    local d = Save.get()
    d.bestiary = d.bestiary or {}
    d.bestiary[monsterType] = (d.bestiary[monsterType] or 0) + (count or 1)
end

function Save.getBestiary()
    local d = Save.get()
    d.bestiary = d.bestiary or {}
    return d.bestiary
end

function Save.setEventRecord(mode, value)
    local d = Save.get()
    d.events = d.events or { bossRushBest = 0, survivalBest = 0 }
    local key = (mode == "survival") and "survivalBest" or "bossRushBest"
    if (value or 0) > (d.events[key] or 0) then
        d.events[key] = value
        Save.save()
        return true
    end
    return false
end

function Save.getEvents()
    local d = Save.get()
    d.events = d.events or { bossRushBest = 0, survivalBest = 0 }
    return d.events
end

function Save.setChapter(chapIndex)
    local d = Save.get()
    d.selectedChapter = math.max(1, math.min(6, chapIndex))
    Save.save()
    return d.selectedChapter
end

-- Rareté effective (Prend en compte les fusions passées)
-- Étoiles d'objet : gagnées en fusionnant un objet déjà au maximum de rareté
-- Succès : réclame la récompense d'un succès terminé
function Save.claimAchievement(id)
    local Achievements = require("src.data.achievements")
    local a = Achievements.get(id)
    if not a then return false end
    local d = Save.get()
    d.achievements = d.achievements or {}
    local _, done, claimed = Achievements.state(a, d)
    if not done or claimed then return false end

    d.achievements[id] = true
    if a.reward.gold then Save.addGold(a.reward.gold) end
    if a.reward.gems then Save.addGems(a.reward.gems) end
    Save.save()
    return true
end

-- Boutique du jour : 3 offres tirées à partir de la date (identiques toute la journée)
function Save.getShop()
    local d = Save.get()
    d.shop = d.shop or { day = "", bought = {} }
    local today = os.date("%Y-%j")
    if d.shop.day ~= today then
        d.shop.day = today
        d.shop.bought = {}
        Save.save()
    end
    return d.shop
end

function Save.markShopBought(index)
    local shop = Save.getShop()
    shop.bought[index] = true
    Save.save()
end

function Save.getItemStars(itemId)
    local d = Save.get()
    d.itemStars = d.itemStars or {}
    return d.itemStars[itemId] or 0
end

function Save.addItemStar(itemId)
    local d = Save.get()
    d.itemStars = d.itemStars or {}
    local cur = d.itemStars[itemId] or 0
    if cur >= 5 then return false end
    d.itemStars[itemId] = cur + 1
    Save.save()
    return true
end

-- Régénération d'énergie : +1 toutes les 6 minutes, même hors du jeu
local ENERGY_PERIOD = Balance.ENERGY.period

function Save.updateEnergyRegen()
    local d = Save.get()
    local now = os.time()
    d.energyStamp = d.energyStamp or now
    if d.energy >= d.maxEnergy then
        d.energyStamp = now
        return 0
    end
    local elapsed = now - d.energyStamp
    if elapsed < ENERGY_PERIOD then return 0 end
    local gained = math.floor(elapsed / ENERGY_PERIOD)
    local before = d.energy
    d.energy = math.min(d.maxEnergy, d.energy + gained)
    d.energyStamp = now - (elapsed % ENERGY_PERIOD)
    if d.energy ~= before then Save.save() end
    return d.energy - before
end

-- Dépense l'énergie pour booster une partie. Renvoie false si la réserve est
-- insuffisante : la partie se lance quand même, simplement sans bonus.
function Save.spendEnergy(mode)
    local d = Save.get()
    Save.updateEnergyRegen()
    local cost = Balance.energyCost(mode)
    if (d.energy or 0) < cost then
        return false, cost
    end
    if d.energy >= d.maxEnergy then
        d.energyStamp = os.time()
    end
    d.energy = d.energy - cost
    Save.save()
    return true, cost
end

-- Temps restant (en secondes) avant la prochaine énergie
function Save.energyCountdown()
    local d = Save.get()
    if d.energy >= d.maxEnergy then return 0 end
    local elapsed = os.time() - (d.energyStamp or os.time())
    return math.max(0, ENERGY_PERIOD - (elapsed % ENERGY_PERIOD))
end

function Save.getItemRarity(itemId)
    local d = Save.get()
    if d.itemRarities and d.itemRarities[itemId] then
        return d.itemRarities[itemId]
    end
    local Items = require("src.data.items")
    local item = Items.get(itemId)
    return item and item.rarity or "common"
end

-- Nombre de copies possédées d'un objet
function Save.getItemCopies(itemId)
    local d = Save.get()
    d.itemCopies = d.itemCopies or {}
    return d.itemCopies[itemId] or 1
end

-- Fusion d'équipement (3 -> 1 palier supérieur)
function Save.fuseItem(itemId)
    local d = Save.get()
    d.itemCopies = d.itemCopies or {}
    d.itemRarities = d.itemRarities or {}

    local copies = Save.getItemCopies(itemId)
    if copies < 3 then
        return false, "NOT ENOUGH COPIES (3 NEEDED)"
    end

    local curRarity = Save.getItemRarity(itemId)
    local nextTiers = {
        common = "uncommon",
        uncommon = "rare",
        rare = "epic",
        epic = "legendary",
    }
    local nextRarity = nextTiers[curRarity]
    if not nextRarity then
        -- Maximum rarity: fusion adds a star (+6% stats)
        if Save.getItemStars(itemId) >= 5 then
            return false, "MAXIMUM STARS"
        end
        d.itemCopies[itemId] = copies - 2
        Save.addItemStar(itemId)
        Save.save()
        return true, curRarity, Save.getItemStars(itemId)
    end

    -- Consomme 2 copies pour hisser l'objet au rang supérieur (3 -> 1)
    d.itemCopies[itemId] = copies - 2
    d.itemRarities[itemId] = nextRarity
    Save.save()
    return true, nextRarity
end

return Save

