local new_set = MiniTest.new_set
local expect = MiniTest.expect

local T = new_set()

local notify

T["setup"] = new_set({
  hooks = {
    pre_case = function()
      package.loaded["alleyoop.notify"] = nil
      notify = require("alleyoop.notify")
    end,
  },
})

T["setup"]["defaults enable all categories"] = function()
  -- Should not error; info calls go through
  notify.info("compose", "test")
  notify.info("dispatch", "test")
  notify.info("target", "test")
  notify.info("library", "test")
end

T["setup"]["init with false disables all"] = function()
  local messages = {}
  local orig = vim.notify
  vim.notify = function(msg)
    table.insert(messages, msg)
  end

  notify.init(false)
  notify.info("compose", "should not appear")
  notify.info("dispatch", "should not appear")
  notify.info("target", "should not appear")
  notify.info("library", "should not appear")

  vim.notify = orig
  expect.equality(#messages, 0)
end

T["setup"]["init with partial table overrides"] = function()
  local messages = {}
  local orig = vim.notify
  vim.notify = function(msg)
    table.insert(messages, msg)
  end

  notify.init({ compose = false })
  notify.info("compose", "suppressed")
  notify.info("dispatch", "visible")

  vim.notify = orig
  expect.equality(#messages, 1)
  expect.equality(messages[1], "visible")
end

T["setup"]["init with nil keeps defaults"] = function()
  local messages = {}
  local orig = vim.notify
  vim.notify = function(msg)
    table.insert(messages, msg)
  end

  notify.init(nil)
  notify.info("compose", "visible")

  vim.notify = orig
  expect.equality(#messages, 1)
end

return T
