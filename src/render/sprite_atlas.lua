-- src/render/sprite_atlas.lua
-- Générateur d'atlas de sprites pixel art à partir de grilles de caractères.
-- Chaque sprite est "cuit" une seule fois au chargement dans un Canvas puis dessiné via Quads :
--   * contour 1 px automatique (voisinage 4 directions)
--   * variante "flash" (silhouette blanche) pour le Hit-Flash
--   * variantes de palette (ex : slime en charge, héros alternatifs)
-- Compatible LÖVE 11 et LÖVE Potion (Canvas + Quad uniquement, aucun shader).

local Palette = require("src.render.palette")
local Slice = require("src.core.slice")

local SpriteAtlas = {}
SpriteAtlas.__index = SpriteAtlas

local GAP = 1

local function toColor(c)
    if type(c) == "string" then return Palette.hex(c) end
    return c
end

-- ---------------------------------------------------------------------------
-- Ombrage volumétrique automatique ("look 3D") :
-- carte de hauteur en dôme depuis la silhouette -> normales -> éclairage haut-gauche,
-- occlusion vers le bas, tons froids dans l'ombre et chauds dans la lumière, postérisé.
-- ---------------------------------------------------------------------------
local LX, LY, LZ = -0.48, -0.72, 0.50
do
    local n = math.sqrt(LX * LX + LY * LY + LZ * LZ)
    LX, LY, LZ = LX / n, LY / n, LZ / n
end

local colorCache = {}
local function intern(r, g, b)
    r = math.max(0, math.min(255, math.floor(r * 255 + 0.5)))
    g = math.max(0, math.min(255, math.floor(g * 255 + 0.5)))
    b = math.max(0, math.min(255, math.floor(b * 255 + 0.5)))
    local key = r * 65536 + g * 256 + b
    local c = colorCache[key]
    if not c then
        c = { r / 255, g / 255, b / 255, 1 }
        colorCache[key] = c
    end
    return c
end

-- Couleur ombrée par (couleur source, facteur postérisé) : le résultat ne dépend que de ces
-- deux valeurs, on évite ainsi le mélange et les trois arrondis d'intern() à chaque pixel
local shadeCache = setmetatable({}, { __mode = "k" })
local function shadeColor(c, f)
    local byF = shadeCache[c]
    if not byF then
        byF = {}
        shadeCache[c] = byF
    end
    local out = byF[f]
    if out then return out end
    local r, g, b = c[1], c[2], c[3]
    if f < 1 then
        local k = 1 - f
        r = r * f + k * 0.10
        g = g * f + k * 0.04
        b = b * f + k * 0.22
    else
        local k = (f - 1) * 0.9
        r = r + (1.00 - r) * k
        g = g + (0.96 - g) * k
        b = b + (0.82 - b) * k
    end
    out = intern(r, g, b)
    byF[f] = out
    return out
end

local function shade3d(pix, gw, gh, opts)
    local D = opts.depth or 3
    local strength = opts.strength or 1.0
    local dist = {}
    for y = 1, gh do
        local row = {}
        for x = 1, gw do row[x] = pix[y][x] and 99 or 0 end
        dist[y] = row
    end
    for y = 1, gh do
        for x = 1, gw do
            if dist[y][x] > 0 then
                local up = (y > 1) and dist[y - 1][x] or 0
                local left = (x > 1) and dist[y][x - 1] or 0
                dist[y][x] = math.min(dist[y][x], up + 1, left + 1)
            end
        end
    end
    for y = gh, 1, -1 do
        for x = gw, 1, -1 do
            if dist[y][x] > 0 then
                local down = (y < gh) and dist[y + 1][x] or 0
                local right = (x < gw) and dist[y][x + 1] or 0
                dist[y][x] = math.min(dist[y][x], down + 1, right + 1)
            end
        end
    end
    local function H(x, y)
        if x < 1 or y < 1 or x > gw or y > gh then return 0 end
        local d = dist[y][x]
        if d == 0 then return 0 end
        local t = math.min(d, D) / D
        return 1 - (1 - t) * (1 - t)
    end

    local out = {}
    for y = 1, gh do
        out[y] = {}
        for x = 1, gw do
            local c = pix[y][x]
            if c and not c.flat then
                local gx = (H(x + 1, y) - H(x - 1, y)) * 1.6
                local gy = (H(x, y + 1) - H(x, y - 1)) * 1.6
                local nx, ny, nz = -gx, -gy, 1
                local n = math.sqrt(nx * nx + ny * ny + nz * nz)
                local lam = (nx * LX + ny * LY + nz * LZ) / n
                local vy = (y - 1) / math.max(1, gh - 1)
                local f = 1 + (lam - LZ) * 1.35 * strength - (vy - 0.35) * 0.22 * strength
                f = math.floor(f / 0.08 + 0.5) * 0.08
                out[y][x] = shadeColor(c, f)
            else
                out[y][x] = c
            end
        end
    end
    return out
end

-- Convertit une grille en lignes de pixels colorés (runs horizontaux) avec contour optionnel
local function rasterize(grid, palette, outline, shadeOpts)
    local gw = #grid[1]
    local gh = #grid
    local pad = outline and 1 or 0
    local w, h = gw + pad * 2, gh + pad * 2

    local pix = {}
    for y = 1, h do pix[y] = {} end
    for gy = 1, gh do
        local row = grid[gy]
        for gx = 1, gw do
            local ch = row:sub(gx, gx)
            local col = palette[ch]
            if col then pix[gy + pad][gx + pad] = col end
        end
    end

    if shadeOpts then
        local inner = {}
        for gy = 1, gh do
            inner[gy] = {}
            for gx = 1, gw do inner[gy][gx] = pix[gy + pad][gx + pad] end
        end
        local shaded = shade3d(inner, gw, gh, shadeOpts)
        for gy = 1, gh do
            for gx = 1, gw do pix[gy + pad][gx + pad] = shaded[gy][gx] end
        end
    end

    if outline then
        local marks = {}
        for y = 1, h do
            for x = 1, w do
                if not pix[y][x] then
                    local n = (pix[y - 1] and pix[y - 1][x]) or (pix[y + 1] and pix[y + 1][x])
                        or pix[y][x - 1] or pix[y][x + 1]
                    if n then
                        marks[#marks + 1] = y
                        marks[#marks + 1] = x
                    end
                end
            end
        end
        for i = 1, #marks, 2 do
            pix[marks[i]][marks[i + 1]] = outline
        end
    end

    return pix, w, h
end

local function toRuns(pix, w, h, forceColor)
    local runs = {}
    for y = 1, h do
        local x = 1
        while x <= w do
            local c = pix[y][x]
            if c then
                local c2 = forceColor or c
                local len = 1
                while x + len <= w and pix[y][x + len] and (forceColor or pix[y][x + len] == c) do
                    len = len + 1
                end
                runs[#runs + 1] = { x = x - 1, y = y - 1, len = len, color = c2 }
                x = x + len
            else
                x = x + 1
            end
        end
    end
    return runs
end

function SpriteAtlas.new(width, height)
    local self = setmetatable({}, SpriteAtlas)
    self.w = width
    self.h = height
    self.items = {}
    self.sprites = {}
    self.image = nil
    return self
end

-- def = {
--   frames   = { grid1, grid2, ... },      -- grilles de chaînes (même largeur)
--   palette  = { ["A"] = "ff0000", ... },  -- caractère -> couleur (hex ou table)
--   outline  = "181425" | nil,             -- contour auto
--   flash    = true | nil,                 -- génère la silhouette blanche
--   anchor   = "center" | "bottom" | {x, y},
--   variants = { nom = { ["A"] = "..." } } -- surcharges de palette
--   shade    = { depth = 3, strength = 1 } | nil -- ombrage volumétrique automatique
-- }
-- ou def = { w, h, draw = function(w, h) end, anchor } pour un dessin vectoriel cuit.
function SpriteAtlas:define(name, def)
    local sprite = { frames = {}, flash = nil, variants = {} }
    self.sprites[name] = sprite

    if def.draw then
        local item = { w = def.w, h = def.h, drawFn = def.draw, target = sprite.frames, index = 1, anchor = def.anchor,
            key = name }
        self.items[#self.items + 1] = item
        return sprite
    end

    for fi, grid in ipairs(def.frames) do
        local gw = #grid[1]
        for ri, row in ipairs(grid) do
            if #row ~= gw then
                print(string.format("[SpriteAtlas] '%s' frame %d ligne %d : largeur %d au lieu de %d", name, fi, ri, #row, gw))
            end
        end
    end

    local outline = def.outline and toColor(def.outline) or nil
    local basePal = {}
    for k, v in pairs(def.palette) do basePal[k] = toColor(v) end

    -- setName : identifie le jeu de cadres dans la clé de tri (placement reproductible)
    local function addSet(pal, target, isFlash, setName)
        for i, grid in ipairs(def.frames) do
            local pix, w, h = rasterize(grid, pal, outline, (not isFlash) and def.shade or nil)
            local runs = toRuns(pix, w, h, isFlash and Palette.C.white or nil)
            self.items[#self.items + 1] = {
                w = w, h = h, runs = runs, target = target, index = i,
                anchor = def.anchor, pad = outline and 1 or 0,
                key = name .. "|" .. setName .. "|" .. i,
            }
        end
    end

    addSet(basePal, sprite.frames, false, "f")

    if def.flash then
        sprite.flash = {}
        addSet(basePal, sprite.flash, true, "flash")
    end

    if def.variants then
        for vName, overrides in pairs(def.variants) do
            local pal = {}
            for k, v in pairs(basePal) do pal[k] = v end
            for k, v in pairs(overrides) do pal[k] = toColor(v) end
            sprite.variants[vName] = {}
            addSet(pal, sprite.variants[vName], false, "v:" .. vName)
        end
    end

    return sprite
end

local function anchorOf(item)
    local a = item.anchor
    local pad = item.pad or 0
    if type(a) == "table" then
        return a[1] + pad, a[2] + pad
    elseif a == "bottom" then
        return math.floor(item.w / 2), item.h - 1
    elseif a == "topleft" then
        return 0, 0
    end
    return math.floor(item.w / 2), math.floor(item.h / 2)
end

-- Empaquetage en étagères + rendu dans le Canvas + création des Quads
function SpriteAtlas:bake()
    local order = {}
    for i, it in ipairs(self.items) do order[i] = it end
    -- Ordre total (hauteur, largeur, puis clé unique) : table.sort n'est pas stable et
    -- l'ordre de définition varie (pairs) ; sans clé, chaque précompilation déplaçait des
    -- milliers de sprites et produisait un atlas différent
    table.sort(order, function(a, b)
        if a.h ~= b.h then return a.h > b.h end
        if a.w ~= b.w then return a.w > b.w end
        return (a.key or "") < (b.key or "")
    end)

    local x, y, shelfH = GAP, GAP, 0
    for _, it in ipairs(order) do
        if x + it.w + GAP > self.w then
            x = GAP
            y = y + shelfH + GAP
            shelfH = 0
        end
        assert(y + it.h + GAP <= self.h, "SpriteAtlas trop petit (" .. self.w .. "x" .. self.h .. ")")
        it.ax, it.ay = x, y
        x = x + it.w + GAP
        if it.h > shelfH then shelfH = it.h end
    end

    local imgData = love.image.newImageData(self.w, self.h)

    for _, it in ipairs(order) do
        if it.runs then
            for _, r in ipairs(it.runs) do
                local cr = r.color[1]
                local cg = r.color[2]
                local cb = r.color[3]
                local ca = r.color[4] or 1.0
                local py = it.ay + r.y
                local px_start = it.ax + r.x
                for px = px_start, px_start + r.len - 1 do
                    imgData:setPixel(px, py, cr, cg, cb, ca)
                end
            end
        end
    end

    self.imageData = imgData
    self.image = love.graphics.newImage(imgData)
    self.image:setFilter("nearest", "nearest")

    for _, it in ipairs(self.items) do
        local ox, oy = anchorOf(it)
        it.target[it.index] = {
            quad = love.graphics.newQuad(it.ax, it.ay, it.w, it.h, self.w, self.h),
            w = it.w, h = it.h, ox = ox, oy = oy,
            ax = it.ax, ay = it.ay,
        }
        it.runs = nil
        it.drawFn = nil
    end
    self.items = {}
end

-- Restaure un SpriteAtlas précompilé à partir de ses métadonnées et de l'image PNG
function SpriteAtlas.loadPrebaked(data, image)
    local self = setmetatable({}, SpriteAtlas)
    self.w = data.w
    self.h = data.h
    self.sprites = data.sprites
    self.image = image
    self.items = {}

    local w, h = data.w, data.h
    for _, s in pairs(self.sprites) do
        if s.frames then
            for _, f in ipairs(s.frames) do
                f.quad = love.graphics.newQuad(f.ax, f.ay, f.w, f.h, w, h)
            end
        end
        if s.flash then
            for _, f in ipairs(s.flash) do
                f.quad = love.graphics.newQuad(f.ax, f.ay, f.w, f.h, w, h)
            end
        end
        if s.variants then
            for _, vFrames in pairs(s.variants) do
                for _, f in ipairs(vFrames) do
                    f.quad = love.graphics.newQuad(f.ax, f.ay, f.w, f.h, w, h)
                end
            end
        end
    end
    return self
end

-- Rend une grille (avec contour / ombrage) dans une Image autonome (props générés par salle)
function SpriteAtlas.gridToCanvas(grid, palette, outline, shadeOpts)
    local pal = {}
    for k, v in pairs(palette) do pal[k] = toColor(v) end
    local pix, w, h = rasterize(grid, pal, outline and toColor(outline) or nil, shadeOpts)
    local imgData = love.image.newImageData(w, h)
    for y = 1, h do
        for x = 1, w do
            local c = pix[y][x]
            if c then
                imgData:setPixel(x - 1, y - 1, c[1], c[2], c[3], c[4] or 1)
            end
        end
    end
    local img = love.graphics.newImage(imgData)
    img:setFilter("nearest", "nearest")
    return img, w, h
end

-- Variante rapide de gridToCanvas pour une grille plate (cells[(y - 1) * gw + x] = caractère).
-- Pixels identiques, mais sans grille de chaînes, sans fermeture par pixel et avec la hauteur
-- en dôme précalculée : les blocs de pierre des salles se construisaient en ~0,6 s chacun sur
-- 3DS (Lua interprété), ce qui gelait chaque changement de salle.
local floor, min, max, sqrt = math.floor, math.min, math.max, math.sqrt

-- Distance (4-voisins) au bord de la silhouette, deux passes comme shade3d
local function distanceMap(col, gw, gh)
    local dist = {}
    for i = 1, gw * gh do dist[i] = col[i] and 99 or 0 end
    for y = 1, gh do
        Slice.check()
        local row = (y - 1) * gw
        for x = 1, gw do
            local i = row + x
            local d = dist[i]
            if d > 0 then
                local up = (y > 1) and dist[i - gw] or 0
                local left = (x > 1) and dist[i - 1] or 0
                dist[i] = min(d, up + 1, left + 1)
            end
        end
    end
    for y = gh, 1, -1 do
        Slice.check()
        local row = (y - 1) * gw
        for x = gw, 1, -1 do
            local i = row + x
            local d = dist[i]
            if d > 0 then
                local down = (y < gh) and dist[i + gw] or 0
                local right = (x < gw) and dist[i + 1] or 0
                dist[i] = min(d, down + 1, right + 1)
            end
        end
    end
    return dist
end

-- Ombrage de shade3d sur tableaux plats ; renvoie les couleurs ombrées (false = vide)
local function shadeFlat(col, gw, gh, opts)
    local D = opts.depth or 3
    local strength = opts.strength or 1.0
    local dist = distanceMap(col, gw, gh)
    -- Hauteur en dôme sur une grille bordée de zéros : hm[y * W2 + x + 1], x et y de 0 à g+1
    local W2 = gw + 2
    local hm = {}
    for i = 1, W2 * (gh + 2) do hm[i] = 0 end
    for y = 1, gh do
        local row = (y - 1) * gw
        for x = 1, gw do
            local d = dist[row + x]
            if d ~= 0 then
                local t = min(d, D) / D
                hm[y * W2 + x + 1] = 1 - (1 - t) * (1 - t)
            end
        end
    end
    local out = {}
    local vyDen = max(1, gh - 1)
    for y = 1, gh do
        Slice.check()
        local vy = (y - 1) / vyDen
        local rowTerm = (vy - 0.35) * 0.22 * strength
        -- Normale verticale (gradient nul) : lam == LZ, le facteur ne dépend que de la ligne
        local fFlat = floor((1 - rowTerm) / 0.08 + 0.5) * 0.08
        local row = (y - 1) * gw
        for x = 1, gw do
            local i = row + x
            local c = col[i]
            if c and not c.flat then
                local p = y * W2 + x + 1
                local gx = (hm[p + 1] - hm[p - 1]) * 1.6
                local gy = (hm[p + W2] - hm[p - W2]) * 1.6
                local f
                if gx == 0 and gy == 0 then
                    f = fFlat
                else
                    local nx, ny = -gx, -gy
                    local lam = (nx * LX + ny * LY + LZ) / sqrt(nx * nx + ny * ny + 1)
                    f = 1 + (lam - LZ) * 1.35 * strength - rowTerm
                    f = floor(f / 0.08 + 0.5) * 0.08
                end
                out[i] = shadeColor(c, f)
            else
                out[i] = c
            end
        end
    end
    return out
end

function SpriteAtlas.cellsToImage(cells, gw, gh, palette, outline, shadeOpts)
    local pal = {}
    for k, v in pairs(palette) do pal[k] = toColor(v) end
    local col = {}
    for i = 1, gw * gh do col[i] = pal[cells[i]] or false end
    if shadeOpts then col = shadeFlat(col, gw, gh, shadeOpts) end

    -- Grille finale avec marge de contour : px[y * w + x + 1], x de 0 à w-1
    local pad = outline and 1 or 0
    local w, h = gw + pad * 2, gh + pad * 2
    local px = {}
    for i = 1, w * h do px[i] = false end
    for y = 1, gh do
        local src, dst = (y - 1) * gw, (y - 1 + pad) * w + pad
        for x = 1, gw do px[dst + x] = col[src + x] end
    end
    if outline then
        local oc = toColor(outline)
        local marks = {}
        for y = 0, h - 1 do
            Slice.check()
            for x = 0, w - 1 do
                local i = y * w + x + 1
                if not px[i] and ((y > 0 and px[i - w]) or (y < h - 1 and px[i + w])
                    or (x > 0 and px[i - 1]) or (x < w - 1 and px[i + 1])) then
                    marks[#marks + 1] = i
                end
            end
        end
        for k = 1, #marks do px[marks[k]] = oc end
    end

    local imgData = love.image.newImageData(w, h)
    for y = 0, h - 1 do
        Slice.check()
        local row = y * w
        for x = 0, w - 1 do
            local c = px[row + x + 1]
            if c then imgData:setPixel(x, y, c[1], c[2], c[3], c[4] or 1) end
        end
    end
    local img = love.graphics.newImage(imgData)
    img:setFilter("nearest", "nearest")
    return img, w, h
end

function SpriteAtlas:has(name)
    return self.sprites[name] ~= nil
end

function SpriteAtlas:frameCount(name)
    local s = self.sprites[name]
    return s and #s.frames or 0
end

local function pick(s, frame, flash, variant)
    local frames = s.frames
    if flash and s.flash then
        frames = s.flash
    elseif variant and s.variants and s.variants[variant] then
        frames = s.variants[variant]
    end
    local n = #frames
    return frames[((frame - 1) % n) + 1]
end

-- Dessin pixel-perfect (position arrondie, miroir horizontal optionnel)
local Gpu = nil -- src.core.gpu, chargé à la demande
function SpriteAtlas:draw(name, frame, x, y, flipX, flash, variant)
    local s = self.sprites[name]
    if not s then return end
    local f = pick(s, frame or 1, flash, variant)
    Gpu = Gpu or require("src.core.gpu")
    Gpu.addSprite(self.image, f.quad, math.floor(x + 0.5), math.floor(y + 0.5), 0, flipX and -1 or 1, 1, f.ox, f.oy)
end

-- Dessin avec rotation / échelle (armes orientées, projectiles, icônes agrandies)
function SpriteAtlas:drawEx(name, frame, x, y, r, sx, sy, flash, variant)
    local s = self.sprites[name]
    if not s then return end
    local f = pick(s, frame or 1, flash, variant)
    Gpu = Gpu or require("src.core.gpu")
    Gpu.addSprite(self.image, f.quad, x, y, r or 0, sx or 1, sy or sx or 1, f.ox, f.oy)
end

function SpriteAtlas:getFrame(name, frame, flash, variant)
    local s = self.sprites[name]
    if not s then return nil end
    return pick(s, frame or 1, flash, variant)
end

return SpriteAtlas
