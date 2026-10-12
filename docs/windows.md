# In-app windows (`rui_windows`)

Several movable, resizable, closable windows over one page, in **one** app:
one `Store`, one widget tree, one theme, one event loop. A window is a floating
child of a host widget drawn and hit-tested on the overlay layer, so "several
windows" is several roots of the same app, not several apps drawing together.

It is **optional**. `import rui_windows` to use it; it is not part of the `rui`
barrel, and an app that does not import it pays nothing (core carries three
nil-checked hooks: `onPointerPress`, pointer capture and `focusScope`).
`Dialog` and `MessageBox` remain the answer for a modal question.

```nim
import rui, rui_windows

let w = newWindow(title = "Inspector", x = 40, y = 60, width = 300, height = 240,
                  closeOnEscape = true)
w.addChild(content)           # one child fills the body
host.openWindow(w)            # on top, active, focus on its first field
...
w.closeWindow()               # off screen, out of the tree, fully released
```

`examples/widgets/windows.nim` is a runnable demo.

## What it does

- **Move**: drag the title bar. The pointer is *captured*, so a fast drag
  that outruns the window keeps working.
- **Resize**: drag a border or corner (`resizable`, default on), down to
  `minWidth` x `minHeight`; the opposite edge stays put.
- **Maximise / restore**: the title-bar button (`maximizable`); **close**: the x
  (`closable`), `Escape` (`closeOnEscape`), or `closeWindow(w)`. `onClose`
  fires once; closing twice is harmless.
- **Stay reachable**: a drag, resize or shrinking screen cannot take the title
  bar off screen.
- **Z-order and activation**: a press anywhere inside a window raises it --
  even on a child that consumes the click. The active window has the
  highlighted title bar. A press on the page behind deactivates the windows.
- **Keyboard**: Tab and Shift+Tab stay inside the active window; opening a
  window focuses its first focusable child.
- **Popups**: a DatePicker's calendar or a ComboBox list opens above its own
  window and above every other.
- **Release**: closing disposes the subtree -- Link bindings, the tree's
  widget map, focus, hover, pointer capture and render textures are all let
  go (tested with a thousand open/close cycles).

## API

| | |
|---|---|
| `newWindow(title, x, y, width, height, minWidth, minHeight, resizable, closable, maximizable, closeOnEscape, onClose, onMove, onResize)` | the widget |
| `host.openWindow(w)` / `closeWindow(w)` | open / close |
| `raiseWindow(w)`, `activeWindow()`, `openWindows()`, `windowOf(widget)`, `deactivate()` | z-order and activation (`window_manager`) |
| `toggleMaximized(w)` | |
| `edgesAt`, `resized`, `clampedTo`, ... | the geometry, pure functions (`window_geometry`) |

## Not done

A second *OS* window (a palette on another monitor) is not possible through
raylib; that would be a different backend. Window positions are not persisted,
and `loadYui` has no `window` element (yui has none; it would be an extension).
