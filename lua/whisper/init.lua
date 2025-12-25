local M = {}

M.setup = function(user_config)
  local config = require('whisper.config').setup(user_config)

  -- Set up keybindings
  for _, mode in ipairs(config.modes) do
    vim.keymap.set(mode, config.keybind, function()
      require('whisper.audio').toggle_recording(config)
    end, { desc = 'Toggle speech-to-text recording' })
  end

  -- Register user commands
  vim.api.nvim_create_user_command('WhisperToggle', function()
    require('whisper.audio').toggle_recording(config)
  end, { desc = 'Toggle speech-to-text recording' })

  vim.api.nvim_create_user_command('WhisperDownloadModel', function(opts)
    local model_name = opts.args ~= '' and opts.args or config.model
    M.download_model(model_name)
  end, {
    nargs = '?',
    desc = 'Download a whisper model',
    complete = function()
      return { 'tiny.en', 'base.en', 'small.en', 'medium.en', 'large-v1', 'large-v2', 'large-v3' }
    end,
  })
end

-- Expose commands
M.toggle = function()
  local config = require('whisper.config').get()
  require('whisper.audio').toggle_recording(config)
end

M.download_model = function(model_name)
  local config = require('whisper.config').get()
  local model = require('whisper.model')

  model_name = model_name or config.model

  local model_info = model.get_model_info(model_name)
  if not model_info then
    vim.notify('Unknown model: ' .. model_name, vim.log.levels.ERROR)
    vim.notify(
      'Available models: tiny.en, base.en, small.en, medium.en, large-v1, large-v2, large-v3',
      vim.log.levels.INFO
    )
    return
  end

  if model.model_exists(model_name) then
    vim.notify('Model already exists: ' .. model_name, vim.log.levels.INFO)
    return
  end

  local size_mb = math.floor(model_info.size / 1024 / 1024)
  vim.notify(string.format('Downloading %s model (%d MB)...', model_name, size_mb), vim.log.levels.INFO)

  model.download_model(model_name, function(progress)
    -- Progress callback (currently not used, curl doesn't provide easy progress)
  end, function(success, msg)
    if success then
      vim.notify('Model downloaded: ' .. model_name, vim.log.levels.INFO)
    else
      vim.notify('Download failed: ' .. msg, vim.log.levels.ERROR)
    end
  end)
end

-- Lualine component
M.lualine_component = function()
  local state = require('whisper.state')

  if state.is_processing() then
    return '🎤 Processing...'
  elseif state.is_recording() then
    if state.is_model_loaded() then
      return '🎤 Recording'
    else
      return '🎤 Loading...'
    end
  else
    return ''
  end
end

return M
