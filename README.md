# whisper.nvim

Speech-to-text for Neovim using whisper.cpp.

Press `<C-g>` to toggle recording. Press `<Space>` to process and insert transcription at your cursor.

## Usage

1. Press `<C-g>` to start recording
2. Speak into your microphone
3. Press `<Space>` to insert transcription (continues recording)
4. Press `<C-g>` again to stop recording

Text is also auto-inserted every 20 seconds if you don't manually trigger it.

On first use, the plugin downloads the whisper base.en model (~148 MB).

## Installation

### 1. Install whisper.cpp

```bash
# macOS
brew install whisper-cpp

# Linux
# Use your distribution's package manager or build from source
# https://github.com/ggerganov/whisper.cpp
```

### 2. Install plugin with lazy.nvim

```lua
{
  'Avi-D-coder/whisper.nvim',
  config = function()
    require('whisper').setup({
      model = 'base.en',
      keybind = '<C-g>',
      manual_trigger_key = '<Space>',
    })
  end,
  keys = {
    { '<C-g>', mode = {'n', 'i', 'v'}, desc = 'Toggle speech-to-text' }
  },
}
```

## Configuration

Default configuration:

```lua
require('whisper').setup({
  -- Binary detection
  binary_path = nil,  -- Auto-detect if nil

  -- Model settings
  model = 'base.en',  -- Options: 'tiny.en', 'base.en', 'small.en', 'medium.en', etc.
  auto_download_model = true,

  -- Keybindings
  keybind = '<C-g>',
  manual_trigger_key = '<Space>',
  modes = {'n', 'i', 'v'},

  -- Whisper parameters
  threads = 8,         -- Number of CPU threads
  step_ms = 20000,     -- Process audio every 20 seconds
  length_ms = 25000,   -- 25 second audio buffer
  vad_thold = 0.60,    -- Voice activity detection threshold (0.0-1.0)
  language = 'en',

  -- Streaming parameters
  enable_streaming = true,
  poll_interval_ms = 20000,     -- Auto-insert every 20 seconds
  filter_markers = true,        -- Remove [BLANK_AUDIO], [MUSIC], etc.

  -- UI settings
  show_whisper_output = false,
  notifications = true,

  -- Debug settings
  debug = false,
  debug_file = '/tmp/whisper-debug.log',
})
```

### Performance Tuning

The trigger key responsiveness depends on `step_ms`:

**Battery friendly** (default):
```lua
step_ms = 20000,  -- Space may take up to 20s to respond
```

**Responsive** (recommended for interactive use):
```lua
step_ms = 5000,
length_ms = 8000,
```

**Real-time** (higher CPU usage):
```lua
step_ms = 3000,
length_ms = 5000,
```

## Lualine Integration

```lua
require('lualine').setup({
  sections = {
    lualine_x = {
      require('whisper').lualine_component,
      'encoding',
      'fileformat',
      'filetype'
    }
  }
})
```

Shows: `🎤 Loading...`, `🎤 Recording`, or `🎤 Processing...`

## Commands

- `:WhisperToggle` - Toggle recording
- `:WhisperDownloadModel [model]` - Download a specific model
- `:checkhealth whisper` - Check plugin health

## Troubleshooting

Run `:checkhealth whisper` to verify setup.

**"whisper-stream not found"**
- Install whisper-cpp: `brew install whisper-cpp`

**"No speech detected"**
- Check microphone permissions (macOS: System Settings → Privacy & Security → Microphone)

**"Model download failed"**
- Manually download from: https://huggingface.co/ggerganov/whisper.cpp
- Place in: `~/.local/share/nvim/whisper/models/`

## Models

- **tiny.en** (77 MB) - Fastest
- **base.en** (148 MB) - Default, good balance
- **small.en** (488 MB) - Most accurate

Models stored in: `~/.local/share/nvim/whisper/models/`

## Requirements

- Neovim >= 0.8.0
- whisper-cpp (`whisper-stream`)
- Working microphone

## License

MIT + Apache-2.0

## Credits

- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) - High-performance inference of OpenAI's Whisper model
- Inspired by the [whisper.nvim example](https://github.com/ggml-org/whisper.cpp/tree/master/examples/whisper.nvim) in whisper.cpp repository
