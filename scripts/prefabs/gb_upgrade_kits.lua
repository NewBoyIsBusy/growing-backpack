local assets = { Asset("ANIM", "anim/sewing_kit.zip") }
local colours = { {1, .8, .5}, {.6, .85, 1}, {1, .9, .25} }

local function MakeKit(level)
    local function fn()
        local inst = CreateEntity()
        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()
        MakeInventoryPhysics(inst)
        inst.AnimState:SetBank("sewing_kit")
        inst.AnimState:SetBuild("sewing_kit")
        inst.AnimState:PlayAnimation("idle")
        inst.AnimState:SetMultColour(colours[level][1], colours[level][2], colours[level][3], 1)
        inst:AddTag("gb_upgrade_kit")
        MakeInventoryFloatable(inst, "small", .05, .8)
        inst.entity:SetPristine()
        if not TheWorld.ismastersim then return inst end
        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem:ChangeImageName("sewing_kit")
        inst:AddComponent("tradable")
        MakeHauntableLaunch(inst)
        return inst
    end
    return Prefab("gb_upgrade_" .. level, fn, assets)
end

return MakeKit(1), MakeKit(2), MakeKit(3)
