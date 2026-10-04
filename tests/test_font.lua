-- tests/test_font.lua
-- The TINY pixel font (buttons, badges, HUD labels) must stay readable on a 3DS screen.
local Glyphs = require("src.ui.font_glyphs")

local T = {}

local TINY = Glyphs.TINY

T["tiny font: every glyph fits its cell with rows of equal width"] = function()
    for ch, g in pairs(TINY.glyphs) do
        local w = #g[2]
        for i = 3, #g do assert(#g[i] == w, ch .. ": uneven rows") end
        assert(g[1] >= 0 and g[1] + #g - 1 <= TINY.CELL_H, ch .. ": outside its cell")
    end
end

T["tiny font: capitals and digits are at least 4x6 px"] = function()
    local narrow = { I = true, ["1"] = true }
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    for i = 1, #chars do
        local ch = chars:sub(i, i)
        local g = assert(TINY.glyphs[ch], ch .. " missing")
        assert(#g - 1 >= 6, ch .. " is only " .. (#g - 1) .. " px tall")
        assert(narrow[ch] or #g[2] >= 4, ch .. " is only " .. #g[2] .. " px wide")
    end
end

T["tiny font: line height leaves room for the outline"] = function()
    assert(TINY.LINE_H >= TINY.CELL_H + 2)
end

T["tiny font: has the middle dot used by the skill draft hint"] = function()
    assert(TINY.glyphs["·"], "the draft hint 'TOUCH A CARD · D-PAD + A' needs '·'")
end

return T
