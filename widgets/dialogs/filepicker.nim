## FilePicker Widget - RUI2
##
## An embeddable file picker for selecting files and directories.
## Simpler approach inspired by Hummingbird - uses GuiTextBox and GuiListView.
## Not a modal dialog - can be embedded in any container.
## Uses defineWidget.

import ../../core/widget_dsl
import std/[options, os, strutils, sets]

when defined(useGraphics):
  import raylib

type
  FilePickerMode* = enum
    fpOpen              # Open existing file
    fpSave              # Save file
    fpDirectory         # Select directory

defineWidget(FilePicker):
  props:
    mode: FilePickerMode = fpOpen
    filter: string = "*"         # File filter (e.g., "*.txt", "*.nim")
    initialPath: string = "."
    multiSelect: bool = false

  state:
    currentPath: string
    selectedFiles: HashSet[string]
    fileList: seq[string]        # Cached file list
    scrollIndex: int

  actions:
    onSelect(paths: HashSet[string])
    onPathChange(path: string)

  layout:
    # No children to layout - draws directly
    discard

  render:
    when defined(useGraphics):
      # Path input at top (editable)
      let pathRect = Rectangle(
        x: widget.bounds.x,
        y: widget.bounds.y,
        width: widget.bounds.width,
        height: 28
      )

      var pathStr = widget.currentPath
      # Simple text display for now (full GuiTextBox needs char buffer)
      DrawRectangleRec(pathRect, Color(r: 255, g: 255, b: 255, a: 255))
      DrawRectangleLinesEx(pathRect, 1.0, Color(r: 180, g: 180, b: 180, a: 255))

      DrawText(
        pathStr.cstring,
        (widget.bounds.x + 4).cint,
        (widget.bounds.y + 6).cint,
        12,
        Color(r: 60, g: 60, b: 60, a: 255)
      )

      # File list below
      let listRect = Rectangle(
        x: widget.bounds.x,
        y: widget.bounds.y + 32,
        width: widget.bounds.width,
        height: widget.bounds.height - 32
      )

      # Build file list string (in real implementation, scan directory)
      let files = widget.fileList
      let filesStr = if files.len > 0: files.join(";") else: "<empty>"

      var selectedIdx = -1
      var scrollIdx = widget.scrollIndex.cint

      if GuiListView(
        listRect,
        filesStr.cstring,
        addr scrollIdx,
        addr selectedIdx
      ):
        widget.scrollIndex = scrollIdx.int

        if selectedIdx >= 0 and selectedIdx < files.len:
          let selectedPath = files[selectedIdx]
          var newSelection = widget.selectedFiles

          # Simple selection logic
          if widget.multiSelect:
            if selectedPath in newSelection:
              newSelection.excl(selectedPath)
            else:
              newSelection.incl(selectedPath)
          else:
            newSelection = [selectedPath].toHashSet

          widget.selectedFiles = newSelection

          if widget.onSelect.isSome:
            widget.onSelect.get()(newSelection)
    else:
      # Non-graphics mode
      echo "FilePicker: ", widget.currentPath
      let files = widget.fileList
      for f in files:
        let marker = if f in widget.selectedFiles: "[X]" else: "[ ]"
        echo "  ", marker, " ", f
