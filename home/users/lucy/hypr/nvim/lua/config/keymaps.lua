-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- vim.keymap.set( "n", ("<C-d>", "<C-d>zz"))
-- vim.keymap.set( "n", ("<C-u>", "<C-u>zz"))
-- nnoremap("<C-d>", "<C-d>zz")
-- nnoremap("<C-u>", "<C-u>zz")
-- map( "n", "<C-d>", "<C-d>zz" { desc = "Go to left window", remap = true })
-- map( "n", "<C-u>", "<C-u>zz" { desc = "Go to left window", remap = true })

vim.keymap.set('n', '<leader>sv', ':source $MYVIMRC<CR>')

vim.keymap.set({'n', 'v'}, '<C-d>', '<C-d>zz', { noremap = true })
vim.keymap.set({'n', 'v'}, '<C-u>', '<C-u>zz', { noremap = true })


vim.keymap.set('n', '<leader>e', ':E<CR>', {noremap = true})


