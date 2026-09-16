# packages/rui_widgets/src/containers/panel.nim

## Purpose

A bordered container with optional background and padding. The foundation for
GroupBox, dialogs and other framed containers.

## Public interface

- `newPanel*(padding = 8.0, borderWidth = 1.0, cornerRadius = 0.0,
  showBackground = true, showBorder = true, intent = Default)`.

Sizing: a child given **zero width measures itself**; otherwise it is stretched
to the content box. When the Panel itself has no size, it sizes to its content
plus padding.

## Usage pattern

```nim
let panel = newPanel(padding = 10.0, cornerRadius = 6.0)
panel.bounds = Rect(x: 0, y: 0, width: 560, height: 60)
panel.addChild(newLabel(text = "Inside a Panel", fontSize = 14.0))
```

## Circumstances

Restored 2026-09-15 from `a4bcc18`, where `render` ended with a loop calling
`child.render()`. That double-draws under the current loop: `renderPass`
already recurses over `children`, so a container draws only its own frame.

Colours come from the theme (`ThemeIntent`) rather than the per-instance
`backgroundColor` / `borderColor` props the original carried.
</content>
