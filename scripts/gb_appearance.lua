-- Vanilla art only; no skin entitlements or gameplay components are copied.
local layout = require("gb_layout")
local M = {}
local looks = {
    { bank = "backpack1", build = "swap_backpack", image = "backpack", size = "small", offset = .2, scale = 1 },
    { bank = "piggyback", build = "swap_piggyback", image = "piggyback", size = "small", offset = .1, scale = .85 },
    { bank = "backpack1", build = "swap_icepack", image = "icepack", size = "small", offset = .15, scale = 1, backpack_symbol = true },
    { bank = "backpack1", build = "swap_krampus_sack", image = "krampus_sack", size = "med", offset = .1, scale = .65, backpack_symbol = true },
}

function M.Get(level)
    return looks[layout.ClampLevel(level) + 1]
end

function M.Equip(inst, owner)
    local look = M.Get(inst._gb_level:value())
    owner.AnimState:ClearOverrideSymbol("backpack")
    owner.AnimState:OverrideSymbol("swap_body", look.build, "swap_body")
    if look.backpack_symbol then
        owner.AnimState:OverrideSymbol("backpack", look.build, "backpack")
    end
end

function M.Apply(inst)
    local look = M.Get(inst._gb_level:value())
    inst.AnimState:SetBank(look.bank)
    inst.AnimState:SetBuild(look.build)
    inst.AnimState:PlayAnimation("anim")
    inst.MiniMapEntity:SetIcon(look.image .. ".png")
    local floater = inst.components.floater
    if floater then
        floater:SetSwapData({ bank = look.bank, anim = "anim" })
        floater:SetSize(look.size)
        floater:SetVerticalOffset(look.offset)
        floater:SetScale(look.scale)
    end
    local inventoryitem = inst.components.inventoryitem
    if inventoryitem then
        inventoryitem:ChangeImageName(look.image)
        local equipped = inst.components.equippable
        if equipped and equipped:IsEquipped() and inventoryitem.owner then
            M.Equip(inst, inventoryitem.owner)
        end
    end
end

return M
