## Where the parts of a file dialog sit inside its panel.
##
## Split out of filedialog.nim. Every rect here is derived from the panel rect
## alone, so the event handlers and `render` cannot disagree about where a
## button is -- which is the bug class this replaces: the old dialog drew
## raygui buttons from inside `render` and hit-tested them separately.

import rui_core
import virtual_rows

type
  FileDialogMode* = enum
    fdOpen              # Open an existing file
    fdSave              # Save a file (a new name is allowed)
    fdDirectory         # Choose a directory

const
  TitleBarHeight* = 30.0'f32
  RowHeight* = 20.0'f32
  ButtonWidth* = 80.0'f32
  ButtonHeight* = 30.0'f32
  Margin* = 10.0'f32
  HeaderHeight* = 70.0'f32
    ## Title bar plus the path strip above the list.

proc listViewport*(list: Rect, scrollY: float32): RowViewport =
  ## The file list's scrollable body, inside the dialog panel.
  rowViewport(top = list.y, height = list.height,
              rowHeight = RowHeight, scrollY = scrollY)

proc okLabelFor*(mode: FileDialogMode): string =
  ## The affirmative button says what it will do, which is the difference
  ## between a dialog you can use without reading the title bar and one you
  ## cannot.
  case mode
  of fdOpen: "Open"
  of fdSave: "Save"
  of fdDirectory: "Select"

proc listRect*(panel: Rect): Rect =
  ## The file list area inside the panel.
  Rect(x: panel.x + Margin, y: panel.y + HeaderHeight,
       width: panel.width - Margin * 2,
       height: panel.height - HeaderHeight - ButtonHeight - Margin * 3)

proc okRect*(panel: Rect): Rect =
  Rect(x: panel.x + panel.width - ButtonWidth - 20,
       y: panel.y + panel.height - ButtonHeight - 15,
       width: ButtonWidth, height: ButtonHeight)

proc cancelRect*(panel: Rect): Rect =
  ## Left of OK, so the affirmative action is in the corner the pointer is
  ## already heading for.
  let ok = okRect(panel)
  Rect(x: ok.x - ButtonWidth - Margin, y: ok.y,
       width: ButtonWidth, height: ButtonHeight)
