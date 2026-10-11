## Dialog -- a modal window around whatever you put in it.
##
## MessageBox answers a question; a Dialog holds a form, a picker, a settings
## page: its first child is the content, you add the buttons. It dims what is
## behind, centres a titled panel sized to the content (or `dialogWidth`), and
## swallows every click that does not land inside. Escape closes it; with
## `closeOnBackdrop` so does a click outside the panel. Like MessageBox it
## covers the whole screen, so add it last to the root and open it with
## `show()`, close it with `close()`. Tab still reaches what is behind it.
##
## ```nim
## let dlg = ui:
##   Dialog(title = "Rename"):
##     Column(spacing = 8.0):
##       TextInput(initialText = "draft")
##       Button(text = "OK", onClick = proc() = dlg.close())
## dlg.show()
## ```

import rui_core
import rui_drawing
import modal, messagebox_layout
from raylib import KeyboardKey

const DialogPad = 16.0'f32

template panelRectOf(w: untyped): Rect =
  ## The panel: as wide as `dialogWidth`, or the content (at least 240), and
  ## as tall as the content under a title bar.
  block:
    let narrow = if w.dialogWidth > 0: w.dialogWidth - DialogPad * 2 else: 0.0'f32
    let content = if w.children.len == 0: Size()
                  else: w.children[0].measure(
                    if narrow > 0: unbounded().withWidth(narrow) else: unbounded())
    let width = if w.dialogWidth > 0: w.dialogWidth
                else: max(content.width + DialogPad * 2, 240.0'f32)
    panelRect(w.bounds, width, content.height + TitleBarHeight + DialogPad * 2)

template closeDialog(w: untyped) =
  w.isOpen = false
  w.visible = false
  w.isDirty = true
  if w.onClose != nil: w.onClose()

definePrimitive(Dialog):
  props:
    title: string = ""
    dialogWidth: float32 = 0.0      # 0: as wide as the content
    closeOnBackdrop: bool = false

  state:
    isOpen: bool

  actions:
    onClose()

  init:
    widget.focusable = true
    widget.visible = false

  events:
    on_mouse_down:
      if not widget.isOpen: return false
      let panel = panelRectOf(widget)
      if widget.closeOnBackdrop and not panel.contains(event.mousePos.x, event.mousePos.y):
        closeDialog(widget)
      return true                    # a modal takes every click

    on_key_down:
      if not widget.isOpen: return false
      if event.key == KeyboardKey.Escape:
        closeDialog(widget)
        return true
      return false

  layout:
    widget.bounds = overlayBounds()
    if widget.children.len > 0:
      let panel = panelRectOf(widget)
      widget.children[0].arrange(Rect(
        x: panel.x + DialogPad, y: panel.y + TitleBarHeight + DialogPad,
        width: panel.width - DialogPad * 2,
        height: panel.height - TitleBarHeight - DialogPad * 2))

  render:
    if not widget.isOpen: return
    drawRect(widget.bounds, Color(r: 0, g: 0, b: 0, a: 128))
    let props = currentTheme.getThemeProps(Default, Normal)
    let panel = panelRectOf(widget)
    drawShadow(panel, Shadow(offsetX: 3.0, offsetY: 3.0, blur: 0.0, spread: 0.0,
                             color: Color(r: 0, g: 0, b: 0, a: 60)))
    drawThemedBackground(panel, props)
    drawThemedBorder(panel, props)
    let titleRect = Rect(x: panel.x, y: panel.y, width: panel.width, height: TitleBarHeight)
    let titleProps = currentTheme.getThemeProps(Default, Selected)
    drawThemedBackground(titleRect, titleProps)
    drawThemedPaddedText(widget.title, titleRect, titleProps, selected = true)

proc show*(widget: Dialog) =
  widget.isOpen = true
  widget.visible = true
  widget.isDirty = true
  widget.layoutDirty = true
  wantFocus(widget)

proc close*(widget: Dialog) = closeDialog(widget)
