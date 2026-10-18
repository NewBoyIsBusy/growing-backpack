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
        assert(p.components.floater.swap_data.bank == look.bank)
        local record = p:GetSaveRecord()
        p:Remove()
        p = assert(SpawnSaveRecord(record))
        assert(p.AnimState:GetBuild() == look.build)
        assert(p.components.inventoryitem.imagename == look.image)
        -- Equipping every tier also exercises both optional backpack symbols.
        local player = SpawnPrefab("wilson")
        player.components.inventory:Equip(p)
        assert(p.components.equippable:IsEquipped())
        player.components.inventory:DropItem(p, true, true)
        player:Remove()
        assert(p.components.container.numslots == 8 * (level + 1))
        assert(not p.components.preserver and not p.components.waterproofer)
    end
    p:Remove()
end)
print("GROWINGPACK_GAME_SUCCESS " .. count .. " tests")
c_shutdown(false)
