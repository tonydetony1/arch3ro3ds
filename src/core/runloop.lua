-- src/core/runloop.lua
-- Boucle principale 3DS (remplace love.run de LÖVE Potion, même logique d'événements).
--
-- Différence : l'écran tactile n'est redessiné qu'une image sur BOTTOM_EVERY (3), sauf s'il a été
-- touché, qu'un bouton a été pressé ou qu'un état l'exige (Screen.bottomDirty). Un écran qui
-- n'est pas redessiné garde simplement l'image précédente (citro3d ne transfère que les cibles
-- utilisées), ce qui libère le processeur pour l'écran du haut où se joue l'action.

local Screen = require("src.core.screen")

local RunLoop = {
    BOTTOM_EVERY = 3,
}

function RunLoop.run()
    if love.load then
        love.load(love.parsedGameArguments, love.rawGameArguments)
    end

    for _, j in ipairs(love.joystick.getJoysticks()) do
        love.handlers.joystickadded(j)
    end

    if love.timer then love.timer.step() end

    local delta = 0
    local frame = 0

    return function()
        if love.window and g_windowShown then
            return
        end

        if love.event and love.event.pump then
            love.event.pump()
            for name, a, b, c, d, e, f in love.event.poll() do
                if name == "quit" then
                    if not love.quit or not love.quit() then
                        love.audio.stop()
                        return a or 0
                    end
                end
                love.handlers[name](a, b, c, d, e, f)
                -- Toute interaction rafraîchit l'écran tactile à l'image suivante
                Screen.bottomDirty = true
            end
        end

        if love.timer then delta = love.timer.step() end
        if love.update then love.update(delta) end

        if love.graphics and love.graphics.isActive() then
            frame = frame + 1
            local drawBottom = Screen.bottomDirty or Screen.bottomAlways or (frame % RunLoop.BOTTOM_EVERY == 0) or frame < 4
            for _, screen in ipairs(love.graphics.getScreens()) do
                if screen ~= "bottom" or drawBottom then
                    love.graphics.origin()
                    love.graphics.setActiveScreen(screen)
                    love.graphics.clear(love.graphics.getBackgroundColor())
                    if love.draw then love.draw(screen) end
                end
            end
            if drawBottom then Screen.bottomDirty = false end
            love.graphics.present()
        end

        if love.timer then love.timer.sleep(0.001) end
    end
end

return RunLoop
