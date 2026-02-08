-- Minimal init for running tests with mini.test
-- Usage: nvim --headless --noplugin -u scripts/minimal_init.lua -c "lua MiniTest.run()"

-- Add plugin to rtp
vim.cmd("set rtp+=.")

-- Clone mini.nvim if not present
local mini_path = vim.fn.stdpath("data") .. "/site/pack/test/start/mini.nvim"
if vim.fn.isdirectory(mini_path) == 0 then
  vim.fn.system({ "git", "clone", "--depth=1", "https://github.com/echasnovski/mini.nvim", mini_path })
end
vim.cmd("set rtp+=" .. mini_path)

require("mini.test").setup()
