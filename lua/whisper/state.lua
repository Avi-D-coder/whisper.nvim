local M = {}

local state = {
  recording = false,
  job_id = nil,
  temp_file = nil,

  -- Streaming state
  poll_timer = nil, -- uv_timer_t handle
  last_read_line = 0, -- Track file position (line number)
  insert_position = nil, -- { buf, row, col } - where to insert next chunk
  recording_buffer = nil, -- Buffer where recording started
  processing = false, -- True when manual trigger is waiting for text
  model_loaded = false, -- True when whisper model is loaded and ready
  trigger_key = nil, -- The configured trigger key
  original_keymaps = nil, -- Original keymaps to restore { n = ..., i = ... }
}

M.is_recording = function()
  return state.recording
end

M.get_job_id = function()
  return state.job_id
end

M.get_temp_file = function()
  return state.temp_file
end

M.set_recording = function(val)
  state.recording = val
end

M.set_job_id = function(id)
  state.job_id = id
end

M.set_temp_file = function(file)
  state.temp_file = file
end

M.get_poll_timer = function()
  return state.poll_timer
end

M.set_poll_timer = function(timer)
  state.poll_timer = timer
end

M.get_last_read_line = function()
  return state.last_read_line
end

M.set_last_read_line = function(line_num)
  state.last_read_line = line_num
end

M.get_insert_position = function()
  return state.insert_position
end

M.set_insert_position = function(pos)
  state.insert_position = pos
end

M.get_recording_buffer = function()
  return state.recording_buffer
end

M.set_recording_buffer = function(buf)
  state.recording_buffer = buf
end

M.is_processing = function()
  return state.processing
end

M.set_processing = function(val)
  state.processing = val
end

M.is_model_loaded = function()
  return state.model_loaded
end

M.set_model_loaded = function(val)
  state.model_loaded = val
end

M.get_trigger_key = function()
  return state.trigger_key
end

M.set_trigger_key = function(key)
  state.trigger_key = key
end

M.get_original_keymaps = function()
  return state.original_keymaps
end

M.set_original_keymaps = function(keymaps)
  state.original_keymaps = keymaps
end

M.clear = function()
  -- Stop timer if running
  if state.poll_timer then
    state.poll_timer:stop()
    state.poll_timer:close()
  end

  -- Remove manual trigger keymaps and restore originals
  if state.recording_buffer and vim.api.nvim_buf_is_valid(state.recording_buffer) and state.trigger_key then
    local key = state.trigger_key
    local buf = state.recording_buffer

    -- Delete our keymaps
    pcall(vim.keymap.del, 'n', key, { buffer = buf })
    pcall(vim.keymap.del, 'i', key, { buffer = buf })

    -- Restore original keymaps if they existed
    if state.original_keymaps then
      if state.original_keymaps.n then
        local m = state.original_keymaps.n
        pcall(vim.keymap.set, 'n', key, m.rhs or m.callback, {
          buffer = buf,
          expr = m.expr,
          silent = m.silent,
          desc = m.desc,
        })
      end
      if state.original_keymaps.i then
        local m = state.original_keymaps.i
        pcall(vim.keymap.set, 'i', key, m.rhs or m.callback, {
          buffer = buf,
          expr = m.expr,
          silent = m.silent,
          desc = m.desc,
        })
      end
    end
  end

  state.recording = false
  state.job_id = nil
  state.temp_file = nil
  state.poll_timer = nil
  state.last_read_line = 0
  state.insert_position = nil
  state.recording_buffer = nil
  state.processing = false
  state.trigger_key = nil
  state.original_keymaps = nil
  -- Don't reset model_loaded - keep it across sessions
end

return M
