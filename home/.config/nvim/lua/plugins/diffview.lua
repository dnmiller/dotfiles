-- https://github.com/sindrets/diffview.nvim
-- One tab for every changed file against the index, a rev, or a file's history.
-- Close it with :DiffviewClose (it is its own tab).
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
      { "<leader>gd", "<cmd>DiffviewOpen<cr>", desc = "Diffview" },
      { "<leader>gH", "<cmd>DiffviewFileHistory %<cr>", desc = "Diffview file history" },
      { "<leader>gH", ":DiffviewFileHistory<cr>", mode = "x", desc = "Diffview line history" },
    },
  },
}
