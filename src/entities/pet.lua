-- src/entities/pet.lua
-- Familiers de soutien (Spirits / Pets) pour Arch3ro 3ds
-- Suivent le joueur avec un lerp fluide et tirent automatiquement sur les ennemis proches

local Config = require("src.data.config")
local VFX = require("src.render.vfx_manager")
local Art = require("src.render.art")

local Pet = {}
Pet.__index = Pet

function Pet.new(petType, slotIndex)
    local self = setmetatable({}, Pet)
    self.type = petType or "laser_bat" -- "laser_bat" ou "ghost_mage"
    self.slotIndex = slotIndex or 1
    self.x = Config.TOP_WIDTH / 2
    self.y = Config.TOP_HEIGHT / 2
    self.fireCooldown = 1.2
    self.fireTimer = math.random() * 0.5
    self.animTime = math.random() * 5.0
    self.damage = (self.type == "laser_bat") and 16 or 14
    self.range = 260
    self.radius = 6
    return self
end

function Pet:update(dt, player, projectilePool, dummyPool)
    self.animTime = self.animTime + dt

    -- 1. Suivi élastique (Lerp) avec décalage en formation derrière le héros
    local offsetX = (self.slotIndex == 1) and -24 or 24
    local offsetY = -16
    local targetX = player.x + offsetX
    local targetY = player.y + offsetY

    local lerpSpeed = 7.5
    self.x = self.x + (targetX - self.x) * math.min(1.0, dt * lerpSpeed)
    self.y = self.y + (targetY - self.y) * math.min(1.0, dt * lerpSpeed)

    -- 2. Recherche de cible et tir automatique
    self.fireTimer = self.fireTimer + dt
    if self.fireTimer >= self.fireCooldown and projectilePool and dummyPool and dummyPool.activeCount > 0 then
        local closestSq = self.range * self.range
        local bestTarget = nil

        for i = 1, dummyPool.activeCount do
            local dIdx = dummyPool.activeList[i]
            local d = dummyPool.items[dIdx]
            if d and d.alive and not d.isBurrowed then
                local dx = d.x - self.x
                local dy = d.y - self.y
                local dsq = dx * dx + dy * dy
                if dsq < closestSq then
                    closestSq = dsq
                    bestTarget = d
                end
            end
        end

        if bestTarget then
            self.fireTimer = 0
            local bdx = bestTarget.x - self.x
            local bdy = bestTarget.y - self.y
            local dist = math.sqrt(bdx * bdx + bdy * bdy)
            if dist > 1 then
                local dirX = bdx / dist
                local dirY = bdy / dist
                local proj = projectilePool:obtain()
                if proj then
                    local color = (self.type == "laser_bat") and {0.75, 0.30, 0.95, 1.0} or {0.35, 0.85, 1.0, 1.0}
                    local pData = {
                        projectile_speed = 300,
                        damage = self.damage,
                        range = self.range,
                        radius = 2.5,
                        color = color,
                    }
                    proj:spawn(self.x + dirX * 6, self.y + dirY * 6, dirX, dirY, pData, false, 0, false)
                end
            end
        end
    end
end

function Pet:draw()
    local floatY = math.floor(math.sin(self.animTime * 3.5 + self.slotIndex) * 3 + 0.5)
    VFX.drawDynamicShadow(self.x, self.y + 10, 5, 2, math.abs(floatY) + 6, 0.30)

    local name = (self.type == "laser_bat") and "pet_bat" or "pet_ghost"
    local fps = (self.type == "laser_bat") and 10 or 3
    local frame = math.floor(self.animTime * fps) % 2 + 1
    love.graphics.setColor(1, 1, 1, 1)
    Art.draw(name, frame, self.x, self.y + floatY, self.slotIndex == 2)
end

return Pet
