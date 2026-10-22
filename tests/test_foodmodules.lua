require("class")
local definitions = require("gb_foodmodules")
local FoodModules = require("components/gb_foodmodules")
local Preserver = require("components/preserver")
local Perishable = require("components/perishable")
local Trader = require("components/trader")
local now, temperature = 0, 20
GetTime = function() return now end
GetTemperatureAtXZ = function() return temperature end
GetTaskRemaining = function() return 5 end
FunctionOrValue = function(v, ...) return type(v) == "function" and v(...) or v end
FRAMES = 1 / 30
TUNING = {
    TOTAL_DAY_TIME = 480, PERISH_FRIDGE_MULT = .5,
    PERISH_FRESH = .5, PERISH_STALE = .2, PERISH_GLOBAL_MULT = 1,
    PERISH_GROUND_MULT = 1, PERISH_WET_MULT = 1.3, PERISH_WINTER_MULT = .75,
    PERISH_SUMMER_MULT = 1.25, OVERHEAT_TEMP = 70,
}
TheWorld = {state = {temperature = 20}}
math.clamp = function(v, low, high) return math.max(low, math.min(high, v)) end
local function netvalue(value)
    return {set = function(self, v) value = v end, value = function() return value end}
end
local function entity(prefab)
    local inst = {prefab = prefab, components = {}, tags = {}, events = {}, received = {}, valid = true}
    function inst:HasTag(tag) return self.tags[tag] == true end
    function inst:AddTag(tag) self.tags[tag] = true end
    function inst:RemoveTag(tag) self.tags[tag] = nil end
    function inst:IsValid() return self.valid end
    function inst:Remove() self.valid = false end
    function inst:GetPosition() return {x = 0, y = 0, z = 0} end
    function inst:GetIsWet() return self.wet == true end
    function inst:ListenForEvent(event, fn) self.events[event] = fn end
    function inst:RemoveEventCallback(event, fn) if self.events[event] == fn then self.events[event] = nil end end
    function inst:PushEvent(event, data)
        self.received[event] = (self.received[event] or 0) + 1
        if self.events[event] then self.events[event](self, data) end
    end
    function inst:DoPeriodicTask(period, fn, delay, dt)
        return {period = period, fn = function() fn(self, dt) end,
            Cancel = function(self) self.cancelled = true end}
    end
    function inst:AddComponent(name)
        assert(name == "preserver")
        self.components[name] = Preserver(self)
    end
    inst.components.inventoryitem = {
        RemoveFromOwner = function(self) self.owner = nil end,
    }
    return inst
end
local function pack(level)
    local p = entity("growing_backpack")
    p._gb_level, p._gb_modules = netvalue(level), netvalue(0)
    p.components.container = {slots = {}}
    local modules = FoodModules(p)
    p.components.gb_foodmodules = modules
    p.components.trader = Trader(p)
    p.components.trader:SetAcceptTest(function(_, item) return modules:CanInstall(item) end)
    p.components.trader:SetOnAccept(function(_, _, item) modules:Install(item) end)
    return p, modules
end
local function install(p, prefab, accepted)
    local kit = entity(prefab)
    assert(p.components.trader:AcceptGift(nil, kit) == accepted)
    assert(kit:IsValid() == not accepted, "refusal must not consume; success must consume")
    return kit
end
local function food(p, prefab, edible, percent, lifetime)
    local item = entity(prefab or "berries")
    if edible ~= false then item.components.edible = {} end
    local perish = Perishable(item)
    item.components.perishable = perish
    perish:SetPerishTime(lifetime or 1000)
    perish:SetPercent(percent or .1)
    perish:StartPerishing()
    item.components.inventoryitem.owner = p
    p.components.container.slots[#p.components.container.slots + 1] = item
    p:PushEvent("itemget", {item = item})
    return item, perish
end
local function near(actual, expected) assert(math.abs(actual - expected) < .000001, actual .. " ~= " .. expected) end
local function decay(perish, time) perish.start_dt = nil; perish:LongUpdate(time) end
local count = 0
local function test(name, fn)
    fn(); count = count + 1; print("FOODMODULE_PASS " .. name)
end

test("tier gates and duplicate modules refuse without consuming", function()
    for level = 0, 3 do
        local p = pack(level)
        install(p, "gb_preservation_kit", level >= 2)
        install(p, "gb_freshness_kit", level >= 3)
        install(p, "gb_preservation_kit", false)
        install(p, "gb_freshness_kit", false)
    end
end)

test("equipped and burning packs refuse installation", function()
    local p = pack(3)
    p.components.inventoryitem.owner = {}
    install(p, "gb_freshness_kit", false)
    p.components.inventoryitem.owner = nil
    p.components.burnable = {IsBurning = function() return true end}
    install(p, "gb_preservation_kit", false)
    assert(p._gb_modules:value() == 0)
end)

test("75 percent of vanilla icebox spoilage reduction, food only", function()
    local p, modules = pack(2)
    install(p, "gb_preservation_kit", true)
    local item, perish = food(p, "berries", true, .9)
    near(p.components.preserver:GetPerishRateMultiplier(item), .625)
    decay(perish, 100)
    near(perish:GetPercent(), .8375)
    local flower, flowerperish = food(p, "petals", false, .9)
    near(p.components.preserver:GetPerishRateMultiplier(flower), 1)
    decay(flowerperish, 100)
    near(flowerperish:GetPercent(), .8)
    TUNING.PERISH_FRIDGE_MULT = .4
    near(definitions.PreservationRate(), .55)
    TUNING.PERISH_FRIDGE_MULT = .5
end)

test("freshness installs independently and native spoilage stops", function()
    local p, modules = pack(3)
    install(p, "gb_freshness_kit", true)
    assert(not modules.preservation and p._gb_modules:value() == 2)
    local item, perish = food(p, "berries", true, .1)
    temperature = 90; item.wet = true
    decay(perish, 200)
    near(perish:GetPercent(), .1)
    modules:LongUpdate(TUNING.TOTAL_DAY_TIME)
    near(perish:GetPercent(), .35)
    temperature = 20; item.wet = false
    modules:LongUpdate(3 * TUNING.TOTAL_DAY_TIME)
    near(perish:GetPercent(), 1)
    assert(item:HasTag("fresh"))
    assert(item.received.perishchange > 0 and item.received.forceperishchange > 0)
    modules:LongUpdate(10000)
    near(perish:GetPercent(), 1)
end)

test("fixed recovery percentage for different food lifetimes", function()
    local p, modules = pack(3)
    install(p, "gb_freshness_kit", true)
    local _, short = food(p, "berries", true, .01, 480)
    local _, long = food(p, "meat", true, .01, 9600)
    modules:LongUpdate(480)
    near(short:GetPercent(), .26); near(long:GetPercent(), .26)
end)

test("rot, nonfoods, dead perish timers and paused foods never rejuvenate", function()
    local p, modules = pack(3)
    install(p, "gb_freshness_kit", true)
    local _, rot = food(p, "spoiled_food", true, .2)
    local _, petals = food(p, "petals", false, .2)
    local _, expired = food(p, "berries", true, 0)
    local _, paused = food(p, "meat", true, .2)
    paused:StopPerishing()
    modules:LongUpdate(4 * TUNING.TOTAL_DAY_TIME)
    near(rot:GetPercent(), .2); near(petals:GetPercent(), .2)
    near(expired:GetPercent(), 0); near(paused:GetPercent(), .2)
end)

test("removing food immediately resumes normal spoilage without lingering modifiers", function()
    local p, modules = pack(3)
    install(p, "gb_freshness_kit", true)
    local item, perish = food(p, "berries", true, .5)
    p.components.container.slots = {}
    p:PushEvent("itemlose", {prev_item = item})
    item.components.inventoryitem.owner = nil
    modules:LongUpdate(480)
    near(perish:GetPercent(), .5)
    decay(perish, 100)
    near(perish:GetPercent(), .4)
end)

test("newly inserted food receives only time actually held", function()
    now = 100
    local p, modules = pack(3)
    install(p, "gb_freshness_kit", true)
    now = 109
    local _, perish = food(p, "berries", true, .1)
    now = 110
    modules.task.fn()
    near(perish:GetPercent(), .1 + 1 / 1920)
    now = 120
    modules.task.fn()
    near(perish:GetPercent(), .1 + 11 / 1920)
end)

test("save and load retain independent flags and freshness priority", function()
    local p, modules = pack(2)
    install(p, "gb_preservation_kit", true)
    local data = modules:OnSave()
    assert(data.preservation and not data.freshness)
    p._gb_level:set(3)
    install(p, "gb_freshness_kit", true)
    data = modules:OnSave()
    local restored, loaded = pack(3)
    loaded:OnLoad(data)
    assert(loaded.preservation and loaded.freshness and restored._gb_modules:value() == 3)
    local item = food(restored, "berries", true, .2)
    near(restored.components.preserver:GetPerishRateMultiplier(item), 0)
    assert(definitions.Description(3):find("返鲜优先"))
    local old, oldmodules = pack(3)
    oldmodules:OnLoad(nil)
    assert(old._gb_modules:value() == 0 and old.components.preserver == nil)
end)

test("client-only install selection replaces store only for its own interaction", function()
    local action = require("gb_module_action")
    local installaction = {id = "GB_INSTALL_MODULE"}
    local player = {replica = {}}
    local kit = {HasTag = function(_, tag) return tag == "gb_foodmodule_kit" end,
        replica = {inventoryitem = {IsGrandOwner = function(_, doer) return doer == player end,
            IsLockedInSlot = function() return false end}}}
    local choices = {{id = "STORE"}, {id = "GIVE"}}
    action.Collect(installaction, kit, player, {prefab = "growing_backpack"}, choices)
    assert(#choices == 1 and choices[1] == installaction)
    choices = {{id = "STORE"}}
    action.Collect(installaction, kit, player, {prefab = "treasurechest"}, choices)
    assert(#choices == 1 and choices[1].id == "STORE")
    choices = {{id = "STORE"}}
    action.Collect(installaction, kit, {replica = {}}, {prefab = "growing_backpack"}, choices)
    assert(#choices == 1 and choices[1].id == "STORE")
end)

print("FOODMODULE_SUCCESS " .. count .. " tests")
