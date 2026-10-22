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

check("16/24/32 preserve native eight-slot integrated HUD geometry exactly",function()
    for _,count in ipairs({16,24,32}) do
        local reference=NewBar(8,false,false,true,false)
        local bar,inventory,overflow=NewBar(count,true)
        assert(#bar.backpackinv==count and overflow:GetNumSlots()==count)
        assert(#Visible(bar.backpackinv)==8)
        for _,field in ipairs({"bg","bgcover","root","toprow","bottomrow","integrated_arrow","hand_inv","hudcompass"}) do
            Geometry(bar[field],reference[field])
            assert(bar[field].shown==reference[field].shown)
        end
        for i,slot in ipairs(bar.inv) do Geometry(slot,reference.inv[i]) end
        for name,slot in pairs(bar.equip) do Geometry(slot,reference.equip[name]) end
        for i,slot in ipairs(bar.backpackinv) do
            local expected=reference.backpackinv[(i-1)%8+1]
            Geometry(slot,expected)
            Eq(slot.top_align_tip,expected.top_align_tip)
            assert(slot.num==i and slot.container==overflow)
        end
        local paging=bar._gb_inventory_layout
        assert(paging.page==1 and paging.pages==count/8 and paging.columns==8)
        assert(paging.left.atlas=="images/ui.xml" and paging.left.normal=="arrow2_left.tex")
        assert(paging.right.normal=="arrow2_right.tex" and paging.left.control==CONTROL_PRIMARY)
        Eq(paging.left.width,28);Eq(paging.left.height,32)
        Eq(paging.root.position.x,bar.backpackinv[8].position.x+270)
        assert(paging.label.font==NEWFONT_OUTLINE and paging.label.fontsize==30)
        assert(paging.root.parent==bar.bottomrow and paging.label.text=="1/"..count/8)
    end
end)

check("mouse page buttons expose the real slot numbers without changing container data",function()
    local bar,inventory,overflow=NewBar(32,true)
    local state=bar._gb_inventory_layout
    assert(not state.left.enabled and state.right.enabled)
    bar.backpackinv[1]:SetFocus()
    for page=1,4 do
        assert(state.page==page and state.label.text==page.."/4")
        local visible=Visible(bar.backpackinv);assert(#visible==8)
        for col,slot in ipairs(visible) do
            assert(slot.num==(page-1)*8+col and slot.container==overflow)
            slot:Click();assert(slot.clicked.num==slot.num)
        end
        state.right:Click()
    end
    assert(state.page==4 and not state.right.enabled and not bar.backpackinv[1].focus)
    state.left:Click();assert(state.page==3)
    assert(#bar.backpackinv==32 and overflow:GetNumSlots()==32 and inventory.overflow==overflow)
end)

check("hidden slot 32 receives original item events and suppresses misleading fly-in animation",function()
    local bar,inventory,overflow=NewBar(32,true)
    local item={prefab="cutgrass",replica={inventoryitem={}}}
    local source=Vector3(1,2,3)
    local data={slot=32,item=item,src_pos=source}
    overflow.items[32]=item;overflow.inst:PushEvent("itemget",data)
    -- The original OnItemGet's animation path would need TheSim and a rendered
    -- Image here. Successful delivery proves the hidden-page source was stripped.
    assert(data.src_pos==source and bar.backpackinv[32].tile.item==item)
    assert(not bar.backpackinv[32]:IsVisible() and bar.backpackinv[32].tile.shown)
    bar._gb_inventory_layout:SetPage(4)
    assert(bar.backpackinv[32].tile:IsVisible())
    overflow.items[32]=nil;overflow.inst:PushEvent("itemlose",{slot=32})
    assert(bar.backpackinv[32].tile==nil)
    bar._gb_inventory_layout:SetPage(1)
    overflow.items[31]=item;overflow.inst:PushEvent("refresh")
    assert(bar.backpackinv[31].tile.item==item and not bar.backpackinv[31]:IsVisible())
    bar._gb_inventory_layout:SetPage(4)
    assert(bar.backpackinv[31].tile:IsVisible())
end)

check("controller traverses all 32 real slots across page boundaries",function()
    local bar=NewBar(32,true,true,false)
    bar.open=true;bar.reps=1
    for index=1,32 do
        Select(bar,index)
        assert(bar._gb_inventory_layout.page==math.ceil(index/8) and bar.active_slot:IsVisible())
        assert(bar:GetCursorSlot()==index)
        bar:CursorLeft()
        assert(bar.active_slot==bar.backpackinv[math.max(1,index-1)])
        assert(bar.current_list==bar.backpackinv and bar.active_slot:IsVisible())
        Select(bar,index);bar:CursorRight()
        assert(bar.active_slot==bar.backpackinv[math.min(32,index+1)])
        assert(bar.current_list==bar.backpackinv and bar.active_slot:IsVisible())
    end
    Select(bar,32);bar:CursorUp()
    assert(bar.current_list==bar.inv and bar.active_slot==bar.inv[15])
    bar:CursorDown()
    assert(bar.current_list==bar.backpackinv and bar.active_slot==bar.backpackinv[32])
end)

check("page boundaries keep native deployment cancellation, hint timing and click sounds",function()
    local native=NewBar(8,false,true,true,false)
    local bar=NewBar(32,true,true)
    assert(bar.CursorNav==native.CursorNav and bar.CursorLeft==native.CursorLeft
        and bar.CursorRight==native.CursorRight)
    local oldsound=TheFrontEnd.GetSound
    local sounds=0
    TheFrontEnd.GetSound=function() return {PlaySound=function() sounds=sounds+1 end} end
    local item={prefab="cutgrass",replica={inventoryitem={}}}
    local function Navigate(target,index,method)
        ThePlayer=target.owner
        target.open=true;target.reps=1
        target.backpackinv[index]:SetTile(Tile(item));Select(target,index)
        target.actionstringtime=0;target.actionstring:Hide()
        local controller=target.owner.components.playercontroller
        local before=controller.cancel_deploy_calls or 0
        local soundbefore=sounds
        target[method](target)
        return controller.cancel_deploy_calls-before,target.actionstringtime,
            target.actionstring.shown,sounds-soundbefore
    end
    local calls,delay,shown,clicks=Navigate(native,7,"CursorRight")
    local pagecalls,pagedelay,pageshown,pageclicks=Navigate(bar,8,"CursorRight")
    assert(calls==1 and pagecalls==calls and pagedelay==delay and pageshown==shown and pageclicks==clicks)
    assert(delay==10 and shown and clicks==1 and bar.active_slot==bar.backpackinv[9])
    assert(bar._gb_inventory_layout.page==2)
    pagecalls,pagedelay,pageshown,pageclicks=Navigate(bar,9,"CursorLeft")
    assert(pagecalls==calls and pagedelay==delay and pageshown==shown and pageclicks==clicks)
    assert(bar.active_slot==bar.backpackinv[8] and bar._gb_inventory_layout.page==1)

    -- Destination queries themselves do not mutate page/focus, just as native
    -- GetClosestWidget does not select anything before CursorNav commits it.
    local destination,list=bar:GetClosestWidget({bar.backpackinv},bar.active_slot:GetWorldPosition(),Vector3(1,0,0))
    assert(destination==bar.backpackinv[9] and list==bar.backpackinv)
    assert(bar.active_slot==bar.backpackinv[8] and bar._gb_inventory_layout.page==1)
    pagecalls,pagedelay,pageshown,pageclicks=Navigate(bar,1,"CursorLeft")
    assert(pagecalls==1 and pagedelay==10 and pageshown and pageclicks==0)
    assert(bar.active_slot==bar.backpackinv[1] and bar._gb_inventory_layout.page==1)
    TheFrontEnd.GetSound=oldsound
end)

check("selection and mouse paging keep controller cursor and held item on the visible real slot",function()
    local bar,inventory=NewBar(32,true,true)
    inventory.active={prefab="twigs",replica={inventoryitem={}}}
    Select(bar,32)
    assert(bar._gb_inventory_layout.page==4 and bar.cursor.parent==bar.backpackinv[32])
    assert(bar.cursortile:GetPosition():DistSq(bar.active_slot:GetWorldPosition())==0)
    bar._gb_inventory_layout.left:Click()
    assert(bar.active_slot==bar.backpackinv[24] and bar.current_list==bar.backpackinv)
    assert(bar.cursor.parent==bar.backpackinv[24] and bar.active_slot:IsVisible())
    assert(bar.cursortile:GetPosition():DistSq(bar.active_slot:GetWorldPosition())==0)
    bar:SelectDefaultSlot();bar._gb_inventory_layout.left:Click()
    assert(bar.active_slot==bar.inv[1] and bar.current_list==bar.inv)
end)

check("rebuild remembers page per pack and disposes controls without duplicate event listeners",function()
    local bar,inventory,overflow=NewBar(32,true)
    local originalpack=overflow.inst
    local state=bar._gb_inventory_layout
    state:SetPage(4)
    for i=1,3 do
        bar.rebuild_snapping=true;bar:Rebuild()
        assert(bar._gb_inventory_layout.page==4 and #Visible(bar.backpackinv)==8)
        assert(#originalpack.listeners.itemget==1 and #originalpack.listeners.itemlose==1)
    end
    assert(state.closed and not state.root.inst.valid)
    local another=Entity();function another:HasTag(tag) return tag=="gb_growing_backpack" end
    overflow.inst=another;bar:Rebuild();assert(bar._gb_inventory_layout.page==1)
    overflow.inst=originalpack;bar:Rebuild();assert(bar._gb_inventory_layout.page==4)
    overflow.count=16;bar:Rebuild();assert(bar._gb_inventory_layout.page==2)
end)

check("native eight slots and unrelated inventories remain unchanged after hook and reuse",function()
    for _,case in ipairs({{32,true,false},{32,false,true},{8,true,true},{8,false,true}}) do
        local bar=NewBar(case[1],case[2],false,case[3])
        local native=NewBar(case[1],case[2],false,case[3],false)
        assert(bar._gb_inventory_layout==nil)
        for _,field in ipairs({"bg","bgcover","root","toprow","bottomrow"}) do Geometry(bar[field],native[field]) end
        for i,slot in ipairs(bar.backpackinv) do Geometry(slot,native.backpackinv[i]) end
    end
    local bar,inventory,overflow=NewBar(32,true)
    local oldstate=bar._gb_inventory_layout
    local ordinary=Entity();function ordinary:HasTag() return false end
    overflow.inst=ordinary;overflow.count=8;bar:Rebuild()
    assert(bar._gb_inventory_layout==nil and oldstate.closed and not oldstate.root.inst.valid)
    local native=NewBar(8,false,false,true,false)
    Geometry(bar.bg,native.bg);Geometry(bar.bottomrow,native.bottomrow)
    for i,slot in ipairs(bar.backpackinv) do Geometry(slot,native.backpackinv[i]);assert(slot.shown) end
    ThePlayer=bar.owner;inventory.overflow=nil;bar:Rebuild()
    assert(bar._gb_inventory_layout==nil and #bar.backpackinv==0)
end)

check("anchor, controller scale and snapping stay entirely native",function()
    local reference=NewBar(8,false,true,true,false)
    local bar=NewBar(32,true,true)
    for i=1,3 do
        bar:UpdatePosition();reference:UpdatePosition();Geometry(bar.autoanchor,reference.autoanchor)
    end
    bar:OpenControllerInventory();reference:OpenControllerInventory()
    bar:UpdatePosition();reference:UpdatePosition();Geometry(bar.autoanchor,reference.autoanchor)
    Eq(bar:GetLooseScale(),reference:GetLooseScale())
    bar:Hide();reference:Hide();bar:UpdatePosition();reference:UpdatePosition()
    Geometry(bar.autoanchor,reference.autoanchor)
    bar:Show();reference:Show();bar:CloseControllerInventory();reference:CloseControllerInventory()
    bar.rebuild_snapping=true;reference.rebuild_snapping=true
    bar:Rebuild();reference:Rebuild();Geometry(bar.root,reference.root)
    assert(bar.root.move==nil and bar.root.cancels>0)
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

check("side mode uses untouched native 2x4 frame, slot positions and animations at all capacities",function()
    controller=false
    local reference=NewContainer(0,nil,false)
    for level=0,3 do
        local widget,container,replica,owner=NewContainer(level)
        Geometry(widget,reference);Geometry(widget.bganim,reference.bganim)
        assert(widget.bganim.shown and widget.bganim.animstate.bank=="ui_backpack_2x4")
        assert(widget.bganim.animstate.build=="ui_backpack_2x4" and widget.bganim.animstate.animation=="open")
        assert(#widget.inv==8*(level+1) and #Visible(widget.inv)==8)
        assert((widget._gb_pack_panel~=nil)==(level>0))
        for i,slot in ipairs(widget.inv) do Geometry(slot,reference.inv[(i-1)%8+1]);assert(slot.num==i) end
        if level>0 then
            local state=widget._gb_pack_panel
            Eq(state.root.position.x,-124.5);Eq(state.root.position.y,-195)
            state:SetPage(level+1)
            assert(widget.inv[#widget.inv]:IsVisible() and not widget.inv[1]:IsVisible())
            widget:Close()
            assert(state.closed and not state.root.inst.valid and widget._gb_pack_panel==nil)
            assert(widget.bganim.animstate.animation=="close")
            widget:Open(container,owner)
            assert(widget._gb_pack_panel.page==level+1)
            for cycle=1,3 do
                local previous=widget._gb_pack_panel
                widget:Close()
                local childcount=0;for _ in pairs(widget.children) do childcount=childcount+1 end
                assert(childcount==2 and not previous.root.inst.valid)
                assert(#container.listeners.itemget==0 and #container.listeners.itemlose==0)
                widget:Open(container,owner)
                assert(widget._gb_pack_panel.page==level+1)
                assert(#container.listeners.itemget==1 and #container.listeners.itemlose==1)
            end
        end
        widget:Close();assert(widget.bganim.animstate.animation=="close")
        replica.widget={slotpos={Vector3(0,0,0)},animbank="ui_chest_3x3",animbuild="ui_chest_3x3"}
        widget:Open(container,owner)
        assert(widget._gb_pack_panel==nil and widget.bganim.shown and #widget.inv==1)
        assert(widget.bganim.animstate.build=="ui_chest_3x3")
    end
end)

check("side hidden-page events preserve data and do not animate toward another page",function()
    controller=false
    local widget,container,replica=NewContainer(3)
    local item={prefab="berries",replica={inventoryitem={}}}
    local data={slot=32,item=item,src_pos=Vector3(3,4,5)}
    replica.items[32]=item;container:PushEvent("itemget",data)
    assert(data.src_pos~=nil and widget.inv[32].tile.item==item)
    assert(not widget.inv[32]:IsVisible() and widget.inv[32].tile.shown)
    widget._gb_pack_panel:SetPage(4);assert(widget.inv[32].tile:IsVisible())
    replica.items[32]=nil;container:PushEvent("itemlose",{slot=32})
    assert(widget.inv[32].tile==nil)
    widget._gb_pack_panel:SetPage(1)
    replica.items[31]=item;container:PushEvent("refresh")
    assert(widget.inv[31].tile.item==item and not widget.inv[31]:IsVisible())
end)

check("controller filters hidden slots in every container and returns the original list",function()
    local bar,inventory,overflow,owner=NewBar(32,true,true)
    local side=NewContainer(3,owner)
    owner.HUD.controls.containers.side=side
    side:SetPosition(0,500,0)
    side._gb_pack_panel:SetPage(4)
    local list=side.inv
    bar.current_list=list;bar:SelectSlot(list[31]);bar:UpdateCursor()
    assert(side._gb_pack_panel.page==4)
    bar:CursorRight();assert(bar.active_slot==list[32] and bar.current_list==list)
    bar:CursorLeft();assert(bar.active_slot==list[31])
    bar:CursorLeft();assert(bar.active_slot==list[24] and side._gb_pack_panel.page==3)
    bar:CursorRight();assert(bar.active_slot==list[31] and side._gb_pack_panel.page==4)
    bar:SelectSlot(list[25]);bar.current_list=list
    bar:CursorDown();assert(bar.active_slot==list[27] and bar.current_list==list)
    local slot,found=bar:GetClosestWidget({list},list[25]:GetWorldPosition(),Vector3(1,0,0))
    assert(slot==list[26] and found==list and slot:IsVisible())
    bar:SelectSlot(bar.backpackinv[32]);bar.current_list=bar.backpackinv
    local result,resultlist=bar:GetClosestWidget({bar.backpackinv},bar.backpackinv[32]:GetWorldPosition(),Vector3(-1,0,0))
    assert(result==bar.backpackinv[31] and resultlist==bar.backpackinv)
end)

check("actual ItemTile stack events stay live on hidden pages without detached flying images",function()
    -- Exercise the installed game's real event listener and Refresh, including
    -- its flag reset. Stub only renderer/services, not stack event behavior.
    Widget.SetClickable=noop
    UIAnim.SetClickable=noop
    Image.SetClickable=noop
    TheWorld=Entity();TheWorld.ismastersim=false
    TheScrapbookPartitions={SetInspectedByCharacter=noop}
    local oldtile=package.loaded["widgets/itemtile"]
    package.loaded["widgets/itemtile"]=nil
    local RealTile=require("widgets/itemtile")
    package.loaded["widgets/itemtile"]=oldtile
    local bar=NewBar(32,true)
    local item=Entity();item.prefab="cutgrass";item.replica={};item.components={};item.count=1
    function item:HasTag() return false end
    function item:HasAnyTag() return false end
    function item:HasClientSideInventoryImageOverrides() return false end
    function item:GetIsWet() return false end
    function item:IsAcidSizzling() return false end
    item.replica.inventoryitem={GetAtlas=function() return "images/inventoryimages.xml" end,
        GetImage=function() return "cutgrass.tex" end,DeserializeUsage=noop}
    item.replica.stackable={StackSize=function() return item.count end}
    local tile=RealTile(item)
    bar.backpackinv[32]:SetTile(tile)
    assert(tile.ignore_stacksize_anim and tile._gb_original_refresh)
    item.count=2;item:PushEvent("stacksizechange",{stacksize=2,src_pos=Vector3(1,2,3)})
    assert(tile.quantity.text=="2" and tile.movinganim==nil)
    tile:Refresh();assert(tile.ignore_stacksize_anim)
    item.count=3;item:PushEvent("stacksizechange",{stacksize=3,src_pos=Vector3(1,2,3)})
    assert(tile.quantity.text=="3" and tile.movinganim==nil)

    -- The visible page retains native detached fly-ins. Pause the renderer's
    -- animation callback so switching page while it flies can be verified.
    local oldmove=Image.MoveTo
    local flights={}
    Image.MoveTo=function(self,from,to,duration,fn)
        self.finish=fn;flights[#flights+1]=self
    end
    TheSim={GetScreenPos=function(x,y,z) return x,y,z end}
    bar._gb_inventory_layout:SetPage(4)
    assert(tile.ignore_stacksize_anim==nil and tile:IsVisible())
    item.count=4;item:PushEvent("stacksizechange",{stacksize=4,src_pos=Vector3(1,2,3)})
    assert(#flights==1 and tile.movinganim==flights[1] and flights[1].parent==nil)
    bar._gb_inventory_layout:SetPage(1)
    assert(not flights[1].inst.valid and tile.movinganim==nil and tile.quantity.text=="4")
    item.count=5;item:PushEvent("stacksizechange",{stacksize=5,src_pos=Vector3(1,2,3)})
    assert(#flights==1 and tile.quantity.text=="5")

    -- An ordinary slot is never wrapped and still uses that native animation.
    local ordinary=Slot(1,"images/hud.xml","inv_slot.tex",bar.owner,{})
    local ordinarytile=RealTile(item);ordinary:SetTile(ordinarytile)
    assert(ordinarytile._gb_original_refresh==nil and ordinarytile.ignore_stacksize_anim==nil)
    item.count=6;item:PushEvent("stacksizechange",{stacksize=6,src_pos=Vector3(1,2,3)})
    assert(#flights==2 and ordinarytile.movinganim==flights[2])
    local originalrefresh=tile._gb_original_refresh
    Paging.Destroy(bar._gb_inventory_layout)
    assert(tile.Refresh==originalrefresh and tile._gb_original_refresh==nil)
    assert(tile.ignore_stacksize_anim==nil and bar.backpackinv[32]._gb_original_settile==nil)
    Image.MoveTo=oldmove
end)

print("GROWINGPACK_INVENTORY_SUCCESS "..checks)
