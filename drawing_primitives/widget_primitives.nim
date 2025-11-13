## Theme-Aware Widget Drawing Primitives
##
## Forth-style compositional design: build complex widgets from simpler parts.
## Each primitive is minimal and reusable.
##
## Layer architecture:
##   Layer 1: primitives/* (drawRect, drawText, etc.)
##   Layer 2: THIS MODULE (drawButton, drawSlider, etc.)
##   Layer 3: widgets/* (Button, Slider widgets)

import ../core/types
import theme_sys_core
import primitives/[shapes, text, controls, indicators, panels]

when defined(useGraphics):
  import raylib

export types, theme_sys_core

# ============================================================================
# Atomic Parts (smallest building blocks)
# ============================================================================

proc drawThemedBackground*(rect: Rect, props: ThemeProps,
                          pressed = false, hovered = false) =
  ## Draw background with state-based color selection
  when defined(useGraphics):
    let bgColor = if pressed:
                    props.pressedColor.get(props.backgroundColor.get(Color(r: 200, g: 200, b: 200, a: 255)))
                  elif hovered:
                    props.hoverColor.get(props.backgroundColor.get(Color(r: 220, g: 220, b: 220, a: 255)))
                  else:
                    props.backgroundColor.get(Color(r: 240, g: 240, b: 240, a: 255))

    let radius = props.borderRadius.get(4.0)
    drawRoundedRect(rect, radius, bgColor)

proc drawThemedBorder*(rect: Rect, props: ThemeProps, focused = false, active = false) =
  ## Draw border with state-based color selection
  when defined(useGraphics):
    if props.borderWidth.get(0.0) > 0:
      let borderColor = if focused:
                          props.focusColor.get(Color(r: 100, g: 150, b: 255, a: 255))
                        elif active:
                          props.activeColor.get(Color(r: 100, g: 150, b: 255, a: 255))
                        else:
                          props.borderColor.get(Color(r: 180, g: 180, b: 180, a: 255))

      let radius = props.borderRadius.get(4.0)
      drawRoundedRectLines(rect, radius, props.borderWidth.get(1.0), borderColor)

proc drawThemedFocusRing*(rect: Rect, props: ThemeProps) =
  ## Draw focus indicator
  when defined(useGraphics):
    let focusColor = props.focusColor.get(Color(r: 100, g: 150, b: 255, a: 255))
    drawFocusRing(rect, focusColor)

proc drawThemedText*(text: string, x, y: float32, props: ThemeProps,
                    selected = false, centered = false) =
  ## Draw text with theme color
  when defined(useGraphics):
    let textColor = if selected:
                      Color(r: 255, g: 255, b: 255, a: 255)  # White on selected
                    else:
                      props.foregroundColor.get(Color(r: 60, g: 60, b: 60, a: 255))

    drawText(text, x, y, props.fontSize.get(14.0), textColor, centered)

proc drawThemedCenteredText*(text: string, rect: Rect, props: ThemeProps,
                             selected = false) =
  ## Draw centered text in rectangle
  when defined(useGraphics):
    let textY = rect.y + (rect.height - props.fontSize.get(14.0)) / 2
    drawThemedText(text, rect.x + rect.width/2, textY, props, selected, centered = true)

proc drawThemedPaddedText*(text: string, rect: Rect, props: ThemeProps,
                          selected = false) =
  ## Draw left-aligned text with padding
  when defined(useGraphics):
    let padding = props.padding.get(8.0)
    let textY = rect.y + (rect.height - props.fontSize.get(14.0)) / 2
    drawThemedText(text, rect.x + padding, textY, props, selected)

proc drawDownArrow*(x, y, size: float32, color: Color) =
  ## Draw a downward-pointing arrow
  when defined(useGraphics):
    drawArrow(x, y, size, 90.0, color)

proc drawUpArrow*(x, y, size: float32, color: Color) =
  ## Draw an upward-pointing arrow
  when defined(useGraphics):
    drawArrow(x, y, size, -90.0, color)

proc drawRightArrow*(x, y, size: float32, color: Color) =
  ## Draw a rightward-pointing arrow
  when defined(useGraphics):
    drawArrow(x, y, size, 0.0, color)

# ============================================================================
# Compound Parts (combine atomic parts)
# ============================================================================

proc drawInteractiveBox*(rect: Rect, props: ThemeProps,
                        pressed = false, hovered = false, focused = false) =
  ## Standard interactive box: background + border + optional focus
  drawThemedBackground(rect, props, pressed, hovered)
  drawThemedBorder(rect, props, focused)
  if focused:
    drawThemedFocusRing(rect, props)

proc drawSelectionBackground*(rect: Rect, props: ThemeProps,
                             selected = false, hovered = false) =
  ## Draw background for selectable items (list items, menu items)
  when defined(useGraphics):
    if selected:
      let selColor = props.activeColor.get(Color(r: 100, g: 150, b: 255, a: 255))
      drawRect(rect, selColor)
    elif hovered:
      let hoverColor = props.hoverColor.get(Color(r: 240, g: 240, b: 240, a: 255))
      drawRect(rect, hoverColor)

# ============================================================================
# Widget Primitives (compose compound parts)
# ============================================================================

proc drawButton*(rect: Rect, text: string, props: ThemeProps,
                 pressed = false, hovered = false, focused = false) =
  ## Button = interactive box + centered text
  drawInteractiveBox(rect, props, pressed, hovered, focused)
  drawThemedCenteredText(text, rect, props)

proc drawCheckbox*(rect: Rect, checked: bool, props: ThemeProps,
                   hovered = false, focused = false) =
  ## Checkbox = box + border + optional checkmark + optional focus
  when defined(useGraphics):
    # Box
    let bgColor = if hovered:
                    props.hoverColor.get(Color(r: 250, g: 250, b: 250, a: 255))
                  else:
                    props.backgroundColor.get(Color(r: 255, g: 255, b: 255, a: 255))
    let radius = props.borderRadius.get(2.0)
    drawRoundedRect(rect, radius, bgColor)

    # Border
    drawThemedBorder(rect, props, focused, active = checked)

    # Checkmark
    if checked:
      let checkColor = props.activeColor.get(Color(r: 100, g: 150, b: 255, a: 255))
      drawCheckmark(rect, checkColor, props.borderWidth.get(2.0))

    # Focus
    if focused:
      drawThemedFocusRing(rect, props)

proc drawRadioButton*(rect: Rect, selected: bool, props: ThemeProps,
                      hovered = false, focused = false) =
  ## Radio button = radio circle + optional focus
  when defined(useGraphics):
    let color = if selected:
                  props.activeColor.get(Color(r: 100, g: 150, b: 255, a: 255))
                else:
                  props.borderColor.get(Color(r: 180, g: 180, b: 180, a: 255))

    drawRadioCircle(rect, selected, color)

    if focused:
      drawThemedFocusRing(rect, props)

proc drawSlider*(rect: Rect, value, minVal, maxVal: float32, props: ThemeProps,
                 dragging = false, hovered = false) =
  ## Slider = reuse existing primitive with theme colors
  when defined(useGraphics):
    drawSlider(
      rect,
      value,
      minVal,
      maxVal,
      props.activeColor.get(Color(r: 100, g: 150, b: 255, a: 255)),
      props.backgroundColor.get(Color(r: 220, g: 220, b: 220, a: 255)),
      dragging,
      hovered
    )

proc drawProgressBar*(rect: Rect, progress: float32, props: ThemeProps) =
  ## Progress bar = reuse existing primitive with theme colors
  when defined(useGraphics):
    drawProgressBar(
      rect,
      progress,
      props.activeColor.get(Color(r: 100, g: 150, b: 255, a: 255)),
      props.backgroundColor.get(Color(r: 220, g: 220, b: 220, a: 255))
    )

proc drawScrollbar*(rect: Rect, contentSize, viewSize, offset: float32,
                   props: ThemeProps, hovered = false) =
  ## Scrollbar = reuse existing primitive with theme colors
  when defined(useGraphics):
    drawScrollbar(
      rect,
      contentSize,
      viewSize,
      offset,
      props.foregroundColor.get(Color(r: 160, g: 160, b: 160, a: 255)),
      hovered
    )

proc drawMenuItem*(rect: Rect, text: string, props: ThemeProps,
                   selected = false, hovered = false, hasSubmenu = false) =
  ## Menu item = selection background + padded text + optional arrow
  when defined(useGraphics):
    drawSelectionBackground(rect, props, selected, hovered)
    drawThemedPaddedText(text, rect, props, selected)

    # Submenu arrow
    if hasSubmenu:
      let padding = props.padding.get(8.0)
      let arrowX = rect.x + rect.width - padding - 8
      let arrowY = rect.y + rect.height / 2
      let textColor = if selected:
                        Color(r: 255, g: 255, b: 255, a: 255)
                      else:
                        props.foregroundColor.get(Color(r: 60, g: 60, b: 60, a: 255))
      drawRightArrow(arrowX, arrowY, 8.0, textColor)

proc drawListItem*(rect: Rect, text: string, props: ThemeProps,
                   selected = false, hovered = false, focused = false) =
  ## List item = selection background + padded text
  ## (same as menu item but without submenu arrow)
  drawSelectionBackground(rect, props, selected, hovered)
  drawThemedPaddedText(text, rect, props, selected)

proc drawComboBox*(rect: Rect, text: string, props: ThemeProps,
                   isOpen = false, hovered = false, focused = false) =
  ## Combo box = interactive box + padded text + down/up arrow
  when defined(useGraphics):
    drawInteractiveBox(rect, props, hovered = hovered, focused = focused)
    drawThemedPaddedText(text, rect, props)

    # Dropdown arrow
    let padding = props.padding.get(8.0)
    let arrowX = rect.x + rect.width - padding - 8
    let arrowY = rect.y + rect.height / 2
    let textColor = props.foregroundColor.get(Color(r: 60, g: 60, b: 60, a: 255))

    if isOpen:
      drawUpArrow(arrowX, arrowY, 8.0, textColor)
    else:
      drawDownArrow(arrowX, arrowY, 8.0, textColor)

proc drawTab*(rect: Rect, text: string, props: ThemeProps,
              active = false, hovered = false) =
  ## Tab = background + bottom indicator + centered text
  when defined(useGraphics):
    # Background
    let bgColor = if active:
                    props.backgroundColor.get(Color(r: 255, g: 255, b: 255, a: 255))
                  elif hovered:
                    props.hoverColor.get(Color(r: 240, g: 240, b: 240, a: 255))
                  else:
                    Color(r: 220, g: 220, b: 220, a: 255)

    let radius = props.borderRadius.get(4.0)
    drawRoundedRect(rect, radius, bgColor)

    # Active indicator bar at bottom
    if active:
      let indicatorHeight = 3.0
      let indicatorRect = Rect(
        x: rect.x,
        y: rect.y + rect.height - indicatorHeight,
        width: rect.width,
        height: indicatorHeight
      )
      let activeColor = props.activeColor.get(Color(r: 100, g: 150, b: 255, a: 255))
      drawRect(indicatorRect, activeColor)

    # Text (dimmed if inactive)
    let textColor = if active:
                      props.foregroundColor.get(Color(r: 60, g: 60, b: 60, a: 255))
                    else:
                      Color(r: 120, g: 120, b: 120, a: 255)
    let textY = rect.y + (rect.height - props.fontSize.get(14.0)) / 2
    drawText(text, rect.x + rect.width/2, textY, props.fontSize.get(14.0), textColor, centered = true)

proc drawSpinnerButtons*(rect: Rect, props: ThemeProps,
                        upHovered = false, downHovered = false) =
  ## Spinner up/down buttons on the right side of a rect
  when defined(useGraphics):
    let buttonWidth = 16.0
    let buttonHeight = rect.height / 2
    let textColor = props.foregroundColor.get(Color(r: 60, g: 60, b: 60, a: 255))

    # Up button
    let upRect = Rect(
      x: rect.x + rect.width - buttonWidth,
      y: rect.y,
      width: buttonWidth,
      height: buttonHeight
    )
    if upHovered:
      drawRect(upRect, props.hoverColor.get(Color(r: 240, g: 240, b: 240, a: 255)))
    drawUpArrow(upRect.x + buttonWidth/2, upRect.y + buttonHeight/2, 6.0, textColor)

    # Down button
    let downRect = Rect(
      x: rect.x + rect.width - buttonWidth,
      y: rect.y + buttonHeight,
      width: buttonWidth,
      height: buttonHeight
    )
    if downHovered:
      drawRect(downRect, props.hoverColor.get(Color(r: 240, g: 240, b: 240, a: 255)))
    drawDownArrow(downRect.x + buttonWidth/2, downRect.y + buttonHeight/2, 6.0, textColor)

proc drawSpinner*(rect: Rect, value: string, props: ThemeProps,
                  upHovered = false, downHovered = false, focused = false) =
  ## Spinner = interactive box + padded text + up/down buttons
  drawInteractiveBox(rect, props, focused = focused)
  drawThemedPaddedText(value, rect, props)
  drawSpinnerButtons(rect, props, upHovered, downHovered)

proc drawGroupBox*(rect: Rect, title: string, props: ThemeProps) =
  ## Group box = reuse existing primitive with theme colors
  when defined(useGraphics):
    drawGroupBox(
      rect,
      title,
      props.borderColor.get(Color(r: 180, g: 180, b: 180, a: 255)),
      props.foregroundColor.get(Color(r: 60, g: 60, b: 60, a: 255)),
      props.fontSize.get(14.0)
    )

proc drawStatusBar*(rect: Rect, text: string, props: ThemeProps) =
  ## Status bar = background + top border + padded text
  when defined(useGraphics):
    # Background
    let bgColor = props.backgroundColor.get(Color(r: 240, g: 240, b: 240, a: 255))
    drawRect(rect, bgColor)

    # Top border
    let borderColor = props.borderColor.get(Color(r: 200, g: 200, b: 200, a: 255))
    drawLine(rect.x, rect.y, rect.x + rect.width, rect.y, borderColor, 1.0)

    # Text
    let padding = props.padding.get(8.0)
    let textY = rect.y + (rect.height - props.fontSize.get(12.0)) / 2
    let textColor = props.foregroundColor.get(Color(r: 80, g: 80, b: 80, a: 255))
    drawText(text, rect.x + padding, textY, props.fontSize.get(12.0), textColor)
