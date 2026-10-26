## A message box's button set, and where each button sits.
##
## Split out of messagebox.nim. Hit-testing and painting both read
## `dialogButtons`, which is what stops them drifting apart -- the old dialog
## drew raygui buttons from inside `render` and fired them from there too, so
## the rect a click was tested against never existed as a value at all.

import rui_core
import rui_drawing

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
  ButtonWidth* = 80.0'f32
  ButtonHeight* = 30.0'f32
  ButtonGap* = 10.0'f32

proc buttonLabels*(buttons: MessageBoxButtons): seq[(string, MessageBoxResult)] =
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

proc intentFor*(t: MessageBoxType): ThemeIntent =
  ## The theme intent a message box of this type is drawn in.
  case t
  of mbInfo: Info
  of mbWarning: Warning
  of mbError: Danger
  of mbQuestion: Default

proc alertLevelFor*(t: MessageBoxType): AlertLevel =
  ## The symbol a message box of this type shows.
  case t
  of mbWarning: alAlert
  of mbError: alCritical
  of mbInfo, mbQuestion: alInfo

