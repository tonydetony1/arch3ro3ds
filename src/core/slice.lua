-- src/core/slice.lua
-- Travail coopératif découpé en tranches : une tâche longue (préparation de la salle
-- suivante) tourne dans une coroutine et rend la main dès que son budget de temps de
-- l'image est épuisé. Les boucles lourdes appellent Slice.check() une fois par ligne :
-- hors tâche découpée (appel synchrone normal), check() ne fait rien.

local Slice = {}

local current = nil       -- coroutine en cours d'exécution découpée
local deadline = math.huge
local now = love.timer.getTime

function Slice.check()
    if current ~= nil and coroutine.running() == current and now() > deadline then
        coroutine.yield()
    end
end

-- Exécute `co` jusqu'à épuisement de `budget` secondes (math.huge = jusqu'au bout).
-- Renvoie true quand la tâche est terminée ; une erreur est renvoyée en second résultat.
function Slice.resume(co, budget)
    if coroutine.status(co) == "dead" then return true end
    current, deadline = co, (budget == math.huge) and math.huge or (now() + budget)
    local ok, err = coroutine.resume(co)
    current, deadline = nil, math.huge
    if not ok then return true, err end
    return coroutine.status(co) == "dead"
end

return Slice
