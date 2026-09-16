# packages/rui_widgets/src/basic/button_v2.nim

## Purpose

The standard push button. A **composite** (`defineWidget`, not
`definePrimitive`): a Rectangle for the background plus a Label for the text,
rather than one widget drawing both.

## Public interface

- `newButton*(text: string, disabled = false, intent = Default, onClick)`.
- State: `isPressed`, `isHovered`.

Note it carries its **own** `isHovered` state field alongside the inherited
`Widget.hovered` — two flags meaning the same thing. Worth reconciling; see the
hover defect below.

## Usage pattern

```nim
let btn = newButton(text = "Submit")
btn.onClick = some(proc() {.closure.} = ...)
row.addChild(btn)

let danger = newButton(text = "Delete", intent = Danger)
```

## Circumstances

Named `button_v2` because it replaced a pre-DSL `button.nim` during the v2 port;
the old one was deleted as `button.nim.old` in `a4bcc18` and was not restored —
this is its successor, not a sibling.

> **Two known issues touch this widget.**
>
> - `Widget.hovered` is never cleared anywhere in the codebase
>   ([#14](https://github.com/kobi2187/rui2/issues/14)), so a button keeps its
>   hover highlight after the pointer leaves.
> - Composites rebuild their children every layout pass
>   ([#31](https://github.com/kobi2187/rui2/issues/31)) — `children.setLen(0)`
>   and recreate — so the Rectangle and Label are reallocated each frame and
>   their cached textures are thrown away. Button is the example named in that
>   issue.
