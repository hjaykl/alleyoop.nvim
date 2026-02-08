local M = {}

---@type string[]
local chain = {}

--- Append a ref to the chain and notify.
---@param ref string
function M.append(ref)
  table.insert(chain, ref)
  vim.notify("Chain (" .. #chain .. "): " .. ref:sub(1, 60), vim.log.levels.INFO)
end

--- Clear the chain.
function M.clear()
  chain = {}
end

--- Return a shallow copy of the chain.
---@return string[]
function M.get()
  return { unpack(chain) }
end

--- Return chain entries joined by double newlines, or empty string.
---@return string
function M.content()
  if #chain == 0 then
    return ""
  end
  return table.concat(chain, "\n\n")
end

--- Check if the chain is empty.
---@return boolean
function M.is_empty()
  return #chain == 0
end

return M
