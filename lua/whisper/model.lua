local M = {}

local MODELS = {
  ['tiny.en'] = {
    url = 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin',
    size = 77 * 1024 * 1024, -- 77 MB
    filename = 'ggml-tiny.en.bin',
  },
  ['base.en'] = {
    url = 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin',
    size = 148 * 1024 * 1024, -- 148 MB
    filename = 'ggml-base.en.bin',
  },
  ['small.en'] = {
    url = 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.en.bin',
    size = 488 * 1024 * 1024, -- 488 MB
    filename = 'ggml-small.en.bin',
  },
  ['medium.en'] = {
    url = 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.en.bin',
    size = 1500 * 1024 * 1024, -- 1.5 GB
    filename = 'ggml-medium.en.bin',
  },
  ['large-v1'] = {
    url = 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v1.bin',
    size = 3100 * 1024 * 1024, -- 3.1 GB
    filename = 'ggml-large-v1.bin',
  },
  ['large-v2'] = {
    url = 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v2.bin',
    size = 3100 * 1024 * 1024, -- 3.1 GB
    filename = 'ggml-large-v2.bin',
  },
  ['large-v3'] = {
    url = 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin',
    size = 3100 * 1024 * 1024, -- 3.1 GB
    filename = 'ggml-large-v3.bin',
  },
}

M.get_model_dir = function()
  local data_path = vim.fn.stdpath('data')
  return data_path .. '/whisper/models'
end

M.ensure_model_dir = function()
  local dir = M.get_model_dir()
  vim.fn.mkdir(dir, 'p')
  return dir
end

M.get_model_path = function(model_name)
  local dir = M.get_model_dir()
  local model_info = MODELS[model_name] or MODELS['base.en']
  return dir .. '/' .. model_info.filename
end

M.model_exists = function(model_name)
  local path = M.get_model_path(model_name)
  return vim.fn.filereadable(path) == 1
end

M.get_model_info = function(model_name)
  return MODELS[model_name]
end

M.download_model = function(model_name, on_progress, on_complete)
  local model_info = MODELS[model_name]
  if not model_info then
    if on_complete then
      on_complete(false, 'Unknown model: ' .. model_name)
    end
    return
  end

  M.ensure_model_dir()
  local dest = M.get_model_path(model_name)

  -- Build curl command with progress
  local cmd = string.format('curl -L -o "%s" "%s" 2>&1', dest, model_info.url)

  -- Show initial notification
  if on_progress then
    on_progress(0)
  end

  -- Run async using vim.loop (libuv)
  local stdout = vim.loop.new_pipe(false)
  local stderr = vim.loop.new_pipe(false)

  local handle
  handle = vim.loop.spawn(
    'sh',
    {
      args = { '-c', cmd },
      stdio = { nil, stdout, stderr },
    },
    vim.schedule_wrap(function(code, signal)
      stdout:read_stop()
      stderr:read_stop()
      stdout:close()
      stderr:close()
      handle:close()

      if code == 0 then
        if on_complete then
          on_complete(true, 'Model downloaded successfully')
        end
      else
        if on_complete then
          on_complete(false, 'Download failed with code: ' .. code)
        end
      end
    end)
  )

  if not handle then
    if on_complete then
      on_complete(false, 'Failed to start download process')
    end
    return
  end

  stdout:read_start(function(err, data) end)
  stderr:read_start(function(err, data) end)

  return handle
end

return M
