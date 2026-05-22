# Agent Notes

Read this before changing Mac Sys Settings 2.

For a smooth handoff from a prior agent, read `AGENT_HANDOFF_CURRENT_STATE.md` first, then `USER_TASTE_AND_PRODUCT_BAR.md`, then `IMPLEMENTED_SETTINGS.md`.

Before testing any change, read `AGENT_TESTING.md`. In this project, "test" means build, run the fresh app only when needed for the requested verification, verify real behavior, fix, rebuild, and repeat until success or a concrete macOS blocker.

If you are helping a new friend download or join the project, read `FRIEND_ONBOARDING.md` before you speak to them. Use its greeting and keep the first explanation short, warm, and non-technical.

If the user asks for the greeting message, read `GREETING_MESSAGE.md` and use that copy. Keep it scoped to Mac Sys Settings 2 only.

If a user asks how to tell friends about the project, read `SHARE_WITH_FRIENDS.md` and give them the copy-paste message from that file.

If the user discusses several possible settings and says to add them to the task list, use `SETTINGS_TASK_LIST.md`. Add each idea there first instead of implementing immediately. When the user later asks to do the list, implement the listed items as a batch, test them one by one, and report only the final concise summary unless there is a password, permission, or macOS-blocker.

If the user asks "what should we build next?" or references the latest research shortlist, read `RESEARCH_SHORTLIST.md` and avoid repeating ignored/low-priority ideas.

## Project

- Xcode project: `Mac Sys Settings 2.xcodeproj`
- Main UI: `MacSysSettings2/ContentView.swift`
- Global screen shortcuts: `MacSysSettings2/ScreenShortcutController.swift`
- Login item support: `MacSysSettings2/LoginItemStore.swift`
- Dock reveal/minimize support: `MacSysSettings2/DockRevealStore.swift`, `MacSysSettings2/DockMinimizeAnimationStore.swift`
- Mic input support: `MacSysSettings2/AudioInputStore.swift`
- Window layout presets: `MacSysSettings2/WindowLayoutStore.swift`
- Fullscreen escape shortcut: `MacSysSettings2/FullscreenEscapeController.swift`

## Product Rules

- Settings pages need section headings and short descriptions.
- Every visible control must do something real, show real state, or be clearly read-only.
- No placeholder categories, dummy buttons, or "coming soon" controls.
- Prefer simple macOS-native rows, toggles, pickers, and status cards.
- If testing moves windows or applies layouts, restore the user's windows afterward.
- Keep `main` protected. Contributors should use branches or forks and open pull requests.

## Current Pages

- App Settings: login item, Accessibility permission, app state, Dock reveal/minimize tuning.
- Screen: move active app between monitors, shortcut recorder, Control-arrow window sizing, macOS Spaces shortcut toggle, fullscreen escape.
- Mic: list input devices, choose system default mic, prompt when a new mic appears.
- Layouts: build named presets from app, screen, position, and size rules, then apply them to running apps or from the menu bar on the display under the mouse.

## Adding A Setting

1. Add a case to `SettingsSection`.
2. Add the sidebar title, subtitle, icon, and gradient.
3. Add a detail view using `SettingsPage`, `SettingsSectionBlock`, and `SettingsGroup`.
4. Put macOS/system API logic in a small store/helper file.
5. Build the app.
6. Open the app and visually inspect the page.
7. Verify the setting performs the promised action.

## Discussed Settings Task List

Use `SETTINGS_TASK_LIST.md` as the living batch queue for settings ideas. This keeps brainstormed options from getting lost and lets agents implement many small settings together.

When adding to the list:

1. Preserve the user's wording when it matters.
2. Split each setting into concrete optional steps or toggles.
3. Write the trigger or shortcut.
4. Write the expected UI location.
5. Write the permission needed, if any.
6. Write the test plan.
7. Mark status as `Discussed`, `Ready`, `Blocked by macOS`, `Implemented`, or `Tested`.

When implementing the list:

1. Work through items one by one.
2. Build after the batch, or earlier if the batch touches risky shared shortcut code.
3. Test each item in isolation.
4. Restore any windows, apps, tabs, or system state changed during testing.
5. Do not report every tiny test step to the user. Save the report for the end unless permission/password/steering is needed.
6. Final report should say which settings passed, which macOS blocked, and what remains.

## Build

Use build-only by default. Do not kill, reinstall, or reopen the app after every successful build, because relaunching Mac Sys Settings 2 refreshes menu bar items and makes the user's whole menu bar flicker away and back. Only reinstall/reopen when the user asks to see the live app, when testing requires the fresh runtime, or when the current running app is stale and you explicitly say you are relaunching it.

```sh
xcodebuild -project 'Mac Sys Settings 2.xcodeproj' \
  -scheme 'Mac Sys Settings 2' \
  -configuration Debug \
  -derivedDataPath /tmp/MacSysSettings2LatestBuild \
  build
```

## GitHub Flow For Agents

Never push directly to `main`.

If the user only has an idea, do not build immediately unless they ask. Help them open a "Setting idea" issue, or use Discussions for loose brainstorming.

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
