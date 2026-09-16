## FilePicker Widget - RUI2
##
## An embeddable file picker: a path strip on top, a scrollable directory
## listing below. Unlike FileDialog it is not modal and has no buttons -- drop
## it into any container and listen to onSelect.

import rui_core
import rui_drawing
import file_listing
import ../virtual_rows
import ../list_input
import std/[options, os, sets, strutils]

export virtual_rows, list_input

import raylib

type
  FilePickerMode* = enum
    fpOpen              # Open an existing file
    fpSave              # Save a file
    fpDirectory         # Choose a directory

const
  PathBarHeight = 28.0'f32
  RowHeight = 20.0'f32
  ListGap = 4.0'f32        ## Space between the path strip and the list

template listTopOf*(widget: untyped): float32 =
  widget.bounds.y + PathBarHeight + ListGap

template viewportOf*(widget: untyped): RowViewport =
  ## A template, not a proc: the FilePicker type does not exist until the macro
  ## below has expanded, and the widget body needs this.
  rowViewport(top = widget.listTopOf,
              height = widget.bounds.height - PathBarHeight - ListGap,
              rowHeight = RowHeight, scrollY = widget.scrollY)

template openDirectory*(widget: untyped, path: string) =
  ## Move to `path` and re-read it. The selection and scroll belong to the
  ## directory you left, so both are dropped.
  widget.currentPath = path
  widget.fileList = listEntries(path, widget.filters,
                                widget.mode == fpDirectory)
  widget.selectedFiles.clear()
  widget.scrollY = 0

definePrimitive(FilePicker):
  props:
    mode: FilePickerMode = fpOpen
    filters: seq[string] = @[]   # e.g. @["*.txt", "*.nim"]
    initialPath: string = "."
    multiSelect: bool = false
    intent: ThemeIntent = Default

  state:
    currentPath: string
    selectedFiles: HashSet[string]
    fileList: seq[string]
    scrollY: float32
    hoverIndex: int
    loaded: bool                 # Directory has been scanned at least once

  actions:
    onSelect(paths: HashSet[string])
    onPathChange(path: string)

  events:
    on_mouse_down:
      let idx = viewportOf(widget).rowAt(event.mousePos.y, widget.fileList.len)
      if idx < 0:
        return false

      let entry = widget.fileList[idx]
      # Directories navigate; only files are selectable.
      let dest = navigatedPath(widget.currentPath, entry)
      if dest.len > 0:
        widget.openDirectory(dest)
        widget.isDirty = true
        if widget.onPathChange.isSome:
          widget.onPathChange.get()(widget.currentPath)
        return true

      # A single-select picker ignores ctrl rather than quietly multi-selecting.
      let additive = widget.multiSelect and
                     (isKeyDown(LeftControl) or isKeyDown(RightControl))
      updateSelection(widget.selectedFiles, widget.currentPath / entry, additive)

      widget.isDirty = true
      if widget.onSelect.isSome:
        widget.onSelect.get()(widget.selectedFiles)
      return true

    on_mouse_move:
      let newHover = viewportOf(widget).rowAt(event.mousePos.y,
                                              widget.fileList.len)
      if newHover != widget.hoverIndex:
        widget.hoverIndex = newHover
        widget.isDirty = true
      return false

    on_mouse_wheel:
      let newScroll = viewportOf(widget).scrolledBy(event.wheelDelta,
                                                    widget.fileList.len)
      if newScroll != widget.scrollY:
        widget.scrollY = newScroll
        widget.isDirty = true
      return true

  layout:
    # First layout is also when the directory gets read: a picker built from the
    # DSL constructor has no chance to run code of its own before this.
    if not widget.loaded:
      if widget.currentPath.len == 0:
        widget.currentPath = widget.initialPath
      widget.fileList = listEntries(widget.currentPath, widget.filters,
                                    widget.mode == fpDirectory)
      widget.loaded = true

    if widget.bounds.width <= 0:
      widget.bounds.width = 300.0'f32
    if widget.bounds.height <= 0:
      widget.bounds.height = PathBarHeight + 4 + RowHeight * 10

  render:
    let props = currentTheme.getThemeProps(widget.intent, Normal)

    let pathRect = Rect(x: widget.bounds.x, y: widget.bounds.y,
                        width: widget.bounds.width, height: PathBarHeight)
    drawInteractiveBox(pathRect, props)
    drawThemedPaddedText(widget.currentPath, pathRect, props)

    let v = viewportOf(widget)
    let list = Rect(x: widget.bounds.x, y: v.top,
                    width: widget.bounds.width, height: v.height)
    drawThemedBackground(list, props)

    let clip = beginClip(list)
    for i in v.visibleRange(widget.fileList.len):
      let entry = widget.fileList[i]
      drawListItem(Rect(x: list.x, y: v.rowTop(i),
                        width: list.width, height: RowHeight),
                   entry, props,
                   selected = (widget.currentPath / entry) in widget.selectedFiles,
                   hovered = i == widget.hoverIndex)
    endClip(clip)

    drawThemedBorder(list, props)

proc refresh*(widget: FilePicker) =
  ## Re-read the current directory, e.g. after something on disk changed.
  widget.fileList = listEntries(widget.currentPath, widget.filters,
                                widget.mode == fpDirectory)
  widget.isDirty = true
