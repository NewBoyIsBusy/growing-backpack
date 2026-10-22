-- Shared client-only paging. The historical filename is retained so deployed
-- mods replace the previous panel hook without leaving another module behind.
local Widget = require("widgets/widget")
local Text = require("widgets/text")
local ImageButton = require("widgets/imagebutton")
local M = {PAGE_SIZE = 8}
local remembered = setmetatable({}, {__mode = "k"})

local function RestoreTileAnimation(tile)
    if tile._gb_hidden_stack_animation then
        tile.ignore_stacksize_anim = tile._gb_saved_stack_animation
        tile._gb_hidden_stack_animation = nil
        tile._gb_saved_stack_animation = nil
    end
end

local function UpdateTileAnimation(slot)
    local tile = slot.tile
    if tile == nil then return end
    if slot._gb_page_state ~= nil and not slot.shown then
        if not tile._gb_hidden_stack_animation then
            tile._gb_saved_stack_animation = tile.ignore_stacksize_anim
            tile._gb_hidden_stack_animation = true
        end
        -- ItemTile independently listens for stacksizechange and can make an
        -- unparented fly-in image. Suppress that path while this page is hidden.
        tile.ignore_stacksize_anim = true
        if tile.movinganim ~= nil then
            tile.movinganim:Kill()
            tile.movinganim = nil
            local stack = tile.item.replica.stackable
            if stack ~= nil then tile:SetQuantity(stack:StackSize()) end
        end
    else
        RestoreTileAnimation(tile)
    end
end

local function TrackTile(slot)
    local tile = slot.tile
    if tile ~= nil and tile._gb_original_refresh == nil then
        local refresh = tile.Refresh
        tile._gb_original_refresh = refresh
        tile.Refresh = function(self, ...)
            RestoreTileAnimation(self)
            refresh(self, ...)
            -- Native Refresh resets ignore_stacksize_anim. Reapply it only to
            -- a hidden, paged slot; normal items keep the original behavior.
            if self.parent ~= nil then UpdateTileAnimation(self.parent) end
        end
    end
    UpdateTileAnimation(slot)
end

function M.AfterItemGet(slot)
    if slot ~= nil and slot._gb_page_state ~= nil then
        local tile = slot.tile
        if tile ~= nil then
            -- Native OnItemGet assigns its animation flag after SetTile.
            -- Preserve that new value as the normal visible-page behavior.
            tile._gb_hidden_stack_animation = nil
            tile._gb_saved_stack_animation = nil
        end
        TrackTile(slot)
    end
end

local function GetInventoryBar(owner)
    return owner ~= nil and owner.HUD ~= nil and owner.HUD.controls ~= nil
        and owner.HUD.controls.inv or nil
end

local function CreateArrow(parent, direction, onclick)
    local side = direction < 0 and "left" or "right"
    local button = parent:AddChild(ImageButton("images/ui.xml",
        "arrow2_" .. side .. ".tex", "arrow2_" .. side .. "_over.tex",
        "arrow_" .. side .. "_disabled.tex", "arrow2_" .. side .. "_down.tex"))
    button:ForceImageSize(28, 32)
    button:SetControl(CONTROL_PRIMARY)
    button:SetOnClick(onclick)
    button:SetPosition(direction * 48, 0, 0)
    return button
end

function M.Create(parent, slots, pack, owner, columns, x, y)
    if #slots <= M.PAGE_SIZE then return nil end
    local state = {slots = slots, pack = pack, owner = owner,
        columns = columns, pages = math.ceil(#slots / M.PAGE_SIZE)}
    state.root = parent:AddChild(Widget("growing_backpack_pages"))
    state.root:SetPosition(x, y, 0)
    state.label = state.root:AddChild(Text(NEWFONT_OUTLINE, 30))
    state.label:SetColour(204/255, 180/255, 154/255, 1)
    state.left = CreateArrow(state.root, -1, function() state:SetPage(state.page - 1) end)
    state.right = CreateArrow(state.root, 1, function() state:SetPage(state.page + 1) end)

    function state:SetPage(page, defer_selection)
        if self.closed then return end
        page = math.max(1, math.min(self.pages, math.floor(page)))
        if page == self.page then return end
        self.page = page
        remembered[self.pack] = page
        local first = (page - 1) * M.PAGE_SIZE + 1
        local last = math.min(first + M.PAGE_SIZE - 1, #self.slots)
        for index, slot in ipairs(self.slots) do
            if index >= first and index <= last then
                slot:Show()
            else
                slot:ClearFocus()
                slot:Hide()
            end
            UpdateTileAnimation(slot)
        end
        self.label:SetString(page .. "/" .. self.pages)
        if page > 1 then self.left:Enable() else self.left:Disable() end
        if page < self.pages then self.right:Enable() else self.right:Disable() end

        -- Mouse buttons can also page while a controller cursor is present.
        local bar = GetInventoryBar(self.owner)
        local active = bar ~= nil and bar.active_slot or nil
        if not defer_selection and active ~= nil and active._gb_page_state == self
            and not active.shown then
            local index = math.min(first + (active.num - 1) % M.PAGE_SIZE, last)
            bar.current_list = self.slots
            bar:SelectSlot(self.slots[index])
            bar:UpdateCursor()
        end
    end

    for _, slot in ipairs(slots) do
        slot._gb_page_state = state
        local settile = slot.SetTile
        slot._gb_original_settile = settile
        slot.SetTile = function(self, ...)
            settile(self, ...)
            TrackTile(self)
        end
        TrackTile(slot)
    end
    state:SetPage(remembered[pack] or 1, true)
    return state
end

function M.Destroy(state)
    if state == nil or state.closed then return end
    state.closed = true
    for _, slot in ipairs(state.slots) do
        slot._gb_page_state = nil
        slot.SetTile = slot._gb_original_settile
        slot._gb_original_settile = nil
        if slot.tile ~= nil then
            RestoreTileAnimation(slot.tile)
            if slot.tile._gb_original_refresh ~= nil then
                slot.tile.Refresh = slot.tile._gb_original_refresh
                slot.tile._gb_original_refresh = nil
            end
        end
    end
    if state.root.inst:IsValid() then state.root:Kill() end
end

function M.InstallContainer(widget)
    if widget._gb_paging_installed then return end
    widget._gb_paging_installed = true

    local close = widget.Close
    widget.Close = function(self, ...)
        M.Destroy(self._gb_pack_panel)
        self._gb_pack_panel = nil
        return close(self, ...)
    end

    local open = widget.Open
    widget.Open = function(self, container, ...)
        open(self, container, ...)
        local definition = container.replica.container:GetWidget()
        if definition.gb_paged_backpack then
            -- Keep the game's unscaled 2x4 frame and open/close animations.
            self._gb_pack_panel = M.Create(self, self.inv, container, self.owner,
                2, -124.5, -195)
        end
    end

    local onitemget = widget.OnItemGet
    widget.OnItemGet = function(self, data, ...)
        local slot = data.slot ~= nil and self.inv[data.slot] or nil
        if slot ~= nil and slot._gb_page_state ~= nil and not slot.shown
            and data.src_pos ~= nil then
            local localdata = {}
            for key, value in pairs(data) do localdata[key] = value end
            localdata.src_pos = nil
            onitemget(self, localdata, ...)
        else
            onitemget(self, data, ...)
        end
        M.AfterItemGet(slot)
    end
end

return M
