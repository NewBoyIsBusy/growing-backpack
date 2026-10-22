-- Four original sprite builds share the vanilla backpack's animation rig.
local layout = require("gb_layout")
local M = {}
local looks = {
    { bank = "backpack1", build = "gb_pack_0", image = "gb_pack_0", size = "small", offset = .2, scale = 1 },
    { bank = "backpack1", build = "gb_pack_1", image = "gb_pack_1", size = "small", offset = .2, scale = 1 },
    { bank = "backpack1", build = "gb_pack_2", image = "gb_pack_2", size = "small", offset = .2, scale = 1 },
    { bank = "backpack1", build = "gb_pack_3", image = "gb_pack_3", size = "small", offset = .2, scale = 1 },
}
for _, look in ipairs(looks) do
    look.atlas = "images/" .. look.image .. ".xml"
end

function M.Get(level)
    return looks[layout.ClampLevel(level) + 1]
end

function M.Equip(inst, owner)
    local look = M.Get(inst._gb_level:value())
    owner.AnimState:ClearOverrideSymbol("backpack")
    owner.AnimState:OverrideSymbol("swap_body", look.build, "swap_body")
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
        inventoryitem.atlasname = look.atlas
        inventoryitem:ChangeImageName(look.image)
        local equipped = inst.components.equippable
        if equipped and equipped:IsEquipped() and inventoryitem.owner then
            M.Equip(inst, inventoryitem.owner)
        end
    end
end

return M
