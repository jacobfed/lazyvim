# Changelog

All notable changes to this Neovim configuration are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added
- .NET debugging via `nvim-dap` + `netcoredbg` (launch / attach / launch-with-args), `nvim-dap-ui`, and F5/F10/F11/F12 stepping.
- Roslyn `///` XML doc-comment auto-generation for C#/Razor buffers.
- Custom snacks dashboard header and a "Sessions" section listing recent persistence sessions.
- lualine: git branch rendered on the right, truncated to 12 characters.
- Obsidian notes integration (fzf-lua picker) and `mini.files`.

### Changed
- Migrated Obsidian from the archived `epwalsh/obsidian.nvim` to the maintained `obsidian-nvim/obsidian.nvim` fork; updated options (`frontmatter.enabled`, `legacy_commands = false`) and keymaps to the new `:Obsidian <sub>` command form.
- Moved custom keymaps off LazyVim's group prefixes to remove conflicts: substitute → `<leader>S`, black-hole delete → `<leader>D`, make-executable → `<leader>X`; formatting now uses LazyVim's `<leader>cf`.
- Window title now reuses gitsigns' head instead of shelling out to `git` on every buffer enter.

### Fixed
- Roslyn auto-insert handler guards against a missing text edit and no longer stacks duplicate autocmds.

### Removed
- `lua/config/nvim-dap.lua` (folded into `lua/plugins/dap.lua` plus F-key maps in `keymaps.lua`).
- Dead `lua/plugins/luarocks.nvim` spec (wrong file extension, never loaded; lazy.nvim manages the image.nvim rock natively).
