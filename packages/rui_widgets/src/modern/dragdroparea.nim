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

  DropVerdict* = object
    ## The decision on one dropped path. `item` is only meaningful when
    ## accepted; `reason` only when refused.
    accepted*: bool
    item*: DroppedItem
    reason*: string

  DropBatch* = object
    ## The outcome of one drop event, before any callback fires.
    accepted*: seq[DroppedItem]
    rejected*: seq[string]
    reason*: string

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

proc modeRejection*(mode: DropMode, isDir: bool): string =
  ## Why an entry of this kind is refused in this mode, or "" if it is fine.
  case mode
  of dmFiles: (if isDir: "Directories not accepted" else: "")
  of dmDirectories: (if isDir: "" else: "Only directories accepted")
  of dmBoth: ""

proc extensionRejection*(path: string, allowed: seq[string]): string =
  ## Why this path's extension is refused, or "" if it passes. An empty
  ## `allowed` accepts everything.
  if allowed.len == 0:
    return ""
  let ext = splitFile(path).ext
  if ext in allowed: "" else: "File type not accepted: " & ext

proc fileSizeOrNone(path: string): Option[int64] =
  ## none when the file cannot be read at all.
  try: some(getFileSize(path))
  except OSError, IOError: none(int64)

proc judgeFile(path: string, allowed: seq[string], maxSize: int64): DropVerdict =
  ## Extension and size checks, for a path already known to be a file.
  let extWhy = extensionRejection(path, allowed)
  if extWhy.len > 0:
    return DropVerdict(accepted: false, reason: extWhy)

  let size = fileSizeOrNone(path)
  if size.isNone:
    return DropVerdict(accepted: false, reason: "Could not read: " & path)
  if size.get() > maxSize:
    return DropVerdict(accepted: false, reason: "File too large: " & path)

  DropVerdict(accepted: true,
              item: DroppedItem(path: path, isDirectory: false, size: size.get()))

proc judgeDrop*(mode: DropMode, allowed: seq[string], maxSize: int64,
                path: string): DropVerdict =
  ## Decide one dropped path. Takes the rules rather than the widget, so the
  ## accept/reject policy is testable without a widget or a window.
  assert maxSize > 0, "maxFileSize of 0 would reject every file"
  let isDir = dirExists(path)

  let modeWhy = modeRejection(mode, isDir)
  if modeWhy.len > 0:
    return DropVerdict(accepted: false, reason: modeWhy)

  if isDir:
    return DropVerdict(accepted: true,
                       item: DroppedItem(path: path, isDirectory: true, size: 0))
  judgeFile(path, allowed, maxSize)

proc keepFirstOnly(batch: var DropBatch) =
  ## Single-file mode keeps the first accepted item and rejects the rest.
  assert batch.accepted.len > 1
  for item in batch.accepted[1..^1]:
    batch.rejected.add(item.path)
  batch.reason = "Only one item accepted"
  batch.accepted.setLen(1)

proc judgeAll(widget: DragDropArea, paths: seq[string]): DropBatch =
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

proc announce(widget: DragDropArea, batch: DropBatch) =
  ## Fire whichever callbacks the batch warrants.
  if batch.accepted.len > 0:
    widget.lastDroppedFiles = batch.accepted
    if widget.onFilesDropped.isSome:
      widget.onFilesDropped.get()(batch.accepted)

  if batch.rejected.len > 0 and widget.onFilesRejected.isSome:
    widget.onFilesRejected.get()(batch.rejected, batch.reason)

proc pollFileDrops*(widget: DragDropArea) =
  ## Call once per frame. Picks up any files dropped on the window, filters them
  ## against `mode` / `acceptedExtensions` / `maxFileSize`, and fires
  ## onFilesDropped and onFilesRejected.
  if not isFileDropped():
    return

  let batch = widget.judgeAll(getDroppedFiles())
  widget.isDragOver = false
  widget.errorMessage = batch.reason
  widget.isDirty = true
  widget.announce(batch)
