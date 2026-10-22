-- Keep the native inventory bar and its real InvSlots; only page this bag's
-- overflow slots. Server containers, inventory events and item actions stay intact.
local M = {}
local Paging = require("gb_pack_panel")

local function Apply(bar)
    local pack = bar.backpack
    local mode = TheNet:GetServerGameMode()
    if not bar.integrated_backpack or pack == nil
        or not pack:HasTag("gb_growing_backpack")
        or mode == "quagmire" or mode == "lavaarena"
        or #bar.backpackinv <= Paging.PAGE_SIZE or #bar.inv < Paging.PAGE_SIZE then
        return
    end

    -- The game's eight-slot bag uses these exact inventory-column positions.
    -- All backgrounds, row positions, tips, controller scale and anchors are
    -- deliberately left as Rebuild created them.
    for index, slot in ipairs(bar.backpackinv) do
        local column = (index - 1) % Paging.PAGE_SIZE + 1
        local reference = bar.inv[#bar.inv - Paging.PAGE_SIZE + column]
        slot:SetPosition(reference:GetPosition().x, 0, 0)
    end
    local lastx = bar.backpackinv[Paging.PAGE_SIZE]:GetPosition().x
    bar._gb_inventory_layout = Paging.Create(bar.bottomrow, bar.backpackinv,
        pack, bar.owner, Paging.PAGE_SIZE, lastx + 270, 0)
    bar:UpdateCursor()
end

function M.Install(bar)
    if bar._gb_inventory_layout_installed then return end
    bar._gb_inventory_layout_installed = true

    local rebuild = bar.Rebuild
    bar.Rebuild = function(self, ...)
        Paging.Destroy(self._gb_inventory_layout)
        self._gb_inventory_layout = nil
        rebuild(self, ...)
        Apply(self)
    end

    local closest = bar.GetClosestWidget
    bar.GetClosestWidget = function(self, lists, position, direction)
        local active = self.active_slot
        local state = active ~= nil and active._gb_page_state or nil
        if state ~= nil and not state.closed and direction.y == 0 and direction.x ~= 0 then
            local included = false
            for _, list in pairs(lists) do
                if list == state.slots then included = true; break end
            end
            local index = (active.num - 1) % Paging.PAGE_SIZE
            local column = index % state.columns
            if included and (direction.x < 0 and column == 0
                or direction.x > 0 and column == state.columns - 1) then
                local step = direction.x < 0 and -1 or 1
                local nextpage = state.page + step
                if nextpage >= 1 and nextpage <= state.pages then
                    local nextcolumn = step < 0 and state.columns - 1 or 0
                    local cell = math.floor(index / state.columns) * state.columns + nextcolumn
                    -- Return a real destination only. The original CursorNav
                    -- cancels deployment, updates hint timing and selects it;
                    -- our SelectSlot hook then reveals the destination page.
                    return state.slots[(nextpage - 1) * Paging.PAGE_SIZE + cell + 1], state.slots
                end
                -- At the first/last page edge, do not jump diagonally. Native
                -- vertical navigation still enters and leaves the container.
                return nil, nil
            end
        end
        local filtered, originals = {}, {}
        local has_paging = false
        for _, list in pairs(lists) do
            local visible = {}
            for _, slot in pairs(list) do
                if slot._gb_page_state ~= nil then has_paging = true end
                if slot:IsVisible() then visible[#visible + 1] = slot end
            end
            filtered[#filtered + 1] = visible
            originals[visible] = list
        end
        if not has_paging then return closest(self, lists, position, direction) end
        local slot, list = closest(self, filtered, position, direction)
        return slot, originals[list]
    end

    local selectslot = bar.SelectSlot
    bar.SelectSlot = function(self, slot, ...)
        local state = slot ~= nil and slot._gb_page_state or nil
        if state ~= nil then
            -- Programmatic selection must reveal its real slot before the
            -- game's cursor/held-item machinery positions itself there.
            state:SetPage(math.ceil(slot.num / Paging.PAGE_SIZE), true)
        end
        return selectslot(self, slot, ...)
    end

    local onitemget = bar.OnItemGet
    bar.OnItemGet = function(self, item, slot, source_pos, ...)
        if slot ~= nil and slot._gb_page_state ~= nil and not slot.shown then
            source_pos = nil
        end
        onitemget(self, item, slot, source_pos, ...)
        Paging.AfterItemGet(slot)
    end
end

return M
