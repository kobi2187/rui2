## What the pickers share with the ComboBox: a closed field, and a popup that
## floats on the overlay layer below it (or above, when the window has no room).

import std/options
import rui_core
import raylib

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

template popupFieldClick*(widget, popupOf: untyped): bool =
  ## A press on the closed field: toggle the popup (unless disabled). The value
  ## is whether the press was taken.
  block:
    let w = widget
    if w.disabled: false
    else:
      w.setFieldOpen(popupOf, not w.isOpen)
      true

template popupToggleKey*(widget, popupOf, event: untyped): bool =
  ## Enter, Space or F4 toggles the popup; Escape closes it if open. The value
  ## is whether the key was taken.
  block:
    let w = widget
    case event.key
    of KeyboardKey.Enter, KeyboardKey.KpEnter, KeyboardKey.Space, KeyboardKey.F4:
      w.setFieldOpen(popupOf, not w.isOpen)
      true
    of KeyboardKey.Escape:
      if w.isOpen:
        w.setFieldOpen(popupOf, false)
        true
      else: false
    else: false

proc highlightKey*(key: KeyboardKey, count, current: int): int =
  ## Where Up/Down/Home/End put the highlight in a popup list of `count` rows,
  ## clamped to the ends; -1 when `key` is not one of them.
  if count <= 0: return -1
  case key
  of KeyboardKey.Down: min(count - 1, max(0, current + 1))
  of KeyboardKey.Up: max(0, current - 1)
  of KeyboardKey.Home: 0
  of KeyboardKey.End: count - 1
  else: -1
