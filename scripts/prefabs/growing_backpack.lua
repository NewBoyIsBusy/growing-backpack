local layout = require("gb_layout")
local appearance = require("gb_appearance")
local assets = {
    Asset("ANIM", "anim/backpack.zip"),
    Asset("ANIM", "anim/swap_backpack.zip"),
    Asset("ANIM", "anim/piggyback.zip"),
    Asset("ANIM", "anim/swap_piggyback.zip"),
    Asset("ANIM", "anim/swap_icepack.zip"),
    Asset("ANIM", "anim/swap_krampus_sack.zip"),
    Asset("ANIM", "anim/ui_backpack_2x4.zip"),
}
local kitnames = { "皮革扩容工具", "机械扩容工具", "远古扩容工具" }

local function ApplyClientLayout(inst)
    -- Ground animation and inventory image are replicated by the engine.
    -- Floater settings are local Lua state, so initialize them for late joiners too.
    local look = appearance.Get(inst._gb_level:value())
    local floater = inst.components.floater
    if floater then
        floater:SetSwapData({ bank = look.bank, anim = "anim" })
        floater:SetSize(look.size)
        floater:SetVerticalOffset(look.offset)
        floater:SetScale(look.scale)
    end
    local container = inst.replica.container
    if container == nil then return end
    local wasopen = ThePlayer ~= nil and container:IsOpenedBy(ThePlayer)
    if wasopen then container:Close() end
    container:WidgetSetup("growing_backpack_" .. inst._gb_level:value())
    if wasopen then container:Open(ThePlayer) end
end

local function SetLevel(inst, level)
    level = math.max(inst._gb_level:value(), layout.ClampLevel(level))
    inst._gb_level:set(level)
    inst.components.container:WidgetSetup("growing_backpack_" .. level)
    appearance.Apply(inst)
end

local function CanUpgrade(inst, item)
    return inst._gb_level:value() < 3
        and item.prefab == "gb_upgrade_" .. (inst._gb_level:value() + 1)
        and inst.components.inventoryitem.owner == nil
        and not (inst.components.burnable and inst.components.burnable:IsBurning())
end

local function OnUpgrade(inst, giver)
    SetLevel(inst, inst._gb_level:value() + 1)
    if giver and giver.components.talker then
        giver.components.talker:Say("扩容完成！现在有 " .. layout.Slots(inst._gb_level:value()) .. " 格。")
    end
end

local function OnRefuse(inst, giver)
    if giver and giver.components.talker then
        local level = inst._gb_level:value()
        giver.components.talker:Say(level == 3 and "背包已经升到满级了。"
            or "把背包放在地上，再用" .. kitnames[level + 1] .. "扩容。")
    end
end

local function OnEquip(inst, owner)
    appearance.Equip(inst, owner)
    inst.components.container:Open(owner)
end

local function OnUnequip(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_body")
    owner.AnimState:ClearOverrideSymbol("backpack")
    inst.components.container:Close(owner)
end

local function OnBurnt(inst)
    inst.components.container:DropEverything()
    inst.components.container:Close()
    local ash = SpawnPrefab("ash")
    if ash then ash.Transform:SetPosition(inst.Transform:GetWorldPosition()) end
    inst:Remove()
end

local function fn()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddSoundEmitter()
    inst.entity:AddMiniMapEntity()
    inst.entity:AddNetwork()
    MakeInventoryPhysics(inst)
    inst.AnimState:SetBank("backpack1")
    inst.AnimState:SetBuild("swap_backpack")
    inst.AnimState:PlayAnimation("anim")
    inst.MiniMapEntity:SetIcon("backpack.png")
    inst:AddTag("backpack")
    inst:AddTag("trader")
    inst.foleysound = "dontstarve/movement/foley/backpack"
    inst._gb_level = net_tinybyte(inst.GUID, "growing_backpack.level", "gb_leveldirty")
    inst._gb_level:set(0)
    inst.displaynamefn = function(inst)
        return "成长背包（" .. layout.Slots(inst._gb_level:value()) .. "格）"
    end
    MakeInventoryFloatable(inst, "small", .2, nil, nil, nil, {bank = "backpack1", anim = "anim"})
    inst.entity:SetPristine()

    if not TheWorld.ismastersim then
        inst:ListenForEvent("gb_leveldirty", ApplyClientLayout)
        inst:DoTaskInTime(0, ApplyClientLayout)
        return inst
    end

    inst:AddComponent("inspectable")
    inst.components.inspectable.descriptionfn = function(inst)
        local level = inst._gb_level:value()
        return "容量：" .. layout.Slots(level) .. " 格。"
            .. (level == 3 and "已完成全部扩容。" or "下一阶段需要" .. kitnames[level + 1] .. "，放在地上后使用“扩容背包”。")
    end
    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem:ChangeImageName("backpack")
    inst.components.inventoryitem.cangoincontainer = false
    inst:AddComponent("equippable")
    inst.components.equippable.equipslot = EQUIPSLOTS.BODY
    inst.components.equippable:SetOnEquip(OnEquip)
    inst.components.equippable:SetOnUnequip(OnUnequip)
    inst.components.equippable:SetOnEquipToModel(function(inst) inst.components.container:Close() end)
    inst:AddComponent("container")
    SetLevel(inst, 0)
    inst:AddComponent("trader")
    inst.components.trader:SetAcceptTest(CanUpgrade)
    inst.components.trader:SetOnAccept(OnUpgrade)
    inst.components.trader:SetOnRefuse(OnRefuse)
    MakeSmallBurnable(inst)
    MakeSmallPropagator(inst)
    inst.components.burnable:SetOnBurntFn(OnBurnt)
    inst.components.burnable:SetOnIgniteFn(function(inst) inst.components.container.canbeopened = false end)
    inst.components.burnable:SetOnExtinguishFn(function(inst) inst.components.container.canbeopened = true end)
    MakeHauntableLaunchAndDropFirstItem(inst)
    inst.OnSave = function(inst, data) data.gb_level = inst._gb_level:value() end
    -- Resize BEFORE container.OnLoad restores items in slots 9 through 32.
    inst.OnPreLoad = function(inst, data)
        local level = data and layout.ClampLevel(data.gb_level) or 0
        -- Recover capacity from contents if an old or incomplete save omits its level.
        for slot in pairs(data and data.container and data.container.items or {}) do
            if type(slot) == "number" then level = math.max(level, math.ceil(slot / 8) - 1) end
        end
        SetLevel(inst, level)
    end
    return inst
end

return Prefab("growing_backpack", fn, assets, { "ash" })
