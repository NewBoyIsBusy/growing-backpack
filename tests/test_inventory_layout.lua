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
    function inst:DoSimTaskInTime(delay, fn) self.pending=fn end
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
function Widget:ClearFocus() self.focus=false end
function Widget:SetFocus() self.focus=true end
function Widget:SetScissor(x,y,w,h) self.scissor={x,y,w,h} end
function Widget:SetClickable(value) self.clickable=value end
for _,name in ipairs({"SetColour","SetScaleMode","EnableWordWrap","SetRegionSize","SetHAlign",
    "StartUpdating","StopUpdating","MoveToFront","MoveToBack","SetMaster","Highlight",
    "DeHighlight","Refresh","RefreshPosition","StartDrag",
    "SetReadOnlyVisuals","SetHRegPoint","SetVRegPoint"}) do Widget[name]=noop end
package.loaded["widgets/widget"]=Widget

local Image=Class(Widget,function(self,atlas,texture)
    Widget._ctor(self,"image");self.atlas=atlas;self.texture=texture
    if texture=="inventory_bg_cover.tex" then self.height=330 end
end)
function Image:SetTexture(atlas,texture)
    self.atlas=atlas;self.texture=texture
    if atlas=="images/dialogrect_9slice.xml" then
        local sizes={
            ["center.tex"]={3,3}, ["top.tex"]={477,13}, ["bottom.tex"]={477,13},
            ["left.tex"]={52,3}, ["right.tex"]={52,3},
            ["topleft.tex"]={59,38}, ["topright.tex"]={59,38},
            ["bottomleft.tex"]={59,30}, ["bottomright.tex"]={59,30},
        }
        assert(sizes[texture],"unknown native nine-slice texture")
        self:SetSize(unpack(sizes[texture]))
    end
end
function Image:SetTint(r,g,b,a) self.tint={r,g,b,a} end
package.loaded["widgets/image"]=Image
_G.Image=Image
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
package.loaded["widgets/text"]=Class(Widget,function(self,font,size)
    Widget._ctor(self,"text");self.font=font;self.fontsize=size
end)
local ImageButton=Class(Widget,function(self,atlas,normal,focus,disabled,down)
    Widget._ctor(self,"imagebutton")
    self.atlas=atlas;self.normal=normal;self.focus_texture=focus;self.disabled_texture=disabled
end)
function ImageButton:ForceImageSize(w,h) self:SetSize(w,h) end
function ImageButton:SetControl(control) self.control=control end
function ImageButton:SetOnClick(fn) self.onclick=fn end
function ImageButton:Enable() self.enabled=true end
function ImageButton:Disable() self.enabled=false end
function ImageButton:Click() if self.enabled then self.onclick() end end
package.loaded["widgets/imagebutton"]=ImageButton
package.loaded["widgets/hudcompass"]=Widget
package.loaded["widgets/tilebg"]=Widget
package.loaded["widgets/templates"]={IconButton=function()
    local button=Widget("button");button.icon=button:AddChild(Image());return button
end}
package.loaded["util/sourcemodifierlist"]={boolean=noop}
setmetatable(package.loaded["util/sourcemodifierlist"],{__call=function() return {} end})
SCALEMODE_PROPORTIONAL=1;ANCHOR_LEFT=1;ANCHOR_RIGHT=2;ANCHOR_MIDDLE=3;ANCHOR_TOP=4;ANCHOR_BOTTOM=5
CONTROL_PRIMARY=10
package.loaded.constants={}
UICOLOURS={BROWN_DARK={80/255,61/255,39/255}}
EQUIPSLOTS={HANDS="hands",BODY="body",HEAD="head"}
TALKINGFONT="font";UIFONT="font";NEWFONT_OUTLINE="outline_font";STRINGS={UI={HUD={INSPECT_SELF="Inspect"}}}
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
    function owner.components.playercontroller:CancelDeployPlacement()
        self.cancel_deploy_calls=(self.cancel_deploy_calls or 0)+1
    end
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

local function Visible(slots)
    local result={}
    for _,slot in ipairs(slots) do if slot:IsVisible() then result[#result+1]=slot end end
    return result
end
local function Geometry(a,b)
    Eq(a.position.x,b.position.x);Eq(a.position.y,b.position.y);Eq(a.position.z,b.position.z)
    Eq(a.scale.x,b.scale.x);Eq(a.scale.y,b.scale.y);Eq(a.scale.z,b.scale.z)
    Eq(a.width,b.width);Eq(a.height,b.height)
end

check("8 and 15 use unmodified native one-row backpack layout",function()
    for _,count in ipairs({8,15}) do
        local bar=NewBar(count,true)
        local reference=NewBar(count,true,false,true,false)
        for _,field in ipairs({"bg","bgcover","root","toprow","bottomrow"}) do Geometry(bar[field],reference[field]) end
        assert(#Visible(bar.backpackinv)==count)
        for i,slot in ipairs(bar.backpackinv) do Geometry(slot,reference.backpackinv[i]) end
    end
end)
check("23 and 30 show 15+8 and 15+15 below the main inventory at unchanged width",function()
    for _,count in ipairs({23,30}) do
        local bar,inventory,overflow=NewBar(count,true)
        local native=NewBar(15,true,false,true,false)
        assert(#bar.backpackinv==count and #Visible(bar.backpackinv)==count)
        Eq(bar.bg.scale.x,native.bg.scale.x)
        Eq(bar.bg.position.y-bar.bg.height*bar.bg.scale.y/2,
            native.bg.position.y-native.bg.height*native.bg.scale.y/2)
        Eq(bar.toprow.position.y,114);Eq(bar.bottomrow.position.y,38)
        local seen={}
        for i,slot in ipairs(bar.backpackinv) do
            local row=math.floor((i-1)/15)
            local n=math.min(15,count-row*15)
            Eq(slot.position.x,bar.inv[15-n+(i-1)%15+1].position.x)
            Eq(slot.position.y,-row*76)
            assert(slot.num==i and slot.container==overflow and slot.shown)
            local key=slot.position.x..":"..slot.position.y
            assert(not seen[key]);seen[key]=true
            assert(slot.scale.x==1 and slot.scale.y==1)
        end
    end
end)
check("last-slot events remain live without hidden cells or custom item handlers",function()
    local bar,inventory,overflow=NewBar(30,true)
    local item={prefab="berries",replica={inventoryitem={}}}
    overflow.items[30]=item;overflow.inst:PushEvent("itemget",{slot=30,item=item})
    assert(bar.backpackinv[30].tile.item==item and bar.backpackinv[30].tile:IsVisible())
    overflow.items[30]=nil;overflow.inst:PushEvent("itemlose",{slot=30})
    assert(bar.backpackinv[30].tile==nil)
    overflow.items[23]=item;overflow.inst:PushEvent("refresh")
    assert(bar.backpackinv[23].tile.item==item)
    local native=NewBar(15,true,false,true,false)
    assert(bar.OnItemGet==native.OnItemGet and bar.GetClosestWidget==native.GetClosestWidget)
end)
check("native controller traverses both rows and maintains the held-item cursor",function()
    for _,count in ipairs({23,30}) do
        local bar,inventory=NewBar(count,true,true)
        inventory.active={prefab="twigs",replica={inventoryitem={}}}
        bar.open=true;bar.reps=1
        for i=1,count do
            Select(bar,i)
            assert(bar.active_slot:IsVisible() and bar:GetCursorSlot()==i)
            assert(bar.cursor.parent==bar.backpackinv[i])
            assert(bar.cursortile:GetPosition():DistSq(bar.active_slot:GetWorldPosition())==0)
            if i%15~=0 and i<count then
                bar:CursorRight();assert(bar.active_slot==bar.backpackinv[i+1])
            end
        end
        Select(bar,count);bar:CursorUp()
        assert(bar.active_slot==bar.backpackinv[15])
        bar:CursorUp();assert(bar.active_slot==bar.inv[15])
        bar:CursorDown();assert(bar.active_slot==bar.backpackinv[15])
        bar:CursorDown();assert(bar.active_slot==bar.backpackinv[count])
    end
end)
check("rebuild and ordinary backpack restore the original frame without accumulating listeners",function()
    local bar,inventory,overflow=NewBar(30,true)
    local sy=bar.bg.scale.y
    for i=1,4 do
        bar.rebuild_snapping=true;bar:Rebuild()
        Eq(bar.bg.scale.y,sy)
        assert(#overflow.inst.listeners.itemget==1 and #overflow.inst.listeners.itemlose==1)
    end
    local ordinary=Entity();function ordinary:HasTag() return false end
    overflow.inst=ordinary;overflow.count=8;bar:Rebuild()
    local native=NewBar(8,false,false,true,false)
    assert(not bar._gb_extra_row)
    for _,field in ipairs({"bg","bgcover","root","toprow","bottomrow"}) do Geometry(bar[field],native[field]) end
end)
check("HUD anchor accounts for precisely one additional row and does not drift",function()
    local bar=NewBar(30,true)
    local native=NewBar(15,true,false,true,false)
    for i=1,4 do
        bar:UpdatePosition();native:UpdatePosition()
        Eq(bar.autoanchor.position.y,native.autoanchor.position.y+76)
    end
    bar:Hide();bar:UpdatePosition();Eq(bar.autoanchor.position.y,0)
end)
local UIAnim=Class(Widget,function(self)
    Widget._ctor(self,"uianim")
    self.animstate=setmetatable({},{__index=function() return noop end})
    function self.animstate:SetBank(value) self.bank=value end
    function self.animstate:SetBuild(value) self.build=value end
    function self.animstate:PlayAnimation(value) self.animation=value end
end)
function UIAnim:GetAnimState() return self.animstate end
package.loaded["widgets/uianim"]=UIAnim
local ContainerWidget=require("widgets/containerwidget")
local Paging=require("gb_pack_panel")
local definitions=require("gb_layout")
local function NewContainer(level,owner,install)
    owner=owner or Entity();owner.components=owner.components or {}
    local container=Entity();container.replica={}
    local replica={items={},widget=definitions.Make(level,Vector3).widget}
    function replica:GetWidget() return self.widget end
    function replica:IsInfiniteStackSize() return false end
    function replica:IsReadOnlyContainer() return false end
    function replica:IsSideWidget() return true end
    function replica:GetItems() return self.items end
    container.replica.container=replica
    local widget=ContainerWidget(owner)
    if install~=false then Paging.InstallContainer(widget) end
    widget:Open(container,owner)
    return widget,container,replica,owner
end

check("separate mode shows all cells in at most two normal-sized rows",function()
    controller=false
    for level,count in ipairs({8,15,23,30}) do
        local widget,container,replica,owner=NewContainer(level-1)
        assert(#widget.inv==count and #Visible(widget.inv)==count)
        assert(widget.bgimage.shown and not widget.bganim.shown)
        Eq(widget.bgimage.width,math.min(count,15)*80+48)
        Eq(widget.bgimage.height,math.ceil(count/15)*76+46)
        local seen={}
        for i,slot in ipairs(widget.inv) do
            assert(slot.num==i and slot.container==replica and slot.scale.x==1)
            local key=slot.position.x..":"..slot.position.y
            assert(not seen[key]);seen[key]=true
        end
        for cycle=1,3 do
            widget:Close();widget:Open(container,owner)
            assert(#container.listeners.itemget==1 and #container.listeners.itemlose==1)
        end
        local item={prefab="berries",replica={inventoryitem={}}}
        replica.items[count]=item;container:PushEvent("itemget",{slot=count,item=item})
        assert(widget.inv[count].tile.item==item and widget.inv[count].tile:IsVisible())
        widget:Close()
        replica.items={}
        replica.widget={slotpos={Vector3(0,0,0)},animbank="ui_chest_3x3",animbuild="ui_chest_3x3"}
        widget:Open(container,owner)
        assert(widget.bganim.shown and not widget.bgimage.shown and #widget.inv==1)
        Eq(widget.bgimage.position.x,0)
    end
end)
print("GROWINGPACK_INVENTORY_SUCCESS "..checks)
