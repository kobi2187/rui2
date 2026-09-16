# packages/rui/src/app.nim

*Only the part this session touched is described in detail; the rest is
summarised for orientation.*

## Purpose

The application object and the main loop: owns the widget tree, the managers
(event, focus, script, hit-test), the theme, and the frame sequence.

## Public interface (orientation)

- `App*` — `tree`, `store`, `window`, the four managers, `themeManager`,
  `currentTheme`, `textCache`, frame timing, `onFrame`, `shouldClose`.
- `newApp*(title, width, height, fps, resizable, minWidth, minHeight): App`
- `setRootWidget*`, `setStore*`, `setTheme*` (by `Theme` or name), `getTheme*`
- `enableScripting*`, `setScriptPollInterval*`, `disableScripting*`
- `clearTextCache*`, `getTextCacheStats*`, `printTextCacheStats*`
- **`onFrame*: Option[proc() {.closure.}]`** — called once per frame, before
  events are collected.
- `run*(app: App, maxFrames = -1)` — `maxFrames > 0` renders that many frames
  and exits, which is what screenshot capture and automated tests use.
- `start*` (in `rui.nim`) is an alias for `run`.

Frame order: `onFrame` → collect raylib events → coalesce → process with a time
budget → poll script commands → layout + render passes → composite.

## Usage pattern

```nim
let app = newApp("My App", 800, 600)
app.setRootWidget(buildUI())

# For work the event stream cannot deliver — window file drops, animation
# ticks, polling an external source:
app.onFrame = some(proc() {.closure.} = dropArea.pollFileDrops())

app.start()
```

## Circumstances

**`onFrame` added 2026-09-16** for `DragDropArea`, which cannot work without
it: window file drops are not `GuiEvent`s, so they never reach `handleInput`,
and a widget polling raylib from inside `render` only sees them on frames where
it happens to be dirty.

> **Known issues**, both in the architecture review:
>
> - **`hovered` is never cleared** (line ~391). That is the only write to the
>   flag in the entire codebase and it only ever sets `true`, despite the
>   comment above it saying "clear old, set new". Every hovered widget stays
>   lit, and `Tooltip` can never hide. Candidate #4.
> - **The `currentTheme` field is written four times and read never.** Line 461's
>   `currentTheme.canvasColor()` resolves to the *global* in
>   `theme_sys_core.nim`, not the field — Nim has no implicit self. Part of
>   candidate #5.
>
> This file is also the repo's #1 git hot spot and holds five concerns at 596
> lines; candidate #3 proposes splitting it.
</content>
