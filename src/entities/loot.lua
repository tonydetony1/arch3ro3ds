local Config = require("src.data.config")
local VFX = require("src.render.vfx_manager")

local Loot = {}
Loot.__index = Loot

-- Room in which loot bounces (set by GameState:setupRoom for every room)
Loot.bounds = { w = Config.TOP_WIDTH, h = Config.TOP_HEIGHT }

function Loot.setBounds(w, h)
    Loot.bounds.w, Loot.bounds.h = w, h
end

function Loot.create(index)
    local self = setmetatable({}, Loot)
    self.id = index
    self.x = 0
    self.y = 0
    self.z = 0
    self.vx = 0
    self.vy = 0
    self.vz = 0
    self.gravity = 420
    self.bounces = 2
    self.type = "coin" -- "coin", "xp", "heart", "scroll"
    self.value = 1
    self.isResting = false
    self.isMagnetized = false
    self.magnetSpeed = 160
    self.animTime = 0
    return self
end

function Loot:spawn(x, y, lootType, value)
    self.x = x
    self.y = y
    self.z = 2
    self.type = lootType or "coin"
    self.value = value or 1

    -- Trajectoire parabolique de bond aléatoire
    local angle = math.random() * math.pi * 2
    local hSpeed = math.random(35, 75)
    self.vx = math.cos(angle) * hSpeed
    self.vy = math.sin(angle) * hSpeed
    self.vz = math.random(90, 140)
    self.bounces = 2
    self.isResting = false
    self.isMagnetized = false
    self.magnetSpeed = 160
    self.animTime = math.random() * 5
end

function Loot:magnetize()
    self.isMagnetized = true
    self.isResting = false
end

-- Retourne true pour continuer à vivre, ou false + type + value quand collecté
function Loot:update(dt, playerX, playerY)
    self.animTime = self.animTime + dt * 4

    -- 1. PHYSIQUE DU SAUT ET REBOND AU SOL
    if not self.isResting and not self.isMagnetized then
        self.z = self.z + self.vz * dt
        self.vz = self.vz - self.gravity * dt
        self.x = self.x + self.vx * dt
        self.y = self.y + self.vy * dt

        -- Stay inside the room
        self.x = math.max(24, math.min(Loot.bounds.w - 24, self.x))
        self.y = math.max(36, math.min(Loot.bounds.h - 24, self.y))

        if self.z <= 0 then
            self.z = 0
            if self.bounces > 0 then
                self.bounces = self.bounces - 1
                self.vz = math.abs(self.vz) * 0.45
                self.vx = self.vx * 0.5
                self.vy = self.vy * 0.5
            else
                self.isResting = true
                self.vx = 0
                self.vy = 0
                self.vz = 0
            end
        end
    end

    -- 2. DISTANCE AU JOUEUR & MAGNÉTISME
    local dx = playerX - self.x
    local dy = playerY - self.y
    local distSq = dx * dx + dy * dy

    -- Ramassage automatique si le joueur passe dessus (rayon ~12px)
    if distSq < 144 then
        return false, self.type, self.value
    end

    -- 3. VOL MAGNÉTIQUE VERS LE JOUEUR (Phase Clear ou proximité)
    if self.isMagnetized then
        local dist = math.sqrt(distSq)
        if dist > 0.1 then
            self.magnetSpeed = self.magnetSpeed + dt * 700 -- Accélération exponentielle
            local step = self.magnetSpeed * dt
            if step >= dist then
                -- Atteint le joueur !
                return false, self.type, self.value
            else
                self.x = self.x + (dx / dist) * step
                self.y = self.y + (dy / dist) * step
                self.z = math.max(0, self.z - dt * 30)
            end
        end
    end

    return true
end

function Loot:draw()
    -- 1. OMBRE DYNAMIQUE AU SOL (reste au sol et rétrécit quand le loot saute)
    VFX.drawDynamicShadow(self.x, self.y + 3, 5.5, 2.5, self.z, 0.38)

    -- 2. RENDU DU BUTIN PROCÉDURAL À HAUTEUR Z
    local drawY = self.y - self.z

    if self.type == "coin" then
        -- PIÈCE D'OR : Disque jaune brillant avec reflet
        love.graphics.setColor(0.75, 0.55, 0.05, 1.0)
        love.graphics.circle("fill", self.x, drawY, 4.2)
        love.graphics.setColor(1.00, 0.85, 0.15, 1.0)
        love.graphics.circle("fill", self.x, drawY, 3.5)
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.circle("fill", self.x - 1, drawY - 1, 1.2)

    elseif self.type == "xp" then
        -- GEMME D'XP : Losange émeraude/cyan avec lueur
        love.graphics.setColor(0.1, 0.8, 0.9, 0.3)
        love.graphics.circle("fill", self.x, drawY, 6.0)

        love.graphics.setColor(0.1, 0.9, 0.6, 1.0)
        love.graphics.polygon("fill", self.x, drawY - 4.5, self.x + 3.5, drawY, self.x, drawY + 4.5, self.x - 3.5, drawY)
        love.graphics.setColor(0.8, 1.0, 0.9, 0.9)
        love.graphics.polygon("fill", self.x - 1, drawY - 2.5, self.x + 1, drawY - 2.5, self.x, drawY + 1)

    elseif self.type == "heart" then
        -- CŒUR DE SOIN : Cœur rouge rubis
        love.graphics.setColor(0.9, 0.15, 0.25, 1.0)
        love.graphics.circle("fill", self.x - 2, drawY - 2, 2.5)
        love.graphics.circle("fill", self.x + 2, drawY - 2, 2.5)
        love.graphics.polygon("fill", self.x - 4.2, drawY - 1, self.x + 4.2, drawY - 1, self.x, drawY + 4.5)
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.circle("fill", self.x - 2, drawY - 2.5, 0.8)

    elseif self.type == "scroll" then
        -- PARCHEMIN : Rouleau beige noué d'un ruban rouge
        love.graphics.setColor(0.85, 0.80, 0.65, 1.0)
        love.graphics.rectangle("fill", self.x - 4, drawY - 3, 8, 6, 1, 1)
        love.graphics.setColor(0.85, 0.2, 0.2, 1.0)
        love.graphics.rectangle("fill", self.x - 1, drawY - 3, 2, 6)
    end
end

return Loot
