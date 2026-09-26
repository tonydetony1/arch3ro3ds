-- src/render/palette.lua
-- Palette maîtresse du jeu (base ENDESGA 32 + tons de sol adoucis)
-- Toute la direction artistique (sprites, décor, interface) pioche ici pour rester cohérente.

local Palette = {}

local function hex(h)
    local r = tonumber(h:sub(1, 2), 16) / 255
    local g = tonumber(h:sub(3, 4), 16) / 255
    local b = tonumber(h:sub(5, 6), 16) / 255
    return { r, g, b, 1.0 }
end
Palette.hex = hex

-- Couleurs nommées (réutilisables partout)
Palette.C = {
    ink        = hex("181425"), -- contour universel
    night      = hex("262b44"),
    slate      = hex("3a4466"),
    steel      = hex("5a6988"),
    fog        = hex("8b9bb4"),
    silver     = hex("c0cbdc"),
    white      = hex("ffffff"),

    rust       = hex("be4a2f"),
    ember      = hex("d77643"),
    sand       = hex("ead4aa"),
    tan        = hex("e4a672"),
    clay       = hex("b86f50"),
    bark       = hex("733e39"),
    umber      = hex("3e2731"),

    wine       = hex("a22633"),
    red        = hex("e43b44"),
    orange     = hex("f77622"),
    amber      = hex("feae34"),
    yellow     = hex("fee761"),

    leaf       = hex("63c74d"),
    moss       = hex("3e8948"),
    pine       = hex("265c42"),
    abyss      = hex("193c3e"),

    navy       = hex("124e89"),
    blue       = hex("0099db"),
    cyan       = hex("2ce8f5"),

    crimson    = hex("ff0044"),
    plum       = hex("68386c"),
    magenta    = hex("b55088"),
    pink       = hex("f6757a"),
    skin       = hex("e8b796"),
    skinShade  = hex("c28569"),

    -- Sol de prairie (tons proches pour un fond calme qui laisse ressortir les personnages)
    grass      = hex("4f9b45"),
    grassLight = hex("5dac4d"),
    grassDark  = hex("438a3e"),
    grassDeep  = hex("356f39"),
    dirt       = hex("9a6a48"),
    dirtDark   = hex("7a4f38"),
}

-- Couleurs de rareté partagées (compétences, objets, cadres)
Palette.RARITY = {
    common    = { main = Palette.C.silver, dark = Palette.C.steel,  light = Palette.C.white,  name = "COMMUN" },
    uncommon  = { main = Palette.C.leaf,   dark = Palette.C.moss,   light = hex("a8e890"),   name = "ATYPIQUE" },
    rare      = { main = Palette.C.blue,   dark = Palette.C.navy,   light = Palette.C.cyan,   name = "RARE" },
    epic      = { main = Palette.C.magenta, dark = Palette.C.plum,  light = Palette.C.pink,   name = "ÉPIQUE" },
    legendary = { main = Palette.C.amber,  dark = Palette.C.ember,  light = Palette.C.yellow, name = "LÉGENDAIRE" },
    forbidden = { main = Palette.C.red,    dark = Palette.C.wine,   light = Palette.C.pink,   name = "INTERDIT" },
}

function Palette.rarity(id)
    return Palette.RARITY[id or "common"] or Palette.RARITY.common
end

-- Applique une couleur de la palette (alpha optionnel)
function Palette.set(color, alpha)
    love.graphics.setColor(color[1], color[2], color[3], alpha or color[4] or 1.0)
end

return Palette
