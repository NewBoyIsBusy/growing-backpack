local M = {}

function M.ClampLevel(value)
    return math.max(0, math.min(3, math.floor(tonumber(value) or 0)))
end

function M.Slots(level)
    return ({8, 15, 23, 30})[M.ClampLevel(level) + 1]
end

function M.Make(level, Vector3)
    local count = M.Slots(level)
    local widget = {
        slotpos = {},
        bgatlas = "images/hud.xml", bgimage = "inventory_bg.tex",
        pos = Vector3(-20, -190, 0),
        gb_rows = math.ceil(count / 15), gb_columns = math.min(count, 15),
    }
    for index = 0, count - 1 do
        local row, col = math.floor(index / 15), index % 15
        local rowcount = math.min(15, count - row * 15)
        widget.slotpos[#widget.slotpos + 1] = Vector3(-50 - (rowcount - 1 - col) * 80, -row * 76, 0)
    end
    return {widget = widget, issidewidget = true, type = "pack", openlimit = 1}
end
return M
