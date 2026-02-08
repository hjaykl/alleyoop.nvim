local new_set = MiniTest.new_set
local expect = MiniTest.expect

local T = new_set()

local targets

T["setup"] = new_set({
  hooks = {
    pre_case = function()
      package.loaded["alleyoop.targets"] = nil
      package.loaded["alleyoop.picker"] = nil
      targets = require("alleyoop.targets")
      targets.register({}, nil)
    end,
  },
})

T["setup"]["register creates clipboard and tmux targets"] = function()
  expect.no_equality(targets.get("clipboard"), nil)
  expect.no_equality(targets.get("tmux"), nil)
end

T["setup"]["register sets default to clipboard"] = function()
  expect.equality(targets.get_default_name(), "clipboard")
end

T["setup"]["register with custom default"] = function()
  targets.register({}, "tmux")
  expect.equality(targets.get_default_name(), "tmux")
end

T["setup"]["register merges user targets"] = function()
  local user = {
    { name = "custom", fn = function() end },
  }
  targets.register(user, nil)
  expect.no_equality(targets.get("custom"), nil)
  -- Built-ins still there
  expect.no_equality(targets.get("clipboard"), nil)
end

T["setup"]["register overrides by name"] = function()
  local called = false
  local user = {
    { name = "clipboard", fn = function() called = true end },
  }
  targets.register(user, nil)
  targets.get("clipboard").fn("test")
  expect.equality(called, true)
end

T["setup"]["dispatch clipboard sets + register"] = function()
  targets.dispatch("clipboard", "test prompt")
  expect.equality(vim.fn.getreg("+"), "test prompt")
end

T["setup"]["dispatch_default uses default target"] = function()
  targets.dispatch_default("default prompt")
  expect.equality(vim.fn.getreg("+"), "default prompt")
end

T["setup"]["dispatch unknown target notifies error"] = function()
  -- Should not error, just notify
  targets.dispatch("nonexistent", "test")
end

T["setup"]["set_default with name updates default"] = function()
  targets.set_default("tmux")
  expect.equality(targets.get_default_name(), "tmux")
end

T["setup"]["list returns sorted targets"] = function()
  local list = targets.list()
  expect.equality(#list >= 2, true)
  for i = 2, #list do
    expect.equality(list[i - 1].name < list[i].name, true)
  end
end

T["setup"]["get returns nil for unknown"] = function()
  expect.equality(targets.get("nonexistent"), nil)
end

T["setup"]["throwing target does not propagate error"] = function()
  local user = {
    { name = "broken", fn = function() error("kaboom") end },
  }
  targets.register(user, "broken")
  -- Should not error, just notify
  targets.dispatch("broken", "test prompt")
end

T["setup"]["reset_tmux_pane is callable"] = function()
  -- Should not error
  targets.reset_tmux_pane()
end

return T
