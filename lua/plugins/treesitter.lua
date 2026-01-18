-- since this is just an example spec, don't actually load anything here and return an empty spec
-- stylua: ignore
return {
{
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "hyprlang",
        "vim",
        "lua",
        "vimdoc",
        "html",
        "css",
        "c_sharp",
        "razor"
      },
    },
  },
  {
  "folke/ts-comments.nvim",
  opts = {
    lang = {
      c_sharp = "/// %s",
    },
  },
}
}
