# Implemented Settings

This is the current inventory of real Mac Sys Settings 2 features. Keep it updated when adding, removing, or materially changing settings.

## App / General

- Setup Cost: one permission dashboard for Accessibility, Screen Recording, Input Monitoring, Microphone, Bluetooth, Files and Folders, Automation, and Login Items, with existing setting names listed under each permission.
- Fun: slow-motion Shift animations for old-school Dock/minimize/Mission Control-style macOS animation paths.
- Launch at login: turn Mac Sys Settings 2 on when the Mac starts.
- Accessibility status: show whether Accessibility permission is available for window/control features.
- Reset stuck keys: releases stuck shortcut/modifier state after shortcut issues.
- Appearance mode: app light/dark/system styling.
- System-wide Dark Mode with Notes Light exception: switches the Mac to Dark Mode and offers Notes as the only curated app that can stay light for now.
- Notes light content: controls Notes > Settings > Use dark backgrounds for note content, so all note pages stay white while Notes chrome can remain dark.
- Dock instant reveal tuning: sets Dock autohide delay/animation faster and can restore defaults.
- Minimize animation tuning: uses the faster native Scale minimize effect.
- Instant Command-M minimize path: shortcut-handled minimize behavior where supported.
- Hide Apple battery icon: optional helper for using the custom battery menu item.
- Hidden apps Dock dimming: setting/helper for making hidden apps visually clearer where possible.
- Settings Change History: tracks Mac Sys Settings 2 settings and touched macOS defaults so recent resets are visible.
- Settings Backup: exports/imports safe local preference groups for Mac Sys Settings 2, Finder, Dock, keyboard shortcuts/preferences, selected app preferences, and a privacy status checklist.

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
- Cursor locator ring: Command-Shift-L shows a glowing ring around the current cursor, and Cursor Jump can fire the same ring after landing.
- Hover to focus: focus follows hovered windows without clicking.
- Pin FaceTime: Control-Option-P toggles the focused window above normal windows until pressed again or unpinned. Built for FaceTime, but works for any focused window.
- Auto key press: Control-Option-Command-K opens a key/interval setup dialog when needed, starts repeating the chosen key every selected number of seconds, and stops on the same shortcut.
- Audio tab jump: Control-Option-Command-P finds the Chrome/Safari tab marked as playing audio and focuses it.

## Agent Settings

- Voice Backup: detects mic sessions, records the same microphone input as temporary audio, keeps the last three clips, deletes old session clips on app restart, and transcribes only on demand with a user-provided OpenAI key.

## Presentation / Meetings

- Cursor Highlight: shows live click highlights across Mac apps for demos, meetings, recordings, UX reviews, and tutorials, with size, duration, intensity, right-click/drag visuals, and a test pulse.

## Finder / Downloads / Shelf

- Downloads newest-first opener: opens Downloads in list view when new downloads arrive and shows newest at top.
- Finder sort shortcut: shortcut opens Date Created / Date Modified style sorting chooser.
- Open/Save folder defaults: per-app rules that steer macOS Open/Save/Upload/Import/Export panels to a chosen folder.
- File shelf: Yoink-style temporary shelf triggered by selected files plus a real shake, with empty auto-close.

## Mic / Audio

- Mic device list: shows available input devices.
- Set default mic: choose system default input device.
- Bluetooth audio input prompt: when an audio Bluetooth device appears, prompt for sound input choice.
- Bluetooth off during sleep: turns Bluetooth off when the Mac sleeps and restores it on wake only if Mac Sys Settings 2 turned it off, with warnings for Apple Watch unlock, Bluetooth keyboard/mouse wake, and Find My-style behavior.
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
