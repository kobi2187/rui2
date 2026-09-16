# packages/rui_widgets/src/containers/groupbox.nim

## Purpose

A bordered container with a title notched into the top border. Groups related
controls visually — a Panel that announces what it is holding.

## Public interface

- `newGroupBox*(title = "", padding = 8.0, titleHeight = 20.0,
  intent = Default)`.

Content sits below the title row and inside the padding. When the box has no
width of its own it sizes to the wider of its content and its **title** — so a
long title does not overflow the frame.

## Usage pattern

```nim
let group = newGroupBox(title = "Shipping", padding = 10.0, titleHeight = 20.0)
group.addChild(newRadioGroup(options = @["Standard", "Express"]))
```

## Circumstances

Restored 2026-09-15 from `a4bcc18`, where it called raygui's `GuiGroupBox` and
then `child.render()` per child (double-drawing under the current loop). It now
draws with `rui_drawing`'s themed `drawGroupBox` and lets `renderPass`
composite the children.
</content>
