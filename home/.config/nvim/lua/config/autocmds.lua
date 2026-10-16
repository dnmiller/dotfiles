-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua

-- Reload buffers that changed on disk (e.g. edited by opencode in another pane).
-- 'autoread' only acts when :checktime runs, and LazyVim only runs it on focus
-- and terminal events, so also run it when entering a buffer and when idle
-- (CursorHold fires after 'updatetime'). Buffers with unsaved edits are never
-- overwritten: nvim warns instead.
vim.o.autoread = true
vim.api.nvim_create_autocmd({ "BufEnter", "FocusGained", "CursorHold", "CursorHoldI" }, {
  group = vim.api.nvim_create_augroup("autoreload_files", { clear = true }),
  callback = function()
    -- :checktime is not allowed in the command-line window or while typing a command.
    if vim.fn.mode() ~= "c" and vim.fn.getcmdwintype() == "" then
      vim.cmd("checktime")
    end
  end,
})
vim.api.nvim_create_autocmd("FileChangedShellPost", {
  group = vim.api.nvim_create_augroup("autoreload_notify", { clear = true }),
  callback = function(ev)
    vim.notify("Reloaded " .. vim.fn.fnamemodify(ev.file, ":~:.") .. " (changed on disk)", vim.log.levels.INFO)
  end,
})

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
