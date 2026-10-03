-- src/core/boot_profile.lua
-- Chronométrage du démarrage : Boot.mark("étape") puis Boot.save() -> boot_profile.txt
-- (dossier de sauvegarde ; sur 3DS : sdmc:/3ds/save/arch3ro/boot_profile.txt)

local Boot = { marks = {} }

local function now()
    return love.timer and love.timer.getTime() or os.clock()
end

Boot.t0 = now()
Boot.last = Boot.t0

function Boot.mark(label)
    local t = now()
    Boot.marks[#Boot.marks + 1] = string.format("%-28s %7.3f s  (+%.3f)", label, t - Boot.t0, t - Boot.last)
    Boot.last = t
end

-- Temps propre de chaque module (sans ses sous-modules), pour trouver ce qui ralentit le
-- démarrage : require est enveloppé jusqu'à Boot.save()
local moduleTimes = {}
local rawRequire = require
local depth, childTime = 0, { 0 }
require = function(name)
    if package.loaded[name] ~= nil then return package.loaded[name] end
    depth = depth + 1
    childTime[depth + 1] = 0
    local t = now()
    local mod = rawRequire(name)
    local total = now() - t
    local own = total - childTime[depth + 1]
    childTime[depth] = (childTime[depth] or 0) + total
    depth = depth - 1
    moduleTimes[#moduleTimes + 1] = { name, own }
    return mod
end

function Boot.save()
    require = rawRequire
    table.sort(moduleTimes, function(a, b) return a[2] > b[2] end)
    local lines = { table.concat(Boot.marks, "\n"), "", "Modules (temps propre, hors sous-modules) :" }
    for i = 1, math.min(25, #moduleTimes) do
        lines[#lines + 1] = string.format("  %-36s %6.3f s", moduleTimes[i][1], moduleTimes[i][2])
    end
    pcall(love.filesystem.write, "boot_profile.txt", table.concat(lines, "\n") .. "\n")
end

return Boot
