-- src/render/sprites/pixgen.lua
-- Petit générateur de grilles pixel art procédurales (formes organiques : feuillage, rochers, nuages).
-- Produit des grilles de caractères consommées par SpriteAtlas (contour automatique inclus).

local PixGen = {}
PixGen.__index = PixGen

function PixGen.new(w, h, seed)
    local self = setmetatable({}, PixGen)
    self.w, self.h = w, h
    self.seed = seed or 1
    self.m = {}
    for y = 0, h - 1 do
        local row = {}
        for x = 0, w - 1 do row[x] = "." end
        self.m[y] = row
    end
    return self
end

-- Générateur pseudo-aléatoire déterministe (LCG)
function PixGen:rand()
    self.seed = (self.seed * 1664525 + 1013904223) % 4294967296
    return self.seed / 4294967296
end

function PixGen:set(x, y, ch)
    x, y = math.floor(x), math.floor(y)
    if x >= 0 and y >= 0 and x < self.w and y < self.h then
        self.m[y][x] = ch
    end
end

function PixGen:get(x, y)
    if x < 0 or y < 0 or x >= self.w or y >= self.h then return "." end
    return self.m[y][x]
end

-- only : si fourni, ne peint que sur ces caractères existants (ex : "GM")
local function allowed(self, x, y, only)
    if not only then return true end
    return only:find(self:get(x, y), 1, true) ~= nil
end

function PixGen:ellipse(cx, cy, rx, ry, ch, only)
    for y = math.floor(cy - ry), math.ceil(cy + ry) do
        for x = math.floor(cx - rx), math.ceil(cx + rx) do
            local dx = (x + 0.5 - cx) / rx
            local dy = (y + 0.5 - cy) / ry
            if dx * dx + dy * dy <= 1.0 and allowed(self, x, y, only) then
                self:set(x, y, ch)
            end
        end
    end
end

function PixGen:circle(cx, cy, r, ch, only)
    self:ellipse(cx, cy, r, r, ch, only)
end

function PixGen:rect(x, y, w, h, ch, only)
    for yy = y, y + h - 1 do
        for xx = x, x + w - 1 do
            if allowed(self, xx, yy, only) then self:set(xx, yy, ch) end
        end
    end
end

-- Parsème un caractère sur les pixels existants de "on"
function PixGen:sprinkle(ch, density, on)
    for y = 0, self.h - 1 do
        for x = 0, self.w - 1 do
            if on:find(self.m[y][x], 1, true) and self:rand() < density then
                self.m[y][x] = ch
            end
        end
    end
end

-- Ombre portée interne : pixels "from" dont le voisin (dx, dy) est vide deviennent "to"
function PixGen:edge(from, to, dx, dy)
    local marks = {}
    for y = 0, self.h - 1 do
        for x = 0, self.w - 1 do
            if from:find(self.m[y][x], 1, true) and self:get(x + dx, y + dy) == "." then
                marks[#marks + 1] = { x, y }
            end
        end
    end
    for _, p in ipairs(marks) do self.m[p[2]][p[1]] = to end
end

function PixGen:toGrid()
    local grid = {}
    for y = 0, self.h - 1 do
        local row = {}
        for x = 0, self.w - 1 do row[#row + 1] = self.m[y][x] end
        grid[#grid + 1] = table.concat(row)
    end
    return grid
end

return PixGen
