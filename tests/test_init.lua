local new_set = MiniTest.new_set
local expect = MiniTest.expect

local T = new_set()

T["setup"] = new_set({
  hooks = {
    pre_case = function()
      -- Reset all modules
      for key in pairs(package.loaded) do
        if key:match("^composer") then
          package.loaded[key] = nil
        end
      end

      -- Use temp dir for isolation
      local test_dir = vim.fn.tempname() .. "/composer_test_init"
      vim.fn.mkdir(test_dir, "p")
      local orig_stdpath = vim.fn.stdpath
      vim.fn.stdpath = function(what)
        if what == "data" then
          return test_dir
        end
        return orig_stdpath(what)
      end
    end,
  },
})

T["setup"]["setup without error"] = function()
  local composer = require("composer")
  composer.setup()
end

T["setup"]["setup with empty opts"] = function()
  local composer = require("composer")
  composer.setup({})
end

T["setup"]["setup with custom config"] = function()
  local composer = require("composer")
  composer.setup({
    max_history = 100,
    default_target = "clipboard",
    builder = { width = 0.9, height = 0.7 },
  })
end

T["setup"]["disabled mapping is not set"] = function()
  local composer = require("composer")
  composer.setup({ mappings = { copy_quickfix = false } })

  -- Verify the default mapping for copy_quickfix doesn't exist
  local maps = vim.api.nvim_get_keymap("n")
  local found = false
  for _, m in ipairs(maps) do
    if m.lhs == " aq" and m.desc == "Copy quickfix list" then
      found = true
      break
    end
  end
  expect.equality(found, false)
end

T["setup"]["public API functions exist"] = function()
  local composer = require("composer")
  composer.setup()

  expect.equality(type(composer.open), "function")
  expect.equality(type(composer.chain), "function")
  expect.equality(type(composer.copy_ref), "function")
  expect.equality(type(composer.clear_chain), "function")
  expect.equality(type(composer.get_chain), "function")
  expect.equality(type(composer.get_commands), "function")
  expect.equality(type(composer.get_targets), "function")
  expect.equality(type(composer.set_default_target), "function")
end

T["setup"]["get_commands returns registered commands"] = function()
  local composer = require("composer")
  composer.setup()

  local cmds = composer.get_commands()
  expect.equality(#cmds >= 7, true)
end

T["setup"]["get_targets returns registered targets"] = function()
  local composer = require("composer")
  composer.setup()

  local tgts = composer.get_targets()
  expect.equality(#tgts >= 2, true)
end

T["setup"]["get_chain returns empty on start"] = function()
  local composer = require("composer")
  composer.setup()

  expect.equality(composer.get_chain(), {})
end

return T
