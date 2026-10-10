-- src/data/combat_rules.lua
-- Rules for the hero's arrows and movement, in one place. Pure module (no LÖVE).
--
-- The values follow the usual rules of top-down arrow roguelikes (community guides do not
-- all agree to the digit: the extra front arrow penalty is quoted between -15% and -25%).

local CombatRules = {
    -- Each extra front arrow multiplies the damage of every front arrow by this factor
    -- (2 arrows: 75% each, 3 arrows: 56% each). Diagonal, side and rear arrows are not reduced.
    FRONT_ARROW_FACTOR = 0.75,

    -- Ricochet: bounces to nearby monsters, up to 3 times, -30% damage per bounce
    RICOCHET_BOUNCES = 3,
    RICOCHET_FACTOR = 0.70,

    -- Piercing Shot: every target after the first takes 33% less
    PIERCE_FACTOR = 0.67,

    -- Bouncy Wall: -50% damage after each bounce on a wall
    WALL_BOUNCE_FACTOR = 0.50,

    -- Critical hit damage when no skill raises it (+100%)
    BASE_CRIT_MULTIPLIER = 2.0,

    -- Monsters keep walking and attacking when an arrow hits them (no hit-stun). Plain arrows do
    -- not push them; shots with a knockback multiplier above 1 do (see knockbackDistance).
    HIT_STUN = 0,

    -- Shockwave and knockback pushes: impulse fades at this rate per second (so an impulse of
    -- d * PUSH_DECAY travels about d pixels)
    PUSH_DECAY = 10,

    -- Knockback: pixels per point of knockback multiplier, capped; bosses are pushed less
    KNOCKBACK_PER_MULT = 6,
    KNOCKBACK_MAX = 60,
    KNOCKBACK_BOSS = 0.35,
}

-- Distance (px) a monster is pushed back by a shot with this knockback multiplier
function CombatRules.knockbackDistance(knockbackMult, isBoss)
    if (knockbackMult or 1) <= 1 then return 0 end
    local dist = math.min(CombatRules.KNOCKBACK_MAX, CombatRules.KNOCKBACK_PER_MULT * knockbackMult)
    return isBoss and dist * CombatRules.KNOCKBACK_BOSS or dist
end

-- Damage multiplier of each front arrow when the hero fires `count` of them
function CombatRules.frontArrowFactor(count)
    if (count or 1) <= 1 then return 1 end
    return CombatRules.FRONT_ARROW_FACTOR ^ (count - 1)
end

-- Damage after a multiplier, whole points, never below 1 (the epsilon absorbs float noise)
function CombatRules.scaled(damage, factor)
    return math.max(1, math.floor(damage * factor + 1e-6))
end

return CombatRules
