local M = {}

--- Thin wrapper around vim.ui.select.
--- Single swap point if user wants telescope/mini.pick later.
---@param items any[]
---@param opts table
---@param on_choice fun(item: any, idx: integer|nil)
function M.select(items, opts, on_choice)
  vim.ui.select(items, opts, on_choice)
end

return M
