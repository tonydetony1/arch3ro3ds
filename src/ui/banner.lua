-- src/ui/banner.lua
-- Bannières de l'écran du haut, façon Archero :
--   * "chapter" : grand ruban doré à l'entrée d'un nouveau chapitre
--   * "boss"    : bandeau rouge "BOSS" + nom du monstre, à l'apparition d'un boss
--                 (titre remplaçable : "CHAMPION" en ambre pour les champions des salles x7)
--   * "clear"   : "SALLE TERMINÉE !" + or gagné dans la salle
--   * "room"    : petit rappel "SALLE 7 / 50" au début de chaque salle
-- Une seule bannière à la fois (la plus récente remplace l'autre). Aucune allocation par image.

local Config = require("src.data.config")
local Palette = require("src.render.palette")
local PixelFont = require("src.ui.pixel_font")
local Skin = require("src.ui.skin")
local Depth = require("src.render.depth")

local C = Palette.C
local floor = math.floor
local TW = Config.TOP_WIDTH

local Banner = {
    kind = nil,
    title = "",
    subtitle = "",
    t = 0,
    duration = 0,
}

local DURATION = { chapter = 2.4, boss = 2.2, clear = 1.6, room = 1.3 }

function Banner.show(kind, title, subtitle, header)
    Banner.kind = kind
    Banner.title = title or ""
    Banner.subtitle = subtitle or ""
    Banner.header = header
    Banner.t = 0
    Banner.duration = DURATION[kind] or 1.5
end

function Banner.clear()
    Banner.kind = nil
end

function Banner.isActive(kind)
    return Banner.kind ~= nil and (kind == nil or Banner.kind == kind)
end

function Banner.update(dt)
    if not Banner.kind then return end
    Banner.t = Banner.t + dt
    if Banner.t >= Banner.duration then Banner.kind = nil end
end

-- Entrée/sortie : glissement rapide avec léger rebond (0 = caché, 1 = en place)
local function slide(t, dur)
    local tin, tout = 0.28, 0.25
    if t < tin then
        local k = t / tin
        return 1 - (1 - k) * (1 - k) * (1 - 2.2 * k)
    elseif t > dur - tout then
        local k = (dur - t) / tout
        return math.max(0, k * k)
    end
    return 1
end

function Banner.draw()
    local kind = Banner.kind
    if not kind then return end
    local k = slide(Banner.t, Banner.duration)
    Depth.push(Depth.TEXT)

    if kind == "room" then
        local y = floor(-18 + 22 * k)
        Skin.roundRect(C.ink, TW / 2 - 52, y, 104, 16, 3, 0.85)
        PixelFont.printf(Banner.title, 0, y + 3, TW, "center", C.white, "main")
    elseif kind == "clear" then
        local y = 84
        local w = floor(260 * k)
        Skin.rect(C.ink, TW / 2 - w / 2, y - 2, w, 38, 0.8)
        Skin.rect(C.leaf, TW / 2 - w / 2, y - 2, w, 2)
        Skin.rect(C.leaf, TW / 2 - w / 2, y + 34, w, 2)
        if k > 0.6 then
            PixelFont.printf(Banner.title, 0, y + 2, TW, "center", C.leaf, "main", 2, "shadow")
            PixelFont.printf(Banner.subtitle, 0, y + 24, TW, "center", C.yellow, "main")
        end
    elseif kind == "boss" then
        local y = 70
        local off = floor((1 - k) * -TW)
        Skin.rect(C.ink, off, y, TW, 56, 0.85)
        Skin.rect(C.wine, off, y + 3, TW, 3)
        Skin.rect(C.wine, off, y + 50, TW, 3)
        Skin.rect(C.red, off, y + 6, TW, 1)
        PixelFont.printf(Banner.header or "BOSS", off, y + 9, TW, "center", Banner.header and C.amber or C.red, "main", 2, "shadow")
        PixelFont.printf(Banner.title, off, y + 32, TW, "center", C.yellow, "main", 1, "shadow")
    else -- chapter
        local y = 62
        local off = floor((1 - k) * TW)
        Skin.ribbon(TW / 2 + off, y, 300, 34, "gold")
        PixelFont.printf(Banner.title, off, y + 3, TW, "center", C.white, "main", 2, "shadow")
        PixelFont.printf(Banner.subtitle, off, y + 42, TW, "center", C.yellow, "main", 1, "shadow")
    end

    Depth.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

-- Barre de vie du boss en haut de l'écran (comme dans Archero)
function Banner.drawBossBar(boss, name)
    if not boss then return end
    local ratio = math.max(0, math.min(1, boss.hp / math.max(1, boss.maxHp)))
    Depth.push(Depth.TEXT)
    local x, y, w = 70, 6, TW - 140
    Skin.bar(x, y, w, 10, ratio, "red", 10)
    PixelFont.printf(name or "BOSS", x, y + 11, w, "center", C.white, "tiny")
    Depth.pop()
end

return Banner
