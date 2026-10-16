-- src/core/slice.lua
-- Travail coopératif découpé en tranches : une tâche longue (préparation de la salle
-- suivante) tourne dans une coroutine et rend la main dès que son budget de temps de
-- l'image est épuisé. Les boucles lourdes appellent Slice.check() une fois par ligne :
-- hors tâche découpée (appel synchrone normal), check() ne fait rien.

local Slice = {}

local current = nil       -- coroutine en cours d'exécution découpée
local deadline = math.huge
local heavyAllowed = true -- the running slice may start a step that cannot yield (Slice.heavy)
local now = love.timer.getTime

function Slice.check()
    if current ~= nil and coroutine.running() == current and now() > deadline then
        coroutine.yield()
    end
end

-- Before a step that cannot yield halfway (a texture upload: tens of ms on Old 3DS), a sliced task
-- waits for a slice that allows it; outside a sliced task (synchronous build) it goes on at once
function Slice.heavy()
    while current ~= nil and coroutine.running() == current and not heavyAllowed do
        coroutine.yield()
    end
end

-- Exécute `co` jusqu'à épuisement de `budget` secondes (math.huge = jusqu'au bout).
-- allowHeavy = false keeps the task off its uninterruptible steps (Slice.heavy) during this slice.
-- Renvoie true quand la tâche est terminée ; une erreur est renvoyée en second résultat.
function Slice.resume(co, budget, allowHeavy)
    if coroutine.status(co) == "dead" then return true end
    current, deadline = co, (budget == math.huge) and math.huge or (now() + budget)
    heavyAllowed = allowHeavy ~= false or budget == math.huge
    local ok, err = coroutine.resume(co)
    current, deadline, heavyAllowed = nil, math.huge, true
    if not ok then return true, err end
    return coroutine.status(co) == "dead"
end

return Slice
