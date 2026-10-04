## Toast -- a short message that appears over the app and goes by itself.
##
## You do not build one by hand: `app.toast("Saved")` shows it at the bottom of
## the window, stacked above any others, and removes it after a few seconds.
## This is the widget the App creates. It is as wide as its text needs, in the
## theme's colours for its intent (a Danger toast is red-tinted).
##
## ```nim
## app.toast("Saved")
## app.toast("Could not reach the server", intent = ThemeIntent.Danger, seconds = 6)
## ```

import rui_core
import rui_drawing
import raylib

definePrimitive(Toast):
  props:
    text: string = ""
    intent: ThemeIntent = Default

  layout:
    let props = currentTheme.getThemeProps(widget.intent)
    let style = props.captionStyle(BLACK)
    let m = measureText(widget.text, style)
    let pad = props.fieldInset * 1.5'f32
    if widget.bounds.width <= 0:
      widget.bounds.width = m.width + pad * 2
    if widget.bounds.height <= 0:
      widget.bounds.height = m.height + pad * 1.4'f32

  render:
    let props = currentTheme.getThemeProps(widget.intent)
    let ink = props.foregroundColor.get(BLACK)
    let style = props.captionStyle(ink)
    let pad = props.fieldInset * 1.5'f32
    let radius = props.cornerRadius.get(6.0'f32)
    # A soft shadow under it, then the box: it floats above everything.
    drawBox(Rect(x: widget.bounds.x + 1, y: widget.bounds.y + 3, width: widget.bounds.width - 2,
                 height: widget.bounds.height - 2), radius, Color(r: 0, g: 0, b: 0, a: 50),
            ink, 0)
    drawBox(Rect(x: widget.bounds.x, y: widget.bounds.y, width: widget.bounds.width,
                 height: widget.bounds.height - 2), radius,
            props.backgroundColor.get(WHITE), props.borderColor.get(ink), props.strokeWidth)
    drawStyledText(widget.text, widget.bounds.x + pad,
                   widget.bounds.y + (widget.bounds.height - 2 - style.fontSize) / 2, style)
