local M = {}

local REPOS_DIR = vim.fn.expand("~/Documents/code")

function M.scan(cb)
  local script = string.format([[
    for dir in "%s"/*/; do
      [ -d "$dir/.git" ] || continue
      name=$(basename "$dir")
      branch=$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || echo "(detached)")
      dirty=$(git -C "$dir" status --short 2>/dev/null | wc -l | tr -d ' ')
      printf "%%s\t%%s\t%%s\t%%s\n" "$name" "$branch" "$dirty" "$dir"
    done
  ]], REPOS_DIR)

  local chunks = {}
  vim.fn.jobstart({ "bash", "-c", script }, {
    on_stdout = function(_, data)
      for _, line in ipairs(data) do
        if line ~= "" then table.insert(chunks, line) end
      end
    end,
    on_exit = function()
      local repos = {}
      for _, line in ipairs(chunks) do
        local name, branch, dirty_s, path = line:match("^([^\t]+)\t([^\t]+)\t([^\t]+)\t(.+)$")
        if name then
          table.insert(repos, {
            name = name,
            branch = branch,
            dirty = tonumber(dirty_s) or 0,
            path = path:gsub("/$", ""),
          })
        end
      end
      table.sort(repos, function(a, b) return a.name < b.name end)
      vim.schedule(function() cb(repos) end)
    end,
  })
end

return M
