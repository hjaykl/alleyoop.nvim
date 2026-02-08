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

      local history = require("composer.history")
      local targets = require("composer.targets")
      local library = require("composer.library")
      local builder = require("composer.builder")

      -- Use temp dirs for isolation
      local test_dir = vim.fn.tempname() .. "/composer_test_builder"
      vim.fn.mkdir(test_dir, "p")
      local orig_stdpath = vim.fn.stdpath
      vim.fn.stdpath = function(what)
        if what == "data" then
          return test_dir
        end
        return orig_stdpath(what)
      end

      history.init(50)
      targets.register({}, nil)
      library.init()
      builder.init({ width = 0.8, height = 0.6 })
    end,
    post_case = function()
      -- Close any open builder windows
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        local name = vim.api.nvim_buf_get_name(buf)
        if name:match("^composer://") then
          vim.api.nvim_win_close(win, true)
        end
      end
    end,
  },
})

T["setup"]["open creates a floating window"] = function()
  local builder = require("composer.builder")
  builder.open()

  -- Find the composer window
  local found = false
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local name = vim.api.nvim_buf_get_name(buf)
    if name:match("^composer://") then
      found = true
      expect.equality(vim.api.nvim_win_is_valid(win), true)
      expect.equality(vim.bo[buf].filetype, "markdown")
      expect.equality(vim.bo[buf].buftype, "acwrite")
      break
    end
  end
  expect.equality(found, true)
end

T["setup"]["double open does not create second window"] = function()
  local builder = require("composer.builder")
  builder.open()

  local count_before = 0
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_buf_get_name(buf):match("^composer://") then
      count_before = count_before + 1
    end
  end

  builder.open()

  local count_after = 0
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_buf_get_name(buf):match("^composer://") then
      count_after = count_after + 1
    end
  end

  expect.equality(count_before, 1)
  expect.equality(count_after, 1)
end

T["setup"]["q keymap closes window"] = function()
  local builder = require("composer.builder")
  builder.open()

  -- Find the builder window and buffer
  local builder_win
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.api.nvim_buf_get_name(buf):match("^composer://") then
      builder_win = win
      break
    end
  end

  expect.no_equality(builder_win, nil)

  -- Simulate pressing q
  vim.api.nvim_set_current_win(builder_win)
  vim.api.nvim_feedkeys("q", "x", false)

  -- Window should be closed
  expect.equality(vim.api.nvim_win_is_valid(builder_win), false)
end

return T
