# Implemented Settings

This is the current inventory of real Mac Sys Settings 2 features. Keep it updated when adding, removing, or materially changing settings.

## App / General

- Launch at login: turn Mac Sys Settings 2 on when the Mac starts.
- Accessibility status: show whether Accessibility permission is available for window/control features.
- Reset stuck keys: releases stuck shortcut/modifier state after shortcut issues.
- Appearance mode: app light/dark/system styling.
- Dock instant reveal tuning: sets Dock autohide delay/animation faster and can restore defaults.
- Minimize animation tuning: uses the faster native Scale minimize effect.
- Instant Command-M minimize path: shortcut-handled minimize behavior where supported.
- Hide Apple battery icon: optional helper for using the custom battery menu item.
- Hidden apps Dock dimming: setting/helper for making hidden apps visually clearer where possible.

## Menu Bar / Compact Panel

- Main menu bar icon: left click opens compact panel; right click opens custom mode/layout chooser.
- Compact panel: small utility panel with Favorites first and setting category tiles.
- Compact Open button: closes compact panel and opens the full app.
- Custom menu mode chooser: applies layout presets from our own UI, not native menu clutter.
- Battery menu item: shows remaining battery on the left and battery used this week on the right.
- Battery popover: shows today, this week, this month, this year, with outside-click close behavior.

## Screen / Windows

- Move active app between monitors: Control-Option-Arrow based monitor movement.
- Monitor picker/overlays: supports choosing destination monitor when there are more than two.
- Tab-or-window browser move: browser move can ask whether to move tab or whole window when relevant.
- Control-arrow window sizing: left/right cycles half, one-third, two-thirds; up makes a normal full-window fit.
- Full-window edge preservation: tries to preserve touching top/bottom/left/right when moving across monitor sizes.
- Up snap aliases: optional Option-Up/Command-Up aliases for full-window snap.
- Disable macOS Control-arrow Spaces switching: setting path/helper for reducing shortcut conflicts.
- Command-H focused-window hide: optional focused-window behavior instead of hiding every app window.
- Command-Shift-H current monitor hide: hides/restores other apps on the current monitor.
- Fullscreen Escape: Command-Option-Tab helper for switching real fullscreen windows.
- Window switcher: Option-Tab window switcher for real windows, with app cards and optional browser tabs view.
- Window switcher hot corner: optional mouse hot-corner trigger with auto-dismiss unless hovered.
- Browser tab snap: Command-Option-Left/Right splits/snaps active browser tabs.
- Quick opposite-arrow browser snap: Left then Right / Right then Left can arrange current and next browser tab/window.
- YouTube theater after tab snap: can press `T` after a short delay on YouTube tabs.
- Cursor jump overlay: shortcut opens monitor/keypad chooser and moves cursor to a chosen screen point.
- Hover to focus: focus follows hovered windows without clicking.

## Finder / Downloads / Shelf

- Downloads newest-first opener: opens Downloads in list view when new downloads arrive and shows newest at top.
- Finder sort shortcut: shortcut opens Date Created / Date Modified style sorting chooser.
- File shelf: Yoink-style temporary shelf triggered by selected files plus a real shake, with empty auto-close.

## Mic / Audio

- Mic device list: shows available input devices.
- Set default mic: choose system default input device.
- Bluetooth audio input prompt: when an audio Bluetooth device appears, prompt for sound input choice.
- Sound input overlay: shows current mic and available mic choices.

## Layouts / Modes

- Layout presets: build named modes from app, monitor, region, and size rules.
- Menu bar layout apply: apply a mode to the monitor under the mouse.
- Editable templates: Coding, Research, Meeting style layouts can be built from explicit app placements.

## Clipboard / Screenshots

- Screenshot clipboard mode: copies screenshots to clipboard when enabled, with safer copy/latest behavior and warnings around clipboard history managers.

## Autoscroll

- Browser autoscroll overlay: shortcut opens up/down and slow/medium/fast scrolling options.
- Stop autoscroll: same shortcut or control path can stop scrolling.

## Known Manual-Test Items

Use `MANUAL_TEST_QUEUE.md` for hardware/browser/manual verification that automation cannot prove cleanly.

