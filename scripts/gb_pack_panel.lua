-- Use the game's nine-slice frame: corners keep their shape while the fill and
-- straight edges fit the slot grid. Both inventory display modes share it.
local NineSlice = require("widgets/nineslice")
local M = {}
local SLOT = 68
local PADDING = 8

function M.Create(parent, columns, rows, xstep, ystep)
    local panel = parent:AddChild(NineSlice("images/dialogrect_9slice.xml"))
    panel:SetSize((columns - 1) * xstep + SLOT + PADDING * 2,
        (rows - 1) * ystep + SLOT + PADDING * 2)
    -- NineSlice:SetScale adjusts border thickness only; it does not squash the
    -- content or enlarge corner ornaments as the number of columns changes.
    panel:SetScale(.35, .35)
    -- These three atlas entries are white tintable fill, as in the game's
    -- RectangleWindow template. Keep the gold corners and horizontal edges.
    local r, g, b = unpack(UICOLOURS.BROWN_DARK)
    panel.mid_center:SetTint(r, g, b, .92)
    panel.elements[4]:SetTint(r, g, b, .92)
    panel.elements[5]:SetTint(r, g, b, .92)
    panel:MoveToBack()
    return panel
end

function M.InstallContainer(widget)
    local close = widget.Close
    widget.Close = function(self, ...)
        if self._gb_pack_panel ~= nil then
            self._gb_pack_panel:Kill()
            self._gb_pack_panel = nil
        end
        -- Native ContainerWidget reuses these widgets for subsequent opens.
        self.bganim:Show()
        return close(self, ...)
    end

    local open = widget.Open
    widget.Open = function(self, container, ...)
        open(self, container, ...)
        local definition = container.replica.container:GetWidget()
        local layout = definition.gb_pack_panel
        if layout ~= nil then
            self.bganim:Hide()
            self.bgimage:Hide()
            self._gb_pack_panel = M.Create(self, layout.columns, layout.rows, 75, 75)
            self._gb_pack_panel:SetPosition(layout.x, layout.y)
        end
    end
end

return M
