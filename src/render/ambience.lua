-- src/render/ambience.lua
-- World ambience on the top screen during a run: fireflies and falling leaves in the forest,
-- drifting sand, crystal glints, rising embers, wind streaks over the sky isles, void motes,
-- golden motes in the angel sanctuary and embers in the devil's den.
--
-- One pre-allocated pool of screen-space particles with a light camera parallax (they read
-- as a layer of air between the camera and the floor). Drawn as pre-coloured atlas pixels
-- (Art.px) inside the effects depth layer: no extra GPU call and no allocation per frame.

local Art = require("src.render.art")
local Config = require("src.data.config")

local Ambience = {}

local MAX = 26
local W, H = Config.TOP_WIDTH, Config.TOP_HEIGHT
local MARGIN = 12           -- particles wrap around a frame slightly larger than the screen
local PARALLAX = 0.35       -- fraction of the camera movement the layer follows
local floor, sin, random = math.floor, math.sin, math.random

-- Per theme index (WorldManager.THEMES): kinds with their share of the pool.
-- vx / vy: speed ranges (px/s), w / h: pixel size, life: seconds, sway: side wave (px),
-- blink: on/off flicker, twinkle: a small cross flashes at the peak of the blink
local LOOKS = {
    [1] = {
        { colors = { "yellow", "amber" }, share = 0.45, vx = { -6, 6 }, vy = { -8, -2 }, w = 2, h = 2,
          life = { 2.5, 4.5 }, sway = 6, blink = true, twinkle = true },
        { colors = { "leaf", "moss" }, share = 0.55, vx = { 6, 16 }, vy = { 10, 22 }, w = 3, h = 2,
          life = { 4, 7 }, sway = 10 },
    },
    [2] = {
        { colors = { "sand", "tan" }, share = 1, vx = { 60, 110 }, vy = { -4, 4 }, w = 3, h = 1, life = { 2, 4 } },
    },
    [3] = {
        { colors = { "cyan", "white", "sky" }, share = 1, vx = { -3, 3 }, vy = { -4, 4 }, w = 2, h = 2,
          life = { 1.5, 3 }, blink = true, twinkle = true },
    },
    [4] = {
        { colors = { "orange", "amber", "yellow" }, share = 1, vx = { -8, 8 }, vy = { -40, -18 }, w = 2, h = 2,
          life = { 1.5, 3 }, sway = 4, blink = true },
    },
    [5] = {
        { colors = { "white", "silver" }, share = 0.7, vx = { -120, -80 }, vy = { -3, 3 }, w = 6, h = 1, life = { 1, 2 } },
        { colors = { "white" }, share = 0.3, vx = { -20, -10 }, vy = { 4, 10 }, w = 2, h = 2, life = { 3, 5 }, sway = 8 },
    },
    [6] = {
        { colors = { "magenta", "pink", "plum" }, share = 1, vx = { -5, 5 }, vy = { -14, -6 }, w = 2, h = 2,
          life = { 2.5, 4.5 }, sway = 5, blink = true, twinkle = true },
    },
    [7] = {
        { colors = { "yellow", "white" }, share = 1, vx = { -4, 4 }, vy = { -12, -5 }, w = 2, h = 2,
          life = { 2.5, 4.5 }, sway = 5, blink = true, twinkle = true },
    },
    [8] = {
        { colors = { "orange", "red", "amber" }, share = 1, vx = { -10, 10 }, vy = { -42, -20 }, w = 2, h = 2,
          life = { 1.5, 3 }, sway = 4, blink = true },
    },
}

local pool = {}
for i = 1, MAX do
    pool[i] = { x = 0, y = 0, vx = 0, vy = 0, life = 0, maxLife = 1, color = "white", w = 1, h = 1,
        sway = 0, blink = false, twinkle = false, phase = 0 }
end
local look = nil
local active = 0

local function between(range)
    return range[1] + random() * (range[2] - range[1])
end

-- (Re)starts a particle; `anywhere` fills the whole screen (room start), otherwise it enters
-- from the edge its motion comes from
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
    p.blink, p.twinkle = kind.blink or false, kind.twinkle or false
    p.phase = random() * 6.28
    if anywhere then
        p.x, p.y = random(0, W), random(0, H)
    else
        p.x = (p.vx > 30) and -MARGIN or ((p.vx < -30) and (W + MARGIN) or random(0, W))
        p.y = (p.vy < -5) and (H + MARGIN) or ((p.vy > 5) and -MARGIN or random(0, H))
    end
end

-- Theme of the new room (nil or an unknown index: no ambience). `scale` follows the
-- battery saver setting (VFX.particleScale).
function Ambience.setLook(themeIndex, scale)
    look = LOOKS[themeIndex]
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
        if p.life <= 0 or p.x < -MARGIN * 2 or p.x > W + MARGIN * 2 or p.y < -MARGIN * 2 or p.y > H + MARGIN * 2 then
            spawn(p, false)
        end
    end
end

-- camX / camY: camera position, for the parallax of the layer
function Ambience.draw(camX, camY)
    if active == 0 then return end
    local t = love.timer.getTime()
    local ox, oy = -(camX or 0) * PARALLAX, -(camY or 0) * PARALLAX
    local spanX, spanY = W + MARGIN * 2, H + MARGIN * 2
    love.graphics.setColor(1, 1, 1, 1)
    for i = 1, active do
        local p = pool[i]
        local visible = true
        local peak = false
        if p.blink then
            local b = sin(t * 3 + p.phase)
            visible = b > -0.35
            peak = b > 0.85
        end
        if visible then
            local x = floor((p.x + ox + sin(t * 1.7 + p.phase) * p.sway) % spanX - MARGIN)
            local y = floor((p.y + oy) % spanY - MARGIN)
            -- Fade out at the end of life by shrinking to a single pixel
            local w, h = p.w, p.h
            if p.life < 0.4 then w, h = 1, 1 end
            Art.px(p.color, x, y, w, h)
            if peak and p.twinkle then
                Art.px(p.color, x - 2, y, w + 4, 1)
                Art.px(p.color, x, y - 2, 1, h + 4)
            end
        end
    end
end

return Ambience
