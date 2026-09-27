-- src/dev/bench.lua
-- Banc d'essai PC : `love . --bench [--sim3ds] [--room=N] [--chapter=N]`
-- Lance une partie, joue automatiquement (déplacements + tirs), relève le budget GPU
-- chaque seconde et enregistre des captures dans le dossier de sauvegarde LÖVE.

local Gpu = require("src.core.gpu")

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

function Bench.start(sm)
    Bench.sm = sm
    if Bench.lprof then startLuaProfiler() end
    if Bench.menu then
        print("[BENCH] menu principal")
        return
    end
    sm:switch("game", { mode = "ascension" })
    local g = sm.current
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
    local g = Bench.sm.current
    if g and g.player and not Bench.menu then autopilot(g, Bench.t) end

    local st = Gpu.stats
    if st.vertices > Bench.peakVertices then Bench.peakVertices = st.vertices end
    Bench.skippedTotal = Bench.skippedTotal + st.skipped

    if Bench.t >= Bench.nextReport then
        Bench.nextReport = Bench.nextReport + 1
        local mobs = g and g.dummyPool and g.dummyPool.activeCount or 0
        local projs = g and g.projectilePool and g.projectilePool.activeCount or 0
        print(string.format("[BENCH] t=%2ds sommets=%5d appels=%4d rejets=%d monstres=%d projectiles=%d RAM=%.0fKo",
            math.floor(Bench.t), st.vertices, st.calls, st.skipped, mobs, projs, collectgarbage("count")))
    end

    local shotAt = Bench.shots[Bench.shotIndex]
    if shotAt and Bench.t >= shotAt then
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
        if Bench.lprof then
            debug.sethook()
            local rows, total = {}, 0
            for k, v in pairs(Bench.lprof) do
                rows[#rows + 1] = { k, v }
                if k:sub(1, 3) ~= "FN " then total = total + v end
            end
            table.sort(rows, function(a, b) return a[2] > b[2] end)
            local shown = 0
            for _, r in ipairs(rows) do
                if r[1]:sub(1, 3) == "FN " and shown < 30 then
                    print(string.format("[LPROF] %5.1f %%  %s", r[2] / total * 100, r[1]))
                    shown = shown + 1
                end
            end
        end
        print(string.format("[BENCH] FIN pic=%d/%d rejets cumulés=%d", Bench.peakVertices, Gpu.VERTEX_CAPACITY, Bench.skippedTotal))
        love.event.quit()
    end
end

return Bench
