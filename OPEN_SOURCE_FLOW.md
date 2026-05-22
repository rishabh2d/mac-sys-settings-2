# Open Source Flow

Mac Sys Settings 2 should be easy for non-coders, friends, and agents to contribute to without putting unsafe or half-built settings into the main app.

## Core Rule

Personal first, public later.

People can build a setting for their own Mac first. Public settings should only become part of the main app when they are useful, safe, tested, and reviewed.

## For Friends

Send friends `SHARE_WITH_FRIENDS.md`.

Their agent should:

1. Clone the repo.
2. Read `README.md`, `AGENTS.md`, `FRIEND_ONBOARDING.md`, `GREETING_MESSAGE.md`, and this file.
3. Show the greeting.
4. Ask what Mac setting they wish existed.
5. Help them either submit an idea or build a branch.

## Idea-Only Contribution

Use this when someone has an idea but does not want to code.

1. Open a GitHub Issue using the Setting idea template.
2. Include the annoying Mac behavior, desired behavior, trigger, app/device/monitor context, and permission concerns.
3. Use Discussions for loose brainstorming.
4. Do not pretend an idea is implemented until code exists.

## Built Feature Contribution

Use this when someone wants to build or use a coding agent.

1. Fork or branch from `main`.
2. Add one real setting.
3. Build locally.
4. Test real behavior.
5. Restore any changed windows/system state.
6. Open a PR.
7. Include user summary, developer summary, permissions, and known limits.

## Main Branch

`main` should stay protected for normal contributors.

Agents should not direct-push to `main` by default. The owner/admin can choose to bypass or relax protection, but a regular friend contribution should go through PR review.

## Review Bar

Before merging a public setting, check:

- Is the control real?
- Does the setting do what it says?
- Is there a clear off/reset path?
- Does it explain permissions plainly?
- Does it fail safely?
- Was it tested on real macOS behavior?
- Does the UI match the product taste?

