-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

vim.opt.fillchars:append({
  vert = "┃",
})

vim.g.loaded_perl_provider = 0
vim.g.loaded_ruby_provider = 0

vim.opt.title = true

-- Title shows the git branch, reused from gitsigns (which already computes it for
-- lualine) so we don't spawn `git` on every BufEnter. Falls back to the cwd name
-- until gitsigns resolves the head; the GitSignsUpdate autocmd refreshes it then.
local function update_title()
  -- Prefer the buffer head (set before gitsigns fires GitSignsUpdate); fall back to
  -- the global cwd head, then the cwd name.
  local branch = vim.b.gitsigns_head
  if not branch or branch == "" then
    branch = vim.g.gitsigns_head
  end
  if branch and branch ~= "" then
    vim.opt.titlestring = branch
  else
    vim.opt.titlestring = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
  end
end

local title_group = vim.api.nvim_create_augroup("user_titlestring", { clear = true })

vim.api.nvim_create_autocmd({ "BufEnter", "DirChanged", "FocusGained" }, {
  group = title_group,
  callback = update_title,
})

-- gitsigns fires this once it resolves or changes the current head.
vim.api.nvim_create_autocmd("User", {
  group = title_group,
  pattern = "GitSignsUpdate",
  callback = update_title,
})
