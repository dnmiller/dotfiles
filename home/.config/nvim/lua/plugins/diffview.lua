-- https://github.com/sindrets/diffview.nvim
-- One tab for every changed file against the index, a rev, or a file's history.
-- It opens in its own tab; <leader>gd from inside that tab closes it.
return {
  {
    "sindrets/diffview.nvim",
    cmd = {
      "DiffviewOpen",
      "DiffviewClose",
      "DiffviewToggleFiles",
      "DiffviewFocusFiles",
      "DiffviewRefresh",
      "DiffviewFileHistory",
    },
    keys = {
      {
        "<leader>gd",
        function()
          vim.cmd(require("diffview.lib").get_current_view() and "DiffviewClose" or "DiffviewOpen")
        end,
        desc = "Toggle Diffview",
      },
      { "<leader>gH", "<cmd>DiffviewFileHistory %<cr>", desc = "Diffview file history" },
      { "<leader>gH", ":DiffviewFileHistory<cr>", mode = "x", desc = "Diffview line history" },
    },
  },
}
