local M = {}

local ORG = "hagerty"
local PROJECT = "Hagerty"
local PAT_ENV = "AZURE_DEVOPS_PAT"
local AREA_PATH = "Hagerty\\Policy\\Internal Sales and Servicing"

local STATE_PRIORITY = {
  ["In Development"] = 1, ["In Progress"] = 1,
  ["Code Review"] = 2,
  ["Ready for QA"] = 2, ["In QA"] = 2, ["In Test"] = 2, ["Testing"] = 2, ["UAT"] = 2,
  ["Staged for Deployment"] = 3, ["Staged"] = 3, ["Staging"] = 3,
  ["Committed"] = 4,
  ["New"] = 5, ["To Do"] = 5, ["Active"] = 5,
}

-- Sprint resolution state
local sprint_cache = nil   -- string once resolved, false if resolution failed
local sprint_fetching = false
local sprint_waiters = {}

-- User ID cache (resolved once from VSSPS profile)
local uid_cache = nil
local uid_fetching = false
local uid_waiters = {}

local function api(path)
  return string.format("https://dev.azure.com/%s/%s/_apis/%s", ORG, PROJECT, path)
end

local function wi_url(id)
  return string.format("https://dev.azure.com/%s/%s/_workitems/edit/%d", ORG, PROJECT, id)
end

local function pr_url(repo, pr_id)
  return string.format("https://dev.azure.com/%s/%s/_git/%s/pullrequest/%d", ORG, PROJECT, repo, pr_id)
end

local function make_auth(pat)
  local creds = ":" .. pat
  if vim.base64 then
    return "Basic " .. vim.base64.encode(creds)
  end
  return "Basic " .. vim.fn.trim(vim.fn.system({ "base64" }, creds))
end

local function curl(url, method, body, cb)
  local pat = os.getenv(PAT_ENV)
  if not pat or pat == "" then
    vim.schedule(function()
      cb(nil, PAT_ENV .. " environment variable is not set")
    end)
    return
  end

  local cmd = {
    "curl", "-s", "--http1.1",
    "-H", "Authorization: " .. make_auth(pat),
    "-H", "Accept: application/json",
  }
  if method and method ~= "GET" then
    vim.list_extend(cmd, { "-X", method })
  end
  if body then
    vim.list_extend(cmd, { "-H", "Content-Type: application/json", "-d", body })
  end
  table.insert(cmd, url)

  local stdout = {}
  local stderr = {}
  vim.fn.jobstart(cmd, {
    on_stdout = function(_, data)
      for _, s in ipairs(data) do
        if s ~= "" then table.insert(stdout, s) end
      end
    end,
    on_stderr = function(_, data)
      for _, s in ipairs(data) do
        if s ~= "" then table.insert(stderr, s) end
      end
    end,
    on_exit = function(_, code)
      local raw = table.concat(stdout)
      if code ~= 0 then
        local detail = #stderr > 0 and table.concat(stderr) or raw
        vim.schedule(function()
          cb(nil, "curl exit " .. code .. ": " .. detail:sub(1, 120))
        end)
        return
      end
      if raw == "" then
        vim.schedule(function() cb(nil, "empty response") end)
        return
      end
      local ok, decoded = pcall(vim.json.decode, raw)
      if not ok then
        vim.schedule(function() cb(nil, "bad JSON: " .. raw:sub(1, 80)) end)
        return
      end
      if decoded.message and not decoded.value and not decoded.workItems and not decoded.children then
        vim.schedule(function() cb(nil, decoded.message) end)
        return
      end
      vim.schedule(function() cb(decoded, nil) end)
    end,
  })
end

-- Walk the classification nodes tree and return the path of the sprint whose
-- dates contain today. ISO date strings compare correctly as plain strings.
local function find_sprint_in_tree(node, parts, today)
  local found = nil
  local a = node.attributes
  if a and a.startDate and a.finishDate then
    local s = a.startDate:match("^(%d%d%d%d%-%d%d%-%d%d)")
    local f = a.finishDate:match("^(%d%d%d%d%-%d%d%-%d%d)")
    if s and f and s <= today and today <= f then
      found = table.concat(parts, "\\")
    end
  end
  for _, child in ipairs(node.children or {}) do
    local child_parts = {}
    for _, v in ipairs(parts) do child_parts[#child_parts + 1] = v end
    child_parts[#child_parts + 1] = child.name
    found = find_sprint_in_tree(child, child_parts, today) or found
  end
  return found
end

-- Resolve the current sprint once per session; concurrent callers queue up.
local function resolve_sprint(cb)
  if sprint_cache ~= nil then
    -- Already resolved (sprint_cache is a string path, or false on failure)
    return cb(sprint_cache or nil, sprint_cache == false and "no active sprint found" or nil)
  end
  if sprint_fetching then
    table.insert(sprint_waiters, cb)
    return
  end

  sprint_fetching = true
  local today = os.date("%Y-%m-%d")
  local url = api("wit/classificationnodes/iterations?$depth=5&api-version=7.1")

  curl(url, "GET", nil, function(data, err)
    local found = nil
    if not err and data then
      -- Only walk versioned folders like "26.3"; skip "External 2026" etc.
      for _, child in ipairs(data.children or {}) do
        if child.name:match("^%d+%.%d+") then
          found = find_sprint_in_tree(child, { PROJECT, child.name }, today) or found
        end
      end
    end

    sprint_cache = found or false
    sprint_fetching = false

    local waiters = sprint_waiters
    sprint_waiters = {}

    local sprint_err = (not found) and (err or "no active sprint found in iteration tree") or nil
    cb(found, sprint_err)
    for _, w in ipairs(waiters) do
      w(found, sprint_err)
    end
  end)
end

-- Expose resolved sprint for display in the renderer
function M.current_sprint()
  return type(sprint_cache) == "string" and sprint_cache or nil
end

-- Reset sprint cache (called on dashboard refresh so sprint re-evaluates)
function M.reset_sprint()
  sprint_cache = nil
  sprint_fetching = false
  sprint_waiters = {}
end

local function wiql(query, cb)
  local url = api("wit/wiql?api-version=7.1")
  local body = vim.json.encode({ query = query })
  curl(url, "POST", body, function(data, err)
    if err then return cb(nil, err) end
    if not data or not data.workItems or #data.workItems == 0 then
      return cb({}, nil)
    end

    local ids = {}
    for i, item in ipairs(data.workItems) do
      if i > 50 then break end
      table.insert(ids, item.id)
    end

    local fields = "System.Id,System.Title,System.State,System.WorkItemType"
    local detail_url = api("wit/workitems?ids=" .. table.concat(ids, ",") ..
      "&fields=" .. fields .. "&api-version=7.1")

    curl(detail_url, "GET", nil, function(detail, derr)
      if derr then return cb(nil, derr) end
      if not detail or not detail.value then return cb({}, nil) end
      local items = {}
      for _, item in ipairs(detail.value) do
        table.insert(items, {
          id = item.id,
          title = item.fields["System.Title"] or "",
          state = item.fields["System.State"] or "",
          type = item.fields["System.WorkItemType"] or "",
          url = wi_url(item.id),
        })
      end
      cb(items, nil)
    end)
  end)
end

local function wi_with_sprint(query_fn, cb)
  resolve_sprint(function(sprint, err)
    if err and not sprint then return cb(nil, err) end
    wiql(query_fn(sprint), cb)
  end)
end

function M.fetch_my_items(cb)
  wiql(string.format([[
    SELECT [System.Id] FROM WorkItems
    WHERE [System.AssignedTo] = @me
    AND [System.State] NOT IN ('Closed','Removed','Done','Completed')
    AND [System.AreaPath] UNDER '%s'
    ORDER BY [System.ChangedDate] DESC
  ]], AREA_PATH), function(items, err)
    if items then
      table.sort(items, function(a, b)
        return (STATE_PRIORITY[a.state] or 6) < (STATE_PRIORITY[b.state] or 6)
      end)
    end
    cb(items, err)
  end)
end

function M.fetch_available(cb)
  wi_with_sprint(function(sprint)
    return string.format([[
      SELECT [System.Id] FROM WorkItems
      WHERE [System.TeamProject] = 'Hagerty'
      AND [System.AssignedTo] = ''
      AND [System.State] NOT IN ('Closed','Removed','Done','Completed','Resolved')
      AND [System.AreaPath] UNDER '%s'
      AND [System.IterationPath] = '%s'
      ORDER BY [System.CreatedDate] DESC
    ]], AREA_PATH, sprint)
  end, cb)
end

function M.fetch_code_review(cb)
  wi_with_sprint(function(sprint)
    return string.format([[
      SELECT [System.Id] FROM WorkItems
      WHERE [System.TeamProject] = 'Hagerty'
      AND [System.State] = 'Code Review'
      AND [System.AreaPath] UNDER '%s'
      AND [System.IterationPath] = '%s'
      ORDER BY [System.ChangedDate] DESC
    ]], AREA_PATH, sprint)
  end, cb)
end

local function resolve_uid(cb)
  -- connectiondata returns authenticatedUser.id which is the ADO identity GUID —
  -- the same one stored in createdBy.id on PR objects.
  local conn_url = string.format("https://dev.azure.com/%s/_apis/connectiondata", ORG)
  curl(conn_url, "GET", nil, function(conn, err)
    if not err and conn and conn.authenticatedUser and conn.authenticatedUser.id then
      return cb(conn.authenticatedUser.id, nil)
    end
    -- Fallback: profile → email → identities search
    curl("https://app.vssps.visualstudio.com/_apis/profile/profiles/me?api-version=6.0", "GET", nil,
      function(profile, perr)
        local email = profile and (profile.emailAddress or profile.publicAlias)
        if not email then
          return cb(nil, perr or "could not determine user identity")
        end
        local id_url = string.format(
          "https://vssps.dev.azure.com/%s/_apis/identities?searchFilter=MailAddress&filterValue=%s&queryMembership=None&api-version=7.1",
          ORG, email)
        curl(id_url, "GET", nil, function(id_data, id_err)
          local ado_id = id_data and id_data.value and id_data.value[1] and id_data.value[1].id
          cb(ado_id, ado_id and nil or (id_err or "no identity found for " .. email))
        end)
      end)
  end)
end

local function get_user_id(cb)
  if uid_cache then return cb(uid_cache, nil) end
  if uid_fetching then
    table.insert(uid_waiters, cb)
    return
  end
  uid_fetching = true
  resolve_uid(function(id, err)
    uid_cache = id or nil
    uid_fetching = false
    local waiters = uid_waiters
    uid_waiters = {}
    cb(uid_cache, uid_cache and nil or err)
    for _, w in ipairs(waiters) do w(uid_cache, uid_cache and nil or err) end
  end)
end

local function fetch_prs_by(criteria_key, uid, cb)
  -- Use org-level endpoint so PRs across all projects/repos are included
  local url = string.format(
    "https://dev.azure.com/%s/_apis/git/pullrequests?searchCriteria.%s=%s&searchCriteria.status=active&$top=50&api-version=7.1",
    ORG, criteria_key, uid)
  curl(url, "GET", nil, function(data, err)
    if err then return cb(nil, err) end
    if not data or not data.value then return cb({}, nil) end
    local prs = {}
    for _, pr in ipairs(data.value) do
      local repo = pr.repository and pr.repository.name or "unknown"
      local project = pr.repository and pr.repository.project and pr.repository.project.name or PROJECT
      local repo_id = pr.repository and pr.repository.id or repo
      local author = pr.createdBy and pr.createdBy.displayName or "?"
      author = author:match("^(%S+)") or author
      -- Find current user's vote in the reviewers list
      local vote = nil
      for _, reviewer in ipairs(pr.reviewers or {}) do
        if reviewer.id == uid then vote = reviewer.vote; break end
      end
      -- Build URL from response data so it works regardless of project/repo location
      local web_url = string.format("https://dev.azure.com/%s/%s/_git/%s/pullrequest/%d",
        ORG, project, repo_id, pr.pullRequestId)
      table.insert(prs, {
        id = pr.pullRequestId,
        title = pr.title or "",
        repo = repo,
        author = author,
        url = web_url,
        vote = vote,
      })
    end
    cb(prs, nil)
  end)
end

function M.fetch_prs(cb)
  get_user_id(function(uid, err)
    if err then return cb(nil, err) end
    fetch_prs_by("reviewerId", uid, cb)
  end)
end

function M.fetch_my_prs(cb)
  get_user_id(function(uid, err)
    if err then return cb(nil, err) end
    fetch_prs_by("creatorId", uid, cb)
  end)
end

-- Fetch full PR details + latest build for a single PR (used by fetch_projects)
local function fetch_pr_with_info(repo_id, pr_id, cb)
  local pr_api = api(string.format(
    "git/repositories/%s/pullrequests/%d?api-version=7.1", repo_id, pr_id))
  curl(pr_api, "GET", nil, function(pr, _)
    if not pr or not pr.pullRequestId then return cb(nil) end

    local branch  = (pr.sourceRefName or ""):gsub("^refs/heads/", "")
    local repo_nm = pr.repository and pr.repository.name or "?"
    local proj    = pr.repository and pr.repository.project
                    and pr.repository.project.name or PROJECT
    local web_url = string.format(
      "https://dev.azure.com/%s/%s/_git/%s/pullrequest/%d",
      ORG, proj, repo_id, pr_id)

    local approved, total = 0, 0
    for _, rv in ipairs(pr.reviewers or {}) do
      total = total + 1
      if (rv.vote or 0) >= 5 then approved = approved + 1 end
    end

    local bld_url = api(string.format(
      "build/builds?searchCriteria.repositoryId=%s" ..
      "&searchCriteria.repositoryType=TfsGit" ..
      "&searchCriteria.branchName=refs/heads/%s&$top=1&api-version=7.1",
      repo_id, branch))
    curl(bld_url, "GET", nil, function(bdata, _)
      local build = nil
      if bdata and bdata.value and #bdata.value > 0 then
        local b = bdata.value[1]
        build = {
          status   = b.status,
          result   = b.result,
          number   = b.buildNumber,
          pipeline = b.definition and b.definition.name or "?",
          time     = b.finishTime or b.startTime or b.queueTime,
          url      = b._links and b._links.web and b._links.web.href,
        }
      end
      cb({ id = pr_id, title = pr.title or "", repo = repo_nm, branch = branch,
           url = web_url, approved = approved, total = total, build = build })
    end)
  end)
end

function M.fetch_projects(cb)
  get_user_id(function(uid, err)
    if err then return cb(nil, err) end

    local prs_url = string.format(
      "https://dev.azure.com/%s/_apis/git/pullrequests" ..
      "?searchCriteria.creatorId=%s&searchCriteria.status=active&$top=30&api-version=7.1",
      ORG, uid)

    curl(prs_url, "GET", nil, function(data, perr)
      if perr then return cb(nil, perr) end
      if not data or not data.value then return cb({}, nil) end

      local valid_prs = {}
      for _, pr in ipairs(data.value) do
        if pr.repository and pr.repository.id then
          table.insert(valid_prs, pr)
        end
      end
      if #valid_prs == 0 then return cb({}, nil) end

      local pr_entries = {}
      local pending    = #valid_prs

      local function all_done()
        -- Collect unique work item IDs across all PRs
        local wi_set, wi_ids = {}, {}
        for _, e in ipairs(pr_entries) do
          for _, id in ipairs(e.wi_ids) do
            if not wi_set[id] then wi_set[id] = true; table.insert(wi_ids, id) end
          end
        end

        local function build_result(wi_details)
          local projects = {}
          for _, e in ipairs(pr_entries) do
            if e.info then
              local work_items = {}
              for _, id in ipairs(e.wi_ids) do
                local wi = wi_details[id] or {}
                table.insert(work_items, {
                  id    = id,
                  title = wi.title or ("Work Item #" .. id),
                  state = wi.state or "",
                  type  = wi.type or "",
                  url   = wi_url(id),
                })
              end
              local pr = vim.tbl_extend("force", e.info, { work_items = work_items })
              table.insert(projects, pr)
            end
          end
          table.sort(projects, function(a, b) return a.id > b.id end)
          cb(projects, nil)
        end

        if #wi_ids == 0 then return build_result({}) end

        local fields = "System.Id,System.Title,System.State,System.WorkItemType"
        local detail_url = api("wit/workitems?ids=" .. table.concat(wi_ids, ",") ..
          "&fields=" .. fields .. "&api-version=7.1")
        curl(detail_url, "GET", nil, function(detail, _)
          local wi_details = {}
          if detail and detail.value then
            for _, item in ipairs(detail.value) do
              wi_details[item.id] = {
                title = item.fields["System.Title"] or "",
                state = item.fields["System.State"] or "",
                type  = item.fields["System.WorkItemType"] or "",
              }
            end
          end
          build_result(wi_details)
        end)
      end

      for _, pr in ipairs(valid_prs) do
        local repo_id = pr.repository.id
        local pr_id   = pr.pullRequestId
        local entry   = { pr_id = pr_id, repo_id = repo_id, wi_ids = {}, info = nil }
        table.insert(pr_entries, entry)

        local sub = 2
        local function sub_done()
          sub = sub - 1
          if sub == 0 then
            pending = pending - 1
            if pending == 0 then all_done() end
          end
        end

        local wi_api = api(string.format(
          "git/repositories/%s/pullrequests/%d/workitems?api-version=7.1", repo_id, pr_id))
        curl(wi_api, "GET", nil, function(wi_data, _)
          if wi_data and wi_data.value then
            for _, wi in ipairs(wi_data.value) do
              local id = tonumber(wi.id)
              if id then table.insert(entry.wi_ids, id) end
            end
          end
          sub_done()
        end)

        fetch_pr_with_info(repo_id, pr_id, function(info)
          entry.info = info
          sub_done()
        end)
      end
    end)
  end)
end

function M.fetch_pipelines(repos, cb)
  if not repos or #repos == 0 then return cb({}, nil) end

  local repos_url = api("git/repositories?api-version=7.1")
  curl(repos_url, "GET", nil, function(data, err)
    if err then return cb(nil, err) end

    local ado_ids = {}
    for _, r in ipairs((data and data.value) or {}) do
      ado_ids[r.name:lower()] = r.id
    end

    local results = {}
    local pending = 0
    local all_dispatched = false

    local function maybe_done()
      if all_dispatched and pending == 0 then
        table.sort(results, function(a, b) return a.repo < b.repo end)
        cb(results, nil)
      end
    end

    for _, repo in ipairs(repos) do
      local ado_id = ado_ids[repo.name:lower()]
      if ado_id then
        pending = pending + 1
        local branch = (repo.branch and repo.branch ~= "(detached)") and repo.branch or "main"
        local build_url = api(string.format(
          "build/builds?searchCriteria.repositoryId=%s&searchCriteria.repositoryType=TfsGit" ..
          "&searchCriteria.branchName=refs/heads/%s&$top=3&api-version=7.1",
          ado_id, branch))
        curl(build_url, "GET", nil, function(bdata, _)
          if bdata and bdata.value and #bdata.value > 0 then
            local b = bdata.value[1]
            table.insert(results, {
              repo     = repo.name,
              branch   = branch,
              status   = b.status,
              result   = b.result,
              number   = b.buildNumber,
              pipeline = b.definition and b.definition.name or "?",
              time     = b.finishTime or b.startTime or b.queueTime,
              url      = b._links and b._links.web and b._links.web.href,
            })
          else
            table.insert(results, { repo = repo.name, branch = branch, status = "none" })
          end
          pending = pending - 1
          maybe_done()
        end)
      end
    end

    all_dispatched = true
    maybe_done()
  end)
end

return M
