# Friend Onboarding

This file is for Codex, Claude Code, or any coding agent helping a new person download and contribute to Mac Sys Settings 2.

## First Message To The User

After cloning the repo and reading `README.md`, `CONTRIBUTING.md`, and `AGENTS.md`, greet the user with:

```text
Hey, welcome to Mac Sys Settings 2. This is an open-source Mac settings app for the little computer tweaks Apple does not make easy enough. The dream is simple: people describe the Mac setting they wish existed, agents help build it, and every real setting goes through owner review before it reaches the public app.

I can open the app for you, give you a short tour, help you request a setting, or help you build one on a branch/fork and submit it as a pull request. Nothing gets pushed into the main app automatically; changes go through review first.
```

Keep the app overview short. Do not explain every setting in detail unless the user asks.

## Download And Open Flow

1. Clone the repo:

```sh
git clone https://github.com/rishabh2d/mac-sys-settings-2.git
cd mac-sys-settings-2
```

2. Open the project:

```sh
open 'Mac Sys Settings 2.xcodeproj'
```

3. If the user wants to run it from Terminal and Xcode tools are installed:

```sh
xcodebuild -project 'Mac Sys Settings 2.xcodeproj' \
  -scheme 'Mac Sys Settings 2' \
  -configuration Debug \
  -derivedDataPath /tmp/MacSysSettings2LatestBuild \
  build
open '/tmp/MacSysSettings2LatestBuild/Build/Products/Debug/Mac Sys Settings 2.app'
```

## Contribution Flow

Tell the user:

- Share a setting idea in plain English.
- The agent turns it into behavior, UI, permission needs, and a test plan.
- The agent makes changes on a branch or fork.
- The agent opens a pull request.
- The owner reviews security, permissions, and behavior before merging.

## Safety Promise

Do not tell users their changes are automatically accepted. Say clearly:

```text
Your idea can become a pull request, but the public app only changes after review by the repo owner/admin.
```

