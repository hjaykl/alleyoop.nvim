local M = {}

local notify = require("alleyoop.notify")

---@class alleyoop.Target
---@field name string
---@field fn fun(prompt: string)

---@type table<string, alleyoop.Target>
local registry = {}

---@type string|nil
local default_name = nil

---@type string|nil
local tmux_pane = nil

--- Return the 2 built-in targets.
---@return alleyoop.Target[]
local function get_builtins()
  return {
    {
      name = "clipboard",
      fn = function(prompt)
        vim.fn.setreg("+", prompt)
        notify.info("dispatch", "Prompt copied to clipboard")
      end,
    },
    {
      name = "tmux",
      fn = function(prompt)
        if vim.fn.executable("tmux") ~= 1 then
          vim.notify("tmux is not available", vim.log.levels.ERROR)
          return
        end

        local function send(pane)
          vim.fn.system({ "tmux", "load-buffer", "-" }, prompt)
          vim.fn.system({ "tmux", "paste-buffer", "-t", pane })
          notify.info("dispatch", "Sent to tmux pane: " .. pane)
        end

        if tmux_pane then
          send(tmux_pane)
        else
          vim.ui.input({ prompt = "Tmux target pane: " }, function(pane)
            if not pane or pane == "" then
              return
            end
            tmux_pane = pane
            send(pane)
          end)
        end
      end,
    },
  }
end

--- Register targets. User targets with the same name override built-ins.
---@param user_targets alleyoop.Target[]
---@param default string|nil
function M.register(user_targets, default)
  registry = {}
  for _, target in ipairs(get_builtins()) do
    registry[target.name] = target
  end
  for _, target in ipairs(user_targets) do
    registry[target.name] = target
  end
  default_name = default or "clipboard"
end

--- Dispatch prompt to a named target.
---@param name string
---@param prompt string
function M.dispatch(name, prompt)
  local target = registry[name]
  if not target then
    vim.notify("Unknown target: " .. name, vim.log.levels.ERROR)
    return
  end
  local ok, err = pcall(target.fn, prompt)
  if not ok then
    vim.notify("Target '" .. name .. "' failed: " .. tostring(err), vim.log.levels.ERROR)
  end
end

--- Dispatch prompt to the default target.
---@param prompt string
function M.dispatch_default(prompt)
  M.dispatch(default_name, prompt)
end

--- Set the default target by name. nil triggers picker.
---@param name string|nil
function M.set_default(name)
  if name then
    if not registry[name] then
      vim.notify("Unknown target: " .. name, vim.log.levels.ERROR)
      return
    end
    default_name = name
    notify.info("target", "Default target: " .. name)
    return
  end

  local picker = require("alleyoop.picker")
  local items = M.list()
  local names = vim.tbl_map(function(t)
    return t.name
  end, items)

  picker.select(names, { prompt = "Default target:" }, function(choice)
    if choice then
      default_name = choice
      notify.info("target", "Default target: " .. choice)
    end
  end)
end

--- Get the current default target name.
---@return string
function M.get_default_name()
  return default_name
end

--- Get a target by name.
---@param name string
---@return alleyoop.Target|nil
function M.get(name)
  return registry[name]
end

--- List all registered targets.
---@return alleyoop.Target[]
function M.list()
  local result = {}
  for _, target in pairs(registry) do
    table.insert(result, target)
  end
  table.sort(result, function(a, b)
    return a.name < b.name
  end)
  return result
end

return M
