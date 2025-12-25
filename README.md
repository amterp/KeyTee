# KeyTee

A macOS menu bar app that captures your keystrokes as a safety net for recovering lost text. Named after the Unix `tee` command, it silently copies your typing to a recoverable buffer while you work.

## Installation

```bash
brew install amterp/tap/keytee
```

Since KeyTee isn't signed with an Apple Developer certificate, you'll need to remove the quarantine flag before first launch:

```bash
xattr -cr /Applications/KeyTee.app
```

## Setup

KeyTee requires Accessibility permission to capture keystrokes:

1. Open KeyTee from Applications
2. Follow the onboarding prompt to grant Accessibility access
3. KeyTee will appear in your menu bar

## Usage

- **Menu bar icon** — Click to access the dropdown menu
- **Open KeyTee** — View captured text, organized by app/window
- **Pause/Resume** — Temporarily stop capturing
- **Settings** — Configure retention period, segmentation timeout, and more

## Configuration

Settings are stored in `~/.config/keytee/config.toml` and can be edited directly or via the Settings UI.

## License

MIT
