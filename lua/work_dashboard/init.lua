local M = {}

local ado = require("work_dashboard.ado")
local repos = require("work_dashboard.repos")
local renderer = require("work_dashboard.renderer")

local AUTO_REFRESH_MS = 10 * 60 * 1000 -- 10 minutes

local state = {
  win = nil,
  buf = nil,
  data = {},
  loading = {},
  line_meta = {},
  section_lines = {},
  tab = 1,
  refreshed_at = nil,
}

local refresh_timer = nil

local function stop_timer()
  if refresh_timer then
    refresh_timer:stop()
    refresh_timer:close()
    refresh_timer = nil
  end
end

local function re_render()
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    renderer.render(state)
  end
end

local function reset()
  state.data = {}
  state.line_meta = {}
  state.section_lines = {}
  state.tab = state.tab or 1
  state.loading = {
    my_items = true,
    prs = true,
    my_prs = true,
    available = true,
    code_review = true,
    repos = true,
    pipelines = true,
    projects = true,
  }
  ado.reset_sprint()
end

local function activate()
  local line = vim.api.nvim_win_get_cursor(state.win)[1]
  local meta = state.line_meta[line]
  if not meta then return end

  if meta.url then
    vim.fn.system({ "open", meta.url })
  elseif meta.path then
    vim.cmd("cd " .. vim.fn.fnameescape(meta.path))
    M.close()
    vim.notify("cwd → " .. meta.path, vim.log.levels.INFO)
  end
end

local function yank_current()
  if not (state.win and vim.api.nvim_win_is_valid(state.win)) then return end
  local line = vim.api.nvim_win_get_cursor(state.win)[1]
  local meta = state.line_meta[line]
  if not meta then return end
  local text = meta.url or meta.path
  if not text then return end
  vim.fn.setreg("+", text)
  vim.fn.setreg('"', text)
  vim.notify("yanked: " .. text, vim.log.levels.INFO)
end

local function fetch()
  state.refreshed_at = os.time()
  ado.fetch_my_items(function(data, err)
    state.data.my_items = data
    state.data.my_items_err = err
    state.loading.my_items = false
    re_render()
  end)
  ado.fetch_prs(function(data, err)
    state.data.prs = data
    state.data.prs_err = err
    state.loading.prs = false
    re_render()
  end)
  ado.fetch_my_prs(function(data, err)
    state.data.my_prs = data
    state.data.my_prs_err = err
    state.loading.my_prs = false
    re_render()
  end)
  ado.fetch_available(function(data, err)
    state.data.available = data
    state.data.available_err = err
    state.loading.available = false
    re_render()
  end)
  ado.fetch_code_review(function(data, err)
    state.data.code_review = data
    state.data.code_review_err = err
    state.loading.code_review = false
    re_render()
  end)
  ado.fetch_projects(function(data, err)
    state.data.projects = data
    state.data.projects_err = err
    state.loading.projects = false
    re_render()
  end)
  repos.scan(function(data)
    state.data.repos = data
    state.loading.repos = false
    re_render()
    ado.fetch_pipelines(data or {}, function(pdata, perr)
      state.data.pipelines = pdata
      state.data.pipelines_err = perr
      state.loading.pipelines = false
      re_render()
    end)
  end)
end

function M.close()
  stop_timer()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
  state.buf = nil
end

function M.refresh()
  reset()
  re_render()
  fetch()
end

function M.open()
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    vim.api.nvim_set_current_win(state.win)
    return
  end

  reset()

  state.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.buf].bufhidden = "wipe"

  local W = math.min(130, math.floor(vim.o.columns * 0.9))
  local H = math.min(55, math.floor(vim.o.lines * 0.9))
  local col = math.floor((vim.o.columns - W) / 2)
  local row = math.floor((vim.o.lines - H) / 2)

  state.win = vim.api.nvim_open_win(state.buf, true, {
    relative = "editor",
    width = W,
    height = H,
    col = col,
    row = row,
    style = "minimal",
    border = "rounded",
    title = "  Work Dashboard ",
    title_pos = "center",
  })

  vim.wo[state.win].wrap = false
  vim.wo[state.win].cursorline = true
  vim.wo[state.win].number = false
  vim.wo[state.win].relativenumber = false
  vim.wo[state.win].signcolumn = "no"

  local buf = state.buf
  local o = { noremap = true, silent = true, buffer = buf }
  vim.keymap.set("n", "q", M.close, o)
  vim.keymap.set("n", "<Esc>", M.close, o)
  vim.keymap.set("n", "r", M.refresh, o)
  vim.keymap.set("n", "<CR>", activate, o)
  vim.keymap.set("n", "o", activate, o)
  vim.keymap.set("n", "y", yank_current, o)
  vim.keymap.set("n", "<Tab>", function()
    state.tab = (state.tab % 4) + 1
    re_render()
  end, vim.tbl_extend("force", o, { desc = "Switch dashboard tab" }))

  local section_map = {
    [1] = { tab = 1, idx = 1 },
    [2] = { tab = 1, idx = 2 },
    [3] = { tab = 1, idx = 3 },
    [4] = { tab = 1, idx = 4 },
    [5] = { tab = 1, idx = 5 },
    [6] = { tab = 2, idx = 1 },
    [7] = { tab = 3, idx = 1 },
    [8] = { tab = 4, idx = 1 },
  }
  for i = 1, 8 do
    vim.keymap.set("n", tostring(i), function()
      local mapping = section_map[i]
      if not mapping then return end
      if state.tab ~= mapping.tab then
        state.tab = mapping.tab
        re_render()
      end
      local line = state.section_lines and state.section_lines[mapping.idx]
      if line and state.win and vim.api.nvim_win_is_valid(state.win) then
        vim.api.nvim_win_set_cursor(state.win, { line, 0 })
      end
    end, vim.tbl_extend("force", o, { desc = "Jump to section " .. i }))
  end

  vim.api.nvim_create_autocmd("WinLeave", {
    buffer = buf,
    once = true,
    callback = function()
      vim.schedule(M.close)
    end,
  })

  -- Auto-refresh every 10 minutes while the window is open
  stop_timer()
  refresh_timer = vim.loop.new_timer()
  refresh_timer:start(AUTO_REFRESH_MS, AUTO_REFRESH_MS, vim.schedule_wrap(function()
    if state.win and vim.api.nvim_win_is_valid(state.win) then
      M.refresh()
    else
      stop_timer()
    end
  end))

  re_render()
  fetch()
end

return M
