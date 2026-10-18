PrefabFiles = { "growing_backpack", "gb_upgrade_kits" }

local G = GLOBAL
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
AddComponentAction("USEITEM", "inventoryitem", function(inst, doer, target, actions, right)
    upgrade.Collect(expand, inst, doer, target, actions)
end)
AddStategraphActionHandler("wilson", G.ActionHandler(expand, "give"))
AddStategraphActionHandler("wilson_client", G.ActionHandler(expand, "give"))

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
}
local descriptions = {
    growing_backpack = "从八格起步，伴你探索到远古。",
    gb_upgrade_1 = "将成长背包从 8 格升级到 16 格。",
    gb_upgrade_2 = "将成长背包从 16 格升级到 24 格。",
    gb_upgrade_3 = "将成长背包从 24 格升级到 32 格。",
}
for prefab, name in pairs(names) do
    local key = G.string.upper(prefab)
    G.STRINGS.NAMES[key] = name
    G.STRINGS.RECIPE_DESC[key] = descriptions[prefab]
    G.STRINGS.CHARACTERS.GENERIC.DESCRIBE[key] = descriptions[prefab]
end

local Ingredient, TECH = G.Ingredient, G.TECH
AddRecipe2("growing_backpack", { Ingredient("cutgrass", 4), Ingredient("twigs", 4) },
    TECH.SCIENCE_ONE, { image = "backpack.tex", atlas = G.GetInventoryItemAtlas("backpack.tex") }, { "CONTAINERS" })
AddRecipe2("gb_upgrade_1", { Ingredient("rope", 2), Ingredient("pigskin", 2), Ingredient("goldnugget", 2) },
    TECH.SCIENCE_ONE, { image = "sewing_kit.tex", atlas = G.GetInventoryItemAtlas("sewing_kit.tex") }, { "CONTAINERS" })
AddRecipe2("gb_upgrade_2", { Ingredient("silk", 4), Ingredient("papyrus", 2), Ingredient("gears", 2) },
    TECH.SCIENCE_TWO, { image = "sewing_kit.tex", atlas = G.GetInventoryItemAtlas("sewing_kit.tex") }, { "CONTAINERS" })
AddRecipe2("gb_upgrade_3", { Ingredient("thulecite", 4), Ingredient("yellowgem", 2), Ingredient("nightmarefuel", 4) },
    TECH.ANCIENT_FOUR, { nounlock = true, image = "sewing_kit.tex", atlas = G.GetInventoryItemAtlas("sewing_kit.tex") }, { "CONTAINERS" })
