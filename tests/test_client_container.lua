require("class")
local noop = function() end
local pending = {}
local function Drain()
    local ticks = 0
    while #pending > 0 do
        ticks = ticks + 1
        assert(ticks < 30, "task loop")
        local current = pending; pending = {}
        for _, task in ipairs(current) do if not task.cancelled then task.fn() end end
    end
end
local function NetworkValue(initial)
    local value = initial
    return {value=function() return value end, set=function(self,v) value=v end}
end
net_bool = function() return NetworkValue(false) end
net_entity = function() return NetworkValue(nil) end
net_tinybyte = function() return NetworkValue(0) end
Vector3 = function(x,y,z) return {x=x,y=y,z=z} end
local layout = require("gb_layout")
local containers = {MAXITEMSLOTS=32, params={}}
for level=0,3 do containers.params["growing_backpack_"..level] = layout.Make(level,Vector3) end
containers.params.growing_backpack = containers.params.growing_backpack_0
function containers.widgetsetup(container, prefab, data)
    local definition = data or containers.params[prefab or container.inst.prefab]
    if definition then
        for k,v in pairs(definition) do container[k]=v end
        container:SetNumSlots(container.widget.numslots or #container.widget.slotpos)
    end
end
package.loaded.containers = containers
local guid = 0
local function Entity()
    guid=guid+1
    local inst = {GUID=guid,components={},replica={},events={},received={}}
    inst.entity=setmetatable({GetParent=function() return inst.parent end},{__index=function() return noop end})
    inst.AnimState=setmetatable({},{__index=function() return noop end})
    inst.MiniMapEntity=setmetatable({},{__index=function() return noop end})
    function inst:AddTag() end
    function inst:IsValid() return true end
    function inst:ListenForEvent(event, fn, source)
        source=source or self
        source.events[event]=source.events[event] or {}
        table.insert(source.events[event], fn)
    end
    function inst:RemoveEventCallback() end
    function inst:PushEvent(event, data)
        self.received[#self.received+1]={event=event,data=data}
        for _,fn in ipairs(self.events[event] or {}) do fn(self,data) end
    end
    function inst:DoStaticTaskInTime(delay, fn, ...)
        local args={...}
        local task={fn=function() fn(self,unpack(args)) end,Cancel=function(self) self.cancelled=true end}
        table.insert(pending,task)
        return task
    end
    inst.DoTaskInTime=inst.DoStaticTaskInTime
    function inst:TryAttachClassifiedToReplicaComponent(classified)
        self.replica.container:AttachClassified(classified)
        return true
    end
    return inst
end
CreateEntity=Entity
Prefab=function(name,fn) return fn end
TheWorld=Entity(); TheWorld.ismastersim=false
ThePlayer=Entity()
local opened,closed=0,0
ThePlayer.HUD={OpenContainer=function() opened=opened+1 end,CloseContainer=function() closed=closed+1 end}
EntityScriptProxy=function(item) return item end
local Replica=require("components/container_replica")
local Classified=require("prefabs/container_classified")
local sync=require("gb_client_container")

local function Setup(level, waiting)
    local parent=Entity(); parent.prefab="growing_backpack"; parent._gb_level=NetworkValue(level)
    local classified=Classified(); classified.parent=parent
    if waiting then parent.container_classified=classified end
    local replica=Replica(parent); parent.replica.container=replica
    sync.Install(replica)
    if waiting then classified._parent=parent else classified:OnEntityReplicated() end
    replica:SetSkipOpenSnd(true); replica:SetSkipCloseSnd(true)
    replica.opener={}
    Drain()
    replica:Open(ThePlayer)
    return parent,replica,classified
end

local parent,replica,classified=Setup(0)
assert(classified._slottasks ~= nil and #classified._items == 8)
local ok,err=pcall(function() replica:WidgetSetup("growing_backpack_0") end)
assert(not ok and tostring(err):find("assertion failed"), "must reproduce the original vanilla assertion")
print("CLIENT_PASS reproduced original post-listener WidgetSetup crash")
for i=1,4 do sync.Refresh(parent); Drain() end
assert(replica:GetNumSlots()==8 and #classified._items==8 and replica:IsOpenedBy(ThePlayer))
print("CLIENT_PASS repeated initialization after auto-equip is safe")

for level=0,3 do
    parent._gb_level:set(level)
    sync.Refresh(parent); Drain()
    local count=8*(level+1)
    assert(replica:GetNumSlots()==count and #classified._items==count)
    assert(#replica:GetWidget().slotpos==count and replica:IsOpenedBy(ThePlayer))
    local item={prefab="rocks", replica={}}
    for i=1,count do classified._items[i]:set(item) end
    assert(classified:IsFull(), "hidden slots must not count as free space")
    local before=#parent.received
    classified:PushEvent("items["..count.."]dirty")
    Drain()
    local received=false
    for i=before+1,#parent.received do
        local event=parent.received[i]
        if event.event=="itemget" and event.data.slot==count and event.data.item==item then received=true end
    end
    assert(received,"newly unlocked last slot must have an active vanilla listener")
    assert(replica:GetItemInSlot(count)==item)
end
assert(opened==4 and closed==3)
print("CLIENT_PASS all tiers retain live last-slot updates, full detection, and open UI")

replica:Close(); replica:DetachClassified()
local replacement=Classified(); replacement.parent=parent; replacement:OnEntityReplicated(); Drain()
replica:Open(ThePlayer)
assert(#replacement._items==32 and replica:GetNumSlots()==32)
for level=0,3 do
    for _,waiting in ipairs({false,true}) do
        local p,r,c=Setup(level,waiting)
        sync.Refresh(p); Drain()
        assert(#c._items==8*(level+1) and r:GetNumSlots()==8*(level+1))
        assert(#c.events["items[32]dirty"]==1, "reserve slot listener must be registered exactly once")
    end
end
print("CLIENT_PASS reopen, late join at every level, and classified-before-replica ordering")

Asset=noop
MakeInventoryPhysics=noop
MakeInventoryFloatable=noop
local packfn=require("prefabs/growing_backpack")
local pack=packfn(); pack.prefab="growing_backpack"
local r=Replica(pack); pack.replica.container=r; sync.Install(r)
local c=Classified(); c.parent=pack; c:OnEntityReplicated()
r:SetSkipOpenSnd(true); r:SetSkipCloseSnd(true); r.opener={}; r:Open(ThePlayer)
Drain() -- actual prefab's zero-delay callback, with an already-open container
assert(#c._items==8 and r:IsOpenedBy(ThePlayer))
for level=1,3 do
    pack._gb_level:set(level); pack:PushEvent("gb_leveldirty"); Drain()
    assert(#c._items==8*(level+1) and r:GetNumSlots()==8*(level+1))
end
print("CLIENT_PASS actual prefab initial task and level-dirty events with real vanilla replicas")
