## FileDialog Widget - RUI2
##
## A modal file open / save / choose-directory dialog with a working directory
## listing, double-click navigation and filtering.
##
## Like MessageBox, the widget covers the screen so it can dim what is behind
## it, and draws its panel in the middle.

import rui_core
import rui_drawing
import file_listing
import modal
import ../virtual_rows
import std/[options, os, strutils]

export virtual_rows

import raylib

import filedialog_layout
export filedialog_layout

template openDirectory*(widget: untyped, path: string) =
  ## Move to `path` and re-read it. The selection and scroll belong to the
  ## directory you left, so both are dropped.
  widget.currentPath = path
  widget.files = listEntries(path, widget.filters, widget.mode == fdDirectory)
  widget.selectedIndex = -1
  widget.scrollY = 0

definePrimitive(FileDialog):
  props:
    title: string = "Select File"
    mode: FileDialogMode = fdOpen
    filters: seq[string] = @[]   # e.g. @["*.txt", "*.nim"]
    initialPath: string = "."
    dialogWidth: float32 = 600.0
    dialogHeight: float32 = 400.0

  state:
    isVisible: bool
    currentPath: string
    selectedIndex: int
    hoverIndex: int
    scrollY: float32
    files: seq[string]           # Entries in currentPath
    accepted: bool               # True when OK was pressed

  actions:
    onSelect(files: seq[string])
    onCancel()

  events:
    on_mouse_down:
      if not widget.isVisible:
        return false
      let panel = panelRect(widget.bounds, widget.dialogWidth, widget.dialogHeight)

      if cancelRect(panel).contains(event.mousePos.x, event.mousePos.y):
        widget.isVisible = false
        widget.accepted = false
        widget.isDirty = true
        if widget.onCancel.isSome:
          widget.onCancel.get()()
        return true

      if okRect(panel).contains(event.mousePos.x, event.mousePos.y):
        widget.isVisible = false
        widget.accepted = true
        widget.isDirty = true
        if widget.onSelect.isSome and widget.selectedIndex >= 0 and
           widget.selectedIndex < widget.files.len:
          widget.onSelect.get()(@[widget.currentPath / widget.files[widget.selectedIndex]])
        return true

      let list = listRect(panel)
      if list.contains(event.mousePos.x, event.mousePos.y):
        let idx = listViewport(list, widget.scrollY).rowAt(event.mousePos.y,
                                                           widget.files.len)
        if idx >= 0:
          let entry = widget.files[idx]
          # Directories navigate instead of selecting; ".." goes up.
          let dest = navigatedPath(widget.currentPath, entry)
          if dest.len > 0:
            widget.openDirectory(dest)
          else:
            widget.selectedIndex = idx
          widget.isDirty = true
        return true

      # A modal swallows every click.
      return true

    on_mouse_move:
      if not widget.isVisible:
        return false
      let panel = panelRect(widget.bounds, widget.dialogWidth, widget.dialogHeight)
      let list = listRect(panel)
      var newHover = -1
      if list.contains(event.mousePos.x, event.mousePos.y):
        newHover = listViewport(list, widget.scrollY).rowAt(event.mousePos.y,
                                                            widget.files.len)
      if newHover != widget.hoverIndex:
        widget.hoverIndex = newHover
        widget.isDirty = true
      return true

    on_mouse_wheel:
      if not widget.isVisible:
        return false
      let panel = panelRect(widget.bounds, widget.dialogWidth, widget.dialogHeight)
      let v = listViewport(listRect(panel), widget.scrollY)
      let newScroll = v.scrolledBy(event.wheelDelta, widget.files.len)
      if newScroll != widget.scrollY:
        widget.scrollY = newScroll
        widget.isDirty = true
      return true

    on_key_down:
      if not widget.isVisible:
        return false
      if event.key == Escape:
        widget.isVisible = false
        widget.accepted = false
        widget.isDirty = true
        if widget.onCancel.isSome:
          widget.onCancel.get()()
        return true
      return false

  layout:
    # Fill the screen so the dim overlay has somewhere to go.
    widget.bounds = overlayBounds()

  render:
    if not widget.isVisible:
      return

    drawRect(widget.bounds, Color(r: 0, g: 0, b: 0, a: 128))

    let props = currentTheme.getThemeProps(Default, Normal)
    let panel = panelRect(widget.bounds, widget.dialogWidth, widget.dialogHeight)

    drawShadow(panel, Shadow(offsetX: 3.0, offsetY: 3.0, blur: 0.0, spread: 0.0,
                             color: Color(r: 0, g: 0, b: 0, a: 60)))
    drawThemedBackground(panel, props)
    drawThemedBorder(panel, props)

    let titleRect = Rect(x: panel.x, y: panel.y,
                         width: panel.width, height: TitleBarHeight)
    let titleProps = currentTheme.getThemeProps(Default, Selected)
    drawThemedBackground(titleRect, titleProps)
    drawThemedPaddedText(widget.title, titleRect, titleProps, selected = true)

    let fgColor = props.foregroundColor.get(Color(r: 60, g: 60, b: 60, a: 255))
    drawText("Path: " & widget.currentPath, panel.x + Margin, panel.y + 45, 12.0, fgColor)

    let list = listRect(panel)
    drawThemedBackground(list, props)
    drawThemedBorder(list, props)

    let v = listViewport(list, widget.scrollY)
    let clip = beginClip(list)
    for i in v.visibleRange(widget.files.len):
      drawListItem(Rect(x: list.x, y: v.rowTop(i),
                        width: list.width, height: RowHeight),
                   widget.files[i], props,
                   selected = i == widget.selectedIndex,
                   hovered = i == widget.hoverIndex)
    endClip(clip)

    drawButton(okRect(panel), okLabelFor(widget.mode), props)
    drawButton(cancelRect(panel), "Cancel", props)

proc show*(widget: FileDialog) =
  ## Display the dialog and read the starting directory.
  widget.isVisible = true
  widget.accepted = false
  widget.selectedIndex = -1
  widget.hoverIndex = -1
  widget.scrollY = 0
  if widget.currentPath.len == 0:
    widget.currentPath = widget.initialPath
  widget.files = listEntries(widget.currentPath, widget.filters,
                             widget.mode == fdDirectory)
  widget.isDirty = true
  widget.layoutDirty = true
