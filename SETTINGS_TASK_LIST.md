# Mac Sys Settings 2 Task List

Use this file as the living queue for brainstormed settings. Add ideas here first when the user is discussing many settings, then implement/test them together when asked.

## Workflow

- `Discussed`: idea captured, still needs sharper behavior.
- `Ready`: behavior, UI, shortcut, permission, and test plan are clear.
- `Implemented`: code is added, but testing is not complete.
- `Tested`: built, opened fresh app, tested real behavior, and cleaned up.
- `Blocked by macOS`: normal apps cannot do it reliably; explain the nearest fallback.

## Rules For Agents

- Keep settings real. Do not add placeholder toggles.
- Preserve the user's exact intent and wording when it affects product feel.
- Add optional steps under the parent setting instead of scattering duplicate settings.
- If several settings are listed, implement them as a batch where safe, but test one by one.
- Do not spam progress updates during batch testing. Report final pass/fail summary at the end.
- Stop only for password, permission prompts, destructive changes, or a real macOS limitation.
- Restore user windows, tabs, apps, and system state after tests.

## Current Queue

### 1. Faster Up Snap Aliases

- Status: `Ready`
- Page: `Screen`
- Section: `Window Sizing`
- Setting: optional aliases for the existing full-window snap.
- Trigger: `Option-Up` and/or `Command-Up`.
- Behavior: pressing either enabled alias should do the same thing as `Control-Up`: resize the chosen/focused/window-under-mouse to the usable full screen bounds as a normal window, not macOS fullscreen.
- UI copy idea: "For speed: Up is rarely used in shortcuts, so you can hit whichever Up chord your hand finds first. This avoids slower reasoning-model brain time and keeps it in instant brain-computation mode."
- Permission: Accessibility, same as existing window sizing.
- Test plan: enable each alias, trigger it on a test app, verify full usable bounds, restore/close the test app.

### 2. Keyboard-Only Spelling Helper

- Status: `Discussed`
- Page: `Keyboard` or `Writing`
- Section: `Spelling`
- Setting: fix selected misspelled word without touching the mouse.
- Trigger: likely one tiny shortcut after selecting the word.
- Behavior: user selects a red-underlined word, presses the shortcut, and the app accepts the top macOS spelling suggestion if available.
- Optional steps: if no top suggestion is exposed, show a small suggestions chooser with number keys / arrows / Enter.
- UI copy: "Select the word, press the shortcut, and accept the best correction without leaving the keyboard."
- Permission: Accessibility.
- Test plan: use TextEdit/Notes with a known misspelled word, select it, run shortcut, verify correction, restore/close test note.
- macOS limits: fully automatic correction just from selection is risky and may mutate code/names/slang; keep shortcut confirmation.

### 3. Middle Click / Autoscroll Expansion

- Status: `Implemented`
- Page: `Screen`
- Section: `Autoscroll`
- Setting: browser-style autoscroll with up/down and three speeds.
- Trigger: current fallback is `Control-Option-Command-A`; original double three-finger tap is blocked by macOS global gesture limits.
- Behavior: shortcut opens a tiny overlay with Up/Down and Slow/Medium/Fast; same shortcut stops scrolling.
- Optional steps: add a true middle-click trigger if macOS/input permissions allow it; keep trackpad double-three-finger tap listed as blocked unless a reliable private/API path is found.
- UI copy: "Choose direction and speed. Press the shortcut again to stop."
- Permission: Accessibility/Input Monitoring style event access.
- Test plan: test all six choices in Chrome/Safari on a long page, verify scroll moves and stop works, then restore/close test tab.
- macOS limits: normal apps cannot reliably detect global double three-finger tap.

### 4. Minimize-Only Animation Speed

- Status: `Tested`
- Page: `General`
- Section: `Window Animations`
- Setting: fast minimize animation only.
- Trigger: toggle.
- Behavior: changes Dock minimize effect to `scale`, restarts Dock, and preserves previous effect for restore.
- Optional steps: keep this strictly minimize-only; do not apply broad/global animation defaults.
- UI copy: "Use macOS's faster Scale minimize effect."
- Permission: none.
- Test plan: toggle on, verify `com.apple.dock mineffect = scale`, minimize/restore a test app, clean up.
- macOS limits: macOS does not expose true zero-animation minimize-only; `scale` is the native minimize-specific option.

### 5. Shortcut Conflict Doctor

- Status: `Discussed`
- Page: `General` or `Keyboard`
- Section: `Shortcut Health`
- Setting: detect when app/system shortcuts conflict with Mac Sys Settings 2 shortcuts.
- Trigger: scan button plus passive warnings near shortcut settings.
- Behavior: identify likely conflicts such as browser/app shortcuts, macOS Spaces, Cmd-Tab/Cmd-H behavior, and suggest safer alternatives.
- Optional steps: add "Fix for me" only when macOS exposes a safe settings/defaults path.
- UI copy: "Find shortcuts that may steal or block this setting."
- Permission: mostly none; Accessibility may help detect focused app during a failed shortcut.
- Test plan: enable known conflict, run scan, verify warning and recommendation.

### 6. Plain-Text Paste By Default

- Status: `Discussed`
- Page: `Keyboard` or `Clipboard`
- Section: `Paste`
- Setting: strip formatting/tracking params/extra whitespace when pasting.
- Trigger: configurable shortcut, possible "make Command-V plain text" mode if safe.
- Behavior: paste clipboard text as plain text, with per-app exceptions.
- Optional steps: cleanup URLs, remove tracking params, normalize spaces/newlines.
- UI copy: "Paste clean text everywhere, with exceptions for apps that need rich text."
- Permission: Accessibility/input event access if overriding paste globally.
- Test plan: copy rich text and URL with tracking params, paste into Notes/Chrome/TextEdit, verify cleanup.

### 7. Grandma Layout Presets

- Status: `Implemented`
- Page: `Modes`
- Section: `Layouts`
- Setting: simple app + monitor + region presets without grid complexity.
- Trigger: apply mode button, mode chooser, or menu bar preset menu.
- Behavior: user chooses app, monitor, and region like left half, right half, one-third, two-thirds, full screen. Menu bar presets apply the chosen mode to the display under the mouse.
- Optional steps: "coding", "research", "meeting" templates are editable and built from explicit app/placement rules rather than saving current chaos.
- UI copy: "Build your layout by choosing apps and where they should go."
- Permission: Accessibility.
- Test plan: create preset with two test apps, apply, verify positions, restore/close tests.

### 8. Per-Display Menu Bar / Distraction Profiles

- Status: `Blocked by macOS`
- Page: `Screen`
- Section: `Displays`
- Setting: hide menu bar/Dock/icons for specific focus or display setups where macOS allows it.
- Trigger: toggle/profile.
- Behavior: work mode hides distracting chrome; meeting mode shows only important status items.
- Optional steps: per-monitor menu bar hide stays blocked/research until a reliable allowed macOS path is found; keep only global/profile options as real settings.
- UI copy: "Make one screen quiet without breaking the screen you work on."
- Permission: may require defaults/system settings access; some parts may be macOS-blocked.
- Test plan: apply profile, verify menu bar/Dock/icon behavior, restore defaults.
- macOS limits: per-display menu bar hiding is not fully exposed through normal macOS APIs.

### 9. Dock Instant Reveal Tuning

- Status: `Implemented`
- Page: `General`
- Section: `Dock`
- Setting: tune auto-hidden Dock reveal speed.
- Trigger: toggle plus restore-defaults button.
- Behavior: writes Dock autohide delay to `0`, shortens animation time, restarts Dock, and can delete those override keys to restore defaults.
- Optional steps: do not force Dock autohide on; this only improves speed for users who already auto-hide Dock.
- UI copy: "For auto-hidden Dock users: set Dock reveal delay to zero and shorten the show/hide animation."
- Permission: none.
- Test plan: toggle on, verify Dock defaults, hover hidden Dock edge, restore defaults.

### 10. Fullscreen Escape

- Status: `Implemented`
- Page: `Screen`
- Section: `Fullscreen Escape`
- Setting: better switching between real fullscreen windows.
- Trigger: `Command-Option-Tab`.
- Behavior: cycles through fullscreen windows Accessibility can see and raises the selected one. `Option-Tab` remains reserved for the regular window switcher.
- Optional steps: if macOS blocks a fullscreen Space, fall back to explaining the limitation instead of fake success.
- UI copy: "Use this when a real macOS fullscreen window feels trapped in its own Space."
- Permission: Accessibility.
- Test plan: put two apps in real fullscreen, trigger shortcut, verify switching, then restore test windows.

### 11. Per-App Volume Mixer

- Status: `Discussed`
- Page: `Audio`
- Section: `App Volume`
- Setting: control volume per running app.
- Trigger: menu bar panel plus settings page.
- Behavior: show currently audible/running apps and let the user lower/raise one app without changing system output volume.
- Optional steps: remember per-app defaults; add quick mute for noisy apps.
- UI copy: "Turn one app down without turning your whole Mac down."
- Permission: research needed; may need Audio HAL/private helper or a user-installed audio driver.
- Test plan: play audio in two apps, change only one app volume, verify the other app stays unchanged.
- macOS limits: normal public macOS APIs may not expose per-app volume control cleanly.

### 12. Per-App Audio Output Routing

- Status: `Discussed`
- Page: `Audio`
- Section: `Routing`
- Setting: route chosen apps to chosen speakers/headphones.
- Trigger: per-app output picker.
- Behavior: send Chrome to speakers, Zoom to headphones, music to another output, etc.
- Optional steps: combine with per-app gain/normalization.
- UI copy: "Choose which speaker each app should use."
- Permission: research needed; likely requires a virtual audio device/helper.
- Test plan: route two audio apps to different outputs and verify with real playback.
- macOS limits: likely not possible with only simple public app APIs.

### 13. Always-On-Top Window Toggle

- Status: `Ready`
- Page: `Screen`
- Section: `Window Control`
- Setting: keep the focused window above normal windows.
- Trigger: configurable shortcut plus toggle row.
- Behavior: selected window stays visible above normal app windows until toggled off.
- Optional steps: small floating badge or menu bar list of pinned windows.
- UI copy: "Keep this window on top while you work."
- Permission: Accessibility; may need an overlay/proxy fallback if macOS blocks changing other apps' window levels.
- Test plan: pin a test window, focus other apps, verify pinned window remains above, then unpin.
- macOS limits: true window level changes for other apps may be limited; fallback may be a custom clone/overlay for some cases.

### 14. Custom Window Grid Zones

- Status: `Discussed`
- Page: `Screen`
- Section: `Window Sizing`
- Setting: user-defined snap zones beyond halves/thirds/full.
- Trigger: shortcut or compact zone picker.
- Behavior: user creates named regions like left 40%, right 60%, lower notes strip, or centered writing pane.
- Optional steps: per-monitor zone sets.
- UI copy: "Make your own snap zones for each monitor."
- Permission: Accessibility.
- Test plan: create zones, snap two apps into them, verify positions on both monitors.

### 15. Disable Top-Edge Mission Control Trigger

- Status: `Discussed`
- Page: `Screen`
- Section: `Mission Control`
- Setting: stop accidental Mission Control/App Expose from top-edge or gesture behavior where macOS allows it.
- Trigger: toggle.
- Behavior: reduce accidental activation when the cursor or gesture hits screen edges.
- Optional steps: replace with a custom shortcut/hot corner that only affects the active monitor if possible.
- UI copy: "Stop accidental Mission Control when you hit the top edge."
- Permission: likely none for defaults-backed settings; Accessibility only for fallback gestures.
- Test plan: toggle, hit the top edge / use gesture, verify behavior changed, restore defaults.
- macOS limits: some Mission Control gesture behavior may not be separately controllable per monitor.

### 16. Desktop Icon Reset And Fix

- Status: `Discussed`
- Page: `Finder`
- Section: `Desktop`
- Setting: restore desktop icons when Finder/macOS scatters them or hides them.
- Trigger: reset button plus optional shortcut.
- Behavior: show icons, clean stale positions if possible, and refresh Finder/Desktop.
- Optional steps: save/restore desktop icon layout snapshots.
- UI copy: "Fix a messy or missing Desktop in one click."
- Permission: Finder Automation may be required.
- Test plan: hide/show desktop icons, run reset, verify icons return.

### 17. Click Wallpaper Behavior Control

- Status: `Discussed`
- Page: `Finder`
- Section: `Desktop`
- Setting: control what happens when clicking wallpaper/Desktop.
- Trigger: toggle/profile.
- Behavior: stop unwanted Desktop reveal/focus behavior or make wallpaper clicks intentionally show Desktop.
- Optional steps: per-monitor behavior.
- UI copy: "Choose what a wallpaper click does."
- Permission: research needed.
- Test plan: click wallpaper in different apps/desktops and verify chosen behavior.
- macOS limits: newer macOS Desktop click behavior may be partially controlled by system settings/defaults only.

### 18. Menu Bar Icon Cleanup

- Status: `Discussed`
- Page: `General`
- Section: `Menu Bar`
- Setting: hide/remove noisy menu bar icons and keep useful replacements.
- Trigger: cleanup panel.
- Behavior: show current menu bar/status items, identify removable Apple items, and offer safe hide/fix actions.
- Optional steps: custom Mac Sys Settings 2 replacements like battery usage.
- UI copy: "Clean the menu bar without losing important status."
- Permission: defaults for Apple items; limited access for third-party app icons.
- Test plan: hide a supported Apple item, verify menu bar updates, restore it.
- macOS limits: third-party menu bar icons usually cannot be controlled by another app.

### 19. Real Show Desktop / Minimize Everything

- Status: `Discussed`
- Page: `Screen`
- Section: `Panic`
- Setting: clear visible windows and restore them later.
- Trigger: shortcut or panic menu.
- Behavior: hide/minimize windows on the current monitor or all monitors, then restore positions/order as well as macOS allows.
- Optional steps: pair with Panic Desktop and Save Tonight / Restore Morning.
- UI copy: "Clear the screen now, then bring your setup back."
- Permission: Accessibility.
- Test plan: open several apps, clear, restore, verify window positions.

### 20. Finder New File Here

- Status: `Ready`
- Page: `Finder`
- Section: `Files`
- Setting: create a new file in the current Finder folder.
- Trigger: shortcut plus Finder/context-menu helper.
- Behavior: choose file type such as text, markdown, doc, or custom template; create it in the open folder and select it.
- Optional steps: template library.
- UI copy: "Create a new file right where Finder is open."
- Permission: Finder Automation and file write permission.
- Test plan: open a test folder, create each supported type, verify file appears selected, then delete test files.

### 21. Cmd-Tab / Option-Tab Predictable Restore

- Status: `Discussed`
- Page: `Window Switcher`
- Section: `Switching`
- Setting: make switching restore minimized windows predictably.
- Trigger: custom switcher option.
- Behavior: when choosing an app/window, raise the exact chosen window even if it was minimized.
- Optional steps: exclude Finder, current-monitor first, text cards/thumbnails.
- UI copy: "Switch to the exact window, even if macOS minimized it."
- Permission: Accessibility.
- Test plan: minimize several windows, switch to one, verify it restores and focuses.

### 22. Monitor Sleep / Restart Layout Restore

- Status: `Discussed`
- Page: `Modes`
- Section: `Restore`
- Setting: remember window positions across sleep, restart, display reconnect, or morning setup.
- Trigger: automatic watcher plus Save Tonight / Restore Morning.
- Behavior: save apps, windows, monitors, sizes, and tabs where possible; restore the setup later.
- Optional steps: panic save before shutdown; restore after login.
- UI copy: "Put your workspace back after sleep, unplug, or tomorrow morning."
- Permission: Accessibility; browser tab restore may need AppleScript/browser automation.
- Test plan: save test layout, move windows, restore, verify windows return.

### 23. Separate Natural Scrolling For Mouse And Trackpad

- Status: `Discussed`
- Page: `Input`
- Section: `Scrolling`
- Setting: use different scroll direction for mouse and trackpad.
- Trigger: device-aware toggle.
- Behavior: trackpad can stay natural while mouse uses traditional scroll, or vice versa.
- Optional steps: auto-switch when a device connects.
- UI copy: "Use the scroll direction that makes sense for each device."
- Permission: likely defaults/System Settings; may require helper if macOS stores one global value.
- Test plan: connect mouse and trackpad, scroll in both, verify direction.
- macOS limits: macOS may expose only one global natural-scroll setting without lower-level event rewriting.

### 24. Finder Global Default View / Sort Reset

- Status: `Ready`
- Page: `Finder`
- Section: `Folder Sorting`
- Setting: force Finder folders into preferred view/sort/order defaults.
- Trigger: apply button plus optional folder watcher.
- Behavior: set Downloads/new Finder windows/list view/newest first or user-selected defaults.
- Optional steps: repair all folders; apply only to Downloads; apply to file pickers if possible.
- UI copy: "Make Finder open the way you expect every time."
- Permission: Finder Automation and file permissions for `.DS_Store` updates.
- Test plan: apply to Downloads/test folder, reopen, verify view and sort order.

### 25. Finder Safe Move / Copy Mode

- Status: `Discussed`
- Page: `Finder`
- Section: `File Safety`
- Setting: make copy vs move clearer, especially for external drives.
- Trigger: Finder drag/drop helper or shortcut.
- Behavior: show a small chooser before risky cross-drive file moves/copies.
- Optional steps: temporary undo shelf.
- UI copy: "Know whether Finder is moving or copying before it happens."
- Permission: Finder Automation; deeper drag interception may be blocked.
- Test plan: move/copy test files between local/external locations and verify prompts.
- macOS limits: intercepting native Finder drag/drop globally may not be fully allowed.

### 26. App-Running Focus Rules

- Status: `Discussed`
- Page: `Focus`
- Section: `App Rules`
- Setting: keep a Focus mode active while chosen apps are running.
- Trigger: app launch/quit watcher.
- Behavior: when Zoom/Codex/Chrome profile is open, enable a chosen Focus; turn it off when the app quits.
- Optional steps: per-window-title or meeting detection.
- UI copy: "Turn on the right Focus while this app is open."
- Permission: Shortcuts/Focus integration research needed.
- Test plan: launch/quit a test app, verify Focus mode changes and restores.
- macOS limits: controlling Focus modes may require Shortcuts automation rather than direct public API.

### 27. Quit Apps When Last Window Closes

- Status: `Discussed`
- Page: `General`
- Section: `App Behavior`
- Setting: quit selected apps when their last window closes.
- Trigger: per-app toggle list.
- Behavior: if a chosen app has no open windows, quit it automatically after a short delay.
- Optional steps: exceptions for apps that should keep running in the menu bar.
- UI copy: "Close the last window and the app really quits."
- Permission: Accessibility/AppKit app observation.
- Test plan: close last window of a test app, verify app quits; test excluded app stays running.

### 28. Better External Display Scaling / HiDPI Presets

- Status: `Discussed`
- Page: `Screen`
- Section: `Displays`
- Setting: choose useful display scaling presets faster than System Settings.
- Trigger: preset picker.
- Behavior: list attached displays and apply known safe resolutions/scales.
- Optional steps: per-monitor named profiles.
- UI copy: "Switch display scaling without digging through System Settings."
- Permission: display configuration APIs; may require admin/private APIs for some modes.
- Test plan: apply a safe preset, verify resolution/scale, restore previous mode.
- macOS limits: some HiDPI/scaling controls are private or hardware-dependent.

### 29. External Drive Health Checker

- Status: `Discussed`
- Page: `Finder`
- Section: `Drives`
- Setting: check external drives for health/risk without SIP-breaking drivers.
- Trigger: scan button and connect watcher.
- Behavior: show SMART/volume status where macOS exposes it, plus backup warnings.
- Optional steps: eject reminder and free-space alerts.
- UI copy: "Catch external drive problems before a file move fails."
- Permission: disk utility access; may need command-line helpers.
- Test plan: connect an external drive, scan, verify readable status.
- macOS limits: many USB enclosures do not expose SMART data to macOS.

### 30. Preserve Chrome Layout When Moving Between Monitors

- Status: `Discussed`
- Page: `Screen`
- Section: `Window Movement`
- Setting: make `Control-Option-Left/Right` preserve Chrome's current snap shape when moving between monitors.
- Trigger: `Control-Option-Left` and `Control-Option-Right`.
- Behavior: if Chrome is faux-fullscreen, meaning a normal window touching the usable screen borders like the `Control-Up` version, moving it to another monitor should keep it faux-fullscreen on the destination monitor instead of shrinking or drifting.
- Behavior: if Chrome is left-half or right-half on an external monitor, moving it to the main monitor should keep the same half-screen shape with exact top alignment; no small offset down from the top.
- Behavior: if the user presses a snap shortcut immediately after `Control-Option-Left/Right`, before the monitor move has visually finished, remember that pending snap and apply it after the window lands. Example: press `Control-Option-Right`, then quickly press `Control-Tab-Left/Right/Up`; the app should move the window to the next monitor first, then align it left, right, or full according to the second shortcut.
- Optional steps: for a Chrome YouTube tab/window, after the move finishes and the window is aligned as left-half or right-half, automatically press `T` on that YouTube tab.
- UI copy: "Move Chrome to the other screen without losing its shape."
- Permission: Accessibility; Chrome tab/title detection may need browser scripting permission.
- Test plan: test Chrome faux-fullscreen external -> main and main -> external; test Chrome left-half and right-half external -> main and main -> external; while a monitor move is still in progress, press the left/right/up snap shortcut and verify the final landed window uses that queued alignment; verify exact usable screen edges numerically; test a YouTube tab receives `T` only after the moved window lands and is aligned; restore all Chrome windows/tabs afterward.
- macOS limits: Chrome may report slightly unusual Accessibility frames across monitors; implementation must compare against usable screen bounds and correct final edges after the move.

## Template

### N. Setting Name

- Status: `Discussed`
- Page:
- Section:
- Setting:
- Trigger:
- Behavior:
- Optional steps:
- UI copy:
- Permission:
- Test plan:
- macOS limits:
