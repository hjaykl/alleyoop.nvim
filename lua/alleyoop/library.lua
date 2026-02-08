local M = {}

local notify = require("alleyoop.notify")

---@type string
local global_dir = ""

---@class alleyoop.LibraryItem
---@field name string
---@field path string
---@field scope string

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

local function get_project_dir()
  local root = vim.fs.root(0, { ".alleyoop" })
  if root then
    return root .. "/.alleyoop"
  end
  return nil
end

local function glob_md(dir)
  if vim.fn.isdirectory(dir) == 0 then
    return {}
  end
  return vim.fn.glob(dir .. "/**/*.md", false, true)
end

--- Initialize library with global directory path.
function M.init()
  global_dir = vim.fn.stdpath("data") .. "/alleyoop/library"
end

--- Get all library items sorted: project first, then alpha.
---@return alleyoop.LibraryItem[]
function M.get_items()
  local items = {}

  -- Project items
  local project_dir = get_project_dir()
  if project_dir then
    for _, path in ipairs(glob_md(project_dir)) do
      local name = path:sub(#project_dir + 2):gsub("%.md$", "")
      table.insert(items, { name = name, path = path, scope = "project" })
    end
  end

  -- Global items
  for _, path in ipairs(glob_md(global_dir)) do
    local name = path:sub(#global_dir + 2):gsub("%.md$", "")
    table.insert(items, { name = name, path = path, scope = "global" })
  end

  table.sort(items, function(a, b)
    if a.scope ~= b.scope then
      return a.scope == "project"
    end
    return a.name < b.name
  end)

  return items
end

--- Browse library items with picker. Callback receives file content.
---@param callback fun(content: string)
function M.browse(callback)
  local items = M.get_items()
  if #items == 0 then
    vim.notify("Library is empty", vim.log.levels.WARN)
    return
  end

  local display = vim.tbl_map(function(item)
    if item.scope == "project" then
      return "[project] " .. item.name
    end
    return item.name
  end, items)

  vim.ui.select(display, { prompt = "Prompt Library:" }, function(_, idx)
    if not idx then
      return
    end
    local item = items[idx]
    local content = read_file(item.path)
    if content then
      callback(content)
    end
  end)
end

--- Delete a library item via picker.
function M.delete()
  local items = M.get_items()
  if #items == 0 then
    vim.notify("Library is empty", vim.log.levels.WARN)
    return
  end

  local display = vim.tbl_map(function(item)
    if item.scope == "project" then
      return "[project] " .. item.name
    end
    return item.name
  end, items)

  vim.ui.select(display, { prompt = "Delete from library:" }, function(_, idx)
    if not idx then
      return
    end
    local item = items[idx]
    os.remove(item.path)
    notify.info("library", "Deleted: " .. item.name)
  end)
end

--- Save content to library. Prompts for name and scope.
---@param content string
function M.save(content)
  local project_dir = get_project_dir()

  local function do_save(dir, scope)
    vim.ui.input({ prompt = "Prompt name: " }, function(name)
      if not name or name == "" then
        return
      end
      write_file(dir .. "/" .. name .. ".md", content)
      notify.info("library", "Saved to " .. scope .. " library: " .. name)
    end)
  end

  if project_dir then
    vim.ui.select({ "Project (.alleyoop/)", "Global" }, { prompt = "Save to:" }, function(choice)
      if not choice then
        return
      end
      if choice:match("^Project") then
        do_save(project_dir, "project")
      else
        do_save(global_dir, "global")
      end
    end)
  else
    do_save(global_dir, "global")
  end
end

return M
