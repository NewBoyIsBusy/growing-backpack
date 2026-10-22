local upgrade = require("gb_upgrade_action")
local M = {}

function M.Collect(action, inst, doer, target, actions)
    upgrade.Collect(action, inst, doer, target, actions, "gb_foodmodule_kit")
end

function M.Perform(act)
    return upgrade.Perform(act, "gb_foodmodule_kit")
end

return M
