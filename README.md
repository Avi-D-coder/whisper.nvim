# whisper.nvim

Speech-to-text for Neovim using whisper.cpp

## Features

- Real-time speech transcription
- Automatic whisper model download
- Text insertion at cursor position
- Works in Normal, Insert, and Visual modes
- Toggle recording mode (press once to start, again to stop)
- `:checkhealth` integration for diagnostics

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
    require('whisper').setup()
  end,
}
```

Or with lazy loading on keybind:

```lua
{
  'Avi-D-coder/whisper.nvim',
  config = function()
    require('whisper').setup({
      model = 'base.en',
      keybind = '<C-g>',
    })
  end,
  keys = {
    { '<C-g>', mode = {'n', 'i', 'v'}, desc = 'Toggle speech-to-text' }
  },
}
```

## Usage

1. Press `<C-g>` (or your configured keybind) to start recording
2. Speak into your microphone
3. **Press Space** to insert the current transcription (continues recording)
4. Press `<C-g>` again to stop recording
5. Transcribed text is inserted at your cursor position

**Auto-insert:** Text is automatically inserted every 20 seconds if you don't manually trigger it.

On first use, the plugin will automatically download the whisper base.en model (~148 MB).

## Configuration

Default configuration:

```lua
require('whisper').setup({
  -- Binary detection
  binary_path = nil,  -- Auto-detect if nil

  -- Model settings
  model = 'base.en',  -- Options: 'tiny.en', 'base.en', 'small.en', 'medium.en', etc.
  auto_download_model = true,

  -- Whisper parameters
  threads = 8,         -- Number of CPU threads (default: 8, adjust based on your CPU)
  step_ms = 20000,     -- Process audio every 20 seconds (battery friendly)
  length_ms = 25000,   -- 25 second audio buffer
  vad_thold = 0.60,    -- Voice activity detection threshold (0.0-1.0)
  language = 'en',

  -- Streaming parameters (v0.1.1)
  enable_streaming = true,      -- Enable manual/auto text insertion
  poll_interval_ms = 20000,     -- Auto-insert every 20 seconds
  filter_markers = true,        -- Remove [BLANK_AUDIO], [MUSIC], (beeping), etc.
  manual_trigger_key = '<Space>', -- Key to manually trigger insertion

  -- UI settings
  show_whisper_output = false,
  notifications = true,

  -- Debug settings
  debug = false,                        -- Enable debug messages
  debug_file = '/tmp/whisper-debug.log', -- Debug log file path

  -- Keybindings
  keybind = '<C-g>',
  modes = {'n', 'i', 'v'},
})
```

### Streaming Behavior

By default (`enable_streaming = true`), you can manually trigger text insertion while recording by pressing **Space**. Text is also automatically inserted every 20 seconds.

**How it works:**
1. Press keybind to start recording
2. **Press Space** to insert current transcription (continues recording)
3. Or wait 20 seconds for auto-insert
4. Press keybind again to stop recording
5. All `[BLANK_AUDIO]`, `[MUSIC]`, `(beeping)`, and similar markers are automatically filtered out

**Manual Trigger Key:**
The `manual_trigger_key` (default: `<Space>`) triggers transcription processing. When you press the trigger key:
1. Shows "Processing..." message
2. Waits for whisper-stream to process the current audio (depends on `step_ms`)
3. Automatically inserts text as soon as it's available
4. In insert mode, still types the original character after inserting transcription

The trigger key is **temporarily hijacked** during recording and **automatically restored** when recording stops. Any existing keybinding on that key will work normally when not recording.

**Important:** The trigger key responsiveness depends on `step_ms`:
- **Default (20s)**: Battery friendly, but Space may take up to 20 seconds to insert text
- **Fast (5s)**: More responsive Space bar, but uses more CPU/GPU
- **Real-time (3s)**: Very responsive, highest CPU/GPU usage

To make Space bar more responsive, set a lower `step_ms`:
```lua
require('whisper').setup({
  step_ms = 5000,   -- Process every 5 seconds (Space responds within 5s)
  length_ms = 8000, -- Increase buffer for better accuracy
})
```

**To disable streaming** (only insert when recording stops):
```lua
require('whisper').setup({
  enable_streaming = false,
})
```

### Performance Tuning

**Battery friendly** (default):
```lua
threads = 8,             -- Use more CPU cores for faster processing
step_ms = 20000,         -- Process every 20 seconds (battery friendly)
length_ms = 25000,       -- 25 second context window
poll_interval_ms = 20000 -- Auto-insert every 20 seconds
```
*Good for: Longer dictation sessions, battery life. Space bar may take up to 20s to respond.*

**Responsive Space bar** (recommended for interactive use):
```lua
threads = 8,             -- Use more CPU cores
step_ms = 5000,          -- Process every 5 seconds
length_ms = 8000,        -- 8 second context window
poll_interval_ms = 20000 -- Auto-insert every 20 seconds
```
*Good for: Quick edits, responsive feedback. Space bar responds within 5s.*

**Very fast, real-time** (higher CPU/GPU usage):
```lua
threads = 8,             -- Use more CPU cores
step_ms = 3000,          -- Process every 3 seconds
length_ms = 5000,        -- 5 second context window
poll_interval_ms = 10000 -- Auto-insert every 10 seconds
```
*Good for: Maximum responsiveness. Space bar responds within 3s. Uses more power.*

**Key parameter explanation:**
- `step_ms`: How often whisper processes audio. **Smaller = Space bar responds faster**, but uses more CPU/GPU
- `length_ms`: Audio context window. Should be larger than step_ms for better accuracy
- `poll_interval_ms`: Auto-insert interval. Can be larger than step_ms since Space provides manual control

**Voice Activity Detection (VAD):**
- `vad_thold = 0.60` (default) - Balanced sensitivity
- `vad_thold = 0.40` - More sensitive (picks up quiet speech)
- `vad_thold = 0.80` - Less sensitive (ignores background noise)

**Note:** You can always press Space to manually insert text at any time, regardless of the auto-insert interval.

## Lualine Integration

You can add a status indicator to your lualine configuration:

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

This will show:
- `🎤 Loading...` when starting first recording session (loading model)
- `🎤 Recording` when actively recording
- `🎤 Processing...` when Space is pressed and waiting for transcription
- Nothing when not recording

**Note:** The model stays loaded in memory after the first recording, so subsequent sessions start immediately without the loading delay.

## Commands

- `:WhisperToggle` - Toggle recording (same as keybind)
- `:WhisperDownloadModel [model]` - Download a specific model
- `:checkhealth whisper` - Check plugin health and configuration

## Troubleshooting

### Check plugin status

```vim
:checkhealth whisper
```

This will verify:
- whisper-stream binary is installed and working
- Models are downloaded
- Directory permissions are correct

### Common Issues

**"whisper-stream not found"**
- Install whisper-cpp: `brew install whisper-cpp`
- Or specify path: `binary_path = '/path/to/whisper-stream'`

**"No speech detected"**
- Check microphone is working
- Speak louder or closer to microphone
- Check system microphone permissions (macOS: System Settings → Privacy & Security → Microphone)

**"Model download failed"**
- Check internet connection
- Manually download from: https://huggingface.co/ggerganov/whisper.cpp
- Place in: `~/.local/share/nvim/whisper/models/`

**"Text not appearing"**
- Press **Space** to manually insert current transcription
- Or wait 30 seconds for auto-insert
- Check that `enable_streaming = true` in config

**"Seeing [BLANK_AUDIO], [MUSIC], or (beeping) markers"**
- Ensure `filter_markers = true` in config (default in v0.1.1+)
- Update to latest version if using v0.1.0

**"Text appears in wrong location"**
- Don't move cursor during recording (text inserts at initial position)
- Or disable streaming: `enable_streaming = false`

**"Trigger key not working"**
- The trigger key (default: Space) only works while recording is active
- In insert mode, the key still types its normal character after inserting transcription
- The trigger keybinding is automatically restored to its original function when recording stops

**Customizing the trigger key:**
```lua
require('whisper').setup({
  manual_trigger_key = '<Tab>',  -- Use Tab instead of Space
})
```

**Debug logging:**
- Enable debug mode: `debug = true` in your config
- View debug log: `cat /tmp/whisper-debug.log` (or `tail -f` for live updates)
- Debug logs to file only (no notification spam)
- Debug log shows:
  - Recording lifecycle events
  - Space bar presses and manual triggers
  - File polling and text insertion attempts
  - whisper-stream stderr output (including Metal GPU usage)

## Models

The plugin supports the following whisper models:

- **tiny.en** (77 MB) - Fastest, good accuracy for English
- **base.en** (148 MB) - Default, good balance of speed and accuracy
- **small.en** (488 MB) - High accuracy, slower

Models are stored in: `~/.local/share/nvim/whisper/models/`

## Platform Support

- **macOS**: Full support (ARM and Intel)
- **Linux**: Full support (tested on Ubuntu, should work on other distributions)

## Requirements

- Neovim >= 0.8.0
- whisper-cpp binary (`whisper-stream`)
- Working microphone
- Internet connection (for initial model download)

## License

MIT + Apache-2.0 License

## Credits

- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) - High-performance inference of OpenAI's Whisper model
- Inspired by the whisper.nvim example in whisper.cpp repository
