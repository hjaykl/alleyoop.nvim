local M = {}

local compose = require("alleyoop.compose")
local history = require("alleyoop.history")
local targets = require("alleyoop.targets")
local picker = require("alleyoop.picker")
local library = require("alleyoop.library")

---@type number
local width_frac = 0.8
---@type number
local height_frac = 0.6
---@type string|nil
local title_text = "Alley-Oop"

---@type integer|nil
local builder_win = nil

---@type string|nil
local draft = nil

--- Counter for unique buffer names
local buf_counter = 0

--- Initialize builder with config.
---@param config { width: number, height: number, title: string|false }
function M.init(config)
  width_frac = config.width
  height_frac = config.height
  if config.title == false or config.title == "" then
    title_text = nil
  else
    title_text = config.title
  end
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
  return " :w → " .. target_name .. " | C-t target | C-s save | C-l clear | q close "
end

local function update_header(win, index, total)
  if not vim.api.nvim_win_is_valid(win) then
    return
  end

  local center = title_text and (" " .. title_text .. " ") or nil
  local right
  if total > 0 and index <= total then
    right = " C-p/C-n (" .. string.format("%2d/%-2d", total - index + 1, total) .. ") "
  elseif total > 0 then
    right = " C-p/C-n ( new ) "
  end

  local title, title_pos
  if center and right then
    local w = vim.api.nvim_win_get_width(win)
    local cw = vim.api.nvim_strwidth(center)
    local rw = vim.api.nvim_strwidth(right)
    local pad_left = math.max(0, math.floor((w - cw) / 2))
    local pad_mid = math.max(1, w - pad_left - cw - rw)
    title = {
      { string.rep("─", pad_left), "FloatBorder" },
      { center, "FloatTitle" },
      { string.rep("─", pad_mid), "FloatBorder" },
      { right, "FloatTitle" },
    }
    title_pos = "left"
  elseif right then
    title = right
    title_pos = "right"
  elseif center then
    title = center
    title_pos = "center"
  end

  vim.api.nvim_win_set_config(win, {
    title = title,
    title_pos = title_pos,
    footer = build_footer(),
    footer_pos = "center",
  })
end

--- Close the builder window and clear the draft.
function M.close()
  draft = nil
  if builder_win and vim.api.nvim_win_is_valid(builder_win) then
    vim.api.nvim_win_close(builder_win, true)
  end
  builder_win = nil
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
    title = title_text and (" " .. title_text .. " ") or nil,
    title_pos = title_text and "center" or nil,
    footer = build_footer(),
    footer_pos = "center",
  })

  builder_win = win

  -- Unique buffer name to avoid collisions
  buf_counter = buf_counter + 1
  vim.api.nvim_buf_set_name(buf, "alleyoop://prompt-" .. buf_counter)
  vim.bo[buf].filetype = "markdown"
  vim.bo[buf].buftype = "acwrite"
  vim.bo[buf].bufhidden = "wipe"
  pcall(vim.treesitter.start, buf, "markdown")
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true

  local entries = history.get_entries()
  local current_index = #entries + 1

  -- Build initial content from draft + any new composed refs
  local initial = draft or ""
  if not compose.is_empty() then
    if initial ~= "" then
      initial = initial .. "\n\n" .. compose.content()
    else
      initial = compose.content()
    end
  end
  compose.clear()

  if initial ~= "" then
    set_buf_content(buf, win, initial)
  end

  -- Capture for C-n "back to draft" navigation
  local draft_content = initial
  update_header(win, current_index, #entries)

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end

  local function save_draft_and_close()
    draft = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    if draft == "" then
      draft = nil
    end
    close()
  end

  local function dispatch_and_close()
    local content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    if content == "" then
      vim.notify("Empty prompt, nothing to dispatch", vim.log.levels.WARN)
      return
    end
    targets.dispatch_default(content)
    history.save(content)
    draft = nil
    close()
  end

  -- BufWriteCmd: :w dispatches to default target
  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = dispatch_and_close,
  })

  -- BufWipeout: clean up guard state
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    callback = function()
      builder_win = nil
    end,
  })

  local map = vim.keymap.set

  -- q: save draft and close without dispatching
  map("n", "q", save_draft_and_close, { buffer = buf, nowait = true })

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
      set_buf_content(buf, win, draft_content)
    else
      set_buf_content(buf, win, entries[current_index])
    end
    update_header(win, current_index, #entries)
  end, { buffer = buf })

  -- <C-t>: switch dispatch target
  map("n", "<C-t>", function()
    local target_list = targets.list()
    local names = vim.tbl_map(function(t)
      return t.name
    end, target_list)

    picker.select(names, { prompt = "Set target:" }, function(choice)
      if choice then
        targets.set_default(choice)
        update_header(win, current_index, #entries)
      end
    end)
  end, { buffer = buf })

  -- <C-s>: save buffer content to library
  map("n", "<C-s>", function()
    local content = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
    if content == "" then
      vim.notify("Empty prompt, nothing to save", vim.log.levels.WARN)
      return
    end
    library.save(content)
  end, { buffer = buf })

  -- <C-l>: clear buffer
  map("n", "<C-l>", function()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
  end, { buffer = buf })
end

return M
