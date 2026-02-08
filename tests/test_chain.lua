local new_set = MiniTest.new_set
local expect = MiniTest.expect

local T = new_set()

local chain

T["setup"] = new_set({
  hooks = {
    pre_case = function()
      package.loaded["composer.chain"] = nil
      chain = require("composer.chain")
    end,
  },
})

T["setup"]["starts empty"] = function()
  expect.equality(chain.is_empty(), true)
  expect.equality(chain.get(), {})
  expect.equality(chain.content(), "")
end

T["setup"]["append adds to list"] = function()
  chain.append("@/foo/bar.lua")
  expect.equality(chain.is_empty(), false)
  expect.equality(chain.get(), { "@/foo/bar.lua" })
end

T["setup"]["append multiple items"] = function()
  chain.append("@/foo/bar.lua")
  chain.append("@/baz/qux.lua:L10")
  local items = chain.get()
  expect.equality(#items, 2)
  expect.equality(items[1], "@/foo/bar.lua")
  expect.equality(items[2], "@/baz/qux.lua:L10")
end

T["setup"]["get returns a copy"] = function()
  chain.append("@/foo.lua")
  local copy = chain.get()
  copy[1] = "modified"
  expect.equality(chain.get()[1], "@/foo.lua")
end

T["setup"]["content joins with double newline"] = function()
  chain.append("first")
  chain.append("second")
  expect.equality(chain.content(), "first\n\nsecond")
end

T["setup"]["content returns empty string when empty"] = function()
  expect.equality(chain.content(), "")
end

T["setup"]["clear resets to empty"] = function()
  chain.append("@/foo.lua")
  chain.append("@/bar.lua")
  chain.clear()
  expect.equality(chain.is_empty(), true)
  expect.equality(chain.get(), {})
  expect.equality(chain.content(), "")
end

T["setup"]["is_empty reflects state"] = function()
  expect.equality(chain.is_empty(), true)
  chain.append("item")
  expect.equality(chain.is_empty(), false)
  chain.clear()
  expect.equality(chain.is_empty(), true)
end

return T
