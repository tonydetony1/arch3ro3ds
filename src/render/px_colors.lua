-- src/render/px_colors.lua
-- Pixels pré-colorés de l'interface : chaque couleur nommée de la palette (et quelques tons
-- propres aux thèmes de boutons) existe dans l'atlas sous forme d'un pixel "px_<nom>_<a>",
-- où a = opacité en vingtièmes (20 = opaque). Étiré à la taille voulue et dessiné en blanc,
-- un aplat d'interface passe par l'auto-batcher (src/core/gpu.lua) au lieu de coûter un
-- appel GPU (~80 µs sur Old 3DS) : un écran d'interface complet tient en quelques appels.

local Palette = require("src.render.palette")

local PxColors = {}

-- Tons des thèmes de boutons absents de Palette.C (voir Skin.THEMES)
PxColors.EXTRA = {
    greenLight = Palette.hex("a8e890"),
    blueLip = Palette.hex("0d3563"),
    redLip = Palette.hex("6b1622"),
}

-- Couleurs déclinées sur les 20 niveaux d'opacité (voiles, ombres, surbrillances)
PxColors.ALL_ALPHAS = {
    ink = true, night = true, slate = true, abyss = true, white = true, red = true,
    amber = true, cyan = true, yellow = true, navy = true, leaf = true, black = true,
    orange = true, sand = true, -- animations des zones dangereuses (lave, sable)
}

-- nom -> couleur, et couleur (identité de table) -> nom
function PxColors.list()
    local out = {}
    for name, c in pairs(Palette.C) do
        if type(c) == "table" and type(c[1]) == "number" then out[name] = c end
    end
    for name, c in pairs(PxColors.EXTRA) do out[name] = c end
    return out
end

local byTable = nil
function PxColors.nameOf(color)
    if not byTable then
        byTable = {}
        for name, c in pairs(PxColors.list()) do byTable[c] = name end
    end
    return byTable[color]
end

-- Opacité quantifiée en vingtièmes, ou nil si la couleur n'a pas ce niveau précuit
-- (mémoïsé : aucune chaîne créée par image)
local names = {}
function PxColors.spriteName(name, alpha)
    local a20 = math.floor((alpha or 1) * 20 + 0.5)
    if a20 <= 0 then return nil end
    if a20 > 20 then a20 = 20 end
    local byAlpha = names[name]
    if not byAlpha then
        byAlpha = {}
        names[name] = byAlpha
    end
    local s = byAlpha[a20]
    if s == nil then
        s = (a20 == 20 or PxColors.ALL_ALPHAS[name]) and ("px_" .. name .. "_" .. a20) or false
        byAlpha[a20] = s
    end
    return s or nil
end

-- Précompilation (tools/bake) : déclare tous les pixels dans l'atlas
function PxColors.define(atlas)
    for name, c in pairs(PxColors.list()) do
        local levels = PxColors.ALL_ALPHAS[name] and 20 or 1
        for i = 1, levels do
            local a20 = (levels == 1) and 20 or i
            atlas:define("px_" .. name .. "_" .. a20, {
                frames = { { "W" } },
                palette = { W = { c[1], c[2], c[3], a20 / 20 } },
                anchor = "topleft",
            })
        end
    end
end

return PxColors
