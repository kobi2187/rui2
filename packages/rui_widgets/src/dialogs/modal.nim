## Shared geometry for modal dialogs.
##
## A modal sizes its `bounds` to the whole screen, because that is the only way
## to dim what is behind it: renderPass draws each widget into a render texture
## sized to its own bounds, so a dialog sized to its panel could not paint an
## overlay around itself. The panel is then centred inside those bounds.

import rui_core

import raylib

proc overlayBounds*(): Rect =
  ## The full-screen rect a modal should occupy.
  Rect(x: 0, y: 0,
       width: float32(getScreenWidth()),
       height: float32(getScreenHeight()))

proc panelRect*(bounds: Rect, width, height: float32): Rect =
  ## The dialog box, centred in the overlay.
  Rect(x: bounds.x + (bounds.width - width) / 2,
       y: bounds.y + (bounds.height - height) / 2,
       width: width, height: height)
