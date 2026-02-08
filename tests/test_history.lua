local new_set = MiniTest.new_set
local expect = MiniTest.expect

local T = new_set()

local history
local test_dir

T["setup"] = new_set({
  hooks = {
    pre_case = function()
      -- Create a temp dir for test isolation
      test_dir = vim.fn.tempname() .. "/alleyoop_test_history"
      vim.fn.mkdir(test_dir, "p")

      -- Override stdpath to use test dir
      package.loaded["alleyoop.history"] = nil
      history = require("alleyoop.history")

      -- Monkey-patch stdpath for isolation
      local orig_stdpath = vim.fn.stdpath
      vim.fn.stdpath = function(what)
        if what == "data" then
          return test_dir
        end
        return orig_stdpath(what)
      end

      history.init(5)
    end,
    post_case = function()
      -- Clean up test dir
      vim.fn.delete(test_dir, "rf")
    end,
  },
})

T["setup"]["starts with no entries"] = function()
  expect.equality(history.count(), 0)
  expect.equality(history.get_entries(), {})
end

T["setup"]["save and retrieve"] = function()
  history.save("first prompt")
  expect.equality(history.count(), 1)
  local entries = history.get_entries()
  expect.equality(entries[1], "first prompt")
end

T["setup"]["multiple saves preserve order"] = function()
  history.save("prompt 1")
  history.save("prompt 2")
  history.save("prompt 3")
  local entries = history.get_entries()
  expect.equality(#entries, 3)
  expect.equality(entries[1], "prompt 1")
  expect.equality(entries[2], "prompt 2")
  expect.equality(entries[3], "prompt 3")
end

T["setup"]["pruning respects max_history"] = function()
  -- max is 5 from init
  for i = 1, 7 do
    history.save("prompt " .. i)
  end
  expect.equality(history.count() <= 5, true)
end

return T
