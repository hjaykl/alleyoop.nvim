local new_set = MiniTest.new_set
local expect = MiniTest.expect

local T = new_set()

local commands

T["setup"] = new_set({
  hooks = {
    pre_case = function()
      package.loaded["alleyoop.commands"] = nil
      commands = require("alleyoop.commands")
      commands.register(commands.get_defaults(), {})
    end,
  },
})

T["setup"]["get_defaults returns 9 commands"] = function()
  local defaults = commands.get_defaults()
  expect.equality(#defaults, 9)
end

T["setup"]["register merges user commands"] = function()
  local user = {
    { name = "custom", modes = { "n" }, fn = function() return "custom" end },
  }
  commands.register(commands.get_defaults(), user)
  expect.no_equality(commands.get("custom"), nil)
end

T["setup"]["register overrides by name"] = function()
  local user = {
    { name = "file", modes = { "n" }, fn = function() return "overridden" end },
  }
  commands.register(commands.get_defaults(), user)
  -- Execute in a child to get a real buffer
  local cmd = commands.get("file")
  expect.no_equality(cmd, nil)
  -- Verify the override was applied by checking the fn returns "overridden"
  local result = cmd.fn({ filepath = "/test", filetype = "lua", line = 1, diagnostics = {}, qf_list = {} })
  expect.equality(result, "overridden")
end

T["setup"]["get returns nil for unknown"] = function()
  expect.equality(commands.get("nonexistent"), nil)
end

T["setup"]["list returns sorted commands"] = function()
  local list = commands.list()
  expect.equality(#list >= 7, true)
  -- Verify sorted by name
  for i = 2, #list do
    expect.equality(list[i - 1].name < list[i].name, true)
  end
end

T["setup"]["execute returns nil for unknown command"] = function()
  local result = commands.execute("nonexistent")
  expect.equality(result, nil)
end

T["setup"]["build_context returns correct fields"] = function()
  local ctx = commands.build_context()
  expect.equality(type(ctx.filepath), "string")
  expect.equality(type(ctx.filetype), "string")
  expect.equality(type(ctx.line), "number")
  expect.equality(type(ctx.diagnostics), "table")
  expect.equality(type(ctx.qf_list), "table")
end

T["setup"]["file command returns @filepath"] = function()
  local cmd = commands.get("file")
  local ctx = { filepath = "/home/user/test.lua", filetype = "lua", line = 5, diagnostics = {}, qf_list = {} }
  expect.equality(cmd.fn(ctx), "@/home/user/test.lua")
end

T["setup"]["line command returns @filepath :Lline"] = function()
  local cmd = commands.get("line")
  local ctx = { filepath = "/home/user/test.lua", filetype = "lua", line = 42, diagnostics = {}, qf_list = {} }
  expect.equality(cmd.fn(ctx), "@/home/user/test.lua :L42")
end

T["setup"]["range command returns nil without visual selection"] = function()
  local cmd = commands.get("range")
  local ctx = { filepath = "/test.lua", filetype = "lua", line = 1, diagnostics = {}, qf_list = {} }
  expect.equality(cmd.fn(ctx), nil)
end

T["setup"]["range command returns range with visual selection"] = function()
  local cmd = commands.get("range")
  local ctx = {
    filepath = "/test.lua", filetype = "lua", line = 1,
    start_line = 10, end_line = 25,
    diagnostics = {}, qf_list = {},
  }
  expect.equality(cmd.fn(ctx), "@/test.lua :L10-25")
end

T["setup"]["range_content includes code block"] = function()
  local cmd = commands.get("range_content")
  local ctx = {
    filepath = "/test.lua", filetype = "lua", line = 1,
    start_line = 1, end_line = 2,
    lines = { "local a = 1", "local b = 2" },
    diagnostics = {}, qf_list = {},
  }
  local result = cmd.fn(ctx)
  expect.equality(result ~= nil, true)
  expect.equality(result:find("```lua") ~= nil, true)
  expect.equality(result:find("local a = 1") ~= nil, true)
end

T["setup"]["quickfix returns nil on empty list"] = function()
  local cmd = commands.get("quickfix")
  local ctx = { filepath = "/test.lua", filetype = "lua", line = 1, diagnostics = {}, qf_list = {} }
  expect.equality(cmd.fn(ctx), nil)
end

T["setup"]["throwing command does not propagate error"] = function()
  local user = {
    { name = "broken", modes = { "n" }, fn = function() error("kaboom") end },
  }
  commands.register(commands.get_defaults(), user)
  local result = commands.execute("broken")
  expect.equality(result, nil)
end

return T
