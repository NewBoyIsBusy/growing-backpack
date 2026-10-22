-- Executed only in a fresh isolated offline test world.
local count = 0
local function test(name, fn)
    fn()
    count = count + 1
    print("GROWINGPACK_GAME_PASS " .. name)
end
local function pack() return assert(SpawnPrefab("growing_backpack")) end
local function upgrade(p, level)
    local kit = assert(SpawnPrefab("gb_upgrade_" .. level))
    assert(p.components.trader:AcceptGift(nil, kit))
    assert(not kit:IsValid(), "accepted kit must be consumed")
    assert(p.components.container.numslots == 8 * (level + 1))
    assert(p.replica.container:GetNumSlots() == 8 * (level + 1))
    assert(#p.replica.container:GetWidget().slotpos == 8 * (level + 1))
end
test("recipes and initial capacity", function()
    for _, name in ipairs({"growing_backpack", "gb_upgrade_1", "gb_upgrade_2", "gb_upgrade_3"}) do
        assert(AllRecipes[name], "missing recipe " .. name)
    end
    local p = pack()
    assert(p.components.container.numslots == 8)
    assert(p.replica.container:GetNumSlots() == 8)
    p:Remove()
end)
test("reject skipped tier and unrelated material without consuming", function()
    local p = pack()
    for _, name in ipairs({"gb_upgrade_2", "gb_upgrade_3", "rocks"}) do
        local item = SpawnPrefab(name)
        assert(not p.components.trader:AcceptGift(nil, item))
        assert(item:IsValid())
        item:Remove()
    end
    assert(p.components.container.numslots == 8)
    p:Remove()
end)
test("all upgrades preserve original contents and unlock last slots", function()
    local p = pack()
    local original = SpawnPrefab("rocks")
    assert(p.components.container:GiveItem(original, 8))
    for level = 1, 3 do
        upgrade(p, level)
        assert(p.components.container:GetItemInSlot(8) == original)
        assert(p.components.container:GiveItem(SpawnPrefab("flint"), 8 * (level + 1)))
    end
    p:Remove()
end)
test("max tier rejects all kits without consuming", function()
    local p = pack()
    for level = 1, 3 do upgrade(p, level) end
    for level = 1, 3 do
        local kit = SpawnPrefab("gb_upgrade_" .. level)
        assert(not p.components.trader:AcceptGift(nil, kit))
        assert(kit:IsValid())
        kit:Remove()
    end
    assert(p.components.container.numslots == 32)
    p:Remove()
end)
test("save and restore all 32 filled slots", function()
    local p = pack()
    for level = 1, 3 do upgrade(p, level) end
    for slot = 1, 32 do
        assert(p.components.container:GiveItem(SpawnPrefab(slot % 2 == 0 and "flint" or "rocks"), slot))
    end
    local record = p:GetSaveRecord()
    p:Remove()
    local restored = assert(SpawnSaveRecord(record))
    assert(restored._gb_level:value() == 3)
    assert(restored.components.container.numslots == 32)
    for slot = 1, 32 do
        assert(restored.components.container:GetItemInSlot(slot).prefab == (slot % 2 == 0 and "flint" or "rocks"))
    end
    restored:Remove()
end)
test("recover level from saved high slots", function()
    local p = pack()
    for level = 1, 3 do upgrade(p, level) end
    assert(p.components.container:GiveItem(SpawnPrefab("yellowgem"), 32))
    local record = p:GetSaveRecord()
    record.data.gb_level = nil
    p:Remove()
    local restored = assert(SpawnSaveRecord(record))
    assert(restored.components.container.numslots == 32)
    assert(restored.components.container:GetItemInSlot(32).prefab == "yellowgem")
    restored:Remove()
end)
test("equipping opens backpack and prevents an upgrade while worn", function()
    local p, player = pack(), SpawnPrefab("wilson")
    player.components.inventory:Equip(p)
    assert(p.components.container:IsOpenedBy(player))
    local kit = SpawnPrefab("gb_upgrade_1")
    assert(not p.components.trader:AcceptGift(player, kit))
    assert(kit:IsValid())
    player.components.inventory:DropItem(p, true, true)
    assert(p.components.inventoryitem.owner == nil)
    assert(not p.components.container:IsOpenedBy(player))
    assert(p.components.trader:AcceptGift(player, kit))
    assert(p.components.container.numslots == 16)
    player:Remove()
    p:Remove()
end)
test("vanilla backpack remains eight slots", function()
    local p = SpawnPrefab("backpack")
    assert(p.components.container.numslots == 8)
    p:Remove()
end)
test("all four art builds and icons survive upgrade and reload", function()
    local looks = require("gb_appearance")
    local p = pack()
    for level = 0, 3 do
        if level > 0 then upgrade(p, level) end
        local look = looks.Get(level)
        assert(p.AnimState:GetBuild() == look.build)
        assert(p.components.inventoryitem.imagename == look.image)
        assert(p.components.inventoryitem.atlasname == look.atlas)
        assert(p.replica.inventoryitem:GetAtlas() == hash(resolvefilepath(look.atlas)))
        assert(p.replica.inventoryitem:GetImage() == hash(look.image .. ".tex"))
        assert(TheSim:AtlasContains(resolvefilepath(look.atlas), look.image .. ".tex"))
        assert(TheSim:AtlasContains(resolvefilepath(look.atlas), look.image .. ".png"))
        assert(p.components.floater.swap_data.bank == look.bank)
        local record = p:GetSaveRecord()
        p:Remove()
        p = assert(SpawnSaveRecord(record))
        assert(p.AnimState:GetBuild() == look.build)
        assert(p.components.inventoryitem.imagename == look.image)
        assert(p.components.inventoryitem.atlasname == look.atlas)
        -- Every tier must attach the custom swap_body build when equipped.
        local player = SpawnPrefab("wilson")
        player.components.inventory:Equip(p)
        assert(p.components.equippable:IsEquipped())
        local swapbuild, swapsymbol = player.AnimState:GetSymbolOverride("swap_body")
        assert(swapbuild == hash(look.build) and swapsymbol == hash("swap_body"))
        player.components.inventory:DropItem(p, true, true)
        player:Remove()
        assert(p.components.container.numslots == 8 * (level + 1))
        assert(not p.components.preserver and not p.components.waterproofer)
    end
    p:Remove()
end)
test("real action picker chooses expand for both mouse buttons and executes upgrades", function()
    local p, player = pack(), SpawnPrefab("wilson")
    player:AddComponent("playeractionpicker") -- no local input component on a dedicated server
    local original = SpawnPrefab("rocks")
    assert(p.components.container:GiveItem(original, 8))
    assert(player.sg.sg.actionhandlers[ACTIONS.GB_EXPAND_BACKPACK], "server stategraph handler missing")
    local clientsg = require("stategraphs/SGwilson_client")
    assert(clientsg.actionhandlers[ACTIONS.GB_EXPAND_BACKPACK], "client stategraph handler missing")
    for level = 1, 3 do
        local kit = SpawnPrefab("gb_upgrade_" .. level)
        player.components.inventory:GiveActiveItem(kit)
        for _, right in ipairs({false, true}) do
            local choices = player.components.playeractionpicker:GetUseItemActions(p, kit, right)
            assert(choices[1] and choices[1].action == ACTIONS.GB_EXPAND_BACKPACK, "click must select expand")
            for _, choice in ipairs(choices) do
                assert(choice.action ~= ACTIONS.STORE and choice.action ~= ACTIONS.GIVE)
            end
        end
        local chosen = player.components.playeractionpicker:GetUseItemActions(p, kit, false)[1]
        assert(chosen:Do(), "selected buffered action must execute")
        assert(not kit:IsValid())
        assert(p.components.container.numslots == 8 * (level + 1))
        assert(p.components.container:GetItemInSlot(8) == original)
    end
    p:Remove(); player:Remove()
end)
test("wrong-tier and full-level clicks refuse without consuming or storing", function()
    local p, player = pack(), SpawnPrefab("wilson")
    player:AddComponent("playeractionpicker")
    local kit = SpawnPrefab("gb_upgrade_2")
    player.components.inventory:GiveActiveItem(kit)
    local function refuse()
        local chosen = player.components.playeractionpicker:GetUseItemActions(p, kit, false)[1]
        assert(chosen.action == ACTIONS.GB_EXPAND_BACKPACK)
        assert(not chosen:Do())
        assert(kit:IsValid() and kit.components.inventoryitem:GetGrandOwner() == player)
        assert(p.components.container:NumItems() == 0)
    end
    refuse()
    for level = 1, 3 do upgrade(p, level) end
    refuse()
    p:Remove(); player:Remove()
end)
test("ordinary storage and storing kits in other containers are unchanged", function()
    local p, player = pack(), SpawnPrefab("wilson")
    player:AddComponent("playeractionpicker")
    local rocks = SpawnPrefab("rocks")
    player.components.inventory:GiveActiveItem(rocks)
    local choices = player.components.playeractionpicker:GetUseItemActions(p, rocks, false)
    local store
    for _, choice in ipairs(choices) do
        assert(choice.action ~= ACTIONS.GB_EXPAND_BACKPACK)
        if choice.action == ACTIONS.STORE then store = choice end
    end
    assert(store and store:Do())
    assert(rocks.components.inventoryitem.owner == p)
    local chest = SpawnPrefab("treasurechest")
    local kit = SpawnPrefab("gb_upgrade_1")
    player.components.inventory:GiveActiveItem(kit)
    choices = player.components.playeractionpicker:GetUseItemActions(chest, kit, false)
    assert(choices[1].action == ACTIONS.STORE and choices[1]:Do())
    assert(kit.components.inventoryitem.owner == chest)
    p:Remove(); chest:Remove(); player:Remove()
end)
test("real crafting consumes ingredients and auto-equips the new backpack", function()
    local player = SpawnPrefab("wilson")
    local built
    player:ListenForEvent("builditem", function(inst,data) built=data.item end)
    for _,name in ipairs({"cutgrass","twigs"}) do
        local item=SpawnPrefab(name)
        item.components.stackable:SetStackSize(4)
        player.components.inventory:GiveItem(item)
    end
    assert(player.components.builder:DoBuild("growing_backpack"))
    assert(built and built.prefab=="growing_backpack")
    assert(built.components.equippable:IsEquipped())
    assert(built.components.container:IsOpenedBy(player))
    assert(built.components.container.numslots==8)
    assert(not player.components.inventory:Has("cutgrass",1))
    assert(not player.components.inventory:Has("twigs",1))
    player.components.inventory:DropItem(built,true,true)
    for level=1,3 do
        local recipe=AllRecipes["gb_upgrade_"..level]
        for _,ingredient in ipairs(recipe.ingredients) do
            local item=SpawnPrefab(ingredient.type)
            item.components.stackable:SetStackSize(ingredient.amount)
            player.components.inventory:GiveItem(item)
        end
        local backpack=built
        assert(player.components.builder:DoBuild("gb_upgrade_"..level))
        assert(built.prefab=="gb_upgrade_"..level)
        assert(backpack.components.trader:AcceptGift(player,built))
        built=backpack
    end
    assert(built.components.container.numslots==32)
    built:Remove(); player:Remove()
end)
test("three expansion tools load original art and crafting icons", function()
    for level = 1, 3 do
        local name = "gb_upgrade_" .. level
        local kit = assert(SpawnPrefab(name))
        local atlas = "images/" .. name .. ".xml"
        assert(kit.AnimState:GetBuild() == name)
        assert(kit.AnimState:IsCurrentAnimation("idle"))
        assert(kit.components.inventoryitem.imagename == name)
        assert(kit.components.inventoryitem.atlasname == atlas)
        assert(kit.replica.inventoryitem:GetAtlas() == hash(resolvefilepath(atlas)))
        assert(TheSim:AtlasContains(resolvefilepath(atlas), name .. ".tex"))
        assert(AllRecipes[name].image == name .. ".tex")
        assert(kit.components.floater ~= nil)
        kit:Remove()
    end
end)
print("GROWINGPACK_GAME_SUCCESS " .. count .. " tests")
c_shutdown(false)
