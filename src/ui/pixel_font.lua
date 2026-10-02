-- src/ui/pixel_font.lua
-- Police bitmap pixel art avec contour intégré (1 seul appel de dessin par glyphe).
-- UTF-8 (accents français), retour à la ligne avec cache, alignement, troncature "…".
-- Aucune allocation par frame une fois les textes mis en cache (objectif 0 GC sur 3DS).

local Palette = require("src.render.palette")
local Glyphs = require("src.ui.font_glyphs")

local PixelFont = {
    fonts = {},
    image = nil,
    ready = false,
}

local floor = math.floor
local GpuMod = nil -- src.core.gpu (chargé à la demande : évite un cycle de require)
local BATCH_AFTER = 30

-- Couleurs de texte précuites dans l'atlas (lettre colorée + contour encre).
-- Un texte dans une de ces couleurs se dessine en blanc "neutre" : l'auto-batcher de
-- src/core/gpu.lua peut alors fusionner toutes ses lettres en un seul appel GPU (3DS).
local BAKED_COLORS = { "white", "yellow", "silver", "fog", "steel", "cyan", "red", "amber", "leaf", "orange", "ink", "pink" }
PixelFont.BAKED_COLORS = BAKED_COLORS

-- Table couleur -> clé précuite (identité de table, puis couleur précuite la plus proche).
-- Les écrans passent souvent des couleurs RVB libres (ex. {0.98, 0.98, 1}) : on les aimante
-- vers la couleur précuite la plus proche si l'écart est imperceptible, sinon la lettre est
-- teintée (1 appel GPU par lettre). Cache à clés faibles : les tables créées à chaque image
-- ne s'accumulent pas.
local NEAR = 0.13 * 0.13 * 3
local bakedByTable = setmetatable({}, { __mode = "k" })
local bakedList = {}
for _, key in ipairs(BAKED_COLORS) do
    local c = Palette.C[key]
    bakedByTable[c] = key
    bakedList[#bakedList + 1] = { key = key, c = c }
end

local function bakedKey(color)
    if not color then return "white" end
    if (color[4] or 1) < 0.85 then return nil end
    local k = bakedByTable[color]
    if k ~= nil then return k or nil end
    local r, g, b = color[1], color[2], color[3]
    local best, bestD = false, NEAR
    for i = 1, #bakedList do
        local c = bakedList[i].c
        local dr, dg, db = c[1] - r, c[2] - g, c[3] - b
        local d = dr * dr + dg * dg + db * db
        if d < bestD then best, bestD = bakedList[i].key, d end
    end
    bakedByTable[color] = best
    return best or nil
end

-- Décodage UTF-8 sans allocation
local function decode(s, i)
    local c = s:byte(i)
    if not c then return nil, i + 1 end
    if c < 0x80 then
        return c, i + 1
    elseif c < 0xE0 then
        return (c % 0x20) * 0x40 + (s:byte(i + 1) or 0) % 0x40, i + 2
    elseif c < 0xF0 then
        return (c % 0x10) * 0x1000 + ((s:byte(i + 1) or 0) % 0x40) * 0x40 + (s:byte(i + 2) or 0) % 0x40, i + 3
    end
    return (c % 0x08) * 0x40000 + ((s:byte(i + 1) or 0) % 0x40) * 0x1000
        + ((s:byte(i + 2) or 0) % 0x40) * 0x40 + (s:byte(i + 3) or 0) % 0x40, i + 4
end
PixelFont.decode = decode

local function copyRows(g)
    local rows = {}
    for i = 2, #g do rows[#rows + 1] = g[i] end
    return rows
end

-- Fusionne une lettre de base et un accent dans une nouvelle grille
local function compose(base, accent, accentName, isCapital)
    local bY, bRows = base[1], copyRows(base)
    local bW, aW = #bRows[1], #accent[1]
    local aY
    if accentName == "cedil" then
        aY = bY + #bRows
    elseif accentName == "trema" then
        aY = isCapital and 0 or 2
    else
        aY = isCapital and 0 or 1
    end

    local W = math.max(bW, aW)
    local bX = floor((W - bW) / 2)
    local aX = floor((W - aW) / 2)
    local minY = math.min(bY, aY)
    local maxY = math.max(bY + #bRows - 1, aY + #accent - 1)

    local grid = {}
    for y = minY, maxY do
        local row = {}
        for x = 1, W do row[x] = "." end
        grid[y] = row
    end
    local function stamp(rows, ox, oy)
        for ry, line in ipairs(rows) do
            for rx = 1, #line do
                if line:sub(rx, rx) == "#" then grid[oy + ry - 1][ox + rx] = "#" end
            end
        end
    end
    stamp(bRows, bX, bY)
    stamp(accent, aX, aY)

    local out = { minY }
    for y = minY, maxY do out[#out + 1] = table.concat(grid[y]) end
    return out
end

local function defineFont(atlas, id, def)
    local font = { cellH = def.CELL_H, lineH = def.LINE_H, space = def.SPACE, glyphs = {}, pending = {} }
    local white = { ["#"] = Palette.C.white }

    local function add(key, g)
        local cp = decode(key, 1)
        local rows = copyRows(g)
        local base = id .. ":" .. cp
        atlas:define(base .. ":o", { frames = { rows }, palette = white, outline = Palette.C.ink, anchor = "topleft" })
        atlas:define(base .. ":p", { frames = { rows }, palette = white, anchor = "topleft" })
        local nameC = {}
        for _, key in ipairs(BAKED_COLORS) do
            local name = base .. ":c:" .. key
            atlas:define(name, { frames = { rows }, palette = { ["#"] = Palette.C[key] }, outline = Palette.C.ink, anchor = "topleft" })
            nameC[key] = name
        end
        font.pending[cp] = { w = #rows[1], yoff = g[1], nameO = base .. ":o", nameP = base .. ":p", nameC = nameC }
    end

    for key, g in pairs(def.glyphs) do add(key, g) end
    if def.composed then
        for key, spec in pairs(def.composed) do
            local base = def.glyphs[spec[1]]
            local isCap = spec[1]:upper() == spec[1] and spec[1] ~= "ı"
            add(key, compose(base, def.accents[spec[2]], spec[2], isCap))
        end
    end

    PixelFont.fonts[id] = font
end

-- Étape 1 : déclaration des glyphes dans l'atlas partagé (avant bake)
function PixelFont.define(atlas)
    defineFont(atlas, "main", Glyphs.MAIN)
    defineFont(atlas, "tiny", Glyphs.TINY)
    PixelFont.atlas = atlas
end

-- Étape 2 : récupération des quads (après bake)
function PixelFont.finalize(atlas)
    PixelFont.image = atlas.image
    PixelFont.atlas = atlas
    for _, font in pairs(PixelFont.fonts) do
        for cp, p in pairs(font.pending) do
            font.glyphs[cp] = {
                w = p.w,
                yoff = p.yoff,
                o = atlas:getFrame(p.nameO, 1),
                p = atlas:getFrame(p.nameP, 1),
                c = {},
                nameO = p.nameO,
                nameP = p.nameP,
                nameC = p.nameC,
            }
            for key, name in pairs(p.nameC or {}) do
                font.glyphs[cp].c[key] = atlas:getFrame(name, 1)
            end
        end
        font.pending = nil
        font.fallback = font.glyphs[63] -- "?"
    end

    -- TINY : minuscules et accents -> majuscules de base
    local tiny = PixelFont.fonts.tiny
    local main = PixelFont.fonts.main
    for cp = 97, 122 do tiny.glyphs[cp] = tiny.glyphs[cp] or tiny.glyphs[cp - 32] end
    for key, spec in pairs(Glyphs.MAIN.composed) do
        local cp = decode(key, 1)
        local baseCp = decode(spec[1]:upper(), 1)
        if spec[1] == "ı" then baseCp = 73 end
        tiny.glyphs[cp] = tiny.glyphs[cp] or tiny.glyphs[baseCp]
    end
    main.glyphs[0x2019] = main.glyphs[0x2019] or main.glyphs[39]
    PixelFont.ready = true
end

-- Restauration instantanée depuis le bundle précompilé
function PixelFont.loadPrebaked(fontsData, atlas)
    PixelFont.image = atlas.image
    PixelFont.atlas = atlas
    PixelFont.fonts = {}
    for id, fData in pairs(fontsData) do
        local font = {
            cellH = fData.cellH,
            lineH = fData.lineH,
            space = fData.space,
            glyphs = {},
        }
        for cp, g in pairs(fData.glyphs) do
            font.glyphs[cp] = {
                w = g.w,
                yoff = g.yoff,
                o = atlas:getFrame(g.nameO, 1),
                p = atlas:getFrame(g.nameP, 1),
                c = {},
                nameO = g.nameO,
                nameP = g.nameP,
                nameC = g.nameC,
            }
            for key, name in pairs(g.nameC or {}) do
                font.glyphs[cp].c[key] = atlas:getFrame(name, 1)
            end
        end
        font.fallback = font.glyphs[63] -- "?"
        PixelFont.fonts[id] = font
    end

    local tiny = PixelFont.fonts.tiny
    local main = PixelFont.fonts.main
    for cp = 97, 122 do tiny.glyphs[cp] = tiny.glyphs[cp] or tiny.glyphs[cp - 32] end
    for key, spec in pairs(Glyphs.MAIN.composed) do
        local cp = decode(key, 1)
        local baseCp = decode(spec[1]:upper(), 1)
        if spec[1] == "ı" then baseCp = 73 end
        tiny.glyphs[cp] = tiny.glyphs[cp] or tiny.glyphs[baseCp]
    end
    main.glyphs[0x2019] = main.glyphs[0x2019] or main.glyphs[39]
    PixelFont.ready = true
end

-- Initialisation paresseuse : la police vit dans l'atlas partagé (src/render/art.lua)
local function ensureReady()
    if PixelFont.ready then return true end
    local ok, Art = pcall(require, "src.render.art")
    if ok and Art and Art.init then
        Art.init()
    end
    return PixelFont.ready
end

local function getFont(id)
    if not PixelFont.ready then ensureReady() end
    return PixelFont.fonts[id or "main"] or PixelFont.fonts.main
end

function PixelFont.lineHeight(id, scale)
    local f = getFont(id)
    return (f and f.lineH or 12) * (scale or 1)
end

-- Cache de mise en page : layouts[id][text] = { n, width, [k] = { g, dx, dy } } (unités de police)
local layouts = { }
local layoutCount = 0
local LAYOUT_CACHE_MAX = 300

local function layoutOf(f, id, text)
    local byFont = layouts[id]
    if not byFont then
        byFont = {}
        layouts[id] = byFont
    end
    local l = byFont[text]
    if l then return l end
    if layoutCount >= LAYOUT_CACHE_MAX then
        -- Chaînes dynamiques (compteurs) : on repart d'un cache vide plutôt que de grossir sans fin
        layouts = { [id] = {} }
        byFont = layouts[id]
        layoutCount = 0
    end
    l = { n = 0, width = 0, maxWidth = 0 }
    local pen, penY = 0, 0
    local i, n = 1, #text
    while i <= n do
        local cp
        cp, i = decode(text, i)
        if cp == 10 then
            if pen > l.maxWidth then l.maxWidth = pen end
            pen = 0
            penY = penY + f.lineH
        elseif cp == 32 then
            pen = pen + f.space + 1
        else
            local g = f.glyphs[cp] or f.fallback
            if g then
                l.n = l.n + 1
                l[l.n] = { g = g, dx = pen, dy = penY }
                pen = pen + g.w + 1
            end
        end
    end
    l.width = pen
    if pen > l.maxWidth then l.maxWidth = pen end
    byFont[text] = l
    layoutCount = layoutCount + 1
    return l
end

function PixelFont.getWidth(text, id, scale)
    local f = getFont(id)
    if not f then return 0 end
    local s = scale or 1
    local l = layoutOf(f, id or "main", tostring(text))
    return math.max(0, l.maxWidth * s - s)
end

-- style : nil (contour), "plain" (sans contour), "shadow" (contour + ombre portée)
function PixelFont.print(text, x, y, color, id, scale, style)
    if not PixelFont.ready and not ensureReady() then return 0 end
    text = tostring(text)
    local f = getFont(id)
    local s = scale or 1
    local plain = (style == "plain")
    local off = plain and 0 or s
    x = floor(x + 0.5)
    y = floor(y + 0.5)

    if style == "shadow" then
        local c = Palette.C.ink
        PixelFont.print(text, x, y + s, (color and (color[4] or 1) < 1) and { c[1], c[2], c[3], color[4] } or c, id, s, nil)
    end

    -- Couleur précuite : lettres déjà colorées, dessinées en blanc (fusionnables en 1 appel)
    local key = (not plain) and bakedKey(color) or nil
    if key then
        love.graphics.setColor(1, 1, 1, 1)
    elseif color then
        love.graphics.setColor(color[1], color[2], color[3], color[4] or 1)
    else
        love.graphics.setColor(1, 1, 1, 1)
    end

    -- Mise en page mise en cache par (police, texte) : plus de décodage UTF-8 ni de
    -- recherche de glyphe à chaque image (le HUD réaffiche les mêmes chaînes en boucle)
    local layout = layoutOf(f, id or "main", text)

    -- Couleur précuite : la chaîne entière est un SpriteBatch construit une fois,
    -- dessiné en 1 appel GPU sans boucle Lua par lettre
    -- Une chaîne ne reçoit son SpriteBatch qu'après BATCH_AFTER affichages : les chaînes
    -- éphémères (dégâts, compteurs qui défilent) passent lettre par lettre dans le lot
    -- automatique au lieu de créer un SpriteBatch à chaque nouvelle valeur.
    GpuMod = GpuMod or require("src.core.gpu")
    layout.uses = (layout.uses or 0) + 1
    if key and layout.n > 0 and layout.uses > BATCH_AFTER and not GpuMod.isRecording() then
        local bkey = plain and "p" or key
        local batches = layout.batches
        if not batches then
            batches = {}
            layout.batches = batches
        end
        local byScale = batches[s]
        if not byScale then
            byScale = {}
            batches[s] = byScale
        end
        local sb = byScale[bkey]
        if not sb then
            sb = love.graphics.newSpriteBatch(PixelFont.image, layout.n, "static")
            for k = 1, layout.n do
                local e = layout[k]
                local g = e.g
                local fr = plain and g.p or (g.c and g.c[key]) or g.o
                sb:add(fr.quad, e.dx * s, e.dy * s + g.yoff * s, 0, s, s)
            end
            byScale[bkey] = sb
        end
        love.graphics.draw(sb, x - off, y - off)
        return layout.width * s
    end

    local img = PixelFont.image
    local add = GpuMod.addSprite
    local pen = x
    for k = 1, layout.n do
        local e = layout[k]
        local g = e.g
        local fr = plain and g.p or (key and g.c and g.c[key]) or g.o
        pen = x + e.dx * s
        add(img, fr.quad, pen - off, y + e.dy * s + g.yoff * s - off, 0, s, s)
    end
    pen = x + layout.width * s
    return pen - x
end

-- Cache de retour à la ligne : cache[id][scale][limit][text] = lignes
local wrapCache = {}

local function cacheSlot(id, s, limit)
    local a = wrapCache[id]
    if not a then a = {}; wrapCache[id] = a end
    local b = a[s]
    if not b then b = {}; a[s] = b end
    local c = b[limit]
    if not c then c = {}; b[limit] = c end
    return c
end

function PixelFont.wrap(text, limit, id, scale)
    text = tostring(text)
    id = id or "main"
    local s = scale or 1
    local slot = cacheSlot(id, s, limit)
    local lines = slot[text]
    if lines then return lines end

    lines = {}
    for paragraph in (text .. "\n"):gmatch("(.-)\n") do
        local current = ""
        for word in paragraph:gmatch("%S+") do
            local candidate = (current == "") and word or (current .. " " .. word)
            if current == "" or PixelFont.getWidth(candidate, id, s) <= limit then
                current = candidate
            else
                lines[#lines + 1] = current
                current = word
            end
        end
        lines[#lines + 1] = current
    end
    slot[text] = lines
    return lines
end

-- Tronque une ligne pour qu'elle tienne (ajoute "…")
local truncCache = {}
local function truncate(line, limit, id, s)
    local key = truncCache[line]
    if key and key.limit == limit and key.id == id and key.s == s then return key.out end
    local out = line
    while #out > 0 and PixelFont.getWidth(out .. "…", id, s) > limit do
        out = out:sub(1, -2)
        -- évite de couper au milieu d'un caractère UTF-8
        while #out > 0 do
            local b = out:byte(#out)
            if b >= 0x80 and b < 0xC0 then out = out:sub(1, -2) else break end
        end
        local b = out:byte(#out)
        if b and b >= 0xC0 then out = out:sub(1, -2) end
    end
    out = out .. "…"
    truncCache[line] = { limit = limit, id = id, s = s, out = out }
    return out
end

-- Texte multi-lignes aligné ; renvoie le nombre de lignes dessinées
function PixelFont.printf(text, x, y, limit, align, color, id, scale, style, maxLines, lineH)
    local s = scale or 1
    local lines = PixelFont.wrap(text, limit, id, s)
    local lh = lineH or PixelFont.lineHeight(id, s)
    local count = #lines
    if maxLines and count > maxLines then count = maxLines end

    for li = 1, count do
        local line = lines[li]
        if maxLines and li == maxLines and #lines > maxLines then
            line = truncate(line, limit, id or "main", s)
        end
        local w = PixelFont.getWidth(line, id, s)
        local lx = x
        if align == "center" then
            lx = x + floor((limit - w) / 2)
        elseif align == "right" then
            lx = x + limit - w
        end
        PixelFont.print(line, lx, y + (li - 1) * lh, color, id, s, style)
    end
    return count
end

return PixelFont
