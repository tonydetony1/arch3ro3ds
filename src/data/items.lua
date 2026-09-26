-- src/data/items.lua
-- Catalogue data-driven des équipements, armes, armures, anneaux et familiers
-- Système de raretés Archero : Commun, Atypique, Rare, Épique, Légendaire
-- Calcul dynamique des stats et des passifs débloqués par palier

local Balance = require("src.data.balance")

local Items = {
    -- COULEURS OFFICIELLES DU DESIGN SYSTEM ARCHERO
    RARITIES = {
        common = {
            id = "common",
            name = "COMMUN",
            tier = 1,
            color = {0.75, 0.78, 0.85},     -- Gris argenté
            bg = {0.14, 0.16, 0.20},
            border = {0.55, 0.60, 0.70},
            highlight = {0.85, 0.88, 0.95},
            statMult = 1.0,
            tag = "BASE",
        },
        uncommon = {
            id = "uncommon",
            name = "ATYPIQUE",
            tier = 2,
            color = {0.25, 0.85, 0.45},     -- Vert émeraude
            bg = {0.08, 0.22, 0.14},
            border = {0.18, 0.75, 0.38},
            highlight = {0.55, 1.00, 0.70},
            statMult = 1.25,
            tag = "+25% STATS",
        },
        rare = {
            id = "rare",
            name = "RARE",
            tier = 3,
            color = {0.25, 0.68, 1.00},     -- Bleu saphir
            bg = {0.08, 0.18, 0.32},
            border = {0.20, 0.55, 0.90},
            highlight = {0.60, 0.88, 1.00},
            statMult = 1.55,
            tag = "PASSIF 1",
        },
        epic = {
            id = "epic",
            name = "ÉPIQUE",
            tier = 4,
            color = {0.80, 0.30, 0.98},     -- Violet améthyste
            bg = {0.24, 0.10, 0.30},
            border = {0.70, 0.22, 0.88},
            highlight = {0.95, 0.60, 1.00},
            statMult = 1.95,
            tag = "GAMEPLAY",
        },
        legendary = {
            id = "legendary",
            name = "LÉGENDAIRE",
            tier = 5,
            color = {1.00, 0.82, 0.18},     -- Or solaire scintillant
            bg = {0.30, 0.24, 0.08},
            border = {0.95, 0.72, 0.10},
            highlight = {1.00, 0.96, 0.65},
            statMult = 2.45,
            tag = "ULTIME",
        },
    },

    CATALOGUE = {
        -- ====================================================================
        -- 1. ARMES (Weapons)
        -- ====================================================================
        starter_bow = {
            id = "starter_bow",
            name = "Arc de Brave",
            slot = "weapon",
            icon = "bow",
            rarity = "common",
            baseAtk = 18,
            fireRate = 0.34,
            speed = 280,
            desc = "Arme équilibrée offrant une cadence constante et des tirs stables.",
            passives = {
                uncommon  = { name = "Puissance Brute", desc = "Attaque de base augmentée de +25%." },
                rare      = { name = "Œil de Faucon", desc = "+10% Chances de Coup Critique." },
                epic      = { name = "Flèches Fractales", desc = "Tire +1 Flèche Diagonale sans perte de dégâts." },
                legendary = { name = "Jugement Solaire", desc = "Les flèches percent 1 obstacle et infligent +50% Crit." },
            },
        },
        rapid_daggers = {
            id = "rapid_daggers",
            name = "Dagues de Vent",
            slot = "weapon",
            icon = "daggers",
            rarity = "uncommon",
            baseAtk = 11,
            fireRate = 0.16,
            speed = 340,
            desc = "Cadence supersonique idéale pour le kiting et le harcèlement continu.",
            passives = {
                uncommon  = { name = "Affûtage", desc = "Attaque de base augmentée de +25%." },
                rare      = { name = "Frénésie Céleste", desc = "+12% Vitesse d'Attaque globale." },
                epic      = { name = "Danse des Lames", desc = "Génère 1 salve de dagues en cône arrière." },
                legendary = { name = "Bourrasque Meurtrière", desc = "Chaque coup critique augmente la vitesse de 5%." },
            },
        },
        heavy_ballista = {
            id = "heavy_ballista",
            name = "Arbalète Lourde",
            slot = "weapon",
            icon = "ballista",
            rarity = "rare",
            baseAtk = 54,
            fireRate = 0.74,
            speed = 220,
            desc = "Décoche de lourds carreaux perforants écrasant les ennemis.",
            passives = {
                uncommon  = { name = "Tension d'Acier", desc = "Attaque de base augmentée de +25%." },
                rare      = { name = "Choc Sismique", desc = "Knockback doublé sur tous les monstres." },
                epic      = { name = "Perforation Pure", desc = "Les carreaux traversent tous les monstres alignés." },
                legendary = { name = "Titanicide", desc = "+35% de dégâts bruts contre les Boss." },
            },
        },
        saw_blade = {
            id = "saw_blade",
            name = "Lame Circulaire",
            slot = "weapon",
            icon = "saw",
            rarity = "epic",
            baseAtk = 24,
            fireRate = 0.22,
            speed = 320,
            desc = "Disque dentelé acéré fendant les airs avec une vélocité féroce.",
            passives = {
                uncommon  = { name = "Dentelure", desc = "Attaque de base augmentée de +25%." },
                rare      = { name = "Vitesse d'Entrée", desc = "+20% Vitesse d'Attaque les 5 premières secondes." },
                epic      = { name = "Effet Scie", desc = "Applique un saignement infligeant 10 dégâts/sec." },
                legendary = { name = "Disque Tranchant", desc = "Rebondit automatiquement sur 1 monstre adjacent." },
            },
        },
        death_scythe = {
            id = "death_scythe",
            name = "Faux de la Mort",
            slot = "weapon",
            icon = "scythe",
            rarity = "rare",
            baseAtk = 42,
            fireRate = 0.55,
            speed = 200,
            desc = "Lame faucheuse écrasante repoussant les monstres et exécutant les affaiblis (<30% PV).",
            passives = {
                uncommon  = { name = "Tranchant Sinistre", desc = "Attaque de base augmentée de +25%." },
                rare      = { name = "Impact Massif", desc = "Knockback décuplé repoussant même les créatures géantes." },
                epic      = { name = "Coup de Grâce", desc = "Exécute instantanément tout monstre sous 30% PV." },
                legendary = { name = "Faucheuse d'Âmes", desc = "Chaque élimination régénère +1.5% des PV Max." },
            },
        },
        stalker_staff = {
            id = "stalker_staff",
            name = "Bâton de Rôdeur",
            slot = "weapon",
            icon = "staff",
            rarity = "epic",
            baseAtk = 28,
            fireRate = 0.38,
            speed = 220,
            desc = "Sphères d'énergie téléguidées qui s'incurvent pour traquer les cibles isolées.",
            passives = {
                uncommon  = { name = "Concentration Magique", desc = "Attaque de base augmentée de +25%." },
                rare      = { name = "Guidage Arcanique", desc = "+30% de vélocité angulaire de suivi de cible." },
                epic      = { name = "Orbes Multiples", desc = "Les orbes traqueuses traversent 1 mur de décor." },
                legendary = { name = "Comète Céleste", desc = "Les orbes explosent à l'impact en infligeant des dégâts de zone." },
            },
        },
        tornado_boomerang = {
            id = "tornado_boomerang",
            name = "Tornade Boomerang",
            slot = "weapon",
            icon = "boomerang",
            rarity = "uncommon",
            baseAtk = 22,
            fireRate = 0.40,
            speed = 280,
            desc = "Lame tournoyante perforante qui revient vers le joueur avec un double impact.",
            passives = {
                uncommon  = { name = "Aérodynamisme", desc = "Attaque de base augmentée de +25%." },
                rare      = { name = "Double Impact", desc = "Inflige 65% de ses dégâts totaux lors de son retour." },
                epic      = { name = "Perforation Totale", desc = "Traverse tous les monstres alignés sans faiblir." },
                legendary = { name = "Typhon Tourbillonnant", desc = "Attire légèrement les ennemis vers son centre." },
            },
        },
        brightspear = {
            id = "brightspear",
            name = "Lance Brillante",
            slot = "weapon",
            icon = "spear",
            rarity = "epic",
            baseAtk = 36,
            fireRate = 0.48,
            speed = 1800,
            desc = "Rayon lumineux hitscan quasi-instantané frappant immédiatement dès l'arrêt.",
            passives = {
                uncommon  = { name = "Faisceau Focalisé", desc = "Attaque de base augmentée de +25%." },
                rare      = { name = "Éclair Instantané", desc = "Dégâts infligés sans aucun temps de trajet." },
                epic      = { name = "Rayon Transperçant", desc = "Le rayon traverse la première cible touchée." },
                legendary = { name = "Prisme Stellaire", desc = "Génère 2 rayons réfractés à 45° sur la première cible." },
            },
        },

        -- ====================================================================
        -- 2. ARMURES (Armors)
        -- ====================================================================
        vest_dexterity = {
            id = "vest_dexterity",
            name = "Gilet d'Agilité",
            slot = "armor",
            icon = "vest",
            rarity = "common",
            baseHp = 130,
            bonusDodge = 7,
            desc = "Gilet souple en cuir renforçant l'endurance et l'esquive naturelle.",
            passives = {
                uncommon  = { name = "Cuir Épais", desc = "Points de vie de base augmentés de +25%." },
                rare      = { name = "Pas Glissant", desc = "+7% Chances d'Esquive supplémentaires." },
                epic      = { name = "Éclair d'Agilité", desc = "Esquiver déclenche une décharge de foudre défensive." },
                legendary = { name = "Fantomatique", desc = "Quand les PV tombent sous 20%, gagne 30% d'esquive." },
            },
        },
        phantom_cloak = {
            id = "phantom_cloak",
            name = "Manteau Spectral",
            slot = "armor",
            icon = "cloak",
            rarity = "rare",
            baseHp = 210,
            bonusRes = 10,
            desc = "Tissu enchanté absorbant l'énergie des impacts cinétiques.",
            passives = {
                uncommon  = { name = "Maille Éthérée", desc = "Points de vie de base augmentés de +25%." },
                rare      = { name = "Résistance Magique", desc = "Réduit de 12% tous les dégâts de projectiles subis." },
                epic      = { name = "Gelée Vindicative", desc = "Touché au corps-à-corps gèle l'assaillant 1.5s." },
                legendary = { name = "Immatériel", desc = "Immunité aux dégâts pendant 1 seconde après un coup." },
            },
        },
        golden_chestplate = {
            id = "golden_chestplate",
            name = "Cuirasse Dorée",
            slot = "armor",
            icon = "golden_armor",
            rarity = "epic",
            baseHp = 290,
            bonusGold = 18,
            desc = "Harnois royal poli qui attire l'or et la fortune lors des expéditions.",
            passives = {
                uncommon  = { name = "Placage Royal", desc = "Points de vie de base augmentés de +25%." },
                rare      = { name = "Soif de Richesse", desc = "+20% d'Or ramassé en combat." },
                epic      = { name = "Aura Dorée", desc = "Chaque pièce d'or collectée soigne 2 PV." },
                legendary = { name = "Monarque Éternel", desc = "Augmente les dégâts de 1% par tranche de 100 or." },
            },
        },

        -- ====================================================================
        -- 3. ANNEAUX (Rings)
        -- ====================================================================
        wolf_ring = {
            id = "wolf_ring",
            name = "Anneau du Loup",
            slot = "ring",
            icon = "wolf_ring",
            rarity = "common",
            baseAtk = 8,
            bonusCrit = 6,
            desc = "Gravé d'une tête de loup hurlant, décuplant l'agressivité au tir.",
            passives = {
                uncommon  = { name = "Morsure", desc = "Attaque de base augmentée de +25%." },
                rare      = { name = "Sens Affûtés", desc = "+7% Chances de Coup Critique." },
                epic      = { name = "Férocité", desc = "+20% Dégâts contre les monstres terrestres (Slimes)." },
                legendary = { name = "Chef de Meute", desc = "Les coups critiques augmentent la vitesse d'attaque." },
            },
        },
        bear_ring = {
            id = "bear_ring",
            name = "Anneau de l'Ours",
            slot = "ring",
            icon = "bear_ring",
            rarity = "uncommon",
            baseHp = 110,
            bonusBoss = 12,
            desc = "Taillé dans de l'os robuste conférant la résilience d'un grizzli.",
            passives = {
                uncommon  = { name = "Vigueur Ursine", desc = "Points de vie augmentés de +25%." },
                rare      = { name = "Tueur de Monstres", desc = "+14% Dégâts contre les Boss et Mini-Boss." },
                epic      = { name = "Carapace", desc = "Réduit de 10% les dégâts de collision des monstres." },
                legendary = { name = "Rage Primale", desc = "+1% Dégâts par tranche de 5% de PV manquants." },
            },
        },
        serpent_ring = {
            id = "serpent_ring",
            name = "Anneau du Serpent",
            slot = "ring",
            icon = "serpent_ring",
            rarity = "rare",
            baseHp = 90,
            bonusDodge = 8,
            desc = "Bague ornée d'écailles émeraude pour se faufiler entre les projectiles.",
            passives = {
                uncommon  = { name = "Mue", desc = "Points de vie augmentés de +25%." },
                rare      = { name = "Esquive Ondoyante", desc = "+8% Chances d'Esquive." },
                epic      = { name = "Venin Paralysant", desc = "Toutes les flèches appliquent un poison léger." },
                legendary = { name = "Ouroboros", desc = "Esquiver une flèche restaure 5 PV instantanément." },
            },
        },
        falcon_ring = {
            id = "falcon_ring",
            name = "Anneau du Faucon",
            slot = "ring",
            icon = "falcon_ring",
            rarity = "epic",
            baseAtk = 14,
            baseHp = 60,
            desc = "Plume gravée dans le platine conférant une vue perçante sur le ciel.",
            passives = {
                uncommon  = { name = "Piqué", desc = "Attaque de base augmentée de +25%." },
                rare      = { name = "Chasse Aérienne", desc = "+20% Dégâts contre les volants (Chauves-souris)." },
                epic      = { name = "Vitesse d'Attaque", desc = "+10% Vitesse d'Attaque permanente." },
                legendary = { name = "Faucon Pèlerin", desc = "Les projectiles voyagent 25% plus vite." },
            },
        },

        -- ====================================================================
        -- 4. FAMILIERS (Pets)
        -- ====================================================================
        bat_companion = {
            id = "bat_companion",
            name = "Chauve-Souris",
            slot = "pet",
            icon = "bat_pet",
            rarity = "common",
            baseAtk = 14,
            desc = "Flotte à vos côtés et tire des lasers fins transperçant les murs.",
            passives = {
                uncommon  = { name = "Rayon Focale", desc = "Attaque de base augmentée de +25%." },
                rare      = { name = "Écholocalisation", desc = "Cadence de tir du familier augmentée de 15%." },
                epic      = { name = "Laser Spectral", desc = "Le tir du familier ignore totalement les rochers." },
                legendary = { name = "Symbiose Sombre", desc = "Confère +10 ATQ au héros en permanence." },
            },
        },
        ghost_familiar = {
            id = "ghost_familiar",
            name = "Spectre Éthéré",
            slot = "pet",
            icon = "ghost_pet",
            rarity = "uncommon",
            baseAtk = 20,
            desc = "Petite ombre projetant des orbes spectraux rebondissants.",
            passives = {
                uncommon  = { name = "Éctoplasme", desc = "Attaque de base augmentée de +25%." },
                rare      = { name = "Orbe Hanté", desc = "Les tirs du familier ont 15% de chances de geler." },
                epic      = { name = "Ricochet Spectral", desc = "L'orbe spectral rebondit sur 2 ennemis." },
                legendary = { name = "Lien Éthéré", desc = "+10% Chances de Critique pour le héros." },
            },
        },
        dragon_pet = {
            id = "dragon_pet",
            name = "Dragonnet Magma",
            slot = "pet",
            icon = "dragon_pet",
            rarity = "rare",
            baseAtk = 28,
            desc = "Crache des boules de feu causant des explosions de zone.",
            passives = {
                uncommon  = { name = "Souffle Incandescent", desc = "Attaque de base augmentée de +25%." },
                rare      = { name = "Brasier", desc = "Explosion de zone plus large et brûlure 2s." },
                epic      = { name = "Double Flamme", desc = "Tire 2 boules de feu explosives simultanément." },
                legendary = { name = "Cœur du Volcan", desc = "Augmente de 15% tous les dégâts de feu du héros." },
            },
        },
    }
}

-- ============================================================================
-- TABLES DE BUTIN : la rareté détermine la difficulté d'obtention
-- ============================================================================
-- Poids relatifs de chaque rareté. Le coffre doré (or) donne surtout du commun,
-- le coffre d'obsidienne (gemmes) vise le rare et au-delà, et les boss laissent
-- tomber un butin intermédiaire.
Items.DROP_TABLES = {
    gold     = { common = 58, uncommon = 27, rare = 11, epic = 3.2, legendary = 0.8 },
    obsidian = { common = 14, uncommon = 28, rare = 33, epic = 19,  legendary = 6 },
    boss     = { common = 35, uncommon = 32, rare = 22, epic = 9,   legendary = 2 },
}

local RARITY_ORDER = { "common", "uncommon", "rare", "epic", "legendary" }

-- Tire un objet au hasard : la rareté est choisie selon les poids de la table,
-- puis un objet de cette rareté est sélectionné uniformément.
-- `slotFilter` (optionnel) limite le tirage à un emplacement ("weapon", "armor", ...).
-- `maxRarity` (optionnel) plafonne le tirage : une rareté non débloquée par la
-- progression ne peut pas sortir, même avec de la chance.
function Items.rollDrop(tableName, slotFilter, maxRarity)
    local weights = Items.DROP_TABLES[tableName] or Items.DROP_TABLES.gold
    local ceiling = Balance.rarityRank(maxRarity or "legendary")

    local byRarity, total = {}, 0
    for _, id in ipairs(Items.getSortedIds()) do
        local item = Items.CATALOGUE[id]
        local rarity = item.rarity or "common"
        if (not slotFilter or item.slot == slotFilter)
            and (weights[rarity] or 0) > 0
            and Balance.rarityRank(rarity) <= ceiling then
            if not byRarity[rarity] then
                byRarity[rarity] = {}
                total = total + weights[rarity]
            end
            table.insert(byRarity[rarity], id)
        end
    end
    if total <= 0 then return "starter_bow" end

    local roll, acc = math.random() * total, 0
    for _, rarity in ipairs(RARITY_ORDER) do
        local pool = byRarity[rarity]
        if pool then
            acc = acc + weights[rarity]
            if roll <= acc then
                return pool[math.random(1, #pool)]
            end
        end
    end

    for _, rarity in ipairs(RARITY_ORDER) do
        if byRarity[rarity] then return byRarity[rarity][1] end
    end
    return "starter_bow"
end

-- Probabilité (0..1) d'obtenir une rareté donnée dans une table de butin
function Items.dropChance(tableName, rarity)
    local weights = Items.DROP_TABLES[tableName] or Items.DROP_TABLES.gold
    local total = 0
    for _, w in pairs(weights) do total = total + w end
    if total <= 0 then return 0 end
    return (weights[rarity] or 0) / total
end

-- Liste stable des identifiants du catalogue (pairs() n'a pas d'ordre garanti)
function Items.getSortedIds()
    if Items._sortedIds then return Items._sortedIds end
    local ids = {}
    for id in pairs(Items.CATALOGUE) do ids[#ids + 1] = id end
    table.sort(ids)
    Items._sortedIds = ids
    return ids
end

function Items.get(id)
    return Items.CATALOGUE[id]
end

function Items.getRarityData(rarity)
    return Items.RARITIES[rarity] or Items.RARITIES.common
end

-- Calcule les statistiques complètes selon l'id, le niveau et la rareté
-- ============================================================================
-- ENSEMBLES D'ÉQUIPEMENT (bonus à 2 et 4 pièces)
-- ============================================================================
Items.SETS = {
    ranger = {
        name = "Tenue du Rôdeur",
        pieces = { "starter_bow", "vest_dexterity", "wolf_ring", "bat_companion" },
        bonus2 = { desc = "+8% vitesse de tir", apply = function(p) p.attackSpeedMult = (p.attackSpeedMult or 1) * 1.08 end },
        bonus4 = { desc = "+12% dégâts et +5% esquive", apply = function(p)
            p.damageMult = (p.damageMult or 1) * 1.12
            p.dodgeChance = (p.dodgeChance or 0) + 0.05
        end },
    },
    shadow = {
        name = "Parure d'Ombre",
        pieces = { "rapid_daggers", "phantom_cloak", "serpent_ring", "ghost_familiar" },
        bonus2 = { desc = "+6% esquive", apply = function(p) p.dodgeChance = (p.dodgeChance or 0) + 0.06 end },
        bonus4 = { desc = "+15% critique et poison sur les tirs", apply = function(p)
            p.critChance = (p.critChance or 0) + 0.15
            p.elements = p.elements or {}
            p.elements.poison = true
        end },
    },
    titan = {
        name = "Armure du Titan",
        pieces = { "heavy_ballista", "golden_chestplate", "bear_ring", "dragon_pet" },
        bonus2 = { desc = "+150 PV max", apply = function(p)
            p.maxHp = p.maxHp + 150
            p.hp = p.maxHp
        end },
        bonus4 = { desc = "+20% dégâts aux boss et recul renforcé", apply = function(p)
            p.bossDamageMult = (p.bossDamageMult or 1) * 1.20
            p.knockbackMult = (p.knockbackMult or 1) * 1.5
        end },
    },
}

-- Renvoie la liste des ensembles actifs : { { set, count, bonus2, bonus4 } }
function Items.getActiveSets(equipped)
    local result = {}
    if not equipped then return result end
    local worn = {}
    for _, id in pairs(equipped) do worn[id] = true end

    for setId, set in pairs(Items.SETS) do
        local count = 0
        for _, pieceId in ipairs(set.pieces) do
            if worn[pieceId] then count = count + 1 end
        end
        if count >= 2 then
            result[#result + 1] = { id = setId, set = set, count = count }
        end
    end
    return result
end

-- Applique les bonus d'ensemble au joueur
function Items.applySetBonuses(player, equipped)
    local active = Items.getActiveSets(equipped)
    player.activeSets = active
    for _, entry in ipairs(active) do
        if entry.count >= 2 and entry.set.bonus2 then entry.set.bonus2.apply(player) end
        if entry.count >= 4 and entry.set.bonus4 then entry.set.bonus4.apply(player) end
    end
    return active
end

function Items.getStats(id, level, rarityOverride, stars)
    local item = Items.get(id)
    if not item then
        return { atk = 0, hp = 0, dodge = 0, crit = 0, level = 1, rarity = "common" }
    end

    level = level or 1
    local curRarity = rarityOverride or item.rarity or "common"
    local rData = Items.getRarityData(curRarity)

    -- Facteur de niveau et de rareté
    local levelScale = 1.0 + (level - 1) * 0.16
    local starScale = 1.0 + (stars or 0) * 0.06
    local totalScale = levelScale * rData.statMult * starScale

    local stats = {
        level = level,
        rarity = curRarity,
        atk = item.baseAtk and math.floor(item.baseAtk * totalScale) or 0,
        hp = item.baseHp and math.floor(item.baseHp * totalScale) or 0,
        dodge = (item.bonusDodge or 0) + ((rData.tier >= 3 and item.passives and item.passives.rare and string.find(item.passives.rare.desc, "Esquive")) and 7 or 0),
        crit = (item.bonusCrit or 0) + ((rData.tier >= 3 and item.passives and item.passives.rare and string.find(item.passives.rare.desc, "Critique")) and 8 or 0),
        bossDmg = item.bonusBoss or 0,
        goldBonus = item.bonusGold or 0,
        fireRate = item.fireRate or 0.3,
        speed = item.speed or 260,
    }

    return stats
end

-- Coût d'amélioration dynamique selon le niveau et la rareté
function Items.getUpgradeCost(level, rarity)
    local rData = Items.getRarityData(rarity)
    return Balance.upgradeCost(level, rData.tier)
end

function Items.getAll()
    local list = {}
    for _, item in pairs(Items.CATALOGUE) do
        table.insert(list, item)
    end
    table.sort(list, function(a, b)
        local ta = Items.getRarityData(a.rarity).tier
        local tb = Items.getRarityData(b.rarity).tier
        if ta ~= tb then return ta > tb end
        return a.name < b.name
    end)
    return list
end

return Items
