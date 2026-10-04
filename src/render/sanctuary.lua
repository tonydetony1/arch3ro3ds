-- src/render/sanctuary.lua
-- Décor propre aux sanctuaires : chemin de dalles et autel au sol, braseros muraux de l'antre
-- du Démon, nuages qui dérivent et rayons de lumière du sanctuaire de l'Ange, lueur de lave.
-- Le sol, les murs et le ciel viennent des thèmes 7 et 8 (WorldManager.THEMES).
-- Une vingtaine de sprites et quelques aplats par image : coût négligeable.

local Art = require("src.render.art")

local Sanctuary = {}
Sanctuary.__index = Sanctuary

local SLAB = 16

-- kind : "angel" ou "devil" ; salle de mapW x mapH (un écran)
function Sanctuary.new(kind, mapW, mapH)
    local self = setmetatable({}, Sanctuary)
    self.kind = kind
    self.variant = (kind == "angel") and "sky" or "lava"
    self.w, self.h = mapW, mapH
    self.cx, self.cy = math.floor(mapW / 2), math.floor(mapH / 2)
    -- Chemin de dalles de l'entrée (sud) à la porte (nord), interrompu par l'autel
    self.path = {}
    for y = 40, mapH - 24, SLAB do
        if math.abs(y + SLAB / 2 - self.cy) > 20 then
            self.path[#self.path + 1] = y
        end
    end
    -- Braseros dans les bandes de mur latérales : jamais sous les pas du héros
    self.braziers = {
        { x = 11, y = math.floor(mapH * 0.38) }, { x = mapW - 11, y = math.floor(mapH * 0.38) },
        { x = 11, y = math.floor(mapH * 0.78) }, { x = mapW - 11, y = math.floor(mapH * 0.78) },
    }
    self.clouds = {
        { x = 30, y = 70, speed = 6, frame = 1 },
        { x = 250, y = 150, speed = 4, frame = 2 },
        { x = 140, y = 200, speed = 5, frame = 1 },
    }
    return self
end

function Sanctuary:update(dt)
    if self.kind ~= "angel" then return end
    for _, c in ipairs(self.clouds) do
        c.x = c.x + c.speed * dt
        if c.x > self.w + 20 then c.x = -20 end
    end
end

-- Sol : chemin de dalles et autel, sous le personnage et le héros
function Sanctuary:drawFloor()
    love.graphics.setColor(1, 1, 1, 1)
    for i, y in ipairs(self.path) do
        Art.draw("slab", 1 + (i % 4), self.cx - SLAB, y, false, false, self.variant)
        Art.draw("slab", 1 + ((i + 2) % 4), self.cx, y, false, false, self.variant)
    end
    Art.draw(self.kind == "angel" and "altar_angel" or "altar_devil", 1, self.cx, self.cy + 14)
end

-- Murs : braseros allumés de l'antre du Démon
function Sanctuary:drawWalls(t)
    if self.kind ~= "devil" then return end
    love.graphics.setColor(1, 1, 1, 1)
    for i, b in ipairs(self.braziers) do
        Art.draw("brazier", Art.animFrame("brazier", t, 8, i * 0.7), b.x, b.y)
    end
end

-- Ambiance au premier plan : rayons et nuages (Ange), lueur de lave qui respire (Démon)
function Sanctuary:drawAmbient(t)
    if self.kind == "angel" then
        for i = 0, 2 do
            local a = 0.06 + 0.04 * math.sin(t * 1.3 + i * 2.1)
            love.graphics.setColor(1, 0.95, 0.75, a)
            local x = self.cx - 70 + i * 60
            love.graphics.polygon("fill", x, 30, x + 26, 30, x + 66, self.h - 20, x + 34, self.h - 20)
        end
        love.graphics.setColor(1, 1, 1, 0.85)
        for _, c in ipairs(self.clouds) do
            Art.draw("cloud_puff", c.frame, c.x, c.y)
        end
    else
        local a = 0.05 + 0.04 * (math.sin(t * 2.0) + 1) * 0.5
        love.graphics.setColor(0.9, 0.25, 0.08, a)
        love.graphics.rectangle("fill", 16, 30, self.w - 32, self.h - 44)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return Sanctuary
