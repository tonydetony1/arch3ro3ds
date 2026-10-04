-- src/data/balance.lua
-- Réglages d'économie et de rythme de progression.
-- Tout est centralisé ici pour pouvoir accélérer ou ralentir la partie sans
-- toucher à la logique de jeu : énergie, gains d'or, coûts et paliers de rareté.
--
-- Objectif de rythme : une session complète (tout l'équipement légendaire,
-- tous les talents) doit demander plusieurs jours de jeu, pas une soirée.

local Balance = {}

-- ============================================================================
-- ÉNERGIE : bonus optionnel, jamais une limite
-- ============================================================================
-- Une partie peut TOUJOURS être lancée. Si le joueur a de l'énergie, elle est
-- dépensée pour booster les gains d'or de la partie : c'est une récompense
-- de régularité, pas une barrière.
Balance.ENERGY = {
    period = 540,        -- secondes par point d'énergie régénéré (9 min)
    bonusCost = 5,       -- énergie consommée pour booster une partie classique
    eventBonusCost = 8,  -- idem pour les modes événement (bonus plus cher)
    goldMult = 1.5,      -- multiplicateur d'or quand la partie est boostée
}

-- Énergie nécessaire pour booster une partie dans le mode donné
function Balance.energyCost(mode)
    if mode == "boss_rush" or mode == "survival" then
        return Balance.ENERGY.eventBonusCost
    end
    return Balance.ENERGY.bonusCost
end

-- ============================================================================
-- GAINS EN JEU : volontairement modestes, l'or est la ressource limitante
-- ============================================================================
Balance.LOOT = {
    coinMin = 6,         -- pièce lâchée par un monstre
    coinMax = 11,
    potCoinMin = 4,      -- pièce cachée dans une urne
    potCoinMax = 8,
    bossBonusMin = 18,   -- bonus d'or garanti à la mort d'un boss
    bossBonusMax = 30,
    xpShare = 0.40,      -- share of drops that are experience gems
    heartShare = 0.15,   -- share of drops that are hearts (only when the hero is hurt)
}

-- Kind of a monster drop from a uniform roll in [0, 1): "xp", "heart" or "coin".
-- (Scrolls used to drop as well, but nothing uses them yet.)
function Balance.lootType(roll, isHurt)
    if roll < Balance.LOOT.xpShare then return "xp" end
    if isHurt and roll < Balance.LOOT.xpShare + Balance.LOOT.heartShare then return "heart" end
    return "coin"
end

-- Le butin doit suivre la difficulté : une salle profonde rapporte davantage,
-- sinon les runs longs ne paient pas leur risque.
-- Salle 1 : ×1.00 | salle 10 : ×1.45 | salle 20 : ×1.95 | salle 40 : ×2.95
function Balance.depthMultiplier(roomNumber)
    return 1.0 + math.max(0, (roomNumber or 1) - 1) * 0.05
end

-- ============================================================================
-- COÛTS : coffres, forge, talents
-- ============================================================================
Balance.COSTS = {
    goldChest = 450,     -- coffre doré (or)
    obsidianChest = 50,  -- coffre d'obsidienne (gemmes)
    talentBase = 120,    -- coût du 1er talent
    talentStep = 70,     -- surcoût par talent déjà acheté
}

-- Coût d'amélioration d'un objet : croissance quadratique douce, majorée par la rareté.
-- Calibré pour qu'un objet rare coûte ~16 000 or jusqu'au niveau 15 et ~31 000 jusqu'au 20,
-- soit une vingtaine d'heures de jeu pour une panoplie complète.
function Balance.upgradeCost(level, rarityTier)
    level = math.max(1, level or 1)
    rarityTier = rarityTier or 1
    local base = 110 + (level - 1) * 60 + (level - 1) * (level - 1) * 2.5
    return math.floor(base * (0.85 + rarityTier * 0.3))
end

-- ============================================================================
-- PALIERS DE RARETÉ : les meilleures pièces demandent de la progression
-- ============================================================================
-- Tant que le joueur n'a pas atteint la salle indiquée, la rareté reste
-- inaccessible dans les coffres : impossible de tout obtenir le premier soir.
Balance.RARITY_UNLOCKS = {
    { rarity = "common",    room = 0 },
    { rarity = "uncommon",  room = 0 },
    { rarity = "rare",      room = 10 },
    { rarity = "epic",      room = 25 },
    { rarity = "legendary", room = 45 },
}

local RARITY_RANK = { common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5 }

-- Rareté maximale actuellement accessible, d'après le meilleur palier atteint
function Balance.maxRarity(saveData)
    local records = saveData and saveData.records or {}
    local best = math.max(records.ascensionMax or 1, records.infiniteMax or 0)
    local unlocked = "common"
    for _, tier in ipairs(Balance.RARITY_UNLOCKS) do
        if best >= tier.room then unlocked = tier.rarity end
    end
    return unlocked
end

-- Salle à atteindre pour débloquer une rareté (nil si déjà accessible d'office)
function Balance.roomForRarity(rarity)
    for _, tier in ipairs(Balance.RARITY_UNLOCKS) do
        if tier.rarity == rarity then
            return tier.room > 0 and tier.room or nil
        end
    end
    return nil
end

function Balance.rarityRank(rarity)
    return RARITY_RANK[rarity or "common"] or 1
end

-- Rencontres (src/core/encounter_director.lua) : PV totaux d'une salle de combat par rapport
-- à l'ancien budget à vague unique (réparti désormais sur 1 à 3 vagues)
Balance.ENCOUNTER = {
    hpMult = 1.3,
}

return Balance
