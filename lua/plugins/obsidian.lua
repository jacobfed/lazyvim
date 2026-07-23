return {
  {
    "obsidian-nvim/obsidian.nvim",
    version = "*", -- stable releases; or branch = "main"
    lazy = true,
    ft = { "markdown" }, -- load on Markdown files
    dependencies = {
      "nvim-lua/plenary.nvim",
      "ibhagwan/fzf-lua",
      "3rd/image.nvim",
    },
    opts = function()
      -- Adjust the path(s) to your vault(s)
      return {
        workspaces = {
          {
            name = "obsidian_work",
            path = "~/Documents/obsidian_work/",
          },
          -- Add more vaults if needed:
          -- { name = "work", path = "~/Obsidian/Work" },
        },
        frontmatter = { enabled = true },
        legacy_commands = false,
        -- Optional: templates support
        templates = {
          folder = "Templates",
          date_format = "%Y-%m-%d",
          time_format = "%H:%M",
        },
        -- Completion is provided by the built-in obsidian-ls LSP server (picked up by blink.cmp).
        -- Optional: daily notes configuration
        daily_notes = {
          folder = "Daily",
          date_format = "%Y-%m-%d",
        },
        -- render-markdown.nvim (LazyVim's lang.markdown extra) already renders markdown UI,
        -- so disable obsidian's own UI to avoid double-conceal / double-rendering.
        ui = {
          enable = false,
        },
        picker = {
          name = "fzf-lua",
        },
      }
    end,
    keys = function()
      local function map(lhs, rhs, desc)
        return { lhs, rhs, desc = "Obsidian: " .. desc, mode = "n" }
      end
      return {
        map("<leader>on", "<cmd>Obsidian new<cr>", "New note"),
        map("<leader>oo", "<cmd>Obsidian open<cr>", "Open in Obsidian app"),
        map("<leader>ot", "<cmd>Obsidian today<cr>", "Today’s daily note"),
        map("<leader>oy", "<cmd>Obsidian yesterday<cr>", "Yesterday’s daily note"),
        map("<leader>os", "<cmd>Obsidian search<cr>", "Search notes"),
        map("<leader>oq", "<cmd>Obsidian quick_switch<cr>", "Quick switch"),
        map("<leader>ol", "<cmd>Obsidian follow_link<cr>", "Follow link"),
        map("<leader>ob", "<cmd>Obsidian backlinks<cr>", "Backlinks"),
        map("<leader>of", "<cmd>Obsidian toggle_checkbox<cr>", "Toggle checkbox"),
        map("<leader>om", "<cmd>Obsidian template<cr>", "Insert template"),
        map("<leader>ow", "<cmd>Obsidian workspace<cr>", "Select workspace"),
      }
    end,
  },
}
