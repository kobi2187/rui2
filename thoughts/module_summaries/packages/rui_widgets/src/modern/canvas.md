# packages/rui_widgets/src/modern/canvas.nim

## Purpose

A retained-mode drawing surface: a list of `DrawCommand`s replayed on every
repaint, plus optional interactive drawing (freehand, line, rect, circle).

## Public interface

- `DrawCommandKind*` — `dcLine`, `dcRect`, `dcRectFilled`, `dcCircle`,
  `dcCircleFilled`, `dcTriangle`, `dcPolygon`, `dcText`.
- `DrawCommand*` — a variant object; **all positions are canvas-relative**.
- `DrawingMode*` — `dmNone` (interaction off), `dmFreehand`, `dmLine`,
  `dmRect`, `dmCircle`.
- `newCanvas*(enableDrawing = true, drawingMode = dmNone, defaultColor,
  defaultThickness = 2.0, showGrid = false, gridSize = 20.0, intent,
  onDraw, onDrawComplete, onClear)`.
- `addCommand*(widget: Canvas, cmd: DrawCommand)` — append from code.
- `clearCanvas*(widget: Canvas)` — drop every command; fires `onClear`.
- State: `commands`, `isDrawing`, `drawStart`, `dragPos`, `currentPath`.

Freehand produces one `dcLine` per sampled segment, so an erase is per-stroke
rather than per-segment only if you track the count yourself.

## Usage pattern

```nim
let canvas = newCanvas(enableDrawing = true, drawingMode = dmFreehand,
                       showGrid = true, gridSize = 20.0)
canvas.bounds = Rect(x: 0, y: 0, width: 580, height: 260)

# Coordinates are relative to the canvas' top-left, not the screen:
canvas.addCommand(DrawCommand(kind: dcRectFilled,
                              rect: Rect(x: 20, y: 20, width: 80, height: 50),
                              rectColor: orange, rectRounded: true,
                              rectRoundness: 6.0))
```

## Circumstances

Restored 2026-09-15 from `a4bcc18`, where all drawing interaction was polled
inside `render` (`IsMouseButtonReleased` etc.) and commands were stored in
screen coordinates.

**Why canvas-relative.** `main_loop.renderPass` zeroes `bounds.x/y` while a
widget paints into its own render texture. Screen-coordinate commands would
land in the wrong place — and would also slide whenever the canvas moved. The
replay offsets by the current origin, which is 0 during the texture pass and
the real position anywhere else.

There is no triangle primitive in `rui_drawing`, so `dcTriangle` draws three
edges rather than dropping to raylib's raw calls.
</content>
