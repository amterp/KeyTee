# KeyTee — Specification

## Overview

KeyTee is a macOS menu bar application that continuously captures keystrokes in the background, providing a safety net for recovering text lost to application crashes, browser glitches, or accidental navigation. Named after the Unix `tee` command, it silently copies your typing to a recoverable buffer while you work.

**Target users:** The developer (primary), plus anyone who finds it via the open-source repo.

**Distribution:** Open source on GitHub, installed via Homebrew. Requires Accessibility permissions.

---

## Requirements

### Keystroke Capture

1. **Capture printable characters** — letters, numbers, punctuation, whitespace, enter/return.

2. **Capture paste content** — When the user pastes (Cmd+V), capture the pasted text from the clipboard, not just the keystroke.

3. **Skip modifier-only shortcuts** — Do not log Cmd+C, Cmd+Z, etc. as text. Only capture keystrokes that produce text output.

4. **Skip password fields** — Best-effort detection of password/secure input fields. If the active field is a secure text field, do not capture. If detection isn't feasible, accept the limitation and rely on security practices (encryption, short retention).

5. **Simple text reconstruction** — Process backspaces by deleting the previous character. Do not attempt to handle arrow keys, mouse repositioning, or selection-replacement. Accept that complex editing may produce imperfect reconstruction.

6. **Exclude KeyTee itself** — Do not capture keystrokes or pastes made within the KeyTee app to avoid feedback loops.

### Grouping & Context

7. **Track active app and window** — For each captured segment, record the frontmost application name and window title (e.g., "VS Code — main.swift", "Safari — Claude.ai").

8. **Bucket by app/window** — Group captured text into buckets by app/window context. When the user switches contexts, start appending to the appropriate bucket.

9. **Inactivity segmentation** — Within a bucket, if no text-affecting input is captured for 5 minutes (configurable), subsequent input starts a new segment rather than appending to the previous one. This prevents unrelated typing sessions (e.g., morning vs. evening) from being treated as one continuous blob. Each bucket may contain multiple segments, displayed separately in the UI.

### Retention & Storage

10. **Default 24-hour retention** — Automatically discard captured text older than 24 hours. Retention period is configurable.

11. **Memory-only by default** — Store captured text in memory. If the app quits or the system reboots, captured text is lost.

12. **Opt-in disk persistence** — User can enable disk storage in settings. When enabled:
    - Periodically flush captured text to disk
    - Encrypt using a key stored in macOS Keychain (no user-provided password)
    - Respect the same retention period (auto-delete expired data)

### User Interface

13. **Menu bar icon** — App lives in the menu bar. Static icon when active, orange/yellow icon when paused.

14. **Main window** — Clicking the menu bar icon opens a window displaying:
    - **"All" view** — Concatenated text from all buckets/segments, in chronological order (default view)
    - **Bucket list** — List of app/window buckets, sorted by most recently active (with option to sort alphabetically)
    - Selecting a bucket shows its segments, each displayed separately
    - Copy button to copy text to clipboard

15. **Clear functionality** — User can clear individual buckets or clear all history.

16. **Pause/resume toggle** — Menu bar dropdown includes a toggle to pause capture. While paused, no keystrokes are logged and the icon changes color.

17. **Settings UI** — Accessible from menu bar dropdown. Allows configuration of:
    - Retention period
    - Inactivity timeout (for segmentation)
    - Disk persistence on/off
    - Launch at login on/off
    - (Future: app blacklist)

### Settings & Configuration

18. **Config file location** — `~/.config/keytee/config.toml`

19. **Human-readable format** — TOML format, easy to edit manually or via the settings UI. Friendly to version control and symlinking.

20. **Settings UI writes to file** — The settings UI reads from and writes to the config file. No separate storage.

### Operational Behavior

21. **Launch at login** — Enabled by default. Configurable via settings (standard macOS approach via Login Items).

22. **Accessibility permission onboarding** — On first launch, guide the user through granting Accessibility permission. Provide clear instructions and a button to open System Settings to the correct pane.

### Code & Documentation

23. **Swift/SwiftUI** — Use modern Apple frameworks.

24. **Commented for newcomers** — Code should be well-commented assuming the reader is an experienced software engineer but unfamiliar with Swift, SwiftUI, and macOS development patterns. Explain Apple-specific idioms.

---

## Future Extensions (Not in MVP)

- **App blacklist** — Allow users to exclude specific apps from capture via settings.
- **Search/filter** — Search within captured text.
- **Keyboard shortcut to open** — Configurable hotkey to summon the window.

---

## Open Questions / Risks

1. **Password field detection reliability** — macOS Accessibility APIs should expose whether a field is secure, but this depends on apps implementing it correctly. Non-native apps (Electron, etc.) may not. Risk: some passwords may be captured. Mitigation: short retention, encryption, user awareness.

2. **Accessibility permission UX** — Users must manually grant permission in System Settings. This is friction, but unavoidable for system-wide keyboard capture. Mitigation: clear onboarding flow.

3. **Performance** — Keystroke capture must be lightweight enough to run continuously without noticeable impact. Risk is low for this use case (keystrokes are infrequent relative to CPU speed), but worth validating.

---

## Design Decisions & Rationale

| Decision | Rationale |
|----------|-----------|
| **Simple backspace reconstruction only** | Handling arrow keys and mouse repositioning would require tracking cursor state, which we can't reliably do without deeper integration. Backspace covers the common "typed linearly, fixed typos" case. |
| **Memory-only by default** | Minimizes security exposure. Users who want persistence can opt in with full awareness. |
| **Keychain for encryption** | Avoids password fatigue. The realistic threat model is "stolen locked laptop" — Keychain handles this. An attacker with an unlocked session could install their own keylogger anyway. |
| **TOML config in ~/.config/** | Human-readable, diffable, symlink-friendly for users who sync dotfiles via git. TOML is less verbose than JSON and avoids YAML's quirks. |
| **Bucket by app+window, not just app** | Users often have multiple windows/tabs. "Safari — Claude.ai" vs "Safari — Gmail" are meaningfully different contexts. |
| **Exclude KeyTee from capture** | Prevents confusing loops where copying recovered text re-logs it. |
| **No App Store** | System-wide keyboard capture would not pass App Store review. Homebrew distribution is appropriate for power-user tools requiring elevated permissions. |
| **5-minute inactivity segmentation** | Typing in the same app hours apart shouldn't be one continuous blob. 5 minutes is long enough to not split mid-thought pauses, short enough to separate distinct sessions. Configurable for user preference. |
