# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## v1.0.0 - 2026-06-24
### Added
* Automatic buffer reload when files change on disk outside Neovim.
* Conflict detection with a warning notification when disk changes collide with unsaved buffer edits.
* Event-based checks on `BufEnter` and `FocusGained`, configurable via the `events` option.
* Optional timer-based periodic `checktime` checks with a configurable interval and start delay.
* Configurable reload and conflict notifications via `notify.on_reload` and `notify.on_conflict`.
* Public API with `setup(opts)` to configure the plugin and `stop()` to tear it down.
