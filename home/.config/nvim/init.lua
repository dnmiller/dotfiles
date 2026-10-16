-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- Share system clipboard
vim.opt.clipboard:append { 'unnamed', 'unnamedplus' }

-- Configure Neovim to use OSC 52 for clipboard
vim.g.clipboard = {
  name = 'OSC 52',
  copy = {
    ['+'] = require('vim.ui.clipboard.osc52').copy('+'),
    ['*'] = require('vim.ui.clipboard.osc52').copy('*'),
  },
  paste = {
    ['+'] = function() return { vim.fn.split(vim.fn.getreg(''), '\n'), vim.fn.getregtype('') } end,
    ['*'] = function() return { vim.fn.split(vim.fn.getreg(''), '\n'), vim.fn.getregtype('') } end,
  },
}
