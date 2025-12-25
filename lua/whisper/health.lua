local M = {}

M.check = function()
  local health = vim.health or require('health')

  health.start('whisper.nvim')

  local config = require('whisper.config').get()
  local binary = require('whisper.binary')
  local model = require('whisper.model')

  -- Check binary
  local binary_path, err = binary.find_binary(config)
  if binary_path then
    health.ok('whisper-stream found at: ' .. binary_path)

    -- Validate binary
    if binary.validate_binary(binary_path) then
      health.ok('whisper-stream is working')
    else
      health.error('whisper-stream failed validation')
    end
  else
    health.error('whisper-stream not found: ' .. (err or 'unknown error'))
    health.info('Install via: brew install whisper-cpp')
  end

  -- Check model
  local model_path = model.get_model_path(config.model)
  if model.model_exists(config.model) then
    health.ok('Model found: ' .. model_path)
  else
    if config.auto_download_model then
      health.warn('Model not found: ' .. model_path)
      health.info('Will auto-download on first use')
    else
      health.error('Model not found: ' .. model_path)
      health.info('Run :WhisperDownloadModel to download')
    end
  end

  -- Check directories
  local model_dir = model.get_model_dir()
  if vim.fn.isdirectory(model_dir) == 1 then
    health.ok('Model directory: ' .. model_dir)

    -- Check write permissions
    local test_file = model_dir .. '/.test'
    local f = io.open(test_file, 'w')
    if f then
      f:close()
      vim.fn.delete(test_file)
      health.ok('Model directory is writable')
    else
      health.error('Model directory is not writable: ' .. model_dir)
    end
  else
    health.info('Model directory will be created: ' .. model_dir)
  end

  -- Check Neovim version
  local nvim_version = vim.version()
  if nvim_version.major == 0 and nvim_version.minor >= 8 then
    health.ok('Neovim version: ' .. vim.version().major .. '.' .. vim.version().minor)
  else
    health.error('Neovim >= 0.8.0 required')
  end

  -- Future: LLM checks (v0.2+)
  if config.llm and config.llm.enabled then
    health.warn('LLM features not implemented in v0.1')
  end
end

return M
