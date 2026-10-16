-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

-- mini.pairs auto-closes ` and types over an existing closing `, which eats
-- backticks when writing inline code and ``` fences in markdown. Turn auto-pairing
-- off for those buffers.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("markdown_no_autopairs", { clear = true }),
  pattern = { "markdown", "markdown.mdx" },
  callback = function(ev)
    vim.b[ev.buf].minipairs_disable = true
  end,
})
