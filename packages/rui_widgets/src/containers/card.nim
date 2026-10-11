## Card -- a themed surface around one child.
##
## What yui calls `card`: content on a raised, bordered, rounded panel, padded
## by the theme. Where Panel is a framed box for a form, a Card is the unit of a
## dashboard or a list of items. `padding` overrides the theme's (a number, all
## sides); `intent` picks the theme colours (`Danger` makes an alert card).
##
## ```nim
## Card(padding = 16):
##   Label(text = "Storage")
##   ProgressBar(...)
## ```

import rui_core
import rui_drawing

proc cardInsets(widget: Widget, padding: float32, intent: ThemeIntent): EdgeInsets =
  if padding >= 0: EdgeInsets.all(padding)
  else: currentTheme.getThemeProps(intent).padding.get(EdgeInsets.all(12.0))

defineWidget(Card):
  props:
    padding: float32 = -1.0       # < 0: the theme's padding
    intent: ThemeIntent = Default

  layout:
    wrapChild(widget, cardInsets(widget, widget.padding, widget.intent))

  render:
    drawThemedRect(widget.bounds, currentTheme.getThemeProps(widget.intent, Normal))

method computeSize*(widget: Card, c: Constraints): Size =
  widget.wrapSize(c, cardInsets(widget, widget.padding, widget.intent))
