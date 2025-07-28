-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.g.snacks_animate = false
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4

vim.opt.scrolloff = 8

vim.opt.updatetime = 50
vim.opt.colorcolumn = "81"

-- views can only be fully collapsed with the global statusline
vim.opt.laststatus = 3
local handle = io.popen("which python3")
if handle then
  local python_path = handle:read("*a"):gsub("%s+", "")
  handle:close()
  vim.g.python3_host_prog = python_path
else
  vim.g.python3_host_prog = nil
  vim.notify("Failed to find python3 executable", vim.log.levels.ERROR)
end
