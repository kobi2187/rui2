## Directory listing shared by FileDialog and FilePicker.
##
## Neither widget ever actually scanned a directory before the split -- both
## rendered whatever was in their `files` field, and nothing ever filled it in.

import std/[os, algorithm, strutils]

const ParentEntry* = ".."

proc isWildcard(filter: string): bool =
  ## A filter that lets everything through.
  filter.len == 0 or filter == "*"

proc matchesFilter*(name, filter: string): bool =
  ## One filter against one name. Only the common "*.ext" shape is treated as a
  ## glob; anything else is compared literally.
  if filter.isWildcard:
    return true
  if filter.startsWith("*."):
    return name.toLowerAscii().endsWith(filter[1..^1].toLowerAscii())
  name == filter

proc matchesAnyFilter*(name: string, filters: seq[string]): bool =
  ## A file passes when it matches any filter, or when there are none at all.
  if filters.len == 0:
    return true
  for filter in filters:
    if name.matchesFilter(filter):
      return true
  false

proc acceptsFile(entry: string, filters: seq[string], dirsOnly: bool): bool =
  ## A file entry is listed only when files are wanted and it passes the filter.
  not dirsOnly and matchesAnyFilter(entry, filters)

proc splitEntries(path: string, filters: seq[string], dirsOnly: bool):
    tuple[dirs, files: seq[string]] =
  ## Directories (with a trailing "/") and passing files in `path`.
  ##
  ## An unreadable path yields nothing rather than raising, so a dialog pointed
  ## at a directory it cannot open still lets the user navigate out.
  try:
    for kind, entry in walkDir(path, relative = true):
      case kind
      of pcDir, pcLinkToDir:
        result.dirs.add(entry & "/")
      of pcFile, pcLinkToFile:
        if entry.acceptsFile(filters, dirsOnly):
          result.files.add(entry)
  except OSError:
    discard

proc listEntries*(path: string, filters: seq[string] = @[],
                  dirsOnly = false): seq[string] =
  ## Directory entries for `path`: ".." first, then sorted directories, then
  ## sorted files that pass the filter.
  var (dirs, files) = splitEntries(path, filters, dirsOnly)
  dirs.sort()
  files.sort()
  result = @[ParentEntry] & dirs & files
  assert result.len >= 1 and result[0] == ParentEntry,
         "the parent entry must always be first so the user can navigate out"
