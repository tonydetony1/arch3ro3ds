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

function Boot.save()
    pcall(love.filesystem.write, "boot_profile.txt", table.concat(Boot.marks, "\n") .. "\n")
end

return Boot
