local M = {}

M.find_binary = function(config)
  -- Priority 1: User-configured path
  if config.binary_path and vim.fn.executable(config.binary_path) == 1 then
    return config.binary_path
  end

  -- Priority 2: Standard locations
  local paths = {
    '/opt/homebrew/bin/whisper-stream', -- macOS ARM
    '/usr/local/bin/whisper-stream', -- macOS Intel, Linux brew
    '/usr/bin/whisper-stream', -- Linux package
  }

  for _, path in ipairs(paths) do
    if vim.fn.executable(path) == 1 then
      return path
    end
  end

  -- Priority 3: System PATH
  if vim.fn.executable('whisper-stream') == 1 then
    return 'whisper-stream'
  end

  return nil, 'whisper-stream binary not found'
end

M.validate_binary = function(binary_path)
  -- Run with --help to verify it works
  local result = vim.fn.system(binary_path .. ' --help 2>&1')
  return result:match('usage:') ~= nil or result:match('Usage:') ~= nil
end

return M
