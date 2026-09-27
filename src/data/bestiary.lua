-- src/data/bestiary.lua
-- Galerie des monstres : fiches, compteurs d'éliminations et bonus de maîtrise.
-- Vaincre 50 / 200 / 500 exemplaires d'un monstre donne un bonus de dégâts permanent contre lui.

local Bestiary = {}

Bestiary.ENTRIES = {
    { type = "slime",      name = "Slime",            family = "Gelée",    attack = "Contact bondissant", weakness = "Feu",     desc = "Rebondit vers le héros sans relâche. Inoffensif seul, mortel en nombre." },
    { type = "bat",        name = "Chauve-souris",    family = "Volant",   attack = "Piqué rapide",       weakness = "Glace",   desc = "Survole l'eau et les pièges, fonce en ligne droite après un temps d'arrêt." },
    { type = "wolf",       name = "Loup Traqueur",    family = "Bête",     attack = "Charge",             weakness = "Poison",  desc = "Rôde en cercle puis charge d'un coup. Sa ruée est télégraphiée." },
    { type = "skeleton",   name = "Squelette Archer", family = "Mort-vivant", attack = "Tir visé",        weakness = "Foudre",  desc = "Vise le héros avec un laser rouge avant de tirer. À couvert !" },
    { type = "plant",      name = "Plante Cracheuse", family = "Végétal",  attack = "Spores à distance",  weakness = "Feu",     desc = "Immobile mais crache des spores toxiques à travers l'arène." },
    { type = "bomber",     name = "Bombardier",       family = "Spectre",  attack = "Bombe lobée",        weakness = "Foudre",  desc = "Lévite et lance des bombes en cloche : le cercle au sol marque l'impact." },
    { type = "burrower",   name = "Ver Fouisseur",    family = "Insecte",  attack = "Embuscade",          weakness = "Glace",   desc = "Invulnérable sous terre, il jaillit pour cracher de l'acide." },
    { type = "splitter",   name = "Slime Écarlate",   family = "Gelée",    attack = "Contact massif",     weakness = "Feu",     desc = "Se divise en deux petits slimes orange à sa mort." },
    { type = "mini_slime", name = "Mini Slime",       family = "Gelée",    attack = "Contact rapide",     weakness = "Feu",     desc = "Petit, vif et agressif : né de la division d'un slime écarlate." },
    { type = "summoner",   name = "Invocateur",       family = "Spectre",  attack = "Renforts",           weakness = "Foudre",  desc = "Reste à distance et appelle des mini-slimes. À abattre en priorité." },
    { type = "turret",     name = "Tourelle de Pierre", family = "Construct", attack = "Salve croisée",     weakness = "Poison",  desc = "Immobile, elle arrose l'arène en croix puis en diagonale." },
    { type = "mage",       name = "Mage Téléporteur", family = "Sorcier",  attack = "Orbe arcanique",     weakness = "Feu",     desc = "Clignote d'un point à l'autre avant de lancer son orbe." },
    { type = "skeleton_king", name = "Roi Squelette", family = "Boss",     attack = "Salve de flèches",   weakness = "Feu",     desc = "Boss du désert. Enragé, il tire 5 flèches et appelle sa garde." },
    { type = "witch",      name = "Sorcière de Cristal", family = "Boss",  attack = "Gerbe d'orbes",      weakness = "Poison",  desc = "Boss des cavernes. Se téléporte et invoque des chauves-souris." },
    { type = "lava_titan", name = "Titan de Lave",    family = "Boss",     attack = "Salve incandescente", weakness = "Glace",  desc = "Boss de l'enfer. Sa carapace brûlante crache des pierres en étoile." },
    { type = "raven",      name = "Rapace des Cimes", family = "Volant",   attack = "Piqué fulgurant",  weakness = "Foudre",  desc = "Fond sur le héros depuis les nuages. Fragile mais très rapide." },
    { type = "wisp",       name = "Feu Follet",      family = "Esprit",   attack = "Orbe flottant",    weakness = "Glace",   desc = "Lévite au-dessus du vide et crache des orbes lumineux." },
    { type = "gargoyle",   name = "Gargouille",      family = "Construct", attack = "Charge de pierre", weakness = "Poison",  desc = "Statue animée des Îles Célestes : lente, lourde, difficile à briser." },
    { type = "frost_wraith", name = "Spectre Givré", family = "Mort-vivant", attack = "Éclat de givre", weakness = "Feu",     desc = "Se téléporte dans la Cité du Vide et gèle tout sur son passage." },
    { type = "storm_drake", name = "Drake des Tempêtes", family = "Boss", attack = "Souffle électrique", weakness = "Glace", desc = "Boss des Îles Célestes. Enragé, sa foudre frappe en continu." },
    { type = "void_watcher", name = "Œil du Vide",   family = "Boss",     attack = "Gerbe d'orbes",    weakness = "Feu",     desc = "Boss final. Son regard déforme l'espace et invoque des spectres." },
    { type = "golem",      name = "Golem de Granit",  family = "Boss",     attack = "Salve de pierres",   weakness = "Poison",  desc = "Boss de palier. Sous 50 % de PV il entre en rage : plus vif, plus dense." },
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
