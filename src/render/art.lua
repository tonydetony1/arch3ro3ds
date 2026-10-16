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
    "src.render.sprites.menu_art",
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
        Art.bindDrawers()
        return
    end

    -- 2. Secours : Génération procédurale si les fichiers précompilés sont absents
    local atlas = SpriteAtlas.new(1024, 640) -- sprites; ground tiles are baked below them
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
    Art.bindDrawers()
end

-- Lazy-init stubs: replaced by the fast drawers of Art.bindDrawers once the atlas is loaded
local drawStub, drawExStub
function drawStub(name, frame, x, y, flipX, flash, variant)
    if not Art.ready then Art.init() end
    if Art.draw == drawStub then Art.bindDrawers() end
    return Art.draw(name, frame, x, y, flipX, flash, variant)
end

function drawExStub(name, frame, x, y, r, sx, sy, flash, variant)
    if not Art.ready then Art.init() end
    if Art.drawEx == drawExStub then Art.bindDrawers() end
    return Art.drawEx(name, frame, x, y, r, sx, sy, flash, variant)
end
Art.draw, Art.drawEx = drawStub, drawExStub

function Art.frame(name, frame, flash, variant)
    if not Art.ready then Art.init() end
    return Art.atlas:getFrame(name, frame, flash, variant)
end

function Art.has(name)
    if not Art.ready then Art.init() end
    return Art.atlas:has(name)
end

-- Pre-coloured flat ("px_<colour>_<opacity>" atlas pixel, src/render/px_colors.lua) stretched over
-- (x, y, w, h). Drawn in white, it stays in the batch of the neighbouring sprites: health bars,
-- gauges and veils no longer break the grouping of GPU calls on 3DS.
local PxColors = nil
local Gpu = nil
local floor = math.floor
local pxQuads = {} -- [colourName][opacity in twentieths] = quad, or false (not baked)

local function pxQuad(colorName, a20)
    local byAlpha = pxQuads[colorName]
    if not byAlpha then
        byAlpha = {}
        pxQuads[colorName] = byAlpha
    end
    local q = byAlpha[a20]
    if q == nil then
        PxColors = PxColors or require("src.render.px_colors")
        local name = PxColors.spriteName(colorName, a20 / 20)
        local s = name and Art.atlas and Art.atlas.sprites[name]
        q = s and s.frames[1].quad or false
        byAlpha[a20] = q
    end
    return q
end
Art.pxQuad = pxQuad

function Art.px(colorName, x, y, w, h, alpha)
    if w <= 0 or h <= 0 then return end
    local a20 = floor((alpha or 1) * 20 + 0.5)
    if a20 <= 0 then return end
    if a20 > 20 then a20 = 20 end
    local q = Art.ready and pxQuad(colorName, a20)
    if not q then
        PxColors = PxColors or require("src.render.px_colors")
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
    Gpu.addSprite(Art.image, q, x, y, 0, w, h)
end

-- Fast drawers bound to the loaded atlas: on Old 3DS every sprite used to go through
-- Art.draw -> atlas:draw -> pick -> Gpu.addSprite (4 Lua calls and a dozen table lookups);
-- these closures resolve the frame inline and call Gpu.addSprite directly.
function Art.bindDrawers()
    local sprites, image = Art.atlas.sprites, Art.image
    local addSprite = require("src.core.gpu").addSprite
    Art.draw = function(name, frame, x, y, flipX, flash, variant)
        local s = sprites[name]
        if not s then return end
        local frames = s.frames
        if flash and s.flash then
            frames = s.flash
        elseif variant then
            local v = s.variants
            v = v and v[variant]
            if v then frames = v end
        end
        local f = frames[((frame or 1) - 1) % #frames + 1]
        addSprite(image, f.quad, floor(x + 0.5), floor(y + 0.5), 0, flipX and -1 or 1, 1, f.ox, f.oy)
    end
    Art.drawEx = function(name, frame, x, y, r, sx, sy, flash, variant)
        local s = sprites[name]
        if not s then return end
        local frames = s.frames
        if flash and s.flash then
            frames = s.flash
        elseif variant then
            local v = s.variants
            v = v and v[variant]
            if v then frames = v end
        end
        local f = frames[((frame or 1) - 1) % #frames + 1]
        addSprite(image, f.quad, x, y, r or 0, sx or 1, sy or sx or 1, f.ox, f.oy)
    end
end

-- Index de frame animée à partir d'un temps, d'une cadence (images/s) et d'un décalage
function Art.animFrame(name, t, fps, offset)
    local n = Art.atlas:frameCount(name)
    if n <= 1 then return 1 end
    return math.floor(t * fps + (offset or 0)) % n + 1
end

return Art
