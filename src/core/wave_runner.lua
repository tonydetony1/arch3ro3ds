-- src/core/wave_runner.lua
-- Déroulement des vagues d'une salle : la suivante arrive quand il ne reste que
-- REINFORCE_AT monstres (ou après TIMEOUT secondes), sans jamais dépasser MAX_ACTIVE
-- monstres en vie ; le surplus attend le déclenchement suivant. Module pur.

local WaveRunner = {
    REINFORCE_AT = 2,
    TIMEOUT = 14,
    MAX_ACTIVE = 7,
}
WaveRunner.__index = WaveRunner

function WaveRunner.new(waves)
    return setmetatable({ waves = waves or {}, index = 1, queue = nil, timer = 0, labelText = nil }, WaveRunner)
end

local function setLabel(self)
    self.labelText = string.format("WAVE %d/%d", self:currentWave(), self:total())
end

-- Première vague (déjà composée), à faire apparaître immédiatement par l'appelant
function WaveRunner:start()
    local first = self.waves[1] or {}
    self.index = 2
    self.timer = 0
    setLabel(self)
    return first
end

-- alive : monstres en vie ; busy : une apparition est déjà en cours (runes au sol).
-- Renvoie (liste de monstres, numéro de la nouvelle vague ou nil) ou nil.
function WaveRunner:update(dt, alive, busy)
    if busy or self:isDone() then return nil end
    self.timer = self.timer + dt
    if alive > WaveRunner.REINFORCE_AT and self.timer < WaveRunner.TIMEOUT then return nil end
    local room = WaveRunner.MAX_ACTIVE - alive
    if room <= 0 then return nil end

    local newWave = nil
    if not self.queue then
        self.queue = {}
        for i, s in ipairs(self.waves[self.index]) do self.queue[i] = s end
        newWave = self.index
        self.index = self.index + 1
        setLabel(self)
    end
    local out = {}
    while #out < room and #self.queue > 0 do
        out[#out + 1] = table.remove(self.queue, 1)
    end
    if #self.queue == 0 then self.queue = nil end
    self.timer = 0
    return out, newWave
end

function WaveRunner:isDone()
    return self.queue == nil and self.index > #self.waves
end

function WaveRunner:currentWave()
    return math.min(math.max(1, self.index - 1), math.max(1, #self.waves))
end

function WaveRunner:total()
    return #self.waves
end

function WaveRunner:label()
    return self.labelText
end

return WaveRunner
