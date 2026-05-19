# Contributing

Mac Sys Settings 2 should grow through small, real macOS settings that people actually want.

## Contribution Flow

No one should auto-push changes into the owner repo.

1. Fork the repo to your own GitHub account.
2. Create a branch, for example `setting/new-mic-picker` or `fix/window-top-edge`.
3. Make your change locally.
4. Build and test the app.
5. Push your branch to your fork.
6. Open a pull request into this repo.
7. The repo owner reviews, requests changes if needed, and merges only when ready.

## For People Using Codex Or Another Agent

Tell your agent:

```text
Read README.md, CONTRIBUTING.md, and AGENTS.md first.
Add one real Mac Sys Settings 2 setting.
Do not push to main.
Create a branch or fork, make the change, test it, and prepare a pull request summary.
```

Your agent should leave a short summary for both:

- Developers: files changed, APIs used, build/test result, risks.
- Users: what the setting does, how to turn it on, what permission it needs.

## What Counts As A Good Setting

A good setting:

- solves a real macOS annoyance
- has a clear on/off state or clear action button
- shows real system state when possible
- explains permissions in plain language
- fails safely if macOS blocks the action

Avoid:

- placeholder settings
- fake buttons
- UI that says a setting works before the implementation exists
- giant rewrites unrelated to the setting

## Pull Request Checklist

- The app builds.
- The setting is visible in the sidebar or an existing page.
- The setting has a heading and short description.
- The setting performs the promised action.
- The PR description includes user-facing and developer-facing summaries.
- Any window movement testing restores the user's windows afterward.

