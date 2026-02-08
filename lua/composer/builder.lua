local M = {}

local chain = require("composer.chain")
local history = require("composer.history")
local targets = require("composer.targets")
local picker = require("composer.picker")
local library = require("composer.library")

---@type number
local width_frac = 0.8
---@type number
local height_frac = 0.6

---@type integer|nil
local builder_win = nil

--- Counter for unique buffer names
local buf_counter = 0

--- Initialize builder with config.
---@param config { width: number, height: number }
function M.init(config)
  width_frac = config.width
  height_frac = config.height
end

local function set_buf_content(buf, win, content)
  local lines = vim.split(content, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  if vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_set_cursor(win, { #lines, math.max(0, #lines[#lines] - 1) })
  end
end

local function build_footer()
  local target_name = targets.get_default_name()
  return " :w → " .. target_name .. " | <C-t> target | <C-p>/<C-n> history | <C-l> library | q cancel "
end

local function update_header(win, index, total)
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  local title
  if total > 0 and index <= total then
    title = " Composer (" .. index .. "/" .. total .. ") "
  elseif total > 0 then
    title = " Composer (new | " .. total .. " saved) "
  else
    title = " Composer "
  end
  vim.api.nvim_win_set_config(win, {
    title = title,
    title_pos = "center",
    footer = build_footer(),
    footer_pos = "center",
  })
end

--- Open the prompt builder floating window.
function M.open()
  -- Double-open guard
  if builder_win and vim.api.nvim_win_is_valid(builder_win) then
    vim.api.nvim_set_current_win(builder_win)
    return
  end

  local width = math.floor(vim.o.columns * width_frac)
  local height = math.floor(vim.o.lines * height_frac)
  local buf = vim.api.nvim_create_buf(false, true)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
    border = "rounded",
    title = " Composer ",
    title_pos = "center",
    footer = build_footer(),
    footer_pos = "center",
  })

  builder_win = win

  -- Unique buffer name to avoid collisions
  buf_counter = buf_counter + 1
  vim.api.nvim_buf_set_name(buf, "composer://prompt-" .. buf_counter)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].bufhidden = "wipe"
  pcall(vim.treesitter.start, buf, "markdown")
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true

  local entries = history.get_entries()
  local current_index = #entries + 1

  -- Pre-fill with chain content if non-empty
  if not chain.is_empty() then
    set_buf_content(buf, win, chain.content())
  end
  update_header(win, current_index, #entries)

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  local function dispatch_and_close(target_name)
    local content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    if content == "" then
      vim.notify("Empty prompt, nothing to dispatch", vim.log.levels.WARN)
      return
    end
    if target_name then
      targets.dispatch(target_name, content)
    else
      targets.dispatch_default(content)
    end
    history.save(content)
    chain.clear()
    close()
  end

  -- BufWriteCmd: :w dispatches to default target
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      dispatch_and_close(nil)
    end,
  })

  -- BufWipeout: clean up guard state
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    callback = function()
      builder_win = nil
    end,
  })

  local map = vim.keymap.set

  -- q: close without dispatching (chain preserved)
  map("n", "q", close, { buffer = buf, nowait = true })

  -- <C-p>: previous history entry
  map("n", "<C-p>", function()
    if #entries == 0 then
      return
    end
    current_index = current_index - 1
    if current_index < 1 then
      current_index = 1
    end
    set_buf_content(buf, win, entries[current_index])
    update_header(win, current_index, #entries)
  end, { buffer = buf })

  -- <C-n>: next history entry
  map("n", "<C-n>", function()
    if current_index > #entries then
      return
    end
    current_index = current_index + 1
    if current_index > #entries then
      local draft = chain.content()
      set_buf_content(buf, win, draft)
    else
      set_buf_content(buf, win, entries[current_index])
    end
    update_header(win, current_index, #entries)
  end, { buffer = buf })

  -- <C-t>: pick target then dispatch
  map("n", "<C-t>", function()
    local target_list = targets.list()
    local names = vim.tbl_map(function(t)
      return t.name
    end, target_list)

    picker.select(names, { prompt = "Dispatch to:" }, function(choice)
      if choice then
        dispatch_and_close(choice)
      end
    end)
  end, { buffer = buf })

  -- <C-l>: save buffer content to library
  map("n", "<C-l>", function()
    local content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    if content == "" then
      vim.notify("Empty prompt, nothing to save", vim.log.levels.WARN)
      return
    end
    library.save(content)
  end, { buffer = buf })
end

return M
