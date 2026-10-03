local WaveRunner = require("src.core.wave_runner")

local T = {}

local function wave(n)
    local w = {}
    for i = 1, n do w[i] = { type = "slime", id = i } end
    return w
end

T["start renvoie la première vague"] = function()
    local r = WaveRunner.new({ wave(4), wave(3) })
    assert(#r:start() == 4)
    assert(r:currentWave() == 1 and r:total() == 2)
    assert(not r:isDone())
end

T["renforts quand il reste 2 monstres ou moins"] = function()
    local r = WaveRunner.new({ wave(4), wave(3) })
    r:start()
    assert(r:update(0.1, 3, false) == nil)
    local spawns, waveNo = r:update(0.1, 2, false)
    assert(#spawns == 3 and waveNo == 2)
    assert(r:isDone())
end

T["renforts après le délai même avec du monde"] = function()
    local r = WaveRunner.new({ wave(2), wave(2) })
    r:start()
    assert(r:update(WaveRunner.TIMEOUT - 0.5, 5, false) == nil)
    local spawns = r:update(1.0, 5, false)
    assert(spawns and #spawns == 2)
end

T["plafond de monstres actifs"] = function()
    local r = WaveRunner.new({ wave(2), wave(7) })
    r:start()
    local spawns, waveNo = r:update(WaveRunner.TIMEOUT + 1, 2, false)
    assert(#spawns == WaveRunner.MAX_ACTIVE - 2 and waveNo == 2)
    assert(not r:isDone())
    local rest, again = r:update(0.1, 2, false)
    assert(#rest == 2 and again == nil)
    assert(r:isDone())
end

T["pas de renfort pendant une apparition en cours"] = function()
    local r = WaveRunner.new({ wave(1), wave(1) })
    r:start()
    assert(r:update(30, 0, true) == nil)
end

T["sans vague : terminé d'emblée"] = function()
    local r = WaveRunner.new({})
    assert(#r:start() == 0 and r:isDone())
end

T["libellé de vague"] = function()
    local r = WaveRunner.new({ wave(1), wave(1), wave(1) })
    r:start()
    assert(r:label() == "WAVE 1/3")
    r:update(0, 0, false)
    assert(r:label() == "WAVE 2/3")
end

return T
