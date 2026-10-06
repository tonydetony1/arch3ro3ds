-- tests/test_skill_rules.lua
-- Skills and Devil pacts: the hero fans at most 3 front arrows (Player:shoot), so extra
-- copies are not offered and cannot stack past the cap; the Infernal Haste pact does what
-- both of its texts promise.

love = love or {}
love.timer = love.timer or { getTime = function() return 0 end }
love.image = love.image or { newImageData = function() return {} end }
love.filesystem = love.filesystem or { write = function() return true end, read = function() return nil end }
love.graphics = love.graphics or {}
if not getmetatable(love.graphics) then
    setmetatable(love.graphics, { __index = function() return function() return {} end end })
end

local Skills = require("src.data.skills")
local PlayerStats = require("src.data.player_stats")
local SpecialRoomManager = require("src.core.special_room_manager")
local Icons = require("src.render.sprites.icons")

local function apply(id, p)
    Skills.get(id).hooks.onApply(p)
end

local function offeredIds(player, draws)
    local seen = {}
    for _ = 1, draws do
        for _, def in ipairs(Skills.getRandomDraft(3, {}, player)) do seen[def.id] = true end
    end
    return seen
end

local T = {}

T["Infernal Haste raises movement and attack speed by 25%"] = function()
    local p = { speed = 100, attackSpeedMult = 1.0 }
    apply("devil_haste", p)
    assert(math.abs(p.speed - 125) < 1e-6, "speed " .. p.speed)
    assert(math.abs(p.attackSpeedMult - 1.25) < 1e-6, "attack speed " .. p.attackSpeedMult)
end

T["Infernal Haste texts agree with the effect"] = function()
    for _, text in ipairs({ Skills.get("devil_haste").desc, SpecialRoomManager.devilPacts({ frontArrows = 1 })[3].desc }) do
        assert(text:find("25%%") and text:lower():find("attack speed"), "text: " .. text)
    end
end

T["front arrows never exceed the cap, whatever the source"] = function()
    local p = { frontArrows = 1 }
    for _ = 1, 4 do apply("front_arrow", p) end
    for _ = 1, 4 do apply("arrow_rain", p) end
    apply("devil_multishot", p)
    assert(p.frontArrows == PlayerStats.max_front_arrows, "front arrows " .. p.frontArrows)
end

T["front arrow skills are not offered once the cap is reached"] = function()
    local seen = offeredIds({ frontArrows = PlayerStats.max_front_arrows }, 300)
    assert(not seen.front_arrow and not seen.arrow_rain, "a wasted front arrow skill was offered")
end

T["front arrow skills are still offered below the cap"] = function()
    local seen = offeredIds({ frontArrows = 1 }, 400)
    assert(seen.front_arrow or seen.arrow_rain, "front arrow skills never offered")
end

T["the Devil never offers a wasted Dark Multishot"] = function()
    local function hasMultishot(player)
        for _, pact in ipairs(SpecialRoomManager.devilPacts(player)) do
            if pact.skillId == "devil_multishot" then return true end
        end
        return false
    end
    assert(hasMultishot({ frontArrows = 1 }))
    assert(not hasMultishot({ frontArrows = PlayerStats.max_front_arrows }))
end

T["gold skills show the coin icon, not the multishot arrows"] = function()
    assert(Icons.skillIcon("gold") == "icon_coin")
    local checked = 0
    for _, id in ipairs(Skills.list) do
        local def = Skills.get(id)
        if def.desc:find("Gold ") then -- "Gold " : not "Golden shield"
            checked = checked + 1
            assert(def.icon == "gold", id .. " uses icon " .. tostring(def.icon))
        end
    end
    assert(checked >= 4, "expected the gold skills to be checked, got " .. checked)
end

return T
