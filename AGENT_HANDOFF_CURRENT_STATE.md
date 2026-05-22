# Agent Handoff Current State

Read this first when taking over Mac Sys Settings 2 from another agent.

This repo is only for Mac Sys Settings 2. Do not pull in Screenshot Gold, Focus Bet, OpenCLaw, or any other local project unless the user explicitly asks. Other agents handle those.

## Product

Mac Sys Settings 2 is a macOS System Settings companion for useful small computer tweaks Apple should have shipped. The app should feel like a serious utility: compact, real, useful, and extensible. It is not a landing page and not a demo playground.

The user wants real settings only. Do not add placeholder pages, dummy buttons, "coming soon" controls, fake toggles, or vague categories.

## Current Architecture

- Main app UI: `MacSysSettings2/ContentView.swift`
- App startup/menu bar controller: `MacSysSettings2/MenuBarController.swift`
- Global window/screen shortcuts: `MacSysSettings2/ScreenShortcutController.swift`
- Shortcut model/recorder support: `MacSysSettings2/ScreenShortcut.swift`
- Compact panel: `MacSysSettings2/CompactPanelController.swift`
- Battery tracking/menu item: `MacSysSettings2/BatteryUsageTracker.swift`, `MacSysSettings2/BatteryMenuStore.swift`, `MacSysSettings2/MenuBarController.swift`
- Mic/audio input: `MacSysSettings2/AudioInputStore.swift`, `MacSysSettings2/BluetoothAudioInputController.swift`, `MacSysSettings2/BluetoothAudioInputPromptStore.swift`
- Window layouts/modes: `MacSysSettings2/WindowLayoutStore.swift`, `MacSysSettings2/ModeChooserPresenter.swift`
- Window switcher: `MacSysSettings2/WindowSwitcherController.swift`, `MacSysSettings2/WindowSwitcherSettingsStore.swift`
- File shelf: `MacSysSettings2/FileShelfController.swift`, `MacSysSettings2/FileShelfStore.swift`, `MacSysSettings2/FileShelfWindowController.swift`
- Downloads helper: `MacSysSettings2/DownloadsWatcherController.swift`, `MacSysSettings2/DownloadsPreviewStore.swift`, `MacSysSettings2/DownloadsPreviewPresenter.swift`
- Hover focus: `MacSysSettings2/HoverFocusController.swift`, `MacSysSettings2/HoverFocusStore.swift`
- Screenshot clipboard: `MacSysSettings2/ScreenshotClipboardController.swift`, `MacSysSettings2/ScreenshotClipboardStore.swift`
- Cursor jump: `MacSysSettings2/CursorJumpController.swift`, `MacSysSettings2/CursorJumpOverlayPresenter.swift`, `MacSysSettings2/CursorJumpStore.swift`
- Finder sort shortcut: `MacSysSettings2/FinderSortShortcutController.swift`, `MacSysSettings2/FinderSortChooserPresenter.swift`, `MacSysSettings2/FinderSortShortcutStore.swift`
- Autoscroll: `MacSysSettings2/AutoScrollController.swift`, `MacSysSettings2/AutoScrollOverlayPresenter.swift`, `MacSysSettings2/AutoScrollStore.swift`

## Live Product Expectations

- App should run as a menu bar utility.
- Compact panel is a first-class surface, not an afterthought.
- Main app and compact panel should not both stay open when one intentionally opens the other.
- Build-only is the default. Do not kill/reinstall/reopen after every build because relaunching refreshes menu bar items and makes the user's menu bar flicker.
- If a feature needs Accessibility, say so plainly and fail safely when permission is missing.

## Important User Preferences

- Keep replies short unless asked for detail.
- Use plain product language, not engineering sludge.
- Preserve exact intent and wording when it affects UI behavior.
- Always restore windows/apps after tests.
- Do not test by wrecking the user's active desktop.
- If using notifications, use the user's custom notification helper only for final/important work updates, not every tiny thought.
- When the user is brainstorming many settings, add them to `SETTINGS_TASK_LIST.md` instead of immediately coding all of them.

## GitHub State

- Repo: `https://github.com/rishabh2d/mac-sys-settings-2`
- `main` is protected.
- Friends/contributors should use branches or forks and PRs.
- Owner/admin can choose to relax protection, but agents should not direct-push to `main` by default.

## When You Start

1. Read `AGENTS.md`.
2. Read `USER_TASTE_AND_PRODUCT_BAR.md`.
3. Read `IMPLEMENTED_SETTINGS.md`.
4. Read `MANUAL_TEST_QUEUE.md` if testing is involved.
5. Read `SETTINGS_TASK_LIST.md` if the user asks what is next.

