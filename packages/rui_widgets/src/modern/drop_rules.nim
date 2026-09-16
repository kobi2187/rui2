## What a DragDropArea accepts, and why it refuses the rest.
##
## Split out of dragdroparea.nim. The policy takes the rules -- a mode, a list
## of extensions, a size cap -- rather than the widget, so it is decidable
## without a widget, a window, or a real drop event. The widget keeps the part
## that needs one: polling raylib for drops and firing the callbacks.

import std/[options, os]

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

proc keepFirstOnly*(batch: var DropBatch) =
  ## Single-file mode keeps the first accepted item and rejects the rest.
  assert batch.accepted.len > 1
  for item in batch.accepted[1..^1]:
    batch.rejected.add(item.path)
  batch.reason = "Only one item accepted"
  batch.accepted.setLen(1)

