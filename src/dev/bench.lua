-- src/dev/bench.lua
-- Banc d'essai PC : `love . --bench [--sim3ds] [--room=N] [--chapter=N]`
-- Lance une partie, joue automatiquement (déplacements + tirs), relève le budget GPU
-- chaque seconde et enregistre des captures dans le dossier de sauvegarde LÖVE.

local Gpu = require("src.core.gpu")
local ObstacleManager = require("src.core.obstacle_manager")

local Bench = {
    active = false,
    t = 0,
    nextReport = 1,
    shots = { 1.5, 4, 8 },
    shotIndex = 1,
    duration = 10,
    peakVertices = 0,
    skippedTotal = 0,
    room = 1,
    chapter = 1,
}

function Bench.parse(args)
    for _, a in ipairs(args or {}) do
        if a == "--bench" then Bench.active = true end
        if a == "--profile" then Gpu.profile = {} end
        if a == "--lprof" then Bench.lprof = {} end
        if a == "--menu" then Bench.menu = true end
        if a == "--alloc" then Bench.alloc = {} end
        if a == "--roomload" then Bench.roomload = true end
        local r = a:match("^%-%-room=(%d+)$")
        if r then Bench.room = tonumber(r) end
        local d = a:match("^%-%-duration=(%d+)$")
        if d then Bench.duration = tonumber(d) end
    end
    return Bench.active
end

-- Profil Lua par échantillonnage (JIT coupé : proche du Lua 5.1 interprété de la 3DS)
local function startLuaProfiler()
    if jit then jit.off() end
    local prof = Bench.lprof
    debug.sethook(function()
        local info = debug.getinfo(2, "Sl")
        if not info then return end
        local key = info.short_src .. ":" .. (info.currentline or 0)
        prof[key] = (prof[key] or 0) + 1
        local fn = debug.getinfo(2, "Sn")
        local fkey = "FN " .. (fn.short_src or "?") .. ":" .. (fn.linedefined or 0) .. " " .. tostring(fn.name)
        prof[fkey] = (prof[fkey] or 0) + 1
    end, "", 1000)
end

-- Profil par fonction : chaque fonction des modules src.* est enveloppée et accumule une
-- mesure (Ko alloués ou secondes) pendant son exécution. Inclusif : un appelant compte
-- aussi ses appelés. measure() doit être monotone (GC arrêté pour les allocations).
local function wrapModules(acc, measure)
    local wrapped = {}
    local function wrapTable(t, prefix)
        if type(t) ~= "table" or wrapped[t] then return end
        wrapped[t] = true
        for k, fn in pairs(t) do
            if type(fn) == "function" and type(k) == "string" and prefix ~= "src.dev.bench" then
                local slot = { 0, 0 }
                acc[prefix .. ":" .. k] = slot
                t[k] = function(...)
                    local before = measure()
                    local a, b, c, d, e, f = fn(...)
                    slot[1] = slot[1] + (measure() - before)
                    slot[2] = slot[2] + 1
                    return a, b, c, d, e, f
                end
            end
        end
        local mt = getmetatable(t)
        if mt and type(mt.__index) == "table" then wrapTable(mt.__index, prefix) end
    end
    for name, mod in pairs(package.loaded) do
        if type(name) == "string" and name:sub(1, 4) == "src." then wrapTable(mod, name) end
    end
end

local function sortedRows(acc)
    local rows = {}
    for k, v in pairs(acc) do
        if v[1] > 0 then rows[#rows + 1] = { k, v[1], v[2] } end
    end
    table.sort(rows, function(a, b) return a[2] > b[2] end)
    return rows
end

local function startAllocProfiler()
    if jit then jit.off() end -- Lua 5.1 interprété comme sur 3DS (LuaJIT supprime des allocations)
    wrapModules(Bench.alloc, function() return collectgarbage("count") end)
    collectgarbage("collect")
    collectgarbage("stop")
    Bench.allocFrames = 0
    Bench.allocStart = collectgarbage("count")
end

local function reportAlloc()
    local frames = math.max(1, Bench.allocFrames)
    local rows = sortedRows(Bench.alloc)
    Bench.log(string.format("[ALLOC] total %.2f Ko/image sur %d images", (collectgarbage("count") - Bench.allocStart) / frames, frames))
    for i = 1, math.min(40, #rows) do
        Bench.log(string.format("[ALLOC] %8.3f Ko/image %7.1f appels/image  %s", rows[i][2] / frames, rows[i][3] / frames, rows[i][1]))
    end
end

-- Affiche une ligne et la garde pour bench_log.txt (lisible sur console via la carte SD)
Bench.lines = {}
function Bench.log(line)
    print(line)
    Bench.lines[#Bench.lines + 1] = line
end

-- Temps de construction de chaque salle (JIT coupé : proche du Lua interprété de la 3DS)
-- `love . --bench --sim3ds --roomload [--chapter=N]`
function Bench.reportLuaProfile()
    debug.sethook()
    local rows, total = {}, 0
    for k, v in pairs(Bench.lprof) do
        rows[#rows + 1] = { k, v }
        if k:sub(1, 3) ~= "FN " then total = total + v end
    end
    table.sort(rows, function(a, b) return a[2] > b[2] end)
    local shown, shownLines = 0, 0
    for _, r in ipairs(rows) do
        if r[1]:sub(1, 3) ~= "FN " and shownLines < 25 then
            Bench.log(string.format("[LPROF-L] %5.1f %%  %s", r[2] / total * 100, r[1]))
            shownLines = shownLines + 1
        end
        if r[1]:sub(1, 3) == "FN " and shown < 30 then
            Bench.log(string.format("[LPROF] %5.1f %%  %s", r[2] / total * 100, r[1]))
            shown = shown + 1
        end
    end
end

function Bench.measureRoomLoads(g)
    if jit then jit.off() end
    local timing = {}
    if not Bench.lprof then wrapModules(timing, love.timer.getTime) end
    local worst, total, bgTotal = 0, 0, 0
    local rooms = (g.chapter and g.chapter.roomCount) or 50
    for room = 1, rooms do
        collectgarbage("collect")
        local t0 = love.timer.getTime()
        g:setupRoom(room)
        local ms = (love.timer.getTime() - t0) * 1000
        total = total + ms
        if ms > worst then worst = ms end
        -- Ce que le jeu prépare en fond pendant la salle (hors gel au changement de salle)
        local t1 = love.timer.getTime()
        ObstacleManager.stepPrefetch(math.huge)
        local bg = (love.timer.getTime() - t1) * 1000
        bgTotal = bgTotal + bg
        Bench.log(string.format("[ROOMLOAD] salle %2d : %6.1f ms  (préparé en fond : %6.1f ms)", room, ms, bg))
    end
    if Bench.lprof then Bench.reportLuaProfile() end
    local rows = sortedRows(timing)
    for i = 1, math.min(30, #rows) do
        Bench.log(string.format("[ROOMLOAD] %8.1f ms/salle %6.1f appels/salle  %s", rows[i][2] * 1000 / rooms, rows[i][3] / rooms, rows[i][1]))
    end
    Bench.log(string.format("[ROOMLOAD] moyenne %.1f ms, pire %.1f ms, fond %.1f ms/salle", total / rooms, worst, bgTotal / rooms))
    pcall(love.filesystem.write, "bench_log.txt", table.concat(Bench.lines, "\n") .. "\n")
end

function Bench.start(sm)
    Bench.sm = sm
    if Bench.lprof then startLuaProfiler() end
    if Bench.menu then
        print("[BENCH] menu principal")
        return
    end
    sm:switch("game", { mode = "ascension" })
    local g = sm.current
    if Bench.roomload then
        Bench.measureRoomLoads(g)
        love.event.quit()
        return
    end
    g.hasSpunStartWheel = true -- saute la roue de départ
    g:setupRoom(Bench.room)
    g.isDrafting = false
    if g.arena and g.arena.groundBatch then
        print(string.format("[BENCH] sol : %d sprites, murs : %d sprites, carte %dx%d",
            g.arena.groundBatch:getCount(), g.arena.wallBatch and g.arena.wallBatch:getCount() or 0, g.mapW, g.mapH))
    end
    print(string.format("[BENCH] partie lancée (salle %d, chapitre %d, 3DS simulée : %s)",
        Bench.room, g.chapterIndex, tostring(Gpu.is3DS)))
end

-- Pilote automatique : cercle autour du centre, arrêts réguliers pour tirer
local function autopilot(g, t)
    local p = g.player
    if not p then return end
    local moving = (t % 2.0) < 1.1
    p.benchInputX = moving and math.cos(t * 1.3) or 0
    p.benchInputY = moving and math.sin(t * 1.7) or 0
    if g.isDrafting and g.draftOptions and g.draftOptions[1] then
        local skill = g.draftOptions[1]
        if skill.hooks and skill.hooks.onApply then skill.hooks.onApply(p) end
        table.insert(g.acquiredSkills, skill)
        g.isDrafting = false
    end
    if g.specialRoomManager and g.specialRoomManager.isActive then
        g.specialRoomManager.isActive = false
    end
    p.hp = math.max(p.hp or 1, (p.maxHp or 100) * 0.5) -- le banc ne doit pas mourir
end

function Bench.update(dt)
    if not Bench.active or not Bench.sm then return end
    Bench.t = Bench.t + dt
    Bench.frames = (Bench.frames or 0) + 1
    if Bench.alloc then
        if not Bench.allocStart and Bench.t >= 2 then startAllocProfiler()
        elseif Bench.allocStart then Bench.allocFrames = Bench.allocFrames + 1 end
    end
    local g = Bench.sm.current
    if g and g.player and not Bench.menu then autopilot(g, Bench.t) end

    local st = Gpu.stats
    if st.vertices > Bench.peakVertices then Bench.peakVertices = st.vertices end
    Bench.skippedTotal = Bench.skippedTotal + st.skipped

    if Bench.t >= Bench.nextReport then
        Bench.nextReport = Bench.nextReport + 1
        local mobs = g and g.dummyPool and g.dummyPool.activeCount or 0
        local projs = g and g.projectilePool and g.projectilePool.activeCount or 0
        Bench.log(string.format("[BENCH] t=%2ds sommets=%5d appels=%4d rejets=%d monstres=%d projectiles=%d RAM=%.0fKo",
            math.floor(Bench.t), st.vertices, st.calls, st.skipped, mobs, projs, collectgarbage("count")))
    end

    local shotAt = Bench.shots[Bench.shotIndex]
    -- Captures sur PC uniquement (LÖVE Potion n'a pas captureScreenshot)
    if shotAt and Bench.t >= shotAt and love.graphics.captureScreenshot and not love.graphics.getScreens then
        local name = string.format("bench_%d.png", Bench.shotIndex)
        love.graphics.captureScreenshot(name)
        print("[BENCH] capture " .. love.filesystem.getSaveDirectory() .. "/" .. name)
        Bench.shotIndex = Bench.shotIndex + 1
    end

    if Bench.t >= Bench.duration then
        if Gpu.profile then
            local rows = {}
            for k, v in pairs(Gpu.profile) do rows[#rows + 1] = { k, v[1], v[2] } end
            table.sort(rows, function(a, b) return a[2] > b[2] end)
            local frames = math.max(1, love.timer.getFPS() * 0 + Bench.frames)
            for i = 1, math.min(30, #rows) do
                print(string.format("[PROF] %6.1f appels %7.0f sommets  %s", rows[i][2] / frames, rows[i][3] / frames, rows[i][1]))
            end
        end
        if Bench.lprof then Bench.reportLuaProfile() end
        if Bench.alloc and Bench.allocStart then reportAlloc() end
        Bench.log(string.format("[BENCH] FIN pic=%d/%d rejets cumulés=%d, %d images en %.1f s (%.1f FPS)",
            Bench.peakVertices, Gpu.VERTEX_CAPACITY, Bench.skippedTotal, Bench.frames, Bench.t, Bench.frames / Bench.t))
        pcall(love.filesystem.write, "bench_log.txt", table.concat(Bench.lines, "\n") .. "\n")
        love.event.quit()
    end
end

return Bench
