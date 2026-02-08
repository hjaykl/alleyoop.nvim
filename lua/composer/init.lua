local M = {}

local commands = require("composer.commands")
local chain = require("composer.chain")
local targets = require("composer.targets")
local history = require("composer.history")
local library = require("composer.library")
local builder = require("composer.builder")

---@class composer.Config
---@field commands? composer.Command[]
---@field targets? composer.Target[]
---@field default_target? string
---@field max_history? integer
---@field mappings? table<string, string|false>
---@field builder? composer.BuilderConfig

---@class composer.BuilderConfig
---@field width? number
---@field height? number

local defaults = {
  commands = {},
  targets = {},
  default_target = "clipboard",
  max_history = 50,
  mappings = {},
  builder = {
    width = 0.8,
    height = 0.6,
  },
}

--- Default mapping definitions.
--- Each entry: { key, mode, action_type, action_arg|nil, desc }
--- action_type: "copy", "chain", "fn"
--- For "copy"/"chain", action_arg is the command name.
--- For "fn", action_arg is the function to call.
local default_mappings = {
  copy_file              = { "<leader>af",  "n", "copy",  "file",             "Copy file ref" },
  copy_file_content      = { "<leader>aF",  "n", "copy",  "file_content",     "Copy file with content" },
  copy_line              = { "<leader>at",  "n", "copy",  "line",             "Copy line ref" },
  copy_range             = { "<leader>at",  "v", "copy",  "range",            "Copy range ref" },
  copy_range_content     = { "<leader>av",  "v", "copy",  "range_content",    "Copy range with content" },
  copy_line_diagnostics  = { "<leader>ad",  "n", "copy",  "line_diagnostics", "Copy line diagnostics" },
  copy_range_diagnostics = { "<leader>ad",  "v", "copy",  "range_diagnostics","Copy range with diagnostics" },
  copy_buf_diagnostics   = { "<leader>aD",  "n", "copy",  "buf_diagnostics",  "Copy buffer diagnostics" },
  copy_quickfix          = { "<leader>aq",  "n", "copy",  "quickfix",         "Copy quickfix list" },
  chain_file             = { "<leader>acf", "n", "chain", "file",             "Chain file ref" },
  chain_file_content     = { "<leader>acF", "n", "chain", "file_content",     "Chain file with content" },
  chain_line             = { "<leader>act", "n", "chain", "line",             "Chain line ref" },
  chain_range            = { "<leader>act", "v", "chain", "range",            "Chain range ref" },
  chain_range_content    = { "<leader>acv", "v", "chain", "range_content",    "Chain range with content" },
  chain_line_diagnostics = { "<leader>acd", "n", "chain", "line_diagnostics", "Chain line diagnostics" },
  chain_range_diagnostics= { "<leader>acd", "v", "chain", "range_diagnostics","Chain range with diagnostics" },
  chain_buf_diagnostics  = { "<leader>acD", "n", "chain", "buf_diagnostics",  "Chain buffer diagnostics" },
  chain_quickfix         = { "<leader>acq", "n", "chain", "quickfix",         "Chain quickfix list" },
  clear_chain            = { "<leader>ax",  "n", "fn",    nil,                "Clear chain" },
  open_builder           = { "<leader>ap",  "n", "fn",    nil,                "Open prompt builder" },
  set_target             = { "<leader>aT",  "n", "fn",    nil,                "Set default target" },
  browse_library         = { "<leader>al",  "n", "fn",    nil,                "Browse prompt library" },
  delete_library         = { "<leader>aL",  "n", "fn",    nil,                "Delete from library" },
}

--- Get the callback for a mapping action.
local function get_callback(mapping_name, action_type, action_arg)
  if action_type == "copy" then
    return function()
      M.copy_ref(action_arg)
    end
  elseif action_type == "chain" then
    return function()
      M.chain(action_arg)
    end
  elseif action_type == "fn" then
    if mapping_name == "clear_chain" then
      return function()
        M.clear_chain()
      end
    elseif mapping_name == "open_builder" then
      return function()
        M.open()
      end
    elseif mapping_name == "set_target" then
      return function()
        M.set_default_target()
      end
    elseif mapping_name == "browse_library" then
      return function()
        library.browse(function(content)
          chain.clear()
          chain.append(content)
          M.open()
        end)
      end
    elseif mapping_name == "delete_library" then
      return function()
        library.delete()
      end
    end
  end
end

--- Merge user config and initialize all modules.
---@param opts? composer.Config
function M.setup(opts)
  local config = vim.tbl_deep_extend("force", defaults, opts or {})

  -- Init modules
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
  return vim.api.nvim_buf_get_name(0):match("^composer://") ~= nil
end

--- Execute a command and append the result to the chain.
---@param cmd string
function M.chain(cmd)
  if in_builder() then
    return
  end
  local ref = commands.execute(cmd)
  if ref then
    chain.append(ref)
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

--- Clear the chain.
function M.clear_chain()
  chain.clear()
  vim.notify("Chain cleared", vim.log.levels.INFO)
end

--- Return a shallow copy of the chain.
---@return string[]
function M.get_chain()
  return chain.get()
end

--- Return the registered command list.
---@return composer.Command[]
function M.get_commands()
  return commands.list()
end

--- Return the registered target list.
---@return composer.Target[]
function M.get_targets()
  return targets.list()
end

--- Set default target by name. No arg opens picker.
---@param name? string
function M.set_default_target(name)
  targets.set_default(name)
end

return M
