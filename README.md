# autoreload.nvim

Automatically reload buffers when files are changed externally (for example by
formatters, generators, or git operations), while warning you about conflicts
if you have unsaved changes.


## Requirements

- Neovim >= 0.7

## Features

- Autoreload when files are updated on disk outside Neovim
- Conflict detection when disk changes collide with unsaved buffer edits
- Safe `checktime` execution (skips command-line mode and command-line window)
- Intended for normal file buffers (`buftype == ""`); special buffers are
  skipped
- Event-based checks (`BufEnter`, `FocusGained` by default)
- Additional timer-based checks
- Conflict/reload notifications

## Usage

![Watch Demo](https://github.com/ccntrq/autoreload.nvim/raw/master/demo.gif)

### Install with lazy.nvim

```lua
{
  "ccntrq/autoreload.nvim",
  opts = {}, -- make sure setup is called with defaults
}
```

### Configure

You can change any of the default options:

```lua
require("autoreload.nvim").setup({
  autoread = true,
  events = { "BufEnter", "FocusGained" },
  timer = {
    enabled = true,
    interval_ms = 3000,
    start_delay_ms = 0,
  },
  notify = {
    on_conflict = true,
    on_reload = true,
  },
})
```

## API

- `require("autoreload.nvim").setup(opts)`
- `require("autoreload.nvim").stop()`

## Notes

- `vim.opt.autoread` is enabled when `autoread = true`.

## Related Work

This plugin comes from a setup I used in my own Neovim config for a long time,
now published as a focused Lua plugin.

- Existing Vimscript version: [djoshea/vim-autoread](https://github.com/djoshea/vim-autoread).
changes
more changes
