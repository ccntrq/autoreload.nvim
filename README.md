# autoreload.nvim

Automatically reload buffers when files are changed externally (for example by
formatters, generators, or git operations), while warning you about conflicts
if you have unsaved changes.


## Requirements

- Neovim >= 0.7

## Features

- Autoreload when files are updated on disk outside Neovim
- Conflict detection when disk changes collide with unsaved buffer edits
- Configurable conflict handling: a blocking prompt, a notification, or silence
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
require("autoreload").setup({
  autoread = true,
  events = { "BufEnter", "FocusGained" },
  timer = {
    enabled = true,
    interval_ms = 3000,
    start_delay_ms = 0,
  },
  conflict = {
    -- How to handle a disk change that collides with unsaved buffer edits:
    --   "prompt" - blocking modal dialog you must answer to proceed
    --   "notify" - non-blocking warning notification (default)
    --   "none"   - keep the buffer silently, do nothing
    strategy = "notify",
    -- Actions offered (and their order) in the "prompt" dialog.
    actions = { "reload", "keep", "diff" },
    -- Action used when the dialog is dismissed with <Esc>.
    default = "keep",
  },
  notify = {
    on_conflict = true,
    on_reload = true,
  },
})
```

### Conflict handling

When a file changes on disk while the buffer has unsaved edits, autoreload
never discards your changes automatically. What happens instead is controlled
by `conflict.strategy`:

- `"prompt"` - show a blocking dialog you must answer before continuing.
- `"notify"` - show a non-blocking warning notification (default).
- `"none"` - keep the buffer as-is and stay silent.

In `"prompt"` mode, `conflict.actions` chooses which options appear (and in
what order). The available actions are:

- `reload` - discard your edits and reload the file from disk.
- `keep` - keep your unsaved edits; the file on disk is left untouched.
- `diff` - open the buffer and the on disk version side by side in diff mode.

`conflict.default` is the action taken when the dialog is dismissed with
`<Esc>` (set it to one of the values listed in `conflict.actions`).

> **Legacy compatibility:** `notify.on_conflict` is still honored when
> `conflict.strategy` is not set - `true` maps to `"notify"` and `false` to
> `"none"`. Prefer `conflict.strategy` in new configs.

## API

- `require("autoreload").setup(opts)`
- `require("autoreload").stop()`

## Notes

- `vim.opt.autoread` is enabled when `autoread = true`.
- If a file is deleted on disk, the buffer is kept (and you are notified) so you
  can save it again to recreate it.

## Related Work

This plugin comes from a setup I used in my own Neovim config for a long time,
now published as a focused Lua plugin.

- Existing Vimscript version: [djoshea/vim-autoread](https://github.com/djoshea/vim-autoread).
