local Physics = require("src.core.physics")

local T = {}

local function circleInRect(cx, cy, r, rect)
    local px = math.max(rect.x, math.min(rect.x + rect.w, cx))
    local py = math.max(rect.y, math.min(rect.y + rect.h, cy))
    local dx, dy = cx - px, cy - py
    return dx * dx + dy * dy < r * r
end

-- Décor factice : rochers rectangulaires, même contrat que ObstacleManager
local function obstacles(rocks)
    local om = { rocks = rocks }
    function om:isBlocked(x, y, r, _, allowGhost)
        if allowGhost then return false end
        for _, rect in ipairs(self.rocks) do
            if circleInRect(x, y, r, rect) then return true, "rock" end
        end
        return false
    end
    function om:findFreeSpot(x, y, r)
        for dist = 10, 200, 10 do
            for k = 0, 11 do
                local a = k * math.pi / 6
                local nx, ny = x + math.cos(a) * dist, y + math.sin(a) * dist
                if not self:isBlocked(nx, ny, r) then return nx, ny end
            end
        end
        return x, y
    end
    return om
end

-- Bloc carré et souche juste en dessous à gauche : un monstre qui contourne le bloc
-- en glissant vers le bas arrive sur la souche
local BLOCK = { x = 100, y = 100, w = 50, h = 50 }
local STUMP = { x = 55, y = 152, w = 40, h = 40 }

T["le contournement d'un bloc ne fait jamais entrer le monstre dans la souche voisine"] = function()
    local om = obstacles({ BLOCK, STUMP })
    local m = { x = 89, y = 125, radius = 10 }
    for step = 1, 120 do
        -- Joueur en bas à droite, derrière le bloc et la souche
        Physics.steerAroundObstacle(m, 300, 220, 60, 1 / 30, m.radius, om, false, 640, 480)
        assert(not om:isBlocked(m.x, m.y, m.radius),
            string.format("monstre dans un obstacle à l'image %d (%.1f, %.1f)", step, m.x, m.y))
    end
end

T["un monstre déjà coincé dans un rocher en est dégagé"] = function()
    local om = obstacles({ BLOCK, STUMP })
    local m = { x = 120, y = 120, radius = 10 }
    Physics.moveAndSlide(m, 50, 0, 1 / 30, m.radius, om, false, 640, 480)
    assert(not om:isBlocked(m.x, m.y, m.radius), "le monstre doit être replacé hors du rocher")
end

T["un monstre fantôme traverse sans être déplacé"] = function()
    local om = obstacles({ BLOCK })
    local m = { x = 120, y = 120, radius = 10, canGhostWalk = true }
    Physics.moveAndSlide(m, 30, 0, 1 / 30, m.radius, om, false, 640, 480)
    assert(math.abs(m.x - 121) < 1e-6 and m.y == 120)
end

return T
