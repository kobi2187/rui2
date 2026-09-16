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
  TitleBarHeight* = 30.0'f32
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

proc alertLevelFor*(t: MessageBoxType): AlertLevel =
  ## AlertLevel is Info/Alert/Critical. The declared return type is what
  ## disambiguates `Info`, which ThemeIntent also has.
  case t
  of mbWarning: Alert
  of mbError: Critical
  of mbInfo, mbQuestion: Info

