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
            name = "COMMON",
            tier = 1,
            color = {0.75, 0.78, 0.85},     -- Silver grey
            bg = {0.14, 0.16, 0.20},
            border = {0.55, 0.60, 0.70},
            highlight = {0.85, 0.88, 0.95},
            statMult = 1.0,
            tag = "BASE",
        },
        uncommon = {
            id = "uncommon",
            name = "GREAT",
            tier = 2,
            color = {0.25, 0.85, 0.45},     -- Emerald green
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
            color = {0.25, 0.68, 1.00},     -- Sapphire blue
            bg = {0.08, 0.18, 0.32},
            border = {0.20, 0.55, 0.90},
            highlight = {0.60, 0.88, 1.00},
            statMult = 1.55,
            tag = "PASSIVE 1",
        },
        epic = {
            id = "epic",
            name = "EPIC",
            tier = 4,
            color = {0.80, 0.30, 0.98},     -- Amethyst violet
            bg = {0.24, 0.10, 0.30},
            border = {0.70, 0.22, 0.88},
            highlight = {0.95, 0.60, 1.00},
            statMult = 1.95,
            tag = "GAMEPLAY",
        },
        legendary = {
            id = "legendary",
            name = "LEGENDARY",
            tier = 5,
            color = {1.00, 0.82, 0.18},     -- Gleaming solar gold
            bg = {0.30, 0.24, 0.08},
            border = {0.95, 0.72, 0.10},
            highlight = {1.00, 0.96, 0.65},
            statMult = 2.45,
            tag = "ULTIMATE",
        },
    },

    CATALOGUE = {
        -- ====================================================================
        -- 1. ARMES (Weapons)
        -- ====================================================================
        starter_bow = {
            id = "starter_bow",
            name = "Brave's Bow",
            slot = "weapon",
            icon = "bow",
            rarity = "common",
            baseAtk = 18,
            fireRate = 0.34,
            speed = 280,
            desc = "Balanced weapon offering steady rate of fire and stable trajectories.",
            passives = {
                uncommon  = { name = "Raw Power", desc = "Base Attack increased by +25%." },
                rare      = { name = "Eagle Eye", desc = "+10% Critical Hit Chance." },
                epic      = { name = "Fractal Arrows", desc = "Fires +1 Diagonal Arrow without damage penalty." },
                legendary = { name = "Solar Judgment", desc = "Arrows pierce 1 obstacle and deal +50% Crit." },
            },
        },
        rapid_daggers = {
            id = "rapid_daggers",
            name = "Wind Daggers",
            slot = "weapon",
            icon = "daggers",
            rarity = "uncommon",
            baseAtk = 11,
            fireRate = 0.16,
            speed = 340,
            desc = "Supersonic fire rate ideal for kiting and continuous harassment.",
            passives = {
                uncommon  = { name = "Sharpened", desc = "Base Attack increased by +25%." },
                rare      = { name = "Celestial Frenzy", desc = "+12% Global Attack Speed." },
                epic      = { name = "Blade Dance", desc = "Unleashes a rear cone volley of daggers." },
                legendary = { name = "Lethal Gale", desc = "Each critical hit increases speed by 5%." },
            },
        },
        heavy_ballista = {
            id = "heavy_ballista",
            name = "Heavy Ballista",
            slot = "weapon",
            icon = "ballista",
            rarity = "rare",
            baseAtk = 54,
            fireRate = 0.74,
            speed = 220,
            desc = "Launches massive piercing bolts crushing through enemies.",
            passives = {
                uncommon  = { name = "Steel Tension", desc = "Base Attack increased by +25%." },
                rare      = { name = "Seismic Shock", desc = "Doubled knockback against all monsters." },
                epic      = { name = "Pure Piercing", desc = "Bolts penetrate all lined-up monsters." },
                legendary = { name = "Titan's Bane", desc = "+35% raw damage against Bosses." },
            },
        },
        saw_blade = {
            id = "saw_blade",
            name = "Saw Blade",
            slot = "weapon",
            icon = "saw",
            rarity = "epic",
            baseAtk = 24,
            fireRate = 0.22,
            speed = 320,
            desc = "Serrated blade cleaving through the air with ferocious velocity.",
            passives = {
                uncommon  = { name = "Serration", desc = "Base Attack increased by +25%." },
                rare      = { name = "Entry Rush", desc = "+20% Attack Speed for the first 5 seconds of a room." },
                epic      = { name = "Saw Tooth", desc = "Applies bleed dealing 10 damage/sec." },
                legendary = { name = "Razor Disc", desc = "Automatically bounces toward 1 adjacent monster." },
            },
        },
        death_scythe = {
            id = "death_scythe",
            name = "Death Scythe",
            slot = "weapon",
            icon = "scythe",
            rarity = "rare",
            baseAtk = 42,
            fireRate = 0.55,
            speed = 200,
            desc = "Crushing reaping blade knocking monsters back and executing weakened foes (<30% HP).",
            passives = {
                uncommon  = { name = "Sinister Edge", desc = "Base Attack increased by +25%." },
                rare      = { name = "Massive Impact", desc = "Decupled knockback pushing back even giant beasts." },
                epic      = { name = "Coup de Grace", desc = "Instantly executes any monster below 30% HP." },
                legendary = { name = "Soul Reaper", desc = "Each kill restores +1.5% Max HP." },
            },
        },
        stalker_staff = {
            id = "stalker_staff",
            name = "Stalker Staff",
            slot = "weapon",
            icon = "staff",
            rarity = "epic",
            baseAtk = 28,
            fireRate = 0.38,
            speed = 220,
            desc = "Homing energy orbs curving through the air to track isolated targets.",
            passives = {
                uncommon  = { name = "Magic Focus", desc = "Base Attack increased by +25%." },
                rare      = { name = "Arcane Guidance", desc = "+30% target-tracking angular velocity." },
                epic      = { name = "Multiple Orbs", desc = "Tracking orbs pass through 1 arena obstacle." },
                legendary = { name = "Celestial Comet", desc = "Orbs detonate upon impact, dealing area damage." },
            },
        },
        tornado_boomerang = {
            id = "tornado_boomerang",
            name = "Tornado Boomerang",
            slot = "weapon",
            icon = "boomerang",
            rarity = "uncommon",
            baseAtk = 22,
            fireRate = 0.40,
            speed = 280,
            desc = "Piercing spinning blade that returns to player dealing double damage.",
            passives = {
                uncommon  = { name = "Aerodynamic", desc = "Base Attack increased by +25%." },
                rare      = { name = "Double Impact", desc = "Deals 50% of total damage on return flight." },
                epic      = { name = "Total Pierce", desc = "Pierces through all lined-up monsters without slowing down." },
                legendary = { name = "Swirling Typhoon", desc = "Lightly pulls enemies toward its center." },
            },
        },
        brightspear = {
            id = "brightspear",
            name = "Brightspear",
            slot = "weapon",
            icon = "spear",
            rarity = "epic",
            baseAtk = 36,
            fireRate = 0.48,
            speed = 1800,
            desc = "Near-instantaneous hitscan beam striking immediately upon standing still.",
            passives = {
                uncommon  = { name = "Focused Beam", desc = "Base Attack increased by +25%." },
                rare      = { name = "Instant Bolt", desc = "Deals damage with zero travel time." },
                epic      = { name = "Piercing Ray", desc = "Beam pierces through the first target struck." },
                legendary = { name = "Starlight Prism", desc = "Refracts 2 additional beams at 45 degrees upon hit." },
            },
        },

        -- ====================================================================
        -- 2. ARMORS
        -- ====================================================================
        vest_dexterity = {
            id = "vest_dexterity",
            name = "Vest of Dexterity",
            slot = "armor",
            icon = "vest",
            rarity = "common",
            baseHp = 130,
            bonusDodge = 7,
            desc = "Supple leather vest boosting endurance and natural evasion.",
            passives = {
                uncommon  = { name = "Thick Leather", desc = "Base HP increased by +25%." },
                rare      = { name = "Slippery Step", desc = "+7% Additional Dodge Chance." },
                epic      = { name = "Lightning Agility", desc = "Dodging an attack triggers defensive chain lightning." },
                legendary = { name = "Phantom Drift", desc = "When HP falls below 20%, gain 30% dodge." },
            },
        },
        phantom_cloak = {
            id = "phantom_cloak",
            name = "Phantom Cloak",
            slot = "armor",
            icon = "cloak",
            rarity = "rare",
            baseHp = 210,
            bonusRes = 10,
            desc = "Enchanted fabric absorbing kinetic impact energy.",
            passives = {
                uncommon  = { name = "Ethereal Mesh", desc = "Base HP increased by +25%." },
                rare      = { name = "Magic Resistance", desc = "Reduces all incoming projectile damage by 12%." },
                epic      = { name = "Vindictive Frost", desc = "Taking melee hits freezes the attacker for 1.5s." },
                legendary = { name = "Incorporeal", desc = "Damage immunity for 1 second after taking damage." },
            },
        },
        golden_chestplate = {
            id = "golden_chestplate",
            name = "Golden Chestplate",
            slot = "armor",
            icon = "golden_armor",
            rarity = "epic",
            baseHp = 290,
            bonusGold = 18,
            desc = "Polished royal harness attracting wealth and fortune during expeditions.",
            passives = {
                uncommon  = { name = "Royal Plating", desc = "Base HP increased by +25%." },
                rare      = { name = "Thirst for Gold", desc = "+20% Gold collected in combat." },
                epic      = { name = "Golden Aura", desc = "Each gold coin collected restores 2 HP." },
                legendary = { name = "Eternal Monarch", desc = "Increases damage by 1% per 100 gold held." },
            },
        },

        -- ====================================================================
        -- 3. RINGS
        -- ====================================================================
        wolf_ring = {
            id = "wolf_ring",
            name = "Wolf Ring",
            slot = "ring",
            icon = "wolf_ring",
            rarity = "common",
            baseAtk = 8,
            bonusCrit = 6,
            desc = "Engraved with a howling wolf, increasing aggressive ranged attacks.",
            passives = {
                uncommon  = { name = "Bite", desc = "Base Attack increased by +25%." },
                rare      = { name = "Keen Senses", desc = "+7% Critical Hit Chance." },
                epic      = { name = "Ferocity", desc = "+20% Damage against ground monsters (Slimes)." },
                legendary = { name = "Pack Leader", desc = "Critical hits boost attack speed." },
            },
        },
        bear_ring = {
            id = "bear_ring",
            name = "Bear Ring",
            slot = "ring",
            icon = "bear_ring",
            rarity = "uncommon",
            baseHp = 110,
            bonusBoss = 12,
            desc = "Carved from sturdy bone granting the resilience of a grizzly.",
            passives = {
                uncommon  = { name = "Ursine Vigor", desc = "Base HP increased by +25%." },
                rare      = { name = "Monster Slayer", desc = "+14% Damage against Bosses and Mini-Bosses." },
                epic      = { name = "Carapace", desc = "Reduces monster collision damage by 10%." },
                legendary = { name = "Primal Rage", desc = "+1% Damage per 5% missing HP." },
            },
        },
        serpent_ring = {
            id = "serpent_ring",
            name = "Serpent Ring",
            slot = "ring",
            icon = "serpent_ring",
            rarity = "rare",
            baseHp = 90,
            bonusDodge = 8,
            desc = "Adorned with emerald scales to weave through projectiles.",
            passives = {
                uncommon  = { name = "Shedding", desc = "Base HP increased by +25%." },
                rare      = { name = "Undulating Evasion", desc = "+8% Dodge Chance." },
                epic      = { name = "Paralyzing Venom", desc = "All arrows apply minor poison." },
                legendary = { name = "Ouroboros", desc = "Dodging an attack instantly restores 5 HP." },
            },
        },
        falcon_ring = {
            id = "falcon_ring",
            name = "Falcon Ring",
            slot = "ring",
            icon = "falcon_ring",
            rarity = "epic",
            baseAtk = 14,
            baseHp = 60,
            desc = "Feather etched into platinum granting keen vision over the battlefield.",
            passives = {
                uncommon  = { name = "Dive", desc = "Base Attack increased by +25%." },
                rare      = { name = "Aerial Hunt", desc = "+20% Damage against flying monsters (Bats)." },
                epic      = { name = "Attack Speed", desc = "+10% Permanent Attack Speed." },
                legendary = { name = "Peregrine Falcon", desc = "Projectiles travel 25% faster." },
            },
        },

        -- ====================================================================
        -- 4. PETS
        -- ====================================================================
        bat_companion = {
            id = "bat_companion",
            name = "Laser Bat",
            slot = "pet",
            icon = "bat_pet",
            rarity = "common",
            baseAtk = 14,
            desc = "Hovers by your side and fires thin lasers piercing through walls.",
            passives = {
                uncommon  = { name = "Focal Beam", desc = "Base Attack increased by +25%." },
                rare      = { name = "Echolocation", desc = "Pet attack speed increased by 15%." },
                epic      = { name = "Spectral Laser", desc = "Pet shots completely ignore walls." },
                legendary = { name = "Dark Symbiosis", desc = "Permanently grants +10 ATK to the hero." },
            },
        },
        ghost_familiar = {
            id = "ghost_familiar",
            name = "Spectral Mage",
            slot = "pet",
            icon = "ghost_pet",
            rarity = "uncommon",
            baseAtk = 20,
            desc = "Small shade casting bouncing spectral orbs.",
            passives = {
                uncommon  = { name = "Ectoplasm", desc = "Base Attack increased by +25%." },
                rare      = { name = "Haunted Orb", desc = "Pet shots have a 15% chance to freeze." },
                epic      = { name = "Spectral Ricochet", desc = "Spectral orb bounces off 2 enemies." },
                legendary = { name = "Ethereal Bond", desc = "+10% Critical Chance for the hero." },
            },
        },
        dragon_pet = {
            id = "dragon_pet",
            name = "Magma Dragon",
            slot = "pet",
            icon = "dragon_pet",
            rarity = "rare",
            baseAtk = 28,
            desc = "Spits fireballs causing area-of-effect explosions.",
            passives = {
                uncommon  = { name = "Incandescent Breath", desc = "Base Attack increased by +25%." },
                rare      = { name = "Blaze", desc = "Larger explosion radius and 2s burn." },
                epic      = { name = "Twin Flame", desc = "Fires 2 explosive fireballs simultaneously." },
                legendary = { name = "Heart of the Volcano", desc = "Increases all fire damage by +15%." },
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
-- `rng` (optional): function returning a number in [0, 1), math.random by default
function Items.rollDrop(tableName, slotFilter, maxRarity, rng)
    rng = rng or math.random
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

    local roll, acc = rng() * total, 0
    for _, rarity in ipairs(RARITY_ORDER) do
        local pool = byRarity[rarity]
        if pool then
            acc = acc + weights[rarity]
            if roll <= acc then
                return pool[math.floor(rng() * #pool) + 1]
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
-- ============================================================================
-- GEAR SETS (2 and 4 piece bonuses)
-- ============================================================================
Items.SETS = {
    ranger = {
        name = "Ranger Attire",
        pieces = { "starter_bow", "vest_dexterity", "wolf_ring", "bat_companion" },
        bonus2 = { desc = "+8% attack speed", apply = function(p) p.attackSpeedMult = (p.attackSpeedMult or 1) * 1.08 end },
        bonus4 = { desc = "+12% damage and +5% dodge", apply = function(p)
            p.damageMult = (p.damageMult or 1) * 1.12
            p.dodgeChance = (p.dodgeChance or 0) + 0.05
        end },
    },
    shadow = {
        name = "Shadow Garb",
        pieces = { "rapid_daggers", "phantom_cloak", "serpent_ring", "ghost_familiar" },
        bonus2 = { desc = "+6% dodge", apply = function(p) p.dodgeChance = (p.dodgeChance or 0) + 0.06 end },
        bonus4 = { desc = "+15% crit chance and poison shots", apply = function(p)
            p.critChance = (p.critChance or 0) + 0.15
            p.elements = p.elements or {}
            p.elements.poison = true
        end },
    },
    titan = {
        name = "Titan Plate",
        pieces = { "heavy_ballista", "golden_chestplate", "bear_ring", "dragon_pet" },
        bonus2 = { desc = "+150 max HP", apply = function(p)
            p.maxHp = p.maxHp + 150
            p.hp = p.maxHp
        end },
        bonus4 = { desc = "+20% damage to bosses and bonus knockback", apply = function(p)
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

-- Stat growth: +16% per level, +6% per star, times the rarity multiplier
local LEVEL_STEP = 0.16
local STAR_STEP = 0.06

local function statScale(level, rData, stars)
    return (1.0 + ((level or 1) - 1) * LEVEL_STEP) * rData.statMult * (1.0 + (stars or 0) * STAR_STEP)
end

-- Item power relative to its starting copy (level 1, original rarity, no star): 1.0 at
-- first. Used where the combat effect is not a raw stat (weapon damage, pet shots), so
-- Forge upgrades still matter.
function Items.powerRatio(id, level, rarityOverride, stars)
    local item = Items.get(id)
    if not item then return 1.0 end
    local base = Items.getRarityData(item.rarity or "common")
    local cur = Items.getRarityData(rarityOverride or item.rarity or "common")
    return statScale(level, cur, stars) / statScale(1, base, 0)
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
    local totalScale = statScale(level, rData, stars)

    -- Rare passive "+N% Dodge" / "+N% Critical": the description sets the bonus
    local rareDesc = rData.tier >= 3 and item.passives and item.passives.rare and item.passives.rare.desc or ""
    local rarePct = tonumber(rareDesc:match("%+(%d+)%%")) or 0
    local rareDodge = rareDesc:find("Dodge") and rarePct or 0
    local rareCrit = rareDesc:find("Crit") and rarePct or 0

    local stats = {
        level = level,
        rarity = curRarity,
        atk = item.baseAtk and math.floor(item.baseAtk * totalScale) or 0,
        hp = item.baseHp and math.floor(item.baseHp * totalScale) or 0,
        dodge = (item.bonusDodge or 0) + rareDodge,
        crit = (item.bonusCrit or 0) + rareCrit,
        bossDmg = item.bonusBoss or 0,
        goldBonus = item.bonusGold or 0,
        fireRate = item.fireRate or 0.3,
        speed = item.speed or 260,
    }

    return stats
end

-- Item bonuses that only matter in combat: boss damage (Bear Ring) and gold collected
-- (Golden Chestplate), in percent in the item stats
function Items.applyCombatBonuses(player, stats)
    if (stats.bossDmg or 0) > 0 then
        player.bossDamageMult = (player.bossDamageMult or 1) + stats.bossDmg / 100
    end
    if (stats.goldBonus or 0) > 0 then
        player.goldMultiplier = (player.goldMultiplier or 1) + stats.goldBonus / 100
    end
end

-- Upgrade cost from the level and the rarity
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
