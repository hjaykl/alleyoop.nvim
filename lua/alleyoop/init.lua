local M = {}

local commands = require("alleyoop.commands")
local compose = require("alleyoop.compose")
local targets = require("alleyoop.targets")
local history = require("alleyoop.history")
local library = require("alleyoop.library")
local builder = require("alleyoop.builder")
local notify = require("alleyoop.notify")

---@class alleyoop.Config
---@field commands? alleyoop.Command[]
---@field targets? alleyoop.Target[]
---@field default_target? string
---@field max_history? integer
---@field mappings? table<string, string|false>
---@field notify? table|false
---@field builder? alleyoop.BuilderConfig

---@class alleyoop.BuilderConfig
---@field width? number
---@field height? number
---@field title? string|false

local defaults = {
  commands = {},
  targets = {},
  default_target = "clipboard",
  max_history = 50,
  mappings = {},
  notify = { compose = true, dispatch = true, target = true, library = true },
  builder = {
    width = 0.8,
    height = 0.6,
    title = "Alley-Oop",
  },
}

--- Default mapping definitions.
--- Each entry: { key, mode, action_type, action_arg|nil, desc }
--- action_type: "copy", "compose", "fn"
--- For "copy"/"compose", action_arg is the command name.
--- For "fn", action_arg is the function to call.
local default_mappings = {
  copy_file                = { "<leader>af",  "n", "copy",    "file",             "Copy file ref" },
  copy_file_content        = { "<leader>aF",  "n", "copy",    "file_content",     "Copy file with content" },
  copy_line                = { "<leader>at",  "n", "copy",    "line",             "Copy line ref" },
  copy_range               = { "<leader>at",  "v", "copy",    "range",            "Copy range ref" },
  copy_range_content       = { "<leader>av",  "v", "copy",    "range_content",    "Copy range with content" },
  copy_line_diagnostics    = { "<leader>ad",  "n", "copy",    "line_diagnostics", "Copy line diagnostics" },
  copy_range_diagnostics   = { "<leader>ad",  "v", "copy",    "range_diagnostics","Copy range with diagnostics" },
  copy_buf_diagnostics     = { "<leader>aD",  "n", "copy",    "buf_diagnostics",  "Copy buffer diagnostics" },
  copy_quickfix            = { "<leader>aq",  "n", "copy",    "quickfix",         "Copy quickfix list" },
  compose_file             = { "<leader>acf", "n", "compose", "file",             "Compose file ref" },
  compose_file_content     = { "<leader>acF", "n", "compose", "file_content",     "Compose file with content" },
  compose_line             = { "<leader>act", "n", "compose", "line",             "Compose line ref" },
  compose_range            = { "<leader>act", "v", "compose", "range",            "Compose range ref" },
  compose_range_content    = { "<leader>acv", "v", "compose", "range_content",    "Compose range with content" },
  compose_line_diagnostics = { "<leader>acd", "n", "compose", "line_diagnostics", "Compose line diagnostics" },
  compose_range_diagnostics= { "<leader>acd", "v", "compose", "range_diagnostics","Compose range with diagnostics" },
  compose_buf_diagnostics  = { "<leader>acD", "n", "compose", "buf_diagnostics",  "Compose buffer diagnostics" },
  compose_quickfix         = { "<leader>acq", "n", "compose", "quickfix",         "Compose quickfix list" },
  clear_compose            = { "<leader>ax",  "n", "fn",      nil,                "Clear compose" },
  open_builder             = { "<leader>ap",  "n", "fn",      nil,                "Open prompt builder" },
  set_target               = { "<leader>aT",  "n", "fn",      nil,                "Set default target" },
  browse_library           = { "<leader>al",  "n", "fn",      nil,                "Browse prompt library" },
  delete_library           = { "<leader>aL",  "n", "fn",      nil,                "Delete from library" },
}

--- Named function actions for "fn" type mappings.
local fn_actions = {
  clear_compose = function()
    M.clear_compose()
  end,
  open_builder = function()
    M.open()
  end,
  set_target = function()
    M.set_default_target()
  end,
  browse_library = function()
    library.browse(function(content)
      builder.close()
      compose.clear()
      compose.append(content)
      M.open()
    end)
  end,
  delete_library = function()
    library.delete()
  end,
}

--- Get the callback for a mapping action.
local function get_callback(mapping_name, action_type, action_arg)
  if action_type == "copy" then
    return function()
      M.copy_ref(action_arg)
    end
  elseif action_type == "compose" then
    return function()
      M.compose(action_arg)
    end
  elseif action_type == "fn" then
    return fn_actions[mapping_name]
  end
end

--- Merge user config and initialize all modules.
---@param opts? alleyoop.Config
function M.setup(opts)
  if vim.fn.has("nvim-0.10") == 0 then
    vim.notify("alleyoop.nvim requires Neovim >= 0.10", vim.log.levels.ERROR)
    return
  end

  opts = opts or {}
  vim.validate("opts", opts, "table")

  -- Extract notify before tbl_deep_extend (false is not a table)
  local notify_opts = opts.notify
  opts.notify = nil
  local config = vim.tbl_deep_extend("force", defaults, opts)

  -- Init modules
  notify.init(notify_opts)
  commands.register(commands.get_defaults(), config.commands)
  targets.register(config.targets, config.default_target)
  history.init(config.max_history)
  library.init()
  builder.init(config.builder)

  -- Register keymaps
  for name, def in pairs(default_mappings) do
    local lhs = def[1]
    local mode = def[2]

    -- User override
    if config.mappings[name] ~= nil then
      if config.mappings[name] == false then
        goto continue
      end
      lhs = config.mappings[name]
    end

    local callback = get_callback(name, def[3], def[4])
    if callback and mode == "v" then
      local inner = callback
      callback = function()
        inner()
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>`<", true, false, true), "nx", false)
      end
    end
    if callback then
      vim.keymap.set(mode, lhs, callback, { desc = def[5], silent = true })
    end

    ::continue::
  end
end

--- Open the prompt builder.
function M.open()
  builder.open()
end

local function in_builder()
  return vim.api.nvim_buf_get_name(0):match("^alleyoop://") ~= nil
end

--- Execute a command and append the result to the compose list.
---@param cmd string
function M.compose(cmd)
  if in_builder() then
    return
  end
  local ref = commands.execute(cmd)
  if ref then
    compose.append(ref)
  end
end

--- Execute a command and dispatch the result to the default target.
---@param cmd string
function M.copy_ref(cmd)
  if in_builder() then
    return
  end
  local ref = commands.execute(cmd)
  if ref then
    targets.dispatch_default(ref)
  end
end

--- Clear the compose list.
function M.clear_compose()
  compose.clear()
  notify.info("compose", "Compose cleared")
end

--- Return a shallow copy of the compose list.
---@return string[]
function M.get_compose()
  return compose.get()
end

--- Return the registered command list.
---@return alleyoop.Command[]
function M.get_commands()
  return commands.list()
end

--- Return the registered target list.
---@return alleyoop.Target[]
function M.get_targets()
  return targets.list()
end

--- Set default target by name. No arg opens picker.
---@param name? string
function M.set_default_target(name)
  targets.set_default(name)
end

--- Reset the cached tmux pane, prompting on next dispatch.
function M.reset_tmux_pane()
  targets.reset_tmux_pane()
end

return M
