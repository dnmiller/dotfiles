-- https://github.com/okuuva/auto-save.nvim
return {
  {
    "okuuva/auto-save.nvim",
    version = "^1.0.0",
    opts = {
      trigger_events = { -- See :h autocmd-events
        immediate_save = { "BufLeave", "FocusLost" }, -- save when leaving buffer or window
        defer_save = { "InsertLeave", "TextChanged" }, -- save after a delay during editing
      },
    },
  },
}
