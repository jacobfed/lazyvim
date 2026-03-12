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
vim.keymap.set({ "n", "v" }, "<leader>d", [["_d]], { desc = "Delete to black hole register" })

-- Format the current buffer using LSP
vim.keymap.set("n", "<leader>f", vim.lsp.buf.format, { desc = "Format buffer (LSP)" })

-- Navigate to the next location in the location list and recenter
vim.keymap.set("n", "<leader>k", "<cmd>lnext<CR>zz", { desc = "Next location list item (recenter)" })

-- Navigate to the previous location in the location list and recenter
vim.keymap.set("n", "<leader>j", "<cmd>lprev<CR>zz", { desc = "Previous location list item (recenter)" })

-- Search and replace the word under the cursor
vim.keymap.set(
  "n",
  "<leader>s",
  [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]],
  { desc = "Substitute word under cursor (global)" }
)

-- Make the current file executable
vim.keymap.set("n", "<leader>x", "<cmd>!chmod +x %<CR>", { silent = true, desc = "Make current file executable" })
