# Touch and several pointers

A pinch is two pointers dragging at once, so RUI2 does not recognise gestures: the
pointer is an id, and widgets that want several read them.

- `GuiEvent.pointerId`: 0 is the mouse or the first finger (raylib folds it into the
  mouse); a second finger is 2, a third 3, and so on. Every ordinary widget only ever sees 0.
- A widget that sets `multiPointer = true` (in `init:`) is also offered the others, and
  each is captured to it until it lifts (`capturePointer(w, id)`). Hover and focus follow
  pointer 0 only.
- `Pointers` (`rui_widgets/src/pointers.nim`) turns the pointers into a change: pass every
  mouse event through `widget.fingers.feed(event)`; with two down, `change.scale` is the
  ratio of their distance, `change.rotation` the turn of the line between them,
  `change.pan` how far its midpoint moved and `change.anchor` where it is. It is measured
  per event, so an anchor finger that moves a moment later just works, and lifting or
  adding a finger never jumps.

What uses it: `MapWidget` and `Timeline` zoom about the point between the fingers;
`ScrollView` scrolls with a finger beyond the first; the row lists (`ListView`,
`ListBox`, `TreeView`, `DataTable`, `DataGrid`) scroll with two fingers.

## Mouse or touch

`isTouch()` (rui_core/input_mode.nim) is the one global widgets consult. With a mouse a
press selects at once. With fingers a drag on a row list scrolls it, so the press is held
back and replayed if the finger lifts without having moved (a tap).

The mode starts as desktop (touch on Android); `RUI_INPUT=touch|desktop` or
`setInputMode(...)` set it, and two fingers down at once switch an unpinned app to touch.
`scroll_drag.nim`'s `rowsTouch` is the shared code for the row lists.

Not yet: one-finger scrolling in `ScrollView` (a press lands on the child first), flings,
rotation in the Map, and real-device testing (raylib's own touch to mouse emulation is
assumed to mirror finger 0).
