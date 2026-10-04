## DragDropArea Widget - RUI2
##
## A drop target for files and directories, with drag-over feedback and a
## click-to-browse fallback.
##
## Files dropped from the OS arrive as an `evFileDrop` event carrying the paths
## and the pointer position, and go to the widget under the pointer (bubbling to
## its ancestors, like a click) -- any widget can take drops with an
## `on_file_drop:` handler. Nothing needs to poll.
##
## raylib reports a drop only when it happens, never while files are still being
## dragged over the window, so `hoverText` and the drag-over look cannot be
## shown in advance; and dragging *out* of the window is not available.
##
## `pollFileDrops` is still here for apps that already call it once per frame.

import rui_core
import rui_drawing
import std/[options, os, strutils]

import raylib

import drop_rules
export drop_rules

proc judgeAll[W](widget: W, paths: seq[string]): DropBatch =
  ## Run every dropped path past the widget's rules.
  for path in paths:
    let verdict = judgeDrop(widget.mode, widget.acceptedExtensions,
                            widget.maxFileSize, path)
    if verdict.accepted:
      result.accepted.add(verdict.item)
    else:
      result.rejected.add(path)
      result.reason = verdict.reason

  if not widget.multiple and result.accepted.len > 1:
    result.keepFirstOnly()

proc announce[W](widget: W, batch: DropBatch) =
  ## Fire whichever callbacks the batch warrants.
  if batch.accepted.len > 0:
    widget.lastDroppedFiles = batch.accepted
    if widget.onFilesDropped != nil:
      widget.onFilesDropped(batch.accepted)

  if batch.rejected.len > 0 and widget.onFilesRejected != nil:
    widget.onFilesRejected(batch.rejected, batch.reason)

proc receiveDrop*[W](widget: W, paths: seq[string]) =
  ## Files dropped on this widget: filter them against `mode` /
  ## `acceptedExtensions` / `maxFileSize`, and fire onFilesDropped and
  ## onFilesRejected. The App delivers an `evFileDrop` to whichever widget is
  ## under the pointer, so nothing needs to poll.
  let batch = widget.judgeAll(paths)
  widget.isDragOver = false
  widget.errorMessage = batch.reason
  widget.isDirty = true
  widget.announce(batch)

proc pollFileDrops*[W](widget: W) =
  ## The older way: call once per frame and pick up whatever was dropped on the
  ## window, wherever the pointer was. Prefer the event (`receiveDrop` is called
  ## for you); this stays for apps that already poll.
  if isFileDropped():
    widget.receiveDrop(getDroppedFiles())

definePrimitive(DragDropArea):
  props:
    mode: DropMode = dmFiles
    acceptedExtensions: seq[string] = @[]  # e.g. @[".txt", ".nim", ".png"]
    maxFileSize: int64 = 100_000_000       # 100 MB
    multiple: bool = true
    promptText: string = "Drag & drop files here"
    hoverText: string = "Drop files here"
    borderWidth: float32 = 2.0
    borderDashed: bool = true
    cornerRadius: float32 = 8.0
    intent: ThemeIntent = Default

  state:
    isDragOver: bool
    lastDroppedFiles: seq[DroppedItem]
    errorMessage: string

  actions:
    onFilesDropped(files: seq[DroppedItem])
    onFilesRejected(files: seq[string], reason: string)
    onClick()

  init:
    widget.focusable = true

  events:
    on_mouse_down:
      if widget.onClick != nil:
        widget.onClick()
      return true

    # Files dropped on the window from the OS arrive here when the pointer is
    # over this widget -- no polling needed.
    on_file_drop:
      widget.receiveDrop(event.paths)
      return true

  layout:
    if widget.bounds.width <= 0:
      widget.bounds.width = 300.0'f32
    if widget.bounds.height <= 0:
      widget.bounds.height = 150.0'f32

  render:
    # Not visualState's ladder: DragOver is a state only this widget has, and it
    # sits above hover for the same reason Pressed does -- something is
    # happening to this control right now.
    let state = if widget.isDragOver: DragOver
                elif widget.hovered: Hovered
                else: Normal
    let props = currentTheme.getThemeProps(widget.intent, state)

    if widget.cornerRadius > 0:
      drawRoundedRect(widget.bounds, widget.cornerRadius,
                      props.backgroundColor.get(Color(r: 250, g: 250, b: 250, a: 255)),
                      true)
    else:
      drawThemedBackground(widget.bounds, props)

    let borderColor = props.borderColor.get(Color(r: 200, g: 200, b: 200, a: 255))
    if widget.borderDashed:
      # Four dashed edges: a dashed rounded rect is not worth the arithmetic.
      let b = widget.bounds
      drawDashedLine(b.x, b.y, b.x + b.width, b.y, 6.0, borderColor)
      drawDashedLine(b.x, b.y + b.height, b.x + b.width, b.y + b.height, 6.0, borderColor)
      drawDashedLine(b.x, b.y, b.x, b.y + b.height, 6.0, borderColor)
      drawDashedLine(b.x + b.width, b.y, b.x + b.width, b.y + b.height, 6.0, borderColor)
    elif widget.cornerRadius > 0:
      drawRoundedRectLines(widget.bounds, widget.cornerRadius,
                           widget.borderWidth, borderColor)
    else:
      drawThemedBorder(widget.bounds, props)

    let text = if widget.isDragOver: widget.hoverText else: widget.promptText
    drawThemedCenteredText(text, widget.bounds, props)

    if widget.errorMessage.len > 0:
      let errProps = currentTheme.getThemeProps(Danger, Normal)
      let errRect = Rect(x: widget.bounds.x,
                         y: widget.bounds.y + widget.bounds.height - 24,
                         width: widget.bounds.width, height: 20)
      drawThemedCenteredText(widget.errorMessage, errRect, errProps)
