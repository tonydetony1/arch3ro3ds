-- tests/test_room_gold.lua
-- "ROOM CLEARED! +X GOLD" banner: the gold of the coins still on the ground (pulled in by
-- the magnet right after the clear) must be counted, not only the coins already picked up.

love = love or {}
love.timer = love.timer or { getTime = function() return 0 end }
love.filesystem = love.filesystem or { write = function() return true end, read = function() return nil end }

local GameState = require("src.states.game")

local function fakeGame(collected, coins, others)
    local items, list = {}, {}
    for i, v in ipairs(coins) do
        items[i] = { type = "coin", value = v }
        list[i] = i
    end
    for _, t in ipairs(others or {}) do
        items[#items + 1] = { type = t, value = 999 }
        list[#list + 1] = #items
    end
    return setmetatable({
        goldEarnedRun = 100 + collected,
        roomGoldStart = 100,
        lootPool = { items = items, activeList = list, activeCount = #list },
    }, { __index = GameState })
end

local T = {}

T["room gold counts coins still on the ground"] = function()
    local g = fakeGame(0, { 12, 8, 5 })
    assert(g:roomClearGold() == 25, "got " .. tostring(g:roomClearGold()))
end

T["room gold adds picked-up and ground coins, ignores gems and hearts"] = function()
    local g = fakeGame(30, { 10 }, { "xp", "heart", "scroll" })
    assert(g:roomClearGold() == 40, "got " .. tostring(g:roomClearGold()))
end

T["room gold is never negative"] = function()
    local g = fakeGame(0, {})
    g.goldEarnedRun, g.roomGoldStart = 50, 80
    assert(g:roomClearGold() == 0)
end

return T
