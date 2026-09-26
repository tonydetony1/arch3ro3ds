-- src/render/depth.lua
-- Profondeur stéréoscopique de l'écran du haut (curseur 3D de la Nintendo 3DS).
-- Chaque couche est décalée horizontalement selon l'œil rendu :
--   valeur négative = derrière l'écran (ciel), 0 = plan de l'écran (sol), positive = jaillit (effets, textes).
-- Sur PC (pas de 3D), l'œil vaut 0 : aucun décalage, aucun coût.

local Depth = {
    eye = 0,
    strength = 0,
    userScale = 1.0,   -- intensité du relief choisie par le joueur (0.0 à 1.5)
    override = nil, -- force une intensité (banc de test PC)
}

-- Profondeurs en pixels au curseur 3D maximum
Depth.SKY        = -10
Depth.FAR        = -7
Depth.CLOUDS     = -4
Depth.GROUND     = 0
Depth.WALLS      = 1
Depth.ACTORS     = 2
Depth.FX         = 3
Depth.TEXT       = 4

function Depth.begin(eye)
    Depth.eye = eye or 0
    local s = 0
    if Depth.eye ~= 0 then
        if Depth.override then
            s = Depth.override
        elseif love.graphics.get3DDepth then
            local ok, v = pcall(love.graphics.get3DDepth)
            if ok and type(v) == "number" then s = v end
        end
    end
    Depth.strength = s
end

-- Décalage horizontal (entier) d'une couche pour l'œil courant
function Depth.offset(layer)
    if Depth.eye == 0 or Depth.strength == 0 then return 0 end
    -- userScale : réglage "Profondeur 3D" de la page Paramètres (0 = relief désactivé)
    return math.floor(-Depth.eye * Depth.strength * (Depth.userScale or 1.0) * layer + 0.5)
end

function Depth.push(layer)
    love.graphics.push()
    local dx = Depth.offset(layer)
    if dx ~= 0 then love.graphics.translate(dx, 0) end
end

function Depth.pop()
    love.graphics.pop()
end

return Depth
