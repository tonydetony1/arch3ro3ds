-- src/core/world_manager.lua
-- Gestionnaire des Biomes, Chapitres, Palettes procédurales et Tables de monstres

local WorldManager = {
    CHAPTERS = {
        [1] = {
            id = "forest",
            name = "Forêt Verdoyante",
            roomCount = 50,
            baseHp = 50,
            hpScaling = 14,
            goldMultiplier = 1.0,
            monsterPool = { "slime", "bat", "wolf", "skeleton", "plant", "splitter", "bomber", "burrower" },
            boss = "golem",
            palette = {
                grassBase   = {0.42, 0.77, 0.26},
                grassTile1  = {0.45, 0.81, 0.28},
                grassTile2  = {0.40, 0.73, 0.24},
                bushDark    = {0.10, 0.32, 0.12},
                bushMid     = {0.16, 0.44, 0.16},
                bushLight   = {0.26, 0.58, 0.22},
                cliff       = {0.34, 0.22, 0.12},
                shadow      = {0.02, 0.08, 0.03, 0.32},
                gateGlow    = {0.20, 0.95, 0.60},
                skyTop      = {0.38, 0.68, 0.96},
                skyBottom   = {0.86, 0.96, 1.00},
                floorBase   = {0.42, 0.77, 0.26},
                floorTile1  = {0.45, 0.81, 0.28},
                floorTile2  = {0.40, 0.73, 0.24},
                mortar      = {0.36, 0.68, 0.21},
                wallNorth   = {0.16, 0.44, 0.16},
                wallSide    = {0.10, 0.32, 0.12},
                torchGlow   = {1.0, 0.85, 0.30},
            },
        },
        [2] = {
            id = "desert",
            name = "Désert Aride",
            roomCount = 50,
            baseHp = 90,
            hpScaling = 22,
            goldMultiplier = 1.4,
            monsterPool = { "wolf", "skeleton", "bomber", "burrower", "plant", "summoner", "turret" },
            boss = "skeleton_king",
            palette = {
                floorBase  = {0.17, 0.14, 0.11},
                floorTile1 = {0.20, 0.17, 0.12},
                floorTile2 = {0.15, 0.12, 0.09},
                mortar     = {0.10, 0.08, 0.06},
                wallNorth  = {0.26, 0.21, 0.15},
                wallSide   = {0.22, 0.18, 0.13},
                torchGlow  = {1.0, 0.45, 0.10},
                gateGlow   = {1.0, 0.75, 0.2},
            },
        },
        [3] = {
            id = "crystal",
            name = "Cavernes de Cristal",
            roomCount = 50,
            baseHp = 140,
            hpScaling = 32,
            goldMultiplier = 1.9,
            monsterPool = { "bat", "skeleton", "bomber", "splitter", "burrower", "mage", "turret" },
            boss = "witch",
            palette = {
                floorBase  = {0.10, 0.11, 0.18},
                floorTile1 = {0.13, 0.14, 0.22},
                floorTile2 = {0.15, 0.11, 0.20},
                mortar     = {0.06, 0.07, 0.12},
                wallNorth  = {0.20, 0.22, 0.35},
                wallSide   = {0.17, 0.19, 0.30},
                torchGlow  = {0.3, 0.75, 1.0},
                gateGlow   = {0.8, 0.3, 1.0},
            },
        },
        [4] = {
            id = "inferno",
            name = "Enfer Volcanique",
            roomCount = 50,
            baseHp = 220,
            hpScaling = 45,
            goldMultiplier = 2.6,
            monsterPool = { "wolf", "skeleton", "splitter", "bomber", "golem", "summoner", "mage" },
            boss = "lava_titan",
            palette = {
                floorBase  = {0.14, 0.08, 0.08},
                floorTile1 = {0.18, 0.09, 0.09},
                floorTile2 = {0.22, 0.10, 0.07},
                mortar     = {0.08, 0.04, 0.04},
                wallNorth  = {0.26, 0.12, 0.12},
                wallSide   = {0.22, 0.10, 0.10},
                torchGlow  = {1.0, 0.25, 0.05},
                gateGlow   = {1.0, 0.4, 0.1},
            },
        },
        [5] = {
            id = "skyward",
            name = "Îles Célestes",
            roomCount = 50,
            baseHp = 320,
            hpScaling = 62,
            goldMultiplier = 3.2,
            monsterPool = { "raven", "wisp", "gargoyle", "bat", "skeleton", "mage", "turret" },
            boss = "storm_drake",
            palette = {
                floorBase  = {0.70, 0.78, 0.92},
                floorTile1 = {0.76, 0.84, 0.96},
                floorTile2 = {0.64, 0.73, 0.89},
                mortar     = {0.52, 0.60, 0.78},
                wallNorth  = {0.58, 0.66, 0.85},
                wallSide   = {0.50, 0.58, 0.78},
                torchGlow  = {0.55, 0.92, 1.0},
                gateGlow   = {0.45, 0.90, 1.0},
                grassBase  = {0.70, 0.78, 0.92},
                grassTile1 = {0.76, 0.84, 0.96},
                grassTile2 = {0.64, 0.73, 0.89},
                bushDark   = {0.30, 0.42, 0.66},
                bushMid    = {0.42, 0.56, 0.80},
                bushLight  = {0.62, 0.76, 0.95},
                cliff      = {0.42, 0.50, 0.70},
                shadow     = {0.10, 0.14, 0.26, 0.30},
                skyTop     = {0.24, 0.52, 0.88},
                skyBottom  = {0.86, 0.94, 1.00},
            },
        },
        [6] = {
            id = "void",
            name = "Cité du Vide",
            roomCount = 50,
            baseHp = 460,
            hpScaling = 88,
            goldMultiplier = 4.0,
            monsterPool = { "frost_wraith", "wisp", "gargoyle", "mage", "summoner", "splitter", "turret" },
            boss = "void_watcher",
            palette = {
                floorBase  = {0.16, 0.12, 0.24},
                floorTile1 = {0.21, 0.15, 0.31},
                floorTile2 = {0.13, 0.10, 0.20},
                mortar     = {0.09, 0.06, 0.14},
                wallNorth  = {0.26, 0.18, 0.38},
                wallSide   = {0.20, 0.14, 0.30},
                torchGlow  = {0.70, 0.35, 1.0},
                gateGlow   = {0.80, 0.40, 1.0},
                grassBase  = {0.16, 0.12, 0.24},
                grassTile1 = {0.21, 0.15, 0.31},
                grassTile2 = {0.13, 0.10, 0.20},
                bushDark   = {0.10, 0.06, 0.18},
                bushMid    = {0.24, 0.14, 0.36},
                bushLight  = {0.40, 0.24, 0.56},
                cliff      = {0.22, 0.16, 0.32},
                shadow     = {0.04, 0.02, 0.08, 0.40},
                skyTop     = {0.08, 0.04, 0.16},
                skyBottom  = {0.38, 0.16, 0.52},
            },
        },
    }
}


-- ============================================================================
-- THÈMES VISUELS DES CHAPITRES (décor, ciel, dangers)
-- ============================================================================
WorldManager.THEMES = {
    [1] = {
        variant = nil,                       -- décor par défaut (prairie)
        ground = "4f9b45", groundLight = "5dac4d", groundDark = "438a3e", edge = "356f39",
        skyTop = "4f9be8", skyBottom = "cdeeff",
        wallTree = "tall_tree_a", wallTreeSmall = "tall_tree_b",
        decals = { "tuft_a", "tuft_b", "tuft_c", "flowers_w", "flowers_y", "flowers_p", "pebbles" },
        patchLight = "patch_light", patchDark = "patch_dark", patchExtra = "patch_dirt",
        hazard = nil,
    },
    [2] = {
        variant = "sand",
        ground = "d6ac72", groundLight = "e4c48c", groundDark = "c09a63", edge = "a07c4a",
        skyTop = "e8a34f", skyBottom = "ffe6b8",
        wallTree = "cactus", wallTreeSmall = "cactus",
        decals = { "bones", "pebbles", "tuft_c", "bones" },
        patchLight = "patch_dirt", patchDark = "patch_dark", patchExtra = "patch_dirt",
        hazard = "sand",                      -- sables mouvants : ralentissent
    },
    [3] = {
        variant = "crystal",
        ground = "3f4a7a", groundLight = "4d5a90", groundDark = "323a63", edge = "232a4d",
        skyTop = "141a33", skyBottom = "2a2f57",
        wallTree = "crystal_spire", wallTreeSmall = "crystal_spire",
        decals = { "pebbles", "ice_patch", "pebbles" },
        patchLight = "patch_light", patchDark = "patch_dark", patchExtra = "patch_dirt",
        hazard = "ice",                       -- plaques de glace : dérapage
    },
    [4] = {
        variant = "lava",
        ground = "4a3b3b", groundLight = "5c4747", groundDark = "3a2e2e", edge = "241c1c",
        skyTop = "6b1f14", skyBottom = "e8632a",
        wallTree = "tall_tree_b", wallTreeSmall = "tall_tree_b",
        decals = { "pebbles", "lava_crack", "bones" },
        patchLight = "patch_dark", patchDark = "patch_dirt", patchExtra = "patch_dark",
        hazard = "lava",                      -- mares de lave : dégâts continus
    },
    [5] = {
        variant = "sky",
        ground = "8b9bb4", groundLight = "c0cbdc", groundDark = "5a6988", edge = "3a4466",
        skyTop = "3d7dd6", skyBottom = "dff2ff",
        wallTree = "crystal_spire", wallTreeSmall = "crystal_spire",
        decals = { "pebbles", "ice_patch" },
        patchLight = "patch_light", patchDark = "patch_dark", patchExtra = "patch_light",
        hazard = "wind",                      -- bourrasques : le héros est poussé
    },
    [6] = {
        variant = "void",
        ground = "2a1f3d", groundLight = "3d2c57", groundDark = "1a1229", edge = "0f0a18",
        skyTop = "140a24", skyBottom = "5c2a7a",
        wallTree = "crystal_spire", wallTreeSmall = "crystal_spire",
        decals = { "pebbles", "bones" },
        patchLight = "patch_dark", patchDark = "patch_dirt", patchExtra = "patch_dark",
        hazard = "void",                      -- failles du Vide : dégâts et ralentissement
    },
}

function WorldManager.getTheme(chapterIndex)
    return WorldManager.THEMES[chapterIndex or 1] or WorldManager.THEMES[1]
end

function WorldManager.getChapter(chapterIndex)
    chapterIndex = chapterIndex or 1
    return WorldManager.CHAPTERS[chapterIndex] or WorldManager.CHAPTERS[1]
end

-- ============================================================================
-- MODES ÉVÉNEMENT
-- ============================================================================

-- BOSS RUSH : chaque salle est un boss entouré de sa garde rapprochée
function WorldManager.generateBossRush(chapterIndex, roomNumber, mapW, mapH)
    local chap = WorldManager.getChapter(chapterIndex)
    local baseHp = math.floor((chap.baseHp + (roomNumber - 1) * chap.hpScaling) * 1.6)
    local cx = mapW and (mapW / 2) or 320
    local cy = mapH and (mapH / 2) or 240
    local spawns = {}

    local bossTypes = { chap.boss or "golem", "splitter", "skeleton_king", "witch", "lava_titan" }
    local bossType = bossTypes[((roomNumber - 1) % #bossTypes) + 1]
    table.insert(spawns, { x = cx, y = cy - 70, hp = math.floor(baseHp * 4.2), type = bossType, isBoss = true })

    local guards = { "skeleton", "bomber", "plant", "wolf" }
    local guardCount = math.min(5, 2 + math.floor(roomNumber / 3))
    for i = 1, guardCount do
        local side = (i % 2 == 0) and 1 or -1
        table.insert(spawns, {
            x = cx + side * (120 + i * 12),
            y = cy + 30 + i * 16,
            hp = math.floor(baseHp * 0.9),
            type = guards[((roomNumber + i) % #guards) + 1],
        })
    end
    return spawns, chap
end

-- ARÈNE DE SURVIE : vagues successives dans une salle unique, boss toutes les 5 vagues
function WorldManager.generateSurvivalWave(chapterIndex, waveNumber, mapW, mapH)
    local chap = WorldManager.getChapter(chapterIndex)
    local baseHp = math.floor(chap.baseHp * (1 + (waveNumber - 1) * 0.28))
    local cx = mapW and (mapW / 2) or 320
    local cy = mapH and (mapH / 2) or 240
    local spawns = {}

    local pool = chap.monsterPool
    local count = math.min(9, 3 + math.floor(waveNumber / 2))
    for i = 1, count do
        local ang = (i / count) * math.pi * 2
        table.insert(spawns, {
            x = cx + math.cos(ang) * (mapW * 0.32),
            y = cy + math.sin(ang) * (mapH * 0.28),
            hp = baseHp,
            type = pool[((waveNumber + i) % #pool) + 1],
        })
    end
    if waveNumber % 5 == 0 then
        table.insert(spawns, { x = cx, y = cy - 60, hp = math.floor(baseHp * 3.4), type = chap.boss or "golem", isBoss = true })
    end
    return spawns, chap
end

-- Détermine le type de salle : "angel" (sanctuaire), "boss" (palier) ou "combat" (vague)
function WorldManager.getRoomType(roomNumber)
    if roomNumber % 10 == 0 then
        return "boss"
    elseif roomNumber % 10 == 5 then
        return "angel"
    else
        return "combat"
    end
end

-- Génération de la vague de la salle (spawns et types) adaptée à mapW et mapH
-- ============================================================================
-- COMPOSITION DES VAGUES
-- ============================================================================
-- Chaque archétype a un "coût" en points de vie : une chauve-souris vaut 0.6 fois
-- un squelette, un slime écarlate 1.6 fois. Les PV d'une salle sont un budget
-- réparti entre les monstres présents : plus il y en a, moins chacun est robuste.
WorldManager.ARCHETYPE_HP = {
    slime      = 0.90,
    bat        = 0.60,
    wolf       = 0.85,
    skeleton   = 1.00,
    plant      = 0.80,
    bomber     = 0.75,
    burrower   = 0.95,
    splitter   = 1.60,
    mini_slime = 0.40,
    summoner   = 1.10,
    turret     = 1.30,
    mage       = 1.05,
    golem      = 2.20,
    raven      = 0.65,
    wisp       = 0.50,
    gargoyle   = 1.40,
    frost_wraith = 1.15,
    storm_drake = 2.40,
    void_watcher = 2.60,
}

-- Nombre de monstres d'une salle : 4 au début, jusqu'à 10 en fin de parcours
function WorldManager.monsterCount(roomNumber)
    return math.max(4, math.min(10, 4 + math.floor(((roomNumber or 1) - 1) / 4)))
end

-- Budget total de PV d'une salle : croît un peu avec le nombre de monstres,
-- mais bien moins vite, pour que les grosses vagues restent gérables.
function WorldManager.hpBudget(baseHp, count)
    return baseHp * 4.4 * (1 + 0.05 * (count - 4))
end

-- Répartit un budget de PV entre les monstres selon leur archétype
function WorldManager.distributeHp(types, budget)
    local totalWeight = 0
    for _, t in ipairs(types) do
        totalWeight = totalWeight + (WorldManager.ARCHETYPE_HP[t] or 1.0)
    end
    if totalWeight <= 0 then totalWeight = 1 end

    local hps = {}
    for i, t in ipairs(types) do
        local weight = WorldManager.ARCHETYPE_HP[t] or 1.0
        hps[i] = math.max(1, math.floor(budget * (weight / totalWeight) + 0.5))
    end
    return hps
end

-- Sélectionne les archétypes d'une vague dans le pool du chapitre, en faisant
-- tourner le point de départ pour que deux salles voisines ne se ressemblent pas.
local function pickTypes(chap, roomNumber, count)
    local pool = chap.monsterPool or { "slime" }
    local types = {}
    local offset = ((roomNumber or 1) - 1) * 3
    for i = 1, count do
        types[i] = pool[((offset + i - 1) % #pool) + 1]
    end
    return types
end

-- Place les monstres en couronne autour du centre de l'arène
local function ringPosition(i, count, cx, cy, mapW, mapH)
    local angle = ((i - 0.5) / count) * math.pi * 2 - math.pi / 2
    local rx = (mapW or 640) * 0.30
    local ry = (mapH or 480) * 0.24
    return cx + math.cos(angle) * rx, cy + math.sin(angle) * ry - 20
end

function WorldManager.generateWave(chapterIndex, roomNumber, mapW, mapH)
    local chap = WorldManager.getChapter(chapterIndex)
    local baseHp = chap.baseHp + (roomNumber - 1) * chap.hpScaling
    local spawns = {}
    local cx = mapW and (mapW / 2) or 200
    local cy = mapH and (mapH / 2) or 120

    -- 1. SANCTUAIRE DE L'ANGE (Salles 5, 15, 25, 35, 45 : aucun monstre)
    if roomNumber % 10 == 5 then
        return spawns, chap
    end

    if roomNumber % 10 == 0 then
        -- GRAND BOSS DE PALIER : le boss concentre les PV, sa garde est plus nombreuse en profondeur
        table.insert(spawns, { x = cx, y = cy - 80, hp = math.floor(baseHp * 4.5), type = chap.boss or "golem", isBoss = true })

        local guardCount = math.max(2, math.min(6, 2 + math.floor(roomNumber / 10)))
        local guardTypes = pickTypes(chap, roomNumber + 1, guardCount)
        local guardHps = WorldManager.distributeHp(guardTypes, baseHp * 2.4)
        for i = 1, guardCount do
            local gx, gy = ringPosition(i, guardCount, cx, cy + 30, mapW, mapH)
            table.insert(spawns, { x = gx, y = gy, hp = guardHps[i], type = guardTypes[i] })
        end
        return spawns, chap
    end

    if roomNumber % 5 == 0 then
        -- MINI-BOSS : un slime écarlate costaud entouré d'une escorte légère
        local escortCount = math.max(2, math.min(6, WorldManager.monsterCount(roomNumber) - 2))
        table.insert(spawns, { x = cx, y = cy - 70, hp = math.floor(baseHp * 2.8), type = "splitter" })

        local escortTypes = pickTypes(chap, roomNumber, escortCount)
        local escortHps = WorldManager.distributeHp(escortTypes, baseHp * 1.9)
        for i = 1, escortCount do
            local ex, ey = ringPosition(i, escortCount, cx, cy + 40, mapW, mapH)
            table.insert(spawns, { x = ex, y = ey, hp = escortHps[i], type = escortTypes[i] })
        end
        return spawns, chap
    end

    -- VAGUE CLASSIQUE : le nombre grimpe avec la profondeur, les PV individuels baissent
    local count = WorldManager.monsterCount(roomNumber)
    local types = pickTypes(chap, roomNumber, count)
    local hps = WorldManager.distributeHp(types, WorldManager.hpBudget(baseHp, count))

    for i = 1, count do
        local x, y = ringPosition(i, count, cx, cy, mapW, mapH)
        table.insert(spawns, { x = x, y = y, hp = hps[i], type = types[i] })
    end

    return spawns, chap
end

return WorldManager
