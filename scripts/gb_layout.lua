local M = {}

function M.ClampLevel(value)
    return math.max(0, math.min(3, math.floor(tonumber(value) or 0)))
end

function M.Slots(level)
    return 8 * (M.ClampLevel(level) + 1)
end

function M.Make(level, Vector3)
    local count = M.Slots(level)
    local widget = {
        slotpos = {},
        animbank = "ui_backpack_2x4",
        animbuild = "ui_backpack_2x4",
        pos = Vector3(-5, -80, 0),
        gb_paged_backpack = true,
    }
    -- Keep every real slot in the definition so network/storage capacity stays
    -- unchanged. Each eight slots use the vanilla 2x4 page coordinates.
    for index = 0, count - 1 do
        local cell = index % 8
        widget.slotpos[#widget.slotpos + 1] = Vector3(-162 + (cell % 2) * 75,
            114 - math.floor(cell / 2) * 75, 0)
    end
    return { widget = widget, issidewidget = true, type = "pack", openlimit = 1 }
end

return M
