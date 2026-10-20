## Directory listing shared by FileDialog and FilePicker.
##
## Neither widget ever actually scanned a directory before the split -- both
## rendered whatever was in their `files` field, and nothing ever filled it in.

import std/[os, algorithm, strutils]

const ParentEntry* = ".."

proc isDirectoryEntry*(entry: string): bool =
  ## Entries that navigate rather than select: the parent, and any directory,
  ## which listEntries marks with a trailing "/".
  entry == ParentEntry or entry.endsWith("/")

proc navigatedPath*(currentPath, entry: string): string =
  ## Where clicking `entry` takes you, or "" when it is a plain file and the
  ## click is a selection instead. Walking up from the root stays at the root
  ## rather than producing an empty path.
  if entry == ParentEntry:
    let up = currentPath.parentDir()
    result = if up.len == 0: "/" else: up
  elif entry.endsWith("/"):
    result = currentPath / entry[0 ..< ^1]
  else:
    result = ""

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

proc globMatch(name, pattern: string): bool =
  ## `*` any run, `?` any one character; everything else literal. Both lower case.
  var n, p = 0
  var star = -1
  var mark = 0
  while n < name.len:
    if p < pattern.len and (pattern[p] == '?' or pattern[p] == name[n]):
      inc n; inc p
    elif p < pattern.len and pattern[p] == '*':
      star = p; mark = n; inc p
    elif star >= 0:
      p = star + 1; inc mark; n = mark
    else:
      return false
  while p < pattern.len and pattern[p] == '*': inc p
  p == pattern.len

proc matchesName*(entry, pattern: string): bool =
  ## The name filter a user types: empty lets everything through, one with `*`
  ## or `?` is a glob over the whole name ("*.nim", "draft?"), anything else
  ## is a piece of the name. Case is ignored; a directory's trailing "/" is not
  ## part of its name. The parent entry always passes: it is the way out.
  if entry == ParentEntry or pattern.strip.len == 0: return true
  let name = (if entry.endsWith("/"): entry[0 ..< ^1] else: entry).toLowerAscii
  let want = pattern.strip.toLowerAscii
  if '*' in want or '?' in want: globMatch(name, want)
  else: want in name
