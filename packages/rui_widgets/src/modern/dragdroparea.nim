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

import drop_rules
export drop_rules

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
