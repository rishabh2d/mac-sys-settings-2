# Mac Sys Settings 2 Undone Settings

Settings here were explored or partially built, but should not ship until they are redesigned and proven reliable.

## Screenshot App Drop Picker

- Status: Removed from the app.
- Original idea: after Command-Shift-3, show a small app icon strip so the screenshot could be sent or dragged into apps like Codex, ChatGPT, WhatsApp, or Chrome.
- Why undone: the flow was not reliable enough and could appear accidentally above normal screenshots.
- Required before reconsidering: a dependable, non-intrusive send flow that never appears unless explicitly requested.

## Auto Clicking And Auto Typing

- Status: Future settings, not ready to ship as final controls.
- User note: "Sys settings: 1. Auto scrolling 2. Auto typing 3. Auto pressing a key"
- Original idea: add a family of automation helpers where Mac Sys Settings 2 can repeatedly scroll, type text, or press a chosen key for the user.
- Why undone: these controls can easily become intrusive, confusing, or unsafe if they start accidentally, keep running after the user changes focus, or do not have obvious stop behavior.
- Required before reconsidering: every automation needs a clear trigger, visible running state, instant stop shortcut, focus/app safety rules, and proof that it cannot keep typing/pressing/scrolling in the wrong app.
- Design direction: treat these as explicit power tools, not background magic. The user should always know what will happen, where it will happen, and how to stop it before it starts.
