-- src/render/sprites/items.lua
-- Icônes d'équipement en pixel art (armes, armures, anneaux, familiers).
-- Formes générées par PixGen puis contournées automatiquement : un seul style pour tout l'inventaire.

local PixGen = require("src.render.sprites.pixgen")

local Items = {}

local INK = "181425"
local S = 16 -- toutes les icônes tiennent dans 16x16

local function newIcon()
    return PixGen.new(S, S, 5)
end

-- ---------------------------------------------------------------------------
-- ARMES
-- ---------------------------------------------------------------------------
local function bow()
    local g = newIcon()
    g:ellipse(6, 8, 6.5, 7.5, "W")
    g:ellipse(6, 8, 4.6, 5.6, ".")
    g:rect(0, 0, 6, 16, ".")
    g:rect(6, 2, 1, 12, "s")
    g:rect(3, 7, 11, 1, "A")
    g:set(14, 6, "T"); g:set(15, 7, "T"); g:set(14, 8, "T"); g:set(13, 7, "T")
    g:set(3, 6, "F"); g:set(3, 8, "F"); g:set(4, 7, "F")
    return g:toGrid()
end

local function daggers()
    local g = newIcon()
    for i, ox in ipairs({ 1, 8 }) do
        g:rect(ox + 2, 1, 2, 8, "W")
        g:set(ox + 2, 0, "W"); g:set(ox + 3, 0, "W")
        g:rect(ox + 1, 9, 4, 1, "G")
        g:rect(ox + 2, 10, 2, 4, "H")
        g:rect(ox + 1, 14, 4, 1, "G")
    end
    return g:toGrid()
end

local function ballista()
    local g = newIcon()
    g:rect(2, 6, 12, 3, "H")
    g:rect(6, 2, 2, 12, "W")
    g:rect(1, 4, 1, 8, "W")
    g:rect(14, 4, 1, 8, "W")
    g:rect(2, 4, 12, 1, "s")
    g:rect(9, 7, 6, 1, "A")
    g:set(15, 6, "T"); g:set(15, 8, "T")
    return g:toGrid()
end

local function staff()
    local g = newIcon()
    g:rect(7, 5, 2, 11, "H")
    g:circle(8, 4, 4, "G")
    g:circle(8, 4, 2.4, "M")
    g:set(7, 2, "W")
    g:rect(6, 9, 4, 1, "G")
    return g:toGrid()
end

local function scythe()
    local g = newIcon()
    g:rect(9, 3, 2, 13, "H")
    g:ellipse(7, 4, 7, 5, "W")
    g:ellipse(7, 6, 6, 5, ".")
    g:rect(0, 0, 16, 1, ".")
    g:rect(9, 8, 4, 1, "G")
    return g:toGrid()
end

local function boomerang()
    local g = newIcon()
    g:ellipse(8, 8, 7, 7, "W")
    g:ellipse(8, 8, 4.5, 4.5, ".")
    g:rect(8, 0, 8, 9, ".")
    g:rect(0, 9, 9, 7, ".")
    g:sprinkle("G", 0.25, "W")
    return g:toGrid()
end

local function saw()
    local g = newIcon()
    g:circle(8, 8, 7, "W")
    for i = 0, 7 do
        local a = i * math.pi / 4
        g:set(8 + math.cos(a) * 7.6, 8 + math.sin(a) * 7.6, "W")
        g:set(8 + math.cos(a) * 8.4, 8 + math.sin(a) * 8.4, "W")
    end
    g:circle(8, 8, 3, "H")
    g:circle(8, 8, 1.4, "G")
    g:ellipse(5, 5, 2.5, 1.6, "s", "W")
    return g:toGrid()
end

local function spear()
    local g = newIcon()
    g:rect(7, 5, 2, 11, "H")
    g:rect(6, 0, 4, 3, "W")
    g:set(7, 0, "."); g:set(9, 0, ".")
    g:rect(7, 3, 2, 2, "W")
    g:rect(5, 5, 6, 1, "G")
    return g:toGrid()
end

-- ---------------------------------------------------------------------------
-- ARMURES, ANNEAUX, FAMILIERS
-- ---------------------------------------------------------------------------
local function armor()
    local g = newIcon()
    g:rect(3, 2, 10, 3, "W")
    g:rect(2, 4, 12, 8, "W")
    g:ellipse(8, 12, 6, 4, "W")
    g:rect(6, 2, 4, 3, ".")
    g:rect(6, 5, 4, 2, "M")
    g:rect(2, 6, 2, 5, "s")
    g:rect(12, 6, 2, 5, "s")
    g:rect(7, 7, 2, 6, "G")
    g:edge("W", "s", 0, 1)
    return g:toGrid()
end

local function ring()
    local g = newIcon()
    g:ellipse(8, 10, 6, 5.5, "W")
    g:ellipse(8, 10, 3.6, 3.4, ".")
    g:circle(8, 4, 3.4, "G")
    g:circle(8, 4, 1.6, "M")
    g:set(7, 3, "L")
    return g:toGrid()
end

local function petIcon(kind)
    local g = newIcon()
    if kind == "bat" then
        g:circle(8, 9, 4.5, "W")
        g:ellipse(2, 8, 3.5, 2.5, "s")
        g:ellipse(14, 8, 3.5, 2.5, "s")
        g:set(6, 4, "W"); g:set(5, 3, "W"); g:set(10, 4, "W"); g:set(11, 3, "W")
        g:set(6, 9, "M"); g:set(10, 9, "M")
    elseif kind == "ghost" then
        g:circle(8, 8, 5, "W")
        g:rect(3, 8, 11, 5, "W")
        g:set(4, 13, "."); g:set(6, 13, "."); g:set(9, 13, "."); g:set(12, 13, ".")
        g:set(6, 7, "M"); g:set(10, 7, "M")
        g:ellipse(8, 3, 4, 1.6, "G")
    else -- dragon
        g:circle(9, 9, 4.5, "W")
        g:ellipse(3, 6, 3.5, 4, "s")
        g:set(12, 5, "W"); g:set(13, 4, "W"); g:set(6, 5, "W"); g:set(5, 4, "W")
        g:rect(12, 10, 4, 1, "s")
        g:set(8, 9, "M"); g:set(11, 9, "M")
        g:set(9, 12, "G"); g:set(10, 12, "G")
    end
    return g:toGrid()
end

-- Palettes : W corps principal | s ombre | H manche | G accent doré | M gemme | A flèche | T pointe | F plumes | L reflet
local WEAPON_PAL = { W = "c0cbdc", s = "8b9bb4", H = "733e39", G = "feae34", M = "e43b44", A = "b86f50", T = "ffffff", F = "e43b44", L = "ffffff" }

Items.ICON_MAP = {
    bow = { sprite = "item_bow" },
    daggers = { sprite = "item_daggers" },
    ballista = { sprite = "item_ballista" },
    staff = { sprite = "item_staff", variant = "arcane" },
    scythe = { sprite = "item_scythe", variant = "dark" },
    boomerang = { sprite = "item_boomerang", variant = "wood" },
    saw = { sprite = "item_saw" },
    spear = { sprite = "item_spear", variant = "gold" },
    vest = { sprite = "item_armor", variant = "leather" },
    cloak = { sprite = "item_armor", variant = "shadow" },
    golden_armor = { sprite = "item_armor", variant = "gold" },
    wolf_ring = { sprite = "item_ring", variant = "steel" },
    bear_ring = { sprite = "item_ring", variant = "ember" },
    serpent_ring = { sprite = "item_ring", variant = "venom" },
    falcon_ring = { sprite = "item_ring", variant = "sky" },
    bat_pet = { sprite = "item_pet_bat" },
    ghost_pet = { sprite = "item_pet_ghost" },
    dragon_pet = { sprite = "item_pet_dragon", variant = "ember" },
}

function Items.define(atlas)
    local shade = { depth = 3, strength = 0.9 }
    local function d(name, grid, variants)
        atlas:define(name, {
            frames = { grid }, palette = WEAPON_PAL, outline = INK,
            anchor = "center", shade = shade, variants = variants,
        })
    end

    d("item_bow", bow())
    d("item_daggers", daggers())
    d("item_ballista", ballista())
    d("item_staff", staff(), { arcane = { G = "b55088", M = "2ce8f5", W = "c0cbdc" } })
    d("item_scythe", scythe(), { dark = { W = "8b9bb4", s = "5a6988", G = "68386c" } })
    d("item_boomerang", boomerang(), { wood = { W = "b86f50", G = "ead4aa", s = "733e39" } })
    d("item_saw", saw())
    d("item_spear", spear(), { gold = { W = "fee761", G = "f77622", s = "feae34" } })
    d("item_armor", armor(), {
        leather = { W = "b86f50", s = "733e39", G = "feae34", M = "ead4aa" },
        shadow = { W = "5a6988", s = "3a4466", G = "b55088", M = "262b44" },
        gold = { W = "feae34", s = "f77622", G = "fee761", M = "ffffff" },
    })
    d("item_ring", ring(), {
        steel = { W = "c0cbdc", G = "8b9bb4", M = "5a6988" },
        ember = { W = "feae34", G = "e43b44", M = "f77622" },
        venom = { W = "c0cbdc", G = "63c74d", M = "3e8948" },
        sky = { W = "c0cbdc", G = "2ce8f5", M = "0099db" },
    })
    d("item_pet_bat", petIcon("bat"), { ember = { W = "b55088", s = "68386c" } })
    d("item_pet_ghost", petIcon("ghost"), { ember = { W = "ffffff", s = "c0cbdc" } })
    d("item_pet_dragon", petIcon("dragon"), { ember = { W = "e43b44", s = "a22633", G = "feae34", M = "fee761" } })
end

return Items
