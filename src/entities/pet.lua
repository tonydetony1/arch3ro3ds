-- src/entities/pet.lua
-- Support companions (spirits / pets) for Arch3ro 3DS
-- They follow the player with a smooth lerp and auto-fire at nearby enemies

local Config = require("src.data.config")
local VFX = require("src.render.vfx_manager")
local Art = require("src.render.art")

local Pet = {}
Pet.__index = Pet

local TWIN_ANGLE = 0.20 -- radians between the two fireballs of Twin Flame

-- Per-pet characteristics, keyed by Forge item id.
-- `damage` is the value of the starting item (level 1): the Forge multiplies it.
local DEFS = {
    bat_companion = {
        type = "laser_bat", damage = 16, cooldown = 1.2, speed = 300, radius = 2.5,
        color = { 0.75, 0.30, 0.95, 1.0 }, sprite = "pet_bat", fps = 10,
    },
    ghost_familiar = {
        type = "ghost_mage", damage = 14, cooldown = 1.2, speed = 300, radius = 2.5,
        color = { 0.35, 0.85, 1.0, 1.0 }, sprite = "pet_ghost", fps = 3,
    },
    dragon_pet = {
        type = "dragon_pet", damage = 22, cooldown = 1.4, speed = 260, radius = 3.5,
        color = { 1.0, 0.45, 0.15, 1.0 }, sprite = "item_pet_dragon", fps = 0, variant = "ember", scale = 1.2,
    },
}
-- Former internal names, still accepted
DEFS.laser_bat = DEFS.bat_companion
DEFS.ghost_mage = DEFS.ghost_familiar

function Pet.getDef(petId)
    return DEFS[petId] or DEFS.bat_companion
end

-- `power`: power of the equipped item (Save.getItemPower), 1.0 for a starting item
function Pet.new(petId, slotIndex, power)
    local self = setmetatable({}, Pet)
    local def = Pet.getDef(petId)
    self.def = def
    self.type = def.type
    self.slotIndex = slotIndex or 1
    self.x = Config.TOP_WIDTH / 2
    self.y = Config.TOP_HEIGHT / 2
    self.fireCooldown = def.cooldown
    self.fireTimer = math.random() * 0.5
    self.animTime = math.random() * 5.0
    self.damage = math.max(1, math.floor(def.damage * (power or 1) + 0.5))
    self.range = 260
    self.radius = 6
    -- Item passives (src/data/item_passives.lua): haste, wall passes, freeze, bounces, burn, twin
    self.haste = 1
    self.wallPasses = 0
    self.freezeChance = 0
    self.bounces = 0
    self.burns = false
    self.twin = false
    -- Reused shot settings (no allocation per shot)
    self.shotData = { projectile_speed = def.speed, damage = self.damage, range = self.range,
        radius = def.radius, color = def.color }
    self.shotExtra = { wallPasses = 0, elements = nil }
    self.fireElements = { fire = true, fireBoost = 0 }
    self.iceElements = { ice = true }
    return self
end

-- One pet shot; `elements` may be nil
function Pet:fireShot(projectilePool, dirX, dirY, elements)
    local proj = projectilePool:obtain()
    if not proj then return end
    local extra = self.shotExtra
    extra.wallPasses = self.wallPasses
    extra.elements = elements
    proj:spawn(self.x + dirX * 6, self.y + dirY * 6, dirX, dirY, self.shotData, false, self.bounces, false, extra)
end

function Pet:update(dt, player, projectilePool, dummyPool)
    self.animTime = self.animTime + dt

    -- 1. Elastic follow (lerp) in formation behind the hero
    local offsetX = (self.slotIndex == 1) and -24 or 24
    local offsetY = -16
    local targetX = player.x + offsetX
    local targetY = player.y + offsetY

    local lerpSpeed = 7.5
    self.x = self.x + (targetX - self.x) * math.min(1.0, dt * lerpSpeed)
    self.y = self.y + (targetY - self.y) * math.min(1.0, dt * lerpSpeed)

    -- 2. Target search and auto-fire
    self.fireTimer = self.fireTimer + dt
    if self.fireTimer >= self.fireCooldown / self.haste and projectilePool and dummyPool and dummyPool.activeCount > 0 then
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
                local elements = nil
                if self.burns then
                    self.fireElements.fireBoost = (player.elements and player.elements.fireBoost) or 0
                    elements = self.fireElements
                elseif self.freezeChance > 0 and math.random() < self.freezeChance then
                    elements = self.iceElements
                end
                self:fireShot(projectilePool, dirX, dirY, elements)
                if self.twin then
                    -- Twin Flame: a second fireball, slightly apart
                    local c, sn = math.cos(TWIN_ANGLE), math.sin(TWIN_ANGLE)
                    self:fireShot(projectilePool, dirX * c - dirY * sn, dirX * sn + dirY * c, elements)
                end
            end
        end
    end
end

-- Draws a pet (combat and hub showcase). Mirroring uses a negative scale: the 8th
-- argument of Art.drawEx is the white flash, not a flip.
function Pet.drawSprite(petId, x, y, time, flipX, scale)
    local def = Pet.getDef(petId)
    local frame = (def.fps > 0) and (math.floor(time * def.fps) % 2 + 1) or 1
    local s = (scale or 1) * (def.scale or 1)
    if s == 1 then
        Art.draw(def.sprite, frame, x, y, flipX, nil, def.variant)
    else
        Art.drawEx(def.sprite, frame, x, y, 0, flipX and -s or s, s, nil, def.variant)
    end
end

function Pet:draw()
    local floatY = math.floor(math.sin(self.animTime * 3.5 + self.slotIndex) * 3 + 0.5)
    VFX.drawDynamicShadow(self.x, self.y + 10, 5, 2, math.abs(floatY) + 6, 0.30)

    love.graphics.setColor(1, 1, 1, 1)
    Pet.drawSprite(self.type, self.x, self.y + floatY, self.animTime, self.slotIndex == 2)
end

return Pet
