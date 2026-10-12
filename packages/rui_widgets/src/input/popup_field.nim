## What the pickers share with the ComboBox: a closed field, and a popup that
## floats on the overlay layer below it (or above, when the window has no room).

import std/options
import rui_core

proc popupRect*(field: Rect, width, height: float32): Rect =
  ## Where a popup of this size goes: below the field, flipped above it when
  ## the window has no room underneath.
  var top = field.y + field.height
  if renderView.isSome:
    let view = renderView.get
    if top + height > view.y + view.height and field.y - height >= view.y:
      top = field.y - height
  Rect(x: field.x, y: top, width: width, height: height)

template setFieldOpen*(widget, popupOf: untyped, wantOpen: bool) =
  ## Show or hide the popup. Open, it is a registered popup -- a press anywhere
  ## else closes it -- on the overlay layer, where it takes the pointer.
  block:
    let w = widget
    let wanted = wantOpen              # evaluated once: it may read isOpen
    if w.isOpen != wanted:
      w.isOpen = wanted
      w.isDirty = true
      w.layoutDirty = true
      let popup = popupOf
      if wanted:
        openPopup(w, scope = w, close = proc() =
          w.isOpen = false
          hideOverlay(popup)
          w.isDirty = true
          w.layoutDirty = true)
        showOverlay(popup, interactive = true)
      else:
        closedPopup(w)
        hideOverlay(popup)
