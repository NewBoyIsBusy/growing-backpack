-- Reflow only the growing backpack's integrated HUD. Keep vanilla InvSlots,
-- containers and event callbacks intact; no profile or server state is changed.
local M = {}
local COLUMNS = 8
local SLOT = 68
local XSTEP = SLOT + 12
local YSTEP = SLOT + 8

local function IsGrowingBar(bar)
    local pack = bar.backpack
    local mode = TheNet:GetServerGameMode()
    return bar.integrated_backpack and pack ~= nil
        and mode ~= "quagmire" and mode ~= "lavaarena"
        and pack:HasTag("gb_growing_backpack") and #bar.backpackinv > COLUMNS
        and bar.toprow ~= nil and bar.bottomrow ~= nil
end

local function Restore(bar)
    local previous = bar._gb_inventory_layout
    if previous == nil then return end
    -- These widgets survive Rebuild. Row widgets, slots and the arrow do not.
    bar.bg:SetSize(previous.background_width, previous.background_height)
    if previous.cover_shown then bar.bgcover:Show() else bar.bgcover:Hide() end
    bar._gb_inventory_layout = nil
end

local function Apply(bar)
    if not IsGrowingBar(bar) or #bar.inv == 0
        or bar.bg.GetSize == nil or bar.bg.SetSize == nil then
        return
    end
    local count = #bar.backpackinv
    local rows = math.ceil(count / COLUMNS)
    local width, height = bar.bg:GetSize()
    local state = {
        rows = rows,
        columns = COLUMNS,
        background_width = width,
        background_height = height,
        cover_shown = bar.bgcover.shown,
        anchor_extra = (rows - 1) * YSTEP,
    }
    bar._gb_inventory_layout = state

    -- Keep the main inventory at the normal bottom-row height. Additional
    -- backpack rows grow upwards, never below the bottom of the screen.
    bar.toprow:SetPosition(0, -YSTEP / 2)
    local center = (bar.inv[1]:GetPosition().x + bar.inv[#bar.inv]:GetPosition().x) / 2
    bar.bottomrow:SetPosition(center, YSTEP / 2)
    local top = YSTEP / 2 + (rows - 1) * YSTEP
    for index, slot in ipairs(bar.backpackinv) do
        local row = math.floor((index - 1) / COLUMNS)
        local column = (index - 1) % COLUMNS
        local y = (rows - row - 1) * YSTEP
        slot:SetPosition((column - (COLUMNS - 1) / 2) * XSTEP, y)
        slot.top_align_tip = top - (YSTEP / 2 + y) + SLOT / 2 + 8
    end
    -- Controller action text sits above all rows, including when a main or
    -- equipped slot is selected. The original text/cursor machinery is reused.
    for _, list in ipairs({bar.inv, bar.equip}) do
        for _, slot in pairs(list) do
            slot.top_align_tip = top + YSTEP / 2 + SLOT / 2 + 8
        end
    end
    if bar.integrated_arrow ~= nil then bar.integrated_arrow:Hide() end
    for _, widget in ipairs({bar.hudcompass, bar.hand_inv}) do
        local position = widget:GetPosition()
        widget:SetPosition(position.x, position.y - YSTEP, position.z)
    end

    -- Stretch only the native panel, never the slot or item art. Its old lower
    -- cover would cross the extra rows, so hide it until the next rebuild.
    local bottom = -YSTEP / 2 - SLOT / 2 - 16
    local upper = top + SLOT / 2 + 16
    bar.bg:SetSize(width, upper - bottom)
    bar.bg:SetPosition(0, (upper + bottom) / 2)
    bar.bgcover:Hide()
    bar:UpdatePosition()
    bar:UpdateCursor()
end

function M.Install(bar)
    if bar._gb_inventory_layout_installed then return end
    bar._gb_inventory_layout_installed = true

    local rebuild = bar.Rebuild
    bar.Rebuild = function(self, ...)
        Restore(self)
        rebuild(self, ...)
        Apply(self)
    end

    local updateposition = bar.UpdatePosition
    bar.UpdatePosition = function(self, ...)
        updateposition(self, ...)
        local state = self._gb_inventory_layout
        if state ~= nil and self.autoanchor ~= nil and self:IsVisible() then
            local position = self.autoanchor:GetPosition()
            local _, yscale = self:GetLooseScale()
            self.autoanchor:SetPosition(position.x,
                position.y + state.anchor_extra * yscale, position.z)
        end
    end

    local closest = bar.GetClosestWidget
    bar.GetClosestWidget = function(self, lists, position, direction)
        local state = self._gb_inventory_layout
        local active = self.active_slot
        if state ~= nil and direction.y == 0 and direction.x ~= 0
            and active ~= nil and active.num ~= nil
            and self.backpackinv[active.num] == active then
            -- Vanilla left/right search accepts diagonal candidates. Restrict
            -- that search to the current visual row, keeping current_list as
            -- the original backpack list so the remaining controls still work.
            local first = math.floor((active.num - 1) / state.columns) * state.columns + 1
            local row = {}
            for index = first, math.min(first + state.columns - 1, #self.backpackinv) do
                row[#row + 1] = self.backpackinv[index]
            end
            local slot = closest(self, {row}, position, direction)
            return slot, slot ~= nil and self.backpackinv or nil
        end
        return closest(self, lists, position, direction)
    end
end

return M
