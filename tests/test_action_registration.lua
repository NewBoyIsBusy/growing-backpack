-- Load the actual vanilla registration map and EntityScript dispatch, then run
-- the actual modmain. The surrounding recipe/asset/UI APIs are irrelevant stubs.
EntityScript = {}
require("class")
require("componentactions")
local register = AddComponentAction
local noop = function() end
local actions, handlers, registrations = {}, {}, 0
local containers = {params = {}, MAXITEMSLOTS = 8}
package.loaded.containers = containers
local vanilla_require = require
local g = setmetatable({
    TheNet = {IsDedicated = function() return true end},
    Asset = noop,
    Vector3 = function(x, y, z) return {x = x, y = y, z = z} end,
    ActionHandler = function(action, state) return {action = action, state = state} end,
    STRINGS = {NAMES = {}, RECIPE_DESC = {}, CHARACTERS = {GENERIC = {DESCRIBE = {}}}},
    Ingredient = noop,
    TECH = {SCIENCE_ONE = {}, SCIENCE_TWO = {}, ANCIENT_FOUR = {}},
    require = function(name)
        return name == "containers" and containers or vanilla_require(name)
    end,
}, {__index = _G})
local env = setmetatable({
    GLOBAL = g,
    RegisterInventoryItemAtlas = noop, AddMinimapAtlas = noop,
    AddClassPostConstruct = noop, AddRecipe2 = noop,
    AddAction = function(id, name, fn)
        local action = {id = id, str = name, fn = fn}
        actions[id] = action
        return action
    end,
    AddStategraphActionHandler = function(name, handler)
        handlers[name] = handlers[name] or {}
        handlers[name][handler.action.id] = handler.state
    end,
    AddComponentAction = function(kind, component, fn)
        registrations = registrations + 1
        register(kind, component, fn, "growing_backpack_registration_test")
    end,
}, {__index = _G})
local chunk = assert(loadstring(MODMAIN_SOURCE, "@modmain.lua"))
setfenv(chunk, env); chunk()
assert(registrations == 1, "inventoryitem USEITEM must be registered exactly once")

local player = {replica = {}}
local function kit(tag)
    local item = setmetatable({actioncomponents = {},
        HasTag = function(_, candidate) return candidate == tag end,
        replica = {inventoryitem = {
            IsGrandOwner = function(_, candidate) return candidate == player end,
            IsLockedInSlot = function() return false end,
        }},
    }, {__index = EntityScript})
    item:RegisterComponentActions("inventoryitem")
    -- Vanilla STORE/GIVE results are seeded below; dispatch only our mod's
    -- collectors here to avoid unrelated player, mount and map requirements.
    item.actioncomponents = {}
    return item
end
for _, case in ipairs({
    {"gb_upgrade_kit", "GB_EXPAND_BACKPACK"},
    {"gb_foodmodule_kit", "GB_INSTALL_MODULE"},
}) do
    local item = kit(case[1])
    for _, right in ipairs({false, true}) do
        local choices = {{id = "STORE"}, {id = "GIVE"}}
        item:CollectActions("USEITEM", player, {prefab = "growing_backpack"}, choices, right)
        assert(#choices == 1 and choices[1] == actions[case[2]], case[2] .. " registration was overwritten")
        choices = {{id = "STORE"}}
        item:CollectActions("USEITEM", player, {prefab = "treasurechest"}, choices, right)
        assert(#choices == 1 and choices[1].id == "STORE")
    end
    assert(handlers.wilson[case[2]] == "give" and handlers.wilson_client[case[2]] == "give")
end
local ordinary = kit("ordinary")
local choices = {{id = "STORE"}}
ordinary:CollectActions("USEITEM", player, {prefab = "growing_backpack"}, choices, false)
assert(#choices == 1 and choices[1].id == "STORE")
print("ACTION_REGISTRATION_PASS real modmain and vanilla AddComponentAction preserve expand and install")
