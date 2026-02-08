local M = {}

local notify = require("alleyoop.notify")

---@type string[]
local items = {}

--- Append a ref to the compose list and notify.
---@param ref string
function M.append(ref)
  table.insert(items, ref)
  notify.info("compose", "Compose (" .. #items .. "): " .. ref:sub(1, 60))
end

--- Clear the compose list.
function M.clear()
  items = {}
end

--- Return a shallow copy of the compose list.
---@return string[]
function M.get()
  return { unpack(items) }
end

--- Return compose entries joined by double newlines, or empty string.
---@return string
function M.content()
  if #items == 0 then
    return ""
  end
  return table.concat(items, "\n\n")
end

--- Check if the compose list is empty.
---@return boolean
function M.is_empty()
  return #items == 0
end

return M
