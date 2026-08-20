local M = {}
local ado = require("work_dashboard.ado")

local ns = vim.api.nvim_create_namespace("work_dashboard")

local TABS = { "Work (1–5)", "Repos (6)", "Pipelines (7)", "Projects (8)" }

local function pad(s, n)
  s = tostring(s)
  if #s >= n then return s:sub(1, n) end
  return s .. string.rep(" ", n - #s)
end

local function trunc(s, n)
  if n <= 0 then return "" end
  if #s > n then return s:sub(1, n - 1) .. "…" end
  return s
end

local type_labels = {
  ["User Story"] = "Story",
  ["Bug"] = "Bug",
  ["Task"] = "Task",
  ["Epic"] = "Epic",
  ["Feature"] = "Feat",
}

local function fmt_type(t)
  return type_labels[t] or (t and t:sub(1, 5) or "?")
end

local function fmt_build_time(iso)
  if not iso then return "" end
  local mo, d, h, mi = iso:match("%-(%d%d)-(%d%d)T(%d%d):(%d%d)")
  if not mo then return "" end
  return mo .. "/" .. d .. " " .. h .. ":" .. mi
end

local BUILD_RESULT = {
  succeeded          = "passed",
  failed             = "FAILED",
  canceled           = "canceled",
  partiallySucceeded = "partial",
}

local BUILD_HL = {
  succeeded          = "DiagnosticOk",
  failed             = "DiagnosticError",
  partiallySucceeded = "DiagnosticWarn",
}

local function fmt_build_result(status, result)
  if status == "none"       then return "no builds" end
  if status == "inProgress" then return "running"   end
  if status == "notStarted" then return "queued"    end
  return BUILD_RESULT[result] or result or status or "?"
end

function M.render(state)
  local buf = state.buf
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then return end

  local win = state.win
  local W = (win and vim.api.nvim_win_is_valid(win)) and vim.api.nvim_win_get_width(win) or 100
  local CW = W - 4

  local lines = {}
  local line_hl = {}
  local line_hl_ranges = {} -- partial: { line_1idx, group, col_s, col_e }
  local line_meta = {}
  local section_lines = {}

  local function row(text, hl, meta)
    table.insert(lines, text)
    if hl then line_hl[#lines] = hl end
    if meta then line_meta[#lines] = meta end
  end

  local function hl_range(group, col_s, col_e)
    table.insert(line_hl_ranges, { #lines, group, col_s, col_e })
  end

  local function section(title)
    row("")
    local n = #section_lines + 1
    table.insert(section_lines, #lines + 1)
    row("  " .. n .. "  " .. title, "Title")
    row("  " .. string.rep("─", CW), "Comment")
  end

  local function wi_row(item)
    local type_s = pad(fmt_type(item.type), 5)
    local id_s = pad("#" .. item.id, 7)
    local state_s = pad(item.state, 18)
    local title_w = math.max(CW - 5 - 7 - 18 - 8, 12)
    local text = string.format("  %s  %s  %s  %s",
      type_s, id_s, pad(trunc(item.title, title_w), title_w), state_s)
    row(text, nil, { url = item.url })
  end

  local function loading_section(key, err_key, empty_msg, render_fn)
    if state.loading[key] then
      row("  ⋯ loading...", "Comment")
    elseif err_key and state.data[err_key] then
      row("  ✗ " .. trunc(tostring(state.data[err_key]), CW - 4), "WarningMsg")
    elseif not state.data[key] or #state.data[key] == 0 then
      row("  " .. empty_msg, "Comment")
    else
      render_fn(state.data[key])
    end
  end

  -- ── Tab bar ──────────────────────────────────────────────────────────
  row("")
  local tab_line = "  "
  local tab_positions = {} -- { col_s, col_e, tab_idx }
  for i, name in ipairs(TABS) do
    local label = (i == state.tab and "● " or "○ ") .. name
    local col_s = #tab_line
    tab_line = tab_line .. label
    local col_e = #tab_line
    table.insert(tab_positions, { col_s, col_e, i })
    if i < #TABS then tab_line = tab_line .. "    " end
  end
  local refresh_s = state.refreshed_at and ("refreshed " .. os.date("%H:%M", state.refreshed_at)) or ""
  if #refresh_s > 0 then
    local gap = math.max(2, W - 2 - #tab_line - #refresh_s)
    tab_line = tab_line .. string.rep(" ", gap) .. refresh_s
  end
  row(tab_line)
  for _, tp in ipairs(tab_positions) do
    local grp = tp[3] == state.tab and "Title" or "Comment"
    hl_range(grp, tp[1], tp[2])
  end
  if #refresh_s > 0 then
    hl_range("Comment", #tab_line - #refresh_s, #tab_line)
  end
  row("  " .. string.rep("─", CW), "Comment")

  -- ── Hint line ────────────────────────────────────────────────────────
  row("  r refresh   <Tab> switch tab   Enter open/cd   y yank   1-8 jump   q close", "Comment")

  -- ── Tab content ──────────────────────────────────────────────────────
  if state.tab == 1 then
    local sprint = ado.current_sprint()
    local sprint_label = sprint and ("  sprint: " .. sprint) or "  resolving sprint..."

    section("MY WORK ITEMS" .. sprint_label)
    loading_section("my_items", "my_items_err", "(none assigned to you)", function(items)
      for _, item in ipairs(items) do wi_row(item) end
    end)

    section("PULL REQUESTS TO REVIEW")
    loading_section("prs", "prs_err", "✓  inbox clear", function(prs)
      local VOTE_LABEL = {
        [10] = "approved", [5] = "approved+",
        [-5] = "waiting", [-10] = "rejected",
      }
      for _, pr in ipairs(prs) do
        local repo_s = pad(pr.repo, 28)
        local id_s = pad("PR #" .. pr.id, 10)
        local author_s = pad("@" .. pr.author, 16)
        local vote_s = pad(VOTE_LABEL[pr.vote] or "no vote", 10)
        local title_w = math.max(CW - 28 - 10 - 16 - 10 - 10, 10)
        local text = string.format("  %s  %s  %s  %s  %s",
          repo_s, id_s, author_s, vote_s, trunc(pr.title, title_w))
        row(text, nil, { url = pr.url })
      end
    end)

    section("MY OPEN PULL REQUESTS")
    loading_section("my_prs", "my_prs_err", "(none open)", function(prs)
      for _, pr in ipairs(prs) do
        local repo_s = pad(pr.repo, 36)
        local id_s = pad("PR #" .. pr.id, 10)
        local title_w = math.max(CW - 36 - 10 - 4, 10)
        local text = string.format("  %s  %s  %s", repo_s, id_s, trunc(pr.title, title_w))
        row(text, nil, { url = pr.url })
      end
    end)

    section("AVAILABLE FOR PICKUP")
    loading_section("available", "available_err", "(none)", function(items)
      for _, item in ipairs(items) do wi_row(item) end
    end)

    section("AVAILABLE FOR CODE REVIEW")
    loading_section("code_review", "code_review_err", "(none)", function(items)
      for _, item in ipairs(items) do wi_row(item) end
    end)

  elseif state.tab == 2 then
    section("LOCAL REPOSITORIES")
    loading_section("repos", nil, "(none found in ~/Documents/code)", function(repos)
      for _, repo in ipairs(repos) do
        local name_s = pad(repo.name, 42)
        local branch_s = pad(repo.branch or "(detached)", 28)
        local dirty = repo.dirty or 0
        local status_s = dirty == 0 and "clean" or (dirty .. " modified")
        local hl_grp = dirty == 0 and "DiagnosticOk" or "DiagnosticWarn"
        local text = string.format("  %s  %s  %s", name_s, branch_s, status_s)
        row(text, hl_grp, { path = repo.path })
      end
    end)

  elseif state.tab == 3 then
    section("PIPELINE STATUS")
    loading_section("pipelines", "pipelines_err", "(no repos matched ADO repositories)", function(pipes)
      for _, p in ipairs(pipes) do
        local repo_s     = pad(p.repo, 30)
        local branch_s   = pad(p.branch or "", 22)
        local pipeline_s = pad(p.pipeline or "", 28)
        local result_str = fmt_build_result(p.status, p.result)
        local result_s   = pad(result_str, 10)
        local time_s     = fmt_build_time(p.time)
        local text = string.format("  %s  %s  %s  %s  %s",
          repo_s, branch_s, pipeline_s, result_s, time_s)
        local hl = BUILD_HL[p.result]
        if not hl and p.status == "inProgress" then hl = "DiagnosticInfo" end
        row(text, hl, p.url and { url = p.url } or nil)
      end
    end)

  elseif state.tab == 4 then
    section("PROJECTS")
    loading_section("projects", "projects_err", "(no active PRs found)", function(projects)
      for _, pr in ipairs(projects) do
        row("")
        -- PR as top-level entry
        local pr_s     = pad("PR #" .. pr.id, 9)
        local branch_s = pad(pr.branch, 28)
        local repo_s   = pad(pr.repo, 24)
        local bld_str  = pr.build and fmt_build_result(pr.build.status, pr.build.result) or "no build"
        local bld_s    = pad(bld_str, 10)
        local time_s   = pad(pr.build and fmt_build_time(pr.build.time) or "", 11)
        local votes_s  = (pr.approved or 0) .. "/" .. (pr.total or 0) .. " appr"
        local pr_text  = string.format("  %s  %s  %s  %s  %s  %s",
          pr_s, branch_s, repo_s, bld_s, time_s, votes_s)
        local hl = pr.build and BUILD_HL[pr.build.result] or nil
        if not hl and pr.build and pr.build.status == "inProgress" then hl = "DiagnosticInfo" end
        row(pr_text, hl, pr.url and { url = pr.url } or nil)

        -- Linked work items indented beneath
        if #(pr.work_items or {}) == 0 then
          row("    (no linked work items)", "Comment")
        else
          for _, wi in ipairs(pr.work_items) do
            local type_s  = pad(fmt_type(wi.type), 5)
            local id_s    = pad("#" .. wi.id, 8)
            local state_s = wi.state
            local title_w = math.max(CW - 4 - 5 - 2 - 8 - 2 - 2 - #state_s, 10)
            local wi_text = string.format("    %s  %s  %s  %s",
              type_s, id_s, pad(trunc(wi.title, title_w), title_w), state_s)
            row(wi_text, "Comment", wi.url and { url = wi.url } or nil)
          end
        end
      end
    end)
  end

  row("")

  -- Write buffer
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  -- Highlights
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for i, grp in pairs(line_hl) do
    pcall(vim.api.nvim_buf_add_highlight, buf, ns, grp, i - 1, 0, -1)
  end
  for _, r in ipairs(line_hl_ranges) do
    pcall(vim.api.nvim_buf_add_highlight, buf, ns, r[2], r[1] - 1, r[3], r[4])
  end

  state.line_meta = line_meta
  state.section_lines = section_lines
end

return M
