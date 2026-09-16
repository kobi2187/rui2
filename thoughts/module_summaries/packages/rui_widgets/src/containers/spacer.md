# packages/rui_widgets/src/containers/spacer.nim

## Purpose

A flexible gap in a layout. Stacks give a Spacer whatever room is left over;
`minWidth` / `minHeight` are the floor it insists on.

## Public interface

- `newSpacer*(minWidth = 0.0, minHeight = 0.0, flexGrow = 1.0,
  showDebug = false)`.
- `showDebug` outlines the spacer in magenta and labels it, so an unexpected
  gap can be seen rather than guessed at.

**`flexGrow` is currently inert.** The stacks do not distribute leftover space
proportionally yet, so a Spacer contributes its minimums and nothing more. The
prop is kept because the field is what a future distributing stack would read;
do not rely on it meaning anything today.

## Usage pattern

```nim
page.addChild(newSpacer(minHeight = 8.0))
page.addChild(newSpacer(minHeight = 8.0, showDebug = true))   # while debugging
```

## Circumstances

Restored 2026-09-15 from `a4bcc18`, where the whole body was behind
`when defined(useGraphics)` and the non-graphics branch echoed its size. It
gained a `layout` section during the port — without one it reported zero size
and the stacks collapsed it, which is the failure the `feedback` about
content-driven sizing was originally about.
</content>
