local M = {}

function M.ClampLevel(value)
    return math.max(0, math.min(3, math.floor(tonumber(value) or 0)))
end

function M.Slots(level)
    return 8 * (M.ClampLevel(level) + 1)
end

function M.Make(level, Vector3)
    local count = M.Slots(level)
    -- Keep side panels four rows high as capacity grows, rather than doubling
    -- their height into the inventory/tooltips at the bottom of the screen.
    local cols = count / 4
    local rows = count / cols
    local widget = {
        slotpos = {},
        animbank = "ui_backpack_2x4",
        animbuild = "ui_backpack_2x4",
        pos = Vector3(-5, -80, 0),
        -- A client widget hook replaces the stock 2x4 animation with an actual
        -- nine-slice frame; widening a 2x4 bitmap also widened its wooden posts.
        gb_pack_panel = {columns = cols, rows = rows,
            x = -87 - (cols - 1) * 37.5, y = 1.5},
    }
    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            widget.slotpos[#widget.slotpos + 1] = Vector3(-87 - (cols - 1 - col) * 75, (rows - 1) * 37.5 - row * 75 + 1.5, 0)
        end
    end
    return { widget = widget, issidewidget = true, type = "pack", openlimit = 1 }
end

return M
