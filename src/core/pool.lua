-- src/core/pool.lua
-- Gestionnaire d'Object Pooling universel ultra-performant et ZÉRO-ALLOCATION
-- Conçu spécialement pour le hardware Nintendo 3DS (ARM11 / RAM 64Mo)

local Pool = {}
Pool.__index = Pool

-- Crée un nouveau pool pré-alloué de taille fixe
-- factoryFn: fonction appelée à l'initialisation pour construire la table d'un objet
function Pool.new(maxSize, factoryFn)
    local self = setmetatable({}, Pool)
    self.maxSize = maxSize
    self.items = {}
    self.freeStack = {}
    self.freeCount = maxSize
    self.activeList = {}
    self.activeCount = 0

    -- Pré-allocation complète et statique en mémoire
    for i = 1, maxSize do
        local obj = factoryFn(i)
        obj._poolIndex = i
        obj._activeSlot = 0
        obj.alive = false
        self.items[i] = obj
        self.freeStack[i] = i
        self.activeList[i] = 0
    end

    return self
end

-- Récupère un objet inactif en O(1) sans aucune allocation mémoire
function Pool:obtain()
    if self.freeCount <= 0 then
        -- Pool saturé : on évite tout crash en renvoyant nil (ou log en debug)
        return nil
    end

    -- Dépilement d'un index libre
    local idx = self.freeStack[self.freeCount]
    self.freeCount = self.freeCount - 1

    -- Ajout dans la liste active via swap
    self.activeCount = self.activeCount + 1
    local slot = self.activeCount
    self.activeList[slot] = idx

    local obj = self.items[idx]
    obj._activeSlot = slot
    obj.alive = true

    return obj
end

-- Libère un objet en O(1) et le remet dans la pile libre
function Pool:free(obj)
    if not obj or not obj.alive then return end

    local slot = obj._activeSlot
    local idx = obj._poolIndex

    -- Swap & pop dans la liste des actifs pour garder une séquence contiguë
    local lastSlot = self.activeCount
    if slot ~= lastSlot then
        local lastIdx = self.activeList[lastSlot]
        self.activeList[slot] = lastIdx
        self.items[lastIdx]._activeSlot = slot
    end
    self.activeList[lastSlot] = 0
    self.activeCount = self.activeCount - 1

    -- Empilement dans la pile libre
    self.freeCount = self.freeCount + 1
    self.freeStack[self.freeCount] = idx

    obj.alive = false
    obj._activeSlot = 0
end

-- Réinitialise tous les objets actifs sans détruire les tables
function Pool:clear()
    for i = self.activeCount, 1, -1 do
        local idx = self.activeList[i]
        local obj = self.items[idx]
        obj.alive = false
        obj._activeSlot = 0
        self.freeCount = self.freeCount + 1
        self.freeStack[self.freeCount] = idx
        self.activeList[i] = 0
    end
    self.activeCount = 0
end

-- Met à jour tous les objets actifs en boucle inverse sécurisée (O(N_actifs))
-- Si obj:update(dt, ...) retourne false, l'objet est libéré automatiquement
function Pool:update(dt, ...)
    for i = self.activeCount, 1, -1 do
        local idx = self.activeList[i]
        local obj = self.items[idx]
        if obj.update then
            local keepAlive = obj:update(dt, ...)
            if keepAlive == false then
                self:free(obj)
            end
        end
    end
end

-- Affiche tous les objets actifs sans créer de closure
function Pool:draw(drawFn)
    for i = 1, self.activeCount do
        local idx = self.activeList[i]
        local obj = self.items[idx]
        if drawFn then
            drawFn(obj)
        elseif obj.draw then
            obj:draw()
        end
    end
end

-- Statistiques pour l'overlay de débogage
function Pool:getStats()
    return self.activeCount, self.maxSize
end

return Pool
