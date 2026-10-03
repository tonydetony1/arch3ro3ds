-- src/core/perf.lua
-- Mesure du temps processeur par image : logique (update), écran du haut, écran du bas.
-- Activé si le fichier "perf_on" existe dans le dossier de sauvegarde (3DS : sdmc:/3ds/save/arch3ro/)
-- ou avec `--perf` sur PC. Écrit perf_log.txt toutes les 3 secondes.

local Gpu = require("src.core.gpu")

local Perf = {
    enabled = false,
    acc = { update = 0, top = 0, bottom = 0, frames = 0, tops = 0, bottoms = 0 },
    lines = {},
    timer = 0,
    t = 0,
}

local now = love.timer.getTime

function Perf.init(args)
    local on = love.filesystem.getInfo and love.filesystem.getInfo("perf_on") ~= nil
    for _, a in ipairs(args or {}) do
        if a == "--perf" then on = true end
    end
    Perf.enabled = on
    if on then pcall(love.filesystem.write, "perf_log.txt", "") end
end

function Perf.begin()
    Perf.t = now()
    Perf.st = Perf.t
end

-- Sous-sections : temps écoulé depuis la section précédente (Perf.sec("sol") etc.)
Perf.secs = {}
Perf.secOrder = {}
function Perf.sec(name)
    if not Perf.enabled then return end
    local t = now()
    if not Perf.secs[name] then
        Perf.secs[name] = 0
        Perf.secOrder[#Perf.secOrder + 1] = name
    end
    Perf.secs[name] = Perf.secs[name] + (t - (Perf.st or t))
    Perf.st = t
end

-- Ajoute une durée mesurée ailleurs (ex. present() dans la boucle 3DS)
function Perf.add(name, seconds)
    if not Perf.enabled then return end
    if not Perf.secs[name] then
        Perf.secs[name] = 0
        Perf.secOrder[#Perf.secOrder + 1] = name
    end
    Perf.secs[name] = Perf.secs[name] + seconds
end

function Perf.stop(key)
    local a = Perf.acc
    a[key] = a[key] + (now() - Perf.t)
    if key == "top" then a.tops = a.tops + 1 elseif key == "bottom" then a.bottoms = a.bottoms + 1 end
end

-- Événements coûteux signalés par le jeu (ex. "hud" = réenregistrement de la couche fixe)
Perf.events = {}
function Perf.event(name)
    if not Perf.enabled then return end
    Perf.events[name] = (Perf.events[name] or 0) + 1
end

function Perf.frame(dt, stateName)
    local a = Perf.acc
    a.frames = a.frames + 1
    Perf.timer = Perf.timer + dt
    -- Histogramme : images qui ratent la synchro (> 17 ms) ou deux (> 34 ms)
    if dt > 0.0175 then a.slow = (a.slow or 0) + 1 end
    if dt > 0.034 then a.veryslow = (a.veryslow or 0) + 1 end
    if dt > (a.maxdt or 0) then a.maxdt = dt end
    if Perf.timer < 3 then return end
    local st = Gpu.stats
    local parts = {}
    for _, name in ipairs(Perf.secOrder) do
        parts[#parts + 1] = string.format("%s %.1f", name, Perf.secs[name] / a.frames * 1000)
        Perf.secs[name] = 0
    end
    local mem = collectgarbage("count")
    local alloc = (mem - (Perf.lastMem or mem))
    Perf.lastMem = mem
    local line = string.format(
        "[%s] %4.1f FPS  update %5.1f ms  haut %5.1f ms (x%d)  bas %5.1f ms (x%d)  sommets %d  appels %d  rejets %d  RAM %.0f Ko",
        stateName or "?", a.frames / Perf.timer,
        a.update / a.frames * 1000,
        a.top / math.max(1, a.tops) * 1000, a.tops,
        a.bottom / math.max(1, a.bottoms) * 1000, a.bottoms,
        st.vertices, st.calls, st.skipped, collectgarbage("count"))
    local ev = {}
    for k, v in pairs(Perf.events) do
        ev[#ev + 1] = k .. "=" .. v
        Perf.events[k] = nil
    end
    line = line .. string.format("\n    images >17ms : %d  >34ms : %d  pire : %.1f ms  RAM +%.0f Ko  événements : %s",
        a.slow or 0, a.veryslow or 0, (a.maxdt or 0) * 1000, alloc, table.concat(ev, " "))
    line = line .. "\n    sections/image (ms) : " .. table.concat(parts, "  ")
    Perf.lines[#Perf.lines + 1] = line
    if #Perf.lines > 40 then table.remove(Perf.lines, 1) end
    pcall(love.filesystem.write, "perf_log.txt", table.concat(Perf.lines, "\n") .. "\n")
    print(line)
    Perf.timer = 0
    for k in pairs(a) do a[k] = 0 end
end

return Perf
