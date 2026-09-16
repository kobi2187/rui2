## Button Widget (DSL v2)
##
## The reference composite: a Rectangle for the background and a Label for the
## text, created once in `init` and *updated* by `layout`, never replaced. It is
## worth reading before writing another composite, because the two rules it
## follows are not obvious from the DSL.
##
## **Children are created once.** This used to `children.setLen(0)` and rebuild
## both on every layout pass. That threw away exactly what the render pass
## exists to reuse -- each child's identity and its cached texture -- so a
## button whose hover state changed re-rasterised its text through Pango even
## though the text had not changed, and handed every child a fresh WidgetId each
## frame. `layout` indexes the children positionally, so the order in `init` is
## part of the contract.
##
## **The theme is read in `layout`, not `render`.** Button draws nothing itself;
## its children do. So the visual-state ladder (disabled, pressed, hovered,
## normal) resolves to ThemeProps here and is pushed into the children's plain
## colour props. A composite that read the theme in `render` would resolve it
## after its children had already been composited.
##
## Sizing is from real font metrics: `measureText` plus symmetric padding, and
## only when the parent has not already imposed a dimension. The older version
## placed the label at a hard-coded 14px with a +10/-20 horizontal fudge.

import rui_core
import rui_drawing
import ../primitives/[rectangle, label]
import raylib
import std/[options, json]

defineWidget(Button):
  props:
    text: string
    disabled: bool = false
    intent: ThemeIntent = Default

  state:
    isPressed: bool
    isHovered: bool

  actions:
    onClick()

  init:
    widget.focusable = true

    # The two children are created once and then updated by `layout`, never
    # replaced. addChild rather than children.add, so the parent link is set --
    # hit-testing depth and event bubbling both rely on it. `layout` indexes
    # these positionally, so the order here is part of the contract.
    widget.addChild(newRectangle(filled = true))
    widget.addChild(newLabel(text = "", fontSize = 14.0,
                             align = TextAlign.Center))

  events:
    on_mouse_down:
      if not widget.disabled:
        widget.isPressed = true
        return true
      return false

    on_mouse_up:
      if widget.isPressed and not widget.disabled:
        widget.isPressed = false
        if widget.onClick.isSome:
          widget.onClick.get()()
        return true
      return false

    on_mouse_move:
      # Check if mouse is over widget
      let mouseX = event.mousePos.x
      let mouseY = event.mousePos.y
      let isOver = mouseX >= widget.bounds.x and
                   mouseX <= widget.bounds.x + widget.bounds.width and
                   mouseY >= widget.bounds.y and
                   mouseY <= widget.bounds.y + widget.bounds.height
      widget.isHovered = isOver
      return false

  layout:
    # The background and label are created once, in `init`, and updated here.
    #
    # This used to do `children.setLen(0)` and rebuild both on every layout
    # pass, with the comment "layout is called on every dirty". That threw away
    # the two things the render pass exists to reuse: each child's identity, and
    # its cached texture. renderPass composites children from their caches, so a
    # button whose hover state changed rebuilt its Rectangle and its Label from
    # scratch -- including re-rasterising the text through Pango -- when neither
    # had actually changed. It also handed every widget a fresh WidgetId each
    # frame, which nothing downstream expects.
    # `rectangle.Rectangle`: raylib has a Rectangle too, and rui_core exports
    # the types it needs, so the bare name is ambiguous here.
    let bg = rectangle.Rectangle(widget.children[0])
    let textLabel = Label(widget.children[1])

    # Look up theme colors based on widget state
    let state = if widget.disabled: Disabled
                elif widget.isPressed: Pressed
                elif widget.isHovered: Hovered
                else: Normal
    let props = currentTheme.getThemeProps(widget.intent, state)

    let buttonColor = props.backgroundColor.get(GRAY)
    let textColor = props.foregroundColor.get(WHITE)
    let radius = props.cornerRadius.get(4.0f32)
    let fontSize = props.fontSize.get(14.0f32)

    # Size to content when the parent has not imposed a height.
    # Real font metrics make this possible; previously the label was placed with
    # a hard-coded 14px height and a +10/-20 horizontal fudge.
    let textStyle = TextStyle(fontFamily: "", fontSize: fontSize,
                              color: textColor, bold: false, italic: false,
                              underline: false)
    let metrics = measureText(widget.text, textStyle)
    const PadX = 16.0f32
    const PadY = 8.0f32

    if widget.bounds.height <= 0:
      widget.bounds.height = metrics.height + PadY * 2
    if widget.bounds.width <= 0:
      widget.bounds.width = metrics.width + PadX * 2

    # Background
    bg.color = buttonColor
    bg.cornerRadius = radius
    bg.filled = true
    bg.bounds = widget.bounds

    # Centred label
    textLabel.text = widget.text
    textLabel.fontSize = fontSize
    textLabel.color = textColor
    textLabel.align = TextAlign.Center
    textLabel.bounds = Rect(
      x: widget.bounds.x + PadX,
      y: widget.bounds.y + (widget.bounds.height - metrics.height) / 2,
      width: max(0.0f32, widget.bounds.width - PadX * 2),
      height: metrics.height
    )

# ============================================================================
# Scripting Support
# ============================================================================
#
# handleScriptAction / getScriptableState are generated by defineWidget for
# every widget (see rui_core/widget_dsl.nim). The hand-written versions that
# used to live here supported "click" and "getText"; both are covered
# generically -- "click" resolves to the declared onClick action, and
# "getText"/"read" expose the `text` prop, still gated on widget.blockReading.
