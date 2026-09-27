-- src/ui/skin.lua
-- Kit d'interface pixel art "jeu mobile" : panneaux, boutons bombés, jauges, pastilles, bannières.
-- Uniquement des rectangles alignés sur la grille de pixels (net sur 3DS, aucun anti-aliasing).

local Palette = require("src.render.palette")
local PixelFont = require("src.ui.pixel_font")

local Skin = {}

local C = Palette.C
local floor = math.floor

local function set(c, a)
    love.graphics.setColor(c[1], c[2], c[3], a or c[4] or 1)
end

local function rect(c, x, y, w, h, a)
    if w <= 0 or h <= 0 then return end
    set(c, a)
    love.graphics.rectangle("fill", x, y, w, h)
end
Skin.rect = rect

-- Rectangle à coins arrondis (r = 0..3) : un seul octogone convexe. Sans anticrénelage, le
-- pan coupé à 45° se rastérise en escalier de r pixels : même rendu que l'ancien empilement
-- de 2r+1 rectangles, pour 1 appel GPU au lieu de 7 (le HUD en dessinait des dizaines).
local octo = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
function Skin.roundRect(c, x, y, w, h, r, a)
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    if w <= 0 or h <= 0 then return end
    set(c, a)
    if r <= 0 or w <= r * 2 or h <= r * 2 then
        love.graphics.rectangle("fill", x, y, w, h)
        return
    end
    local p = octo
    p[1], p[2] = x + r, y
    p[3], p[4] = x + w - r, y
    p[5], p[6] = x + w, y + r
    p[7], p[8] = x + w, y + h - r
    p[9], p[10] = x + w - r, y + h
    p[11], p[12] = x + r, y + h
    p[13], p[14] = x, y + h - r
    p[15], p[16] = x, y + r
    love.graphics.polygon("fill", p)
end

-- Disque : un seul polygone (l'ancien balayage ligne par ligne coûtait 2r+1 appels GPU,
-- soit ~250 appels pour une icône ronde : c'était la moitié du coût du HUD sur 3DS)
local discSegments = {}
function Skin.disc(c, cx, cy, r, a)
    if r <= 0 then return end
    set(c, a)
    local seg = discSegments[r]
    if not seg then
        seg = math.max(10, math.min(32, floor(r * 1.4)))
        discSegments[r] = seg
    end
    love.graphics.circle("fill", floor(cx) + 0.5, floor(cy) + 0.5, r + 0.5, seg)
end

-- ---------------------------------------------------------------------------
-- Thèmes de couleur (bouton / bandeau)
-- ---------------------------------------------------------------------------
Skin.THEMES = {
    gold   = { main = C.amber,  light = C.yellow,            dark = C.orange, lip = C.rust },
    blue   = { main = C.blue,   light = C.cyan,              dark = C.navy,   lip = Palette.hex("0d3563") },
    green  = { main = C.leaf,   light = Palette.hex("a8e890"), dark = C.moss, lip = C.pine },
    red    = { main = C.red,    light = C.pink,              dark = C.wine,   lip = Palette.hex("6b1622") },
    purple = { main = C.magenta, light = C.pink,             dark = C.plum,   lip = C.umber },
    gray   = { main = C.fog,    light = C.silver,            dark = C.steel,  lip = C.slate },
    dark   = { main = C.slate,  light = C.steel,             dark = C.night,  lip = C.ink },
}

function Skin.theme(name)
    return Skin.THEMES[name] or Skin.THEMES.blue
end

-- ---------------------------------------------------------------------------
-- Panneaux
-- ---------------------------------------------------------------------------
-- style : "dark" (bleu nuit), "raised" (ardoise), "inset" (creux)
function Skin.panel(x, y, w, h, style)
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    Skin.roundRect(C.ink, x, y, w, h, 3)
    if style == "inset" then
        Skin.roundRect(C.ink, x + 1, y + 1, w - 2, h - 2, 2)
        rect(C.night, x + 2, y + 2, w - 4, h - 4)
        rect(C.slate, x + 2, y + h - 2, w - 4, 1)
        return
    end
    local body = (style == "raised") and C.slate or C.night
    local top = (style == "raised") and C.steel or C.slate
    Skin.roundRect(body, x + 1, y + 1, w - 2, h - 2, 2)
    rect(top, x + 3, y + 1, w - 6, 1)
    rect(C.ink, x + 3, y + h - 2, w - 6, 1, 0.45)
end

-- Panneau avec bandeau de titre coloré
function Skin.titledPanel(x, y, w, h, title, themeName)
    Skin.panel(x, y, w, h, "dark")
    local th = Skin.theme(themeName)
    Skin.roundRect(th.dark, x + 1, y + 1, w - 2, 12, 2)
    rect(th.main, x + 3, y + 1, w - 6, 10)
    rect(th.light, x + 3, y + 1, w - 6, 1)
    PixelFont.printf(title, x, y + 3, w, "center", C.white, "tiny")
end

-- ---------------------------------------------------------------------------
-- Boutons bombés (lèvre 3D, reflet, contour encre)
-- ---------------------------------------------------------------------------
function Skin.button(x, y, w, h, themeName, pressed)
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    local th = Skin.theme(themeName)
    local lip = pressed and 1 or 3
    local oy = pressed and 2 or 0
    Skin.roundRect(C.ink, x, y + oy, w, h - oy, 3)
    Skin.roundRect(th.lip, x + 1, y + oy + 1, w - 2, h - oy - 2, 2)
    Skin.roundRect(th.main, x + 1, y + oy + 1, w - 2, h - oy - 1 - lip, 2)
    rect(th.dark, x + 2, y + h - lip - 2, w - 4, 1)
    rect(th.light, x + 3, y + oy + 2, w - 6, 2)
    rect(C.white, x + 3, y + oy + 2, 3, 1, 0.9)
    return oy
end

-- Bouton avec libellé centré (et icône optionnelle)
function Skin.labelButton(x, y, w, h, text, themeName, pressed, iconName)
    local oy = Skin.button(x, y, w, h, themeName, pressed)
    local tw = PixelFont.getWidth(text, "main")
    local total = tw
    if iconName then total = tw + 13 end
    local tx = floor(x + (w - total) / 2)
    local ty = floor(y + oy + (h - 3 - 11) / 2) - 1
    if iconName then
        love.graphics.setColor(1, 1, 1, 1)
        require("src.render.art").draw(iconName, 1, tx + 5, ty + 6)
        tx = tx + 13
    end
    PixelFont.print(text, tx, ty, C.white, "main")
end

-- ---------------------------------------------------------------------------
-- Jauges
-- ---------------------------------------------------------------------------
function Skin.bar(x, y, w, h, ratio, themeName, segments)
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    local th = Skin.theme(themeName)
    ratio = math.max(0, math.min(1, ratio or 0))
    Skin.roundRect(C.ink, x, y, w, h, 2)
    rect(C.night, x + 1, y + 1, w - 2, h - 2)
    rect(C.ink, x + 1, y + 1, w - 2, 1, 0.6)
    local fw = floor((w - 2) * ratio + 0.5)
    if fw > 0 then
        rect(th.main, x + 1, y + 1, fw, h - 2)
        rect(th.light, x + 1, y + 1, fw, 1)
        if h >= 6 then rect(th.light, x + 1, y + 2, fw, 1, 0.45) end
        rect(th.dark, x + 1, y + h - 2, fw, 1)
    end
    if segments and segments > 1 then
        for i = 1, segments - 1 do
            rect(C.ink, x + floor(i * w / segments), y + 1, 1, h - 2, 0.5)
        end
    end
end

-- Pastille arrondie (badge de rareté, niveau, coût)
function Skin.pill(x, y, w, h, themeName, text, font)
    x, y, w, h = floor(x), floor(y), floor(w), floor(h)
    local th = Skin.theme(themeName)
    Skin.roundRect(C.ink, x, y, w, h, 3)
    Skin.roundRect(th.dark, x + 1, y + 1, w - 2, h - 2, 2)
    Skin.roundRect(th.main, x + 1, y + 1, w - 2, h - 3, 2)
    rect(th.light, x + 3, y + 1, w - 6, 1)
    if text then
        local f = font or "tiny"
        local lh = (f == "tiny") and 5 or 7
        local top = (f == "tiny") and 0 or 2
        PixelFont.printf(text, x, floor(y + (h - 1 - lh) / 2) - top, w, "center", C.white, f)
    end
end

-- Bannière / ruban avec pointes repliées
function Skin.ribbon(cx, y, w, h, themeName)
    local th = Skin.theme(themeName)
    local x = floor(cx - w / 2)
    local tail = 10
    -- pans arrière
    for side = 0, 1 do
        local tx = (side == 0) and (x - tail + 2) or (x + w - 2)
        rect(C.ink, tx, y + 4, tail, h)
        rect(th.dark, tx + 1, y + 5, tail - 2, h - 2)
        local notchX = (side == 0) and tx or (tx + tail - 3)
        rect(C.ink, notchX, y + 4 + floor(h / 2) - 1, 3, 2)
    end
    Skin.roundRect(C.ink, x, y, w, h, 2)
    rect(th.lip, x + 1, y + 1, w - 2, h - 2)
    rect(th.main, x + 1, y + 1, w - 2, h - 4)
    rect(th.light, x + 2, y + 2, w - 4, 1)
    rect(th.dark, x + 1, y + h - 4, w - 2, 1)
end

-- Cadre circulaire d'icône (compétences, niveau)
function Skin.iconDisc(cx, cy, r, themeName)
    local th = Skin.theme(themeName)
    Skin.disc(C.ink, cx, cy, r)
    Skin.disc(th.dark, cx, cy, r - 1)
    Skin.disc(th.main, cx, cy - 1, r - 2)
    Skin.disc(C.night, cx, cy, r - 4)
    Skin.disc(C.slate, cx, cy - 1, r - 5)
    Skin.disc(C.night, cx, cy + 1, r - 5)
end

-- Fond d'écran tactile : bleu nuit avec motif diagonal discret (cuit une fois)
local bgCache = {}
function Skin.background(w, h)
    local key = w * 10000 + h
    local cv = bgCache[key]
    -- Pas de Canvas sur 3DS : setCanvas en plein rendu désynchronise la cible de l'écran
    if not cv and love.graphics.newCanvas and not require("src.core.gpu").is3DS then
        local prev = love.graphics.getCanvas()
        local ok; ok, cv = pcall(love.graphics.newCanvas, w, h)
        if not ok or not cv then cv = nil end
        if cv then
            cv:setFilter("nearest", "nearest")
            love.graphics.push()
            love.graphics.origin()
            love.graphics.setCanvas(cv)
            love.graphics.clear(C.ink[1], C.ink[2], C.ink[3], 1)
            set(C.night)
            love.graphics.rectangle("fill", 0, 0, w, h)
            set(Palette.hex("2b3150"))
            for d = -h, w, 8 do
                love.graphics.polygon("fill", d, h, d + 3, h, d + 3 + h, 0, d + h, 0)
            end
            set(C.ink, 0.35)
            love.graphics.rectangle("fill", 0, 0, w, 2)
            love.graphics.rectangle("fill", 0, h - 2, w, 2)
            love.graphics.setCanvas(prev)
            love.graphics.pop()
            bgCache[key] = cv
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
    if cv then
        love.graphics.draw(cv, 0, 0)
    else
        rect(C.night, 0, 0, w, h)
        set(Palette.hex("2b3150"))
        for d = -h, w, 16 do
            love.graphics.polygon("fill", d, h, d + 3, h, d + 3 + h, 0, d + h, 0)
        end
        set(C.ink, 0.35)
        love.graphics.rectangle("fill", 0, 0, w, 2)
        love.graphics.rectangle("fill", 0, h - 2, w, 2)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

return Skin
