-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
--- Add any additional keymaps here

-- Move selected lines down in visual mode
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down one line" })

-- Move selected lines up in visual mode
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up one line" })

-- Join lines in normal mode and keep cursor position
vim.keymap.set("n", "J", "mzJ`z", { desc = "Join line below (keep cursor position)" })

-- Scroll down and recenter the view
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Half-page down (recenter cursor)" })

-- Scroll up and recenter the view
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Half-page up (recenter cursor)" })

-- Search next and recenter the view
vim.keymap.set("n", "n", "nzzzv", { desc = "Next search result (recenter + open folds)" })

-- Search previous and recenter the view
vim.keymap.set("n", "N", "Nzzzv", { desc = "Previous search result (recenter + open folds)" })

-- Paste without overwriting the default register
vim.keymap.set("x", "<leader>p", [["_dP]], { desc = "Paste over selection (keep yank register)" })

-- Yank to the system clipboard
vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]], { desc = "Yank to system clipboard" })
vim.keymap.set("n", "<leader>Y", [["+Y]], { desc = "Yank line to system clipboard" })

-- Delete without affecting the default register
-- (<leader>D, not <leader>d, to leave the DAP debug group on <leader>d)
vim.keymap.set({ "n", "v" }, "<leader>D", [["_d]], { desc = "Delete to black hole register" })

-- Format: use LazyVim's <leader>cf (conform.nvim, with LSP fallback) + format-on-save.
-- A bare <leader>f mapping shadowed LazyVim's file/find group (<leader>ff, <leader>fr, ...).

-- Navigate to the next location in the location list and recenter
vim.keymap.set("n", "<leader>k", "<cmd>lnext<CR>zz", { desc = "Next location list item (recenter)" })

-- Navigate to the previous location in the location list and recenter
vim.keymap.set("n", "<leader>j", "<cmd>lprev<CR>zz", { desc = "Previous location list item (recenter)" })

-- Search and replace the word under the cursor
-- (<leader>S, not <leader>s, to leave LazyVim's search group on <leader>s)
vim.keymap.set(
  "n",
  "<leader>S",
  [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]],
  { desc = "Substitute word under cursor (global)" }
)

-- Make the current file executable
-- (<leader>X, not <leader>x, to leave LazyVim's diagnostics/quickfix group on <leader>x)
vim.keymap.set("n", "<leader>X", "<cmd>!chmod +x %<CR>", { silent = true, desc = "Make current file executable" })

-- DAP F-key bindings (LazyVim extras.dap.core handles <leader>d* bindings)
vim.keymap.set("n", "<F5>", function() require("dap").continue() end, { desc = "DAP: Continue" })
vim.keymap.set("n", "<F10>", function() require("dap").step_over() end, { desc = "DAP: Step over" })
vim.keymap.set("n", "<F11>", function() require("dap").step_into() end, { desc = "DAP: Step into" })
vim.keymap.set("n", "<F12>", function() require("dap").step_out() end, { desc = "DAP: Step out" })
