-- src/data/bestiary.lua
-- Galerie des monstres : fiches, compteurs d'éliminations et bonus de maîtrise.
-- Vaincre 50 / 200 / 500 exemplaires d'un monstre donne un bonus de dégâts permanent contre lui.

local Bestiary = {}

Bestiary.ENTRIES = {
    { type = "slime",      name = "Slime",            family = "Jelly",     attack = "Bouncing contact", weakness = "Fire",      desc = "Relentlessly hops toward the hero. Harmless alone, lethal in hordes." },
    { type = "bat",        name = "Bat",              family = "Flying",    attack = "Fast dive",        weakness = "Ice",       desc = "Flies over water and traps, charging straight ahead after hovering." },
    { type = "wolf",       name = "Stalker Wolf",     family = "Beast",     attack = "Lunge",            weakness = "Poison",    desc = "Circles around before lunging. Its charge is telegraphed." },
    { type = "skeleton",   name = "Skeleton Archer",  family = "Undead",    attack = "Aimed shot",       weakness = "Lightning", desc = "Targets the hero with a red laser sight before firing. Take cover!" },
    { type = "plant",      name = "Spitter Plant",    family = "Flora",     attack = "Ranged spores",    weakness = "Fire",      desc = "Stationary but spits toxic spores across the arena." },
    { type = "bomber",     name = "Bombardier",       family = "Specter",   attack = "Lobbed bomb",      weakness = "Lightning", desc = "Hovers and lobs arced bombs: a ground circle marks the impact point." },
    { type = "burrower",   name = "Burrowing Worm",   family = "Insect",    attack = "Ambush",           weakness = "Ice",       desc = "Invulnerable underground, pops up to spit corrosive acid." },
    { type = "splitter",   name = "Scarlet Slime",    family = "Jelly",     attack = "Heavy contact",    weakness = "Fire",      desc = "Splits into two mini slimes upon defeat." },
    { type = "mini_slime", name = "Mini Slime",       family = "Jelly",     attack = "Quick contact",    weakness = "Fire",      desc = "Small, agile and aggressive: born from a scarlet slime's split." },
    { type = "summoner",   name = "Summoner",         family = "Specter",   attack = "Reinforcements",   weakness = "Lightning", desc = "Stays back and summons mini slimes. High priority target." },
    { type = "turret",     name = "Stone Turret",     family = "Construct", attack = "Cross volley",     weakness = "Poison",    desc = "Stationary construct firing cross and diagonal barrages." },
    { type = "mage",       name = "Teleporting Mage", family = "Sorcerer",  attack = "Arcane orb",       weakness = "Fire",      desc = "Blinks across the arena before hurling energy orbs." },
    { type = "skeleton_king", name = "Skeleton King", family = "Boss",      attack = "Arrow volley",     weakness = "Fire",      desc = "Desert boss. When enraged, fires 5 arrows and calls for guards." },
    { type = "witch",      name = "Crystal Witch",    family = "Boss",      attack = "Orb barrage",      weakness = "Poison",    desc = "Cavern boss. Teleports and summons swarms of bats." },
    { type = "lava_titan", name = "Lava Titan",       family = "Boss",      attack = "Molten barrage",   weakness = "Ice",       desc = "Inferno boss. Its molten carapace expels stones in star patterns." },
    { type = "raven",      name = "Peak Raptor",      family = "Flying",    attack = "Lightning dive",   weakness = "Lightning", desc = "Dives onto the hero from the clouds. Fragile but lightning fast." },
    { type = "wisp",       name = "Will-o'-the-Wisp", family = "Spirit",    attack = "Floating orb",     weakness = "Ice",       desc = "Floats over chasms casting radiant glowing orbs." },
    { type = "gargoyle",   name = "Gargoyle",         family = "Construct", attack = "Stone tackle",     weakness = "Poison",    desc = "Animated stone statue from the Skyward Isles: slow and heavily armored." },
    { type = "frost_wraith", name = "Frost Wraith",   family = "Undead",    attack = "Frost shard",      weakness = "Fire",      desc = "Teleports through the Void City, freezing everything in its path." },
    { type = "storm_drake", name = "Storm Drake",     family = "Boss",      attack = "Electric breath",  weakness = "Ice",       desc = "Skyward Isles boss. When enraged, calls down continuous lightning." },
    { type = "void_watcher", name = "Void Watcher",   family = "Boss",      attack = "Orb barrage",      weakness = "Fire",      desc = "Final boss. Its otherworldly gaze distorts space and summons wraiths." },
    { type = "golem",      name = "Granite Golem",    family = "Boss",      attack = "Boulder volley",   weakness = "Poison",    desc = "Threshold boss. Below 50% HP enters an enraged frenzy: faster and denser." },
}

-- Paliers de maîtrise : éliminations -> bonus de dégâts contre ce monstre
Bestiary.THRESHOLDS = {
    { kills = 50,  bonus = 0.03 },
    { kills = 200, bonus = 0.06 },
    { kills = 500, bonus = 0.10 },
}

function Bestiary.entry(monsterType)
    for _, e in ipairs(Bestiary.ENTRIES) do
        if e.type == monsterType then return e end
    end
    return nil
end

-- Bonus cumulé (0.0 à 0.19) pour un nombre d'éliminations donné
function Bestiary.bonusFor(kills)
    local bonus = 0
    for _, tier in ipairs(Bestiary.THRESHOLDS) do
        if (kills or 0) >= tier.kills then bonus = bonus + tier.bonus end
    end
    return bonus
end

-- Prochain palier à atteindre (nil si tous atteints)
function Bestiary.nextTier(kills)
    for _, tier in ipairs(Bestiary.THRESHOLDS) do
        if (kills or 0) < tier.kills then return tier end
    end
    return nil
end

-- Table multiplicatrice prête à l'emploi pour le combat : { [type] = 1.0 + bonus }
function Bestiary.buildMasteryTable(counters)
    local t = {}
    for _, e in ipairs(Bestiary.ENTRIES) do
        t[e.type] = 1.0 + Bestiary.bonusFor(counters and counters[e.type] or 0)
    end
    return t
end

-- Nom affiché d'un type de monstre (repli : le type lui-même)
local namesByType = nil
function Bestiary.nameOf(monsterType)
    if not namesByType then
        namesByType = {}
        for _, e in ipairs(Bestiary.ENTRIES) do namesByType[e.type] = e.name end
    end
    return namesByType[monsterType] or tostring(monsterType or "?")
end

return Bestiary
