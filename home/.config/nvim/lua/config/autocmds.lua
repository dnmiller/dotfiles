-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

-- LazyVim sets conceallevel=2, and markdown's treesitter highlights use it to
-- hide the backticks around `inline code` and ``` fences (revealed only on the
-- cursor line). The characters are still in the file, they just aren't drawn.
-- conceallevel is window-local and something keeps setting it back, so keep it
-- at 0 for markdown windows: apply it on every event that can show a markdown
-- buffer, and undo any later change via OptionSet. Deferred with vim.schedule
-- so it runs after whichever handler set the value.
-- (This also means <leader>uc cannot turn conceal back on in markdown.)
local function show_markdown_backticks(buf)
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(buf) or not vim.bo[buf].filetype:find("^markdown") then
      return
    end
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      if vim.wo[win].conceallevel ~= 0 then
        vim.wo[win].conceallevel = 0
      end
    end
  end)
end

local group = vim.api.nvim_create_augroup("markdown_show_backticks", { clear = true })

vim.api.nvim_create_autocmd({ "FileType", "BufEnter", "BufWinEnter", "WinEnter" }, {
  group = group,
  callback = function(ev)
    show_markdown_backticks(ev.buf)
  end,
})

vim.api.nvim_create_autocmd("OptionSet", {
  group = group,
  pattern = "conceallevel",
  callback = function()
    if vim.v.option_new ~= "0" then
      show_markdown_backticks(vim.api.nvim_get_current_buf())
    end
  end,
})
