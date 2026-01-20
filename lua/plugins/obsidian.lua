return {
  {
    "epwalsh/obsidian.nvim",
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
            name = "notes",
            path = "~/Documents/notes",
          },
          -- Add more vaults if needed:
          -- { name = "work", path = "~/Obsidian/Work" },
        },
        disable_frontmatter = false,
        -- Optional: templates support
        templates = {
          folder = "Templates",
          date_format = "%Y-%m-%d",
          time_format = "%H:%M",
        },
        -- Optional: completion integration with nvim-cmp or blink.cmp
        completion = {
          nvim_cmp = false,
          min_chars = 2,
        },
        -- Optional: daily notes configuration
        daily_notes = {
          folder = "Daily",
          date_format = "%Y-%m-%d",
        },
        -- Optional: UI preferences
        ui = {
          enable = true,
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
        map("<leader>on", "<cmd>ObsidianNew<cr>", "New note"),
        map("<leader>oo", "<cmd>ObsidianOpen<cr>", "Open in Obsidian app"),
        map("<leader>ot", "<cmd>ObsidianToday<cr>", "Today’s daily note"),
        map("<leader>oy", "<cmd>ObsidianYesterday<cr>", "Yesterday’s daily note"),
        map("<leader>os", "<cmd>ObsidianSearch<cr>", "Search notes"),
        map("<leader>oq", "<cmd>ObsidianQuickSwitch<cr>", "Quick switch"),
        map("<leader>ol", "<cmd>ObsidianFollowLink<cr>", "Follow link"),
        map("<leader>ob", "<cmd>ObsidianBacklinks<cr>", "Backlinks"),
        map("<leader>of", "<cmd>ObsidianToggleCheckbox<cr>", "Toggle checkbox"),
        map("<leader>om", "<cmd>ObsidianTemplate<cr>", "Insert template"),
        map("<leader>ow", "<cmd>ObsidianWorkspace<cr>", "Select workspace"),
      }
    end,
  },
}
