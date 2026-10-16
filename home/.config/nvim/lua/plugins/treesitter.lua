return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      -- LazyVim starts vim.treesitter on FileType for these, replacing regex syntax.
      highlight = { enable = true },
      ensure_installed = {
        "c",
        "cpp",
        "python",
        "rust",
        "yaml",
        "json",
        "xml",
        "toml",
        "bash",
        "starlark", -- Bazel BUILD/.bzl
        "nix",
        "markdown",
        "markdown_inline",
      },
    },
    init = function()
      -- No jsonc parser exists; the json grammar already accepts comments.
      vim.treesitter.language.register("json", "jsonc")
    end,
  },
}
