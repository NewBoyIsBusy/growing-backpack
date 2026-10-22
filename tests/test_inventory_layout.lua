-- The layout, event callbacks, rebuild and controller navigation under test are
-- from the installed game's actual widgets/inventorybar.lua, not a reimplementation.
require("class")
local checks = 0
local function check(name, fn)
    fn()
    checks = checks + 1
    print("GROWINGPACK_INVENTORY_PASS " .. name)
end
local function noop() end
local vector = {}
function vector:Get() return self.x, self.y, self.z end
function vector:DistSq(other)
    return (self.x-other.x)^2 + (self.y-other.y)^2 + (self.z-other.z)^2
end
function Vector3(x,y,z) return setmetatable({x=x or 0,y=y or 0,z=z or 0}, {__index=vector}) end
function VecUtil_Dot(x,y,u,v) return x*u+y*v end

local function Entity(widget)
    local inst = {widget=widget, valid=true, listeners={}}
    function inst:IsValid() return self.valid end
    function inst:ListenForEvent(event, fn, source)
        source = source or self
        source.listeners[event] = source.listeners[event] or {}
        table.insert(source.listeners[event], {listener=self,fn=fn})
    end
    function inst:RemoveEventCallback(event, fn, source)
        source = source or self
        local callbacks = source.listeners[event] or {}
        for i=#callbacks,1,-1 do
            if callbacks[i].listener == self and callbacks[i].fn == fn then table.remove(callbacks,i) end
        end
    end
    function inst:PushEvent(event,data)
        for _,callback in ipairs(self.listeners[event] or {}) do callback.fn(self,data) end
    end
    inst.UITransform={GetWorldPosition=function() return widget:GetWorldPosition():Get() end}
    return inst
end

local Widget = Class(function(self,name)
    self.name=name; self.children={}; self.shown=true; self.position=Vector3(); self.scale=Vector3(1,1,1)
    self.inst=Entity(self); self.width=1352; self.height=250
end)
function Widget:AddChild(child)
    if child.parent then child.parent:RemoveChild(child) end
    child.parent=self; self.children[child]=true; return child
end
function Widget:RemoveChild(child) self.children[child]=nil; child.parent=nil end
function Widget:Kill()
    self.inst.valid=false
    local children={}; for child in pairs(self.children) do children[#children+1]=child end
    for _,child in ipairs(children) do child:Kill() end
    if self.parent then self.parent:RemoveChild(self) end
end
function Widget:SetPosition(x,y,z)
    self.position=type(x)=="table" and Vector3(x.x,x.y,x.z) or Vector3(x,y,z)
end
function Widget:GetPosition() return self.position end
function Widget:GetWorldPosition()
    if self.parent then
        local p,s=self.parent:GetWorldPosition(),self.parent:GetScale()
        return Vector3(p.x+self.position.x*s.x,p.y+self.position.y*s.y,p.z+self.position.z*s.z)
    end
    return self.position
end
function Widget:SetScale(x,y,z)
    self.scale=type(x)=="table" and x or Vector3(x,y or x,z or x)
end
function Widget:GetLooseScale() return self.scale:Get() end
function Widget:GetScale()
    local p=self.parent and self.parent:GetScale() or Vector3(1,1,1)
    return Vector3(self.scale.x*p.x,self.scale.y*p.y,self.scale.z*p.z)
end
function Widget:SetSize(w,h) self.width=w;self.height=h end
function Widget:GetSize() return self.width,self.height end
function Widget:Show() self.shown=true end
function Widget:Hide() self.shown=false end
function Widget:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function Widget:MoveTo(from,to,time,fn)
    self.move={from=from,to=to,time=time};self:SetPosition(to);if fn then fn() end
end
function Widget:CancelMoveTo() self.move=nil;self.cancels=(self.cancels or 0)+1 end
function Widget:ScaleTo(from,to,time) self:SetScale(to) end
function Widget:SetTile(tile)
    if self.tile then self.tile:Kill() end
    self.tile=tile;if tile then self:AddChild(tile) end
end
function Widget:SetString(value) self.text=value end
function Widget:Click(right) self.clicked={num=self.num,container=self.container,right=right} end
for _,name in ipairs({"SetColour","SetScaleMode","EnableWordWrap","SetRegionSize","SetHAlign",
    "StartUpdating","StopUpdating","MoveToFront","MoveToBack","SetMaster","Highlight",
    "DeHighlight","SetFocus","ClearFocus","Refresh","RefreshPosition","StartDrag"}) do Widget[name]=noop end
package.loaded["widgets/widget"]=Widget

local Image=Class(Widget,function(self,atlas,texture)
    Widget._ctor(self,"image");self.atlas=atlas;self.texture=texture
    if texture=="inventory_bg_cover.tex" then self.height=330 end
end)
package.loaded["widgets/image"]=Image
local Slot=Class(Widget,function(self,index,atlas,texture,owner,container)
    Widget._ctor(self,"slot");self.num=index;self.container=container
    self.bgimage=self:AddChild(Image(atlas,texture))
end)
package.loaded["widgets/invslot"]=Slot
package.loaded["widgets/equipslot"]=Class(Slot,function(self,slot,atlas,texture,owner)
    Slot._ctor(self,nil,atlas,texture,owner,owner.replica.inventory);self.equipslot=slot
end)
local Tile=Class(Widget,function(self,item)
    Widget._ctor(self,"tile");self.item=item;self.image=self:AddChild(Image())
end)
function Tile:HasSpoilage() return false end
package.loaded["widgets/itemtile"]=Tile
package.loaded["widgets/text"]=Widget
package.loaded["widgets/hudcompass"]=Widget
package.loaded["widgets/tilebg"]=Widget
package.loaded["widgets/templates"]={IconButton=function()
    local button=Widget("button");button.icon=button:AddChild(Image());return button
end}
package.loaded["util/sourcemodifierlist"]={boolean=noop}
setmetatable(package.loaded["util/sourcemodifierlist"],{__call=function() return {} end})
SCALEMODE_PROPORTIONAL=1;ANCHOR_LEFT=1;EQUIPSLOTS={HANDS="hands",BODY="body",HEAD="head"}
TALKINGFONT="font";UIFONT="font";STRINGS={UI={HUD={INSPECT_SELF="Inspect"}}}
function softresolvefilepath() return nil end
function GetGameModeProperty() return false end
function SetAutopaused() end
local controller=false
local integrated=true
TheNet={GetServerGameMode=function() return "survival" end}
TheInput={ControllerAttached=function() return controller end}
Profile=setmetatable({GetIntegratedBackpack=function() return integrated end},
    {__newindex=function() error("Profile must not be written") end})
TheFrontEnd={GetSound=function() return {PlaySound=noop} end,LockFocus=noop}

local Inv=require("widgets/inventorybar")
local layout=require("gb_inventory_layout")
local function NewBar(count,growing,with_controller,with_integrated,install)
    controller=with_controller or false;integrated=with_integrated~=false
    local owner=Entity();owner.prefab="wilson";owner.replica={};owner.components={playercontroller={CancelDeployPlacement=noop}}
    local pack=Entity()
    function pack:HasTag(tag) return growing and tag=="gb_growing_backpack" end
    local overflow={inst=pack,count=count,items={}}
    function overflow:GetNumSlots() return self.count end
    function overflow:GetItemInSlot(index) return self.items[index] end
    function overflow:IsOpenedBy() return true end
    local inventory={overflow=overflow,items={},equips={}}
    function inventory:GetNumSlots() return 15 end
    function inventory:GetItemInSlot(index) return self.items[index] end
    function inventory:GetEquippedItem(slot) return self.equips[slot] end
    function inventory:GetOverflowContainer() return self.overflow end
    function inventory:GetActiveItem() return self.active end
    function inventory:ReturnActiveItem() self.active=nil end
    function inventory:GetItems() return self.items end
    function inventory:GetEquips() return self.equips end
    function inventory:IsHolding(item) return self.overflow and self.overflow.inst==item end
    owner.replica.inventory=inventory
    owner.HUD={controls={containers={},craftingshown=false,SetDark=noop,
        craftingmenu={is_left_aligned=true,ClearFocus=noop,InvNavToPin=noop}},InspectSelf=noop}
    ThePlayer=owner
    local bar=Inv(owner);bar.autoanchor=Widget("autoanchor")
    -- Text content relies on renderer/localized control APIs; layout attributes,
    -- actual UpdateCursor and all navigation methods remain the game's originals.
    bar.UpdateCursorText=noop
    owner.HUD.controls.inv=bar
    if install~=false then layout.Install(bar) end
    bar:Rebuild()
    return bar,inventory,overflow,owner
end
local function Select(bar,index)
    bar.current_list=bar.backpackinv;bar:SelectSlot(bar.backpackinv[index]);bar:UpdateCursor()
end
local function Eq(a,b,message) assert(math.abs(a-b)<.0001,message or (tostring(a).." != "..tostring(b))) end

check("16/24/32 use eight readable columns above the main bar",function()
    for _,count in ipairs({16,24,32}) do
        local bar=NewBar(count,true)
        assert(#bar.backpackinv==count and bar._gb_inventory_layout.rows==count/8)
        local rows={}
        for index,slot in ipairs(bar.backpackinv) do
            local p=slot:GetWorldPosition();rows[p.y]=(rows[p.y] or 0)+1
            assert(p.y>bar.inv[1]:GetWorldPosition().y)
            assert(slot:GetScale().x==bar.inv[1]:GetScale().x)
            assert(slot.num==index and slot.container==bar.owner.replica.inventory.overflow)
            assert(p.x>=bar.inv[1]:GetWorldPosition().x and p.x<=bar.inv[#bar.inv]:GetWorldPosition().x)
        end
        local rowcount=0;for _,size in pairs(rows) do assert(size==8);rowcount=rowcount+1 end
        assert(rowcount==count/8 and not bar.bgcover.shown and not bar.integrated_arrow.shown)
        local upper=bar.backpackinv[1]:GetPosition().y+bar.bottomrow:GetPosition().y+34
        local _,height=bar.bg:GetSize();assert(bar.bg:GetPosition().y+height/2>upper)
        assert(bar.inv[1].top_align_tip>upper-bar.toprow:GetPosition().y)
        local oldheight=height;bar:Rebuild();local _,newheight=bar.bg:GetSize();Eq(newheight,oldheight)
    end
end)

check("controller reaches every backpack slot without diagonal row jumps",function()
    local bar=NewBar(32,true,true,false)
    bar.open=true;bar.reps=1
    assert(bar._gb_inventory_layout and bar.integrated_backpack)
    for index=1,32 do
        Select(bar,index)
        bar:CursorLeft();assert(bar.active_slot==bar.backpackinv[index%8==1 and index or index-1])
        Select(bar,index)
        bar:CursorRight();assert(bar.active_slot==bar.backpackinv[index%8==0 and index or index+1])
        if index>8 then Select(bar,index);bar:CursorUp();assert(bar.active_slot==bar.backpackinv[index-8]) end
        if index<=24 then Select(bar,index);bar:CursorDown();assert(bar.active_slot==bar.backpackinv[index+8]) end
    end
    Select(bar,32);bar:CursorDown();assert(bar.current_list==bar.inv)
    bar:CursorUp();assert(bar.current_list==bar.backpackinv)
    Select(bar,32);bar.backpackinv[32]:Click();assert(bar.backpackinv[32].clicked.num==32)
    assert(bar:GetCursorSlot()==32)
end)

check("original item events and refresh keep slot 32 live after wrapping",function()
    local bar,inventory,overflow=NewBar(32,true)
    local item={prefab="cutgrass",replica={inventoryitem={}}}
    overflow.items[32]=item;overflow.inst:PushEvent("itemget",{slot=32,item=item})
    assert(bar.backpackinv[32].tile.item==item)
    overflow.items[32]=nil;overflow.inst:PushEvent("itemlose",{slot=32})
    assert(bar.backpackinv[32].tile==nil)
    overflow.items[31]=item;overflow.inst:PushEvent("refresh")
    assert(bar.backpackinv[31].tile.item==item)
    bar:Rebuild();assert(#overflow.inst.listeners.itemget==1 and #overflow.inst.listeners.itemlose==1)
    assert(bar.backpackinv[31].tile.item==item)
end)

check("cursor, active item and original snapping follow reflowed slot positions",function()
    local bar,inventory=NewBar(24,true,true)
    inventory.active={prefab="twigs",replica={inventoryitem={}}}
    Select(bar,24)
    assert(bar.cursor.parent==bar.backpackinv[24])
    assert(bar.cursortile:GetPosition():DistSq(bar.active_slot:GetWorldPosition())==0)
    bar.rebuild_snapping=true;bar:Rebuild()
    assert(bar.root.move==nil and bar.root.cancels>0)
    Eq(bar.root:GetPosition().y,bar.in_pos.y)
    assert(bar.cursortile:GetPosition():DistSq(bar.active_slot:GetWorldPosition())==0)
    bar:Rebuild();assert(bar.root.move and bar.root.move.time==.5)
end)

check("switching to vanilla, eight slots or no bag restores native background and geometry",function()
    local bar,inventory,overflow=NewBar(32,true)
    local originalpack=overflow.inst
    local reference=NewBar(8,false,false,true,false)
    ThePlayer=bar.owner
    local vanilla=Entity();function vanilla:HasTag() return false end
    overflow.inst=vanilla;overflow.count=8
    bar:Rebuild()
    assert(bar._gb_inventory_layout==nil and bar.bgcover.shown and bar.integrated_arrow.shown)
    assert(#originalpack.listeners.itemget==0 and #originalpack.listeners.itemlose==0)
    Eq(bar.bg.height,reference.bg.height);Eq(bar.bg.position.y,reference.bg.position.y)
    Eq(bar.toprow.position.y,reference.toprow.position.y)
    for i=1,8 do Eq(bar.backpackinv[i].position.x,reference.backpackinv[i].position.x) end
    overflow.inst=originalpack;overflow.count=8;bar:Rebuild();assert(bar._gb_inventory_layout==nil)
    inventory.overflow=nil;bar:Rebuild();assert(#bar.backpackinv==0 and bar._gb_inventory_layout==nil)
    Eq(bar.bg.height,250);Eq(bar.toprow.position.y,0)
end)

check("nonintegrated mouse HUD and ordinary large bags remain entirely native",function()
    for _,case in ipairs({{32,true,false},{32,false,true},{8,true,true}}) do
        local bar=NewBar(case[1],case[2],false,case[3])
        local vanilla=NewBar(case[1],case[2],false,case[3],false)
        assert(bar._gb_inventory_layout==nil)
        Eq(bar.toprow.position.y,vanilla.toprow.position.y)
        Eq(bar.bottomrow.position.y,vanilla.bottomrow.position.y)
        Eq(bar.bg.height,vanilla.bg.height)
        assert(#bar.backpackinv==#vanilla.backpackinv)
        for i,slot in ipairs(bar.backpackinv) do Eq(slot.position.x,vanilla.backpackinv[i].position.x) end
    end
end)

check("anchor follows controller scale and visibility without cumulative drift",function()
    local bar=NewBar(32,true,true)
    local expected=bar.root.position.y-10+3*76*.6
    bar:UpdatePosition();Eq(bar.autoanchor.position.y,expected)
    bar:UpdatePosition();Eq(bar.autoanchor.position.y,expected)
    bar:OpenControllerInventory();bar:UpdatePosition()
    Eq(bar.autoanchor.position.y,bar.root.position.y-10+3*76*.8)
    bar:Hide();bar:UpdatePosition();Eq(bar.autoanchor.position.y,0)
    bar:Show();bar:CloseControllerInventory();bar:UpdatePosition();Eq(bar.autoanchor.position.y,expected)
    local parent=Widget("scaled-parent");parent:SetScale(.7);parent:AddChild(bar);parent:AddChild(bar.autoanchor)
    bar:UpdatePosition();Eq(bar.autoanchor.position.y,expected)
    layout.Install(bar);bar:Rebuild();Eq(bar.bg.height,404)
end)
print("GROWINGPACK_INVENTORY_SUCCESS "..checks)
