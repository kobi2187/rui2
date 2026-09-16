## MessageBox Widget - RUI2
##
## A modal dialog for messages and confirmations: Info, Warning, Error, Question.
##
## The widget covers the whole screen, because that is the only way to dim what
## is behind it -- renderPass clips every widget to its own bounds, so a dialog
## sized to its panel could not paint an overlay around itself. `bounds` is the
## screen; `panelRect` is the box in the middle.

import rui_core
import rui_drawing
import modal
import std/options

import raylib

type
  MessageBoxType* = enum
    mbInfo
    mbWarning
    mbError
    mbQuestion

  MessageBoxButtons* = enum
    mbOK                # Just OK
    mbOKCancel          # OK and Cancel
    mbYesNo             # Yes and No
    mbYesNoCancel       # Yes, No and Cancel

  MessageBoxResult* = enum
    mrNone = 0
    mrOK = 1
    mrCancel = 2
    mrYes = 3
    mrNo = 4

  DialogButton* = tuple[label: string, res: MessageBoxResult, rect: Rect]

const
  TitleBarHeight = 30.0'f32
  ButtonWidth = 80.0'f32
  ButtonHeight = 30.0'f32
  ButtonGap = 10.0'f32

proc buttonLabels(buttons: MessageBoxButtons): seq[(string, MessageBoxResult)] =
  ## Right to left, so the affirmative action sits in the bottom-right corner.
  case buttons
  of mbOK:          @[("OK", mrOK)]
  of mbOKCancel:    @[("OK", mrOK), ("Cancel", mrCancel)]
  of mbYesNo:       @[("Yes", mrYes), ("No", mrNo)]
  of mbYesNoCancel: @[("Yes", mrYes), ("No", mrNo), ("Cancel", mrCancel)]

proc dialogButtons*(panel: Rect, buttons: MessageBoxButtons): seq[DialogButton] =
  ## Button rects laid out right to left along the bottom of the panel.
  ## Hit-testing and painting both read this, so they cannot drift apart.
  var x = panel.x + panel.width - ButtonWidth - 20.0
  let y = panel.y + panel.height - ButtonHeight - 15.0
  for (label, res) in buttonLabels(buttons):
    result.add((label: label, res: res,
                rect: Rect(x: x, y: y, width: ButtonWidth, height: ButtonHeight)))
    x -= ButtonWidth + ButtonGap

proc intentFor(t: MessageBoxType): ThemeIntent =
  ## Same disambiguation problem as alertLevelFor. `Info` belongs to both
  ## ThemeIntent and AlertLevel, and `Warning` to both ThemeIntent and
  ## ValidationState -- all four are rui_drawing's own enums, so trimming
  ## rui_core's raylib re-export does not help here. A `case` inside a macro
  ## body has no expected type to resolve against; a declared return type does.
  case t
  of mbInfo: Info
  of mbWarning: Warning
  of mbError: Danger
  of mbQuestion: Default

proc alertLevelFor(t: MessageBoxType): AlertLevel =
  ## AlertLevel is Info/Alert/Critical. The declared return type is what
  ## disambiguates `Info`, which ThemeIntent also has.
  case t
  of mbWarning: Alert
  of mbError: Critical
  of mbInfo, mbQuestion: Info

definePrimitive(MessageBox):
  props:
    title: string = "Message"
    message: string = ""
    messageType: MessageBoxType = mbInfo
    buttons: MessageBoxButtons = mbOK
    dialogWidth: float32 = 400.0
    dialogHeight: float32 = 200.0

  state:
    isVisible: bool
    dialogResult: MessageBoxResult
    hoverResult: MessageBoxResult

  actions:
    onClose(res: MessageBoxResult)

  events:
    on_mouse_down:
      if not widget.isVisible:
        return false
      let panel = panelRect(widget.bounds, widget.dialogWidth, widget.dialogHeight)
      for button in dialogButtons(panel, widget.buttons):
        if button.rect.contains(event.mousePos.x, event.mousePos.y):
          widget.isVisible = false
          widget.dialogResult = button.res
          widget.isDirty = true
          if widget.onClose.isSome:
            widget.onClose.get()(button.res)
          return true
      # A modal swallows every click, including the ones that miss a button.
      return true

    on_mouse_move:
      if not widget.isVisible:
        return false
      let panel = panelRect(widget.bounds, widget.dialogWidth, widget.dialogHeight)
      var newHover = mrNone
      for button in dialogButtons(panel, widget.buttons):
        if button.rect.contains(event.mousePos.x, event.mousePos.y):
          newHover = button.res
          break
      if newHover != widget.hoverResult:
        widget.hoverResult = newHover
        widget.isDirty = true
      return true

    on_key_down:
      if not widget.isVisible:
        return false
      # Escape cancels; Enter takes the first (affirmative) button.
      let res = case event.key
                of Escape:
                  if widget.buttons == mbOK: mrOK else: mrCancel
                of Enter, KpEnter:
                  buttonLabels(widget.buttons)[0][1]
                else:
                  mrNone
      if res == mrNone:
        return false
      widget.isVisible = false
      widget.dialogResult = res
      widget.isDirty = true
      if widget.onClose.isSome:
        widget.onClose.get()(res)
      return true

  layout:
    # Fill the screen so the dim overlay has somewhere to go.
    widget.bounds = overlayBounds()

  render:
    if not widget.isVisible:
      return

    drawRect(widget.bounds, Color(r: 0, g: 0, b: 0, a: 128))

    let intent = intentFor(widget.messageType)
    let props = currentTheme.getThemeProps(intent, Normal)
    let panel = panelRect(widget.bounds, widget.dialogWidth, widget.dialogHeight)

    drawShadow(panel, Shadow(offsetX: 3.0, offsetY: 3.0, blur: 0.0, spread: 0.0,
                             color: Color(r: 0, g: 0, b: 0, a: 60)))
    drawThemedBackground(panel, props)
    drawThemedBorder(panel, props)

    let titleRect = Rect(x: panel.x, y: panel.y,
                         width: panel.width, height: TitleBarHeight)
    let titleProps = currentTheme.getThemeProps(intent, Selected)
    drawThemedBackground(titleRect, titleProps)
    drawThemedPaddedText(widget.title, titleRect, titleProps, selected = true)

    let iconRect = Rect(x: panel.x + 20, y: panel.y + 50, width: 32, height: 32)
    drawAlertSymbol(iconRect, alertLevelFor(widget.messageType),
                    props.foregroundColor)

    # Wrap the message inside the panel instead of letting it run off the edge.
    let style = TextStyle(fontFamily: "", fontSize: 14.0,
                          color: props.foregroundColor.get(
                            Color(r: 60, g: 60, b: 60, a: 255)),
                          bold: false, italic: false, underline: false)
    let messageRect = Rect(
      x: panel.x + 70, y: panel.y + 58,
      width: panel.width - 90,
      height: panel.height - 58 - ButtonHeight - 30
    )
    drawText(widget.message, messageRect, style, TextAlign.Left)

    for button in dialogButtons(panel, widget.buttons):
      let bProps = currentTheme.getThemeProps(intent,
        if button.res == widget.hoverResult: Hovered else: Normal)
      drawButton(button.rect, button.label, bProps,
                 hovered = button.res == widget.hoverResult)

proc show*(widget: MessageBox) =
  ## Display the dialog.
  widget.isVisible = true
  widget.dialogResult = mrNone
  widget.isDirty = true
  widget.layoutDirty = true
