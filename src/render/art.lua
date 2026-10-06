-- src/render/art.lua
-- Point d'accès unique aux graphismes pixel art : un seul atlas (personnages, décor, icônes, police).
-- Initialisé une fois au chargement (love.load) ; initialisation paresseuse de secours.

local SpriteAtlas = require("src.render.sprite_atlas")
local PixelFont = require("src.ui.pixel_font")
local Boot = require("src.core.boot_profile")

local Art = {
    ready = false,
    atlas = nil,
}

local SPRITE_MODULES = {
    "src.render.sprites.heroes",
    "src.render.sprites.monsters",
    "src.render.sprites.monsters_extra",
    "src.render.sprites.props",
    "src.render.sprites.sanctuary",
    "src.render.sprites.biomes",
    "src.render.sprites.icons",
    "src.render.sprites.items",
    "src.render.sprites.fx",
    "src.render.sprites.overlays",
}

function Art.init()
    if Art.ready then return end

    -- 1. Mode Ultra-Rapide (Boot Instantané < 0.05s) : Chargement du pack précompilé
    local prebakedImg = "assets/atlas.png"
    local hasPrebakedData, prebakedData = pcall(require, "src.render.atlas_data")
    Boot.mark("  atlas: données Lua " .. (hasPrebakedData and type(prebakedData) or tostring(prebakedData)))

    local okImg, img = pcall(love.graphics.newImage, prebakedImg)
    if not okImg then
        local okData, imgData = pcall(love.image.newImageData, prebakedImg)
        if okData then okImg, img = pcall(love.graphics.newImage, imgData) end
    end
    Boot.mark("  atlas: texture " .. tostring(okImg))

    if hasPrebakedData and type(prebakedData) == "table" and okImg and img then
        img:setFilter("nearest", "nearest")
        Boot.mark("  atlas: texture GPU")
        local atlas = SpriteAtlas.loadPrebaked(prebakedData, img)
        Boot.mark("  atlas: quads")
        PixelFont.loadPrebaked(prebakedData.fonts, atlas)
        prebakedData.fonts = nil -- copiées dans PixelFont : les données brutes ne servent plus
        Boot.mark("  atlas: police")
        Art.atlas = atlas
        Art.image = img
        Art.ready = true
        require("src.core.gpu").setAutoBatchImage(img)
        return
    end

    -- 2. Secours : Génération procédurale si les fichiers précompilés sont absents
    local atlas = SpriteAtlas.new(1024, 512)
    for _, modName in ipairs(SPRITE_MODULES) do
        require(modName).define(atlas)
    end
    PixelFont.define(atlas)
    atlas:bake()
    PixelFont.finalize(atlas)
    Art.atlas = atlas
    Art.image = atlas.image
    Art.ready = true
    require("src.core.gpu").setAutoBatchImage(atlas.image)
end

function Art.draw(name, frame, x, y, flipX, flash, variant)
    if not Art.ready then Art.init() end
    Art.atlas:draw(name, frame, x, y, flipX, flash, variant)
end

function Art.drawEx(name, frame, x, y, r, sx, sy, flash, variant)
    if not Art.ready then Art.init() end
    Art.atlas:drawEx(name, frame, x, y, r, sx, sy, flash, variant)
end

function Art.frame(name, frame, flash, variant)
    if not Art.ready then Art.init() end
    return Art.atlas:getFrame(name, frame, flash, variant)
end

function Art.has(name)
    if not Art.ready then Art.init() end
    return Art.atlas:has(name)
end

-- Aplat pré-coloré (pixel "px_<couleur>_<opacité>" de l'atlas, src/render/px_colors.lua)
-- étiré sur (x, y, w, h). Dessiné en blanc, il reste dans le lot des sprites voisins :
-- barres de vie, jauges et voiles ne cassent plus le regroupement des appels GPU sur 3DS.
local PxColors = nil
local Gpu = nil
function Art.px(colorName, x, y, w, h, alpha)
    if w <= 0 or h <= 0 then return end
    PxColors = PxColors or require("src.render.px_colors")
    local name = PxColors.spriteName(colorName, alpha or 1)
    local s = name and Art.atlas and Art.atlas.sprites[name]
    if not s then
        local c = PxColors.list()[colorName]
        if c then
            love.graphics.setColor(c[1], c[2], c[3], alpha or 1)
            love.graphics.rectangle("fill", x, y, w, h)
        end
        love.graphics.setColor(1, 1, 1, 1)
        return
    end
    love.graphics.setColor(1, 1, 1, 1)
    Gpu = Gpu or require("src.core.gpu")
    Gpu.addSprite(Art.image, s.frames[1].quad, x, y, 0, w, h)
end

-- Index de frame animée à partir d'un temps, d'une cadence (images/s) et d'un décalage
function Art.animFrame(name, t, fps, offset)
    local n = Art.atlas:frameCount(name)
    if n <= 1 then return 1 end
    return math.floor(t * fps + (offset or 0)) % n + 1
end

return Art
