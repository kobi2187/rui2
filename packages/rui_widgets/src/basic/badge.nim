## Badge -- a small pill with a count or a word: "3", "New", "beta".
##
## It reports status rather than takes input, so it is not focusable. `intent`
## colours it (`Danger` for an error count, `Success` for "online").
##
## ```nim
## Badge(text = "3", intent = Danger)
## Label(text = "Inbox") ; Badge(text = $unread.value)
## ```

import rui_core
import rui_drawing
import std/options

const BadgeMinHeight = 18.0'f32


proc badgeFill(props: ThemeProps): Color =
  ## The intent's strong colour: its accent hue (red for Danger), or its ink for a
  ## theme that gives the intent no hue of its own.
  props.activeColor.get(props.foregroundColor.get(Color(r: 200, g: 50, b: 50, a: 255)))

proc badgeStyle(props: ThemeProps): TextStyle =
  ## The ink that reads on the badge's fill.
  props.captionStyle(onFillInk(badgeFill(props)), size = 12.0)

definePrimitive(Badge):
  props:
    text: string = ""
    intent: ThemeIntent = Danger

  layout:
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    let m = measureText(widget.text, badgeStyle(props))
    let h = max(BadgeMinHeight, m.height + 4)
    if widget.bounds.height <= 0: widget.bounds.height = h
    if widget.bounds.width <= 0:
      widget.bounds.width = max(h, m.width + h * 0.7'f32)   # a circle for one digit

  render:
    let props = currentTheme.getThemeProps(widget.intent, Normal)
    let fill = badgeFill(props)
    drawBox(widget.bounds, widget.bounds.height / 2, fill, fill, 0)
    let style = badgeStyle(props)
    let m = measureText(widget.text, style)
    drawStyledText(widget.text, widget.bounds.x + (widget.bounds.width - m.width) / 2,
                   widget.bounds.y + (widget.bounds.height - style.fontSize) / 2, style)
