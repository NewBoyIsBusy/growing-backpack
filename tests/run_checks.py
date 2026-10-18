"""Lua 5.1 syntax validation and client-side replica layout regression checks."""
from pathlib import Path
import sys

SOURCE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(SOURCE.parent / ".tools/lua_test_runtime"))
from lupa.lua51 import LuaRuntime

lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().package.path = str(SOURCE / "scripts/?.lua").replace("\\", "/") + ";" + lua.globals().package.path
for file in SOURCE.rglob("*.lua"):
    lua.execute("assert(loadstring(...))", file.read_text(encoding="utf-8"))
lua.execute('''
local layout = require("gb_layout")
for level = 0, 3 do
    local data = layout.Make(level, function(x,y,z) return {x=x,y=y,z=z} end)
    assert(#data.widget.slotpos == 8 * (level+1))
    local seen = {}
    for _, pos in ipairs(data.widget.slotpos) do
        local key = pos.x .. ":" .. pos.y
        assert(not seen[key]); seen[key] = true
        assert(pos.x >= -312 and pos.x <= -87)
        assert(math.abs(pos.y) < 265)
    end
end
assert(layout.Slots(-1) == 8)
assert(layout.Slots(99) == 32)

-- Run the actual prefab's remote-client branch and dirty-event callback.
local events, pending, open, closes, opens = {}, nil, false, 0, 0
TheWorld = {ismastersim=false}; ThePlayer = {}
Asset = function() end
Prefab = function(name, fn) return fn end
MakeInventoryPhysics = function() end
MakeInventoryFloatable = function() end
net_tinybyte = function()
    local value=0
    return {set=function(self,n) value=n end, value=function() return value end}
end
local noop = function() end
local methods = setmetatable({}, {__index=function() return noop end})
local replica = {
    IsOpenedBy=function() return open end,
    Close=function() closes=closes+1; open=false end,
    Open=function() opens=opens+1; open=true end,
    WidgetSetup=function(self, name) self.name=name end,
}
CreateEntity = function()
    return {entity=methods,AnimState=methods,MiniMapEntity=methods,GUID=1,
        replica={container=replica}, components={}, AddTag=noop,
        ListenForEvent=function(self,event,fn) events[event]=fn end,
        DoTaskInTime=function(self,t,fn) pending=fn end}
end
local fn = require("prefabs/growing_backpack")
local inst = fn()
inst._gb_level:set(2); pending(inst)
assert(replica.name == "growing_backpack_2")
open=true; inst._gb_level:set(3); events.gb_leveldirty(inst)
assert(replica.name == "growing_backpack_3" and closes == 1 and opens == 1)
assert(inst.displaynamefn(inst):find("32"))

local appearance = require("gb_appearance")
local applied, symbols = {}, {}
local visual = {
    _gb_level=inst._gb_level,
    AnimState={SetBank=function(self,v) applied.bank=v end,
        SetBuild=function(self,v) applied.build=v end, PlayAnimation=noop},
    MiniMapEntity={SetIcon=function(self,v) applied.map=v end},
    components={inventoryitem={ChangeImageName=function(self,v) applied.image=v end},
        floater={SetSwapData=function(self,v) applied.floatbank=v.bank end,
            SetSize=noop, SetVerticalOffset=noop, SetScale=noop}},
}
local owner = {AnimState={
    ClearOverrideSymbol=function(self,s) symbols[s]=nil end,
    OverrideSymbol=function(self,s,build) symbols[s]=build end,
}}
local expected = {"backpack", "piggyback", "icepack", "krampus_sack"}
-- Reverse order also checks that returning to a plain bag clears sack symbols.
for level=3,0,-1 do
    visual._gb_level:set(level)
    appearance.Apply(visual); appearance.Equip(visual,owner)
    local look=appearance.Get(level)
    assert(applied.image == expected[level+1] and applied.map == expected[level+1] .. ".png")
    assert(applied.bank == look.bank and applied.build == look.build and applied.floatbank == look.bank)
    assert(symbols.swap_body == look.build)
    assert(symbols.backpack == (level >= 2 and look.build or nil))
end
''')
print("PASS: Lua 5.1 syntax, four layouts, remote sync, four appearances/icons, equip symbols and floater banks")
