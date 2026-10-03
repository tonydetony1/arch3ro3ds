-- src/core/screen.lua
-- Abstraction du double écran Nintendo 3DS (LÖVEPotion) avec simulateur PC Desktop

local Config = require("src.data.config")

-- Compatibilité LÖVE-Potion (setActiveScreen) et LÖVE standard
if love.graphics and not love.graphics.setScreen and love.graphics.setActiveScreen then
    love.graphics.setScreen = love.graphics.setActiveScreen
end

local Screen = {
    is3DS = (love._console == "3DS" or love._os == "3DS" or (love.graphics and (love.graphics.setActiveScreen ~= nil or love.graphics.getScreens ~= nil))),
    
    -- Dimensions constantes
    TOP_W = Config.TOP_WIDTH,
    TOP_H = Config.TOP_HEIGHT,
    BOT_W = Config.BOTTOM_WIDTH,
    BOT_H = Config.BOTTOM_HEIGHT,
    
    -- Offset sur PC pour centrer l'écran inférieur dans la fenêtre 400x480
    PC_BOT_OFFSET_X = (Config.TOP_WIDTH - Config.BOTTOM_WIDTH) / 2, -- 40 px
    PC_BOT_OFFSET_Y = Config.TOP_HEIGHT,                            -- 240 px
}

-- Rendu complet des deux écrans
function Screen.render(drawTopFn, drawBottomFn, currentScreen)
    if Screen.is3DS then
        -- Sur 3DS LÖVE-Potion, love.run appelle love.draw(screen) successivement pour chaque écran ('top', 'bottom', 'left', 'right')
        local s = currentScreen or (love.graphics.getActiveScreen and love.graphics.getActiveScreen())
        if s then
            if s == "top" or s == "left" or s == "right" then
                local eye = (s == "left" and -1) or (s == "right" and 1) or 0
                if drawTopFn then drawTopFn(eye) end
            elseif s == "bottom" then
                if drawBottomFn then drawBottomFn() end
            end
        else
            -- Si appelé sans argument de boucle interne, bascule manuellement
            local setScreen = love.graphics.setActiveScreen or love.graphics.setScreen
            local is3DActive = false
            if love.graphics.get3D then
                local status, res = pcall(love.graphics.get3D)
                if status and res then is3DActive = true end
            end

            if is3DActive then
                if setScreen then setScreen("left") end
                if drawTopFn then drawTopFn(-1) end
                if setScreen then setScreen("right") end
                if drawTopFn then drawTopFn(1) end
            else
                if setScreen then setScreen("top") end
                if drawTopFn then drawTopFn(0) end
            end

            if setScreen then setScreen("bottom") end
            if drawBottomFn then drawBottomFn() end
        end
    else
        -- Mode émulation PC (Double écran empilé dans 400x480)
        -- 1. Fond noir général
        love.graphics.clear(0.05, 0.05, 0.07, 1.0)

        -- 2. Écran Supérieur (Top Screen : 400x240)
        love.graphics.push()
        love.graphics.setScissor(0, 0, Screen.TOP_W, Screen.TOP_H)
        if drawTopFn then drawTopFn() end
        love.graphics.setScissor()
        love.graphics.pop()

        -- Séparateur esthétique 3DS
        love.graphics.setColor(0.12, 0.12, 0.16, 1.0)
        love.graphics.line(0, Screen.TOP_H, Screen.TOP_W, Screen.TOP_H)

        -- 3. Écran Inférieur (Bottom Screen : 320x240, centré à X=40, Y=240)
        love.graphics.push()
        love.graphics.translate(Screen.PC_BOT_OFFSET_X, Screen.PC_BOT_OFFSET_Y)
        love.graphics.setScissor(Screen.PC_BOT_OFFSET_X, Screen.PC_BOT_OFFSET_Y, Screen.BOT_W, Screen.BOT_H)
        
        -- Fond d'écran inférieur par défaut
        love.graphics.setColor(0.08, 0.09, 0.12, 1.0)
        love.graphics.rectangle("fill", 0, 0, Screen.BOT_W, Screen.BOT_H)
        
        if drawBottomFn then drawBottomFn() end
        
        love.graphics.setScissor()
        love.graphics.pop()

        -- Contour visuel de l'écran tactile sur PC
        love.graphics.setColor(0.25, 0.28, 0.35, 1.0)
        love.graphics.rectangle("line", Screen.PC_BOT_OFFSET_X - 0.5, Screen.PC_BOT_OFFSET_Y - 0.5, Screen.BOT_W + 1, Screen.BOT_H + 1)
    end
end

-- Convertit les coordonnées tactiles PC/3DS vers le repère local Bottom Screen
function Screen.normalizeTouch(rawX, rawY)
    if Screen.is3DS then
        return rawX, rawY
    else
        local localX = rawX - Screen.PC_BOT_OFFSET_X
        local localY = rawY - Screen.PC_BOT_OFFSET_Y
        if localX >= 0 and localX <= Screen.BOT_W and localY >= 0 and localY <= Screen.BOT_H then
            return localX, localY
        end
        return nil, nil
    end
end

return Screen
