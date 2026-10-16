-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

-- LazyVim sets conceallevel=2, and markdown's treesitter highlights use it to
-- hide the backticks around `inline code` and ``` fences (revealed only on the
-- cursor line). The characters are still in the file, they just aren't drawn.
-- conceallevel is window-local, so also reapply it whenever a markdown buffer
-- is shown in a window, not only when the filetype is first set.
-- Deferred with vim.schedule so it runs after any other FileType/BufWinEnter
-- handler (plugins, treesitter start) that might set conceallevel again.
local function show_markdown_backticks(ev)
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(ev.buf) or not vim.bo[ev.buf].filetype:find("^markdown") then
      return
    end
    for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
      vim.wo[win].conceallevel = 0
    end
  end)
end

vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
  group = vim.api.nvim_create_augroup("markdown_show_backticks", { clear = true }),
  callback = show_markdown_backticks,
})
