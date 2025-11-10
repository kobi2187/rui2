## Link Widget - RUI2
##
## A clickable hyperlink with visited state tracking.
## Displays as underlined text that changes color when clicked.
## Ported from Hummingbird to RUI2's definePrimitive DSL.

import ../../core/widget_dsl_v2
import std/options

when defined(useGraphics):
  import raylib

definePrimitive(Link):
  props:
    text: string
    url: string = ""
    colorUnvisited: Color = Color(r: 0, g: 102, b: 204, a: 255)    # Blue
    colorVisited: Color = Color(r: 128, g: 0, b: 128, a: 255)      # Purple
    colorHover: Color = Color(r: 0, g: 153, b: 255, a: 255)        # Light blue
    underline: bool = true
    disabled: bool = false

  state:
    visited: bool

  actions:
    onClick()
    onNavigate(url: string)

  events:
    on_mouse_down:
      if not widget.disabled:
        # Mark as visited and trigger callbacks
        widget.visited.set(true)

        if widget.onClick.isSome:
          widget.onClick.get()()

        if widget.onNavigate.isSome and widget.url.len > 0:
          widget.onNavigate.get()(widget.url)

        return true
      return false

  render:
    when defined(useGraphics):
      # Determine color based on state
      let color = if widget.disabled:
                    Color(r: 160, g: 160, b: 160, a: 255)  # Gray
                  elif widget.isHovered.get():
                    widget.colorHover
                  elif widget.visited.get():
                    widget.colorVisited
                  else:
                    widget.colorUnvisited

      # Draw as clickable label button
      if GuiLabelButton(
        Rectangle(
          x: widget.bounds.x,
          y: widget.bounds.y,
          width: widget.bounds.width,
          height: widget.bounds.height
        ),
        widget.text.cstring
      ):
        # Handle click (same as on_mouse_down logic)
        if not widget.disabled:
          widget.visited.set(true)
          if widget.onClick.isSome:
            widget.onClick.get()()
          if widget.onNavigate.isSome and widget.url.len > 0:
            widget.onNavigate.get()(widget.url)

      # Draw underline if enabled
      if widget.underline:
        let textWidth = MeasureText(widget.text.cstring, 10)
        DrawLineEx(
          Vector2(x: widget.bounds.x, y: widget.bounds.y + widget.bounds.height - 2),
          Vector2(x: widget.bounds.x + float32(textWidth), y: widget.bounds.y + widget.bounds.height - 2),
          1.0,
          color
        )
    else:
      # Non-graphics mode: just echo
      let marker = if widget.visited.get(): "[visited]" else: ""
      echo "Link: ", widget.text, " (", widget.url, ") ", marker
