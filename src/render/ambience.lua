-- src/render/ambience.lua
-- World ambience during a run: falling leaves in the forest, sand blown across the desert,
-- crystal dust in the caverns, rising embers, wind streaks over the sky isles and drifting
-- motes in the void city.
--
-- The particles belong to the room (world coordinates, drawn under the camera), so they
-- scroll with the floor when the hero moves instead of hanging in front of the screen like
-- stars. Each one fades in and out by its size, without blinking. One pre-allocated pool,
-- drawn as pre-coloured atlas pixels (Art.px): no extra GPU call, no allocation per frame.

local Art = require("src.render.art")

local Ambience = {}

local MAX = 14
local MARGIN = 16           -- particles wrap around a frame slightly larger than the room
local FADE_IN, FADE_OUT = 0.35, 0.45 -- seconds drawn as a single pixel at birth and death
local floor, sin, random = math.floor, math.sin, math.random

-- Per theme index (WorldManager.THEMES): kinds with their share of the pool.
-- vx / vy: speed ranges (px/s), w / h: pixel size, life: seconds, sway: side wave (px)
local LOOKS = {
    [1] = { -- forest: leaves drifting down
        { colors = { "leaf", "moss" }, share = 1, vx = { 6, 16 }, vy = { 12, 22 }, w = 3, h = 2,
          life = { 5, 8 }, sway = 8 },
    },
    [2] = { -- desert: sand blown across
        { colors = { "sand", "tan" }, share = 1, vx = { 70, 120 }, vy = { -3, 3 }, w = 3, h = 1, life = { 3, 5 } },
    },
    [3] = { -- caverns: crystal dust settling
        { colors = { "cyan", "sky" }, share = 1, vx = { -3, 3 }, vy = { 6, 12 }, w = 1, h = 2,
          life = { 4, 7 }, sway = 3 },
    },
    [4] = { -- volcano: embers rising
        { colors = { "orange", "amber" }, share = 1, vx = { -8, 8 }, vy = { -36, -18 }, w = 2, h = 2,
          life = { 2, 3.5 }, sway = 4 },
    },
    [5] = { -- sky isles: wind streaks
        { colors = { "white", "silver" }, share = 1, vx = { -120, -80 }, vy = { -3, 3 }, w = 6, h = 1, life = { 1.5, 2.5 } },
    },
    [6] = { -- void city: motes drifting up
        { colors = { "magenta", "plum" }, share = 1, vx = { -5, 5 }, vy = { -14, -6 }, w = 2, h = 2,
          life = { 3, 5 }, sway = 5 },
    },
    [7] = { -- angel sanctuary: golden motes
        { colors = { "yellow", "white" }, share = 1, vx = { -4, 4 }, vy = { -12, -5 }, w = 2, h = 2,
          life = { 3, 5 }, sway = 5 },
    },
    [8] = { -- devil's den: embers
        { colors = { "orange", "red" }, share = 1, vx = { -10, 10 }, vy = { -40, -20 }, w = 2, h = 2,
          life = { 2, 3.5 }, sway = 4 },
    },
}

local pool = {}
for i = 1, MAX do
    pool[i] = { x = 0, y = 0, vx = 0, vy = 0, life = 0, maxLife = 1, color = "white", w = 1, h = 1,
        sway = 0, phase = 0 }
end
local look = nil
local active = 0
local roomW, roomH = 400, 240

local function between(range)
    return range[1] + random() * (range[2] - range[1])
end

-- (Re)starts a particle; `anywhere` scatters it over the whole room (room start), otherwise it
-- enters from the side its motion comes from
local function spawn(p, anywhere)
    local kinds = look
    local r, kind = random(), kinds[#kinds]
    for i = 1, #kinds do
        if r <= kinds[i].share then kind = kinds[i]; break end
        r = r - kinds[i].share
    end
    p.vx, p.vy = between(kind.vx), between(kind.vy)
    p.maxLife = between(kind.life)
    p.life = anywhere and p.maxLife * random() or p.maxLife
    p.color = kind.colors[random(1, #kind.colors)]
    p.w, p.h = kind.w, kind.h
    p.sway = kind.sway or 0
    p.phase = random() * 6.28
    if anywhere then
        p.x, p.y = random(0, roomW), random(0, roomH)
    else
        p.x = (p.vx > 30) and -MARGIN or ((p.vx < -30) and (roomW + MARGIN) or random(0, roomW))
        p.y = (p.vy < -5) and (roomH + MARGIN) or ((p.vy > 5) and -MARGIN or random(0, roomH))
    end
end

-- Theme and size of the new room (nil or an unknown theme: no ambience). `scale` follows the
-- battery saver setting (VFX.particleScale).
function Ambience.setLook(themeIndex, scale, mapW, mapH)
    look = LOOKS[themeIndex]
    roomW, roomH = mapW or roomW, mapH or roomH
    active = look and math.max(0, math.min(MAX, floor(MAX * (scale or 1) + 0.5))) or 0
    for i = 1, active do spawn(pool[i], true) end
end

function Ambience.clear()
    look, active = nil, 0
end

function Ambience.update(dt)
    for i = 1, active do
        local p = pool[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt
        if p.life <= 0 or p.x < -MARGIN * 2 or p.x > roomW + MARGIN * 2
            or p.y < -MARGIN * 2 or p.y > roomH + MARGIN * 2 then
            spawn(p, false)
        end
    end
end

-- Drawn in world coordinates, between camera:attach() and camera:detach()
function Ambience.draw()
    if active == 0 then return end
    local t = love.timer.getTime()
    love.graphics.setColor(1, 1, 1, 1)
    for i = 1, active do
        local p = pool[i]
        local x = floor(p.x + sin(t * 1.7 + p.phase) * p.sway)
        local y = floor(p.y)
        -- Born and dying as a single pixel: a soft fade without alpha (keeps the batch)
        local w, h = p.w, p.h
        if p.life < FADE_OUT or p.maxLife - p.life < FADE_IN then w, h = 1, 1 end
        Art.px(p.color, x, y, w, h)
    end
end

return Ambience
