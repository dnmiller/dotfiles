-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

-- "jk" typed within 'timeoutlen' leaves insert mode.
vim.keymap.set("i", "jk", "<Esc>", { desc = "Exit insert mode" })

-- Cmd+C in a visual selection copies to the system clipboard. Terminals never
-- forward Cmd, so Ghostty (home/.config/ghostty/config) sends Esc y (= <M-y>).
vim.keymap.set("x", "<M-y>", '"+y', { desc = "Copy selection to system clipboard" })
