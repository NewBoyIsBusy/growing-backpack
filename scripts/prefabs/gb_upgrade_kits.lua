local function MakeKit(name, tag)
    local atlas = "images/" .. name .. ".xml"
    local assets = {
        Asset("ANIM", "anim/" .. name .. ".zip"),
        Asset("ATLAS", atlas),
        Asset("IMAGE", "images/" .. name .. ".tex"),
    }
    local function fn()
        local inst = CreateEntity()
        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()
        MakeInventoryPhysics(inst)
        inst.AnimState:SetBank(name)
        inst.AnimState:SetBuild(name)
        inst.AnimState:PlayAnimation("idle")
        inst:AddTag(tag)
        MakeInventoryFloatable(inst, "small", .05, .8)
        inst.entity:SetPristine()
        if not TheWorld.ismastersim then return inst end
        inst:AddComponent("inspectable")
        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.atlasname = atlas
        inst.components.inventoryitem:ChangeImageName(name)
        inst:AddComponent("tradable")
        MakeHauntableLaunch(inst)
        return inst
    end
    return Prefab(name, fn, assets)
end

return MakeKit("gb_upgrade_1", "gb_upgrade_kit"),
    MakeKit("gb_upgrade_2", "gb_upgrade_kit"),
    MakeKit("gb_upgrade_3", "gb_upgrade_kit"),
    MakeKit("gb_preservation_kit", "gb_foodmodule_kit"),
    MakeKit("gb_freshness_kit", "gb_foodmodule_kit")
