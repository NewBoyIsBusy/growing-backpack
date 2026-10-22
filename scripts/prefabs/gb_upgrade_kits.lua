local function MakeKit(level)
    local name = "gb_upgrade_" .. level
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
        inst:AddTag("gb_upgrade_kit")
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

return MakeKit(1), MakeKit(2), MakeKit(3)
