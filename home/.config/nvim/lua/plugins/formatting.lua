-- <leader>cf formats the buffer (or visual selection) and LazyVim also formats
-- on save (<leader>uf toggles it). LazyVim only has formatters wired up for the
-- filetypes of enabled extras, so declare them here.
--
-- Prettier finds .prettierrc* / prettier.config.{js,cjs,mjs,ts} on its own, but
-- not nonstandard names like prettier.config.md.cjs, which repos pass with
-- `--config`. Some repos keep one config per file type: each "kind" below looks
-- for prettier.config.<kind>.cjs upward from the buffer and passes it
-- explicitly. Without that file the formatter behaves like plain prettier.
local kinds = {
  js = {
    "javascript",
    "javascriptreact",
    "typescript",
    "typescriptreact",
    "json",
    "jsonc",
  },
  md = { "markdown", "markdown.mdx" },
  xml = { "xml", "xsd", "xslt" },
}

local formatters = {}
local formatters_by_ft = {}
for kind, filetypes in pairs(kinds) do
  local name = "prettier_" .. kind
  local config = ("prettier.config.%s.cjs"):format(kind)
  formatters[name] = {
    inherit = "prettier",
    prepend_args = function(_, ctx)
      local found = vim.fs.find(config, { path = ctx.dirname, upward = true })[1]
      return found and { "--config", found } or {}
    end,
  }
  for _, ft in ipairs(filetypes) do
    formatters_by_ft[ft] = { name }
  end
end

return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = formatters_by_ft,
      formatters = formatters,
    },
  },
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "prettier" })
    end,
  },
}
