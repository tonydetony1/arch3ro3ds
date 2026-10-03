-- tools/bake/main.lua
-- Script autonome de précompilation de l'atlas graphique Arch3ro
-- Exécuté par love.appimage lors du build pour générer :
--   1. assets/atlas.png (1024x1024 PNG optimisé : sprites + tuiles de sol)
--   2. src/render/atlas_data.lua (mapping coordonnées + quads + fonts)

local ROOT = love.filesystem.getSource()
package.path = package.path .. ";./?.lua;./?/init.lua"

local Palette = require("src.render.palette")
local SpriteAtlas = require("src.render.sprite_atlas")
local PixelFont = require("src.ui.pixel_font")
local Art = require("src.render.art")

local function serialize(val, indent)
    indent = indent or ""
    local t = type(val)
    if t == "number" or t == "boolean" then
        return tostring(val)
    elseif t == "string" then
        return string.format("%q", val)
    elseif t == "table" then
        local isArray = (#val > 0)
        local parts = {}
        local nextIndent = indent .. "  "
        if isArray then
            for _, v in ipairs(val) do
                parts[#parts + 1] = nextIndent .. serialize(v, nextIndent)
            end
            return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
        else
            local keys = {}
            for k in pairs(val) do keys[#keys + 1] = k end
            table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
            for _, k in ipairs(keys) do
                local keyStr = (type(k) == "number") and ("[" .. k .. "]") or (string.format("[%q]", tostring(k)))
                parts[#parts + 1] = nextIndent .. keyStr .. " = " .. serialize(val[k], nextIndent)
            end
            return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
        end
    end
    return "nil"
end

function love.load()
    print("=== ARCH3RO SPRITE ATLAS PRECOMPILER ===")
    local t0 = os.clock()

    -- 1. Construction complète de l'atlas en mémoire
    local atlas = SpriteAtlas.new(1024, 512)
    local SPRITE_MODULES = {
        "src.render.sprites.heroes",
        "src.render.sprites.monsters",
        "src.render.sprites.monsters_extra",
        "src.render.sprites.props",
        "src.render.sprites.icons",
        "src.render.sprites.items",
        "src.render.sprites.fx",
        "src.render.sprites.overlays",
    }
    for _, modName in ipairs(SPRITE_MODULES) do
        require(modName).define(atlas)
    end
    PixelFont.define(atlas)
    atlas:bake()
    PixelFont.finalize(atlas)

    print(string.format(" -> Atlas généré en %.3fs (#items: %d)", os.clock() - t0, #atlas.items))

    -- 1b. Jeu de tuiles du sol (src/render/ground_tiles.lua) sous les sprites : atlas 1024x1024
    local GroundTiles = require("src.render.ground_tiles")
    local tall = love.image.newImageData(atlas.w, 1024)
    tall:paste(atlas.imageData, 0, 0, 0, 0, atlas.w, atlas.h)
    local groundSprites, usedTo = GroundTiles.bake(atlas, tall, atlas.h)
    for name, sprite in pairs(groundSprites) do atlas.sprites[name] = sprite end
    atlas.imageData = tall
    atlas.h = 1024
    print(string.format(" -> Tuiles de sol : %d thèmes x %d variantes (jusqu'à y=%d)",
        GroundTiles.THEMES, GroundTiles.VARIANTS, usedTo))

    -- 2. Export de l'image PNG (assets/atlas.png)
    local imgData = atlas.imageData
    assert(imgData, "atlas.imageData doit être défini dans SpriteAtlas:bake()")
    local fileData = imgData:encode("png")
    local pngFile = io.open("assets/atlas.png", "wb")
    assert(pngFile, "Impossible d'ouvrir assets/atlas.png en écriture")
    pngFile:write(fileData:getString())
    pngFile:close()
    local pngSize = fileData:getSize()
    print(string.format(" -> assets/atlas.png sauvegardé (%d Ko)", math.floor(pngSize / 1024)))

    -- 3. Extraction des métadonnées légères
    local cleanSprites = {}
    for name, s in pairs(atlas.sprites) do
        local entry = {}
        if s.frames and #s.frames > 0 then
            entry.frames = {}
            for i, f in ipairs(s.frames) do
                entry.frames[i] = { ax = f.ax, ay = f.ay, w = f.w, h = f.h, ox = f.ox, oy = f.oy }
            end
        end
        if s.flash and #s.flash > 0 then
            entry.flash = {}
            for i, f in ipairs(s.flash) do
                entry.flash[i] = { ax = f.ax, ay = f.ay, w = f.w, h = f.h, ox = f.ox, oy = f.oy }
            end
        end
        if s.variants then
            local hasV = false
            entry.variants = {}
            for vName, vFrames in pairs(s.variants) do
                if #vFrames > 0 then
                    hasV = true
                    entry.variants[vName] = {}
                    for i, f in ipairs(vFrames) do
                        entry.variants[vName][i] = { ax = f.ax, ay = f.ay, w = f.w, h = f.h, ox = f.ox, oy = f.oy }
                    end
                end
            end
            if not hasV then entry.variants = nil end
        end
        cleanSprites[name] = entry
    end

    local cleanFonts = {}
    for id, font in pairs(PixelFont.fonts) do
        local fEntry = {
            cellH = font.cellH,
            lineH = font.lineH,
            space = font.space,
            glyphs = {},
        }
        for cp, g in pairs(font.glyphs) do
            fEntry.glyphs[cp] = {
                w = g.w,
                yoff = g.yoff,
                nameO = g.nameO,
                nameP = g.nameP,
                nameC = g.nameC,
            }
        end
        cleanFonts[id] = fEntry
    end

    local outData = {
        w = atlas.w,
        h = atlas.h,
        sprites = cleanSprites,
        fonts = cleanFonts,
    }

    -- 4. Écriture de src/render/atlas_data.lua
    local luaFile = io.open("src/render/atlas_data.lua", "w")
    assert(luaFile, "Impossible d'ouvrir src/render/atlas_data.lua en écriture")
    luaFile:write("-- src/render/atlas_data.lua\n")
    luaFile:write("-- FICHIER PRÉCOMPILÉ AUTOMATIQUEMENT PAR tools/bake\n")
    luaFile:write("-- Permet un démarrage instantané (< 0.05s) sur Nintendo 3DS et émulateurs.\n\n")
    luaFile:write("return " .. serialize(outData) .. "\n")
    luaFile:close()
    print(" -> src/render/atlas_data.lua sauvegardé avec succès.")
    print("=== PRÉCOMPILATION TERMINÉE ===")
    love.event.quit(0)
end
