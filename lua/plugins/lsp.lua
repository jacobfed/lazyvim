return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      inlay_hints = {
        exclude = { "vue", "lua" },
      },
      servers = {
        lua_ls = {
          settings = {
            Lua = {
              hint = { enable = false },
              codeLens = { enable = false },
            },
          },
        },
        -- C# is handled solely by roslyn.nvim (LSP client name "roslyn"). Disable the OTHER
        -- C# servers LazyVim auto-enables for the mason `roslyn` package — they spawn-fail
        -- and conflict:
        --   csharp_ls → `csharp-ls` (not installed)
        --   roslyn_ls → `Microsoft.CodeAnalysis.LanguageServer --stdio` (not on PATH; roslyn.nvim runs it)
        csharp_ls = { enabled = false },
        roslyn_ls = { enabled = false },
        omnisharp = { enabled = false },
      },
    },
  },
}
