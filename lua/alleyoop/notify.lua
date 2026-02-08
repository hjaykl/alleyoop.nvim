local M = {}

local config = { compose = true, dispatch = true, target = true, library = true }

--- Initialize notify config.
---@param opts table|false|nil
function M.init(opts)
  if opts == false then
    for k in pairs(config) do
      config[k] = false
    end
  elseif type(opts) == "table" then
    config = vim.tbl_extend("force", config, opts)
  end
end

--- Send an INFO notification if the category is enabled.
---@param category string
---@param msg string
function M.info(category, msg)
  if config[category] then
    vim.notify(msg, vim.log.levels.INFO)
  end
end

return M
