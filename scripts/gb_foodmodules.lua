local M = {}

M.KITS = {
    gb_preservation_kit = { key = "preservation", level = 2, name = "保鲜插件" },
    gb_freshness_kit = { key = "freshness", level = 3, name = "返鲜插件" },
}

-- Express the requested strength as 75% of the icebox's reduction in spoilage.
-- Vanilla icebox 0.5 => 0.625 spoilage speed, not 0.375 or 0.75.
function M.PreservationRate()
    return 1 - (1 - TUNING.PERISH_FRIDGE_MULT) * .75
end

function M.IsFood(item)
    return item ~= nil and item.components.edible ~= nil
        and item.components.perishable ~= nil
        and item.components.perishable.perishtime ~= nil
        and item.components.perishable.perishtime > 0
        and item.components.perishable.perishremainingtime ~= nil
        and item.components.perishable.perishremainingtime > 0
        and item.prefab ~= "spoiled_food" and item.prefab ~= "rottenegg"
        and item.prefab ~= "spoiled_fish" and item.prefab ~= "spoiled_fish_small"
end

function M.NameSuffix(flags)
    if flags == 3 then return " · 保鲜+返鲜" end
    if flags == 2 then return " · 返鲜" end
    if flags == 1 then return " · 保鲜" end
    return ""
end

function M.Description(flags)
    if flags == 3 then
        return "已安装保鲜和返鲜插件，返鲜优先生效：食物停止腐败，每游戏日恢复25%新鲜度。"
    elseif flags == 2 then
        return "已安装返鲜插件：食物停止腐败，每游戏日恢复25%新鲜度。"
    elseif flags == 1 then
        return "已安装保鲜插件：保鲜强度为冰箱的75%，常温干燥下腐败速度为原来的62.5%。"
    end
    return "机械包可安装保鲜插件，远古包可独立安装返鲜插件。"
end

return M
