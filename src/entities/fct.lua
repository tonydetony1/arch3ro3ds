-- src/entities/fct.lua
-- Floating Combat Text (Dégâts flottants style Archero)
-- Poolé universellement pour ZÉRO allocation pendant les combats intenses

local FCT = {}
FCT.__index = FCT

function FCT.create(index)
    local self = setmetatable({}, FCT)
    self.id = index
    self.x = 0
    self.y = 0
    self.vx = 0
    self.vy = 0
    self.text = "0"
    self.isCrit = false
    self.life = 0
    self.maxLife = 0.65
    return self
end

function FCT:spawn(x, y, value, isCrit)
    self.x = x + math.random(-8, 8)
    self.y = y - 10
    self.text = tostring(value)
    self.isCrit = isCrit or false
    self.maxLife = self.isCrit and 0.80 or 0.60
    self.life = self.maxLife
    self.vy = self.isCrit and -65 or -45
    self.vx = math.random(-12, 12)
end

function FCT:update(dt)
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
    self.vy = self.vy + 35 * dt -- Freinage ascendant naturel
    self.life = self.life - dt
    return (self.life > 0)
end

function FCT:draw()
    local progress = 1.0 - (self.life / self.maxLife)
    local alpha = math.max(0, math.min(1.0, self.life / (self.maxLife * 0.4)))

    -- Effet de pop / échelle à l'apparition
    local scale = 1.0
    if progress < 0.25 then
        scale = 0.8 + (progress / 0.25) * 0.4
    else
        scale = 1.2 - ((progress - 0.25) / 0.75) * 0.2
    end
    if self.isCrit then
        scale = scale * 1.3
    end

    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.scale(scale, scale)

    local displayStr = self.isCrit and ("!" .. self.text) or self.text

    -- Ombre portée noire nette pour lisibilité maximale
    love.graphics.setColor(0.05, 0.05, 0.05, alpha * 0.9)
    love.graphics.print(displayStr, -7, -6)
    love.graphics.print(displayStr, -9, -6)
    love.graphics.print(displayStr, -8, -5)
    love.graphics.print(displayStr, -8, -7)

    -- Couleur du texte
    if self.isCrit then
        -- Coup critique : rouge-orangé éclatant
        love.graphics.setColor(1.0, 0.25, 0.15, alpha)
    else
        -- Dégât normal : jaune d'or étincelant
        love.graphics.setColor(1.0, 0.90, 0.25, alpha)
    end
    love.graphics.print(displayStr, -8, -6)

    love.graphics.pop()
end

return FCT
