-- src/data/heroes.lua
-- Catalogue des Héros Archero 2 avec caractéristiques uniques et passifs de combat
-- Optimisé pour Nintendo 3DS (Zéro allocation GC au runtime)

local Heroes = {
    ROSTER = {
        atreus = {
            id = "atreus",
            name = "Atreus",
            title = "Archer Rôdeur",
            desc = "Héros équilibré, vif et déterminé.",
            costType = "free",
            cost = 0,
            color = {0.20, 0.78, 0.38},
            accentColor = {0.95, 0.85, 0.25},
            baseAtkBonus = 10,
            baseHpBonus = 150,
            passiveId = "courage",
            passiveName = "Courage du Rôdeur",
            passiveDesc = "+10% Vitesse de tir & +5% Esquive permanente.",
            cowlColor = {0.18, 0.65, 0.35},
            capeColor = {0.12, 0.42, 0.24},
            hasFeather = true,
            ultimate = {
                id = "celestial_barrage",
                name = "Barrage Céleste",
                desc = "Pluie de flèches dorées ciblées sur les ennemis",
            },
        },
        urasil = {
            id = "urasil",
            name = "Urasil",
            title = "Maître des Poisons",
            desc = "Assassin silencieux manipulant les toxines.",
            costType = "gold",
            cost = 500,
            color = {0.55, 0.22, 0.85},
            accentColor = {0.25, 0.95, 0.35},
            baseAtkBonus = 15,
            baseHpBonus = 80,
            passiveId = "poison_arrows",
            passiveName = "Venin Mortel",
            passiveDesc = "Toutes les flèches empoisonnent l'ennemi (35 dégâts/s continus).",
            cowlColor = {0.40, 0.15, 0.60},
            capeColor = {0.25, 0.08, 0.40},
            hasMask = true,
            ultimate = {
                id = "deadly_miasma",
                name = "Miasme Mortel",
                desc = "Nuage d'acide asphyxiant toute la salle",
            },
        },
        phoren = {
            id = "phoren",
            name = "Phoren",
            title = "Seigneur des Flammes",
            desc = "Pyromancien furieux brûlant ses adversaires.",
            costType = "gold",
            cost = 1200,
            color = {0.95, 0.35, 0.15},
            accentColor = {1.00, 0.82, 0.18},
            baseAtkBonus = 25,
            baseHpBonus = 50,
            passiveId = "flame_arrows",
            passiveName = "Fureur Pyrotechnique",
            passiveDesc = "Toutes les flèches brûlent l'ennemi (60 dégâts/0.3s pendant 2s).",
            cowlColor = {0.85, 0.25, 0.10},
            capeColor = {0.55, 0.12, 0.08},
            hasFlameCrest = true,
            ultimate = {
                id = "volcanic_meteor",
                name = "Météore Volcanique",
                desc = "Impact volcanique cataclysmique brûlant le sol",
            },
        },
        helix = {
            id = "helix",
            name = "Helix",
            title = "Guerrier Berserker",
            desc = "Féroce combattant tribal devenant plus fort blessé.",
            costType = "gems",
            cost = 100,
            color = {0.82, 0.52, 0.22},
            accentColor = {0.95, 0.25, 0.25},
            baseAtkBonus = 20,
            baseHpBonus = 250,
            passiveId = "berserk_fury",
            passiveName = "Rage Primale",
            passiveDesc = "Dégâts augmentés jusqu'à +120% lorsque les PV diminuent.",
            cowlColor = {0.55, 0.35, 0.15},
            capeColor = {0.35, 0.20, 0.10},
            hasHorns = true,
            ultimate = {
                id = "berserker_rage",
                name = "Fureur Berserker",
                desc = "Invulnérabilité 3s + Vitesse d'attaque x2",
            },
        },
        rolla = {
            id = "rolla",
            name = "Rolla",
            title = "Reine Polaire",
            desc = "Souveraine des glaces immortelles.",
            costType = "gems",
            cost = 250,
            color = {0.32, 0.85, 1.00},
            accentColor = {0.95, 0.98, 1.00},
            baseAtkBonus = 20,
            baseHpBonus = 180,
            passiveId = "freeze_arrows",
            passiveName = "Gel Boréal",
            passiveDesc = "Toutes les flèches gèlent les monstres pendant 1.5s.",
            cowlColor = {0.20, 0.65, 0.88},
            capeColor = {0.12, 0.38, 0.58},
            hasTiara = true,
            ultimate = {
                id = "absolute_zero",
                name = "Zéro Absolu",
                desc = "Gèle instantanément toute la salle pendant 3 secondes",
            },
        },
    },
    ORDER = { "atreus", "urasil", "phoren", "helix", "rolla" },
}

function Heroes.get(id)
    return Heroes.ROSTER[id or "atreus"] or Heroes.ROSTER.atreus
end

function Heroes.getAll()
    local list = {}
    for _, id in ipairs(Heroes.ORDER) do
        table.insert(list, Heroes.ROSTER[id])
    end
    return list
end

-- Application des passifs et bonus du héros sur le joueur lors de l'entrée en combat
function Heroes.applyHeroPassives(player, heroId)
    local h = Heroes.get(heroId)
    if not h or not player then return end

    -- Bonus de base
    player.maxHp = player.maxHp + (h.baseHpBonus or 0)
    player.hp = player.maxHp
    player.baseHeroAtk = h.baseAtkBonus or 0
    player.heroId = h.id

    -- Trait passif unique
    if h.passiveId == "courage" then
        player.attackSpeedMult = (player.attackSpeedMult or 1.0) * 1.10
        player.dodgeChance = (player.dodgeChance or 0) + 0.05

    elseif h.passiveId == "poison_arrows" then
        player.elements = player.elements or {}
        player.elements.poison = true

    elseif h.passiveId == "flame_arrows" then
        player.elements = player.elements or {}
        player.elements.fire = true

    elseif h.passiveId == "freeze_arrows" then
        player.elements = player.elements or {}
        player.elements.ice = true

    elseif h.passiveId == "berserk_fury" then
        player.hasBerserkFury = true
    end
end

return Heroes
