-- src/core/camera.lua
-- Caméra 2D fluide avec interpolation (lerp) et clamping aux limites de l'arène
-- Conçue pour afficher des mondes plus grands que l'écran 3DS (400x240) à 60 FPS

local Config = require("src.data.config")

local Camera = {}
Camera.__index = Camera

-- Marge ciel ouvert : l'arène flotte sans toucher les bords absolus (0 = caméra fixe
-- sur une salle d'un écran, comme les sanctuaires)
Camera.SKY_MARGIN = 36

function Camera.new()
    local self = setmetatable({}, Camera)
    self.viewportW = Config.TOP_WIDTH   -- 400
    self.viewportH = Config.TOP_HEIGHT  -- 240
    self.halfW = self.viewportW / 2     -- 200
    self.halfH = self.viewportH / 2     -- 120

    self.x = self.halfW
    self.y = self.halfH
    self.mapW = self.viewportW
    self.mapH = self.viewportH
    self.margin = Camera.SKY_MARGIN
    self.lerpSpeed = 7.5 -- Vitesse de suivi fluide

    return self
end

function Camera:setBounds(mapW, mapH, margin)
    self.mapW = math.max(self.viewportW, mapW)
    self.mapH = math.max(self.viewportH, mapH)
    if margin ~= nil then
        self.margin = margin
    end
end

function Camera:setPosition(x, y)
    self.x = x
    self.y = y
    self:clamp()
end

function Camera:clamp()
    -- Clamping avec marge céleste : révèle le ciel ouvert et les nuages en arrière-plan
    local m = self.margin or Camera.SKY_MARGIN
    local minX = self.halfW - m
    local maxX = math.max(minX, self.mapW - self.halfW + m)
    local minY = self.halfH - m
    local maxY = math.max(minY, self.mapH - self.halfH + m)

    self.x = math.max(minX, math.min(maxX, self.x))
    self.y = math.max(minY, math.min(maxY, self.y))
end

function Camera:update(dt, targetX, targetY)
    if not targetX or not targetY then return end

    -- Interpolation linéaire fluide (Lerp) vers la position du joueur
    local smoothFactor = math.min(1.0, dt * self.lerpSpeed)
    self.x = self.x + (targetX - self.x) * smoothFactor
    self.y = self.y + (targetY - self.y) * smoothFactor

    self:clamp()
end

function Camera:attach()
    love.graphics.push()
    -- Translation entière (pixel-perfect) pour éviter tout flou ou scintillement
    local offsetX = -math.floor(self.x - self.halfW)
    local offsetY = -math.floor(self.y - self.halfH)
    love.graphics.translate(offsetX, offsetY)
end

function Camera:detach()
    love.graphics.pop()
end

-- Conversion coordonnées Écran -> Monde
function Camera:toWorld(screenX, screenY)
    local offsetX = math.floor(self.x - self.halfW)
    local offsetY = math.floor(self.y - self.halfH)
    return screenX + offsetX, screenY + offsetY
end

-- Conversion coordonnées Monde -> Écran
function Camera:toScreen(worldX, worldY)
    local offsetX = math.floor(self.x - self.halfW)
    local offsetY = math.floor(self.y - self.halfH)
    return worldX - offsetX, worldY - offsetY
end

return Camera
