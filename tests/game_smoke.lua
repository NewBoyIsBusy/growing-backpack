local slots = require("gb_layout").Slots
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
    assert(p.components.container.numslots == slots(level))
    assert(p.replica.container:GetNumSlots() == slots(level))
    assert(#p.replica.container:GetWidget().slotpos == slots(level))
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
        assert(p.components.container:GiveItem(SpawnPrefab("flint"), slots(level)))
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
    assert(p.components.container.numslots == 30)
    p:Remove()
end)
test("save and restore all 30 filled slots", function()
    local p = pack()
    for level = 1, 3 do upgrade(p, level) end
    for slot = 1, 30 do
        assert(p.components.container:GiveItem(SpawnPrefab(slot % 2 == 0 and "flint" or "rocks"), slot))
    end
    local record = p:GetSaveRecord()
    p:Remove()
    local restored = assert(SpawnSaveRecord(record))
    assert(restored._gb_level:value() == 3)
    assert(restored.components.container.numslots == 30)
    for slot = 1, 30 do
        assert(restored.components.container:GetItemInSlot(slot).prefab == (slot % 2 == 0 and "flint" or "rocks"))
    end
    restored:Remove()
end)
test("recover level from saved high slots", function()
    local p = pack()
    for level = 1, 3 do upgrade(p, level) end
    assert(p.components.container:GiveItem(SpawnPrefab("yellowgem"), 30))
    local record = p:GetSaveRecord()
    record.data.gb_level = nil
    p:Remove()
    local restored = assert(SpawnSaveRecord(record))
    assert(restored.components.container.numslots == 30)
    assert(restored.components.container:GetItemInSlot(30).prefab == "yellowgem")
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
    assert(p.components.container.numslots == 15)
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
        assert(p.components.container.numslots == slots(level))
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
        assert(p.components.container.numslots == slots(level))
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
    assert(built.components.container.numslots==30)
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
test("food plugin tier gates and duplicates preserve rejected tools", function()
    local p = pack()
    for level = 0, 3 do
        if level > 0 then upgrade(p, level) end
        for _, name in ipairs({"gb_preservation_kit", "gb_freshness_kit"}) do
            local kit = assert(SpawnPrefab(name))
            local expected = (name == "gb_preservation_kit" and level == 2)
                or (name == "gb_freshness_kit" and level == 3)
            assert(p.components.trader:AcceptGift(nil, kit) == expected)
            assert(kit:IsValid() == not expected)
            if kit:IsValid() then kit:Remove() end
        end
    end
    assert(p._gb_modules:value() == 3)
    for _, name in ipairs({"gb_preservation_kit", "gb_freshness_kit"}) do
        local kit = SpawnPrefab(name)
        assert(not p.components.trader:AcceptGift(nil, kit) and kit:IsValid())
        kit:Remove()
    end
    p:Remove()
end)

test("preservation survives expansion with original backpack and contents", function()
    local p = pack()
    upgrade(p, 1); upgrade(p, 2)
    local originalguid = p.GUID
    local berries = SpawnPrefab("berries")
    assert(p.components.container:GiveItem(berries, 23))
    local kit = SpawnPrefab("gb_preservation_kit")
    assert(p.components.trader:AcceptGift(nil, kit))
    assert(p.components.container.numslots == 23)
    local expected = 1 - (1 - TUNING.PERISH_FRIDGE_MULT) * .75
    assert(p.components.preserver:GetPerishRateMultiplier(berries) == expected)
    upgrade(p, 3)
    assert(p.GUID == originalguid and p.components.container:GetItemInSlot(23) == berries)
    assert(p.components.gb_foodmodules.preservation and p._gb_modules:value() == 1)
    local record = p:GetSaveRecord()
    p:Remove()
    p = assert(SpawnSaveRecord(record))
    assert(p.components.gb_foodmodules.preservation and p._gb_modules:value() == 1)
    assert(p.components.container.numslots == 30)
    assert(p.components.container:GetItemInSlot(23).prefab == "berries")
    p:Remove()
end)

test("freshness alone pauses spoilage and returns 25 percent per day", function()
    local p = pack()
    for level = 1, 3 do upgrade(p, level) end
    local kit = SpawnPrefab("gb_freshness_kit")
    assert(p.components.trader:AcceptGift(nil, kit))
    assert(not p.components.gb_foodmodules.preservation and p._gb_modules:value() == 2)
    local berries = SpawnPrefab("berries")
    assert(p.components.container:GiveItem(berries, 1))
    local perish = berries.components.perishable
    perish:SetPercent(.1)
    perish.start_dt = nil
    perish:LongUpdate(TUNING.TOTAL_DAY_TIME)
    assert(math.abs(perish:GetPercent() - .1) < .000001)
    p.components.gb_foodmodules:LongUpdate(TUNING.TOTAL_DAY_TIME)
    assert(math.abs(perish:GetPercent() - .35) < .000001)
    p.components.gb_foodmodules:LongUpdate(3 * TUNING.TOTAL_DAY_TIME)
    assert(perish:GetPercent() == 1 and berries:HasTag("fresh"))
    local rot = SpawnPrefab("spoiled_food")
    assert(p.components.container:GiveItem(rot, 2))
    local rocks = SpawnPrefab("rocks")
    assert(p.components.container:GiveItem(rocks, 3))
    p.components.gb_foodmodules:LongUpdate(4 * TUNING.TOTAL_DAY_TIME)
    assert(p.components.container:GetItemInSlot(2) == rot and rot.prefab == "spoiled_food")
    assert(p.components.container:GetItemInSlot(3) == rocks)
    assert(p.components.preserver:GetPerishRateMultiplier(rocks) == 1)
    p.components.container:RemoveItemBySlot(1)
    perish.start_dt = nil
    perish:LongUpdate(30)
    assert(perish:GetPercent() < 1, "outside food must resume native spoilage")
    berries:Remove(); p:Remove()
end)

test("both food modules survive full save load with freshness priority", function()
    local p = pack()
    for level = 1, 3 do upgrade(p, level) end
    for _, name in ipairs({"gb_freshness_kit", "gb_preservation_kit"}) do
        assert(p.components.trader:AcceptGift(nil, SpawnPrefab(name)))
    end
    local berries = SpawnPrefab("berries")
    assert(p.components.container:GiveItem(berries, 30))
    berries.components.perishable:SetPercent(.2)
    local record = p:GetSaveRecord()
    p:Remove()
    p = assert(SpawnSaveRecord(record))
    local modules = p.components.gb_foodmodules
    assert(modules.preservation and modules.freshness and p._gb_modules:value() == 3)
    berries = p.components.container:GetItemInSlot(30)
    assert(berries.prefab == "berries")
    assert(p.components.preserver:GetPerishRateMultiplier(berries) == 0)
    modules:LongUpdate(TUNING.TOTAL_DAY_TIME)
    assert(math.abs(berries.components.perishable:GetPercent() - .45) < .000001)
    assert(p.displaynamefn(p):find("保鲜+返鲜", 1, true))
    p:Remove()
end)

test("real plugin action replaces store, refuses worn pack, and installs on ground", function()
    local p, player = pack(), SpawnPrefab("wilson")
    for level = 1, 3 do upgrade(p, level) end
    player:AddComponent("playeractionpicker")
    local kit = SpawnPrefab("gb_freshness_kit")
    player.components.inventory:GiveActiveItem(kit)
    assert(player.sg.sg.actionhandlers[ACTIONS.GB_INSTALL_MODULE])
    assert(require("stategraphs/SGwilson_client").actionhandlers[ACTIONS.GB_INSTALL_MODULE])
    player.components.inventory:Equip(p)
    assert(not p.components.trader:AcceptGift(player, kit) and kit:IsValid())
    player.components.inventory:DropItem(p, true, true)
    for _, right in ipairs({false, true}) do
        local choices = player.components.playeractionpicker:GetUseItemActions(p, kit, right)
        assert(choices[1] and choices[1].action == ACTIONS.GB_INSTALL_MODULE)
        for _, choice in ipairs(choices) do
            assert(choice.action ~= ACTIONS.STORE and choice.action ~= ACTIONS.GIVE)
        end
    end
    assert(player.components.playeractionpicker:GetUseItemActions(p, kit, true)[1]:Do())
    assert(not kit:IsValid() and p.components.gb_foodmodules.freshness)
    local duplicate = SpawnPrefab("gb_freshness_kit")
    player.components.inventory:GiveActiveItem(duplicate)
    assert(not player.components.playeractionpicker:GetUseItemActions(p, duplicate, true)[1]:Do())
    assert(duplicate:IsValid() and duplicate.components.inventoryitem:GetGrandOwner() == player)
    local chest = SpawnPrefab("treasurechest")
    local choices = player.components.playeractionpicker:GetUseItemActions(chest, duplicate, false)
    assert(choices[1].action == ACTIONS.STORE and choices[1]:Do())
    assert(duplicate.components.inventoryitem.owner == chest)
    chest:Remove(); player:Remove(); p:Remove()
end)

test("both new plugins craft with matching custom icons and ground builds", function()
    local player = SpawnPrefab("wilson")
    local built
    player:ListenForEvent("builditem", function(_, data) built = data.item end)
    for _, name in ipairs({"gb_preservation_kit", "gb_freshness_kit"}) do
        local recipe = assert(AllRecipes[name])
        for _, ingredient in ipairs(recipe.ingredients) do
            local material = SpawnPrefab(ingredient.type)
            material.components.stackable:SetStackSize(ingredient.amount)
            player.components.inventory:GiveItem(material)
        end
        assert(player.components.builder:DoBuild(name))
        assert(built and built.prefab == name and built:HasTag("gb_foodmodule_kit"))
        assert(built.AnimState:GetBuild() == name and built.AnimState:IsCurrentAnimation("idle"))
        assert(built.components.inventoryitem.imagename == name)
        assert(built.components.inventoryitem.atlasname == "images/" .. name .. ".xml")
        assert(TheSim:AtlasContains(resolvefilepath(recipe.atlas), name .. ".tex"))
        assert(recipe.image == name .. ".tex")
        built:Remove()
    end
    player:Remove()
end)

-- Exercise real old save records, including worn bags at non-origin positions.
local migrations = {}
for level=1,3 do
    local template=pack()
    for n=1,level do upgrade(template,n) end
    local record=template:GetSaveRecord()
    template:Remove()
    record.data.gb_capacity_version=nil
    record.data.container.items={}
    for slot=1,8*(level+1) do
        local item=SpawnPrefab("axe")
        record.data.container.items[slot]=item:GetSaveRecord()
        item:Remove()
    end
    local restored=assert(SpawnSaveRecord(record))
    local player=SpawnPrefab("wilson")
    player.Transform:SetPosition(20+level*7,0,20)
    player.components.inventory:Equip(restored)
    local snapshot=restored:GetSaveRecord()
    assert(#snapshot.data.container.gb_overflow==8*(level+1)-slots(level))
    assert(snapshot.data.gb_level==level)
    migrations[#migrations+1]={pack=restored,player=player,level=level}
end
local sparse=pack()
upgrade(sparse,1)
local sparse_record=sparse:GetSaveRecord()
sparse:Remove()
sparse_record.data.gb_capacity_version=nil
local gem=SpawnPrefab("yellowgem")
sparse_record.data.container.items={[16]=gem:GetSaveRecord()}
gem:Remove()
sparse=assert(SpawnSaveRecord(sparse_record))

TheWorld:DoTaskInTime(.1,function()
    local ok,err=pcall(function()
        test("old 16/24/32 full worn bags preserve tiers and drop excess beside owners",function()
            for _,case in ipairs(migrations) do
                local p,player,level=case.pack,case.player,case.level
                assert(p._gb_level:value()==level and p.components.container.numslots==slots(level))
                for i=1,slots(level) do assert(p.components.container:GetItemInSlot(i).prefab=="axe") end
                local x,y,z=player.Transform:GetWorldPosition()
                local dropped=0
                for _,item in ipairs(TheSim:FindEntities(x,y,z,2)) do
                    if item.prefab=="axe" and item.components.inventoryitem.owner==nil then
                        assert(item.persists)
                        dropped=dropped+1
                        item:Remove()
                    end
                end
                assert(dropped==8*(level+1)-slots(level),"legacy excess must drop at equipped owner")
                assert(p:GetSaveRecord().data.container.gb_overflow==nil)
                p:Remove();player:Remove()
            end
        end)
        test("legacy sparse last slot moves into available space without promoting tier",function()
            assert(sparse._gb_level:value()==1 and sparse.components.container.numslots==15)
            assert(sparse.components.container:GetItemInSlot(1).prefab=="yellowgem")
            sparse:Remove()
        end)
    end)
    if not ok then print("GROWINGPACK_GAME_FAILURE "..tostring(err))
    else print("GROWINGPACK_GAME_SUCCESS "..count.." tests") end
    c_shutdown(false)
end)
