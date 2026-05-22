# Agent Notifications

Use this when working on Mac Sys Settings 2 and the user wants visible app-style notifications.

These are not normal macOS Notification Center alerts. They are the user's custom Screenshot Gold / Codex floating panel notifications.

## Helper Location

Read the helper handoff first:

```text
/Users/rishabh/Desktop/Screenshot Gold 1/Agent Notifications/AGENT_HANDOFF.md
```

Main command:

```sh
"$HOME/Desktop/Screenshot Gold 1/Agent Notifications/fire-agent-panel-notification.sh" "SYS SETTINGS 2" $'Point one\nPoint two' 4
```

Close stale notifications:

```sh
"$HOME/Desktop/Screenshot Gold 1/Agent Notifications/close-agent-panel-notifications.sh"
```

Watch for STEER / STOP after firing a steerable notification:

```sh
"$HOME/Desktop/Screenshot Gold 1/Agent Notifications/watch-agent-panel-actions.sh" --clear --timeout 300
```

## User Preference

- Use heading `SYS SETTINGS 2`.
- Use notifications for final/important work summaries, password/permission waits, or when the user explicitly says "fire a notif" / "reply in notif".
- Do not use notifications for every tiny progress thought.
- Use chat for normal replies unless the user specifically asks for notification replies.
- If the app is not in focus and you are doing foreground testing, fire a short heads-up notification first.
- Put summary updates in point form, one point per line.
- If asking the user to steer, use `--steer` or `AGENT_PANEL_STEER_AVAILABLE=1`.

## Useful Examples

Final summary:

```sh
"$HOME/Desktop/Screenshot Gold 1/Agent Notifications/fire-agent-panel-notification.sh" \
  "SYS SETTINGS 2" \
  $'Green: Build passed\nGreen: Battery menu fixed\nConclusion: Ready for you to test' \
  5
```

Tiny heads-up before taking focus:

```sh
"$HOME/Desktop/Screenshot Gold 1/Agent Notifications/fire-agent-panel-notification.sh" \
  tiny "SYS SETTINGS 2" "Taking focus now for testing." 2
```

Password or permission wait:

```sh
AGENT_PANEL_TITLE="SYS SETTINGS 2" \
"$HOME/Desktop/Screenshot Gold 1/Agent Notifications/fire-agent-panel-notification.sh" \
  monitor1 tr password
```

Steerable question:

```sh
"$HOME/Desktop/Screenshot Gold 1/Agent Notifications/fire-agent-panel-notification.sh" \
  monitor1 tr --steer "SYS SETTINGS 2" \
  $'Need your choice before continuing\nPress STEER to reply' \
  300
```

## Current Placement Note

The notification helper has a Codex-specific tiny-notification fallback that tries to place tiny alerts above the Codex input box when Codex does not expose the text field through Accessibility. If placement feels wrong, fix the helper in:

```text
/Users/rishabh/Desktop/Screenshot Gold 1/Agent Notifications/fire-agent-panel-notification.swift
```

