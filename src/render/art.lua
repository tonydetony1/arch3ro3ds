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
    "src.render.sprites.icons",
    "src.render.sprites.items",
    "src.render.sprites.fx",
}

function Art.init()
    if Art.ready then return end

    -- 1. Mode Ultra-Rapide (Boot Instantané < 0.05s) : Chargement du pack précompilé
    local prebakedImg = "assets/atlas.png"
    local hasPrebakedData, prebakedData = pcall(require, "src.render.atlas_data")
    Boot.mark("  atlas: données Lua " .. (hasPrebakedData and type(prebakedData) or tostring(prebakedData)))

    local okData, imgData = pcall(love.image.newImageData, prebakedImg)
    local okImg, rawImg = false, nil
    if not okData then okImg, rawImg = pcall(love.graphics.newImage, prebakedImg) end
    Boot.mark("  atlas: PNG " .. tostring(okData) .. " " .. tostring(okData and "" or imgData) .. " / " .. tostring(okImg) .. " " .. tostring(rawImg))

    if hasPrebakedData and type(prebakedData) == "table" and (okData or okImg) then
        local img = okData and love.graphics.newImage(imgData) or rawImg
        img:setFilter("nearest", "nearest")
        Boot.mark("  atlas: texture GPU")
        local atlas = SpriteAtlas.loadPrebaked(prebakedData, img)
        Boot.mark("  atlas: quads")
        PixelFont.loadPrebaked(prebakedData.fonts, atlas)
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

-- Index de frame animée à partir d'un temps, d'une cadence (images/s) et d'un décalage
function Art.animFrame(name, t, fps, offset)
    local n = Art.atlas:frameCount(name)
    if n <= 1 then return 1 end
    return math.floor(t * fps + (offset or 0)) % n + 1
end

return Art
