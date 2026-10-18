local containers = require("containers")
local M = {}
local MAX_SLOTS = 32

local function SetActiveSlots(classified, count)
    if not classified._gb_dynamic_slots or classified._slottasks == nil then
        return
    end
    -- The vanilla listeners were registered once for all 32 existing netvars.
    -- Only repartition the active list and reserve pool; never reinitialize the
    -- classified or create netvars after its network listeners have started.
    local current = #classified._items
    if current == count then return end
    if current < count then
        for i = current + 1, count do
            table.insert(classified._items, table.remove(classified._itemspool, 1))
        end
    else
        for i = current, count + 1, -1 do
            table.insert(classified._itemspool, 1, table.remove(classified._items))
        end
    end
    classified._itemspreview = nil
end

function M.Refresh(inst)
    local replica = inst.replica.container
    if replica == nil then return end
    local key = "growing_backpack_" .. inst._gb_level:value()
    local changed = replica:GetWidget() ~= containers.params[key].widget
    local wasopen = changed and ThePlayer ~= nil and replica:IsOpenedBy(ThePlayer)
    if wasopen then replica:Close() end
    -- WidgetSetup also calls classified:InitializeSlots(), which is illegal
    -- after RegisterNetListeners. widgetsetup changes only the layout/count.
    containers.widgetsetup(replica, key)
    if replica.classified then
        SetActiveSlots(replica.classified, replica:GetNumSlots())
    end
    if wasopen then replica:Open(ThePlayer) end
end

local function Prepare(replica, classified)
    if classified._gb_dynamic_slots then return end
    classified:InitializeSlots(MAX_SLOTS)
    classified._gb_dynamic_slots = true
    local function Finish()
        if replica.classified ~= classified then return end
        if classified._slottasks == nil then
            classified:DoStaticTaskInTime(0, Finish)
        else
            M.Refresh(replica.inst)
        end
    end
    classified:DoStaticTaskInTime(0, Finish)
end

function M.Install(replica)
    if TheWorld.ismastersim or replica._gb_dynamic_installed then return end
    replica._gb_dynamic_installed = true
    local attach = replica.AttachClassified
    replica.AttachClassified = function(self, classified)
        attach(self, classified)
        Prepare(self, classified)
    end
    -- A classified can already be waiting when the replica is constructed.
    if replica.classified then Prepare(replica, replica.classified) end
end

return M
