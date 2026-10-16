-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

-- "jk" typed within 'timeoutlen' leaves insert mode.
vim.keymap.set("i", "jk", "<Esc>", { desc = "Exit insert mode" })
