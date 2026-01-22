return {
  { import = "lazyvim.plugins.extras.dap.core" },
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "mason-org/mason.nvim",
    },
    config = function()
      local dap = require("dap")

      local netcoredbg_path = vim.fn.expand("~/.local/share/nvim/mason/packages/netcoredbg/netcoredbg")
      if not netcoredbg_path then
        vim.notify("netcoredbg not found. Install via :Mason or set manual path.", vim.log.levels.WARN)
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
            vim.fn.jobstart({ "dotnet", "build" }, { detach = true })
            local cwd = vim.fn.getcwd()
            -- Try to find the most recent dll in bin/Debug
            local dll = vim.fn.glob(cwd .. "/bin/Debug/**/*.dll", false, true)
            if dll and #dll > 0 then
              return dll[1]
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
            vim.fn.jobstart({ "dotnet", "build" }, { detach = true })
            return vim.fn.input("Path to dll: ", vim.fn.getcwd() .. "/bin/Debug/", "file")
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
