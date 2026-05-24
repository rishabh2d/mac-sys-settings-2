# Mac Sys Settings 2 Manual Test Queue

Use this as the user-facing list of settings Rishabh should manually test later. Keep it short, practical, and current. Add items here when a feature needs real human hardware, external monitors, browser state, Bluetooth devices, Raycast history, or hand/mouse testing that automation cannot prove cleanly.

## Needs Rishabh Test

1. Bluetooth audio mic prompt
   - Connect AirPods or another Bluetooth audio device.
   - Confirm the centered Sound Input prompt appears only for audio devices.
   - Click Sound Input and confirm it shows the current mic plus available mic choices.
   - Choose MacBook/internal mic and confirm macOS input really changes.

2. Screenshot clipboard mode with Raycast history
   - Turn the setting on only for testing.
   - Take two normal macOS screenshots.
   - Confirm the latest screenshot can paste.
   - Open Raycast clipboard history and confirm screenshots are not piling up forever in a storage-heavy way.
   - If Raycast keeps permanent copies, keep this setting default off and make the warning copy stricter.

3. Tab-or-window monitor move
   - Focus Chrome, Safari, or Edge on a two-monitor setup.
   - Press Control-Option-Arrow.
   - Confirm the T/W chooser appears.
   - Press T and confirm only the active tab moves to the other monitor.
   - Press W and confirm the whole browser window moves.

4. Grandma layout presets from menu bar
   - Right-click the Mac Sys Settings 2 menu bar icon.
   - Confirm our custom layout chooser opens, not a native macOS menu.
   - Pick Coding, Research, or Meeting.
   - Confirm it applies to the monitor under the mouse.
   - Restore any moved windows after the test.

5. Quick opposite-arrow browser tab snap
   - In Chrome/Safari/Edge, press Command-Option-Left then Command-Option-Right quickly.
   - Confirm the first active tab snaps left and the next browser tab/window snaps right.
   - Test the mirror: Right then Left.
   - Confirm it chooses the next browser window on the same monitor when needed.

6. Browser tab snap plus YouTube theater mode
   - Open a YouTube tab in Chrome or Safari.
   - Press Command-Option-Left or Command-Option-Right.
   - Confirm the tab snaps to that side.
   - Confirm YouTube theater mode toggles after the short delay.

7. Downloads newest-first opener
   - Add/download a new file into Downloads.
   - Confirm Finder opens Downloads in list view.
   - Confirm the newest item is visible at the top.
   - Confirm it does not keep randomly firing when no new download happened.

8. Hover to focus
   - Turn on Focus window on hover.
   - Move the mouse across visible apps without clicking.
   - Confirm focus follows the hovered window quickly.
   - Confirm it does not click buttons, play/pause Chrome, or type into the wrong app.

9. Open/Save folder defaults
   - In Finder settings, turn on Per-app file picker folders.
   - Add a rule for Chrome or Safari pointing to a test folder.
   - In that app, open an upload/open-file picker.
   - Confirm the picker jumps to the saved folder.
   - Confirm unrelated apps are not redirected.

10. File shelf shake trigger
   - Select files in Finder.
   - Shake the cursor left/right in a small area.
   - Confirm the shelf opens.
   - Move the cursor quickly across the screen without shaking and confirm the shelf does not open.
   - Leave shelf empty for 10 seconds and confirm it closes.

11. Cursor jump overlay
   - Press the configured cursor-jump shortcut.
   - Confirm the monitor chooser appears.
   - Choose monitor and keypad point.
   - Confirm cursor lands at the expected screen point.
   - Confirm a glowing locator ring appears around the cursor after it lands.

12. Cursor locator ring
   - Press Command-Shift-L, or the custom locator shortcut if changed.
   - Confirm a glowing ring appears exactly around the current cursor.
   - Test on monitor 1 and monitor 2.
   - Test while Chrome, Notes, Finder, Telegram, and Codex are focused.
   - Confirm the ring does not steal focus or click anything.

13. Control-arrow window sizing on both monitors
   - Test left/right half, one-third, and two-thirds on monitor 1 and monitor 2.
   - Confirm full-height windows touch top and bottom usable bounds.
   - Confirm full-window state resets the sizing cycle back to half.

14. Chrome/Gmail resize behavior
   - Open Gmail in Chrome.
   - Use Control-arrow sizing.
   - Confirm the browser content reflows like manual resizing, not stuck at old width.

15. Fullscreen Escape
   - Put two apps into real macOS fullscreen.
   - Press Command-Option-Tab.
   - Confirm it switches between fullscreen windows if macOS exposes them.
   - Restore fullscreen state after testing.

16. Window switcher hot corner
   - Turn on the optional hot corner trigger.
   - Move the cursor to the bottom-right corner.
   - Confirm the app-specific window switcher appears.
   - Confirm it closes after 3 seconds unless hovered.

17. Finder sort shortcut
   - Open a Finder folder.
   - Use the sort shortcut.
   - Confirm the chooser applies Date Created or Date Modified sorting.
   - Restore the folder view if needed.

18. Autoscroll overlay
   - Open a long Chrome page.
   - Use the autoscroll shortcut.
   - Test up/down plus slow/medium/fast.
   - Confirm pressing the shortcut again stops scrolling.

19. Command-H focused-window hide
   - Focus one browser window while another browser window is visible on another monitor.
   - Press Command-H.
   - Confirm only the focused window hides/minimizes, not every browser window.
   - Press again or restore manually and confirm other monitors were not disturbed.

20. Command-Shift-H hide current monitor
   - Focus one app on a monitor with several apps visible.
   - Press Command-Shift-H.
   - Confirm other apps on that monitor hide and the focused app remains.
   - Press Command-Shift-H again and confirm hidden apps return.

21. Dock instant reveal tuning
   - If Dock autohide is enabled, turn on Dock reveal tuning.
   - Confirm the Dock reveals faster.
   - Use restore defaults and confirm Dock behavior returns.

22. Compact panel one-open rule
   - Open compact panel from the sidebar.
   - Press Open and confirm compact panel closes while main app opens.
   - Reopen compact panel and confirm only one compact panel exists.

## Already Automated Or Partially Proven

- Build succeeds with current app code.
- Chrome T/W chooser appears from the real Control-Option-Arrow event path.
- Chrome active tab can be split into its own window and tracked by window ID.
- Menu bar right-click opens a custom chooser panel window.
