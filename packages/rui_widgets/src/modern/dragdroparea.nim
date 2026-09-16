## DragDropArea Widget - RUI2
##
## A drop target for files and directories, with drag-over feedback and a
## click-to-browse fallback.
##
## File drops are not part of the GuiEvent stream, so they cannot arrive through
## `handleInput`. The app polls them instead:
##
##   proc frame(app: App) =
##     dropArea.pollFileDrops()
##     ...
##
## The old version called raylib's IsFileDropped() from inside `render`, which
## meant the drop was only noticed on frames where the widget happened to be
## repainting, and the accept/reject callbacks fired mid-paint.

import rui_core
import rui_drawing
import std/[options, os, strutils]

import raylib

type
  DropMode* = enum
    dmFiles          # Accept files only
    dmDirectories    # Accept directories only
    dmBoth           # Accept either

  DroppedItem* = object
    path*: string
    isDirectory*: bool
    size*: int64

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

  events:
    on_mouse_down:
      if widget.onClick.isSome:
        widget.onClick.get()()
      return true

  layout:
    if widget.bounds.width <= 0:
      widget.bounds.width = 300.0'f32
    if widget.bounds.height <= 0:
      widget.bounds.height = 150.0'f32

  render:
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

proc classify(widget: DragDropArea, path: string,
               accepted: var seq[DroppedItem], rejected: var seq[string],
               reason: var string) =
  ## Sort one dropped path into accepted or rejected, recording why.
  let isDir = dirExists(path)

  if widget.mode == dmFiles and isDir:
    rejected.add(path)
    reason = "Directories not accepted"
    return
  if widget.mode == dmDirectories and not isDir:
    rejected.add(path)
    reason = "Only directories accepted"
    return

  if not isDir:
    if widget.acceptedExtensions.len > 0:
      let ext = splitFile(path).ext
      if ext notin widget.acceptedExtensions:
        rejected.add(path)
        reason = "File type not accepted: " & ext
        return

    var size: int64 = 0
    try:
      size = getFileSize(path)
    except OSError, IOError:
      rejected.add(path)
      reason = "Could not read: " & path
      return

    if size > widget.maxFileSize:
      rejected.add(path)
      reason = "File too large: " & path
      return

    accepted.add(DroppedItem(path: path, isDirectory: false, size: size))
  else:
    accepted.add(DroppedItem(path: path, isDirectory: true, size: 0))

proc pollFileDrops*(widget: DragDropArea) =
  ## Call once per frame. Picks up any files dropped on the window, filters them
  ## against `mode` / `acceptedExtensions` / `maxFileSize`, and fires
  ## onFilesDropped and onFilesRejected.
  if not isFileDropped():
    return

  var accepted: seq[DroppedItem] = @[]
  var rejected: seq[string] = @[]
  var reason = ""

  for path in getDroppedFiles():
    widget.classify(path, accepted, rejected, reason)

  if not widget.multiple and accepted.len > 1:
    # Single-file mode keeps the first and rejects the rest.
    for item in accepted[1..^1]:
      rejected.add(item.path)
    reason = "Only one item accepted"
    accepted.setLen(1)

  widget.isDragOver = false
  widget.errorMessage = reason
  widget.isDirty = true

  if accepted.len > 0:
    widget.lastDroppedFiles = accepted
    if widget.onFilesDropped.isSome:
      widget.onFilesDropped.get()(accepted)

  if rejected.len > 0 and widget.onFilesRejected.isSome:
    widget.onFilesRejected.get()(rejected, reason)
