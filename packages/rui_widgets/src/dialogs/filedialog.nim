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
import std/[options, os, strutils]

import raylib

type
  FileDialogMode* = enum
    fdOpen              # Open an existing file
    fdSave              # Save a file (a new name is allowed)
    fdDirectory         # Choose a directory

const
  TitleBarHeight = 30.0'f32
  RowHeight = 20.0'f32
  ButtonWidth = 80.0'f32
  ButtonHeight = 30.0'f32
  Margin = 10.0'f32

proc okLabelFor(mode: FileDialogMode): string =
  case mode
  of fdOpen: "Open"
  of fdSave: "Save"
  of fdDirectory: "Select"

proc listRect*(panel: Rect): Rect =
  ## The file list area inside the panel.
  Rect(x: panel.x + Margin, y: panel.y + 70,
       width: panel.width - Margin * 2,
       height: panel.height - 70 - ButtonHeight - Margin * 3)

proc okRect*(panel: Rect): Rect =
  Rect(x: panel.x + panel.width - ButtonWidth - 20,
       y: panel.y + panel.height - ButtonHeight - 15,
       width: ButtonWidth, height: ButtonHeight)

proc cancelRect*(panel: Rect): Rect =
  let ok = okRect(panel)
  Rect(x: ok.x - ButtonWidth - Margin, y: ok.y,
       width: ButtonWidth, height: ButtonHeight)

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
        let idx = int((event.mousePos.y - list.y + widget.scrollY) / RowHeight)
        if idx >= 0 and idx < widget.files.len:
          let entry = widget.files[idx]
          # Directories navigate instead of selecting; ".." goes up.
          if entry == ParentEntry:
            widget.currentPath = widget.currentPath.parentDir()
            if widget.currentPath.len == 0:
              widget.currentPath = "/"
            widget.files = listEntries(widget.currentPath, widget.filters,
                                       widget.mode == fdDirectory)
            widget.selectedIndex = -1
            widget.scrollY = 0
          elif entry.endsWith("/"):
            widget.currentPath = widget.currentPath / entry[0..^2]
            widget.files = listEntries(widget.currentPath, widget.filters,
                                       widget.mode == fdDirectory)
            widget.selectedIndex = -1
            widget.scrollY = 0
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
        let idx = int((event.mousePos.y - list.y + widget.scrollY) / RowHeight)
        if idx >= 0 and idx < widget.files.len:
          newHover = idx
      if newHover != widget.hoverIndex:
        widget.hoverIndex = newHover
        widget.isDirty = true
      return true

    on_mouse_wheel:
      if not widget.isVisible:
        return false
      let panel = panelRect(widget.bounds, widget.dialogWidth, widget.dialogHeight)
      let list = listRect(panel)
      let maxScroll = max(0.0'f32, float32(widget.files.len) * RowHeight - list.height)
      let newScroll = clamp(widget.scrollY - event.wheelDelta * RowHeight * 3.0,
                            0.0'f32, maxScroll)
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

    let clip = beginClip(list)
    for i, entry in widget.files:
      let rowY = list.y + float32(i) * RowHeight - widget.scrollY
      if rowY + RowHeight < list.y or rowY > list.y + list.height:
        continue
      drawListItem(Rect(x: list.x, y: rowY, width: list.width, height: RowHeight),
                   entry, props,
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
