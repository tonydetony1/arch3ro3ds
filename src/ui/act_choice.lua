-- src/ui/act_choice.lua
-- End of Act I: the bottom screen offers to go on to Act II with the same hero and build, or to
-- end the run on the victory screen. Pure drawing and hit test; GameState owns the choice.
local Skin = require("src.ui.skin")
local PixelFont = require("src.ui.pixel_font")
local Palette = require("src.render.palette")
local Config = require("src.data.config")

local ActChoice = {}

-- Buttons in cursor order (D-pad up/down)
ActChoice.BUTTONS = {
    { id = "continue", x = 20, y = 96, w = 280, h = 52, theme = "green", label = "CONTINUE TO ACT II" },
    { id = "finish",   x = 20, y = 160, w = 280, h = 44, theme = "blue",  label = "END THE RUN" },
}

-- Id of the button under (tx, ty), or nil
function ActChoice.hit(tx, ty)
    for _, b in ipairs(ActChoice.BUTTONS) do
        if tx >= b.x and tx <= b.x + b.w and ty >= b.y and ty <= b.y + b.h then return b.id end
    end
    return nil
end

-- Draws the panel; the button at `cursor` is shown pressed
function ActChoice.draw(cursor)
    local C = Palette.C
    love.graphics.setColor(0.04, 0.04, 0.06, 0.75)
    love.graphics.rectangle("fill", 0, 0, Config.BOTTOM_WIDTH, Config.BOTTOM_HEIGHT)
    Skin.panel(12, 12, Config.BOTTOM_WIDTH - 24, 72, "dark")
    PixelFont.printf("ACT I CLEAR!", 12, 22, Config.BOTTOM_WIDTH - 24, "center", C.yellow, "main", 2)
    PixelFont.printf("KEEP YOUR BUILD AND FACE THE VOID", 12, 56, Config.BOTTOM_WIDTH - 24, "center", C.white, "main")
    for i, b in ipairs(ActChoice.BUTTONS) do
        local oy = Skin.button(b.x, b.y, b.w, b.h, b.theme, cursor == i) or 0
        PixelFont.printf(b.label, b.x, b.y + oy + math.floor(b.h / 2) - 6, b.w, "center", C.white, "main")
    end
end

return ActChoice
