# Agent Testing Rules

When the user says "test it", "test them", "retest", or "test and fix", treat it as a full success loop, not a quick build check.

## Meaning Of Test

Testing means:

1. Build the app.
2. Install or launch the fresh build only when the requested test needs the running app to change.
3. Verify the feature in the real macOS UI or with real macOS automation.
4. Check the actual resulting state, not just whether a command returned.
5. If it fails, fix the issue.
6. Rebuild and retest.
7. Repeat until it works, or until there is one concrete macOS/app-permission blocker.

Do not stop after the first failed test unless macOS is blocking the feature and the blocker is specific.

## Relaunch Discipline

Do not kill, reinstall, or reopen Mac Sys Settings 2 after a build unless the test requires it or the user asks. Relaunching the app refreshes its menu bar items and can make the user's full menu bar disappear and come back. If a relaunch is needed, say so before doing it.

## Permission Dialogs

If a permission dialog appears and it has an Allow button, use computer control to press Allow when possible. Do not wait for the user unless the system asks for a password or the dialog cannot be controlled.

If a password prompt appears, wait and check again instead of ending immediately, unless the user has said they are away and will not enter it.

## Window Testing

For window-moving or shortcut features:

- Test on real app windows, preferably Chrome, Notes, Finder, or the app itself.
- Do not use Cursor for routine testing unless the user explicitly asks.
- Before testing, record the original state of any app you will touch: whether it was open, whether it was hidden, which windows were visible, window position/size, and the frontmost app when useful.
- Record the before/after window frame when useful.
- Confirm the result numerically when possible, such as matching left/right edges or screen bounds.
- Restore the user's windows after testing. Put apps back to their original open/hidden state, position, size, monitor, and focus as closely as macOS allows.

## Cleanup After Testing

Testing is not done until the desktop is cleaned up.

Before changing windows, hiding/unhiding apps, moving apps between monitors, shrinking windows, opening apps, or making overlays appear, take a quick baseline of the apps you will touch. After the test passes or fails, restore that baseline to the best of your ability. It does not need to be perfectly identical if macOS or the app refuses exact sizes, but make a real attempt and mention any leftover difference.

Use this as the agent prompt:

> When testing Mac Sys Settings 2, preserve the user's workspace. Before the test, note the original state of every app/window you will use: open/closed, hidden/visible, frontmost app, monitor, position, and size. Run the real test. Then restore those apps and windows as closely as macOS allows. Do not leave test apps opened, hidden, moved, shrunk, enlarged, or focused differently unless the user asked for that. If exact restoration is impossible, restore the closest practical state and say what changed.

## Shortcut Testing

For keyboard shortcut changes:

- Trigger the actual shortcut.
- Verify the real final behavior.
- Watch for macOS default shortcuts stealing the key combo.
- If macOS steals it, use the lower-level event tap path or report the concrete blocker.

## Final Reply

After testing, answer in one or two lines unless the user asks for detail. Include:

- whether it works
- what was tested
- any blocker, only if there is one

Example: "Built and tested. Ctrl-Down now cycles smallest -> +10% -> +20% -> smallest, and stays bottom-right."
