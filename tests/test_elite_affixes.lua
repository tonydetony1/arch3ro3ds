local Elite = require("src.core.elite_affixes")

local T = {}

local function monster()
    return { x = 10, y = 20, hp = 100, maxHp = 100, speed = 40, attackRateMult = 1.0 }
end

T["swift : plus rapide et attaque plus souvent"] = function()
    local d = monster()
    Elite.apply(d, { "swift" })
    assert(d.elite and d.speed > 40 and d.attackRateMult < 1)
end

T["shielded : le bouclier absorbe avant les PV"] = function()
    local d = monster()
    Elite.apply(d, { "shielded" })
    assert(d.shieldHp == 35)
    assert(Elite.absorb(d, 20) == 0 and d.shieldHp == 15)
    assert(Elite.absorb(d, 20) == 5 and d.shieldHp == 0)
    assert(Elite.absorb(d, 20) == 20)
end

T["regenerating : soigne après 2 s sans coup"] = function()
    local d = monster()
    Elite.apply(d, { "regenerating" })
    d.hp = 50
    Elite.update(d, 1.0)
    assert(d.hp == 50)
    Elite.update(d, 1.5)
    assert(d.hp > 50)
    Elite.onHit(d)
    local hp = d.hp
    Elite.update(d, 0.5)
    assert(d.hp == hp)
end

T["enraged : une seule fois sous 50 %"] = function()
    local d = monster()
    Elite.apply(d, { "enraged" })
    assert(Elite.update(d, 0.1) == nil)
    d.hp = 49
    assert(Elite.update(d, 0.1) == "enraged")
    local speed = d.speed
    assert(Elite.update(d, 0.1) == nil and d.speed == speed)
end

T["volatile : explosion différée à la mort"] = function()
    local d = monster()
    Elite.apply(d, { "volatile" })
    local blast = Elite.onDeath(d, 3)
    assert(blast and blast.x == 10 and blast.y == 20 and blast.delay > 0 and blast.radius > 0 and blast.damage > 0)
    assert(Elite.onDeath(monster(), 3) == nil)
end

T["frost : seuls les tirs du porteur ralentissent"] = function()
    local d = monster()
    Elite.apply(d, { "frost" })
    assert(Elite.chillsShots(d) == true)
    assert(Elite.chillsShots(monster()) == false)
    assert(Elite.chillsShots(nil) == false)
end

T["champion : deux affixes, anneau et icônes précalculés"] = function()
    local d = monster()
    Elite.apply(d, { "shielded", "enraged" }, true)
    assert(d.champion and d.affixes.shielded and d.affixes.enraged)
    assert(d.ringSprite == "fx_ring_blue")
    assert(#d.affixIcons == 2 and d.affixIcons[2] == "icon_affix_enraged")
end

T["reset efface l'état d'élite"] = function()
    local d = monster()
    Elite.apply(d, { "shielded" })
    Elite.reset(d)
    assert(not d.elite and d.shieldHp == 0 and d.affixes == nil)
end

return T
