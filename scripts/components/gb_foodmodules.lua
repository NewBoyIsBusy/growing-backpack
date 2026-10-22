local definitions = require("gb_foodmodules")
local TICK_TIME = 10

local FoodModules = Class(function(self, inst)
    self.inst = inst
    self.preservation = false
    self.freshness = false
    self.entered = setmetatable({}, { __mode = "k" })
    self.onitemget = function(_, data)
        if data and data.item then self.entered[data.item] = GetTime() end
    end
    self.onitemlose = function(_, data)
        if data and data.prev_item then self.entered[data.prev_item] = nil end
    end
    inst:ListenForEvent("itemget", self.onitemget)
    inst:ListenForEvent("itemlose", self.onitemlose)
end)

function FoodModules:CanInstall(item)
    local spec = item ~= nil and definitions.KITS[item.prefab] or nil
    if spec == nil then return false, "这不是背包功能插件。" end
    if self.inst.components.inventoryitem.owner ~= nil then
        return false, "先把背包放在地上，再安装插件。"
    end
    if self.inst.components.burnable and self.inst.components.burnable:IsBurning() then
        return false, "先把背包上的火扑灭。"
    end
    if self[spec.key] then return false, spec.name .. "已经安装了。" end
    if self.inst._gb_level:value() < spec.level then
        return false, spec.level == 2 and "机械包或远古包才能安装保鲜插件。"
            or "远古包才能安装返鲜插件。"
    end
    return true
end

function FoodModules:Install(item)
    -- Trader rechecks CanInstall before consuming the item. This method runs
    -- after consumption, so it uses only the accepted prefab's stable name.
    local spec = definitions.KITS[item.prefab]
    if spec == nil then return end
    self[spec.key] = true
    self:Apply()
end

function FoodModules:GetPerishRate(item)
    if not definitions.IsFood(item) then return 1 end
    if self.freshness then return 0 end
    return self.preservation and definitions.PreservationRate() or 1
end

function FoodModules:Apply()
    self.inst._gb_modules:set((self.preservation and 1 or 0) + (self.freshness and 2 or 0))
    if self.preservation or self.freshness then
        if self.inst.components.preserver == nil then self.inst:AddComponent("preserver") end
        self.inst.components.preserver:SetPerishRateMultiplier(function(_, item)
            return self:GetPerishRate(item)
        end)
    end
    if self.freshness and self.task == nil then
        for _, item in pairs(self.inst.components.container.slots) do
            self.entered[item] = GetTime()
        end
        self.task = self.inst:DoPeriodicTask(TICK_TIME, function() self:Refresh(TICK_TIME, false) end)
    end
end

function FoodModules:Refresh(dt, longupdate)
    if not self.freshness or dt <= 0 then return end
    local now = GetTime()
    local duration = 4 * TUNING.TOTAL_DAY_TIME
    for _, item in pairs(self.inst.components.container.slots) do
        if definitions.IsFood(item) and item.components.inventoryitem
            and item.components.inventoryitem.owner == self.inst then
            local perishable = item.components.perishable
            -- Native AddTime preserves perishable tags, events and network
            -- updates. It also respects foods whose perish timer is paused.
            -- Never replace rot, change max perish time, or modify food data.
            local elapsed = longupdate and dt or math.min(dt, math.max(0, now - (self.entered[item] or now)))
            if perishable:IsPerishing() and perishable:GetPercent() < 1 then
                perishable:AddTime(perishable.perishtime * elapsed / duration)
            end
            self.entered[item] = now
        end
    end
end

function FoodModules:LongUpdate(dt)
    self:Refresh(dt or 0, true)
end

function FoodModules:OnSave()
    return (self.preservation or self.freshness) and {
        preservation = self.preservation or nil,
        freshness = self.freshness or nil,
    } or nil
end

function FoodModules:OnLoad(data)
    if data then
        self.preservation = data.preservation == true
        self.freshness = data.freshness == true
        self:Apply()
    end
end

function FoodModules:OnRemoveFromEntity()
    if self.task then self.task:Cancel(); self.task = nil end
    self.inst:RemoveEventCallback("itemget", self.onitemget)
    self.inst:RemoveEventCallback("itemlose", self.onitemlose)
end

return FoodModules
