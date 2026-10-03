local Admin = require("src.data.admin")

local T = {}

local function fresh()
    Admin.load(nil)
end

T["valeurs par défaut, rien de modifié"] = function()
    fresh()
    assert(Admin.get("hpMult") == 1 and Admin.get("god") == false)
    assert(not Admin.isModified())
end

T["pas et bornes des curseurs"] = function()
    fresh()
    Admin.step("hpMult", 1)
    assert(math.abs(Admin.get("hpMult") - 1.1) < 1e-9)
    for _ = 1, 50 do Admin.step("hpMult", 1) end
    assert(Admin.get("hpMult") == 2.0)
    for _ = 1, 50 do Admin.step("hpMult", -1) end
    assert(Admin.get("hpMult") == 0.5)
    assert(Admin.isModified())
end

T["pas exacts (pas d'erreur d'arrondi cumulée)"] = function()
    fresh()
    for _ = 1, 5 do Admin.step("hpMult", 1) end
    for _ = 1, 5 do Admin.step("hpMult", -1) end
    assert(Admin.get("hpMult") == 1)
    assert(not Admin.isModified())
end

T["bascules des triches"] = function()
    fresh()
    Admin.toggle("god")
    assert(Admin.get("god") == true and Admin.isModified())
    Admin.toggle("god")
    assert(Admin.get("god") == false and not Admin.isModified())
end

T["resetTuning remet tout par défaut"] = function()
    fresh()
    Admin.step("eliteMult", 2)
    Admin.toggle("oneHit")
    Admin.resetTuning()
    assert(not Admin.isModified())
end

T["chargement validé"] = function()
    Admin.load({ hpMult = 1.5, budgetMult = "beaucoup", eliteMult = 99, god = "oui", infUlt = true, inconnu = 3 })
    assert(Admin.get("hpMult") == 1.5)
    assert(Admin.get("budgetMult") == 1)   -- type invalide
    assert(Admin.get("eliteMult") == 3)    -- borné
    assert(Admin.get("god") == false)      -- type invalide
    assert(Admin.get("infUlt") == true)
    assert(Admin.get("inconnu") == nil)
    fresh()
end

T["aller-retour export / load"] = function()
    fresh()
    Admin.step("goldMult", 2)
    Admin.toggle("infUlt")
    local saved = Admin.export()
    fresh()
    Admin.load(saved)
    assert(Admin.get("goldMult") == 2 and Admin.get("infUlt") == true)
    fresh()
end

T["identifiant inconnu refusé"] = function()
    fresh()
    assert(not pcall(Admin.step, "nope", 1))
    assert(not pcall(Admin.toggle, "nope"))
end

return T
