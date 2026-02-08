local M = {}

---@class alleyoop.Context
---@field filepath string
---@field filetype string
---@field line integer
---@field start_line integer|nil
---@field end_line integer|nil
---@field lines string[]|nil
---@field diagnostics table[]
---@field qf_list table[]

---@class alleyoop.Command
---@field name string
---@field fn fun(ctx: alleyoop.Context): string|nil
---@field modes string[]
---@field scope? "file"|"line" Determines compose_qf dedup behavior (default: "file").

---@type table<string, alleyoop.Command>
local registry = {}

--- Build context from current editor state.
--- For visual mode, captures selection before it's lost.
---@return alleyoop.Context
function M.build_context()
  local mode = vim.fn.mode()
  local ctx = {
    filepath = vim.fn.expand("%:p"),
    filetype = vim.bo.filetype,
    line = vim.fn.line("."),
    diagnostics = vim.diagnostic.get(0),
    qf_list = vim.fn.getqflist(),
  }

  if mode == "v" or mode == "V" or mode == "\22" then
    local start_line = vim.fn.line("v")
    local end_line = vim.fn.line(".")
    if start_line > end_line then
      start_line, end_line = end_line, start_line
    end
    ctx.start_line = start_line
    ctx.end_line = end_line
    ctx.lines = vim.api.nvim_buf_get_lines(0, start_line - 1, end_line, false)
  end

  return ctx
end

--- Return the 7 default commands.
---@return alleyoop.Command[]
function M.get_defaults()
  return {
    {
      name = "file",
      modes = { "n" },
      fn = function(ctx)
        return "@" .. ctx.filepath
      end,
    },
    {
      name = "file_content",
      modes = { "n" },
      fn = function(ctx)
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        return "@" .. ctx.filepath .. "\n\n```" .. ctx.filetype .. "\n" .. table.concat(lines, "\n") .. "\n```"
      end,
    },
    {
      name = "line",
      modes = { "n" },
      scope = "line",
      fn = function(ctx)
        return "@" .. ctx.filepath .. " :L" .. ctx.line
      end,
    },
    {
      name = "range",
      modes = { "v" },
      fn = function(ctx)
        if not ctx.start_line then
          return nil
        end
        return "@" .. ctx.filepath .. " :L" .. ctx.start_line .. "-" .. ctx.end_line
      end,
    },
    {
      name = "range_content",
      modes = { "v" },
      fn = function(ctx)
        if not ctx.start_line or not ctx.lines then
          return nil
        end
        return "@"
          .. ctx.filepath
          .. " :L"
          .. ctx.start_line
          .. "-"
          .. ctx.end_line
          .. "\n\n```"
          .. ctx.filetype
          .. "\n"
          .. table.concat(ctx.lines, "\n")
          .. "\n```"
      end,
    },
    {
      name = "range_diagnostics",
      modes = { "v" },
      fn = function(ctx)
        if not ctx.start_line or not ctx.lines then
          return nil
        end
        local numbered = {}
        for i, line in ipairs(ctx.lines) do
          table.insert(numbered, string.format("%3d | %s", ctx.start_line + i - 1, line))
        end
        local ref = "@"
          .. ctx.filepath
          .. " :L"
          .. ctx.start_line
          .. "-"
          .. ctx.end_line
          .. "\n\n```"
          .. ctx.filetype
          .. "\n"
          .. table.concat(numbered, "\n")
          .. "\n```"
        local range_diags = vim.tbl_filter(function(d)
          return d.lnum >= ctx.start_line - 1 and d.lnum <= ctx.end_line - 1
        end, ctx.diagnostics)
        if #range_diags > 0 then
          ref = ref .. "\n\nDiagnostics:"
          for i, d in ipairs(range_diags) do
            local source = d.source and (" [" .. d.source .. "]") or ""
            local severity = vim.diagnostic.severity[d.severity] or "?"
            ref = ref .. "\n" .. i .. ". L" .. (d.lnum + 1) .. ": " .. severity .. " " .. d.message .. source
          end
        end
        return ref
      end,
    },
    {
      name = "line_diagnostics",
      modes = { "n" },
      scope = "line",
      fn = function(ctx)
        local ref = "@" .. ctx.filepath .. " :L" .. ctx.line
        local line_diags = vim.tbl_filter(function(d)
          return d.lnum == ctx.line - 1
        end, ctx.diagnostics)
        if #line_diags > 0 then
          ref = ref .. "\n\nDiagnostics:"
          for i, d in ipairs(line_diags) do
            local source = d.source and (" [" .. d.source .. "]") or ""
            ref = ref .. "\n" .. i .. ". " .. d.message .. source
          end
        end
        return ref
      end,
    },
    {
      name = "buf_diagnostics",
      modes = { "n" },
      fn = function(ctx)
        if #ctx.diagnostics == 0 then
          vim.notify("No diagnostics in buffer", vim.log.levels.WARN)
          return nil
        end
        local ref = "@" .. ctx.filepath .. "\n\nDiagnostics:"
        for i, d in ipairs(ctx.diagnostics) do
          local source = d.source and (" [" .. d.source .. "]") or ""
          local severity = vim.diagnostic.severity[d.severity] or "?"
          ref = ref .. "\n" .. i .. ". L" .. (d.lnum + 1) .. ": " .. severity .. " " .. d.message .. source
        end
        return ref
      end,
    },
    {
      name = "quickfix",
      modes = { "n" },
      fn = function(ctx)
        if #ctx.qf_list == 0 then
          vim.notify("Quickfix list is empty", vim.log.levels.WARN)
          return nil
        end
        local lines = {}
        for _, item in ipairs(ctx.qf_list) do
          local filename = item.bufnr > 0 and vim.fn.bufname(item.bufnr) or item.filename or ""
          table.insert(lines, filename .. ":" .. item.lnum .. ": " .. item.text)
        end
        return table.concat(lines, "\n")
      end,
    },
  }
end

--- Register commands. User commands with the same name override defaults.
---@param defaults alleyoop.Command[]
---@param user_commands alleyoop.Command[]
function M.register(defaults, user_commands)
  registry = {}
  for _, cmd in ipairs(defaults) do
    registry[cmd.name] = cmd
  end
  for _, cmd in ipairs(user_commands) do
    registry[cmd.name] = cmd
  end
end

--- Execute a command by name. Builds context, validates mode, returns string or nil.
---@param name string
---@return string|nil
function M.execute(name)
  local cmd = registry[name]
  if not cmd then
    vim.notify("Unknown command: " .. name, vim.log.levels.ERROR)
    return nil
  end

  local mode = vim.fn.mode()
  local is_visual = mode == "v" or mode == "V" or mode == "\22"
  local current_mode = is_visual and "v" or "n"

  local mode_ok = false
  for _, m in ipairs(cmd.modes) do
    if m == current_mode then
      mode_ok = true
      break
    end
  end

  if not mode_ok then
    return nil
  end

  local ctx = M.build_context()
  local ok, result = pcall(cmd.fn, ctx)
  if not ok then
    vim.notify("Command '" .. name .. "' failed: " .. tostring(result), vim.log.levels.ERROR)
    return nil
  end
  return result
end

--- Get a command by name.
---@param name string
---@return alleyoop.Command|nil
function M.get(name)
  return registry[name]
end

--- List all registered commands.
---@return alleyoop.Command[]
function M.list()
  local result = {}
  for _, cmd in pairs(registry) do
    table.insert(result, cmd)
  end
  table.sort(result, function(a, b)
    return a.name < b.name
  end)
  return result
end

return M
