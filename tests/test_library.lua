local new_set = MiniTest.new_set
local expect = MiniTest.expect

local T = new_set()

local library
local test_dir

local function write_file(path, content)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local f = io.open(path, "w")
  if f then
    f:write(content)
    f:close()
  end
end

T["setup"] = new_set({
  hooks = {
    pre_case = function()
      test_dir = vim.fn.tempname() .. "/composer_test_library"
      vim.fn.mkdir(test_dir, "p")

      package.loaded["composer.library"] = nil
      package.loaded["composer.picker"] = nil
      library = require("composer.library")

      -- Override stdpath for isolation
      local orig_stdpath = vim.fn.stdpath
      vim.fn.stdpath = function(what)
        if what == "data" then
          return test_dir
        end
        return orig_stdpath(what)
      end

      library.init()
    end,
    post_case = function()
      vim.fn.delete(test_dir, "rf")
    end,
  },
})

T["setup"]["get_items returns empty when no files"] = function()
  local items = library.get_items()
  expect.equality(#items, 0)
end

T["setup"]["get_items finds md files"] = function()
  local lib_dir = test_dir .. "/composer/library"
  write_file(lib_dir .. "/test-prompt.md", "# Test prompt")
  write_file(lib_dir .. "/refactoring/extract.md", "# Extract function")

  local items = library.get_items()
  expect.equality(#items, 2)
end

T["setup"]["get_items returns correct structure"] = function()
  local lib_dir = test_dir .. "/composer/library"
  write_file(lib_dir .. "/my-prompt.md", "content")

  local items = library.get_items()
  expect.equality(#items, 1)
  expect.equality(items[1].name, "my-prompt")
  expect.equality(items[1].scope, "global")
  expect.equality(type(items[1].path), "string")
end

T["setup"]["get_items sorts project before global"] = function()
  local lib_dir = test_dir .. "/composer/library"
  write_file(lib_dir .. "/global-prompt.md", "global")

  -- Create a project dir with .composer
  local project_dir = test_dir .. "/project"
  vim.fn.mkdir(project_dir .. "/.composer", "p")
  write_file(project_dir .. "/.composer/project-prompt.md", "project")

  -- Override vim.fs.root for this test
  local orig_root = vim.fs.root
  vim.fs.root = function()
    return project_dir
  end

  package.loaded["composer.library"] = nil
  library = require("composer.library")
  local orig_stdpath = vim.fn.stdpath
  vim.fn.stdpath = function(what)
    if what == "data" then
      return test_dir
    end
    return orig_stdpath(what)
  end
  library.init()

  local items = library.get_items()
  expect.equality(#items, 2)
  expect.equality(items[1].scope, "project")
  expect.equality(items[2].scope, "global")

  vim.fs.root = orig_root
end

return T
