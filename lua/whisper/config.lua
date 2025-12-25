local M = {}

M.defaults = {
  -- Binary detection
  binary_path = nil, -- Auto-detect if nil

  -- Model settings
  model = 'base.en', -- Options: 'tiny.en', 'base.en', 'small.en', 'medium.en', 'large-v1', 'large-v2', 'large-v3'
  auto_download_model = true,

  -- Whisper parameters
  threads = 8, -- Increased from 4 to use more CPU cores (system has 16)
  step_ms = 20000, -- Process audio every 20 seconds (battery friendly, use smaller value for faster Space bar)
  length_ms = 25000, -- 25 second audio buffer (longer context than step for overlap)
  vad_thold = 0.60, -- Voice activity detection threshold (0.0-1.0)
  language = 'en',

  -- Streaming parameters (v0.1.1)
  enable_streaming = true, -- Incrementally insert text as it's transcribed
  poll_interval_ms = 20000, -- Auto-insert every 20 seconds
  filter_markers = true, -- Remove [BLANK_AUDIO], [MUSIC], (beeping), etc.
  manual_trigger_key = '<Space>', -- Key to manually trigger inference during recording

  -- UI settings
  show_whisper_output = false,
  notifications = true,
  debug = false, -- Enable debug messages
  debug_file = '/tmp/whisper-debug.log', -- Debug log file path

  -- Keybindings
  keybind = '<C-g>',
  modes = { 'n', 'i', 'v' },

  -- Future: LLM settings (v0.2+)
  llm = {
    enabled = false, -- Not implemented in v0.1
  },
}

M.config = nil

M.setup = function(user_config)
  M.config = vim.tbl_deep_extend('force', M.defaults, user_config or {})
  return M.config
end

M.get = function()
  return M.config or M.defaults
end

return M
