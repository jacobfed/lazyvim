-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- C# XML doc comment generation via Roslyn's textDocument/_vs_onAutoInsert.
-- Typing `///` above a method, class, property, etc. will auto-generate a
-- stubbed XML doc comment with <summary>, <param>, <returns>, <typeparam>, etc.
-- Tab/S-Tab navigates between the generated snippet placeholders (via vim.snippet).
vim.api.nvim_create_autocmd("LspAttach", {
  desc = "Roslyn: generate XML doc comments on /// trigger",
  callback = function(args)
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    local bufnr = args.buf

    if not client or (client.name ~= "roslyn" and client.name ~= "roslyn_ls") then
      return
    end

    vim.api.nvim_create_autocmd("InsertCharPre", {
      desc = "Roslyn: trigger _vs_onAutoInsert on '/'",
      buffer = bufnr,
      callback = function()
        local char = vim.v.char

        if char ~= "/" then
          return
        end

        local row, col = unpack(vim.api.nvim_win_get_cursor(0))
        row, col = row - 1, col + 1
        local uri = vim.uri_from_bufnr(bufnr)

        local params = {
          _vs_textDocument = { uri = uri },
          _vs_position = { line = row, character = col },
          _vs_ch = char,
          _vs_options = {
            tabSize = vim.bo[bufnr].tabstop,
            insertSpaces = vim.bo[bufnr].expandtab,
          },
        }

        -- Defer so the buffer reflects the typed character before we send the request.
        vim.defer_fn(function()
          client:request(
            ---@diagnostic disable-next-line: param-type-mismatch
            "textDocument/_vs_onAutoInsert",
            params,
            function(err, result, _)
              if err or not result then
                return
              end

              vim.snippet.expand(result._vs_textEdit.newText)
            end,
            bufnr
          )
        end, 1)
      end,
    })
  end,
})
