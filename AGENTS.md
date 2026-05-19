# Agent Notes

Read this before changing Mac Sys Settings 2.

## Project

- Xcode project: `Mac Sys Settings 2.xcodeproj`
- Main UI: `MacSysSettings2/ContentView.swift`
- Global screen shortcuts: `MacSysSettings2/ScreenShortcutController.swift`
- Login item support: `MacSysSettings2/LoginItemStore.swift`
- Mic input support: `MacSysSettings2/AudioInputStore.swift`
- Window layout presets: `MacSysSettings2/WindowLayoutStore.swift`

## Product Rules

- Settings pages need section headings and short descriptions.
- Every visible control must do something real, show real state, or be clearly read-only.
- No placeholder categories, dummy buttons, or "coming soon" controls.
- Prefer simple macOS-native rows, toggles, pickers, and status cards.
- If testing moves windows or applies layouts, restore the user's windows afterward.
- Keep `main` protected. Contributors should use branches or forks and open pull requests.

## Current Pages

- App Settings: login item, Accessibility permission, app state.
- Screen: move active app between monitors, shortcut recorder, Control-arrow window sizing, macOS Spaces shortcut toggle.
- Mic: list input devices, choose system default mic, prompt when a new mic appears.
- Layouts: build named presets from app, screen, position, and size rules, then apply them to running apps.

## Adding A Setting

1. Add a case to `SettingsSection`.
2. Add the sidebar title, subtitle, icon, and gradient.
3. Add a detail view using `SettingsPage`, `SettingsSectionBlock`, and `SettingsGroup`.
4. Put macOS/system API logic in a small store/helper file.
5. Build the app.
6. Open the app and visually inspect the page.
7. Verify the setting performs the promised action.

## Build

```sh
xcodebuild -project 'Mac Sys Settings 2.xcodeproj' \
  -scheme 'Mac Sys Settings 2' \
  -configuration Debug \
  -derivedDataPath /tmp/MacSysSettings2LatestBuild \
  build
```

## GitHub Flow For Agents

Never push directly to `main`.

Use this flow:

1. Sync or fork the repo.
2. Create a branch named for the setting or fix.
3. Make the smallest useful change.
4. Build and test.
5. Commit with a clear message.
6. Push your branch or fork.
7. Open a pull request.

Pull request summary format:

```md
## User Summary
- What setting changed or was added.
- How a normal user turns it on or uses it.
- What permission is needed, if any.

## Developer Summary
- Files changed.
- macOS APIs or permissions used.
- Build/test result.
- Known limits or risks.
```

## For Non-Coder Requests

When a non-coder asks for a setting, translate the request into:

- desired behavior
- trigger or shortcut
- system permission needed
- visible UI control
- failure case if macOS blocks it
- test plan

Then implement only what can be made real.

