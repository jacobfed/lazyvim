return {
  {
    "folke/snacks.nvim",
    opts = function(_, opts)
      opts.dashboard = opts.dashboard or {}
      local dashboard = opts.dashboard

      local function session_items()
        local ok_persistence, persistence = pcall(require, "persistence")
        if not ok_persistence then
          return {}
        end

        local ok_config, config = pcall(require, "persistence.config")
        if not ok_config or not config.options or not config.options.dir then
          return {}
        end

        local items = {}
        local visible = 0
        local max_items = 5
        local uv = vim.uv or vim.loop

        for _, session in ipairs(persistence.list()) do
          if visible >= max_items then
            break
          end

          if uv.fs_stat(session) then
            local name = session:sub(#config.options.dir + 1, -5)
            local parts = vim.split(name, "%%", { plain = true })
            local dir = parts[1] or ""
            local branch = parts[2]

            dir = dir:gsub("%%", "/")
            if jit and jit.os and jit.os:find("Windows") then
              dir = dir:gsub("^(%w)/", "%1:/")
            end

            local label = vim.fn.fnamemodify(dir, ":~")
            if branch and branch ~= "" then
              label = label .. " [" .. branch .. "]"
            end

            local function load_session()
              vim.fn.chdir(dir)
              if persistence.fire then
                persistence.fire("LoadPre")
              end
              vim.cmd("silent! source " .. vim.fn.fnameescape(session))
              if persistence.fire then
                persistence.fire("LoadPost")
              end
            end

            visible = visible + 1
            local key = tostring(visible)
            items[#items + 1] = { icon = " ", desc = label, key = key, action = load_session }
            items[#items + 1] = { key = "<k" .. key .. ">", action = load_session, hidden = true }
          end
        end

        if visible == 0 then
          items[#items + 1] = { icon = " ", desc = "No saved sessions" }
        end

        return items
      end

      local sections = dashboard.sections or {
        { section = "header" },
        { section = "keys", gap = 1, padding = 1 },
        { section = "startup" },
      }

      local inserted = false
      for index, section in ipairs(sections) do
        if type(section) == "table" and section.section == "keys" then
          table.insert(sections, index, { icon = " ", title = "Sessions", padding = 1 })
          table.insert(sections, index + 1, session_items)
          inserted = true
          break
        end
      end

      if not inserted then
        sections[#sections + 1] = { icon = " ", title = "Sessions", padding = 1 }
        sections[#sections + 1] = session_items
      end

      dashboard.sections = sections
    end,
  },
}
