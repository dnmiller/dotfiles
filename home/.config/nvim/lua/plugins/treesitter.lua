return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
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
