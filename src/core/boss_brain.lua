-- src/core/boss_brain.lua
-- Cerveau des boss : 3 phases (src/data/bosses.lua), et pour chaque attaque un télégraphe,
-- une exécution puis une récupération. Module pur : tout effet sur le monde passe par le
-- contexte `ctx` fourni par l'IA (fire, lob, summon, steer, move, contact, freeSpot,
-- shotCount, clearShots, minionCount, fx, rng, player, mapW, mapH).
-- État par boss dans `dummy.brain` (tables réutilisées : aucune allocation par image).

local Bosses = require("src.data.bosses")
local Admin = require("src.data.admin")

local BossBrain = {}

local TAU = math.pi * 2
local sqrt, atan2, cos, sin = math.sqrt, math.atan2, math.cos, math.sin
local floor, min, max = math.floor, math.min, math.max

local KEEP_SPEED = 1.4        -- vitesse de déplacement "keep" (x vitesse du boss)
local STRAFE_SPEED = 0.6
local STRAFE_FLIP = 2.0       -- le boss change de sens de glissade toutes les 2 s
local HOVER_TURN = 0.6        -- radians par seconde autour du centre
local CHASE_STOP = 34         -- distance à laquelle la poursuite s'arrête
local AFTER_STAGGER = 0.4
local FAN_TELEGRAPH_LEN = 120

function BossBrain.has(monsterType)
    return Bosses.DEFS[monsterType] ~= nil
end

function BossBrain.damage(base, d)
    return base * (1 + Bosses.DAMAGE_PER_CHAPTER * ((d.chapterIndex or 1) - 1)) * Admin.get("bossDmgMult")
end

local function brainOf(d)
    local b = d.brain
    if not b then
        b = {
            phase = 1, index = 0, state = "recover", timer = Bosses.INITIAL_DELAY, attack = nil,
            aimX = 0, aimY = 1, exec = {}, strafe = 1, strafeTimer = 0, hoverAngle = 0,
            tg = { kind = nil, x = 0, y = 0, dirX = 0, dirY = 1, length = 0, progress = 0 },
        }
        d.brain = b
        d.bossInvuln = false
    end
    return b
end

local function aimAt(b, d, ctx)
    local dx, dy = ctx.player.x - d.x, ctx.player.y - d.y
    local len = sqrt(dx * dx + dy * dy)
    if len > 0.001 then b.aimX, b.aimY = dx / len, dy / len end
end

local function shotBudget(ctx)
    return max(0, Bosses.MAX_SHOTS - ctx.shotCount())
end

-- Cercle de `count` tirs ; trou de `gapLen` tirs à partir de l'indice `gapFrom` (facultatif)
local function fireRing(d, ctx, a, count, offset, gapFrom, gapLen)
    local budget = shotBudget(ctx)
    local step = TAU / count
    local dmg = BossBrain.damage(a.damage, d)
    for i = 0, count - 1 do
        if not (gapFrom and (i - gapFrom) % count < gapLen) then
            if budget <= 0 then return end
            ctx.fire(d.x, d.y, offset + i * step, a.speed, dmg, Bosses.SHOT_RADIUS, a.color)
            budget = budget - 1
        end
    end
end

-- ---------------------------------------------------------------------------
-- Exécuteurs : start(b, d, ctx, a) prépare, update(b, d, dt, ctx, a) renvoie true à la fin
-- ---------------------------------------------------------------------------
local E = {}

E.radial = {
    start = function(b) b.exec.burst, b.exec.t = 0, 0 end,
    update = function(b, d, dt, ctx, a)
        local e = b.exec
        local bursts = a.bursts or 1
        if e.burst < bursts and e.t >= e.burst * (a.interval or 0) then
            local offset = (a.alternate and e.burst % 2 == 1) and (TAU / a.count / 2) or 0
            fireRing(d, ctx, a, a.count, offset)
            e.burst = e.burst + 1
        end
        e.t = e.t + dt
        return e.burst >= bursts
    end,
}

E.fan = {
    start = function(b) b.exec.burst, b.exec.t = 0, 0 end,
    update = function(b, d, dt, ctx, a)
        local e = b.exec
        local bursts = a.bursts or 1
        if e.burst < bursts and e.t >= e.burst * (a.interval or 0) then
            local base = atan2(b.aimY, b.aimX)
            local budget = shotBudget(ctx)
            local dmg = BossBrain.damage(a.damage, d)
            for i = 1, a.count do
                if budget <= 0 then break end
                ctx.fire(d.x, d.y, base + (i - (a.count + 1) / 2) * a.spread, a.speed, dmg, Bosses.SHOT_RADIUS, a.color)
                budget = budget - 1
            end
            e.burst = e.burst + 1
        end
        e.t = e.t + dt
        return e.burst >= bursts
    end,
}

E.ring_gap = {
    start = function(b) b.exec.burst, b.exec.t = 0, 0 end,
    update = function(b, d, dt, ctx, a)
        local e = b.exec
        local bursts = a.bursts or 1
        if e.burst < bursts and e.t >= e.burst * (a.interval or 0) then
            fireRing(d, ctx, a, a.count, 0, floor(ctx.rng() * a.count), a.gap)
            e.burst = e.burst + 1
        end
        e.t = e.t + dt
        return e.burst >= bursts
    end,
}

E.spiral = {
    start = function(b, d, ctx)
        local e = b.exec
        e.t, e.next, e.angle = 0, 0, ctx.rng() * TAU
    end,
    update = function(b, d, dt, ctx, a)
        local e = b.exec
        if e.t >= e.next and e.t < a.duration then
            fireRing(d, ctx, a, a.arms, e.angle)
            e.angle = e.angle + a.turn * a.interval
            e.next = e.next + a.interval
        end
        e.t = e.t + dt
        return e.t >= a.duration
    end,
}

E.rain = {
    start = function() end,
    update = function(b, d, dt, ctx, a)
        local p = ctx.player
        local dmg = BossBrain.damage(a.damage, d)
        for i = 1, a.count do
            local tx, ty = p.x, p.y
            if i > 1 then
                local r, ang = a.spread * sqrt(ctx.rng()), ctx.rng() * TAU
                tx, ty = p.x + cos(ang) * r, p.y + sin(ang) * r
            end
            ctx.lob(d.x, d.y, tx, ty, a.flight, dmg, a.aoe, a.color)
        end
        return true
    end,
}

E.charge = {
    start = function(b) b.exec.rep, b.exec.t, b.exec.hit = 0, 0, false end,
    update = function(b, d, dt, ctx, a)
        local e = b.exec
        ctx.move(d, b.aimX * a.speed, b.aimY * a.speed, dt)
        if not e.hit and ctx.contact(d, BossBrain.damage(a.damage, d)) then e.hit = true end
        e.t = e.t + dt
        if e.t >= a.duration then
            e.rep = e.rep + 1
            if e.rep >= (a.repeats or 1) then return true end
            aimAt(b, d, ctx)
            e.t, e.hit = 0, false
        end
        return false
    end,
}

E.summon = {
    start = function() end,
    update = function(b, d, dt, ctx, a)
        local n = min(a.count, a.maxMinions - ctx.minionCount())
        for i = 1, n do
            local ang = (i - 0.5) / n * TAU
            ctx.summon(a.type, d.x + cos(ang) * 36, d.y + 14 + sin(ang) * 22, max(1, floor(d.maxHp * a.hpRatio)))
        end
        if n > 0 then ctx.fx("summon", d) end
        return true
    end,
}

E.teleport = {
    start = function() end,
    update = function(b, d, dt, ctx, a)
        local tx, ty
        if a.mode == "center" then
            tx, ty = ctx.mapW / 2, ctx.mapH / 2 - 20
        else
            local ang = ctx.rng() * TAU
            local r = a.minDist + ctx.rng() * (a.maxDist - a.minDist)
            tx = max(40, min(ctx.mapW - 40, ctx.player.x + cos(ang) * r))
            ty = max(50, min(ctx.mapH - 40, ctx.player.y + sin(ang) * r))
        end
        tx, ty = ctx.freeSpot(tx, ty, d.radius or 16)
        ctx.fx("teleport", d, d.x, d.y)
        d.x, d.y = tx, ty
        return true
    end,
}

BossBrain.EXECUTORS = E

-- ---------------------------------------------------------------------------
-- Déplacements (entre deux attaques seulement : un boss s'arrête pour attaquer)
-- ---------------------------------------------------------------------------
local function move(b, d, dt, ctx, mv)
    local p = ctx.player
    local dx, dy = p.x - d.x, p.y - d.y
    local dist = sqrt(dx * dx + dy * dy)
    if mv.kind == "chase" then
        if dist > CHASE_STOP then ctx.steer(d, p.x, p.y, d.speed * (mv.speed or 1), dt) end
    elseif mv.kind == "keep" then
        local speed = d.speed * KEEP_SPEED
        if dist < 0.001 then return end
        if dist < mv.min then
            ctx.move(d, -dx / dist * speed, -dy / dist * speed, dt)
        elseif dist > mv.max then
            ctx.steer(d, p.x, p.y, speed, dt)
        else
            b.strafeTimer = b.strafeTimer + dt
            if b.strafeTimer >= STRAFE_FLIP then b.strafeTimer, b.strafe = 0, -b.strafe end
            ctx.move(d, -dy / dist * speed * STRAFE_SPEED * b.strafe, dx / dist * speed * STRAFE_SPEED * b.strafe, dt)
        end
    elseif mv.kind == "hover" then
        b.hoverAngle = b.hoverAngle + HOVER_TURN * dt
        ctx.steer(d, ctx.mapW / 2 + cos(b.hoverAngle) * mv.radius, ctx.mapH / 2 - 20 + sin(b.hoverAngle) * mv.radius * 0.6,
            d.speed * 1.2, dt)
    else -- anchor
        local cx, cy = ctx.mapW / 2, ctx.mapH / 2 - 20
        local ax, ay = cx - d.x, cy - d.y
        if ax * ax + ay * ay > 36 then ctx.steer(d, cx, cy, d.speed * 1.5, dt) end
    end
end

-- ---------------------------------------------------------------------------
-- Boucle principale
-- ---------------------------------------------------------------------------
local function phaseFor(d)
    local r = d.hp / max(1, d.maxHp)
    if r <= Bosses.PHASE_AT[2] then return 3 end
    if r <= Bosses.PHASE_AT[1] then return 2 end
    return 1
end

local function enterPhase(b, d, ctx, phase)
    b.phase, b.index, b.attack = phase, 0, nil
    b.state, b.timer = "stagger", Bosses.STAGGER_TIME
    d.bossInvuln = true
    if phase == 3 then d.isEnraged = true end
    ctx.clearShots()
    ctx.fx("phase", d, phase)
end

local function beginAttack(b, d, ctx, attack)
    b.attack = attack
    b.state, b.timer = "windup", attack.windup
    aimAt(b, d, ctx)
end

-- Lance tout de suite l'attaque `name` (tests, outils de mise au point)
function BossBrain.forceAttack(d, name, ctx)
    local b = brainOf(d)
    beginAttack(b, d, ctx, Bosses.ATTACKS[name])
end

function BossBrain.update(d, dt, ctx)
    local b = brainOf(d)
    local def = Bosses.DEFS[d.type]
    local target = phaseFor(d)
    if target > b.phase then enterPhase(b, d, ctx, target) end
    local phase = def.phases[b.phase]

    if b.state == "stagger" then
        b.timer = b.timer - dt
        if b.timer <= 0 then
            d.bossInvuln = false
            b.state, b.timer = "recover", AFTER_STAGGER
        end
    elseif b.state == "recover" then
        move(b, d, dt, ctx, phase.move)
        b.timer = b.timer - dt
        if b.timer <= 0 then
            b.index = b.index % #phase.attacks + 1
            beginAttack(b, d, ctx, Bosses.ATTACKS[phase.attacks[b.index]])
        end
    elseif b.state == "windup" then
        b.timer = b.timer - dt
        if b.timer > Bosses.AIM_LOCK then aimAt(b, d, ctx) end
        if b.timer <= 0 then
            b.state = "exec"
            E[b.attack.kind].start(b, d, ctx, b.attack)
        end
    elseif b.state == "exec" then
        if E[b.attack.kind].update(b, d, dt, ctx, b.attack) then
            b.state, b.timer = "recover", b.attack.recover
        end
    end
    return true
end

-- Télégraphe à dessiner pendant la préparation d'une attaque (table réutilisée) ou nil.
-- kind : "line" (éventail, ruée : direction + longueur), "circle" (tirs en cercle),
-- "sparkle" (invocation, téléportation, pluie)
function BossBrain.telegraph(d)
    local b = d.brain
    if not b or b.state ~= "windup" or not b.attack then return nil end
    local a, tg = b.attack, b.tg
    tg.x, tg.y, tg.dirX, tg.dirY = d.x, d.y, b.aimX, b.aimY
    tg.progress = max(0, min(1, 1 - b.timer / a.windup))
    tg.locked = b.timer <= Bosses.AIM_LOCK
    if a.kind == "fan" then
        tg.kind, tg.length = "line", FAN_TELEGRAPH_LEN
    elseif a.kind == "charge" then
        tg.kind, tg.length = "line", a.speed * a.duration
    elseif a.kind == "radial" or a.kind == "ring_gap" or a.kind == "spiral" then
        tg.kind, tg.length = "circle", (d.radius or 16) + 10
    else
        tg.kind, tg.length = "sparkle", 0
    end
    return tg
end

return BossBrain
