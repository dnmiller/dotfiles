-- https://github.com/nickjvandyke/opencode.nvim
-- Talks to a running OpenCode server (found automatically; `opencode` in a tmux
-- pane works) or starts one in a split. Default branch supports OpenCode v2.
-- Verify with :checkhealth opencode.
return {
  {
    "nickjvandyke/opencode.nvim",
    dependencies = {
      -- LazyVim already ships snacks; these give Ask a floating input and
      -- Select a picker.
      { "folke/snacks.nvim", opts = { input = { enabled = true }, picker = { enabled = true } } },
    },
    init = function()
      ---@type opencode.Opts
      vim.g.opencode_opts = {
        server = {
          start = function()
            vim.cmd("vsplit")
            vim.cmd.terminal("opencode")
            vim.cmd("wincmd p")
          end,
        },
      }
    end,
    keys = {
      -- <leader>o rather than the plugin's suggested <C-a>/<C-x>, which would
      -- shadow Vim's number increment/decrement.
      { "<leader>oa", function() require("opencode").ask("@this: ") end, mode = { "n", "x" }, desc = "Ask OpenCode" },
      { "<leader>os", function() require("opencode").select() end, mode = { "n", "x" }, desc = "Select OpenCode action" },
      { "<leader>ob", function() require("opencode").ask("@buffer: ") end, desc = "Ask OpenCode about buffer" },
      { "<leader>od", function() require("opencode").prompt("Fix @diagnostics") end, desc = "OpenCode: fix diagnostics" },
      { "go", function() return require("opencode").operator("@this") end, mode = { "n", "x" }, expr = true, desc = "Send range to OpenCode" },
      { "goo", function() return require("opencode").operator("@this") .. "_" end, expr = true, desc = "Send line to OpenCode" },
    },
  },
  { "folke/which-key.nvim", opts = { spec = { { "<leader>o", group = "opencode" } } } },
}
