-- tests/run.lua
-- Tests unitaires en Lua 5.1 pur (même VM que la 3DS) : `lua5.1 tests/run.lua`
-- Chaque fichier tests/test_*.lua renvoie une table { ["nom du test"] = function() ... end }.
package.path = "./?.lua;" .. package.path

local files = {
    "tests.test_director",
    "tests.test_world_encounter",
    "tests.test_wave_runner",
    "tests.test_elite_affixes",
    "tests.test_admin",
    "tests.test_boss_brain",
    "tests.test_stick",
    "tests.test_physics",
    "tests.test_save_equipment",
    "tests.test_room_gold",
    "tests.test_sanctuary_rooms",
    "tests.test_ai_damage",
    "tests.test_world_progress",
    "tests.test_rewards",
    "tests.test_font",
    "tests.test_camera",
    "tests.test_talent_caps",
    "tests.test_boss_loot",
    "tests.test_loot_bounds",
    "tests.test_vfx_shake",
    "tests.test_world_rooms",
    "tests.test_status_effects",
    "tests.test_hero_hits",
    "tests.test_skill_rules",
    "tests.test_targeting",
    "tests.test_combat_physics",
}

local passed, failed = 0, 0
for _, modName in ipairs(files) do
    local ok, suite = pcall(require, modName)
    if not ok then
        print("ÉCHEC CHARGEMENT " .. modName .. " : " .. tostring(suite))
        failed = failed + 1
    else
        local names = {}
        for name in pairs(suite) do names[#names + 1] = name end
        table.sort(names)
        for _, name in ipairs(names) do
            local okTest, err = pcall(suite[name])
            if okTest then
                passed = passed + 1
            else
                failed = failed + 1
                print("ÉCHEC " .. modName .. " › " .. name .. "\n    " .. tostring(err))
            end
        end
    end
end
print(string.format("%d tests réussis, %d échecs", passed, failed))
os.exit(failed == 0 and 0 or 1)
