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
    Perf.lastSpr, Perf.lastCalls = Gpu.counters()
end

-- Sous-sections : temps écoulé depuis la section précédente (Perf.sec("sol") etc.)
Perf.secs = {}
Perf.secOrder = {}
Perf.sprites = {} -- sprites sent in each section (Gpu.counters)
Perf.calls = {}   -- draw calls issued in each section
function Perf.sec(name)
    if not Perf.enabled then return end
    local t = now()
    local spr, calls = Gpu.counters()
    if not Perf.secs[name] then
        Perf.secs[name] = 0
        Perf.sprites[name] = 0
        Perf.calls[name] = 0
        Perf.secOrder[#Perf.secOrder + 1] = name
    end
    local dt = t - (Perf.st or t)
    Perf.secs[name] = Perf.secs[name] + dt
    Perf.cur[name] = (Perf.cur[name] or 0) + dt
    Perf.sprites[name] = Perf.sprites[name] + (spr - (Perf.lastSpr or spr))
    local dc = calls - (Perf.lastCalls or calls)
    if dc > 0 then Perf.calls[name] = Perf.calls[name] + dc end
    Perf.st, Perf.lastSpr, Perf.lastCalls = t, spr, calls
end

-- Ajoute une durée mesurée ailleurs (ex. present() dans la boucle 3DS)
function Perf.add(name, seconds)
    if not Perf.enabled then return end
    if not Perf.secs[name] then
        Perf.secs[name] = 0
        Perf.secOrder[#Perf.secOrder + 1] = name
    end
    Perf.secs[name] = Perf.secs[name] + seconds
    Perf.cur[name] = (Perf.cur[name] or 0) + seconds
end

-- Slow-frame trace: every frame whose CPU work exceeds SLOW_FRAME is kept with its heaviest
-- sections, the memory it allocated and whether a garbage collection cycle ended in it
Perf.cur = {}      -- section times of the frame in progress
Perf.slow = {}     -- last slow frames (text lines)
local SLOW_FRAME = 0.0155
local SLOW_KEEP = 12
local slowRows = {}
local LATE_PERIOD = 0.025 -- a frame period this long missed at least one vertical sync
function Perf.endFrame(busy, drewBottom, period, syncWait)
    if not Perf.enabled then return end
    local mem = collectgarbage("count")
    local last = Perf.frameMem or mem
    Perf.frameMem = mem
    local late = period and period > LATE_PERIOD
    if late then Perf.lateCount = (Perf.lateCount or 0) + 1 end
    if (busy and busy > SLOW_FRAME) or late then
        local n = 0
        for name, v in pairs(Perf.cur) do
            if v >= 0.0004 then
                n = n + 1
                local row = slowRows[n] or {}
                slowRows[n] = row
                row[1], row[2] = name, v
            end
        end
        for i = n + 1, #slowRows do slowRows[i] = nil end
        table.sort(slowRows, function(a, b) return a[2] > b[2] end)
        local parts = {}
        for i = 1, math.min(8, n) do
            parts[i] = string.format("%s %.1f", slowRows[i][1], slowRows[i][2] * 1000)
        end
        local gc = (mem < last) and "  GC" or string.format("  +%.1fKo", mem - last)
        Perf.slow[#Perf.slow + 1] = string.format("    %s %.1f ms (period %.1f, sync %.1f)%s%s : %s",
            late and "late" or "slow", busy * 1000, (period or 0) * 1000, (syncWait or 0) * 1000,
            drewBottom and " [bas]" or "", gc, table.concat(parts, "  "))
        if #Perf.slow > SLOW_KEEP then table.remove(Perf.slow, 1) end
        Perf.slowCount = (Perf.slowCount or 0) + 1
    end
    for k in pairs(Perf.cur) do Perf.cur[k] = 0 end
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
        local spr = (Perf.sprites[name] or 0) / a.frames
        if spr >= 1 then
            parts[#parts + 1] = string.format("%s %.1f [%ds %dc]", name, Perf.secs[name] / a.frames * 1000,
                spr + 0.5, (Perf.calls[name] or 0) / a.frames + 0.5)
        else
            parts[#parts + 1] = string.format("%s %.1f", name, Perf.secs[name] / a.frames * 1000)
        end
        Perf.secs[name] = 0
        if Perf.sprites[name] then Perf.sprites[name], Perf.calls[name] = 0, 0 end
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
    line = line .. string.format("\n    slow frames : %d  late frames : %d", Perf.slowCount or 0, Perf.lateCount or 0)
    Perf.lateCount = 0
    if #Perf.slow > 0 then line = line .. "\n" .. table.concat(Perf.slow, "\n") end

    Perf.slowCount = 0
    for i = #Perf.slow, 1, -1 do Perf.slow[i] = nil end
    Perf.lines[#Perf.lines + 1] = line
    if #Perf.lines > 40 then table.remove(Perf.lines, 1) end
    pcall(love.filesystem.write, "perf_log.txt", table.concat(Perf.lines, "\n") .. "\n")
    print(line)
    Perf.timer = 0
    for k in pairs(a) do a[k] = 0 end
end

return Perf
