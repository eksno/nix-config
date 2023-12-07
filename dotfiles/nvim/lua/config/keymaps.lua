-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set('n', '<leader>sv', ':source $home/.config/nvim/init.lua <cr>')

vim.keymap.set({'n', 'v'}, '<C-d>', '<C-d>zz', { noremap = true })
vim.keymap.set({'n', 'v'}, '<C-u>', '<C-u>zz', { noremap = true })
