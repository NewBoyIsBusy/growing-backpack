-- Keep native events, controls and real slot numbers; all cells stay visible.
local M = {}
local function Apply(bar)
    local pack = bar.backpack
    local mode = TheNet:GetServerGameMode()
    local count = #bar.backpackinv
    if not bar.integrated_backpack or pack == nil or not pack:HasTag("gb_growing_backpack")
        or mode == "quagmire" or mode == "lavaarena" or count <= 15 or #bar.inv < 15 then return end
    -- Main inventory above both backpack rows; the lowest row stays on screen.
    bar.toprow:SetPosition(0, 114, 0)
    bar.bottomrow:SetPosition(0, 38, 0)
    local sx, sy, sz = bar.bg:GetLooseScale()
    local _, height = bar.bg:GetSize()
    bar.bg:SetScale(sx, sy + 76 / height, sz)
    bar.bg:SetPosition(0, 14, 0)
    for index, slot in ipairs(bar.backpackinv) do
        local row = math.floor((index - 1) / 15)
        local rowcount = math.min(15, count - row * 15)
        local column = (index - 1) % 15 + 1
        local reference = bar.inv[#bar.inv - rowcount + column]
        slot:SetPosition(reference:GetPosition().x, -row * 76, 0)
        slot.top_align_tip = slot.top_align_tip + row * 76
    end
    bar._gb_extra_row = true
    bar:UpdatePosition()
    bar:UpdateCursor()
end
function M.Install(bar)
    if bar._gb_rows_installed then return end
    bar._gb_rows_installed = true
    local rebuild = bar.Rebuild
    bar.Rebuild = function(self, ...)
        self._gb_extra_row = nil
        rebuild(self, ...)
        Apply(self)
    end
    local position = bar.UpdatePosition
    bar.UpdatePosition = function(self, ...)
        position(self, ...)
        if self._gb_extra_row and self:IsVisible() then
            local p = self.autoanchor:GetPosition()
            self.autoanchor:SetPosition(p.x, p.y + 76, p.z)
        end
    end
end
return M
