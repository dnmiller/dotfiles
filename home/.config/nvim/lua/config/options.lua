-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua

-- In containers there is no pbcopy/xclip/wl-copy, so yanks to the "+ register
-- would go nowhere. Fall back to OSC 52 (needs Neovim >= 0.10): the terminal
-- escape travels through tmux (set-clipboard on) to Ghostty and into the
-- Mac clipboard. OSC 52 paste is not reliably supported, so paste reads from
-- the unnamed register instead.
-- The nix-built nvim bundles wl-clipboard on its PATH, so a tool existing is not
-- enough: wl-copy/xclip/xsel also need a Wayland/X11 display to talk to.
local has_clipboard_tool = vim.fn.executable("pbcopy") == 1
  or (vim.env.WAYLAND_DISPLAY and vim.fn.executable("wl-copy") == 1)
  or (vim.env.DISPLAY and (vim.fn.executable("xclip") == 1 or vim.fn.executable("xsel") == 1))

if not has_clipboard_tool then
  local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
  if ok then
    local function paste()
      return { vim.fn.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") }
    end
    vim.g.clipboard = {
      name = "OSC 52",
      copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
      paste = { ["+"] = paste, ["*"] = paste },
    }
    vim.opt.clipboard = "unnamedplus"
  end
end
