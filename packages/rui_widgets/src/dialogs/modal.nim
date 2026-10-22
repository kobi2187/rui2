## Shared geometry for modal dialogs.
##
## A modal sizes its `bounds` to the whole screen, because it paints what is
## behind it: renderPass draws each widget into a render texture sized to its
## own bounds, so a dialog sized to its panel could not paint around itself.
## The panel is then centred inside those bounds.
##
## While it is open the page behind it is frozen (rui_core freeze.nim): the
## App keeps one picture of it, in the theme's backdrop look, which the modal
## draws as its background, and only the modal is laid out and painted.
##
## A modal is on its own hit-test layer (`ModalLayer`), above the page: it is a
## shallow child of the root, and without the layer whatever lay under its
## buttons -- nested deeper, so preferred -- took their clicks and the dialog
## could never be closed. Closed, it is invisible, so it leaves the hit-test
## tree and the page has the pointer back.

import rui_core
import rui_drawing

import raylib

const TitleBarHeight* = 30.0'f32

proc overlayBounds*(widget: Widget): Rect =
  ## The rect a modal should occupy: its root's, which is the app's whole area,
  ## or the screen while it is not yet in a tree that has been laid out.
  var root = widget
  while root.parent != nil: root = root.parent
  if root != widget and root.bounds.width > 0 and root.bounds.height > 0:
    return root.bounds
  Rect(x: 0, y: 0,
       width: float32(getScreenWidth()),
       height: float32(getScreenHeight()))

const ModalLayer* = 100

proc initModal*(widget: Widget) =
  ## For a modal's `init`: closed, on the modal layer, and able to take keys.
  widget.hitLayer = ModalLayer
  widget.visible = false
  widget.focusable = true

proc openModal*(widget: Widget) =
  ## Show it above the page, taking every click and the keyboard.
  widget.visible = true
  widget.isDirty = true
  widget.layoutDirty = true
  widget.markDirtyToRoot()
  freezeBehind(widget)          # the page behind it stops: a still picture (freeze.nim)
  wantFocus(widget)

proc closeModal*(widget: Widget) =
  ## Take it off the screen and out of the hit-test tree.
  widget.visible = false
  widget.isDirty = true
  thaw(widget)
  # Hidden, it is skipped by the layout check, so it is the parent that asks for
  # the pass that takes it out of the hit-test tree.
  if widget.parent != nil: widget.parent.layoutDirty = true
  widget.markDirtyToRoot()

proc panelRect*(bounds: Rect, width, height: float32): Rect =
  ## The dialog box, centred in the overlay.
  Rect(x: bounds.x + (bounds.width - width) / 2,
       y: bounds.y + (bounds.height - height) / 2,
       width: width, height: height)

proc drawModalFrame*(modal: Widget, panel: Rect, title: string,
                     intent = ThemeIntent.Default): ThemeProps =
  ## What every modal paints first: the backdrop over its whole area -- the
  ## page frozen behind it, in the theme's backdrop look (backdrop.nim) --
  ## then the shadowed themed panel with its title bar. Returns the panel's
  ## props so the caller can draw its own content in the same colours.
  drawBackdrop(modal, modal.bounds)
  result = currentTheme.getThemeProps(intent, Normal)
  drawFloatingShadow(panel, result)
  drawThemedBackground(panel, result)
  drawThemedBorder(panel, result)
  let titleRect = Rect(x: panel.x, y: panel.y, width: panel.width, height: TitleBarHeight)
  if currentTheme.titleColor.isSome:
    # A coloured title tab, as in BeOS: the same tab a window wears.
    discard drawWindowTab(Rect(x: panel.x, y: panel.y, width: panel.width, height: TitleBarHeight),
                          title, result, currentTheme.titleColor.get)
    return
  let titleProps = currentTheme.getThemeProps(intent, Selected)
  drawThemedBackground(titleRect, titleProps)
  drawThemedPaddedText(title, titleRect, titleProps, selected = true)
