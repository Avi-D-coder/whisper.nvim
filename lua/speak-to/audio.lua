local M = {}

local state = require('speak-to.state')
local binary = require('speak-to.binary')
local model = require('speak-to.model')
local insert = require('speak-to.insert')

-- Debug logging helper
local function debug_log(config, message)
  if config and config.debug then
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    local log_message = string.format('[%s] %s', timestamp, message)

    -- Write to debug file only (no notifications)
    if config.debug_file then
      local file = io.open(config.debug_file, 'a')
      if file then
        file:write(log_message .. '\n')
        file:close()
      end
    end
  end
end

-- Clear debug file at start of recording session
local function clear_debug_file(config)
  if config and config.debug and config.debug_file then
    local file = io.open(config.debug_file, 'w')
    if file then
      file:write(string.format('=== speak-to.nvim debug session started at %s ===\n', os.date('%Y-%m-%d %H:%M:%S')))
      file:close()
    end
  end
end

M.toggle_recording = function(config)
  if state.is_recording() then
    M.stop_recording()
  else
    M.start_recording(config)
  end
end

-- Text filtering functions (v0.1.1)
M.filter_text = function(text)
  if not text then
    return ''
  end

  -- Remove all [...] markers
  text = text:gsub('%[.-%]', '')

  -- Remove all (...) markers like (beeping)
  text = text:gsub('%(.-%)', '')

  -- Trim whitespace
  text = text:match('^%s*(.-)%s*$') or ''

  return text
end

M.should_insert_line = function(line)
  local filtered = M.filter_text(line)
  if filtered == '' then
    return false, nil
  end
  return true, filtered
end

-- Incremental text insertion (v0.1.1)
M.insert_streaming_text = function(text)
  local config = require('speak-to.config').get()
  debug_log(config, '>>> insert_streaming_text called with: "' .. (text or 'nil') .. '"')

  if not text or text == '' then
    debug_log(config, 'Text is empty, skipping insertion')
    return
  end

  -- Add space prefix if not first insertion
  if state.get_last_read_line() > 0 then
    text = ' ' .. text
    debug_log(config, 'Added space prefix: "' .. text .. '"')
  end

  local insert_pos = state.get_insert_position()
  if not insert_pos then
    debug_log(config, 'No insert position, using fallback insert.insert_text')
    insert.insert_text(text)
    return
  end

  local buf = insert_pos.buf
  local row = insert_pos.row
  local col = insert_pos.col
  debug_log(config, string.format('Insert position: buf=%d, row=%d, col=%d', buf, row, col))

  -- Validate buffer still exists
  local ok, valid = pcall(vim.api.nvim_buf_is_valid, buf)
  if not ok or not valid then
    debug_log(config, 'Buffer invalid, using fallback insert.insert_text')
    insert.insert_text(text)
    return
  end

  -- Get current line
  local line
  ok, line = pcall(vim.api.nvim_buf_get_lines, buf, row - 1, row, false)
  if not ok or not line or not line[1] then
    debug_log(config, 'Failed to get current line')
    return
  end

  debug_log(config, 'Current line: "' .. line[1] .. '"')

  -- Insert text at position
  local new_line = line[1]:sub(1, col) .. text .. line[1]:sub(col + 1)
  debug_log(config, 'New line: "' .. new_line .. '"')
  pcall(vim.api.nvim_buf_set_lines, buf, row - 1, row, false, { new_line })

  -- Update insert position
  state.set_insert_position({
    buf = buf,
    row = row,
    col = col + #text,
  })
  debug_log(config, 'Updated insert position to col=' .. (col + #text))
  debug_log(config, '<<< insert_streaming_text complete')
end

-- File polling (v0.1.1)
M.poll_transcription_file = function(config)
  debug_log(config, '--- poll_transcription_file called ---')

  local temp_file = state.get_temp_file()
  debug_log(config, 'Temp file: ' .. (temp_file or 'nil'))

  if not temp_file then
    debug_log(config, 'No temp file, skipping poll')
    return
  end

  local readable = vim.fn.filereadable(temp_file)
  debug_log(config, 'File readable: ' .. tostring(readable))

  if readable ~= 1 then
    debug_log(config, 'File not readable, skipping poll')
    return
  end

  -- Read all lines safely
  local ok, lines = pcall(vim.fn.readfile, temp_file)
  if not ok then
    debug_log(config, 'Failed to read file: ' .. tostring(lines))
    return
  end

  if not lines then
    debug_log(config, 'Lines is nil')
    return
  end

  debug_log(config, 'Total lines in file: ' .. #lines)
  local last_read = state.get_last_read_line()
  debug_log(config, 'Last read line: ' .. last_read)
  local new_lines = {}

  -- Collect new lines (1-indexed)
  for i = last_read + 1, #lines do
    debug_log(config, 'Line ' .. i .. ': ' .. lines[i])
    if config.filter_markers then
      local should_insert, filtered = M.should_insert_line(lines[i])
      if should_insert then
        debug_log(config, 'After filter: ' .. filtered)
        table.insert(new_lines, filtered)
      else
        debug_log(config, 'Filtered out (empty after filter)')
      end
    else
      -- No filtering, just trim
      local trimmed = lines[i]:match('^%s*(.-)%s*$') or ''
      if trimmed ~= '' then
        table.insert(new_lines, trimmed)
      end
    end
  end

  debug_log(config, 'New lines to insert: ' .. #new_lines)

  -- Insert new text if any
  if #new_lines > 0 then
    local text = table.concat(new_lines, ' ')
    debug_log(config, 'Inserting text: "' .. text .. '"')
    M.insert_streaming_text(text)
  else
    debug_log(config, 'No new text to insert')
  end

  -- Update position
  state.set_last_read_line(#lines)
  debug_log(config, 'Updated last_read_line to: ' .. #lines)
end

-- Manual trigger for insertion (v0.1.1)
M.manual_trigger_insertion = function()
  local config = require('speak-to.config').get()
  debug_log(config, '=== MANUAL TRIGGER pressed ===')
  if state.is_recording() then
    debug_log(config, 'Recording active, triggering poll')
    if config.enable_streaming then
      -- Set processing state
      state.set_processing(true)

      -- Show processing message
      if config.notifications then
        vim.cmd('echohl WarningMsg | echo "Processing..." | echohl None')
      end

      local last_read_start = state.get_last_read_line()
      local poll_count = 0
      local max_polls = 30 -- Poll for up to 15 seconds (30 * 500ms)

      -- Poll repeatedly until text appears
      local function poll_until_text()
        poll_count = poll_count + 1
        M.poll_transcription_file(config)
        local current_read = state.get_last_read_line()

        if current_read > last_read_start then
          -- Text inserted! Clear message and processing state
          debug_log(config, 'Text found and inserted after ' .. (poll_count * 500) .. 'ms')
          state.set_processing(false)
          if config.notifications then
            vim.cmd('echo ""')
          end
        elseif poll_count < max_polls then
          -- Keep polling
          vim.defer_fn(poll_until_text, 500)
        else
          -- Timeout - no text after 15 seconds
          debug_log(config, 'Timeout: no new text after 15 seconds')
          state.set_processing(false)
          if config.notifications then
            vim.cmd('echohl WarningMsg | echo "No transcription (silence or timeout)" | echohl None')
            vim.defer_fn(function() vim.cmd('echo ""') end, 2000)
          end
        end
      end

      -- Start polling immediately
      poll_until_text()
    else
      debug_log(config, 'Streaming disabled, ignoring manual trigger')
    end
  else
    debug_log(config, 'Not recording, ignoring manual trigger')
  end
end

-- Timer management (v0.1.1)
M.start_polling = function(config)
  debug_log(config, '*** Starting polling timer ***')
  local timer = vim.loop.new_timer()
  local poll_interval = config.poll_interval_ms or 30000
  debug_log(config, 'Poll interval: ' .. poll_interval .. 'ms')

  timer:start(
    poll_interval,
    poll_interval,
    vim.schedule_wrap(function()
      debug_log(config, '### TIMER FIRED (auto-insert) ###')
      if not state.is_recording() then
        debug_log(config, 'Not recording, stopping timer')
        timer:stop()
        timer:close()
        return
      end
      M.poll_transcription_file(config)
    end)
  )

  state.set_poll_timer(timer)
  debug_log(config, 'Timer started successfully')
end

M.stop_polling = function(config)
  local timer = state.get_poll_timer()
  if timer then
    timer:stop()
    timer:close()
    state.set_poll_timer(nil)
  end

  -- Final poll to catch remaining text
  M.poll_transcription_file(config)
end

M.start_recording = function(config)
  -- Clear debug file for fresh session
  clear_debug_file(config)
  debug_log(config, '@@@ START_RECORDING called @@@')

  -- Check prerequisites
  local binary_path, err = binary.find_binary(config)
  if not binary_path then
    vim.notify('whisper-stream not found. Install via: brew install whisper-cpp', vim.log.levels.ERROR)
    return
  end
  debug_log(config, 'Binary path: ' .. binary_path)

  local model_path = model.get_model_path(config.model)
  if not model.model_exists(config.model) then
    if config.auto_download_model then
      local model_info = model.get_model_info(config.model)
      local size_mb = math.floor(model_info.size / 1024 / 1024)
      vim.notify(
        string.format('Downloading %s model (%d MB)...', config.model, size_mb),
        vim.log.levels.INFO
      )

      model.download_model(config.model, nil, function(success, msg)
        if success then
          vim.notify('Model downloaded successfully!', vim.log.levels.INFO)
          M.start_recording(config) -- Retry after download
        else
          vim.notify('Model download failed: ' .. msg, vim.log.levels.ERROR)
        end
      end)
      return
    else
      vim.notify('Model not found. Run :SpeakToDownloadModel to download.', vim.log.levels.ERROR)
      return
    end
  end

  -- Create temp file for output
  local temp_file = vim.fn.tempname()
  state.set_temp_file(temp_file)

  -- Initialize streaming state if enabled (v0.1.1)
  if config.enable_streaming then
    debug_log(config, 'Streaming enabled, setting up state')
    local win = vim.api.nvim_get_current_win()
    local buf = vim.api.nvim_win_get_buf(win)
    local cursor = vim.api.nvim_win_get_cursor(win)

    debug_log(config, string.format('Initial cursor position: row=%d, col=%d', cursor[1], cursor[2]))

    state.set_insert_position({
      buf = buf,
      row = cursor[1],
      col = cursor[2],
    })

    state.set_last_read_line(0)
    state.set_recording_buffer(buf)

    -- Set up manual trigger keybind (space bar triggers insertion)
    local trigger_desc = 'Insert transcribed text'
    debug_log(config, 'Setting up Space keybind for buffer ' .. buf)
    vim.keymap.set('n', '<Space>', M.manual_trigger_insertion, { buffer = buf, desc = trigger_desc })
    vim.keymap.set('i', '<Space>', function()
      M.manual_trigger_insertion()
      return '<Space>' -- Still insert the space character in insert mode
    end, { buffer = buf, expr = true, desc = trigger_desc })
    debug_log(config, 'Space keybind configured')
  else
    debug_log(config, 'Streaming disabled')
  end

  -- Build command (v0.1.1: added vad_thold)
  local cmd = string.format(
    '%s -m "%s" -t %d --step %d --length %d --vad-thold %.2f -f "%s"',
    binary_path,
    model_path,
    config.threads or 4,
    config.step_ms or 15000,
    config.length_ms or 30000,
    config.vad_thold or 0.60,
    temp_file
  )

  -- Add language if specified
  if config.language then
    cmd = cmd .. ' -l ' .. config.language
  end

  -- Show loading message if model not loaded yet
  if not state.is_model_loaded() and config.notifications then
    vim.notify('Loading model...', vim.log.levels.INFO)
  end

  -- Start process using jobstart (non-blocking)
  debug_log(config, 'Starting whisper-stream job with command: ' .. cmd)
  local job_id = vim.fn.jobstart(cmd, {
    on_stderr = function(_, data)
      if data then
        vim.schedule(function()
          for _, line in ipairs(data) do
            if line ~= '' then
              -- Debug log all stderr
              if config.debug then
                debug_log(config, '[whisper-stream stderr] ' .. line)
              end

              -- Detect when model is ready (look for "main: processing" message)
              if not state.is_model_loaded() and line:match('main: processing') then
                state.set_model_loaded(true)
                if config.notifications then
                  vim.notify('Ready to record', vim.log.levels.INFO)
                end
                debug_log(config, 'Model loaded and ready')
              end
            end
          end
        end)
      end
    end,
    on_exit = function(_, exit_code)
      vim.schedule(function()
        debug_log(config, 'Job exited with code: ' .. exit_code)
        if exit_code == 0 or exit_code == 143 then -- 143 is SIGTERM
          M.on_recording_complete(temp_file, config)
        else
          vim.notify('Recording failed with exit code: ' .. exit_code, vim.log.levels.ERROR)
        end
        state.clear()
      end)
    end,
  })

  if job_id <= 0 then
    vim.notify('Failed to start recording', vim.log.levels.ERROR)
    debug_log(config, 'Failed to start job, job_id=' .. job_id)
    return
  end

  debug_log(config, 'Job started successfully, job_id=' .. job_id)
  state.set_job_id(job_id)
  state.set_recording(true)

  -- Start polling if streaming enabled (v0.1.1)
  if config.enable_streaming then
    M.start_polling(config)
  end

  if config.notifications then
    vim.notify(
      'Recording... (Space=insert text now, ' .. config.keybind .. '=stop)',
      vim.log.levels.INFO
    )
  end
end

M.stop_recording = function()
  local config = require('speak-to.config').get()
  debug_log(config, '@@@ STOP_RECORDING called @@@')

  local job_id = state.get_job_id()
  if job_id then
    debug_log(config, 'Stopping job_id=' .. job_id)
    -- Stop polling first if streaming enabled (v0.1.1)
    if config.enable_streaming then
      debug_log(config, 'Stopping polling timer')
      M.stop_polling(config)
    end

    vim.fn.jobstop(job_id) -- Send SIGTERM, triggers on_exit
    debug_log(config, 'Sent SIGTERM to job')
  else
    debug_log(config, 'No job_id found, nothing to stop')
  end
end

M.on_recording_complete = function(temp_file, config)
  -- For non-streaming mode, use old behavior (v0.1.1)
  if not config.enable_streaming then
    local lines = vim.fn.readfile(temp_file)
    if #lines == 0 then
      if config.notifications then
        vim.notify('No transcription result', vim.log.levels.WARN)
      end
      vim.fn.delete(temp_file)
      return
    end

    local text = lines[#lines]

    -- Apply filtering if enabled
    if config.filter_markers then
      text = M.filter_text(text)
    else
      text = text:match('^%s*(.-)%s*$')
    end

    if text == '' then
      if config.notifications then
        vim.notify('Transcription was empty', vim.log.levels.WARN)
      end
      vim.fn.delete(temp_file)
      return
    end

    insert.insert_text(text)

    if config.notifications then
      vim.notify('Transcribed: ' .. text:sub(1, 50) .. (text:len() > 50 and '...' or ''), vim.log.levels.INFO)
    end
  else
    -- Streaming mode: just notify completion
    if config.notifications then
      vim.notify('Transcription complete', vim.log.levels.INFO)
    end
  end

  -- Cleanup temp file
  vim.fn.delete(temp_file)
end

return M
