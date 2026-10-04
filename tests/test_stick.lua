local Stick = require("src.core.stick")

local T = {}

-- Manette factice : axes bruts tels que renvoyés par joystick:getAxis(i)
local function joy(x, y)
    return { getAxis = function(_, i) return (i == 1) and x or y end }
end

-- Sur 3DS, LÖVE Potion renvoie le Circle Pad brut : axe 2 positif vers le HAUT
T["3DS : Circle Pad vers le bas déplace vers le bas de l'écran"] = function()
    local x, y = Stick.read(joy(0, -1), true)
    assert(x == 0 and y == 1, "bas doit donner y = 1, obtenu " .. tostring(y))
end

T["3DS : Circle Pad vers le haut déplace vers le haut de l'écran"] = function()
    local _, y = Stick.read(joy(0, 0.8), true)
    assert(y == -0.8, "haut doit donner y = -0.8, obtenu " .. tostring(y))
end

T["3DS : droite reste à droite et gauche à gauche"] = function()
    assert(Stick.read(joy(1, 0), true) == 1)
    assert(Stick.read(joy(-0.5, 0), true) == -0.5)
end

-- Sur PC, LÖVE (SDL) suit déjà le repère de l'écran : axe 2 positif vers le bas
T["PC : axes de manette inchangés"] = function()
    local x, y = Stick.read(joy(0.3, 1), false)
    assert(x == 0.3 and y == 1)
end

T["axe absent : zéro"] = function()
    local x, y = Stick.read({ getAxis = function() return nil end }, true)
    assert(x == 0 and y == 0)
end

return T
