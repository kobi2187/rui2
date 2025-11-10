## FileDialog Widget - RUI2
##
## A file open/save dialog for selecting files and directories.
## Provides file browsing, filtering, and selection.
## Uses defineWidget with internal ListView and path navigation.

import ../../core/widget_dsl_v2
import std/[options, os, strutils]

when defined(useGraphics):
  import raylib

type
  FileDialogMode* = enum
    fdOpen              # Open existing file
    fdSave              # Save file (can create new)
    fdDirectory         # Select directory

defineWidget(FileDialog):
  props:
    title: string = "Select File"
    mode: FileDialogMode = fdOpen
    filters: seq[string] = @[]   # e.g., @["*.txt", "*.nim"]
    initialPath: string = "."
    width: float = 600.0
    height: float = 400.0
    multiSelect: bool = false    # Allow selecting multiple files (fdOpen only)

  state:
    isVisible: bool
    currentPath: string
    selectedFiles: seq[string]
    files: seq[string]           # Files in current directory
    result: bool                 # True if OK clicked, False if cancelled

  actions:
    onSelect(files: seq[string])
    onCancel()

  layout:
    # Center the dialog
    widget.bounds.width = widget.width
    widget.bounds.height = widget.height

    # TODO: Layout internal components (path bar, file list, buttons)

  events:
    on_key_down:
      # ESC closes the dialog
      when defined(useGraphics):
        if widget.isVisible.get():
          widget.isVisible.set(false)
          if widget.onCancel.isSome:
            widget.onCancel.get()()
          return true
      return false

  render:
    when defined(useGraphics):
      if widget.isVisible.get():
        # Draw semi-transparent overlay
        DrawRectangle(
          0, 0,
          GetScreenWidth(),
          GetScreenHeight(),
          Color(r: 0, g: 0, b: 0, a: 128)
        )

        # Draw dialog background
        DrawRectangleRec(widget.bounds, Color(r: 250, g: 250, g: 250, a: 255))

        # Draw border
        DrawRectangleLinesEx(widget.bounds, 2.0, Color(r: 100, g: 100, b: 100, a: 255))

        # Draw title bar
        DrawRectangle(
          widget.bounds.x.cint,
          widget.bounds.y.cint,
          widget.bounds.width.cint,
          30,
          Color(r: 60, g: 120, b: 180, a: 255)
        )

        DrawText(
          widget.title.cstring,
          (widget.bounds.x + 10).cint,
          (widget.bounds.y + 8).cint,
          14,
          Color(r: 255, g: 255, b: 255, a: 255)
        )

        # Draw path bar
        let pathY = widget.bounds.y + 40
        DrawText(
          "Path:".cstring,
          (widget.bounds.x + 10).cint,
          pathY.cint,
          12,
          Color(r: 60, g: 60, b: 60, a: 255)
        )

        DrawText(
          widget.currentPath.get().cstring,
          (widget.bounds.x + 50).cint,
          pathY.cint,
          12,
          Color(r: 100, g: 100, b: 100, a: 255)
        )

        # Draw file list area
        let listY = widget.bounds.y + 70
        let listHeight = widget.bounds.height - 140

        DrawRectangle(
          (widget.bounds.x + 10).cint,
          listY.cint,
          (widget.bounds.width - 20).cint,
          listHeight.cint,
          Color(r: 255, g: 255, b: 255, a: 255)
        )

        # TODO: Use ListView widget to show files

        # Draw buttons at bottom
        let buttonY = widget.bounds.y + widget.bounds.height - 50
        var buttonX = widget.bounds.x + widget.bounds.width - 110

        # OK/Open/Save button
        let okLabel = case widget.mode:
                      of fdOpen: "Open"
                      of fdSave: "Save"
                      of fdDirectory: "Select"

        if GuiButton(
          Rectangle(x: buttonX, y: buttonY, width: 80, height: 30),
          okLabel.cstring
        ):
          widget.isVisible.set(false)
          widget.result.set(true)
          if widget.onSelect.isSome:
            widget.onSelect.get()(widget.selectedFiles.get())

        # Cancel button
        buttonX -= 90
        if GuiButton(
          Rectangle(x: buttonX, y: buttonY, width: 80, height: 30),
          "Cancel".cstring
        ):
          widget.isVisible.set(false)
          widget.result.set(false)
          if widget.onCancel.isSome:
            widget.onCancel.get()()
    else:
      # Non-graphics mode
      if widget.isVisible.get():
        echo "╔═══ ", widget.title, " ", "═".repeat(max(0, 30 - widget.title.len)), "═╗"
        echo "║ Path: ", widget.currentPath.get()
        echo "║ Files:"
        for f in widget.files.get():
          echo "║   ", f
        echo "╚", "═".repeat(40), "╝"
