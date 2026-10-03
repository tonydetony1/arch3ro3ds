-- src/core/stick.lua
-- Lecture du Circle Pad dans le repère de l'écran : x vers la droite, y vers le bas.

local Stick = {}

-- LÖVE Potion renvoie le Circle Pad brut de la 3DS : getAxis(2) est positif vers le HAUT,
-- alors que LÖVE sur PC (SDL) le donne positif vers le bas. Sans inversion sur 3DS, haut et
-- bas sont échangés.
function Stick.read(joy, is3DS)
    local x = joy:getAxis(1) or 0
    local y = joy:getAxis(2) or 0
    if is3DS then y = -y end
    return x, y
end

return Stick
