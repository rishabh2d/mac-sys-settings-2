# Mac Sys Settings 2

Mac Sys Settings 2 is an open-source macOS System Settings companion for small computer tweaks that Apple does not make easy enough.

The idea is simple: real settings only. Each setting should either change a real macOS behavior, show real system state, or guide an agent through a repeatable system tweak.

## Current Settings

- App Settings: open Mac Sys Settings 2 when your Mac starts, check Accessibility permission, and see app state.
- Screen: move the active app between monitors, resize windows with Control-arrow, and disable macOS Spaces shortcuts when needed.
- Mic: see available input devices, switch the default microphone, and ask what to do when a new mic appears.
- Layouts: build named layouts like Coding, Research, or Meeting from app, screen, alignment, and size rules.

## For Non-Coders

You can request a new setting by opening a GitHub Issue.

Good request format:

```text
Setting name:
What I want to do:
What currently makes this annoying on macOS:
What should happen when I turn it on:
Any shortcut, app, or device involved:
```

You do not need to know code. Describe the computer behavior you want.

## For Contributors

Contributions should go through pull requests. Do not push directly to `main`.

1. Fork this repo.
2. Make a branch for your setting.
3. Add a real setting with UI, implementation, and a short explanation.
4. Test it on your Mac.
5. Open a pull request with screenshots or a screen recording if possible.

See [CONTRIBUTING.md](CONTRIBUTING.md) and [AGENTS.md](AGENTS.md).

If you are using Codex, Claude Code, or another coding agent, give it [FRIEND_ONBOARDING.md](FRIEND_ONBOARDING.md) first so it can download the app, greet you, and explain the contribution flow.

## Build Locally

Open `Mac Sys Settings 2.xcodeproj` in Xcode and run the `Mac Sys Settings 2` scheme.

Command-line build:

```sh
xcodebuild -project 'Mac Sys Settings 2.xcodeproj' \
  -scheme 'Mac Sys Settings 2' \
  -configuration Debug \
  -derivedDataPath /tmp/MacSysSettings2LatestBuild \
  build
```

Some features need Accessibility permission because they move or resize other app windows.
