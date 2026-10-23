-- All cells are visible. Retain the deployed module path.
local M = {}
local Widget = require("widgets/widget")
local Image = require("widgets/image")
function M.InstallContainer(widget)
    if widget._gb_rows_installed then return end
    widget._gb_rows_installed = true
    local close = widget.Close
    widget.Close = function(self, ...)
        if self._gb_bottom_edge then
            self._gb_bottom_edge:Kill()
            self._gb_bottom_edge = nil
        end
        return close(self, ...)
    end
    local open = widget.Open
    widget.Open = function(self, container, ...)
        if self._gb_custom_background then
            self:Close()
            self.bgimage.texture = nil
            self.bgimage:Hide()
            self.bgimage:SetPosition(0, 0, 0)
            self._gb_custom_background = nil
        end
        open(self, container, ...)
        local definition = container.replica.container:GetWidget()
        if definition.gb_rows ~= nil then
            self._gb_custom_background = true
            self.bganim:Hide()
            local width, height = definition.gb_columns * 80 + 48, definition.gb_rows * 76 + 46
            self.bgimage:SetSize(width, height)
            self.bgimage:SetPosition(-50 - (definition.gb_columns - 1) * 40,
                -(definition.gb_rows - 1) * 38, 0)
            -- The native HUD texture has an open bottom hidden below the
            -- screen. Mirror its top trim for an enclosed standalone window.
            local clip = self.bgimage:AddChild(Widget("gb_bottom_edge"))
            clip:SetScissor(-width / 2, -height / 2, width, height / 2)
            local edge = clip:AddChild(Image("images/hud.xml", "inventory_bg.tex"))
            edge:SetSize(width, height)
            edge:SetScale(1, -1, 1)
            edge:SetClickable(false)
            self._gb_bottom_edge = clip
        else
            self.bganim:Show()
        end
    end
end
return M
