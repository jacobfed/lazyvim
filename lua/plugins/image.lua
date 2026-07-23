return {
  {
    "3rd/image.nvim",
    ft = { "markdown" },
    -- image.nvim's defaults already fit this machine: backend "kitty" (Ghostty
    -- implements the Kitty graphics protocol) and processor "magick_cli" (uses the
    -- ImageMagick CLI, `brew install imagemagick`). This spec mainly ensures setup()
    -- actually runs, and lazy-loads image.nvim on markdown instead of at startup.
    opts = {
      window_overlap_clear_enabled = true, -- hide images when a float (e.g. completion) covers them
    },
  },
}
