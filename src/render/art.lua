-- src/render/art.lua
-- Point d'accès unique aux graphismes pixel art : un seul atlas (personnages, décor, icônes, police).
-- Initialisé une fois au chargement (love.load) ; initialisation paresseuse de secours.

local SpriteAtlas = require("src.render.sprite_atlas")
local PixelFont = require("src.ui.pixel_font")

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

    local diagLog = {}
    local function logDiag(msg)
        table.insert(diagLog, msg)
        pcall(function()
            local f = io.open("test_diag.txt", "a")
            if f then f:write(msg .. "\n"); f:close() end
        end)
    end

    logDiag("=== Art.init DIAGNOSTIC ===")
    local testData = string.rep("\0\0\0\0", 64 * 64)
    local okRaw1, idRaw1 = pcall(love.image.newImageData, 64, 64, "rgba8", testData)
    logDiag("newImageData(64, 64, 'rgba8', str): ok=" .. tostring(okRaw1) .. " res=" .. tostring(idRaw1))
    local okRaw2, idRaw2 = pcall(love.image.newImageData, 64, 64, testData)
    logDiag("newImageData(64, 64, str): ok=" .. tostring(okRaw2) .. " res=" .. tostring(idRaw2))

    local okImgRaw, imgRaw = false, nil
    if okRaw1 and idRaw1 then
        logDiag("idRaw1 format: " .. tostring(idRaw1:getFormat()))
        okImgRaw, imgRaw = pcall(love.graphics.newImage, idRaw1)
        logDiag("newImage(idRaw1): ok=" .. tostring(okImgRaw) .. " res=" .. tostring(imgRaw))
        if okImgRaw and imgRaw then
            logDiag("imgRaw format: " .. tostring(imgRaw:getFormat()))
        end
    end
    local info = love.filesystem.getInfo and love.filesystem.getInfo(prebakedImg)
    logDiag("getInfo(atlas.png): " .. tostring(info and (info.size or true)))

    local okData, imgData = pcall(love.image.newImageData, prebakedImg)
    logDiag("newImageData(atlas.png): ok=" .. tostring(okData) .. " res=" .. tostring(imgData))
    if okData and imgData then
        local fmt = tostring(imgData:getFormat())
        local r0, g0, b0, a0 = imgData:getPixel(0, 0)
        logDiag(string.format("imgData fmt=%s, p(0,0)=(%s,%s,%s,%s)", fmt, tostring(r0), tostring(g0), tostring(b0), tostring(a0)))
    end

    local okImg, rawImg = pcall(love.graphics.newImage, prebakedImg)
    logDiag("newImage(atlas.png): ok=" .. tostring(okImg) .. " res=" .. tostring(rawImg))

    if hasPrebakedData and type(prebakedData) == "table" and (okData or okImg) then
        local img = okData and love.graphics.newImage(imgData) or rawImg
        img:setFilter("nearest", "nearest")
        local atlas = SpriteAtlas.loadPrebaked(prebakedData, img)
        PixelFont.loadPrebaked(prebakedData.fonts, atlas)
        Art.atlas = atlas
        Art.image = img
        Art.ready = true
        logDiag("Prebaked pack successfully loaded!")
        return
    end

    -- 2. Secours : Génération procédurale si les fichiers précompilés sont absents
    local atlas = SpriteAtlas.new(512, 512)
    for _, modName in ipairs(SPRITE_MODULES) do
        require(modName).define(atlas)
    end
    PixelFont.define(atlas)
    atlas:bake()
    PixelFont.finalize(atlas)
    Art.atlas = atlas
    Art.image = atlas.image
    Art.ready = true
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
