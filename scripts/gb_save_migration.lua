-- Load valid slots first, then recover legacy overflow without promoting tiers.
local M = {}
function M.Install(inst)
    local container = inst.components.container
    local pending = {}
    local function Flush(removing)
        if #pending == 0 then return end
        local owner = inst.components.inventoryitem:GetGrandOwner() or inst
        local pos = owner:GetPosition()
        local items = pending
        pending = {}
        for _, entry in ipairs(items) do
            local item = entry.item
            item.persists = entry.persists
            if item:IsValid() and (removing or not container:GiveItem(item, nil, pos, false)) then
                item.Transform:SetPosition(pos:Get())
                item.components.inventoryitem:OnDropped(true)
            end
        end
    end
    local load = container.OnLoad
    container.OnLoad = function(self, data, newents)
        local regular, overflow = {}, {}
        for slot, record in pairs(data.items or {}) do
            if type(slot) == "number" and slot >= 1 and slot <= self.numslots then
                regular[slot] = record
            else
                overflow[#overflow + 1] = {slot = slot, record = record}
            end
        end
        table.sort(overflow, function(a, b) return tostring(a.slot) < tostring(b.slot) end)
        load(self, {items = regular}, newents)
        for _, record in ipairs(data.gb_overflow or {}) do
            overflow[#overflow + 1] = {record = record}
        end
        for _, entry in ipairs(overflow) do
            local item = SpawnSaveRecord(entry.record, newents)
            if item ~= nil then
                pending[#pending + 1] = {item = item, persists = item.persists}
                item.persists = false -- saved by the bag until the deferred transfer
            end
        end
        -- Parent inventory/equipment loading finishes before this task, so a
        -- worn bag drops excess at its owner, never at the world's origin.
        if #pending > 0 then inst:DoTaskInTime(0, function() Flush(false) end) end
    end
    local save = container.OnSave
    container.OnSave = function(self, ...)
        local data, refs = save(self, ...)
        if #pending > 0 then
            data = data or {}
            data.gb_overflow = {}
            refs = refs or {}
            for _, entry in ipairs(pending) do
                local item = entry.item
                if item:IsValid() then
                    local record, itemrefs = item:GetSaveRecord()
                    data.gb_overflow[#data.gb_overflow + 1] = record
                    for _, ref in ipairs(itemrefs or {}) do refs[#refs + 1] = ref end
                end
            end
        end
        return data, refs
    end
    inst:ListenForEvent("onremove", function() Flush(true) end)
end
return M
