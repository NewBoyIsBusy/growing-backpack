PrefabFiles = { "growing_backpack", "gb_upgrade_kits" }

local G = GLOBAL
Assets = {}
for level = 0, 3 do
    local image = "gb_pack_" .. level
    local atlas = "images/" .. image .. ".xml"
    Assets[#Assets + 1] = G.Asset("ATLAS", atlas)
    Assets[#Assets + 1] = G.Asset("IMAGE", "images/" .. image .. ".tex")
    RegisterInventoryItemAtlas(atlas, image .. ".tex")
    AddMinimapAtlas(atlas)
end
for level = 1, 3 do
    local image = "gb_upgrade_" .. level
    local atlas = "images/" .. image .. ".xml"
    Assets[#Assets + 1] = G.Asset("ATLAS", atlas)
    Assets[#Assets + 1] = G.Asset("IMAGE", "images/" .. image .. ".tex")
    RegisterInventoryItemAtlas(atlas, image .. ".tex")
end
for _, image in ipairs({ "gb_preservation_kit", "gb_freshness_kit" }) do
    local atlas = "images/" .. image .. ".xml"
    Assets[#Assets + 1] = G.Asset("ATLAS", atlas)
    Assets[#Assets + 1] = G.Asset("IMAGE", "images/" .. image .. ".tex")
    RegisterInventoryItemAtlas(atlas, image .. ".tex")
end
if not G.TheNet:IsDedicated() then
    local inventorylayout = G.require("gb_inventory_layout")
    AddClassPostConstruct("widgets/inventorybar", inventorylayout.Install)
    local packpanel = G.require("gb_pack_panel")
    AddClassPostConstruct("widgets/containerwidget", packpanel.InstallContainer)
end
local clientcontainer = G.require("gb_client_container")
AddClassPostConstruct("components/container_replica", function(self)
    if self.inst:HasTag("gb_growing_backpack") then
        clientcontainer.Install(self)
    end
end)
local upgrade = G.require("gb_upgrade_action")
local expand = AddAction("GB_EXPAND_BACKPACK", "扩容背包", upgrade.Perform)
expand.priority = 10
expand.distance = 2
AddStategraphActionHandler("wilson", G.ActionHandler(expand, "give"))
AddStategraphActionHandler("wilson_client", G.ActionHandler(expand, "give"))
local moduleaction = G.require("gb_module_action")
local install = AddAction("GB_INSTALL_MODULE", "安装背包插件", moduleaction.Perform)
install.priority = 10
install.distance = 2
AddComponentAction("USEITEM", "inventoryitem", function(inst, doer, target, actions, right)
    -- DST stores one callback per mod/action type/component. A second
    -- registration would replace expansion with module installation.
    upgrade.Collect(expand, inst, doer, target, actions)
    moduleaction.Collect(install, inst, doer, target, actions)
end)
AddStategraphActionHandler("wilson", G.ActionHandler(install, "give"))
AddStategraphActionHandler("wilson_client", G.ActionHandler(install, "give"))

local containers = G.require("containers")
local layout = G.require("gb_layout")
for level = 0, 3 do
    containers.params["growing_backpack_" .. level] = layout.Make(level, G.Vector3)
end
containers.params.growing_backpack = containers.params.growing_backpack_0
containers.MAXITEMSLOTS = G.math.max(containers.MAXITEMSLOTS, 32)

local names = {
    growing_backpack = "成长背包",
    gb_upgrade_1 = "皮革扩容工具",
    gb_upgrade_2 = "机械扩容工具",
    gb_upgrade_3 = "远古扩容工具",
    gb_preservation_kit = "保鲜插件",
    gb_freshness_kit = "返鲜插件",
}
local descriptions = {
    growing_backpack = "从八格起步，伴你探索到远古。",
    gb_upgrade_1 = "将成长背包从 8 格升级到 16 格。",
    gb_upgrade_2 = "将成长背包从 16 格升级到 24 格。",
    gb_upgrade_3 = "将成长背包从 24 格升级到 32 格。",
    gb_preservation_kit = "安装在机械或远古包上，获得冰箱75%的保鲜效果。",
    gb_freshness_kit = "安装在远古包上，每游戏日恢复25%食物新鲜度。无需先装保鲜。",
}
for prefab, name in pairs(names) do
    local key = G.string.upper(prefab)
    G.STRINGS.NAMES[key] = name
    G.STRINGS.RECIPE_DESC[key] = descriptions[prefab]
    G.STRINGS.CHARACTERS.GENERIC.DESCRIBE[key] = descriptions[prefab]
end

local Ingredient, TECH = G.Ingredient, G.TECH
AddRecipe2("growing_backpack", { Ingredient("cutgrass", 4), Ingredient("twigs", 4) },
    TECH.SCIENCE_ONE, { image = "gb_pack_0.tex", atlas = "images/gb_pack_0.xml" }, { "CONTAINERS" })
AddRecipe2("gb_upgrade_1", { Ingredient("rope", 2), Ingredient("pigskin", 2), Ingredient("goldnugget", 2) },
    TECH.SCIENCE_ONE, { image = "gb_upgrade_1.tex", atlas = "images/gb_upgrade_1.xml" }, { "CONTAINERS" })
AddRecipe2("gb_upgrade_2", { Ingredient("silk", 4), Ingredient("papyrus", 2), Ingredient("gears", 2) },
    TECH.SCIENCE_TWO, { image = "gb_upgrade_2.tex", atlas = "images/gb_upgrade_2.xml" }, { "CONTAINERS" })
AddRecipe2("gb_upgrade_3", { Ingredient("thulecite", 4), Ingredient("yellowgem", 2), Ingredient("nightmarefuel", 4) },
    TECH.ANCIENT_FOUR, { nounlock = true, image = "gb_upgrade_3.tex", atlas = "images/gb_upgrade_3.xml" }, { "CONTAINERS" })
AddRecipe2("gb_preservation_kit", { Ingredient("gears", 2), Ingredient("bluegem", 1), Ingredient("transistor", 2) },
    TECH.SCIENCE_TWO, { image = "gb_preservation_kit.tex", atlas = "images/gb_preservation_kit.xml" }, { "CONTAINERS" })
AddRecipe2("gb_freshness_kit", { Ingredient("thulecite", 6), Ingredient("greengem", 2), Ingredient("nightmarefuel", 6) },
    TECH.ANCIENT_FOUR, { nounlock = true, image = "gb_freshness_kit.tex", atlas = "images/gb_freshness_kit.xml" }, { "CONTAINERS" })
