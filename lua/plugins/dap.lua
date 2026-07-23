return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "mason-org/mason.nvim",
    },
    config = function()
      local dap = require("dap")
      local uv = vim.uv or vim.loop

      -- Mason's macOS netcoredbg is an x86_64 build that can't debug arm64 .NET processes
      -- (it launches under Rosetta, but the debuggee never starts). Prefer a native arm64
      -- build if one is installed under ~/.local/share/netcoredbg-arm64.
      local netcoredbg_arm64 = vim.fn.expand("~/.local/share/netcoredbg-arm64/netcoredbg/netcoredbg")
      local netcoredbg_path = (vim.fn.executable(netcoredbg_arm64) == 1) and netcoredbg_arm64
        or (vim.fn.stdpath("data") .. "/mason/packages/netcoredbg/netcoredbg")
      if vim.fn.executable(netcoredbg_path) ~= 1 then
        vim.notify("netcoredbg not found. Install via :Mason.", vim.log.levels.WARN)
        return
      end

      -- Find the startup project to build/run: a web (Microsoft.NET.Sdk.Web) or Exe project,
      -- excluding test projects.
      -- Pick the project to build/run: the web/worker/exe project that most looks like a
      -- service host. Ranks candidates (prefers "*.Host"/"Server.Host" and web/worker SDKs,
      -- deprioritizes example/client/sample/template projects) so repos with several runnable
      -- projects still choose the real host. filereadable guards against a directory named
      -- "*.csproj" (some repos have them).
      local function startup_csproj(root)
        local best, best_score
        for _, p in ipairs(vim.fn.glob(root .. "/**/*.csproj", false, true)) do
          if vim.fn.filereadable(p) == 1 and not p:find("/test/", 1, true) and not p:find("/tests/", 1, true) then
            local content = table.concat(vim.fn.readfile(p), "\n")
            local is_web = content:match('Sdk%s*=%s*"Microsoft%.NET%.Sdk%.Web"') ~= nil
            local is_worker = content:match('Sdk%s*=%s*"Microsoft%.NET%.Sdk%.Worker"') ~= nil
            local is_exe = content:match("<OutputType>%s*Exe%s*</OutputType>") ~= nil
            if is_web or is_worker or is_exe then
              local name = vim.fn.fnamemodify(p, ":t:r")
              local score = 0
              if name:match("Server%.Host") or name:match("%.Host$") then
                score = score + 5
              end
              if is_web or is_worker then
                score = score + 2
              end
              if p:find("/src/", 1, true) then
                score = score + 1
              end
              if name:match("[Ee]xample") or name:match("[Ss]ample") or name:match("%.Client") or name:match("[Tt]emplate") or p:find("{{", 1, true) then
                score = score - 5
              end
              if not best_score or score > best_score then
                best, best_score = p, score
              end
            end
          end
        end
        return best
      end

      -- Mirror `dotnet run --project`: read the project's launchSettings.json "Project"
      -- profile so the debugged app gets the same environment (ASPNETCORE_ENVIRONMENT,
      -- custom vars) and URLs. netcoredbg does not read launchSettings.json itself.
      local function launch_env(proj)
        if not proj then
          return nil
        end
        local file = vim.fn.fnamemodify(proj, ":h") .. "/Properties/launchSettings.json"
        if not uv.fs_stat(file) then
          return nil
        end
        local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(file), "\n"))
        if not ok or type(data) ~= "table" or type(data.profiles) ~= "table" then
          return nil
        end
        local profile
        for _, p in pairs(data.profiles) do
          if type(p) == "table" and p.commandName == "Project" then
            profile = p
            break
          end
        end
        if not profile then
          return nil
        end
        local env = {}
        for k, v in pairs(profile.environmentVariables or {}) do
          env[k] = tostring(v)
        end
        if profile.applicationUrl and not env.ASPNETCORE_URLS then
          env.ASPNETCORE_URLS = profile.applicationUrl
        end
        return next(env) and env or nil
      end

      -- Enumerate launchable assemblies by globbing built output dirs for runtimeconfig.json
      -- (only runnable projects emit one; class libraries don't). Globbing — rather than
      -- parsing `dotnet build` stdout — is deterministic: a multi-targeted project always
      -- lists ALL its TFMs. Prefers the startup project; falls back to the tree (no tests).
      local function launchable_dlls(proj, root)
        local seen, dlls = {}, {}
        local function add(dll)
          if dll == "" or seen[dll] then
            return
          end
          local is_test = dll:find("/test/", 1, true)
            or dll:find("/tests/", 1, true)
            or dll:match("%.Unit%.dll$")
            or dll:match("%.Integration%.dll$")
          if not is_test and uv.fs_stat(dll) then
            seen[dll] = true
            dlls[#dlls + 1] = dll
          end
        end
        local patterns = {}
        if proj then
          patterns[#patterns + 1] = vim.fn.fnamemodify(proj, ":h") .. "/bin/Debug/*/*.runtimeconfig.json"
        end
        patterns[#patterns + 1] = root .. "/**/bin/Debug/**/*.runtimeconfig.json"
        for _, pattern in ipairs(patterns) do
          for _, rc in ipairs(vim.fn.glob(pattern, false, true)) do
            add((rc:gsub("%.runtimeconfig%.json$", ".dll")))
          end
          if #dlls > 0 then
            break
          end
        end
        -- Highest .NET version first: it matches the TFM `dotnet run` builds, so its output
        -- stays fresh (a lower TFM often isn't rebuilt → stale PDB → "cursor line out of range"),
        -- and the native arm64 netcoredbg handles current runtimes fine.
        table.sort(dlls, function(a, b)
          local va = tonumber(a:match("/net(%d+)%.")) or 0
          local vb = tonumber(b:match("/net(%d+)%.")) or 0
          if va ~= vb then
            return va > vb
          end
          return a > b
        end)
        return dlls
      end

      -- Build asynchronously (UI stays responsive), then resolve which app DLL to debug.
      -- Calls cb(dll) with the chosen assembly, or cb(false) to abort.
      local function resolve_program(cb)
        local root = vim.fn.getcwd()
        local proj = startup_csproj(root)
        local cmd = proj and { "dotnet", "build", proj } or { "dotnet", "build" }
        vim.notify("dotnet build…", vim.log.levels.INFO, { title = "DAP" })
        vim.system(cmd, { text = true, cwd = root }, function(obj)
          vim.schedule(function()
            if obj.code ~= 0 then
              local detail = (obj.stderr ~= "" and obj.stderr) or obj.stdout or ""
              vim.notify("dotnet build failed:\n" .. detail, vim.log.levels.ERROR, { title = "DAP" })
              return cb(false)
            end
            local dlls = launchable_dlls(proj, root)
            local function finish(dll)
              if not dll or dll == "" then
                return cb(false)
              end
              vim.notify(
                "Debugging " .. vim.fn.fnamemodify(dll, ":t") .. " (" .. vim.fn.fnamemodify(dll, ":h:t") .. ")",
                vim.log.levels.INFO,
                { title = "DAP" }
              )
              cb(dll)
            end
            -- If the candidates are the same assembly across target frameworks, auto-pick the
            -- first (highest TFM — matches `dotnet run`, so its build stays fresh) instead of
            -- prompting. Only prompt when there are genuinely different projects to choose from.
            local same_project = #dlls > 0
            for _, d in ipairs(dlls) do
              if vim.fn.fnamemodify(d, ":t") ~= vim.fn.fnamemodify(dlls[1], ":t") then
                same_project = false
                break
              end
            end
            if #dlls == 0 then
              finish(vim.fn.input("Path to dll: ", root .. "/", "file"))
            elseif same_project then
              finish(dlls[1])
            else
              vim.ui.select(dlls, {
                prompt = "Select project to debug:",
                format_item = function(dll)
                  return vim.fn.fnamemodify(dll, ":t:r") .. "  (" .. vim.fn.fnamemodify(dll, ":h:t") .. ")"
                end,
              }, finish)
            end
          end)
        end)
      end

      -- program: async build + pick, delivered as a dap coroutine config value.
      local function program()
        return coroutine.create(function(dap_co)
          resolve_program(function(dll)
            coroutine.resume(dap_co, dll or dap.ABORT)
          end)
        end)
      end

      -- cwd + env mirror `dotnet run --project`: run from the project dir (so relative
      -- config paths like conf-local resolve) with the launchSettings profile applied.
      local function project_dir()
        local proj = startup_csproj(vim.fn.getcwd())
        return proj and vim.fn.fnamemodify(proj, ":h") or vim.fn.getcwd()
      end
      local function project_env()
        return launch_env(startup_csproj(vim.fn.getcwd()))
      end

      dap.adapters.coreclr = {
        type = "executable",
        command = netcoredbg_path,
        args = { "--interpreter=vscode" },
      }

      dap.configurations.cs = {
        {
          type = "coreclr",
          name = "Launch project (debug)",
          request = "launch",
          program = program,
          cwd = project_dir,
          env = project_env,
          stopAtEntry = false,
          -- internalConsole: netcoredbg + integratedTerminal (runInTerminal) was exiting at
          -- configurationDone. App output shows in the dap console instead.
          console = "internalConsole",
          justMyCode = true,
        },
        {
          type = "coreclr",
          name = "Attach to process",
          request = "attach",
          processId = require("dap.utils").pick_process,
          justMyCode = true,
        },
        {
          type = "coreclr",
          name = "Launch with args",
          request = "launch",
          program = program,
          cwd = project_dir,
          env = project_env,
          args = function()
            local args_str = vim.fn.input("Program arguments: ")
            return vim.split(vim.trim(args_str), "%s+")
          end,
          console = "internalConsole",
          justMyCode = true,
        },
      }
    end,
  },
  {
    "rcarriga/nvim-dap-ui",
    dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")
      dapui.setup()
      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open()
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close()
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close()
      end
    end,
  },
}
