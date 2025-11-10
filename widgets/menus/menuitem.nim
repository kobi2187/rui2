## MenuItem Widget - RUI2
##
## A single item in a menu (MenuBar or ContextMenu).
## Can have text, icon, shortcut key, checkbox state, and submenu.
## Ported from Hummingbird to RUI2's definePrimitive DSL.

import ../../core/widget_dsl_v2
import std/options

when defined(useGraphics):
  import raylib

definePrimitive(MenuItem):
  props:
    text: string
    shortcut: string = ""        # e.g., "Ctrl+S", "F5"
    iconText: string = ""        # Text icon (emoji/Unicode)
    checkable: bool = false      # Can be checked/unchecked
    separator: bool = false      # Is this a separator line?
    disabled: bool = false

  state:
    checked: bool

  actions:
    onClick()
    onToggle(checked: bool)

  events:
    on_mouse_down:
      if not widget.disabled and not widget.separator:
        if widget.checkable:
          widget.checked.set(not widget.checked.get())
          if widget.onToggle.isSome:
            widget.onToggle.get()(widget.checked.get())

        if widget.onClick.isSome:
          widget.onClick.get()()

        return true
      return false

  render:
    when defined(useGraphics):
      if widget.separator:
        # Draw separator line
        let y = widget.bounds.y + widget.bounds.height / 2
        DrawLineEx(
          Vector2(x: widget.bounds.x + 10, y: y),
          Vector2(x: widget.bounds.x + widget.bounds.width - 10, y: y),
          1.0,
          Color(r: 200, g: 200, b: 200, a: 255)
        )
      else:
        # Format text with shortcut
        var displayText = widget.text
        if widget.shortcut.len > 0:
          displayText = displayText & "\t" & widget.shortcut

        # Use GuiMenuItem from raygui if available
        if GuiMenuItem(
          Rectangle(
            x: widget.bounds.x,
            y: widget.bounds.y,
            width: widget.bounds.width,
            height: widget.bounds.height
          ),
          displayText.cstring
        ):
          # Item was clicked
          if not widget.disabled:
            if widget.checkable:
              widget.checked.set(not widget.checked.get())
              if widget.onToggle.isSome:
                widget.onToggle.get()(widget.checked.get())

            if widget.onClick.isSome:
              widget.onClick.get()()

        # Draw check mark if checked
        if widget.checkable and widget.checked.get():
          DrawText(
            "✓".cstring,
            (widget.bounds.x + 4).cint,
            (widget.bounds.y + 2).cint,
            16,
            Color(r: 0, g: 0, b: 0, a: 255)
          )
    else:
      # Non-graphics mode
      if widget.separator:
        echo "  ─────────────────"
      else:
        let check = if widget.checkable and widget.checked.get(): "[✓] " else: "    "
        let shortcut = if widget.shortcut.len > 0: " (" & widget.shortcut & ")" else: ""
        echo "  ", check, widget.text, shortcut
