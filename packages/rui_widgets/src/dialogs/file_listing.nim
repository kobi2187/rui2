## Directory listing shared by FileDialog and FilePicker.
##
## Neither widget ever actually scanned a directory before the split -- both
## rendered whatever was in their `files` field, and nothing ever filled it in.

import std/[os, algorithm, strutils]

const ParentEntry* = ".."

proc matchesAnyFilter*(name: string, filters: seq[string]): bool =
  ## A file passes when it matches any glob, or when there are no globs at all.
  if filters.len == 0:
    return true
  for filter in filters:
    if filter.len == 0 or filter == "*":
      return true
    # Only the common "*.ext" shape is handled; anything else is a literal match.
    if filter.startsWith("*."):
      if name.toLowerAscii().endsWith(filter[1..^1].toLowerAscii()):
        return true
    elif name == filter:
      return true
  false

proc listEntries*(path: string, filters: seq[string] = @[],
                  dirsOnly = false): seq[string] =
  ## Directory entries for `path`: ".." first, then sorted directories (with a
  ## trailing "/"), then sorted files that pass the filter.
  ##
  ## An unreadable path yields just ".." rather than raising, so a dialog
  ## pointed at a directory it cannot open still lets the user navigate out.
  var dirs: seq[string] = @[]
  var files: seq[string] = @[]

  try:
    for kind, entry in walkDir(path, relative = true):
      case kind
      of pcDir, pcLinkToDir:
        dirs.add(entry & "/")
      of pcFile, pcLinkToFile:
        if not dirsOnly and matchesAnyFilter(entry, filters):
          files.add(entry)
  except OSError:
    discard

  dirs.sort()
  files.sort()
  result = @[ParentEntry] & dirs & files
