return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.sections = opts.sections or {}
      opts.sections.lualine_b = opts.sections.lualine_b or {}
      opts.sections.lualine_x = opts.sections.lualine_x or {}

      -- Remove the default branch component from the left section.
      opts.sections.lualine_b = vim.tbl_filter(function(component)
        if type(component) == "string" then
          return component ~= "branch"
        end

        if type(component) == "table" then
          return component[1] ~= "branch"
        end

        return true
      end, opts.sections.lualine_b)

      -- Render branch on the right, limited to the first 12 characters.
      table.insert(opts.sections.lualine_x, 1, {
        function()
          local branch = vim.b.gitsigns_head
          if not branch or branch == "" then
            return ""
          end

          return " " .. branch:sub(1, 12)
        end,
      })
    end,
  },
}
