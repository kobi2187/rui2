## Label Widget - Text display with theme support
##
## Features:
## - Theme-aware text rendering
## - State-based styling (Normal, Hovered, etc.)
## - Intent support (Default, Info, Success, Warning, Danger)
## - YAML-UI compatible

import raylib
import ../../core/[types, widget_dsl]
import ../../drawing_primitives/[theme_sys_core, drawing_primitives]

export types, widget_dsl, theme_sys_core, drawing_primitives.TextAlign

defineWidget(Label):
  props:
    text: string
    intent: ThemeIntent
    state: ThemeState
    theme: Theme
    textAlign: TextAlign

  init:
    widget.text = "Label"
    widget.bounds.width = 100
    widget.bounds.height = 30
    widget.intent = ThemeIntent.Default
    widget.state = ThemeState.Normal
    widget.textAlign = TextAlign.Left
    # Theme should be set by parent/app

  render:
    when defined(useGraphics):
      # Get themed properties
      let props = widget.theme.getThemeProps(widget.intent, widget.state)

      # Background (if specified)
      if props.backgroundColor.isSome:
        let bgColor = props.backgroundColor.get()
        let cornerRad = if props.cornerRadius.isSome:
                         props.cornerRadius.get()
                       else:
                         0.0
        if cornerRad > 0:
          drawRoundedRect(widget.bounds, cornerRad, bgColor, true)
        else:
          drawRect(widget.bounds, bgColor, true)

      # Border (if specified)
      if props.borderColor.isSome and props.borderWidth.isSome:
        let borderColor = props.borderColor.get()
        let cornerRad = if props.cornerRadius.isSome:
                         props.cornerRadius.get()
                       else:
                         0.0
        if cornerRad > 0:
          drawRoundedRect(widget.bounds, cornerRad, borderColor, false)
        else:
          drawRect(widget.bounds, borderColor, false)

      # Text
      let fgColor = if props.foregroundColor.isSome:
                      props.foregroundColor.get()
                    else:
                      WHITE

      let fontSize = if props.fontSize.isSome:
                      int32(props.fontSize.get())
                     else:
                      14'i32

      let fontFamily = if props.fontFamily.isSome:
                         props.fontFamily.get()
                       else:
                         ""  # Empty = use default

      let textStyle = TextStyle(
        fontFamily: fontFamily,
        fontSize: float32(fontSize),
        color: fgColor,
        bold: false,
        italic: false,
        underline: false
      )

      # Apply padding if specified
      var textRect = widget.bounds
      if props.padding.isSome:
        let p = props.padding.get()
        textRect = Rect(
          x: widget.bounds.x + p.left,
          y: widget.bounds.y + p.top,
          width: widget.bounds.width - p.left - p.right,
          height: widget.bounds.height - p.top - p.bottom
        )

      drawText(widget.text, textRect, textStyle, widget.textAlign)
