-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
--- Add any additional keymaps here

-- Move selected lines down in visual mode
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv") -- Move the selected lines down
-- Move selected lines up in visual mode
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv") -- Move the selected lines up

-- Join lines in normal mode and keep cursor position
vim.keymap.set("n", "J", "mzJ`z") -- Join the current line with the next one, preserving cursor position

-- Scroll down and recenter the view
vim.keymap.set("n", "<C-d>", "<C-d>zz") -- Scroll down half a page and center the cursor
-- Scroll up and recenter the view
vim.keymap.set("n", "<C-u>", "<C-u>zz") -- Scroll up half a page and center the cursor

-- Search next and recenter the view
vim.keymap.set("n", "n", "nzzzv") -- Search next occurrence and center the cursor
-- Search previous and recenter the view
vim.keymap.set("n", "N", "Nzzzv") -- Search previous occurrence and center the cursor

-- paste without overwriting the default register
vim.keymap.set("x", "<leader>p", [["_dP]])

-- yank to the system clipboard
vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]]) -- Yank selected text to the system clipboard
vim.keymap.set("n", "<leader>Y", [["+Y]]) -- Yank the entire line to the system clipboard

-- Delete without affecting the default register
vim.keymap.set({ "n", "v" }, "<leader>d", [["_d]]) -- Delete selected text without overwriting the default register

-- Format the current buffer using LSP
vim.keymap.set("n", "<leader>f", vim.lsp.buf.format) -- Format the current buffer

-- Navigate to the next location in the location list and recenter
vim.keymap.set("n", "<leader>k", "<cmd>lnext<CR>zz") -- Go to the next location in the location list
-- Navigate to the previous location in the location list and recenter
vim.keymap.set("n", "<leader>j", "<cmd>lprev<CR>zz") -- Go to the previous location in the location list
-->

-- Search and replace the word under the cursor
vim.keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]]) -- Search and replace the current word

-- Make the current file executable
vim.keymap.set("n", "<leader>x", "<cmd>!chmod +x %<CR>", { silent = true }) -- Change file permissions to make it executable

-- Insert error handling template
vim.keymap.set("n", "<leader>ee", "oif err != nil {<CR>}<Esc>Oreturn err<Esc>") -- Insert error handling code

-- Source the current file
vim.keymap.set("n", "<leader><leader>", function()
  vim.cmd("so") -- Source the current file
end)
