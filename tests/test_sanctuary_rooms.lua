local WorldManager = require("src.core.world_manager")
local Rooms = require("src.data.rooms")

local T = {}

T["salles 5, 15… : Ange ; 9, 19… : Démon ; 10, 20… : boss"] = function()
    assert(WorldManager.getRoomType(4) == "combat")
    assert(WorldManager.getRoomType(5) == "angel")
    assert(WorldManager.getRoomType(9) == "devil")
    assert(WorldManager.getRoomType(10) == "boss")
    assert(WorldManager.getRoomType(15) == "angel")
    assert(WorldManager.getRoomType(19) == "devil")
    assert(WorldManager.getRoomType(49) == "devil")
end

T["aucune vague dans un sanctuaire"] = function()
    for _, room in ipairs({ 5, 9, 25, 39 }) do
        local enc = WorldManager.generateEncounter(1, room, 400, 240)
        assert(#enc.waves == 0, "salle " .. room .. " : vagues inattendues")
    end
end

T["thèmes des sanctuaires : ciel pour l'Ange, lave pour le Démon"] = function()
    local angel = WorldManager.getTheme(WorldManager.SANCTUARY_THEME.angel)
    local devil = WorldManager.getTheme(WorldManager.SANCTUARY_THEME.devil)
    assert(angel.variant == "sky" and angel.hazard == nil)
    assert(devil.variant == "lava" and devil.hazard == nil)
    assert(angel ~= WorldManager.getTheme(5) and devil ~= WorldManager.getTheme(4))
end

T["sanctuaire : un écran, grille sans obstacle"] = function()
    assert(Rooms.SANCTUARY_W == 400 and Rooms.SANCTUARY_H == 240)
    local layout = Rooms.pick("sanctuary", 9)
    for _, row in ipairs(layout.grid) do
        assert(not row:find("[^%.]"), layout.id .. " : " .. row)
    end
end

return T
