-- https://github.com/debugloop/telescope-undo.nvim
-- <leader>u is LazyVim's UI menu, so undo lives under search.
return {
  {
    "debugloop/telescope-undo.nvim",
    dependencies = {
      {
        "nvim-telescope/telescope.nvim",
        dependencies = { "nvim-lua/plenary.nvim" },
      },
    },
    keys = {
      { "<leader>su", "<cmd>Telescope undo<cr>", desc = "Undo history" },
    },
    config = function()
      require("telescope").setup({})
      require("telescope").load_extension("undo")
    end,
  },
}
