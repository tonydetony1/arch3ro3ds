local BossBrain = require("src.core.boss_brain")
local Bosses = require("src.data.bosses")
local Admin = require("src.data.admin")

local T = {}

local BOSS_TYPES = { "golem", "skeleton_king", "witch", "lava_titan", "storm_drake", "void_watcher" }

-- Contexte factice : enregistre tout ce que le cerveau demande
local function fakeCtx(opts)
    opts = opts or {}
    local seed = 12345
    local ctx = {
        player = { x = 320, y = 400, radius = 9 },
        mapW = 640, mapH = 480,
        shots = {}, lobs = {}, summons = {}, events = {}, cleared = 0, contacts = 0,
        liveShots = opts.liveShots or 0, minions = opts.minions or 0,
    }
    ctx.rng = function()
        seed = (seed * 1664525 + 1013904223) % 4294967296
        return seed / 4294967296
    end
    ctx.fire = function(x, y, angle, speed, damage)
        ctx.shots[#ctx.shots + 1] = { x = x, y = y, angle = angle, speed = speed, damage = damage }
        return true
    end
    ctx.lob = function(x, y, tx, ty, flight, damage, aoe)
        ctx.lobs[#ctx.lobs + 1] = { tx = tx, ty = ty, damage = damage, aoe = aoe }
    end
    ctx.summon = function(t, x, y, hp) ctx.summons[#ctx.summons + 1] = { type = t, hp = hp } end
    ctx.minionCount = function() return ctx.minions end
    ctx.shotCount = function() return ctx.liveShots end
    ctx.clearShots = function() ctx.cleared = ctx.cleared + 1 end
    ctx.steer = function(d, tx, ty, speed, dt)
        local dx, dy = tx - d.x, ty - d.y
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 0.001 then d.x, d.y = d.x + dx / len * speed * dt, d.y + dy / len * speed * dt end
    end
    ctx.move = function(d, vx, vy, dt) d.x, d.y = d.x + vx * dt, d.y + vy * dt end
    ctx.freeSpot = function(x, y) return x, y end
    ctx.contact = function() ctx.contacts = ctx.contacts + 1; return true end
    ctx.fx = function(event, d, a) ctx.events[#ctx.events + 1] = { event = event, a = a } end
    return ctx
end

local function boss(t, chapter)
    return { type = t, x = 320, y = 160, hp = 1000, maxHp = 1000, speed = 30, radius = 20, chapterIndex = chapter or 1, isBoss = true }
end

local function run(d, ctx, seconds, dt)
    dt = dt or 1 / 30
    for _ = 1, math.floor(seconds / dt) do BossBrain.update(d, dt, ctx) end
end

local function countEvents(ctx, name)
    local n = 0
    for _, e in ipairs(ctx.events) do if e.event == name then n = n + 1 end end
    return n
end

T["fiches valides : 3 phases, attaques connues"] = function()
    for _, t in ipairs(BOSS_TYPES) do
        assert(BossBrain.has(t), t)
        local def = Bosses.DEFS[t]
        assert(#def.phases == 3, t)
        for p, phase in ipairs(def.phases) do
            assert(Bosses.MOVES[phase.move.kind], t .. " phase " .. p)
            assert(#phase.attacks >= 1, t .. " phase " .. p)
            for _, name in ipairs(phase.attacks) do
                local a = Bosses.ATTACKS[name]
                assert(a, t .. " : attaque inconnue " .. name)
                assert(BossBrain.EXECUTORS[a.kind], name .. " : type inconnu " .. tostring(a.kind))
                assert(a.windup and a.recover, name)
            end
        end
    end
    assert(not BossBrain.has("splitter"))
end

T["phases à 66 % et 33 %, étourdissement invulnérable puis reprise"] = function()
    local d, ctx = boss("golem"), fakeCtx()
    run(d, ctx, 0.5)
    assert(d.brain.phase == 1)
    d.hp = 650
    BossBrain.update(d, 1 / 30, ctx)
    assert(d.brain.phase == 2 and d.bossInvuln == true)
    assert(ctx.cleared == 1 and countEvents(ctx, "phase") == 1)
    run(d, ctx, Bosses.STAGGER_TIME + 0.1)
    assert(d.bossInvuln == false)
    d.hp = 300
    BossBrain.update(d, 1 / 30, ctx)
    assert(d.brain.phase == 3 and d.isEnraged == true and countEvents(ctx, "phase") == 2)
end

T["saut direct en phase 3 : une seule transition"] = function()
    local d, ctx = boss("golem"), fakeCtx()
    d.hp = 100
    BossBrain.update(d, 1 / 30, ctx)
    assert(d.brain.phase == 3 and countEvents(ctx, "phase") == 1)
end

local function fireAttack(name, ctx, d)
    d = d or boss("golem")
    ctx = ctx or fakeCtx()
    BossBrain.forceAttack(d, name, ctx)
    run(d, ctx, 6)
    return ctx, d
end

T["radial : nombre de tirs x salves"] = function()
    local a = Bosses.ATTACKS.golem_star8
    local ctx = fireAttack("golem_star8")
    assert(#ctx.shots >= a.count * (a.bursts or 1), #ctx.shots)
end

T["fan : tirs visés vers le héros"] = function()
    local d = boss("skeleton_king")
    local ctx = fireAttack("king_volley3", nil, d)
    local a = Bosses.ATTACKS.king_volley3
    assert(#ctx.shots >= a.count)
    local s = ctx.shots[math.ceil(a.count / 2)]
    local toPlayer = math.atan2(ctx.player.y - s.y, ctx.player.x - s.x)
    assert(math.abs(s.angle - toPlayer) < 0.3, s.angle .. " vs " .. toPlayer)
end

T["ring_gap : un trou dans l'anneau"] = function()
    local a = Bosses.ATTACKS.king_ring
    local ctx = fakeCtx()
    local d = boss("skeleton_king")
    BossBrain.forceAttack(d, "king_ring", ctx)
    run(d, ctx, a.windup + 0.1)
    assert(#ctx.shots == a.count - a.gap, #ctx.shots)
end

T["spiral : tirs étalés sur la durée"] = function()
    local a = Bosses.ATTACKS.witch_spiral3
    local ctx = fakeCtx()
    local d = boss("witch")
    BossBrain.forceAttack(d, "witch_spiral3", ctx)
    run(d, ctx, a.windup + a.duration * 0.5)
    local half = #ctx.shots
    run(d, ctx, a.duration)
    assert(half > 0 and #ctx.shots > half * 1.5, half .. " / " .. #ctx.shots)
end

T["rain : bombes autour du héros"] = function()
    local a = Bosses.ATTACKS.golem_rain3
    local ctx = fireAttack("golem_rain3")
    assert(#ctx.lobs == a.count)
    for _, l in ipairs(ctx.lobs) do
        local dx, dy = l.tx - ctx.player.x, l.ty - ctx.player.y
        assert(dx * dx + dy * dy <= (a.spread + 1) ^ 2)
    end
end

T["charge : le boss se déplace et touche une fois par ruée"] = function()
    local d = boss("lava_titan")
    local x0, y0 = d.x, d.y
    local ctx = fireAttack("titan_charge", nil, d)
    assert(math.abs(d.x - x0) + math.abs(d.y - y0) > 40)
    assert(ctx.contacts >= 1 and ctx.contacts <= (Bosses.ATTACKS.titan_charge.repeats or 1))
end

T["summon : respecte le maximum de serviteurs"] = function()
    local ctx = fakeCtx({ minions = 0 })
    fireAttack("king_summon", ctx, boss("skeleton_king"))
    local a = Bosses.ATTACKS.king_summon
    assert(#ctx.summons == math.min(a.count, a.maxMinions))
    local full = fakeCtx({ minions = a.maxMinions })
    fireAttack("king_summon", full, boss("skeleton_king"))
    assert(#full.summons == 0)
end

T["teleport : le boss change de place"] = function()
    local d = boss("witch")
    local x0, y0 = d.x, d.y
    local ctx = fireAttack("witch_blink", nil, d)
    assert(d.x ~= x0 or d.y ~= y0)
    assert(countEvents(ctx, "teleport") >= 1)
end

T["plafond de tirs ennemis"] = function()
    local ctx = fakeCtx({ liveShots = Bosses.MAX_SHOTS })
    fireAttack("golem_star8", ctx)
    assert(#ctx.shots == 0)
    -- une seule attaque (le boss enchaînerait sinon les suivantes)
    local nearly = fakeCtx({ liveShots = Bosses.MAX_SHOTS - 3 })
    local d = boss("golem")
    BossBrain.forceAttack(d, "golem_star8", nearly)
    run(d, nearly, Bosses.ATTACKS.golem_star8.windup + 0.2)
    assert(#nearly.shots == 3, #nearly.shots)
end

T["dégâts selon le chapitre et le réglage admin"] = function()
    Admin.load(nil)
    local base = Bosses.ATTACKS.golem_star8.damage
    assert(BossBrain.damage(base, boss("golem", 1)) == base)
    assert(math.abs(BossBrain.damage(base, boss("golem", 5)) - base * (1 + 4 * Bosses.DAMAGE_PER_CHAPTER)) < 1e-9)
    Admin.set("bossDmgMult", 2)
    assert(math.abs(BossBrain.damage(base, boss("golem", 1)) - base * 2) < 1e-9)
    Admin.load(nil)
end

T["90 s de combat par boss : sans erreur, tous les types exécutés"] = function()
    for _, t in ipairs(BOSS_TYPES) do
        local d, ctx = boss(t, 3), fakeCtx()
        local kinds, seen = {}, {}
        for _, phase in ipairs(Bosses.DEFS[t].phases) do
            for _, name in ipairs(phase.attacks) do kinds[Bosses.ATTACKS[name].kind] = true end
        end
        for step = 1, 90 * 30 do
            -- perd ses PV régulièrement pour traverser les trois phases
            d.hp = math.max(1, d.maxHp * (1 - step / (90 * 30)))
            BossBrain.update(d, 1 / 30, ctx)
            local a = d.brain.attack
            if a and d.brain.state == "exec" then seen[a.kind] = true end
            assert(d.x == d.x and d.y == d.y, t .. " : position invalide")
        end
        assert(d.brain.phase == 3, t)
        for kind in pairs(kinds) do assert(seen[kind], t .. " : " .. kind .. " jamais exécuté") end
    end
end

T["télégraphe disponible pendant la préparation"] = function()
    local d, ctx = boss("golem"), fakeCtx()
    BossBrain.forceAttack(d, "golem_star8", ctx)
    BossBrain.update(d, 0.05, ctx)
    local tg = BossBrain.telegraph(d)
    assert(tg and tg.kind and tg.progress >= 0 and tg.progress <= 1)
end

return T
