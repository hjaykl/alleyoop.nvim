local new_set = MiniTest.new_set
local expect = MiniTest.expect

local T = new_set()

local compose

T["setup"] = new_set({
  hooks = {
    pre_case = function()
      package.loaded["alleyoop.compose"] = nil
      compose = require("alleyoop.compose")
    end,
  },
})

T["setup"]["starts empty"] = function()
  expect.equality(compose.is_empty(), true)
  expect.equality(compose.get(), {})
  expect.equality(compose.content(), "")
end

T["setup"]["append adds to list"] = function()
  compose.append("@/foo/bar.lua")
  expect.equality(compose.is_empty(), false)
  expect.equality(compose.get(), { "@/foo/bar.lua" })
end

T["setup"]["append multiple items"] = function()
  compose.append("@/foo/bar.lua")
  compose.append("@/baz/qux.lua:L10")
  local items = compose.get()
  expect.equality(#items, 2)
  expect.equality(items[1], "@/foo/bar.lua")
  expect.equality(items[2], "@/baz/qux.lua:L10")
end

T["setup"]["get returns a copy"] = function()
  compose.append("@/foo.lua")
  local copy = compose.get()
  copy[1] = "modified"
  expect.equality(compose.get()[1], "@/foo.lua")
end

T["setup"]["content joins with double newline"] = function()
  compose.append("first")
  compose.append("second")
  expect.equality(compose.content(), "first\n\nsecond")
end

T["setup"]["content returns empty string when empty"] = function()
  expect.equality(compose.content(), "")
end

T["setup"]["clear resets to empty"] = function()
  compose.append("@/foo.lua")
  compose.append("@/bar.lua")
  compose.clear()
  expect.equality(compose.is_empty(), true)
  expect.equality(compose.get(), {})
  expect.equality(compose.content(), "")
end

T["setup"]["is_empty reflects state"] = function()
  expect.equality(compose.is_empty(), true)
  compose.append("item")
  expect.equality(compose.is_empty(), false)
  compose.clear()
  expect.equality(compose.is_empty(), true)
end

return T
