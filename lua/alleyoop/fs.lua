local M = {}

function M.read_file(path)
  local fd = vim.uv.fs_open(path, "r", 0)
  if not fd then return nil end
  local stat = vim.uv.fs_fstat(fd)
  if not stat then
    vim.uv.fs_close(fd)
    return nil
  end
  local content = vim.uv.fs_read(fd, stat.size, 0)
  vim.uv.fs_close(fd)
  return content
end

function M.write_file(path, content)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local fd = vim.uv.fs_open(path, "w", 438) -- 0o666
  if not fd then return end
  vim.uv.fs_write(fd, content, 0)
  vim.uv.fs_close(fd)
end

return M
