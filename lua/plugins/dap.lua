return {
  { import = "lazyvim.plugins.extras.dap.core" },
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "mason-org/mason.nvim",
    },
    config = function()
      local dap = require("dap")
      local uv = vim.uv or vim.loop

      local function netcoredbg_cmd()
        local base = vim.fn.stdpath("data") .. "/mason/packages/netcoredbg/netcoredbg"
        if vim.fn.has("win32") == 1 then
          base = base .. ".exe"
        end
        if vim.fn.executable(base) == 1 then
          return base
        end
        return nil
      end

      local function latest_dll(root)
        local dlls = vim.fn.glob(root .. "/bin/Debug/**/*.dll", false, true)
        table.sort(dlls, function(a, b)
          local a_stat = uv.fs_stat(a)
          local b_stat = uv.fs_stat(b)
          if not a_stat then
            return false
          end
          if not b_stat then
            return true
          end
          return a_stat.mtime.sec > b_stat.mtime.sec
        end)
        return dlls[1]
      end

      local netcoredbg_path = netcoredbg_cmd()
      if not netcoredbg_path then
        vim.notify("netcoredbg not found. Install via :Mason.", vim.log.levels.WARN)
        return
      end

      dap.adapters.coreclr = {
        type = "executable",
        command = netcoredbg_path,
        args = { "--interpreter=vscode" },
      }

      -- Common launch configurations for C#
      dap.configurations.cs = {
        {
          type = "coreclr",
          name = "Launch project (debug)",
          request = "launch",
          program = function()
            -- Build and locate dll under ./bin/Debug/<tfm>/<ProjectName>.dll
            vim.fn.system({ "dotnet", "build" })
            if vim.v.shell_error ~= 0 then
              vim.notify("dotnet build failed; select a dll manually.", vim.log.levels.WARN)
            end
            local cwd = vim.fn.getcwd()
            local dll = latest_dll(cwd)
            if dll then
              return dll
            end
            return vim.fn.input("Path to dll: ", cwd .. "/bin/Debug/", "file")
          end,
          cwd = "${workspaceFolder}",
          stopAtEntry = false,
          console = "integratedTerminal",
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
          program = function()
            vim.fn.system({ "dotnet", "build" })
            if vim.v.shell_error ~= 0 then
              vim.notify("dotnet build failed; select a dll manually.", vim.log.levels.WARN)
            end
            local cwd = vim.fn.getcwd()
            return vim.fn.input("Path to dll: ", cwd .. "/bin/Debug/", "file")
          end,
          args = function()
            local args_str = vim.fn.input("Program arguments: ")
            return vim.split(vim.trim(args_str), "%s+")
          end,
          cwd = "${workspaceFolder}",
          console = "integratedTerminal",
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
