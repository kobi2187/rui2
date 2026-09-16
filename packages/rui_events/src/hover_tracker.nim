## Hover ownership.
##
## `Widget.hovered` is the flag themes resolve their state from
## (`elif widget.hovered: Hovered`) and the one Tooltip hides itself on. Nothing
## owned it: `app.nim` set it `true` on the widget under the pointer and no code
## anywhere ever set it back, so a widget that had been hovered once stayed lit
## for the life of the process — every button kept its highlight after the
## pointer left, and a Tooltip could never hide once shown.
##
## Focus already had an owner in `FocusManager`, and hover is the same shape:
## one widget at a time, cleared on transition. This is that, deliberately kept
## as small as the job.
##
## Note this is distinct from the `isHovered` *state field* some widgets keep
## for themselves (Button, ToolButton). Those are self-managed from the widget's
## own `on_mouse_move` and are not this module's business.

import rui_core

type
  HoverTracker* = ref object
    current: Widget

proc newHoverTracker*(): HoverTracker =
  HoverTracker(current: nil)

proc hovered*(tracker: HoverTracker): Widget =
  ## The widget currently under the pointer, or nil.
  tracker.current

proc setHover*(tracker: HoverTracker, widget: Widget): bool =
  ## Move hover to `widget`, or clear it entirely when `widget` is nil.
  ##
  ## Returns **true when the hover actually moved**, so the caller knows whether
  ## anything needs repainting. Re-hovering the same widget every mouse-move —
  ## which is the common case, since the pointer usually stays put — reports
  ## false and touches nothing.
  if tracker.current == widget:
    return false

  if tracker.current != nil:
    tracker.current.hovered = false
    tracker.current.isDirty = true

  tracker.current = widget

  if widget != nil:
    widget.hovered = true
    widget.isDirty = true

  true

proc widgetRemoved*(tracker: HoverTracker, widget: Widget) =
  ## Forget a widget that is leaving the tree, so the tracker never holds a
  ## reference to something detached. Mirrors `FocusManager.widgetRemoved`.
  if tracker.current == widget:
    if widget != nil:
      widget.hovered = false
    tracker.current = nil

proc clear*(tracker: HoverTracker) =
  ## Drop hover entirely, e.g. when the pointer leaves the window.
  discard tracker.setHover(nil)
