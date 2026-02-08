local M = {}

---@type string[]
local entries = {}

---@type string
local history_dir = ""

---@type integer
local max_entries = 50

local function read_file(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local content = f:read("*a")
  f:close()
  return content
end

local function write_file(path, content)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local f = io.open(path, "w")
  if not f then
    return
  end
  f:write(content)
  f:close()
end

local function get_history_files()
  if vim.fn.isdirectory(history_dir) == 0 then
    return {}
  end
  local files = vim.fn.glob(history_dir .. "/*.md", false, true)
  table.sort(files)
  return files
end

--- Initialize history. Loads all entries from disk.
---@param max_history integer
function M.init(max_history)
  max_entries = max_history
  history_dir = vim.fn.stdpath("data") .. "/alleyoop/history"
  entries = {}
  local files = get_history_files()
  for _, file in ipairs(files) do
    local content = read_file(file)
    if content then
      table.insert(entries, content)
    end
  end
end

--- Save content to history. Appends to memory and disk, prunes if over max.
---@param content string
function M.save(content)
  vim.fn.mkdir(history_dir, "p")
  local base = os.date("%Y%m%d-%H%M%S")
  local path = history_dir .. "/" .. base .. ".md"
  -- Disambiguate if file already exists (rapid saves within same second)
  local suffix = 1
  while vim.fn.filereadable(path) == 1 do
    path = history_dir .. "/" .. base .. "-" .. suffix .. ".md"
    suffix = suffix + 1
  end
  write_file(path, content)
  table.insert(entries, content)
  -- Prune oldest entries
  local files = get_history_files()
  while #files > max_entries do
    os.remove(files[1])
    table.remove(files, 1)
  end
  while #entries > max_entries do
    table.remove(entries, 1)
  end
end

--- Return all history entries (oldest first).
---@return string[]
function M.get_entries()
  return entries
end

--- Return number of history entries.
---@return integer
function M.count()
  return #entries
end

return M
