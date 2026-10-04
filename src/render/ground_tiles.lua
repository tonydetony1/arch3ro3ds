-- src/render/ground_tiles.lua
-- Jeu de tuiles du sol (64x64), précalculé dans l'atlas par tools/bake.
--
-- Pourquoi : sur 3DS, LÖVE Potion recopie chaque sommet de chaque sprite à chaque image.
-- Le sol était fait de ~400 petits sprites (taches d'herbe, touffes, cailloux) : 4 ms par
-- image sur Old 3DS. Le Canvas ne peut pas servir de cache (bug LÖVE Potion #276 : un Canvas
-- s'affiche toujours en 0,0). On compose donc à la compilation, pour chaque thème, quelques
-- variantes de tuiles contenant déjà la couleur du sol, les taches et les détails : à
-- l'écran, ~35 tuiles au lieu de ~400 sprites.
--
-- Les motifs restent entièrement à l'intérieur de chaque tuile (marge), pour que deux
-- variantes différentes se raccordent sans couture : leurs bords sont de la couleur du sol.

local GroundTiles = {
    SIZE = 64,
    VARIANTS = 6,
    THEMES = 8, -- 6 chapitres + sanctuaires de l'Ange (7) et du Démon (8)
}

function GroundTiles.name(themeIndex, variant)
    return "ground_" .. themeIndex .. "_" .. variant
end

-- ----------------------------------------------------------------------------
-- Précompilation (tools/bake, sur PC uniquement)
-- ----------------------------------------------------------------------------
local function hexColor(h)
    return tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255
end

local function makeRng(seed)
    local s = seed % 4294967296
    return function()
        s = (s * 1664525 + 1013904223) % 4294967296
        return s / 4294967296
    end
end

-- Cadre d'un sprite de l'atlas cuit, avec variante de palette du thème si elle existe
local function frameOf(atlas, name, variant)
    local s = atlas.sprites[name]
    if not s then return nil end
    local frames = (variant and s.variants and s.variants[variant]) or s.frames
    return frames and frames[1]
end

-- Copie un sprite de l'atlas dans la tuile (mélange alpha), centré en (cx, cy)
local function stamp(dst, src, f, tx, ty, cx, cy, size)
    local x0 = math.floor(cx - f.w / 2)
    local y0 = math.floor(cy - f.h / 2)
    for y = 0, f.h - 1 do
        for x = 0, f.w - 1 do
            local px, py = x0 + x, y0 + y
            if px >= 0 and py >= 0 and px < size and py < size then
                local r, g, b, a = src:getPixel(f.ax + x, f.ay + y)
                if a > 0 then
                    local dr, dg, db = dst:getPixel(tx + px, ty + py)
                    dst:setPixel(tx + px, ty + py, r * a + dr * (1 - a), g * a + dg * (1 - a), b * a + db * (1 - a), 1)
                end
            end
        end
    end
end

-- Compose toutes les tuiles dans `dst` (ImageData de l'atlas agrandi) à partir de y = originY.
-- Renvoie la table { nom = { frames = { {ax, ay, w, h, ox, oy} } } } à fusionner dans l'atlas.
function GroundTiles.bake(atlas, dst, originY)
    local WorldManager = require("src.core.world_manager")
    local size = GroundTiles.SIZE
    local margin = 10
    local perRow = math.floor(dst:getWidth() / size)
    local src = atlas.imageData
    local out = {}
    local n = 0
    for ti = 1, GroundTiles.THEMES do
        local theme = WorldManager.getTheme(ti)
        local gr, gg, gb = hexColor(theme.ground)
        for v = 1, GroundTiles.VARIANTS do
            local tx = (n % perRow) * size
            local ty = originY + math.floor(n / perRow) * size
            n = n + 1
            for y = 0, size - 1 do
                for x = 0, size - 1 do dst:setPixel(tx + x, ty + y, gr, gg, gb, 1) end
            end
            local rng = makeRng(ti * 7919 + v * 104729)
            local function place(name)
                local f = frameOf(atlas, name, theme.variant)
                if not f then return end
                local hw, hh = math.ceil(f.w / 2), math.ceil(f.h / 2)
                local lo, hi = margin + hw, size - margin - hw
                local loY, hiY = margin + hh, size - margin - hh
                if hi < lo or hiY < loY then return end
                stamp(dst, src, f, tx, ty, lo + math.floor(rng() * (hi - lo + 1)), loY + math.floor(rng() * (hiY - loY + 1)), size)
            end
            -- une tache (claire ou sombre) sur 2 tuiles sur 3, une tache rare, 2 à 3 détails
            if v % 3 ~= 0 then place((v % 2 == 0) and theme.patchLight or theme.patchDark) end
            if v == GroundTiles.VARIANTS then place(theme.patchExtra) end
            local decals = theme.decals or {}
            for _ = 1, 2 + (v % 2) do
                if #decals > 0 then place(decals[1 + math.floor(rng() * #decals)]) end
            end
            out[GroundTiles.name(ti, v)] = { frames = { { ax = tx, ay = ty, w = size, h = size, ox = 0, oy = 0 } } }
        end
    end
    return out, originY + math.ceil(n / perRow) * size
end

return GroundTiles
