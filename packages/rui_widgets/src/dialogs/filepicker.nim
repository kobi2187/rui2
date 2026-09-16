## FilePicker Widget - RUI2
##
## An embeddable file picker: a path strip on top, a scrollable directory
## listing below. Unlike FileDialog it is not modal and has no buttons -- drop
## it into any container and listen to onSelect.

import rui_core
import rui_drawing
import file_listing
import std/[options, os, sets, strutils]

import raylib

type
  FilePickerMode* = enum
    fpOpen              # Open an existing file
    fpSave              # Save a file
    fpDirectory         # Choose a directory

const
  PathBarHeight = 28.0'f32
  RowHeight = 20.0'f32

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
      let listTop = widget.bounds.y + PathBarHeight + 4
      if event.mousePos.y < listTop:
        return false

      let idx = int((event.mousePos.y - listTop + widget.scrollY) / RowHeight)
      if idx < 0 or idx >= widget.fileList.len:
        return false

      let entry = widget.fileList[idx]
      # Directories navigate; only files are selectable.
      if entry == ParentEntry or entry.endsWith("/"):
        widget.currentPath =
          if entry == ParentEntry:
            let up = widget.currentPath.parentDir()
            if up.len == 0: "/" else: up
          else:
            widget.currentPath / entry[0..^2]
        widget.fileList = listEntries(widget.currentPath, widget.filters,
                                      widget.mode == fpDirectory)
        widget.selectedFiles.clear()
        widget.scrollY = 0
        widget.isDirty = true
        if widget.onPathChange.isSome:
          widget.onPathChange.get()(widget.currentPath)
        return true

      let fullPath = widget.currentPath / entry
      let ctrlDown = isKeyDown(LeftControl) or isKeyDown(RightControl)
      if widget.multiSelect and ctrlDown:
        if fullPath in widget.selectedFiles: widget.selectedFiles.excl(fullPath)
        else: widget.selectedFiles.incl(fullPath)
      else:
        widget.selectedFiles = [fullPath].toHashSet

      widget.isDirty = true
      if widget.onSelect.isSome:
        widget.onSelect.get()(widget.selectedFiles)
      return true

    on_mouse_move:
      let listTop = widget.bounds.y + PathBarHeight + 4
      var newHover = -1
      if event.mousePos.y >= listTop:
        let idx = int((event.mousePos.y - listTop + widget.scrollY) / RowHeight)
        if idx >= 0 and idx < widget.fileList.len:
          newHover = idx
      if newHover != widget.hoverIndex:
        widget.hoverIndex = newHover
        widget.isDirty = true
      return false

    on_mouse_wheel:
      let listHeight = widget.bounds.height - PathBarHeight - 4
      let maxScroll = max(0.0'f32, float32(widget.fileList.len) * RowHeight - listHeight)
      let newScroll = clamp(widget.scrollY - event.wheelDelta * RowHeight * 3.0,
                            0.0'f32, maxScroll)
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

    let list = Rect(x: widget.bounds.x, y: widget.bounds.y + PathBarHeight + 4,
                    width: widget.bounds.width,
                    height: widget.bounds.height - PathBarHeight - 4)
    drawThemedBackground(list, props)

    let clip = beginClip(list)
    for i, entry in widget.fileList:
      let rowY = list.y + float32(i) * RowHeight - widget.scrollY
      if rowY + RowHeight < list.y or rowY > list.y + list.height:
        continue
      let fullPath = widget.currentPath / entry
      drawListItem(Rect(x: list.x, y: rowY, width: list.width, height: RowHeight),
                   entry, props,
                   selected = fullPath in widget.selectedFiles,
                   hovered = i == widget.hoverIndex)
    endClip(clip)

    drawThemedBorder(list, props)

proc refresh*(widget: FilePicker) =
  ## Re-read the current directory, e.g. after something on disk changed.
  widget.fileList = listEntries(widget.currentPath, widget.filters,
                                widget.mode == fpDirectory)
  widget.isDirty = true
