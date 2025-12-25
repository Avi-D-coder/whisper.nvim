local M = {}

M.insert_text = function(text)
  if not text or text == '' then
    return
  end

  local mode = vim.api.nvim_get_mode().mode

  if mode == 'i' then
    -- Insert mode: insert at cursor
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_get_current_line()
    local new_line = line:sub(1, col) .. text .. line:sub(col + 1)
    vim.api.nvim_set_current_line(new_line)
    vim.api.nvim_win_set_cursor(0, { row, col + #text })
  elseif mode == 'n' then
    -- Normal mode: paste after cursor
    vim.fn.setreg('a', text)
    vim.cmd('normal! "ap')
  elseif mode == 'v' or mode == 'V' or mode == '\22' then -- \22 is visual block mode
    -- Visual mode: replace selection
    vim.cmd('normal! c')
    vim.api.nvim_put({ text }, 'c', true, true)
  end
end

return M
