local M = {}

function M.Collect(action, inst, doer, target, actions)
    if not inst:HasTag("gb_upgrade_kit") or target == nil
        or target.prefab ~= "growing_backpack" then
        return
    end
    local inventoryitem = inst.replica.inventoryitem
    local rider = doer.replica.rider
    if inventoryitem == nil or not inventoryitem:IsGrandOwner(doer)
        or inventoryitem:IsLockedInSlot()
        or (rider ~= nil and rider:IsRiding()) then
        return
    end
    -- Replace the ambiguous vanilla STORE/GIVE pair only for this interaction.
    for i = #actions, 1, -1 do
        if actions[i].id == "STORE" or actions[i].id == "GIVE" then
            table.remove(actions, i)
        end
    end
    actions[#actions + 1] = action
end

function M.Perform(act)
    local item, target, doer = act.invobject, act.target, act.doer
    if item == nil or target == nil or doer == nil
        or not item:IsValid() or not target:IsValid()
        or not item:HasTag("gb_upgrade_kit") or target.prefab ~= "growing_backpack" then
        return false
    end
    local inventoryitem = item.components.inventoryitem
    local rider = doer.components.rider
    if inventoryitem == nil or inventoryitem:GetGrandOwner() ~= doer
        or inventoryitem.islockedinslot
        or (rider ~= nil and rider:IsRiding()) then
        return false
    end
    -- Recheck level, ownership and fire state at execution time via the trader.
    -- Refused upgrades leave the kit in the player's inventory.
    return target.components.trader ~= nil
        and target.components.trader:AcceptGift(doer, item) or false
end

return M
